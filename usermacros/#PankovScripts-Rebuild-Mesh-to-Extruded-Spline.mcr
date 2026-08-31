/* Rebuild-Mesh-to-Extruded-Spline - 2026.08.30 alpha

Скрипт для восстановления исходного состояния импортированных мешей,
которые изначально были сплайнами, выдавленными модификатором Extrude.

Использование:
Customize -> Customize User Interface -> Toolbars -> #PankovScripts
Вынести на панель "Rebuild Mesh to Spline"

Выделить меши (любая геометрия) и нажать на кнопку макроса.
Для именения поведения используйте Shift, Control и Alt.
Если пользовательский интерфейс не заблокирован, то клавиши Control и Alt
могт мешать запустить макрост.
ТОгда нужно заблокировать интерфейс Customize -> Lock UI Layout
Или так: снала нажать на кнопку интерфейса, потом зажать модификационную
клафишу и потом отпустить кнопку мыши.

Особенность этой версии - автоматическое определение оси выдавливания
по РЁБРАМ ПОЛИГОНОВ (Editable Poly): исходник конвертируется в EditPoly,
конвертор сшивает треугольники по скрытым рёбрам в ЛОГИЧЕСКИЕ ПОЛИГОНЫ и
убирает вершины, у которых все рёбра скрытые. Каждое ребро полигона -
граница реальной поверхности, поэтому у гладких тел (круглые колонны)
боковые квады распознаются как стены (ребро вдоль оси + нормаль ⊥ оси),
а рёбра-диагонали триангуляции не засоряют направления/классификацию.
Выбор режима кнопкой Shift не нужен (Shift остаётся только как ПОДСКАЗКА
при вырождении).

Работает по всем выделенным объектам-геометрии:

1. Определяет ось выдавливания:
   1.1 собираются рёбра ПОЛИГОНОВ (границы логических граней; внутренние
       диагонали трианглирования после конвертации в EditPoly исчезают),
       поэтому соприкасающиеся параллельные грани фактически объединены,
       а счёт не раздувается фрагментами одной поверхности;
   1.2 рёбра группируются по направлению (параллельные без учёта знака,
       допуск ~1 градус);
   1.3 в каждой семье считаются ОБРАЗУЮЩИЕ - рёбра, оба конца которых лежат
       на двух крайних плоскостях объекта вдоль направления (допуск 1%
       протяжённости): у двух крышек выдавливания их больше всего, у
       профильных/дуговых рёбер - мало или нет вовсе;
   1.4 побеждает семья с самым большим числом образующих (не меньше 3);
       если максимум разделили НЕ параллельные семьи (прямоугольная коробка,
       плита, колонна, куб) - счёт "в ничью", определение вырождается;
   1.5 в ничьей/неудаче ось берётся по подсказке:
         без Shift - мировая +Z (плита);
         с Shift    - локальная ось наименьшей протяжённости (стена, PCA
                      координат вершин) - корректно при любом наклоне/повороте;
   1.6 ось принимается, если на обеих крайних плоскостях найдены грани
       крышки (нормаль параллельна оси); иначе - следующий шаг.
       Для каждого объекта - свои данные.
2. Базовая сторона (направление выдавливания) и профиль:
   - профиль = грани КРЫШКИ: собираются грани, НОРМАЛЬ которых параллельна оси
     (перпендикулярны плоскости выдавливания), боковые рёбра экструзии
     (нормаль перпендикулярна оси) отбрасываются;
   - из связных островов таких граней выбираются острова БАЗОВОЙ стороны - те,
     чей край вдоль оси лежит на крайней плоскости объекта (по ЦЕНТРОИДАМ граней,
     а не по вершинам: при скошенных торцах «нос»-вершина выступает за плоскость
     крышки, и плоскость по вершинам пуста);
   - профиль = граничные рёбра наборов выбранных островов, сшитые в замкнутые
     петли (внешний контур + петли проёмов);
   - без Alt база - МИНИМАЛЬНАЯ плоскость объекта вдоль оси,
     с Alt - МАКСИМАЛЬНАЯ (направление базовой стороны).
3. Универсальный механизм для любой оси выдавливания:
   3.1 контур крышки приводится к положительному обходу вдоль оси, проёмы
       разворачиваются в противоположный обход и становятся отверстиями;
       сплайн строится в локальной системе профиля, узел получает мировую
       трансформацию;
   3.2 величина Extrude - протяжённость объекта вдоль оси выдавливания.
4. При зажатом Ctrl запускает автоматическую обработку скриптом
   scripts\Simplify-Spline.ms (run_rebuildArcs, затем run_simplifySpline).
5. Вешает на сплайн модификатор Extrude:
    - без Alt - положительная величина (от базы в сторону +оси);
    - с Alt   - отрицательная (от базы в сторону -оси);
    - для ВЕРТИКАЛЬНЫХ элементов (ось = мировая Z) при смене базы действует
      договор на выводе: локальная ось Z сплайна всегда направлена в ПОЛОЖИТЕЛЬНУЮ
      сторону (вверх), а направление вниз задаётся ОТРИЦАТЕЛЬНЫМ Extrude.
      (см. ниже независимое сохранение Material ID крышек и торца).


Управление:
- обычный запуск                 - ось автоматически (по рёбрам полигонов);
                                   при ничьей - +Z;
- зажатый Shift                  - подсказка фолбэка: стена (локальная ось
                                   наименьшей протяжённости, PCA вершин);
- зажатый Alt                    - направление: базовая сторона максимальная;
- зажатый Ctrl                   - включить упрощение сплайна.

Глобальные настройки REMS_* в начале файла

Сохранение Material ID (REMS_preserveMatIDs=true): восстанавливаются MaterialID
верхней крышки, нижней крышки и поверхности выдавливания исходного меша.
Определение верха/низа - по ЛОКАЛЬНОЙ ОСИ Z сплайна (всегда, независимо от знака
выдавливания; при отрицательном extrude верх - это база после разворота).
   - если ID исходника совпадают с дефолтом Extrude (верх=1, низ=2, торец=3) -
     ничего не добавлять, обычный Extrude;
   - если все ID одинаковые - Extrude + модификатор MaterialID (materialID);
   - иначе (свой набор) - вместо Extrude ставится Shell + UVWMap (plane 1 м,
     размер переводится в системные единицы функцией REMS_mmToSys) + UVW Xform
     (tile = 1 / размер в системных). Настройки Shell: overrideMatID/matID (торец),
     overrideInnerMatID/matInnerID (нижняя), overrideOuterMatID/matOuterID (верхняя);
     направления: outerAmount (вверх/+Z), innerAmount (вниз/-Z) по знаку extrude.

Ориентация осей XY к минимальному bbox: для любой оси выдавливания профиль
построения (локальные x,y) обрабатывается выпуклой оболочкой (Andrew's Monotone
Chain) и для каждой грани оболочки вычисляется площадь bounding box; минимум
площади гарантированно достигается со стороной, параллельной одному из рёбер
оболочки, поэтому перебор рёбер даёт точный глобальный минимум направления.
Профиль с почти постоянной площадью по всем углам (круг/квадрат/правильный
многоугольник) считается симметричным и НЕ переориентируется (неоднозначность).
Иначе оси доворачиваются вокруг оси выдавливания до минимума, прилипают к
мировой оси XY в допуске и длинная сторона укладывается в локальную +X.

Пост-коррекция для ГОРИЗОНТАЛЬНЫХ элементов (ось выдавливания в X/Y-плоскости):
после min-bbox длинная сторона сечения укладывается в локальную +X. Но у
горизонтальной плиты/балки/бруса длинная сторона сечения - это ВЫСОТА (вертикаль),
и ей место в Y, а X должен остаться горизонтальной шириной. Поэтому если после
min-bbox первая ось (loc-X) ушла в вертикаль, локальные X и Y меняются местами:
новая X = горизонтальная длинная сторона, Y = вертикаль вверх; ось выдавливания
(loc-Z) при этом не изменяется. Для ВЕРТИКАЛЬНЫХ элементов (ось = мировая Z)
первая ось уже горизонтальна, вторая вертикальна - коррекция не нужна.

Пивот сплайна: локальная ось Z (направление выдавливания) проходит через центр
bbox крышек базы; нижний контур по этой оси (профильная петля с минимальной
проекцией на ось) лежит в плоскости, перпендикулярной оси; пивот - точка
пересечения этой плоскости с осью. Расчёт целиком в мировых координатах
(после упрощения узлы сплайна могут лежать в мировых координатах, а node.pivot
задаётся в мире). При плоской базе пивот совпадает с центром bbox крышек базы.

Отмена: прогресс-бар; Esc останавливает обработку и откатывает ВСЕ изменения
прогона (undo()). Слой и группа наследуются от исходника. Исходник удаляется,
как только готов сплайн с Extrude; чтобы оставлять исходники:
    REMS_deleteSourceObjects = false
При REMS_deleteSourceObjects=false расчёты ведутся по независимой КОПИИ данных,
исходный объект не модифицируется.

Результат: SplineShape (трансформ без масштаба) + Extrude (mapcoords on,
realWorldMapSize on) - или, при своём наборе Material ID, Shell + UVWMap + UVW Xform.
Материал заимствуется с исходного объекта.

Ограничения:
- корректное автоматическое определение оси - для тел, у которых семья
  образующих доминирует: 5+ рёбер в основании, многосоставные основания
  (несколько прямоугольников), окружности, трапециевидные/аркочные профили,
  модифицированные выдавливания;
- прямоугольные коробки/плиты/колонны (низ == верх, все три семьи по
  8 рёбер равной длины) вырождены по счёту - ось по подсказке
  (с Shift - локальная толщина стены, в т.ч. под углом; без Shift - +Z);
- одна базовая сторона на объект (набор компланарных фрагментов - проёмы);
- поверхность второй базы может быть на разной высоте - это не мешает
  определению оси и выбору базы;

*/

macroScript REMS_RebuildMeshToSpline
    category:"#PankovScripts"
    buttonText:"Rebuild Mesh to Spline"
    tooltip:"Rebuild Mesh to Spline\n\nThe axis is determined automatically based on the edges of the polygons (generators).\nShift — wall hint when degenerating,\nAlt — extrusion direction,\nCtrl — simplification off"
    autoUndoEnabled:false
    icon: #("Standard_Modifiers", 13)
(

global REMS_deleteSourceObjects = true -- false - оставлять исходные объекты

global REMS_debug = true -- подробный лог этапов (отборка, крышки, трансформация)

-- Толщина выдавливания: true - ПРОЕКЦИЕЙ всех вершин меша на ось (удалённая
-- точка) - устойчиво к куполам/фасетам/скосам дальней шапки; false (по умолч.) -
-- лучом из пивота до дальней шапки
global REMS_projectionThickness = true

-- Глубина захвата крышек: доля протяжённости объекта вдоль оси выдавливания,
-- в пределах которой остров крышки считается принадлежащим БАЗОВОЙ крышке
-- (допуск tolCap вокруг крайней плоскости tBase). Меньше - захватывается
-- только сама крайняя крышка с её проёмами; больше - дополнительно соседние
-- уступы/полки/ступицы на той же стороне (лишняя крышка легко удаляется вручную,
-- но исходная форма повторяется точнее). 1.0 = вся протяжённость объекта
global REMS_capDepthFrac = 0.15

-- НЕПЛОСКАЯ база (захвачены уступы/полки, профиль имеет разброс по локальному Z):
-- true - корректировать толщину выдавливания на глубину крышки: Extrude удлиняет
-- каждую вершину на extrudeAmount, тело занимает [минZ, максZ+extrudeAmount], а
-- толщина мереется от ЦЕНТРА bbox крышки, поэтому из неё вычитается ПОЛОВИНА
-- разброса Z профиля - итоговый bbox совпадает с ИСХОДНЫМ ГАБАРИТНЫМ КОНТЕЙНЕРОМ
-- объекта; false - оставлять толщину как есть (тело длиннее на пол-глубины)
global REMS_subtractCapDepthFromThickness = true

-- Ориентация осей XY профиля к МИНИМАЛЬНОМУ ограничивающему прямоугольнику
-- (для всех осей выдавливания): строится выпуклая оболочка профильных точек
-- (Andrew's Monotone Chain), считается площадь bbox для каждой грани оболочки,
-- берётся угол стороны рёбра с минимумом площади; затем прилипание к мировой
-- оси {0,90} в допуске REMS_minBBoxAxisSnapTol и длинная сторона укладывается
-- в локальную +X. Если по всем граням оболочки площади примерно ОДИНАКОВЫ
-- (разброс < REMS_minBBoxSymTol) - перед нами круг/квадрат/правильный
-- многоугольник: ориентация НЕ производится (случай/неоднозначность).
global REMS_findMinimalBBox = true

-- Допуск (градусы) прилипания результирующей оси к мировой оси XY {0,90}:
-- у регулярного многоугольника/круга минимумы равноценны, и прилипание
-- даёт детерминированную (не произвольную) ориентацию.
global REMS_minBBoxAxisSnapTol = 2.0

-- Разброс площадей bbox по ГРУБОМУ ПРОХОДУ ВСЕХ углов (0..180, шаг 2°), ниже
-- которого профиль считается симметричным (круг/квадрат/правильный многоугольник)
-- и доворот НЕ делается: у такого профиля площадь почти постоянна (плато).
-- Формула: (aSweepMax - aMin) / aMean < симTol. У вытянутого прямоугольника
-- площадь в промежуточных углах заметно больше минимума, поэтому он всегда
-- проходит мимо этой проверки и ориентируется. 0.03 отсекает окружности с
-- ~32 вершинами и гуще; малоугольные правильные многоугольники попадают под
-- прилипание к мировой оси (детерминизм) без явного пропуска.
global REMS_minBBoxSymTol = 0.03

-- Сохранение Material ID исходного меша при выдавливании:
-- true - восстановить MaterialID верхней/нижней крышки и торца (см. ниже);
-- если ID исходника совпадают с дефолтом Extrude (верх=1, низ=2, торец=3) -
-- ничего не добавлять; все одинаковые - добавляется модификатор MaterialID;
-- иной набор - вместо Extrude ставится Shell + UVWMap + UVW Xform.
-- false - всегда обычный Extrude (как раньше).
global REMS_preserveMatIDs = true
	
/* --------------------
--
-- Профиль на базовой стороне (универсально для любой оси выдавливания)
--
*/ --------------------

-- Габаритный контейнер полигональной геометрии p в мировых координатах
-- (конвертер в EditPoly даёт вершины в координатах входящего меша - мировых):
-- #(minPoint3, maxPoint3)
fn REMS_meshBBox m = (
    local nv = polyop.getNumVerts m
    if nv == 0 do return #([0,0,0], [0,0,0])
    local p0 = polyop.getVert m 1
    local xmin = p0.x
    local xmax = p0.x
    local ymin = p0.y
    local ymax = p0.y
    local zmin = p0.z
    local zmax = p0.z
    for v = 2 to nv do (
        local p = polyop.getVert m v
        if p.x < xmin do xmin = p.x
        if p.x > xmax do xmax = p.x
        if p.y < ymin do ymin = p.y
        if p.y > ymax do ymax = p.y
        if p.z < zmin do zmin = p.z
        if p.z > zmax do zmax = p.z
    )
    #([xmin, ymin, zmin], [xmax, ymax, zmax])
)

/* --------------------
--
-- Ось выдавливания: по РЁБРАМ ПОЛИГОНОВ (Editable Poly)
-- Семья параллельных рёбер с самым большим числом ОБРАЗУЮЩИХ - рёбер,
-- натянутых от крышки к крышке вдоль оси, длиной равной величине экструзии.
--
*/ --------------------

-- Все ВИДИМЫЕ рёбра полигональной геометрии: массив #(длина, направление,
-- точкаA, точкаB). В EditPoly грани - ЛОГИЧЕСКИЕ ПОЛИГОНЫ: внутренние
-- диагонали трианглирования исчезают (конвертер сшивает треугольники по
-- скрытым рёбрам и убирает вершины со всеми скрытыми рёбрами), поэтому
-- КАЖДОЕ ребро полигона - граница поверхности. На гладких телах у боковых
-- квадов появляются ранее скрытые рёбра вдоль оси - именно они нужны для
-- определения оси и удаления стен (полигон = каждой продуктовой грани).
fn REMS_collectVisibleEdges m = (
    local edges = #()
    for e = 1 to (polyop.getNumEdges m) do (
        local ev = polyop.getEdgeVerts m e
        local p1 = polyop.getVert m ev[1]
        local p2 = polyop.getVert m ev[2]
        append edges #(distance p1 p2, normalize (p2 - p1), p1, p2)
    )
    edges
)

-- Число СВЯЗНЫХ ЦЕПОЧЕК в наборе рёбер eList: для голосования оси каждый
-- связный кусок рёбер считается за ОДНО (шаг 2 схемы пользователя: «связанные
-- рёбра считаем за одно»). Ребро = #(длина, направление, точкаA, точкаB).
-- Два ребра связаны, если у них есть общая вершина; вершины отождествляются
-- по точкам (идентичные значения = одна вершина snapshot-меша). Параллельность
-- рёбер одной семьи гарантирует: цепочка - отрезок одной прямой.
fn REMS_countEdgeChains m eList = (
    local vid = Dictionary #string
    local last = 0
    local adj = #()
    for e in eList do (
        for p in #(e[3], e[4]) do (
            local k = (p as string)
            if vid[k] == undefined do (
                last += 1
                vid[k] = last
                append adj #()
            )
        )
        local ia = vid[(e[3] as string)]
        local ib = vid[(e[4] as string)]
        if ia != ib then (
            append adj[ia] ib
            append adj[ib] ia
        )
    )
    local used = for v = 1 to last collect false
    local chains = 0
    for v = 1 to last do (
        if used[v] do continue
        chains += 1
        local stk = #(v)
        used[v] = true
        while stk.count > 0 do (
            local c = stk[stk.count]
            deleteItem stk stk.count
            for nb in adj[c] do if not used[nb] do ( used[nb] = true; append stk nb )
        )
    )
    chains
)

-- Число ОБРАЗУЮЩИХ среди рёбер семьи fam (параллельных d): рёбра, оба конца
-- которых лежат на двух крайних плоскостях объекта вдоль d (допуск tolE) -
-- ребро "натянуто от крышки к крышке". Образующие дуг и профильных рёбер
-- не проходят через обе крайние плоскости.
fn REMS_countSpanningEdges fam d ex tolE = (
    local cnt = 0
    for e in fam do (
        local t1 = dot d e[3]
        local t2 = dot d e[4]
        if (((abs (t1 - ex[1])) <= tolE) and ((abs (t2 - ex[2])) <= tolE)) or \
           (((abs (t1 - ex[2])) <= tolE) and ((abs (t2 - ex[1])) <= tolE)) do cnt += 1
    )
    cnt
)

-- Экстремумы проекций вершин на ось dir: #(tMin, tMax, vMin, vMax)
fn REMS_axisExtremes m dir = (
    local nv = polyop.getNumVerts m
    local tMin = 1e30
    local tMax = -1e30
    local vMin = 1
    local vMax = 1
    for vx = 1 to nv do (
        local dc = dot (polyop.getVert m vx) dir
        if dc < tMin do (tMin = dc; vMin = vx)
        if dc > tMax do (tMax = dc; vMax = vx)
    )
    #(tMin, tMax, vMin, vMax)
)

-- Ось по ВИДИМЫМ рёбрам (шаги 1-2 схемы пользователя):
-- 1) рёбра группируются по направлению (параллельные без учёта знака, tolAng);
-- 2) слова ГОЛОСОВАНИЯ в семье - СВЯЗНЫЕ ЦЕПОЧКИ (REMS_countEdgeChains):
--    связные рёбра считаются за ОДНО; у стены/балки/клина короткие рёбра
--    выдавливания изолированы (по одному), а длинные контурные сливаются в
--    цепочки и проигрывают;
-- 3) ничью по числу цепочек решают ОБРАЗУЮЩИЕ (REMS_countSpanningEdges) -
--    короткие рёбра от крышки до крышки, которых у семьи выдавливания больше;
-- 4) если по паре (цепочки, образующие) победили НЕ параллельные семьи
--    (коробка/плита/колонна/цилиндр вырождены) - ничья, undefined -> подсказка.
fn REMS_pickAxisByEdges m tolAng:0.9998 minCount:3 = (
    local edges = REMS_collectVisibleEdges m
    if edges.count < minCount do return undefined
    local fams = #()  -- #(направление, #(рёбра семьи))
    for e in edges do (
        local d = e[2]
        local found = false
        for fi = 1 to fams.count do
            if (abs (dot d fams[fi][1])) >= tolAng do ( append fams[fi][2] e; found = true; exit )
        if not found do append fams #(d, #(e))
    )
    local ranked = #()  -- #(направление, цепочек, образующих)
    for fam in fams do (
        local ex = REMS_axisExtremes m fam[1]
        local tolE = (ex[2] - ex[1]) * 0.01
        local chains = REMS_countEdgeChains m fam[2]
        local span = REMS_countSpanningEdges fam[2] fam[1] ex tolE
        append ranked #(fam[1], chains, span)
    )
    -- победитель: максимум цепочек, при равенстве - максимум образующих
    local bestDir = ranked[1][1]
    local bestCh = ranked[1][2]
    local bestSp = ranked[1][3]
    for ri = 2 to ranked.count do (
        local ch = ranked[ri][2]
        local sp = ranked[ri][3]
        if (ch > bestCh) or ((ch == bestCh) and (sp > bestSp)) then (
            bestCh = ch
            bestSp = sp
            bestDir = ranked[ri][1]
        )
    )
    if bestCh < 2 do return undefined   -- нужны минимум две цепочки рёбер
    -- ничья: НЕ параллельная семья с теми же (цепочки, образующие)
    for rk in ranked do (
        if (abs (dot rk[1] bestDir)) >= 0.9999 do continue
        if rk[2] == bestCh and rk[3] == bestSp do return undefined
    )
    bestDir
)

-- Ось-подсказка (фолбэк при вырождении/неудаче): без Shift - мировая +Z (плита);
-- с Shift - СТЕНА: локальная ось наименьшей протяжённости (PCA координат вершин).
-- Направление толщины стены, корректно при любом наклоне и повороте объекта.
fn REMS_meshCovarianceRows m = (
    local nv = polyop.getNumVerts m
    local cen = [0,0,0]
    for vx = 1 to nv do cen += polyop.getVert m vx
    cen /= nv as float
    local rows = #([0,0,0], [0,0,0], [0,0,0])
    for vx = 1 to nv do (
        local d = polyop.getVert m vx - cen
        rows[1] += [d.x*d.x, d.x*d.y, d.x*d.z]
        rows[2] += [d.y*d.x, d.y*d.y, d.y*d.z]
        rows[3] += [d.z*d.x, d.z*d.y, d.z*d.z]
    )
    rows
)

-- Доминантная ось ковариации (степенная итерация по строкам 3x3)
fn REMS_covDominantAxis rows seed = (
    local v = normalize seed
    for it = 1 to 40 do (
        local w = [dot rows[1] v, dot rows[2] v, dot rows[3] v]
        local wl = length w
        if wl > 1e-12 do v = w / wl
    )
    v
)

-- Пара #(ось, собственное значение)
fn REMS_covEigen rows seed = (
    local v = REMS_covDominantAxis rows seed
    local cv = [dot rows[1] v, dot rows[2] v, dot rows[3] v]
    #(v, dot v cv)
)

-- Локальная ось наименьшей протяжённости: третья главная компонента
-- (минимум дисперсии вершин) = толщина стенки/стены. Две доминантные оси
-- берутся как максимум собственного значения среди стартовых осей, чтобы
-- не "застревать" на точно осевом боксе.
fn REMS_meshMinorAxis m = (
    local rows = REMS_meshCovarianceRows m
    local seeds = #([1,0,0], [0,1,0], [0,0,1])
    local best1 = undefined
    for s in seeds do (
        local e = REMS_covEigen rows s
        if best1 == undefined or e[2] > best1[2] do best1 = e
    )
    local v1 = best1[1]
    local defl = #([0,0,0], [0,0,0], [0,0,0])
    for i = 1 to 3 do for j = 1 to 3 do (
        defl[i][j] = rows[i][j] - best1[2] * v1[i] * v1[j]
    )
    local best2 = undefined
    for s in seeds do (
        local e = REMS_covEigen defl s
        if best2 == undefined or e[2] > best2[2] do best2 = e
    )
    cross v1 best2[1]
)

fn REMS_pickFallbackAxis m wall: = (
    if not wall then [0,0,1] else (
        local ax = REMS_meshMinorAxis m
        if (length ax) < 1e-9 then [1,0,0] else normalize ax
    )
)

-- Центроид ПОЛИГОНА (среднее вершин логической грани)
fn REMS_faceCentroid m f = (
    local vs = polyop.getFaceVerts m f
    local acc = [0,0,0]
    for v in vs do acc += polyop.getVert m v
    acc / (vs.count as float)
)

-- Экстремумы проекций ЦЕНТРОИДОВ ПОЛИГОНОВ на ось dir: #(tMin, tMax, fMin, fMax).
-- Крышка - крайний слой ГРАНЕЙ: экстремальная ВЕРШИНА может выступать за плоскость
-- крышки (скошенные/составные торцы), а центроид крайней грани лежит на ней точно.
fn REMS_faceCentroidExtremes m dir = (
    local nf = polyop.getNumFaces m
    local tMin = 1e30
    local tMax = -1e30
    local fMin = 1
    local fMax = 1
    for f = 1 to nf do (
        local d = dot dir (REMS_faceCentroid m f)
        if d < tMin do (tMin = d; fMin = f)
        if d > tMax do (tMax = d; fMax = f)
    )
    #(tMin, tMax, fMin, fMax)
)

-- Допуск сбора граней крышки: полоса вдоль оси. Чтобы крышка собиралась даже
-- при наклонённой плоскости грани (скос/конусность торца), полоса ~20%
-- протяжённости объекта вдоль оси (доля - глобальная REMS_capDepthFrac:
-- глубина захвата крышек), но не менее 0.1% диагонали.
fn REMS_capTol m diag tMin tMax = (
    amax #(diag * 0.001, (tMax - tMin) * REMS_capDepthFrac) + 1e-4
)

-- Грани-крышки ПОЛИГОНАЛЬНОЙ геометрии: НОРМАЛЬ ПОЛИГОНА параллельна оси dir
-- (полигоны, перпендикулярные оси выдавливания, т.е. сами крышки). Боковые
-- рёбра экструзии (нормаль ⊥ оси) отбрасываются. Сбор ТОЛЬКО по нормали, без
-- привязки к плоскости. Возвращает bitArray.
fn REMS_collectCapFacesByNormal m dir tolAng:0.9 = (
    local nf = polyop.getNumFaces m
    local bits = #{}
    bits.count = nf
    for f = 1 to nf do (
        local fnrm = normalize (polyop.getFaceNormal m f)
        if (abs (dot fnrm dir)) >= tolAng do bits[f] = true
    )
    bits
)

-- Грани-СТЕНЫ (шаг 3 схемы: «удалить грани по рёбрам выдавливания»): ПОЛИГОН с
-- РЕБРОМ параллельным оси (|dot единичн. ребра, dir| >= tolE), чья нормаль почти
-- перпендикулярна оси (|dot| <= tolN). Крышкой не является: у крышки нормаль ∥
-- оси, и даже если на её границе есть ребро ∥ оси (край выреза/отверстия) - она
-- СТЕНКОЙ не становится (первое условие её отсекает). В EditPoly рёбра полигона
-- - границы поверхности: у гладкого бокового квада есть ребро вдоль оси, и он
-- теперь распознаётся (раньше на тримэше это ребро было скрытым диагональным).
-- Наклонённые/скошенные крышки остаются в наборе: у них нормаль не ⊥ оси даже
-- если на границе есть ребро, параллельное оси выдавливания.
fn REMS_collectSideFaces m dir tolE:0.9 tolN:0.5 = (
    local nf = polyop.getNumFaces m
    local side = #{}
    side.count = nf
    for f = 1 to nf do (
        local nrm = normalize (polyop.getFaceNormal m f)
        if (abs (dot nrm dir)) <= tolN do (
            local vv = polyop.getFaceVerts m f
            local ee = polyop.getFaceEdges m f
            for i = 1 to ee.count do (
                local a = vv[i]
                local b = if i == ee.count then vv[1] else vv[i + 1]
                local e = (polyop.getVert m b) - (polyop.getVert m a)
                local el = length e
                if el > 1e-9 and (abs (dot (e / el) dir)) >= tolE do ( side[f] = true; exit )
            )
        )
    )
    side
)

-- Разделяет набор ПОЛИГОНОВ на связные острова (по общему ребру: ребро EditPoly
-- разделяется максимум двумя полигонами; ключ словаря - индекс ребра).
-- Возвращает массив bitArray островов.
fn REMS_splitFaceIslands m bits = (
    local edgeFaces = Dictionary #integer  -- индекс ребра -> полигоны набора
    for f in bits do (
        for e in (polyop.getFaceEdges m f) do (
            local lst = edgeFaces[e]
            if lst == undefined do (lst = #(); edgeFaces[e] = lst)
            append lst f
        )
    )
    local used = #{}; used.count = polyop.getNumFaces m
    local islands = #()
    for f in bits do (
        if used[f] do continue
        local island = #{}; island.count = polyop.getNumFaces m
        local queue = #(f)
        used[f] = true
        while queue.count > 0 do (
            local c = queue[queue.count]
            deleteItem queue queue.count
            island[c] = true
            for e in (polyop.getFaceEdges m c) do
                for nb in edgeFaces[e] where not used[nb] do (
                    used[nb] = true
                    append queue nb
                )
        )
        append islands island
    )
    islands
)

-- Экстремумы проекций ЦЕНТРОИДОВ граней острова на dir: #(tMin, tMax)
fn REMS_islandCentroidExtremes m island dir = (
    local tMin = 1e30
    local tMax = -1e30
    for f in island do (
        local d = dot dir (REMS_faceCentroid m f)
        if d < tMin do tMin = d
        if d > tMax do tMax = d
    )
    #(tMin, tMax)
)

-- Центроид острова граней: среднее центроидов граней (Point3)
fn REMS_islandCentroid m island = (
    local acc = [0,0,0]
    for f in island do acc += REMS_faceCentroid m f
    acc / (island.numberSet as float)
)

-- Направленное граничное ребро (EditPoly): ребро полигона в порядке обхода его
-- вершин. key - неориентированный ключ (сортированные индексы вершин) - один и
-- тот же для двух полигонов, разделяющих ребро; направления контура по порядку
-- вершин полигона (getFaceVerts возвращает их в порядке обхода контура).
-- На кладёт вершина: vFrom/vTo - направление контура РЕБРА ПОЛИГОНА.
struct REMS_EdgeRec (key, vFrom, vTo)

fn REMS_edgeRecKeyCmp x y = (
    if x.key < y.key then -1 else if x.key > y.key then 1 else 0
)

-- Граничные рёбра набора ПОЛИГОНОВ: рёбра, встречающиеся в наборе один раз.
-- Направление берётся по порядку вершин полигона (для обхода контура).
fn REMS_collectBoundaryEdges m faceBits = (
    local stride = (polyop.getNumVerts m) + 1
    local recs = #()
    for f in faceBits do (
        local vv = polyop.getFaceVerts m f
        local ee = polyop.getFaceEdges m f
        for i = 1 to ee.count do (
            local vStart = vv[i]
            local vEnd = if i == ee.count then vv[1] else vv[i + 1]
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
            -- внутреннее ребро: ключ дублируется (его разделяют два полигона набора);
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
        local pts = for vi in lp collect (polyop.getVert m vi)
        local clean = #(pts[1])
        for i = 2 to pts.count do (
            if distance pts[i] clean[clean.count] > tol do append clean pts[i]
        )
        if clean.count >= 2 and (distance clean[clean.count] clean[1]) <= tol do deleteItem clean clean.count
        if clean.count >= 3 do append res clean
    )
    res
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

-- Перевод мировых точек петель в ЛОКАЛЬНЫЕ координаты сплайна (базис {u, v, dir}).
-- В отличие от сплющивания контура в плоскость (z=0) НЕ сплющивает его
-- z-компонента = смещение вдоль dir сохраняется, поэтому наклонённая крышка
-- повторяется точками сплайна 1:1 и остаётся скошенной, а не выпрямленной.
fn REMS_loopsToLocal loopsW tm = (
    local pos = tm.pos
    local u = tm.row1
    local v = tm.row2
    local d = tm.row3
    for lp in loopsW collect (
        for p in lp collect (
            local q = p - pos
            [(dot u q), (dot v q), (dot d q)]
        )
    )
)

-- Центр BOUNDING BOX вершин заданного набора ПОЛИГОНОВ (базовой крышки).
-- Позиция профиля привязывается к самой крышке, а не к центру меша:
-- центр меша лежит в середине толщины (на полэкструзии позади торца)
fn REMS_capBBoxCenter m sel = (
    local mn = undefined
    local mx = undefined
    for f in sel do (
		local vsel = polyop.getVertsUsingFace m #{f}
        for vi in vsel do (
            local p = polyop.getVert m vi
            if mn == undefined then (
                mn = p
                mx = p
            ) else (
                mn = [amin #(mn.x, p.x), amin #(mn.y, p.y), amin #(mn.z, p.z)]
                mx = [amax #(mx.x, p.x), amax #(mx.y, p.y), amax #(mx.z, p.z)]
            )
        )
    )
    if mn == undefined then [0,0,0] else (mn + mx) * 0.5
)

-- Точное направление и длина рёбер выдавливания: РЁБРА ПОЛИГОНОВ, у которых
-- РОВНО ОДИН конец лежит в базовой крышке, - рёбра ПЕРИМЕТРА профиля, ведущие
-- наружу (к противоположной крышке/скошенной стороне) вдоль оси экструзии.
-- В EditPoly рёбра - только границы полигонов (диагонали трианглирования
-- убраны конвертером), поэтому Direction не сбивается фрагментами поверхности.
-- Результат фильтруется медианой по длине и по согласованности НАПРАВЛЕНИЙ
-- (~16°): на круглой/скользкой базе пара рёбер периметра может оказаться
-- тангентами сопряжений, но чаще это ОБРАЗУЮЩИЕ наклонной оси (например колонна
-- наклонена на 12° - её ось дают эти два ребра), поэтому достаточно >=2
-- СОГЛАСОВАННЫХ рёбер.
-- Возвращает #(направление, число СОГЛАСОВАННЫХ рёбер, средняя длина).
fn REMS_extrudeDirFromCaps m baseSel dir tol = (
    local res = #(dir, 0, 0.0)
    local baseVerts = #{}
    baseVerts.count = polyop.getNumVerts m
    for f in baseSel do baseVerts += (polyop.getVertsUsingFace m #{f})
    local basePts = for vi in baseVerts collect (polyop.getVert m vi)
    local diffs = #()
    for e in (REMS_collectVisibleEdges m) do (
        local pA = e[3]
        local pB = e[4]
        local inA = (findItem basePts pA) > 0
        local inB = (findItem basePts pB) > 0
        if inA != inB then (
            local dv = if inA then (pB - pA) else (pA - pB)
            if (length dv) > tol do append diffs dv
        )
    )
    if diffs.count >= 3 then (
        local lens = for d in diffs collect (length d)
        sort lens
        local med = lens[(lens.count + 1) / 2]
        local lim = (amax #(med, tol) * 1.5) + tol
        local vs = for d in diffs where (length d) <= lim collect d
        if vs.count == 0 do vs = diffs
        local acc = [0,0,0]
        local accLen = 0.0
        for d in vs do (
            acc += normalize d
            accLen += length d
        )
        local nd = normalize acc
        if (length nd) > 1e-9 do (
            local vs2 = for d in vs where (abs (dot (normalize d) nd)) >= 0.96 collect d
            if vs2.count >= 2 do (
                local acc2 = [0,0,0]
                local accLen2 = 0.0
                for d in vs2 do (
                    acc2 += normalize d
                    accLen2 += length d
                )
                local nd2 = normalize acc2
                if (dot nd2 dir) < 0 do nd2 = -nd2
                res = #(nd2, vs2.count, accLen2 / vs2.count)
            )
        )
    )
    res
)

-- Толщина выдавливания ЛУЧОМ (шаг 6 схемы): из пивота pos (центра bbox базовой
-- крышки) вдоль оси до первого пересечения с ПРОТИВОПОЛОЖНОЙ дальней гранью.
-- Реализация на RayMeshGridIntersect (воксельная сетка, двойная сторона) -
-- пересечение считается даже с обратной стороной граней, точная дистанция
-- через getHitDist. Начало луча сдвигается на tol внутрь вдоль +d, чтобы не
-- зацепить саму базу; если в +d пересечения нет (база со стороны max, объект
-- растёт в -d) - луч пускается в -d. Итог = дистанция от pos + tol.
-- Возвращает 0.0, если пересечений нет вообще.
fn REMS_rayThickness m pos d tol = (
    local res = 0.0
    local rm = RayMeshGridIntersect()
    rm.Initialize 10
    -- временный узел из SNAPSHOT меша m (вершины уже в мировых координатах,
    -- transform единичный): сетка строится по той же поверхности, что анализировалась
    local tmp = mesh mesh:m
    try (
        rm.addNode tmp
        rm.buildGrid()
        local st = pos + (d * tol)
        if (rm.intersectRay st d true) > 0 then (
            -- берём наиболее УДАЛЁННОЕ пересечение: луч проходит сквозь ВСЕ
            -- крышки по пути, но Extrude должен дотянуться до противоположного
            -- дальнего торца, а не до промежуточной выемки/полки внутри
            res = tol + (rm.getHitDist (rm.getFarthestHit()))
        ) else (
            local st2 = pos - (d * tol)
            if (rm.intersectRay st2 (-d) true) > 0 do res = tol + (rm.getHitDist (rm.getFarthestHit()))
        )
    ) catch (
        format "REMS: ошибка луча RayMeshGridIntersect: %\n" (getCurrentException())
    )
    rm.free()
    try (delete tmp) catch ()
    res
)

-- Толщина выдавливания ПРОЕКЦИЕЙ (опция REMS_projectionThickness): все вершины
-- геометрии проецируются на ось dir, толщина = максимальная удалённость проекции
-- от базы (capCenter) вдоль +dir. Не зависит от формы дальней шапки (купол/фасет/
-- скос) и не может «промахнуться» мимо дальней грани, как луч.
-- Возвращает 0.0, если ничего не удалённее базы вдоль +dir.
fn REMS_axisProjectionThickness m capCenter dir = (
    local hs = 0.0
    for v = 1 to (polyop.getNumVerts m) do (
        hs = amax #(hs, dot ((polyop.getVert m v) - capCenter) dir)
    )
    hs
)

-- Нормаль базовой крышки как среднее нормалей её ПОЛИГОНОВ - фолбэк для
-- направления выдавливания, когда противоположная крышка не найдена
-- (на скошенных формах с плоским торцом точнее PCA-подсказки).
fn REMS_capNormal m sel = (
    local acc = [0,0,0]
    for f in sel do acc += normalize (polyop.getFaceNormal m f)
    if (length acc) < 1e-9 then [0,0,0] else normalize acc
)

-- Bounding box точек ПРОФИЛЯ в локальной системе сплайна (loopsP - массив петель
-- локальных точек): #(min, max). Разброс по локальному Z = глубина крышки вдоль
-- оси выдавливания (неплоская база: взяты уступы/полки).
fn REMS_profileBBox loopsP = (
    local mn = [1e30, 1e30, 1e30]
    local mx = [-1e30, -1e30, -1e30]
    for lp in loopsP do for p in lp do (
        mn = [amin #(mn.x, p.x), amin #(mn.y, p.y), amin #(mn.z, p.z)]
        mx = [amax #(mx.x, p.x), amax #(mx.y, p.y), amax #(mx.z, p.z)]
    )
    #(mn, mx)
)

/* --------------------
--
-- Ориентация осей XY профиля к минимальному bbox (convex hull + rotating calipers)
--
*/ --------------------

-- Размер (ширина/высота/площадь) ориентационно-независимого прямоугольника по
-- проекции точек на ось, повёрнутую на угол ang (в градусах) относительно XY.
-- Точки - массив point3 с значимыми только x,y. Возвращает #(width, height, area).
fn REMS_bboxSizeAtAngle pts ang = (
    local cosA = cos ang
    local sinA = sin ang
    local uMin = 1e30, uMax = -1e30
    local vMin = 1e30, vMax = -1e30
    for pt in pts do (
        local u = pt.x * cosA + pt.y * sinA
        local v = -pt.x * sinA + pt.y * cosA
        if u < uMin do uMin = u
        if u > uMax do uMax = u
        if v < vMin do vMin = v
        if v > vMax do vMax = v
    )
    local w = uMax - uMin
    local h = vMax - vMin
    #(w, h, w * h)
)

-- Знаковое поперечное произведение (2D) векторов (b-a)x(c-a); >0 означает
-- поворот против часовой стрелки. Используется в оболочке и для коллинеарности.
fn REMS_cross2 a b c = (
    (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
)

-- Выпуклая оболочка набора 2D-точек (x,y значимы) алгоритмом Andrew's Monotone
-- Chain. Сортировка точек по (x, y), затем построение нижней и верхней цепей,
-- коллинеарные точки отбрасываются. Возвращает массив point3 оболочки (CCW,
-- без замыкающей повторной первой точки). Если точек < 3 или они коллинеарны -
-- вернёт менее 3 точек, и вызов наружу должен это учесть.
fn REMS_convexHull2D pts = (
    local sp = deepCopy pts
    qsort sp (fn REMS_sortPtsXY a b = (
        if a.x != b.x then if a.x < b.x then -1 else 1
        else if a.y != b.y then if a.y < b.y then -1 else 1
        else 0
    ))
    if sp.count < 3 do return sp
    local lo = #()
    for p in sp do (
        while lo.count >= 2 and (REMS_cross2 lo[lo.count - 1] lo[lo.count] p) <= 0 do deleteItem lo lo.count
        append lo p
    )
    local up = #()
    for i = sp.count to 1 by -1 do (
        local p = sp[i]
        while up.count >= 2 and (REMS_cross2 up[up.count - 1] up[up.count] p) <= 0 do deleteItem up up.count
        append up p
    )
    deleteItem lo lo.count
    deleteItem up up.count
    join lo up
    lo
)

-- Минимальный ограничивающий прямоугольник выпуклого многоугольника и его угол.
-- Минимум площади bbox гарантированно имеет сторону, совпадающую с ребром
-- оболочки (rotating calipers), поэтому достаточно перебрать рёбра оболочки и
-- для каждого посчитать площадь bbox при оси, параллельной ребру. Вершины
-- оболочки должны быть упорядочены по контуру (как из REMS_convexHull2D).
-- Возвращает #(width, height, area, angle, areas) где angle - угол (градусы)
-- поворота, ставящий сторону прямоугольника параллельно ребру минимума,
-- areas - массив площадей по всем рёбрам (для проверки симметрии).
fn REMS_minBBoxByHullEdges hull = (
    local n = hull.count
    if n < 3 do return #(0.0, 0.0, 0.0, 0.0, #())
    local areas = #()
    local widths = #()
    local heights = #()
    local angles = #()
    for i = 1 to n do (
        local a = hull[i]
        local b = hull[(if i == n then 1 else i + 1)]
        local ang = atan2 (b.y - a.y) (b.x - a.x)
        local sz = REMS_bboxSizeAtAngle hull ang
        append widths sz[1]
        append heights sz[2]
        append areas sz[3]
        append angles ang
    )
    local best = 1
    for i = 2 to n do if areas[i] < areas[best] do best = i
    #(widths[best], heights[best], areas[best], angles[best], areas)
)

-- Направление (угол в [0,180)) ДЛИННОЙ стороны прямоугольника при заданном угле
-- оси bbox ang (обычно - угол ребра минимального bbox из REMS_minBBoxByHullEdges).
-- Если ширина (u-размах) >= высоты (v-размаха), длинная сторона лежит вдоль оси
-- ang, иначе - перпендикулярно ей (+90). Возвращает угол направления длинной
-- стороны в текущей XY-системе.
fn REMS_normLongSideToX pts ang = (
    local sz = REMS_bboxSizeAtAngle pts ang
    if sz[1] >= sz[2] then mod ang 180.0 else mod (ang + 90.0) 180.0
)

-- Определение результирующего направления ДЛИННОЙ стороны после прилипания к
-- мировой оси XY {0,90}: расстояние заданного направления longA до мировой X
-- (0, с учётом симметрии 180) и до мировой Y (90). Если одно из расстояний
-- меньше tol (градусы) - возвращается соответствующая мировая ось (детерминизм
-- для круглых/симметричных профилей); иначе возвращается само направление.
-- Возвращаемое значение - угол ЦЕЛЕВОГО направления длинной стороны; поворот
-- профиля на это значение приводит длинную сторону в мировую +X.
fn REMS_snapProfileAxis longA tol = (
    local d0 = amin #(abs longA, abs (longA - 180.0))
    local d90 = abs (longA - 90.0)
    if d0 <= tol then 0.0
    else if d90 <= tol then 90.0
    else longA
)

-- Перевод МИЛЛИМЕТРОВ в текущие СИСТЕМНЫЕ единицы 3ds Max.
-- Например REMS_mmToSys 1000 (1 м): в мм -> 1000, в дюймах -> 40.81, в м -> 1.0.
-- Используется для размера UVWMap (plane 1 м) и расчёта UVW Xform tile (1/значение).
fn REMS_mmToSys mm = (
    local v = undefined
    try ( v = units.decodeValue ((mm as string) + "mm") ) catch ( v = undefined )
    if v == undefined then (
        -- fallback по units.SystemType (SystemScale в #Generic игнорируем)
        local k = case units.SystemType of (
            #Micrometers: 1000.0
            #Millimeters: 1.0
            #Centimeters: 0.1
            #Meters: 0.001
            #Kilometers: 0.000001
            #Inches: (1.0 / 25.4)
            #Feet: (1.0 / 304.8)
            #Miles: (1.0 / 1609344.0)
            default: 1.0
        )
        v = mm * k
    )
    v
)

-- Доминирующий (самый частый) MaterialID по набору граней faceBits полигона p.
-- Для пустого набора возвращает undefined.
fn REMS_collectGroupMatID p faceBits = (
    if faceBits == undefined or faceBits.numberSet == 0 do return undefined
    local freq = #()
    local foundID = undefined
    for f in faceBits do (
        local id = polyop.getFaceMatID p f
        local has = false
        for ff = 1 to freq.count do if freq[ff][1] == id do ( freq[ff][2] += 1; has = true; exit )
        if not has do append freq #(id, 1)
    )
    local best = 0
    for ff in freq do if ff[2] > best do ( best = ff[2]; foundID = ff[1] )
    foundID
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
    -- Исходник сразу конвертируется в EditablePoly (по схеме пользователя):
    -- EditPoly строит ЛОГИЧЕСКИЕ ПОЛИГОНЫ - сшивает треугольники по скрытым
    -- рёбрам и убирает вершины, у которых все рёбра скрытые. Поэтому:
    --   * рёбра полигона - только границы реальной поверхности (диагонали
    --     трианглирования исчезают) - направление/классификация не
    --     засоряются фрагментами одной поверхности;
    --   * у гладких тел (круглые колонны) боковые квады получают рёбра вдоль
    --     оси выдавливания, раньше скрытые на тримэше, - стены распознаются;
    --   * работать с логическими полигонами быстрее и проще (polyops).
    -- временный mesh-снапшот остаётся только для луча толщины (RayMeshGrid).
    -- КОПИЯ перед конвертацией: исходник удаляется по умолчанию - снапшот и так
    -- независимая копия; если исходник ОСТАЁТСЯ (REMS_deleteSourceObjects=false),
    -- делается повторный глубокий снапшот через временный узел, чтобы временный
    -- поли заведомо не делил буферы вершин/граней с исходным объектом.
    local m = snapshotAsMesh obj
    if not REMS_deleteSourceObjects do (
        local cp = mesh mesh:m
        cp.ishidden = true
        m = snapshotAsMesh cp
        try (delete cp) catch ()
    )
    local p = convertToPoly (mesh mesh:m)
    p.ishidden = true
    local bb = REMS_meshBBox p
    local diag = length (bb[2] - bb[1])
    -- петли в локальной системе сплайна
    local loopsP = #()
    local tmFacade = matrix3 1
    local extrudeAmount = 0.0

    -- ---- универсальный механизм для ЛЮБОЙ оси выдавливания ----
    -- ШАГИ 1-2 (схема пользователя): ось по ВИДИМЫМ рёбрам большинством голосов,
    -- где СВЯЗНЫЕ рёбра считаются за одно (REMS_pickAxisByEdges). Коробки/плиты/
    -- колонны вырождены (ничья по всем трём осям) - подсказка wall:Shift.
    local dir = REMS_pickAxisByEdges p
    local axisNote = "подсказка"
    if dir != undefined then axisNote = "видимые рёбра" else (
        dir = REMS_pickFallbackAxis p wall:wall
    )
    -- ОРИЕНТАЦИЯ ЗНАКА (как check_z_up, всегда, без допусков, одинаково для всех осей):
    -- знак оси произволен (направления рёбер от обхода граней неопределённы), и он
    -- определяет, какой конец - база. Смотрим, к какой МИРОВОЙ оси ось ближе всего
    -- (доминантная компонента, граница ровно 45° в проекции), и выравниваем знак по
    -- положительной её стороне; с Alt (направление выдавливания) - по отрицательной.
    -- Сам НАКЛОН оси (наклонённые колонны/клинья) НЕ выравнивается - меняется только
    -- знак, чтобы база (tMin) лежала на детерминированном конце.
    local da = #(abs dir.x, abs dir.y, abs dir.z)
    local di = 1
    if da[2] > da[1] then di = 2
    if da[3] > da[di] then di = 3
    local c = if di == 1 then dir.x else if di == 2 then dir.y else dir.z
    if useMaxSide then (
        if c > 0.0 do dir = -dir
    ) else (
        if c < 0.0 do dir = -dir
    )
    -- экстремумы вдоль выбранной оси
    local ex = REMS_faceCentroidExtremes p dir
    local tMin = ex[1]
    local tMax = ex[2]
    format "REMS: '%' (ось=% %)\n" obj.name dir axisNote
    -- ШАГ 3: крышки = ВСЕ полигоны МИНУС стены (эквивалент «удалить грани по
    -- рёбрам выдавливания»). Стена - ПОЛИГОН с ребром ∥ оси, чья нормаль ⊥ оси.
    -- Скошенные/наклонённые крышки (нормаль не ∥ оси) при таком способе НЕ
    -- теряются, в отличие от отборки строго по нормали.
    local nfAll = polyop.getNumFaces p
    if REMS_debug do (
        format "  -- удаление граней по рёбрам выдавливания (% полигонов всего) --\n" nfAll
    )
    local sideBits = REMS_collectSideFaces p dir
    if REMS_debug do format "  стены (удалено): % полигонов\n" sideBits.numberSet
    local capBits = #{}
    capBits.count = nfAll
    for f = 1 to nfAll do if not sideBits[f] do capBits[f] = true
    if capBits.isEmpty then (
        format "REMS: '%': все грани оказались стенами по оси % - пропуск\n" obj.name dir
    ) else (
        -- ШАГ 4: выбрать БАЗОВУЮ крышку из связных островов: остров, ЦЕЛИКОМ
        -- лежащий на крайней плоскости tBase (по центроидам граней; у скошенного
        -- торца «нос»-вершина выступает за плоскость крышки, поэтому по вершинам
        -- плоскость пуста). Требование малой протяжённости вдоль оси отсекает
        -- наклонённую противоположную крышку, заходящую на tBase.
        -- база - всегда начало отсчёта вдоль оси (tMin); смена направления (Alt)
        -- уже задана ЗНАКОМ оси (ориентация выше), поэтому tBase от Alt не зависит
        local tBase = tMin
        local tolCap = REMS_capTol p diag tMin tMax
        local capSel = #{}
        capSel.count = nfAll
        local allIslands = REMS_splitFaceIslands p capBits
        if REMS_debug do (
            format "  -- связные острова крышек: % шт --\n" allIslands.count
            for ii = 1 to allIslands.count do (
                local ib = allIslands[ii]
                local ie = REMS_islandCentroidExtremes p ib dir
                local ig = REMS_islandCentroid p ib
                format "   остров %: граней=% центроид=[%,%,%] ось,%..% (контуры вдоль оси)\n" \
                    ii ib.numberSet ig[1] ig[2] ig[3] ie[1] ie[2]
            )
        )
        for isl in allIslands do (
            local ie = REMS_islandCentroidExtremes p isl dir
            if (abs (ie[1] - tBase)) <= tolCap and (abs (ie[2] - tBase)) <= tolCap do capSel += isl
        )
        if capSel.isEmpty do (
            -- фолбэк: если рёбра выдавливания невидимы - крышка по НОРМАЛИ ∥ оси
            local capN = REMS_collectCapFacesByNormal p dir
            if not capN.isEmpty do (
                format "REMS: '%': база по рёбрам не набрана - фолбэк по нормали\n" obj.name
                for isl in (REMS_splitFaceIslands p capN) do (
                    local ie = REMS_islandCentroidExtremes p isl dir
                    if (abs (ie[1] - tBase)) <= tolCap and (abs (ie[2] - tBase)) <= tolCap do capSel += isl
                )
            )
        )
        if REMS_debug do (
            format "  база: tBase=% (tMin, направление через знак оси, Alt=%), tolCap=% - островов: % (грани=%)\n" \
                tBase useMaxSide tolCap (REMS_splitFaceIslands p capSel).count capSel.numberSet
        )
        if capSel.isEmpty then (
            format "REMS: '%': остров базовой стороны не найден - пропуск\n" obj.name
        ) else (
            format "REMS: '%': базовых островов крышки: % (грани=%)\n" obj.name (REMS_splitFaceIslands p capSel).count capSel.numberSet
            local edges = REMS_collectBoundaryEdges p capSel
            if edges[1].count > 0 then (
                local loopsV = REMS_traceLoops (polyop.getNumVerts p) edges[1] edges[2]
                local loopsW = REMS_loopsToWorldPoints p loopsV (amax #(diag * 0.00001, 0.000001))
                if loopsW.count > 0 then (
                    -- внешний контур - по максимальной площади; проёмы - в обратном обходе;
                    -- внешний контур приводится к положительному обходу вдоль оси (как +Z)
                    local orientRes = REMS_loopsOrient loopsW dir
                    loopsW = orientRes[1]
                    if orientRes[2] do (
                        format "REMS: '%': петли сопоставимой площади - возможно это боковая поверхность, а не грань\n" obj.name
                    )
                    -- локальная система профиля: u, v лежат в плоскости, z - ось выдавливания;
                    -- ось и длина уточняются по ВИДИМЫМ рёбрам периметра базовой
                    -- крышки (выдают наклонной оси: у колонны база плоская, но
                    -- ось наклонена, а рёбра периметра - её образующие);
                    -- нормаль базы - только слабый предохранитель: если рёбра
                    -- противоречат ей сильнее ~45°, верить нормали;
                    -- фолбэк по нормали базы;
                    -- начало координат - ЦЕНТР BBOX БАЗОВОЙ КРЫШКИ (профиля выдавливания),
                    -- а не всего меша: центр меша лежит в середине толщины,
                    -- на полэкструзии позади торца, и сплайн уезжает с крышки
                    local axisNote = "подсказка"
                    local extrudeRef = 0.0
                    local cn = REMS_capNormal p capSel
                    local cnOk = (length cn) > 1e-9 and (abs (dot cn dir)) > 0.5
                    if cnOk do if (dot cn dir) < 0 do cn = -cn
                    local r = REMS_extrudeDirFromCaps p capSel dir (diag * 0.0001)
                    -- рёбра весомы при любом количестве, если не противоречат
                    -- нормали базы сильнее ~45° (тангенты сопряжений отклоняются
                    -- больше, а настоящие образующие выдавливания - меньше)
                    local useEdges = r[2] > 0 and (not cnOk or (abs (dot cn r[1])) >= 0.7)
                    if useEdges then (
                        local dir0 = dir
                        dir = r[1]
                        extrudeRef = r[3]
                        axisNote = ("рёбра выдавливания (" + (r[2] as string) + " шт)")
                        if dir != dir0 and REMS_debug do (
                            format "  уточнение оси: [%,%,%] -> [%,%,%] (рёбра выдавливания, длина=%)\n" \
                                dir0.x dir0.y dir0.z dir.x dir.y dir.z r[3]
                        )
                    ) else (
                        if cnOk and (abs (dot cn dir)) < 0.999999 do (
                            local dir0 = dir
                            dir = cn
                            axisNote = "нормаль крышки"
                            if REMS_debug do (
                                format "  уточнение оси (нормаль крышки): [%,%,%] -> [%,%,%]\n" \
                                    dir0.x dir0.y dir0.z dir.x dir.y dir.z
                            )
                        )
                        -- длина рёбер (если есть) остаётся запасом для толщины
                        if r[2] > 0 and extrudeRef == 0.0 do extrudeRef = r[3]
                    )
                    -- ФОЛБЭК по центроидам крайних крышек: если ни рёбра, ни нормаль
                    -- базовой крышки не дали наклона оси (база горизонтальна, а
                    -- образующие на выбранном конце не распознаны), ось берётся
                    -- по ЦЕНТРОИДАМ базы и максимально удалённого вдоль +dir торца:
                    -- для прямых призматических тел это и есть направление
                    -- выдавливания. Иначе вниз/вверх уходило бы ровно по мировой
                    -- оси (баг: Alt=true на наклонённом объекте).
                    if axisNote == "подсказка" do (
                        local ccB = REMS_capBBoxCenter p capSel
                        local farIsl = undefined
                        local farT = -1e30
                        for ib2 in (REMS_splitFaceIslands p capBits) do (
                            local ie2 = REMS_islandCentroidExtremes p ib2 dir
                            if ie2[2] > farT do ( farT = ie2[2]; farIsl = ib2 )
                        )
                        if farIsl != undefined and (farT - tBase) > (diag * 0.01) do (
                            local ccF = REMS_islandCentroid p farIsl
                            local ax2 = normalize (ccF - ccB)
                            if (length ax2) > 1e-6 do (
                                if (dot ax2 dir) < 0 do ax2 = -ax2
                                if (dot ax2 dir) < 0.999999 do (
                                    local dir0 = dir
                                    dir = ax2
                                    axisNote = "центроиды крайних крышек"
                                    if REMS_debug do (
                                        format "  уточнение оси (центроиды крайних крышек): [%,%,%] -> [%,%,%]\n" \
                                            dir0.x dir0.y dir0.z dir.x dir.y dir.z
                                    )
                                )
                            )
                        )
                    )
                    local capCenter = REMS_capBBoxCenter p capSel
                    -- ортонормированный базис плоскости профиля. Наклонённая dir
                    -- не должна ломать u/v: раньше при |dir.z|>=0.9 всегда бралось
                    -- u=[1,0,0], и для оси с наклоном в X v=cross(dir,u) укорачивался,
                    -- а u не был ⊥ dir -> матрица неортогональная и сплайн скошен;
                    -- при dir точно вдоль Z сохраняем классику (u=+X, v=+Y)
                    local u = if (abs dir.z) < 0.9 then normalize (cross [0,0,1] dir) else (
                        if (abs dir.x) < 1e-6 and (abs dir.y) < 1e-6 then [1,0,0]
                        else normalize (cross [0,1,0] dir)
                    )
                    local v = normalize (cross dir u)
                    tmFacade = matrix3 u v dir capCenter
                    -- axZ - признак, что ось выдавливания вертикальна (мировая Z).
                    -- Вычисляется по финальной dir; используется и для договора
                    -- экструзии, и для пост-коррекции горизонтальных элементов.
                    local axZ = (abs dir.z >= abs dir.x) and (abs dir.z >= abs dir.y)
                    if REMS_debug do (
                        format "  -- локальная трансформация --\n"
                        format "  dir(ось экструзии: %)     = [%,%,%]\n" axisNote dir.x dir.y dir.z
                        format "  capCenter (центр bbox базовой крышки)  = [%,%,%]\n" capCenter.x capCenter.y capCenter.z
                        format "  u (первая ось плоскости) = [%,%,%] = normalize(cross Z dir) при |dir.z|<0.9\n" u.x u.y u.z
                        format "  v (вторая ось плоскости) = [%,%,%] = cross dir u\n" v.x v.y v.z
                        format "  tmFacade = matrix3 u v dir capCenter:\n"
                        format "    u=[%,%,%] v=[%,%,%] z=[%,%,%] pos=[%,%,%]\n" \
                            tmFacade.row1.x tmFacade.row1.y tmFacade.row1.z \
                            tmFacade.row2.x tmFacade.row2.y tmFacade.row2.z \
                            tmFacade.row3.x tmFacade.row3.y tmFacade.row3.z \
                            tmFacade.pos.x tmFacade.pos.y tmFacade.pos.z
                    )
                    loopsP = REMS_loopsToLocal loopsW tmFacade
                    -- ОРИЕНТАЦИЯ ОСЕЙ XY К МИНИМАЛЬНОМУ BBОX (все оси выдавливания).
                    -- Строим выпуклую оболочку профильных точек (x,y) и для каждой
                    -- грани оболочки считаем площадь bbox; минимум площади
                    -- гарантированно достигается, когда сторона bbox параллельна
                    -- одному из рёбер оболочки (rotating calipers), поэтому перебор
                    -- рёбер даёт точный глобальный минимум направления.
                    -- Чтобы отличить настоящую (неоднозначную) симметрию - круг/
                    -- квадрат/правильный многоугольник - от вытянутого прямоугольника,
                    -- площадь снимается ГРУБЫМ ПРОХОДОМ по всем углам 0..180:
                    -- у круга/квадрата она почти постоянна (плато), у прямоугольника
                    -- в промежуточных углах заметно вырастает. Поэтому сравнение
                    -- только площадей рёбер оболочки не годится (у прямоугольника
                    -- все рёберные площади равны) - нужен проход по углам.
                    -- Вращение вокруг row3 не меняет локальный Z: глубина крышки
                    -- (capZ), вычет толщины и пивот (считается по мировым петлям)
                    -- остаются прежними.
                    if REMS_findMinimalBBox and loopsW.count > 0 do (
                        local pts = #()
                        for lp in loopsP do for pt in lp do append pts (point3 pt.x pt.y 0)
                        if pts.count >= 3 then (
                            local hull = REMS_convexHull2D pts
                            if hull.count >= 3 then (
                                local mb = REMS_minBBoxByHullEdges hull
                                local min = mb[3]
                                -- грубый проход по углам: max площади (для детекта плато)
                                local aSweepMax = 0.0
                                local sweepStep = 2.0
                                for degS = 0.0 to 178.0 by sweepStep do
                                    aSweepMax = amax #(aSweepMax, (REMS_bboxSizeAtAngle pts degS)[3])
                                local aMean = (min + aSweepMax) * 0.5
                                local flat = (aMean > 0.0) and ((aSweepMax - min) / aMean) < REMS_minBBoxSymTol
                                if flat then (
                                    if REMS_debug do format "  ориентация: площадь почти постоянна (круг/квadрат, разброс %): доворот не выполняется\n" ((aSweepMax - min) / (amax #(1e-9, aMean)))
                                ) else (
                                    local A = REMS_normLongSideToX pts mb[4]
                                    local An = REMS_snapProfileAxis A REMS_minBBoxAxisSnapTol
                                    if abs An > 1e-6 then (
                                        local cosA = cos An
                                        local sinA = sin An
                                        local u = tmFacade.row1
                                        local v = tmFacade.row2
                                        tmFacade = matrix3 (u * cosA + v * sinA) (-u * sinA + v * cosA) tmFacade.row3 tmFacade.pos
                                        local loopsPmin = REMS_loopsToLocal loopsW tmFacade
                                        if REMS_debug do (
                                            local ptsN = #()
                                            for lp in loopsPmin do for pt in lp do append ptsN (point3 pt.x pt.y 0)
                                            format "  ориентация: мин bbox угол=% (после прилипания к мировой оси), площадь мин % -> %\n" An mb[3] (REMS_bboxSizeAtAngle ptsN 0.0)[3]
                                        )
                                        loopsP = loopsPmin
                                    ) else (
                                        if REMS_debug do format "  ориентация: угол % уже прилип к мировой оси - доворот не нужен\n" mb[4]
                                    )
                                )
                            )
                        )
                    )
                    -- ПОСТ-КОРРЕКЦИЯ ОРИЕНТАЦИИ ДЛЯ ГОРИЗОНТАЛЬНЫХ ЭЛЕМЕНТОВ.
                    -- Для вертикальной оси (axZ) u уже горизонтален, v вертикален -
                    -- оставляем как есть. Для ГОРИЗОНТАЛЬНОЙ оси (ось выдавливания в
                    -- X/Y-плоскости) min-bbox мог уложить длинную сторону профиля в v
                    -- (вертикаль), что неверно: у горизонтальной плиты/балки/бруса
                    -- длинная сторона сечения - это ВЫСОТА (вертикаль), и она должна
                    -- лежать в Y(вертикаль), а X должен остаться горизонтальной
                    -- шириной. Поэтому если первая ось (u) ушла в вертикаль, меняем
                    -- u и v местами: новая X = горизонтальная длинная сторона,
                    -- Y = вертикаль вверх. Знак новой X берём противоположный старой
                    -- u, чтобы ось выдавливания row3(=dir) не изменилась и система
                    -- осталась правой (cross(newRow1,newRow2) = +row3).
                    if (not axZ) and (abs (dot tmFacade.row1 [0,0,1])) > 0.7 do (
                        tmFacade = matrix3 (-tmFacade.row2) tmFacade.row1 tmFacade.row3 tmFacade.pos
                        loopsP = REMS_loopsToLocal loopsW tmFacade
                        if REMS_debug do (
                            local ptsN = #()
                            for lp in loopsP do for pt in lp do append ptsN (point3 pt.x pt.y 0)
                            local bb = REMS_bboxSizeAtAngle ptsN 0.0
                            format "  пост-коррекция X/Y: длинная сторона была в вертикали (v), поменяли u<->v, Y вверх\n"
                            format "    новая u=[%,%,%] v=[%,%,%] оси штрих=% x % \n" \
                                tmFacade.row1.x tmFacade.row1.y tmFacade.row1.z \
                                tmFacade.row2.x tmFacade.row2.y tmFacade.row2.z \
                                bb[1] bb[2]
                        )
                    )
                    -- ШАГ 6: толщина выдавливания. По умолчанию ЛУЧ из ПИВОТА (центра bbox
                    -- базовой крышки) вдоль оси до пересечения с ПРОТИВОПОЛОЖНОЙ
                    -- дальней гранью (REMS_rayThickness). Опция REMS_projectionThickness
                    -- вместо луча проецирует ВСЕ вершины меша на ось и берёт удалённую
                    -- точку (устойчиво к купольной/фасетной дальней шапке).
                    -- Фолбэки: средняя длина рёбер выдавливания, затем разброс вершин.
                    local thick = 0.0
                    local thickNote = ""
                    if REMS_projectionThickness then (
                        thick = REMS_axisProjectionThickness p capCenter dir
                        thickNote = "проекция вершин"
                    ) else (
                        thick = REMS_rayThickness m capCenter dir (diag * 0.0001)
                        thickNote = "луч от пивота"
                    )
                    if thick <= 0.0 and extrudeRef > 0.0 do ( thick = extrudeRef; thickNote = "рёбра выдавливания" )
                    if thick <= 0.0 do (
                        local axF = REMS_axisExtremes p dir
                        thick = axF[2] - axF[1]
                        thickNote = "разброс вершин"
                    )
                    if REMS_debug do format "  толщина выдавливания: % (%)\n" thick thickNote
                    -- ДОГОВОР НА ВЫВОДЕ (только для вертикальных элементов - ось
                    -- выдавливания = МИРОВАЯ Z): локальная ось Z сплайна всегда
                    -- направлена в ПОЛОЖИТЕЛЬНУЮ сторону, а направление вниз при
                    -- Alt задаётся ОТРИЦАТЕЛЬНОЙ величиной Extrude. Для осей X/Y
                    -- (горизонтальных плит/балок) поведение не меняется: локальная
                    -- ось = направление выдавливания, amount всегда положительный.
                    -- axZ - признак, что ось выдавливания вертикальна (мировая Z);
                    -- сам НАКЛОН оси (dir) не влияет на знак, только его мировая
                    -- ориентация. Вычисляется по финальной dir (объявлена ранее).
                    -- выдавливание: для axZ знак по договору (вниз при Alt = отрицат.);
                    -- для X/Y - всегда положительное (направление через знак оси).
                    if axZ and useMaxSide then extrudeAmount = -thick
                    else extrudeAmount = thick
                    -- Опция REMS_subtractCapDepthFromThickness: НЕПЛОСКАЯ база
                    -- (профиль имеет разброс по локальному Z - захвачены уступы/
                    -- полки/скосы). Extrude удлиняет КАЖДУЮ вершину профиля на
                    -- extrudeAmount вдоль оси, поэтому тело занимает
                    -- [минZ, максZ+extrudeAmount]; профиль сам уже покрывает
                    -- глубину крышки capZ, по кругу и вниз от центра bbox-
                    -- крышки (capCenter ~ середина разброса). Т.к. толщина
                    -- мереется от ЦЕНТРА bbox крышки до дальней грани, то для
                    -- исходного габаритного контейнера нужно вычесть ПОЛОВИНУ
                    -- глубины: максZ+extrude = (центр+capZ/2)+(thick-capZ/2) =
                    -- центр+thick = дальняя грань. Вычитание полной глубины дало
                    -- бы тело на capZ/2 короче исходного контейнера.
                    if REMS_subtractCapDepthFromThickness and loopsP.count > 0 do (
                        local pbb = REMS_profileBBox loopsP
                        local capZ = pbb[2][3] - pbb[1][3]
                        if capZ > (diag * 0.0001) and (abs extrudeAmount) > (capZ * 0.5) then (
                            local t0 = extrudeAmount
                            -- вычитаем полглубины крышки в направлении выдавливания:
                            -- для axZ+Alt (отрицат. amount) знак вычитания тоже минус
                            local signW = if axZ and useMaxSide then -1.0 else 1.0
                            extrudeAmount = extrudeAmount - signW * capZ * 0.5
                            if REMS_debug do format "  толщина скорректирована (неплоская база, глубина крышки %): % -> % (вычтен 0.5*глубины)\n" capZ t0 extrudeAmount
                        )
                    )
                ) else (
                    format "REMS: '%': контур не построен - пропуск\n" obj.name
                )
            ) else (
                format "REMS: '%': на базовой стороне нет границы - пропуск\n" obj.name
            )
        )
    )

    if loopsP.count > 0 do (
        local knotsBefore = 0
        for lp in loopsP do knotsBefore += lp.count
        -- имя запоминаем сразу: обращения к .name возможны только у живого узла
        local ssName = uniqueName (obj.name + "_spline")
        -- ДОГОВОР НА ВЫВОДЕ выполняется КАК МОЖНО ПОЗЖЕ - после всех внутренних
        -- расчётов (минимальный bbox, толщина, вычет глубины), прямо перед
        -- построением сплайна, и ТОЛЬКО для вертикальных элементов (axZ, ось =
        -- мировая Z): локальная ось Z формы разворачивается в МИРОВУЮ
        -- положительную сторону. Это поворот на 180 градусов вокруг локальной
        -- оси u (row1 остаётся, row2/v и row3/dir меняют знак; pos=capCenter тот
        -- же). Петли пересчитываются в новом базисе через REMS_loopsToLocal.
        -- Геометрия и пивот в мире не смещаются - меняется только ориентация
        -- local-Z; направление вниз при Alt задано отрицательным extrudeAmount.
        -- Разворот уже построенного узла (после упрощения) не делаем: после
        -- Simplify-Spline.ms узлы могут лежать в мировых координатах (ловушка
        -- фреймов), пересчёт был бы ненадёжным.
        if axZ and useMaxSide do (
            tmFacade = matrix3 tmFacade.row1 (-tmFacade.row2) (-tmFacade.row3) tmFacade.pos
            loopsP = REMS_loopsToLocal loopsW tmFacade
        )
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
        -- пивот (до Extrude); присваивание .pivot смещает только пивот,
        -- геометрия и направление экструзии не меняются
        local kpts = #()
        for s = 1 to numSplines ss do
            for k = 1 to numKnots ss s do append kpts (getKnotPoint ss s k)
        if kpts.count > 0 do (
            local kmn = kpts[1], kmx = kpts[1]
            for p in kpts do (
                kmn = [amin #(kmn.x, p.x), amin #(kmn.y, p.y), amin #(kmn.z, p.z)]
                kmx = [amax #(kmx.x, p.x), amax #(kmx.y, p.y), amax #(kmx.z, p.z)]
            )
            -- Пивот (схема: центр bbox крышек базы x плоскость нижнего контура):
            -- 1. Локальная ось Z проходит через ЦЕНТР bbox крышек базы (capCenter);
            -- 2. нижний контур по локальной оси Z - петля профиля с минимальной
            --    проекцией на dir - лежит в плоскости, перпендикулярной оси;
            -- 3. пивот = пересечение этой плоскости с локальной осью Z.
            -- Расчёт ведётся в МИРОВЫХ координатах по петлям loopsW (frame сплайна
            -- и .pivot у node задаются в мире - после упрощения узлы могут лежать
            -- в мировых координатах, поэтому локальными Z из getKnotPoint не
            -- пользоваться). Для плоской базы это совпадает с capCenter.
            local tPlane = 1e30
            for lp in loopsW do for pt in lp do
                if (dot pt dir) < tPlane do tPlane = (dot pt dir)
            local pivZ = tPlane - (dot capCenter dir)
            ss.pivot = capCenter + (pivZ * dir)
            local zspan = kmx.z - kmn.z
            local flat = zspan <= (diag * 0.0001)
            if REMS_debug do (
                if flat then (
                    format "  пивот: база плоская - ось Z через центр bbox крышек, tPlane=%: [%,%,%]\n" tPlane ss.pivot.x ss.pivot.y ss.pivot.z
                ) else (
                    format "  пивот: база не плоская (Z разброс %) - ось Z через центр bbox крышек пересекает нижний контур (tPlane=%): [%,%,%]\n" zspan tPlane ss.pivot.x ss.pivot.y ss.pivot.z
                )
            )
        )
        -- СОХРАНЕНИЕ MATERIAL ID ИСХОДНИКА (если REMS_preserveMatIDs=true):
        -- верхняя/нижняя крышка и торец. Верх определяется по +лок. Z
        -- (tmFacade.row3) - ВСЕГДА, независимо от знака extrudeAmount: при
        -- отрицательном выдавливании верх - это и есть база после разворота.
        local miTop = undefined
        local miBottom = undefined
        local miSide = undefined
        if REMS_preserveMatIDs do (
            miSide = REMS_collectGroupMatID p sideBits
            if loopsP.count > 0 and capBits.numberSet > 0 do (
                -- разделить все крышки на две торцевые группы по знаку проекции
                -- их центроидов на локальную ось Z (относительно средней)
                local zAx = tmFacade.row3
                local projSum = 0.0
                local cnt = 0
                local proj = #()
                for f in capBits do (
                    local d = dot (polyop.getFaceCenter p f) zAx
                    append proj #(f, d)
                    projSum += d
                    cnt += 1
                )
                if cnt > 0 do (
                    local midV = projSum / cnt
                    local topBits = #{}; topBits.count = capBits.count
                    local botBits = #{}; botBits.count = capBits.count
                    for pr in proj do (
                        if pr[2] >= midV then topBits[pr[1]] = true
                        else botBits[pr[1]] = true
                    )
                    miTop = REMS_collectGroupMatID p topBits
                    miBottom = REMS_collectGroupMatID p botBits
                )
            )
        )
        -- Выбор стека: дефолт Extrude / Extrude+MaterialID / Shell+UVWMap+UVWXform
        --  - MatID исходника == дефолт Extrude (верх=1, низ=2, торец=3): ничего
        --    не добавляем, обычный Extrude;
        --  - все MatID одинаковые: Extrude + модификатор MaterialID(force);
        --  - иной набор: вместо Extrude - Shell + UVWMap (plane 1 м) + UVW Xform,
        --    чтобы воспроизвести свой набор ID на крышках и торце.
        local useCustomStack = false
        local useMatIDOverride = false
        if REMS_preserveMatIDs and miTop != undefined and miBottom != undefined and miSide != undefined then (
            if miTop == 1 and miBottom == 2 and miSide == 3 then (
                if REMS_debug do format "  MatID совпадает с дефолтом Extrude (1/2/3) - Extrude без доп.\n"
            ) else if miTop == miBottom and miBottom == miSide then (
                format "REMS: '%': MatID одинаковые (%) - Extrude + MaterialID\n" ssName miTop
                useMatIDOverride = true
            ) else (
                format "REMS: '%': свой набор MatID (верх=% низ=% торец=%) - Shell+UVWMap+UVW Xform\n" ssName miTop miBottom miSide
                useCustomStack = true
            )
        )
        if useCustomStack then (
            -- SHELL путь: порядок модификаторов UVWMap -> Shell -> UVW Xform
            local stackOk = true
            try (
                local planeSize = REMS_mmToSys 1000
                local uv = UVWMap()
                uv.maptype = 0
                uv.length = planeSize
                uv.width = planeSize
                uv.height = planeSize
                addModifier ss uv
                local sh = Shell()
                if extrudeAmount >= 0 then (
                    sh.outerAmount = extrudeAmount
                    sh.innerAmount = 0.0
                ) else (
                    sh.innerAmount = -extrudeAmount
                    sh.outerAmount = 0.0
                )
                sh.overrideMatID       = true
                sh.matID       = miSide
                sh.overrideInnerMatID = true
                sh.matInnerID  = miBottom
                sh.overrideOuterMatID = true
                sh.matOuterID  = miTop
                addModifier ss sh
                local ux = UVW_Xform()
                local tile = 1.0 / (REMS_mmToSys 1000)
                ux.U_Tile = tile
                ux.V_Tile = tile
                ux.W_Tile = tile
                ux.U_Flip = false
                ux.V_Flip = false
                ux.W_Flip = false
                addModifier ss ux
                exAdded = true
            ) catch (
                stackOk = false
                format "REMS: ошибка Shell пути '%': %\n" ssName (getCurrentException())
            )
            if not stackOk do format "REMS: '%': Shell НЕ ДОБАВЛЕН\n" ssName
        ) else (
            -- EXTRUDE путь (дефолт или + MaterialID для одинаковых ID)
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
            if useMatIDOverride and exAdded then (
                try (
                    local mi = MaterialID()
                    mi.materialID = miTop
                    addModifier ss mi
                ) catch (
                    format "REMS: ошибка MaterialID '%': %\n" ssName (getCurrentException())
                )
            )
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
    -- временный полигон-конвертер удаляется в любом случае (в т.ч. при пропуске)
    try (delete p) catch ()
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
        messageBox "Выделите объекты-геометрию для обработки." title:"Rebuild Mesh to Spline"
    ) else (
        local useWallHint = keyboard.shiftPressed      -- Shift: подсказка оси (фолбэк): стена
        local useMaxSide = keyboard.altPressed         -- Alt: направление выдавливания (база max)
        local useSimple = not keyboard.controlPressed  -- Ctrl: упрощение вкл/выкл
        format "REMS: ось автоматическая% упрощение=%, объектов: %, REMS_deleteSourceObjects=%\n" \
            ((if useWallHint then " + подсказка стены (Shift)" else "") + \
                (if useMaxSide then ": база max (экструзия вниз)" else ": база min (экструзия вверх)")) \
            (if useSimple then "вкл" else "выкл") \
            geoObjs.count REMS_deleteSourceObjects
        local created = #()
        local total = geoObjs.count
        local processed = 0
        local cancelled = false
        progressStart ("Rebuild Mesh to Spline: " + (total as string) + " объектов, Esc - отмена")
        undo "Rebuild Mesh to Spline" on (
            for o in geoObjs do (
                if not (isValidNode o) do continue
                -- отмена (Esc) проверяется между объектами; откат - общим undo ниже
                if keyboard.escPressed then (cancelled = true; exit)
                local newOnes = #()
                --try (
					newOnes = REMS_processObject o useMaxSide:useMaxSide doSimplify:useSimple wall:useWallHint
				/*) catch (
                    local nm = "<удалён>"
                    try (nm = o.name) catch ()
                    format "REMS: ошибка обработки '%': %\n" nm (getCurrentException())
                )*/
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
                title:"Rebuild Mesh to Spline"
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
