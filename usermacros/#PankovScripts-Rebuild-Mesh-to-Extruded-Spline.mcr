/* Rebuild-Mesh-to-Extruded-Spline - 2025.08.25 alpha

Скрипт для восстановления исходного состояния импортированных мешей,
которые изначально были сплайнами, выдавленными модификатором Extrude.

Работает по всем выделенным объектам-геометрии:

1. Находит грани крышки: плоские горизонтальные грани (нормаль почти вертикальна),
   лежащие на минимальной (обычный запуск) или максимальной (Shift) высоте.
2. По границе этих граней строит замкнутый сплайн в мировых координатах -
   узел создаётся с единичной трансформацией (без масштабирования),
   все точки заданы в масштабе сцены.
3. При зажатом Ctrl запускает автоматическую обработку скриптом
   scripts\Simplify-Spline.ms:
   run_rebuildArcs (восстановление дуг) -> run_simplifySpline (сокращение вершин
   с защитой границ дуг). Перед вызовами выставляется состояние UI,
   ожидаемое этими функциями: объект один в выделении, Modify-панель
   на базовом объекте, уровень подобъектов - сплайны.
4. Вешает на сплайн модификатор Extrude величиной в высоту исходного меша:
   - нижняя крышка  -> выдавливание вверх (amount положительный);
   - верхняя крышка -> выдавливание вниз (amount отрицательный).

Направление и упрощение выбираются так:
- обычный запуск                 - нижняя крышка, экструзия вверх, без упрощения;
- зажатый Shift                  - верхняя крышка, экструзия вниз, без упрощения;
- зажатый Ctrl                   - включить упрощение сплайна;
- Shift + Ctrl                   - верхняя крышка, экструзия вниз + упрощение.

Слой и принадлежность к группе наследуются от исходного объекта.
При полном успехе (упрощение + Extrude + слой/группа) исходный объект удаляется.
Чтобы оставлять исходные объекты, установите в Listener'е перед запуском:
    REMS_deleteSourceObjects = false

Результат: объект SplineShape (трансформ без масштаба) + модификатор Extrude.
Материал заимствуется с исходного объекта. В Extrude по умолчанию включены
Generate Mapping Coords и Real-World Map Size.

Ограничения:
- предполагается, что исходное выдавливание шло вдоль мировой оси Z;
- обрабатывается одна крышка на объект (самая верхняя/нижняя);
- крышка должна быть плоской и перпендикулярной оси Z;
- один цельный профиль на объект.

Использование:
- выделить меши и запустить макрос "Rebuild Extruded Mesh to Spline"
  (категория "PankovEA Scripts"), либо выполнить run_rebuildExtrudedMeshToSpline().
*/

macroScript REMS_RebuildExtrudedMeshToSpline
    category:"#PankovScripts"
    buttonText:"Rebuild Extruded Mesh to Spline"
    tooltip:"Rebuild Extruded Mesh to Spline (Shift=Extrude upside down, Ctrl=disable Symplify Spline)"
    autoUndoEnabled:false
    icon: #("Standard_Modifiers", 13)
(

global REMS_deleteSourceObjects = true -- false - оставлять исходные объекты

/* --------------------
--
-- Поиск граней крышки
--
*/ --------------------

-- Габаритный контейнер меша m в мировых координатах: #(minPoint3, maxPoint3)
fn REMS_meshBBox m = (
    local nv = m.numVerts
    if nv == 0 do return #([0,0,0], [0,0,0])
    local p0 = getVert m 1
    local xmin = p0.x
    local xmax = p0.x
    local ymin = p0.y
    local ymax = p0.y
    local zmin = p0.z
    local zmax = p0.z
    for v = 2 to nv do (
        local p = getVert m v
        if p.x < xmin do xmin = p.x
        if p.x > xmax do xmax = p.x
        if p.y < ymin do ymin = p.y
        if p.y > ymax do ymax = p.y
        if p.z < zmin do zmin = p.z
        if p.z > zmax do zmax = p.z
    )
    #([xmin, ymin, zmin], [xmax, ymax, zmax])
)

-- Возвращает bitArray с гранями верхней/нижней плоской крышки меша m (мировые координаты)
fn REMS_findCapFaces m useTop: = (
    local nf = m.numFaces
    local bits = #{}
    if nf > 0 do (
        bits.count = nf
        local zs = #()
        local fs = #()
        for f = 1 to nf do (
            local nrm = normalize (getFaceNormal m f)
            if (abs nrm.z) > 0.9 do (
                local vs = getFace m f
                local c = ((getVert m vs[1]) + (getVert m vs[2]) + (getVert m vs[3])) / 3.0
                append zs c.z
                append fs f
            )
        )
        if fs.count > 0 do (
            local bestZ = if useTop then amax zs else amin zs
            local bb = REMS_meshBBox m
            local diag = length (bb[2] - bb[1])
            local tol = amax #(diag * 0.0001, 0.000001)
            for i = 1 to fs.count do (
                if (abs (zs[i] - bestZ)) <= tol do bits[fs[i]] = true
            )
        )
    )
    bits
)

/* --------------------
--
-- Построение контура крышки
--
*/ --------------------

struct REMS_EdgeRec (k, a, b)

fn REMS_edgeRecCmp x y = (
    if x.k < y.k then -1 else if x.k > y.k then 1 else 0
)

-- Граничные рёбра набора граней: рёбра, встречающиеся в наборе один раз.
-- Направление берётся по порядку вершин грани (для обхода контура).
fn REMS_collectBoundaryEdges m faceBits = (
    local stride = m.numVerts + 1
    local recs = #()
    for f in faceBits do (
        local vs = getFace m f
        for i = 1 to 3 do (
            local a = vs[i]
            local b = if i == 3 then vs[1] else vs[i + 1]
            append recs (REMS_EdgeRec k:(((amin #(a, b)) * stride) + (amax #(a, b))) a:a b:b)
        )
    )
    qsort recs REMS_edgeRecCmp
    local fromArr = #()
    local toArr = #()
    local i = 1
    while i <= recs.count do (
        if i < recs.count and recs[i + 1].k == recs[i].k then (
            -- внутреннее ребро: пропускаем все дубликаты
            local k0 = recs[i].k
            while i <= recs.count and recs[i].k == k0 do i += 1
        ) else (
            append fromArr recs[i].a
            append toArr recs[i].b
            i += 1
        )
    )
    #(fromArr, toArr)
)

-- Сшивает направленные граничные рёбра в замкнутые петли (массивы индексов вершин)
fn REMS_traceLoops nv fromArr toArr = (
    local ne = fromArr.count
    local loops = #()
    if ne >= 3 do (
        local firstEdgeOf = for i = 1 to nv collect 0
        local nextSame = for i = 1 to ne collect 0
        for i = 1 to ne do (
            nextSame[i] = firstEdgeOf[fromArr[i]]
            firstEdgeOf[fromArr[i]] = i
        )
        local used = for i = 1 to ne collect false
        for s = 1 to ne do (
            if used[s] do continue
            used[s] = true
            local start = fromArr[s]
            local pts = #(start)
            local cur = toArr[s]
            local closed = false
            for guard = 1 to (ne + 1) do (
                if cur == start do (closed = true; exit)
                append pts cur
                local nxt = 0
                local e = firstEdgeOf[cur]
                while e > 0 do (
                    if not used[e] then (nxt = e; exit)
                    e = nextSame[e]
                )
                if nxt == 0 do exit
                used[nxt] = true
                cur = toArr[nxt]
            )
            if closed and pts.count >= 3 then append loops pts
            else if not closed do format "REMS: незамкнутый контур отброшен (% точек)\n" pts.count
        )
    )
    loops
)

-- Переводит петли вершин в мировые точки, убирая повторы подряд ближе tol
fn REMS_loopsToWorldPoints m loops tol = (
    local res = #()
    for lp in loops do (
        local pts = for vi in lp collect (getVert m vi)
        local clean = #(pts[1])
        for i = 2 to pts.count do (
            if distance pts[i] clean[clean.count] > tol do append clean pts[i]
        )
        if clean.count >= 2 and (distance clean[clean.count] clean[1]) <= tol do deleteItem clean clean.count
        if clean.count >= 3 do append res clean
    )
    res
)

-- Создает SplineShape в мировых координатах (трансформация узла - единичная)
fn REMS_makeSplineShape loopsP nodeName = (
    local ss = SplineShape()
    ss.name = nodeName
    ss.steps = 12
    for lp in loopsP do (
        local si = addNewSpline ss
        for p in lp do addKnot ss si #corner #curve p
        close ss si
    )
    updateShape ss
    ss
)

/* --------------------
--
-- Автоупрощение через Simplify-Spline.ms
--
*/ --------------------

-- Загрузка скрипта упрощения: его точки входа run_rebuildArcs/run_simplifySpline
-- становятся глобальными после fileIn
fn REMS_loadSimplifyScript = (
    if run_simplifySpline == undefined or run_rebuildArcs == undefined do (
        local scriptPath = (getDir #userScripts) + "\\Simplify-Spline.ms"
        if not doesFileExist scriptPath do scriptPath = "Simplify-Spline.ms"
        fileIn scriptPath
    )
)

/*
Упрощение всех сплайнов объекта через точки входа Simplify-Spline.ms:
1) run_rebuildArcs   - восстановление дуг (заполняет SS_ARC_PROTECTED);
2) run_simplifySpline - сокращение вершин с учётом защиты дуг.
Обе функции рассчитаны на ручной запуск, поэтому предварительно выставляется
то же состояние UI: объект один в выделении, панель Modify на базовом объекте,
уровень подобъектов 3 (сплайны), выделены все сплайны формы.
*/
fn REMS_autoSimplify ss loopsP = (
    -- Возвращает #(okFlag, ss) - узел может быть ПЕРЕСОЗДАН внутри функции.
    -- Их run_rebuildArcs/run_simplifySpline содержат собственные undo-блоки;
    -- исключение внутри них откатывает запись и уничтожает узел сплайна
    -- (воспроизводится в Max 2026). При гибели узла он пересоздаётся из
    -- исходных точек loopsP, после чего упрощение повторяется один раз
    -- без этапа дуг (дуги - необязательное улучшение качества).
    local okFlag = false
    local nameBase = ss.name
    local attempt = 1
    while true do (
        local simpOk = true
        try (
            REMS_loadSimplifyScript()
            clearSelection()
            select ss
            max modify mode
            modPanel.setCurrentObject ss.baseobject
            undo "REMS arcs+simplify" on (
                if attempt == 1 then (
                    try (
                        run_rebuildArcs()
                    ) catch (
                        format "REMS: восстановление дуг прервано: % (продолжаем без дуг)\n" (getCurrentException())
                    )
                )
                if isValidNode ss then (
                    -- в этой версии setSplineSelection требует массив индексов, а не bitArray
                    local allSplines = for s = 1 to numSplines ss collect s
                    setSplineSelection ss allSplines
                    try (
                        run_simplifySpline()
                    ) catch (
                        simpOk = false
                        format "REMS: упрощение прервано: %\n" (getCurrentException())
                    )
                ) else (
                    simpOk = false
                )
            )
        ) catch (
            simpOk = false
            local nm = "<узел удалён>"
            try (nm = ss.name) catch ()
            format "REMS: попытка %: ошибка при упрощении '%': %\n" attempt nm (getCurrentException())
        )
        if not (isValidNode ss) then (
            format "REMS: узел удалён при упрощении (попытка %) - пересоздаю из исходных точек\n" attempt
            ss = REMS_makeSplineShape loopsP (uniqueName nameBase)
        ) else if simpOk do (
            okFlag = true
        )
        if okFlag or (isValidNode ss) or attempt >= 2 do exit
        attempt += 1
        format "REMS: повторяю упрощение без этапа дуг (попытка 2)\n"
    )
    #(okFlag, ss)
)

/* --------------------
--
-- Обработка одного объекта
--
*/ --------------------

fn REMS_processObject obj useTop: doSimplify:true = (
    local created = #()
    format "REMS: '%' ...\n" obj.name
    local m = snapshotAsMesh obj
    local faceBits = REMS_findCapFaces m useTop:useTop
    if faceBits.isEmpty then (
        format "REMS: '%': не найдены горизонтальные грани крышки - пропуск\n" obj.name
    ) else (
        local edges = REMS_collectBoundaryEdges m faceBits
        local fromArr = edges[1]
        local toArr = edges[2]
        if fromArr.count == 0 then (
            format "REMS: '%': у крышки нет границы - пропуск\n" obj.name
        ) else (
            local loopsV = REMS_traceLoops m.numVerts fromArr toArr
            if loopsV.count == 0 then (
                format "REMS: '%': контур крышки не построен - пропуск\n" obj.name
            ) else (
                local bb = REMS_meshBBox m
                local diag = length (bb[2] - bb[1])
                local loopsP = REMS_loopsToWorldPoints m loopsV (amax #(diag * 0.00001, 0.000001))
                if loopsP.count == 0 then (
                    format "REMS: '%': контур короче 3 точек - пропуск\n" obj.name
                ) else (
                    local knotsBefore = 0
                    for lp in loopsP do knotsBefore += lp.count
                    -- имя запоминаем сразу: обращения к .name возможны только у живого узла
                    local ssName = uniqueName (obj.name + "_spline")
                    local ss = REMS_makeSplineShape loopsP ssName
                    -- упрощение: только если doSimplify=true (Ctrl зажат при запуске)
                    local simplifyOk = true
                    if doSimplify then (
                        local simpRes = REMS_autoSimplify ss loopsP
                        simplifyOk = simpRes[1]
                        ss = simpRes[2]
                    ) else (
                        format "REMS: '%': упрощение пропущено (Ctrl не зажат)\n" obj.name
                    )
                    -- наследование слоя
                    local layerOk = false
                    try (
                        obj.layer.addNode ss
                        layerOk = (ss.layer.name == obj.layer.name)
                        if not layerOk do format "REMS: '%': слой не совпал (%)\n" ssName ss.layer.name
                    ) catch (
                        format "REMS: '%': не удалось назначить слой: %\n" ssName (getCurrentException())
                    )
                    -- наследование группы (родитель - голова группы); мировая трансформация остаётся единичной,
                    -- точки сплайна заданы в мировых координатах, геометрия не смещается
                    local groupOk = true
                    local grpHead = undefined
                    if isGroupMember obj do grpHead = obj.parent
                    if grpHead == undefined do (
                        try (if obj.parent != undefined and isGroupHead obj.parent do grpHead = obj.parent) catch ()
                    )
                    if grpHead != undefined then (
                        try (
                            attachNodesToGroup #(ss) grpHead
                            groupOk = isGroupMember ss
                            if not groupOk do format "REMS: '%': объект не включён в группу '%'\n" ssName grpHead.name
                        ) catch (
                            groupOk = false
                            format "REMS: '%': не удалось включить в группу: %\n" ssName (getCurrentException())
                        )
                    ) else (
                        format "REMS: '%': исходник не состоит в группе - наследовать нечего\n" obj.name
                    )
                    local h = 0.0
                    local exAdded = false
                    if not (isValidNode ss) then (
                        format "REMS: '%': сплайн был удалён в процессе упрощения - исходник сохранён\n" obj.name
                    ) else (
                    -- пивот в центр bounding box сплайна (до Extrude);
                    -- точки сплайна заданы в мировых координатах, присваивание .pivot
                    -- смещает только пивот, геометрия и направление экструзии не меняются
                    local kpts = #()
                    for s = 1 to numSplines ss do
                        for k = 1 to numKnots ss s do append kpts (getKnotPoint ss s k)
                    if kpts.count > 0 do (
                        local kmn = kpts[1], kmx = kpts[1]
                        for p in kpts do (
                            kmn = [amin #(kmn.x, p.x), amin #(kmn.y, p.y), amin #(kmn.z, p.z)]
                            kmx = [amax #(kmx.x, p.x), amax #(kmx.y, p.y), amax #(kmx.z, p.z)]
                        )
                        ss.pivot = (kmn + kmx) / 2.0
                    )
                    h = bb[2].z - bb[1].z
                    -- Extrude добавляем защищенно: сбой опции не должен отменять модификатор
                    try (
                        local ex = Extrude()
                        ex.amount = if useTop then (-h) else h
                        ex.mapcoords = true
                        ex.realWorldMapSize = true
                        addModifier ss ex
                        for mo in ss.modifiers where (classOf mo) == Extrude do exAdded = true
                    ) catch (
                        format "REMS: ошибка Extrude '%': %\n" ssName (getCurrentException())
                    )
                    if not exAdded do format "REMS: '%': Extrude НЕ ДОБАВЛЕН\n" ssName
                    try (ss.renderable = false) catch ()
                    try (ss.material = obj.material) catch ()
                    local knotsAfter = 0
                    for s = 1 to numSplines ss do knotsAfter += numKnots ss s
                    append created ss
                    format "REMS: '%': петель=% вершины %->% высота=% упрощение=% extrude=% слой=% группа=%\n" ssName loopsP.count knotsBefore knotsAfter h \
                        (if simplifyOk then "ok" else "ошибка") (if exAdded then "ok" else "НЕТ") \
                        (if layerOk then "ok" else "НЕТ") (if groupOk then "ok" else "НЕТ")
                    )
                    -- удаление исходника только при полном успехе
                    -- (имя запоминаем заранее: у удалённого узла читать .name нельзя)
                    local srcName = obj.name
                    -- удаление исходника: критично только построение сплайна и Extrude;
                    -- сбой наследования слоя/группы не должен блокировать удаление
                    local fullOk = simplifyOk and exAdded
                    if not fullOk then (
                        format "REMS: '%': исходник НЕ удалён (упрощение=% extrude=% слой=% группа=%)\n" \
                            srcName simplifyOk exAdded layerOk groupOk
                    ) else (
                        if REMS_deleteSourceObjects then (
                            try (
                                delete obj
                                format "REMS: исходник '%' удалён\n" srcName
                            ) catch (
                                format "REMS: '%': не удалось удалить исходник: %\n" srcName (getCurrentException())
                            )
                        ) else (
                            format "REMS: '%': исходник оставлен (REMS_deleteSourceObjects=false)\n" srcName
                        )
                    )
                )
            )
        )
    )
    created
)

/* --------------------
--
-- Точка входа
--
*/ --------------------

fn run_rebuildExtrudedMeshToSpline = (
    -- развернуть выделение: если выбрана голова группы, взять её содержимое
    local picked = #()
    for o in selection do (
        append picked o
        try (if o.isGroupHead do join picked o.children) catch ()
    )
    local geoObjs = #()
    for o in picked where (superClassOf o) == GeometryClass do
        if (findItem geoObjs o) == 0 do append geoObjs o
    if geoObjs.count == 0 then (
        messageBox "Выделите объекты-геометрию для обработки." title:"Rebuild Extruded Mesh to Spline"
    ) else (
        local useTop = keyboard.shiftPressed
        local doSimplify = not keyboard.controlPressed
        format "REMS: режим %, упрощение=%, объектов: %, REMS_deleteSourceObjects=%\n" \
            (if useTop then "верхняя крышка (экструзия вниз)" else "нижняя крышка (экструзия вверх)") \
            (if doSimplify then "вкл" else "выкл") \
            geoObjs.count REMS_deleteSourceObjects
        local created = #()
        undo "Rebuild Extruded Mesh to Spline" on (
            for o in geoObjs do (
                if not (isValidNode o) do continue -- пропустить уже удалённые
                local newOnes = #()
                try (newOnes = REMS_processObject o useTop:useTop doSimplify:doSimplify) catch (
                    local nm = "<удалён>"
                    try (nm = o.name) catch ()
                    format "REMS: ошибка обработки '%': %\n" nm (getCurrentException())
                )
                join created newOnes
            )
        )
        if created.count > 0 do (
            clearSelection()
            select created
        )
        redrawViews()
        format "REMS: готово. Обработано объектов: %, создано сплайнов: %\n" geoObjs.count created.count
    )
    OK
)

    on isEnabled do selection.count > 0
    on execute do run_rebuildExtrudedMeshToSpline()
)
