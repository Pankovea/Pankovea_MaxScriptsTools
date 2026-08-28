/* Rebuild-Mesh-to-Extruded-Spline - 2025.08.25 alpha

Скрипт для восстановления исходного состояния импортированных мешей,
которые изначально были сплайнами, выдавленными модификатором Extrude.

Работает по всем выделенным объектам-геометрии:

1. Определяет ось выдавливания:
   - по умолчанию (без Shift) - мировая +Z (плита);
   - при зажатом Shift - горизонтальная ось, вдоль которой объект наименьший
     (толщина стены) - стена. Для каждого объекта ось вычисляется по своим габаритам.
2. Выбирает базовую сторону вдоль этой оси (направление выдавливания):
   - без Alt - МИНИМАЛЬНАЯ поверхность объекта вдоль оси;
   - с Alt    - МАКСИМАЛЬНАЯ.
   Базовая сторона вычисляется для каждого объекта отдельно.
3. Универсальный механизм для любой оси выдавливания:
   3.1 на базовой стороне собирает все грани, перпендикулярные оси (нормаль
       может смотреть в любую сторону вдоль оси);
   3.2 по границе этих граней строит замкнутый сплайн: внешний контур
       приводится к положительному обходу вдоль оси, проёмы (внутренние петли)
       разворачиваются в противоположный обход и становятся отверстиями;
       сплайн строится в локальной системе профиля (оси u, v лежат в плоскости,
       z - ось выдавливания), узел получает трансформацию, переводящую её в
       мировые координаты;
   3.3 величина Extrude - протяжённость объекта вдоль оси выдавливания
       (высота по Z либо толщина стены); выбор базовой стороны влияет на
       результат, если две стороны объекта различаются.
4. При зажатом Ctrl запускает автоматическую обработку скриптом
   scripts\Simplify-Spline.ms:
   run_rebuildArcs (восстановление дуг) -> run_simplifySpline (сокращение вершин
   с защитой границ дуг). Перед вызовами выставляется состояние UI,
   ожидаемое этими функциями: объект один в выделении, Modify-панель
   на базовом объекте, уровень подобъектов - сплайны.
5. Вешает на сплайн модификатор Extrude:
   - без Alt - положительная величина (как +Z): выдавливание от базовой
     стороны в положительную сторону оси;
   - с Alt    - отрицательная (как -Z): выдавливание в отрицательную сторону.

Ось, направление и упрощение выбираются так:
- обычный запуск                 - плита: ось +Z, базовая сторона минимальная, экструзия вверх;
- зажатый Shift                  - стена: ось выдавливания горизонтальная, вдоль
                                   минимальной протяжённости объекта;
- зажатый Alt                    - направление выдавливания: базовая сторона
                                   максимальная, экструзия вниз;
- зажатый Ctrl                   - включить упрощение сплайна;
- Shift + Alt + Ctrl             - комбинации допустимы.

Отмена: при работе с несколькими объектами ход выполнения показывается
в прогресс-баре; нажатие Esc останавливает обработку и откатывает ВСЕ
изменения текущего прогона (созданные сплайны удаляются, исходники восстанавливаются).

Слой и принадлежность к группе наследуются от исходного объекта.
Исходный объект удаляется, как только готов сплайн с Extrude; сбой упрощения
сплайна или наследования слоя/группы удаление не отменяет (исходник и результат
не должны существовать одновременно).
Чтобы оставлять исходные объекты, установите в Listener'е перед запуском:
    REMS_deleteSourceObjects = false

Результат: объект SplineShape (трансформ без масштаба) + модификатор Extrude.
Материал заимствуется с исходного объекта. В Extrude по умолчанию включены
Generate Mapping Coords и Real-World Map Size.

Ограничения:
- по умолчанию обрабатываются объекты, выдавленные вдоль мировой оси Z;
  стены (горизонтальное выдавливание) обрабатываются с зажатым Shift;
- обрабатывается один профиль на объект: одна базовая сторона;
- базовая сторона должна быть плоской и перпендикулярной оси выдавливания
  (допускается набор компланарных фрагментов - так сохраняются проёмы);
- в режиме стены ось определяется по наименьшей горизонтальной протяжённости.

Использование:
- выделить меши и запустить макрос "Rebuild Extruded Mesh to Spline"
  (категория "PankovEA Scripts"), либо выполнить run_rebuildExtrudedMeshToSpline().
*/

macroScript REMS_RebuildMeshToExtrudedSpline
    category:"#PankovScripts"
    buttonText:"Rebuild Mesh to Extruded Spline"
    tooltip:"Rebuild Mesh to Extruded Spline\n\nShift - стена (горизонтальная ось),\nAlt - направление выдавливания,\nCtrl - упрощение: вкл/выкл"
    autoUndoEnabled:false
    icon: #("Standard_Modifiers", 13)
(

global REMS_deleteSourceObjects = true -- false - оставлять исходные объекты

/* --------------------
--
-- Профиль на базовой стороне (универсально для любой оси выдавливания)
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

-- Ось выдавливания объекта: без Shift - мировая +Z (плита); с Shift - горизонтальная
-- ось, вдоль которой объект наименьший (стена выдавливается по толщине).
fn REMS_pickExtrusionAxis m wall: = (
    if not wall then [0,0,1] else (
        local bb = REMS_meshBBox m
        if (bb[2].x - bb[1].x) <= (bb[2].y - bb[1].y) then [1,0,0] else [0,1,0]
    )
)

-- Грани базовой стороны: перпендикулярные оси dir (нормаль может смотреть
-- в любую сторону вдоль оси) и лежащие в плоскости (dot dir p) = dRef
-- (допуск tolD). Собираются все компланарные фрагменты, не требуя связности -
-- так сохраняются проёмы. Возвращает bitArray индексов граней.
fn REMS_gatherCapFaces m dir dRef tolD = (
    local bits = #{}
    bits.count = m.numFaces
    for f = 1 to m.numFaces do (
        local fnrm = normalize (getFaceNormal m f)
        if (abs (dot fnrm dir)) < 0.9 do continue
        if (abs ((dot dir (getVert m ((getFace m f)[1]))) - dRef)) > tolD do continue
        bits[f] = true
    )
    bits
)

-- Ориентация петель профиля: внешний контур (максимальная площадь) приводится к
-- положительному обходу вдоль оси n, проёмы остаются/разворачиваются в
-- противоположный обход (становятся отверстиями при экструзии).
-- Возвращает #(петли, предупреждениеФлаг).
fn REMS_loopsOrient loopsP n = (
    local flag = false
    -- подписанные площади контуров вдоль оси n
    local areas = #()
    for lp in loopsP do (
        local a = [0,0,0]
        for i = 1 to (lp.count - 1) do a += (cross lp[i] lp[i + 1])
        a += (cross lp[lp.count] lp[1])
        append areas (dot a n)
    )
    local outer = 1
    for i = 2 to areas.count do if (abs areas[i]) > (abs areas[outer]) do outer = i
    for i = 1 to areas.count do
        if i != outer and (abs areas[i]) >= 0.9 * (abs areas[outer]) do flag = true
    local signO = if areas[outer] >= 0 then 1 else -1
    local oriented = #()
    for i = 1 to loopsP.count do (
        if i == outer or (areas[i] * signO) < 0 then (
            append oriented loopsP[i]
        ) else (
            local rp = for j = loopsP[i].count to 1 by -1 collect loopsP[i][j]
            append oriented rp
        )
    )
    -- если внешний контур при взгляде с +n обходится по часовой стрелке
    -- (отрицательная площадь), разворачиваем ВСЕ контуры: внешний становится
    -- положительным, проёмы остаются противоположными
    local acc = [0,0,0]
    local lpO = oriented[outer]
    for i = 1 to (lpO.count - 1) do acc += (cross lpO[i] lpO[i + 1])
    acc += (cross lpO[lpO.count] lpO[1])
    if (dot acc n) < 0 do
        oriented = for lp in oriented collect (for j = lp.count to 1 by -1 collect lp[j])
    #(oriented, flag)
)

-- Перевод мировых точек петель в локальную систему {u, v} плоскости профиля (z=0).
fn REMS_loopsProject loopsW u v o = (
    for lp in loopsW collect (
        for p in lp collect ([(dot u (p - o)), (dot v (p - o)), 0])
    )
)

/* --------------------
--
-- Построение контура крышки
--
*/ --------------------

-- Направленное граничное ребро меша:
--   key   - ключ НЕОРИЕНТИРОВАННОГО ребра: один и тот же для двух граней,
--           разделяющих ребро (позволяет найти повторы и отсеять внутренние);
--   vFrom - индекс вершины, где ребро начинается (по порядку обхода грани);
--   vTo   - индекс вершины, где ребро заканчивается (направление контура).
struct REMS_EdgeRec (key, vFrom, vTo)

fn REMS_edgeRecKeyCmp x y = (
    if x.key < y.key then -1 else if x.key > y.key then 1 else 0
)

-- Граничные рёбра набора граней: рёбра, встречающиеся в наборе один раз.
-- Направление берётся по порядку вершин грани (для обхода контура).
fn REMS_collectBoundaryEdges m faceBits = (
    local stride = m.numVerts + 1
    local recs = #()
    for f in faceBits do (
        local vs = getFace m f
        for i = 1 to 3 do (
            local vStart = vs[i]
            local vEnd = if i == 3 then vs[1] else vs[i + 1]
            -- ключ неориентированного ребра не зависит от порядка концов
            local key = ((amin #(vStart, vEnd)) * stride) + (amax #(vStart, vEnd))
            append recs (REMS_EdgeRec key:key vFrom:vStart vTo:vEnd)
        )
    )
    qsort recs REMS_edgeRecKeyCmp
    local edgeFrom = #()
    local edgeTo = #()
    local i = 1
    while i <= recs.count do (
        if i < recs.count and recs[i + 1].key == recs[i].key then (
            -- внутреннее ребро: ключ дублируется (его разделяют две грани);
            -- пропускаем все дубликаты
            local k0 = recs[i].key
            while i <= recs.count and recs[i].key == k0 do i += 1
        ) else (
            append edgeFrom recs[i].vFrom
            append edgeTo recs[i].vTo
            i += 1
        )
    )
    #(edgeFrom, edgeTo)
)

-- Сшивает направленные граничные рёбра в замкнутые петли (массивы индексов вершин).
-- edgeFrom[e] / edgeTo[e] - начало и конец e-го граничного ребра.
fn REMS_traceLoops nv edgeFrom edgeTo = (
    local nEdges = edgeFrom.count
    local loopsV = #()
    if nEdges >= 3 do (
        -- связные списки рёбер по их начальным вершинам:
        -- firstEdgeAt[v] - индекс первого ребра, выходящего из вершины v;
        -- nextEdgeAt[e]  - индекс следующего ребра с тем же началом, что у ребра e
        local firstEdgeAt = for i = 1 to nv collect 0
        local nextEdgeAt = for i = 1 to nEdges collect 0
        for i = 1 to nEdges do (
            nextEdgeAt[i] = firstEdgeAt[edgeFrom[i]]
            firstEdgeAt[edgeFrom[i]] = i
        )
        local usedEdge = for i = 1 to nEdges collect false
        for e = 1 to nEdges do (
            if usedEdge[e] do continue
            usedEdge[e] = true
            local startV = edgeFrom[e]
            local pts = #(startV)
            local curV = edgeTo[e]
            local closed = false
            for guard = 1 to (nEdges + 1) do (
                if curV == startV do (closed = true; exit)
                append pts curV
                local nextE = 0
                local en = firstEdgeAt[curV]
                while en > 0 do (
                    if not usedEdge[en] then (nextE = en; exit)
                    en = nextEdgeAt[en]
                )
                if nextE == 0 do exit
                usedEdge[nextE] = true
                curV = edgeTo[nextE]
            )
            if closed and pts.count >= 3 then append loopsV pts
            else if not closed do format "REMS: незамкнутый контур отброшен (% точек)\n" pts.count
        )
    )
    loopsV
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

-- Создает SplineShape в локальной системе сплайна (для Z-режима локальная
-- система совпадает с мировой, tmFacade единичная). Трансформация узла
-- tmFacade отображает локальные точки в мировые координаты.
fn REMS_makeSplineShape loopsP nodeName tmFacade:(matrix3 1) = (
    local ss = SplineShape()
    ss.name = nodeName
    ss.steps = 12
    for lp in loopsP do (
        local si = addNewSpline ss
        for p in lp do addKnot ss si #corner #curve p
        close ss si
    )
    updateShape ss
    ss.transform = tmFacade
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
fn REMS_autoSimplify ss loopsP tmFacade:(matrix3 1) = (
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
            ss = REMS_makeSplineShape loopsP (uniqueName nameBase) tmFacade:tmFacade
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

fn REMS_processObject obj useMaxSide: doSimplify:true wall:false = (
    local created = #()
    format "REMS: '%' (режим=%)\n" obj.name (if wall then "стена (Shift): ось горизонтальная" else "плита: ось Z")
    local m = snapshotAsMesh obj
    local bb = REMS_meshBBox m
    local diag = length (bb[2] - bb[1])
    -- петли в локальной системе сплайна
    local loopsP = #()
    local tmFacade = matrix3 1
    local extrudeAmount = 0.0

    -- ---- универсальный механизм для ЛЮБОЙ оси выдавливания ----
    -- ось определяется по режиму и габаритам объекта
    local dir = REMS_pickExtrusionAxis m wall:wall
    -- экстремумы вдоль оси - минимальная и максимальная базовая сторона объекта
    local tMin = 1e30
    local tMax = -1e30
    local vMin = 1
    local vMax = 1
    for vx = 1 to m.numVerts do (
        local dc = dot (getVert m vx) dir
        if dc < tMin do (tMin = dc; vMin = vx)
        if dc > tMax do (tMax = dc; vMax = vx)
    )
    -- базовая сторона (направление выдавливания): без Alt - минимальная, с Alt - максимальная
    local baseP = getVert m (if useMaxSide then vMax else vMin)
    local capBits = REMS_gatherCapFaces m dir (dot dir baseP) (diag * 0.0002 + 1e-4)
    if capBits.isEmpty then (
        format "REMS: '%': не найдены грани на базовой стороне по оси % - пропуск\n" obj.name (if wall then dir else "Z")
    ) else (
        local edges = REMS_collectBoundaryEdges m capBits
        if edges[1].count > 0 then (
            local loopsV = REMS_traceLoops m.numVerts edges[1] edges[2]
            local loopsW = REMS_loopsToWorldPoints m loopsV (amax #(diag * 0.00001, 0.000001))
            if loopsW.count > 0 then (
                -- внешний контур - по максимальной площади; проёмы - в обратном обходе;
                -- внешний контур приводится к положительному обходу вдоль оси (как +Z)
                local orientRes = REMS_loopsOrient loopsW dir
                loopsW = orientRes[1]
                if orientRes[2] do (
                    format "REMS: '%': петли сопоставимой площади - возможно это боковая поверхность, а не грань\n" obj.name
                )
                -- локальная система профиля: u, v лежат в плоскости, z - ось выдавливания
                local u = if (abs dir.z) < 0.9 then normalize (cross [0,0,1] dir) else [1,0,0]
                local v = cross dir u
                tmFacade = matrix3 u v dir baseP
                loopsP = REMS_loopsProject loopsW u v baseP
                -- без Alt выдавливание в положительную сторону оси (как +Z),
                -- с Alt - в отрицательную (как -Z); величина = протяжённость по оси
                extrudeAmount = if useMaxSide then (-(tMax - tMin)) else (tMax - tMin)
            ) else (
                format "REMS: '%': контур не построен - пропуск\n" obj.name
            )
        ) else (
            format "REMS: '%': на базовой стороне нет границы - пропуск\n" obj.name
        )
    )

    if loopsP.count > 0 do (
        local knotsBefore = 0
        for lp in loopsP do knotsBefore += lp.count
        -- имя запоминаем сразу: обращения к .name возможны только у живого узла
        local ssName = uniqueName (obj.name + "_spline")
        local ss = REMS_makeSplineShape loopsP ssName tmFacade:tmFacade
        -- упрощение: только если doSimplify=true (Ctrl зажат при запуске)
        local simplifyOk = true
        if doSimplify then (
            local simpRes = REMS_autoSimplify ss loopsP tmFacade:tmFacade
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
        -- наследование группы (родитель - голова группы); точки сплайна заданы в локальных
        -- координатах, трансформация узла переводит их в мировые, геометрия не смещается
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
        local h = abs extrudeAmount
        local exAdded = false
        if not (isValidNode ss) then (
            format "REMS: '%': сплайн был удалён в процессе упрощения - исходник сохранён\n" obj.name
        ) else (
        -- пивот в центр bounding box сплайна (до Extrude);
        -- присваивание .pivot смещает только пивот, геометрия и направление экструзии не меняются
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
        -- Extrude добавляем защищенно: сбой опции не должен отменять модификатор
        try (
            local ex = Extrude()
            ex.amount = extrudeAmount
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
        format "REMS: '%': петель=% вершины %->% экструзия=% упрощение=% extrude=% слой=% группа=%\n" ssName loopsP.count knotsBefore knotsAfter h \
            (if simplifyOk then "ok" else "ошибка") (if exAdded then "ok" else "НЕТ") \
            (if layerOk then "ok" else "НЕТ") (if groupOk then "ok" else "НЕТ")
        )
        -- удаление исходника при наличии готового сплайна с Extrude:
        -- (имя запоминаем заранее: у удалённого узла читать .name нельзя)
        local srcName = obj.name
        -- удаление исходника: критично только построение сплайна и Extrude;
        -- сбой упрощения или наследования слоя/группы не должен блокировать
        -- удаление - исходник и результат не должны существовать одновременно
        local fullOk = exAdded
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
        local useWall = keyboard.shiftPressed          -- Shift: стена (горизонтальная ось)
        local useMaxSide = keyboard.altPressed         -- Alt: направление выдавливания (база max)
        local useSimple = not keyboard.controlPressed  -- Ctrl: упрощение вкл/выкл
        format "REMS: режим=%, упрощение=%, объектов: %, REMS_deleteSourceObjects=%\n" \
            ((if useWall then "стена (Shift)" else "плита") + \
                (if useMaxSide then ": база max (экструзия вниз)" else ": база min (экструзия вверх)")) \
            (if useSimple then "вкл" else "выкл") \
            geoObjs.count REMS_deleteSourceObjects
        local created = #()
        local total = geoObjs.count
        local processed = 0
        local cancelled = false
        progressStart ("Rebuild Extruded Mesh to Spline: " + (total as string) + " объектов, Esc - отмена")
        undo "Rebuild Extruded Mesh to Spline" on (
            for o in geoObjs do (
                if not (isValidNode o) do continue
                -- отмена (Esc) проверяется между объектами; откат - общим undo ниже
                if keyboard.escPressed then (cancelled = true; exit)
                local newOnes = #()
                try (newOnes = REMS_processObject o useMaxSide:useMaxSide doSimplify:useSimple wall:useWall) catch (
                    local nm = "<удалён>"
                    try (nm = o.name) catch ()
                    format "REMS: ошибка обработки '%': %\n" nm (getCurrentException())
                )
                join created newOnes
                processed += 1
                progressUpdate (100.0 * processed / total)
                if keyboard.escPressed then (cancelled = true; exit)
            )
        )
        progressEnd()
        if cancelled then (
            -- откат всего прогона одним шагом undo (записи блока выше уже закоммичены)
            undo()
            messageBox "Операция отменена (Esc). Все изменения прогона откатаны." \
                title:"Rebuild Extruded Mesh to Spline"
            format "REMS: отменено пользователем (Esc), изменения прогона откатаны.\n"
        ) else (
            if created.count > 0 do (
                clearSelection()
                select created
            )
            redrawViews()
            format "REMS: готово. Обработано объектов: %, создано сплайнов: %\n" geoObjs.count created.count
        )
    )
    OK
)

    on isEnabled do selection.count > 0
    on execute do run_rebuildExtrudedMeshToSpline()
)
