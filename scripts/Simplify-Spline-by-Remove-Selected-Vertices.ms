/* @PankovEA scripts - 2025.08.03 alpha

Скрипт для упрощения сплайнов. Обязательно базовый объект EditableSpline или Line. Модификатор работать не будет.

* В случае выделения вершин, удаляет группу последовательных вершин и стремится созранить форму.
* В случае выделения сплайнов сам определяет какие вершины можно удалить и удалет их. (данный режим экспериментальный)

Для работы необходим Matrix.ms в папке со скриптом.

Нужно выделить удаляемые вершины в сплайне (не в модификаторе) и запустить run_simplifySpline(). Пока общумываю в каком виде оформить макроскрипт.

Не обрабатывает крайние вершины. Первую и последнюю в замкнутом сплайне удалить не получится.
Так же есть проблемы, если вершины угловые. Они все должны иметь направляющие в данной реализации

--

Script to simplify splines. The base EditableSpline or Line object is required. The modifier won't work.

* If vertices are selected, it deletes a group of consecutive vertices and strives to restore the shape.
* If splines are selected, it determines which vertices can be deleted and deletes them. (This mode is experimental)

To work, you need Matrix.ms in the script folder. Matrix docs

You need to select the vertices to be deleted in the spline (not in the modifier) and run run_simplifySpline().
I'm still trying to figure out how to format the macro script.

Does not process extreme vertices. You will not be able to delete the first and last in a closed spline.
There are also problems if the vertices are angular. They should all have guides in this implementation.
*/


fileIn "Matrix.ms" -- Добавить функционал для работы с матриами. Файл должен лежать в одной папке с данным скриптом

global SS_DEBUG = false -- установить в true в Listener'е для подробного вывода расхождений по каждому сэмплу

/* --------------------
--
-- Функции для выделения базовых вершин
--
*/ --------------------

fn calculatePlaneNormal p1 p2 p3 =
(
    local v1 = normalize (p2 - p1)
    local v2 = normalize (p3 - p2)
    local normal = cross v1 v2
    if (length normal) > 0.0001 then normal = normalize normal
    return normal
)

fn computeSignedAngle v1 v2 referenceNormal =
(
    v1 = normalize v1
    v2 = normalize v2
    local ang = acos (dot v1 v2)
    local crossProduct = cross v1 v2
    local direction = dot crossProduct referenceNormal
    return if direction >= 0 then ang else -ang
)

fn getSplinePoint points index isClosedSpline =
(
    local pointCount = points.count
    if isClosedSpline then
    (
        local wrappedIndex = mod (index - 1 + pointCount) pointCount + 1
        return points[wrappedIndex]
    )
    else
    (
        local clampedIndex = clamp index 1 pointCount
        return points[clampedIndex]
    )
)

fn findSupportPoints points isClosedSpline =
(
    local pointCount = points.count
    if pointCount < 3 then return #(1, pointCount)
    
    local supportPoints = #()
    
    -- Инициализация для первых точек
    local p0 = getSplinePoint points (if isClosedSpline then pointCount else 1) isClosedSpline
    local p1 = getSplinePoint points 1 isClosedSpline
    local p2 = getSplinePoint points 2 isClosedSpline
    
    local referencePlaneNormal = calculatePlaneNormal p0 p1 p2
    local lastPlaneNormal = referencePlaneNormal
    
    -- Счётчики
    local currentPlanarAngleSum = 0.0
    local currentTorsionAngleSum = 0.0
    local inflectionCount = 0
    local torsionInflectionCount = 0
    local lastPlanarAngleSign = 0
    local lastTorsionAngleSign = 0
    local planarDirectionAfterInflection = 0
    local torsionDirectionAfterInflection = 0
    
    local endIndex = if isClosedSpline then pointCount else (pointCount - 1)
    
    for i = 2 to endIndex do
    (
        -- Получаем точки с учётом замкнутости
        local prevPoint = getSplinePoint points (i-1) isClosedSpline
        local currPoint = getSplinePoint points i isClosedSpline
        local nextPoint = getSplinePoint points (i+1) isClosedSpline
        local nextNextPoint = getSplinePoint points (i+2) isClosedSpline
        
        -- Плоскостные вычисления (для кручения)
        if (i >= 3) or (isClosedSpline and i >= 2) then
        (
            local currentPlaneNormal = calculatePlaneNormal prevPoint currPoint nextPoint
            
            if (i > 3) or (isClosedSpline and i >= 3) then
            (
                local dotProduct = dot lastPlaneNormal currentPlaneNormal
                dotProduct = clamp dotProduct -1.0 1.0
                local torsionAngle = acos dotProduct
                
                local torsionAxis = cross lastPlaneNormal currentPlaneNormal
                local torsionDirection = dot torsionAxis referencePlaneNormal
                local torsionAngleSigned = if torsionDirection >= 0 then torsionAngle else -torsionAngle
                
                currentTorsionAngleSum += abs torsionAngle
                
                local torsionAngleSign = if torsionAngleSigned > 0.001 then 1 else if torsionAngleSigned < -0.001 then -1 else 0
                
                if (torsionAngleSign != lastTorsionAngleSign) and (lastTorsionAngleSign != 0) then
                (
                    torsionInflectionCount += 1
                    if torsionInflectionCount == 1 then
                    (
                        torsionDirectionAfterInflection = torsionAngleSign
                    )
                    else if torsionAngleSign != torsionDirectionAfterInflection then
                    (
                        append supportPoints (i-1)
                        -- Сброс счётчиков
                        currentPlanarAngleSum = 0.0
                        currentTorsionAngleSum = 0.0
                        inflectionCount = 0
                        torsionInflectionCount = 0
                        lastPlanarAngleSign = 0
                        lastTorsionAngleSign = 0
                        planarDirectionAfterInflection = 0
                        torsionDirectionAfterInflection = 0
                        continue
                    )
                )
            )
            lastPlaneNormal = currentPlaneNormal
        )
        
        -- Планарные вычисления
        local v1 = currPoint - prevPoint
        local v2 = nextPoint - currPoint
        
        if (length v1) < 0.0001 or (length v2) < 0.0001 then continue
        
        local planarAngle = computeSignedAngle v1 v2 lastPlaneNormal
        
        if (abs planarAngle) < 2.0 then continue -- MIN_ANGLE_THRESHOLD
        
        currentPlanarAngleSum += abs planarAngle
        
        local planarAngleSign = if planarAngle > 0.001 then 1 else if planarAngle < -0.001 then -1 else 0
        
        if (planarAngleSign != lastPlanarAngleSign) and (lastPlanarAngleSign != 0) then
        (
            inflectionCount += 1
            if inflectionCount == 1 then
            (
                planarDirectionAfterInflection = planarAngleSign
            )
            else if planarAngleSign != planarDirectionAfterInflection then
            (
                append supportPoints (i-1)
                -- Сброс счётчиков
                currentPlanarAngleSum = 0.0
                currentTorsionAngleSum = 0.0
                inflectionCount = 0
                torsionInflectionCount = 0
                lastPlanarAngleSign = 0
                lastTorsionAngleSign = 0
                planarDirectionAfterInflection = 0
                torsionDirectionAfterInflection = 0
                continue
            )
        )
        
        -- Проверка лимитов
        if (currentPlanarAngleSum >= 90.0) or 
           (currentTorsionAngleSum >= 90.0) or
           (inflectionCount > 1) or 
           (torsionInflectionCount > 2) then
        (
            append supportPoints (i-1)
            -- Сброс счётчиков
            currentPlanarAngleSum = 0.0
            currentTorsionAngleSum = 0.0
            inflectionCount = 0
            torsionInflectionCount = 0
            lastPlanarAngleSign = 0
            lastTorsionAngleSign = 0
            planarDirectionAfterInflection = 0
            torsionDirectionAfterInflection = 0
        )
        
        lastPlanarAngleSign = planarAngleSign
        lastTorsionAngleSign = torsionAngleSign
    )
    
    -- Добавляем первую и последнюю точки
    if (findItem supportPoints 1) == 0 then append supportPoints 1
    if (findItem supportPoints pointCount) == 0 then append supportPoints pointCount
    
    -- Для замкнутого сплайна проверяем замыкание
    if isClosedSpline then
    (
        local firstTangent = (points[2]) - (points[1])
        local lastTangent = (points[1]) - (points[pointCount])
        if (length firstTangent) > 0.0001 and (length lastTangent) > 0.0001 then
        (
            firstTangent = normalize firstTangent
            lastTangent = normalize lastTangent
            local closingAngle = acos (dot firstTangent lastTangent)
            if closingAngle > 45.0 then
            (
                if (findItem supportPoints 1) == 0 then append supportPoints 1
            )
        )
    )
    
    return supportPoints
)

/* --------------------
--
-- Функции для удаления выделенных вершин
--
*/ --------------------

/* --- Самодостаточная геометрия участка сплайна ---
   Позиции и длины считаются напрямую по контрольным точкам Безье.
   Это исключает путаницу с параметризацией встроенных функций
   (interpCurve3D принимает параметр в пространстве индексов сегментов, а не длину). */

-- Точка на кубической Безье при параметре t
fn bezierPointAt p0 p1 p2 p3 t = (
    local mt = 1.0 - t
    ((mt*mt*mt) * p0) + ((3*mt*mt*t) * p1) + ((3*mt*t*t) * p2) + ((t*t*t) * p3)
)

-- Производная кубической Безье при параметре t
fn bezierDerivAt p0 p1 p2 p3 t = (
    local mt = 1.0 - t
    (3*mt*mt)*(p1-p0) + (6*mt*t)*(p2-p1) + (3*t*t)*(p3-p2)
)

-- Точка на сегменте seg при локальном параметре t (учитывает тип сегмента и шов замкнутого сплайна)
fn evalSplineSegment spline s_num seg t = (
    local kB = if seg == (numknots spline s_num) then 1 else seg + 1
    if (getSegmentType spline s_num seg) == #line then (
        local pa = getKnotPoint spline s_num seg
        local pb = getKnotPoint spline s_num kB
        pa + (pb - pa) * t
    ) else (
        bezierPointAt (getKnotPoint spline s_num seg) (getOutVec spline s_num seg) \
                      (getInVec spline s_num kB) (getKnotPoint spline s_num kB) t
    )
)

-- Производная по t на сегменте seg
fn evalSplineSegmentDeriv spline s_num seg t = (
    local kB = if seg == (numknots spline s_num) then 1 else seg + 1
    if (getSegmentType spline s_num seg) == #line then (
        (getKnotPoint spline s_num kB) - (getKnotPoint spline s_num seg)
    ) else (
        bezierDerivAt (getKnotPoint spline s_num seg) (getOutVec spline s_num seg) \
                      (getInVec spline s_num kB) (getKnotPoint spline s_num kB) t
    )
)

fn splineSegCount spline s_num = (
    local nk = numknots spline s_num
    if nk >= 2 and (isClosed spline s_num) then nk else nk - 1
)

-- Кумулятивные длины сегментов: массив из nseg+1 значений, cum[i] = длина до узла i.
-- Длина сегмента считается квадратурой Гаусса-Лежандря (8 точек) - точно для кубик.
fn buildSplineCumLengths spline s_num = (
    local nseg = splineSegCount spline s_num
    local glT = #(-0.96028985649753620, -0.79666647741362670, -0.52546409566427920, -0.18343464249564980, \
                   0.18343464249564980,  0.52546409566427920,  0.79666647741362670,  0.96028985649753620)
    local glW = #( 0.10122853629037624,  0.22238103445337450,  0.31370664587788730,  0.36268378337836198, \
                   0.36268378337836198,  0.31370664587788730,  0.22238103445337450,  0.10122853629037624)
    local cum = #(0.0)
    local acc = 0.0
    for seg = 1 to nseg do (
        local halfLen = 0.0
        for k = 1 to 8 do (
            local t = 0.5 * (glT[k] + 1.0)
            halfLen += glW[k] * (length (evalSplineSegmentDeriv spline s_num seg t))
        )
        halfLen *= 0.5
        acc += halfLen
        append cum acc
    )
    cum
)

-- Точка на сплайне на расстоянии l от начала (по таблице длин cum)
fn getSplinePosAtLen spline s_num cum l = (
    local nseg = cum.count - 1
    local lo = 1
    local hi = nseg
    while lo < hi do (
        local mid = (lo + hi) / 2
        if cum[mid + 1] < l then lo = mid + 1 else hi = mid
    )
    local slen = cum[lo + 1] - cum[lo]
    local t = if slen > 0.0 then (l - cum[lo]) / slen else 0.0
    if t < 0.0 then t = 0.0
    if t > 1.0 then t = 1.0
    evalSplineSegment spline s_num lo t
)

-- Возвращает #(lenAtKnotA, regionLen, totalLen, cum): длина до узла kA, длина участка kA->kB,
-- полная длина сплайна и таблица длин. Для замкнутого сплайна переход через шов (kB < kA) учитывается.
fn getRegionParams spline s_num kA kB = (
    local cum = buildSplineCumLengths spline s_num
    local totalLen = cum[cum.count]
    local lenA = cum[kA]
    local lenB = cum[kB]
    local regionLen = lenB - lenA
    if regionLen < 0.0 then (
        if (isClosed spline s_num) then regionLen += totalLen -- замкнутый сплайн, участок через шов
        else regionLen = -1.0 -- разомкнутый сплайн: участок через конец недопустим
    )
    #(lenA, regionLen, totalLen, cum)
)

-- Вспомогательная функция сэмплирования участка сплайна (от узла work_range[1] до work_range[end])
-- равномерно по длине дуги. Возвращает #(#(точка, длина от начала участка), ...).
fn sampleSpline spline s_num work_range totalSamples:100 = (
    local rp = getRegionParams spline s_num work_range[1] work_range[work_range.count]
    local startLen = rp[1]
    local regionLen = rp[2]
    local totalLen = rp[3]
    local cum = rp[4]

    if regionLen <= 0.0 then (
        format "sampleSpline: некорректный участок (regionLen=%) - разомкнутый сплайн?\n" regionLen
        return #()
    )

    local samples = #()
    local n = amax #(totalSamples, 2)
    for i = 0 to n - 1 do (
        local f = i as float / (n - 1)
        local l = startLen + f * regionLen
        if l > totalLen then l -= totalLen -- шов замкнутого сплайна
        append samples #(getSplinePosAtLen spline s_num cum l, f * regionLen)
    )
    if SS_DEBUG do format "sampleSpline: startLen=% regionLen=% totalLen=% samples=%\n" startLen regionLen totalLen samples.count
    samples
)


-- Расстояние от точки p до отрезка [a,b]
fn pointSegDist p a b =
(
    local ab = b - a
    local l2 = dot ab ab
    local tt = if l2 > 0.0 then (dot (p - a) ab) / l2 else 0.0
    tt = clamp tt 0.0 1.0
    distance p (a + ab * tt)
)

-- Функция для проверки результата. Основная метрика - отклонение исходных сэмплов от
-- БЛИЖАЙШЕЙ точки новой кривой (геометрическое отклонение формы).
-- Дополнительно выводится сравнение по совпадению доли длины (для справки).
fn checkSamples spline s_num work_range samples =
(
    local rp = getRegionParams spline s_num work_range[1] work_range[work_range.count]
    local startLen = rp[1]
    local newRegionLen = rp[2]
    local totalLen = rp[3]
    local cum = rp[4]
    local origRegionLen = samples[samples.count][2] -- Общая длина аппроксимируемого участка

    -- плотная полилиния новой кривой на участке
    local polyCount = amax #(samples.count * 6, 400)
    local poly = for j = 0 to polyCount collect (
        local l = startLen + (j as float / polyCount) * newRegionLen
        if l > totalLen then l -= totalLen
        getSplinePosAtLen spline s_num cum l
    )

    local errorsNear = #()
    local errorsParam = #()
    local totalNear = 0.0
    local totalParam = 0.0

    for i = 1 to samples.count do
    (
        -- геометрическое отклонение: минимум расстояния до полилинии
        local dBest = 1e30
        for j = 1 to poly.count - 1 do (
            local dd = pointSegDist samples[i][1] poly[j] poly[j + 1]
            if dd < dBest do dBest = dd
        )
        append errorsNear dBest
        totalNear += dBest

        -- сравнение по доле длины (параметрическое, для справки)
        local f = samples[i][2] / origRegionLen
        local lp = startLen + f * newRegionLen
        if lp > totalLen then lp -= totalLen
        local errP = distance samples[i][1] (getSplinePosAtLen spline s_num cum lp)
        append errorsParam errP
        totalParam += errP

        if SS_DEBUG do format "  sample %: pos=% errNearest=% errParam=%\n" i samples[i][1] dBest errP
    )

    local avgNearPercent = (totalNear / samples.count) / origRegionLen * 100.0
    local maxNearPercent = (amax errorsNear) / origRegionLen * 100.0
    local avgParamPercent = (totalParam / samples.count) / origRegionLen * 100.0
    local maxParamPercent = (amax errorsParam) / origRegionLen * 100.0

    format "CheckSamples: knots %->% samples=% regionLen % -> % closed=% totalLen=% cumN=%\n" work_range[1] work_range[work_range.count] samples.count origRegionLen newRegionLen (isClosed spline s_num) totalLen cum.count
    if newRegionLen <= 0.0 do format "  ВНИМАНИЕ: длина участка после удаления нулевая - проверьте closed/индексы!\n"
    format "  Nearest-point: Avg % % Max % % (отклонение формы)\n" avgNearPercent "%" maxNearPercent "%"
    format "  Param-matched: Avg % % Max % % (справочно)\n" avgParamPercent "%" maxParamPercent "%"
    #(errorsNear, totalNear, totalNear / origRegionLen * 100.0, avgNearPercent, maxNearPercent, avgParamPercent, maxParamPercent)
)


-- Функция для тестов для отображения сэмплов во вьюпорте. Воздаёт новый сплайн.
fn drawSamples samples nm =
(
    local newSpline = splineShape()
    addNewSpline newSpline
	for p in samples do (
		addKnot newSpline 1 #corner #curve p[1]
	)
	updateshape newSpline
	newSpline.name = nm
		
    return newSpline
)


-- Ближайший параметр t на кубической Безье к точке s (грубый скан + уточнение Ньютоном)
fn bezierClosestT p0 p1 p2 p3 s tGuess = (
    local bestT = 0.0
    local bestD = 1e30
    for k = 0 to 24 do (
        local t = k / 24.0
        local d = distance (bezierPointAt p0 p1 p2 p3 t) s
        if d < bestD do ( bestD = d; bestT = t )
    )
    local tG = clamp tGuess 0.0 1.0
    local dG = distance (bezierPointAt p0 p1 p2 p3 tG) s
    local t = if dG <= bestD then tG else bestT

    for k = 1 to 10 do (
        local mt = 1.0 - t
        local a1 = p1 - p0
        local a2 = p2 - p1
        local a3 = p3 - p2
        local d1 = (3*mt*mt)*a1 + (6*mt*t)*a2 + (3*t*t)*a3
        local d2 = (6*mt)*(a2-a1) + (6*t)*(a3-a2)
        local r = (bezierPointAt p0 p1 p2 p3 t) - s
        local f = dot r d1
        local fd = (dot d1 d1) + (dot r d2)
        if abs fd < 1e-9 then exit
        t -= f / fd
        if t < 0.0 then t = 0.0
        if t > 1.0 then t = 1.0
    )
    t
)

-- Редуцированное МНК-решение: P1 = P0 + a*dir0, P2 = P3 + c*dir1 (dir0/dir1 единичные;
-- нулевой вектор = направление не задано для этого конца).
-- Ограничения направлений выполняются точно, без штрафных строк: система сводится к 2x2
-- и устойчива даже во float на больших координатах сцены.
-- МНК-решение длин хендлов вдоль заданных направлений (см. комментарий к solveHandlesAlongDirs).
fn handleScalarsAlongDirs samples ts dir0 dir1 = (
    local n = samples.count
    local P0 = samples[1][1]
    local P3 = samples[n][1]
    local rel3 = P3 - P0

    local s00 = 0.0; local s01 = 0.0; local s11 = 0.0
    local r0 = 0.0;  local r1 = 0.0

    for i = 1 to n do (
        local t = ts[i]
        local mt = 1.0 - t
        local kEnd = t * t * (3.0 - 2.0 * t) -- доля P3 в фиксированной части K(t)
        local resid = (samples[i][1] - P0) - kEnd * rel3

        local g0 = (3 * mt * mt * t) * dir0
        local g1 = (3 * mt * t * t) * dir1

        s00 += dot g0 g0
        s01 += dot g0 g1
        s11 += dot g1 g1
        r0  += dot g0 resid
        r1  += dot g1 resid
    )

    local det = s00 * s11 - s01 * s01
    local tol = 1e-9 * (amax #(s00, s11, 1.0))
    local aa = 0.0
    local cc = 0.0
    if (abs det) > tol then (
        aa = (s11 * r0 - s01 * r1) / det
        cc = (s00 * r1 - s01 * r0) / det
    )
    else (
        -- вырожденный случай: одно из направлений не задано (нулевое) либо базисы коллинеарны
        aa = if s00 > tol then r0 / s00 else 0.0
        cc = if s11 > tol then r1 / s11 else 0.0
    )
    -- неотрицательность длин хендлов; при клампе переучитываем оставшийся
    if aa < 0.0 then (
        aa = 0.0
        cc = if s11 > tol then r1 / s11 else 0.0
        if cc < 0.0 then cc = 0.0
    )
    else if cc < 0.0 then (
        cc = 0.0
        aa = if s00 > tol then r0 / s00 else 0.0
        if aa < 0.0 then aa = 0.0
    )
    #(aa, cc)
)

fn solveHandlesAlongDirs samples ts dir0 dir1 = (
    local P0 = samples[1][1]
    local P3 = samples[samples.count][1]
    local ac = handleScalarsAlongDirs samples ts dir0 dir1
    #((P0 + ac[1] * dir0), (P3 + ac[2] * dir1))
)

-- функция для решения системы уравнений минимизирующих ошибку.
-- ts - параметры сэмплов в [0,1]. origOutVec/origInVec - направления касательных на концах (опционально).
fn fitBezierToSamples samples ts origOutVec:[0,0,0] origInVec:[0,0,0] dirWeight:100.0 =
(
    local numSamples = samples.count
    if numSamples < 2 then return #(samples[1][1], samples[numSamples][1])

    local P0 = samples[1][1]
    local P3 = samples[numSamples][1]
    local totalLength = samples[numSamples][2]
    if totalLength <= 0.0 then return #(P0, P3)

    local hasDir0 = (length origOutVec) > 0.0001
    local hasDir1 = (length origInVec) > 0.0001

    if hasDir0 or hasDir1 then (
        -- Основной путь: точное решение вдоль заданных направлений
        local d0 = if hasDir0 then (normalize origOutVec) else [0,0,0]
        local d1 = if hasDir1 then (normalize origInVec) else [0,0,0]
        return solveHandlesAlongDirs samples ts d0 d1
    )

    -- Свободный фит без ограничений (направления не заданы): общая система на 6 неизвестных.
    -- Работаем в координатах относительно P0: сцены бывают сотни тысяч единиц,
    -- а нормальные уравнения в float теряют точность на больших смещениях.
    local base = P0
    local rel3 = P3 - base

    local A = Matrix (numSamples * 3) 6 0.0
    local b = Matrix (numSamples * 3) 1 0.0

    -- Аппроксимация кривой
    for i = 1 to numSamples do
    (
        local t = ts[i]
        local mt = 1 - t
        local mt2 = mt * mt
        local t2 = t * t

        local coeffV0 = 3 * mt2 * t
        local coeffV1 = 3 * mt * t2
        local known = (t2 * t) * rel3 -- член с (P0-base) равен нулю
        local residual = (samples[i][1] - base) - known

        local rowX = (i-1)*3 + 1
        A.data[rowX][1] = coeffV0
        A.data[rowX][4] = coeffV1
        b.data[rowX][1] = residual.x

        local rowY = (i-1)*3 + 2
        A.data[rowY][2] = coeffV0
        A.data[rowY][5] = coeffV1
        b.data[rowY][1] = residual.y

        local rowZ = (i-1)*3 + 3
        A.data[rowZ][3] = coeffV0
        A.data[rowZ][6] = coeffV1
        b.data[rowZ][1] = residual.z
    )

    local AT_ = A.transpose()
    local AT_A = AT_.multiplyByMatrix A
    local AT_b = AT_.multiplyByVector b

    local invAT_A = AT_A.inverse()
    if invAT_A == undefined then return #(P0, P3)

    local solution = invAT_A.multiplyByVector AT_b
    if solution == undefined then return #(P0, P3)

    local P1 = [solution.data[1][1], solution.data[2][1], solution.data[3][1]] + base
    local P2 = [solution.data[4][1], solution.data[5][1], solution.data[6][1]] + base

    return #(P1, P2)
)

-- Проекция сэмплов на текущую кривую Безье с принудительной монотонностью параметров.
-- Возвращает НОВЫЙ массив ts.
fn reprojectSamplesOntoBezier samples ts P0 P1 P2 P3 = (
    local n = samples.count
    local resTs = deepcopy ts
    local prevT = 0.0
    for i = 2 to n - 1 do (
        local t = bezierClosestT P0 P1 P2 P3 samples[i][1] ts[i]
        if t < prevT then t = prevT -- монотонность параметров
        resTs[i] = t
        prevT = t
    )
    resTs
)

-- Сумма квадратов расстояний от сэмплов до кривой при данных (уже спроецированных) ts -
-- это и есть минимизируемая "ближайшая точка" метрика.
fn projectedResidualSum samples ts P0 P1 P2 P3 = (
    local ss = 0.0
    for i = 1 to samples.count do (
        local d = (bezierPointAt P0 P1 P2 P3 ts[i]) - samples[i][1]
        ss += dot d d
    )
    ss
)

-- Мультистарт-фит вдоль заданных направлений касательных.
-- Чередование "проекция -> МНК" имеет локальные basin'ы: старт только из арк-длины
-- может сойтись к заметно худшей кривой. Перебираем несколько стартовых длин хендлов,
-- для каждого гоним чередование до сходимости и оставляем кандидата с минимальной
-- суммой ближайших расстояний.
fn fitConstrainedMultiStart samples dir0 dir1 iterations:6 = (
    local n = samples.count
    local regionLen = samples[n][2]
    local P0 = samples[1][1]
    local P3 = samples[n][1]
    local chordLen = length (P3 - P0)

    local ts0 = for i = 1 to n collect if regionLen > 0.0 then samples[i][2] / regionLen else 0.0

    -- 0.0 => старт напрямую из арк-длины без начальной кривой; остальные - доли хорды
    local fracs = #(0.0, 0.34, 0.5, 0.67)

    local bestParams = undefined
    local bestScore = 1e30
    for f in fracs do (
        local params
        local ts
        if f <= 0.0 then (
            params = solveHandlesAlongDirs samples ts0 dir0 dir1
            ts = reprojectSamplesOntoBezier samples ts0 P0 params[1] params[2] P3
        )
        else (
            -- стартовая кривая с симметричными хендлами заданной доли хорды
            local hlen = f * chordLen
            params = #((P0 + hlen * dir0), (P3 + hlen * dir1))
            ts = reprojectSamplesOntoBezier samples ts0 P0 params[1] params[2] P3
        )
        for iter = 2 to iterations while chordLen > 0.0 do (
            params = solveHandlesAlongDirs samples ts dir0 dir1
            ts = reprojectSamplesOntoBezier samples ts P0 params[1] params[2] P3
        )
        local score = projectedResidualSum samples ts P0 params[1] params[2] P3
        if SS_DEBUG do format "  multistart f=% score=% a=% c=%\n" f (sqrt score) (length (params[1] - P0)) (length (P3 - params[2]))
        if score < bestScore then (
            bestScore = score
            bestParams = params
        )
    )
    bestParams
)


-- Фит с итеративной репараметризацией: сэмплы проецируются на текущую кривую,
-- параметры обновляются и фит повторяется. На сходимости это минимизирует именно
-- ортогональное (ближайшая точка) отклонение, а не совпадение по параметру.
-- При заданных направлениях касательных используется мультистарт (см. fitConstrainedMultiStart).
fn fitBezierIterative samples origOutVec:[0,0,0] origInVec:[0,0,0] iterations:5 dirWeight:100.0 =
(
    local n = samples.count
    local regionLen = samples[n][2]

    if (length origOutVec) > 0.0001 or (length origInVec) > 0.0001 then (
        local d0 = if (length origOutVec) > 0.0001 then (normalize origOutVec) else [0,0,0]
        local d1 = if (length origInVec) > 0.0001 then (normalize origInVec) else [0,0,0]
        return fitConstrainedMultiStart samples d0 d1 iterations:(amax #(iterations + 1, 6))
    )

    local ts = for i = 1 to n collect samples[i][2] / regionLen

    local params = fitBezierToSamples samples ts dirWeight:dirWeight

    for iter = 1 to iterations while regionLen > 0.0 do
    (
        local P0 = samples[1][1]
        local P3 = samples[n][1]
        local P1 = params[1]
        local P2 = params[2]
        local prevT = 0.0
        for i = 2 to n - 1 do (
            local t = bezierClosestT P0 P1 P2 P3 samples[i][1] ts[i]
            if t < prevT then t = prevT -- монотонность параметров
            ts[i] = t
            prevT = t
        )
        params = fitBezierToSamples samples ts dirWeight:dirWeight
    )
    params
)


-- Выбор направления касательной на границе участка. Хендл соседнего узла доверяем,
-- только если он согласован с направлением самих данных участка (dot >= cosThreshold).
-- Иначе узел угловой/шовный, и принудительная касательность уводит фит в сторону.
fn pickBoundaryDir dataSecant neighborVec cosThreshold = (
    local dd = normalize dataSecant
    if (length dd) < 0.0001 then return [0,0,0]
    if (length neighborVec) > 0.0001 then (
        local nd = normalize neighborVec
        local agree = dot nd dd
        if agree >= cosThreshold then nd else (
            format "  pickBoundaryDir: хендл соседа противоречит данным участка (dot=%), беру направление данных\n" agree
            dd
        )
    ) else dd
)


-- Основная функция для удаления подряд идущих вершин (не крайних) с сохранением кривизны
fn simplifySpline spline s_num vert_selection samplesPerSegment:100 refitIterations:5 dirWeight:100.0 =
(
	local test = false
	local iStart = vert_selection[1]
	local iEnd = vert_selection[vert_selection.count]
	local nknots = numknots spline s_num

	local pre_start = if iStart == 1 then nknots else (iStart - 1)
	local after_end = if iEnd == nknots then 1 else (iEnd + 1)

	local work_range = #(pre_start)
	for i in vert_selection do append work_range i
	append work_range after_end
	format "work_range=% \n" work_range

    local samples = sampleSpline spline s_num work_range totalSamples:samplesPerSegment
    if samples.count < 2 then (
        format "simplifySpline: участок некорректен, узлы не удаляю (выделение %)\n" vert_selection
        return undefined
    )
    local P0 = samples[1][1]
    local P3 = samples[samples.count][1]

    --format "simplifySpline: P0=% P3=%\n" P0 P3

	if test then (
		format "samples:\n"
		for s in samples do (
			format "point=%; paam=%\n" s[1] s[2])
		format "end samples\n"
		drawSamples samples "samples"
	)

	-- Направление данных у границ участка (секущая на ~10% длины)
	local step10 = amax #((samples.count / 10), 2)
	local leadIdx = amin #(1 + step10, samples.count)
	local tailIdx = amax #(samples.count - step10, 1)
	local dataSecant0 = samples[leadIdx][1] - P0
	local dataSecant1 = samples[tailIdx][1] - P3

	-- Хендл соседа используем только если он согласован с данными, иначе - направление данных
	local origOutVec = pickBoundaryDir dataSecant0 (getOutVec spline s_num pre_start - P0) 0.7
	local origInVec = pickBoundaryDir dataSecant1 (getInVec spline s_num after_end - P3) 0.7
	if SS_DEBUG do format "boundary dirs: out=% in=%\n" origOutVec origInVec
	--format "origOutVec=% origInVec=%\n" origOutVec origInVec

	local params = fitBezierIterative samples origOutVec:origOutVec origInVec:origInVec iterations:refitIterations dirWeight:dirWeight

	local P1 = params[1]
	local P2 = params[2]

	if SS_DEBUG do (
		format "fitted handles: |P1-P0|=% |P2-P3|=%\n" (length (P1 - P0)) (length (P3 - P2))
		format "  P0=% P1=% P2=% P3=%\n" P0 P1 P2 P3
	)

	if not test then (
		-- произведём удаление
		setKnotSelection spline s_num #()

		for i in #(pre_start, after_end) do (
			case (getknottype spline s_num i) of (
				#smooth: (setKnotType spline s_num i #bezier)
				#corner: (setKnotType spline s_num i #bezierCorner)
			)
		)
		format "pre_start: %\n" (getknottype spline s_num pre_start)
		format "after_end: %\n" (getknottype spline s_num after_end)

		setOutVec spline s_num pre_start P1
		setInVec spline s_num after_end P2

		local sortedVertSel = sort (for i in vert_selection collect i)
		for i = sortedVertSel.count to 1 by -1 do (
			deleteKnot spline s_num sortedVertSel[i]
		)

		updateShape spline
		format "after delete: numknots=% isClosed=% (было %)\n" (numknots spline s_num) (isClosed spline s_num) nknots

		-- пересчитываем индексы граничных узлов после удаления
		local pre_start_new = pre_start
		local after_end_new = after_end
		for i in sortedVertSel do (
			if i < pre_start then pre_start_new -= 1
			if i < after_end then after_end_new -= 1
		)

		checkSamples spline s_num #(pre_start_new, after_end_new) samples
	) else (
		-- вариант с созданием сплайна для тестов вместо удаления --
		local newSpline = splineShape()
		newSpline.steps = 12
		newSpline.name = "result_fitted"
		addNewSpline newSpline
		addKnot newSpline 1 #bezier #curve P0 P0 P1
		addKnot newSpline 1 #bezier #curve P3 P2 P3
		updateShape newSpline

		--format "Final Control Points: P1=% P2=%\n" P1 P2
		checkSamples spline s_num work_range samples
	)
)

-- вспомогательная функция для выделения групп выделенных вершин
fn getGroups knots isClosedSpline nknots = (
    if knots.count == 0 then return #()
	if knots.count == 1 then return #(knots)
    groups = #(); currentGroup = #(knots[1])
    for i = 2 to knots.count do (
        if knots[i] == knots[i-1] + 1 then append currentGroup knots[i] 
        else (append groups currentGroup; currentGroup = #(knots[i]))
    )
    append groups currentGroup
    groups
)


-- функция обработки выделения в интерфейсе и передача данных в овновную функцию
fn run_simplifySpline = (
	local obj = selection[1]
	if selection.count == 1 \
		and modPanel.getCurrentObject() == obj.baseobject \
		and (subObjectLevel == 1 or subObjectLevel == 3)\ 
		and finditem #(SplineShape, Line) (classof obj.baseobject) > 0 \
	then (
		local spline = obj
		undo on (
			-- выделение опорных точек на выделеннчх сплайнах
			if subobjectlevel == 3 do (
				for s = 1 to numSplines spline do setKnotSelection spline s #() -- нять выделение вершин
				for s_num in getsplineselection spline do (
					local isClosedSpline = isClosed spline s_num

					-- Создаем массив точек для текущего сплайна
					local nKnots = numKnots spline s_num
					local points = for i = 1 to nKnots collect (getKnotPoint spline s_num i)
					
					local supportPoints = findSupportPoints points isClosedSpline
					-- Инвертируем выделение
					deletePoints = for i = 1 to nKnots where (finditem supportPoints i) == 0 collect i
					
					-- Выделяем точки для удаления
					subobjectlevel = 1
					setKnotSelection spline s_num deletePoints
				)
			)
			-- Удаление выделенных вершин
			if subObjectLevel == 1 do (
				for s_num = 1 to numSplines spline do (
					-- format "s_num = %\n" s_num
					knots = getKnotSelection spline s_num
					nKnots = numKnots spline s_num
					isClosedSpline = isClosed spline s_num
					if knots == undefined or knots.count == 0 then continue
					if nKnots - knots.count < 2 then (
						format "Ошибка: после удаления в сплайне % останется менее 2 вершин. выделено % из %\n" s_num knots.count nKnots
						continue
					)

					-- РАЗОМКНУТЫЙ СПЛАЙН: крайние узлы (1 и nKnots) фичить нельзя - у них нет соседа
					-- с одной стороны. Удаляем их напрямую без перестройки кривой и сдвигаем индексы.
					if not isClosedSpline and ((finditem knots 1) > 0 or (finditem knots nKnots) > 0) then (
						local interior = for k in knots where (k != 1 and k != nKnots) collect k
						if (finditem knots nKnots) > 0 do deleteKnot spline s_num nKnots
						if (finditem knots 1) > 0 do (
							deleteKnot spline s_num 1
							for ik = 1 to interior.count do interior[ik] -= 1
						)
						updateShape spline
						knots = interior
						nKnots = numKnots spline s_num
						format "Разомкнутый сплайн %: крайние выделенные узлы удалены напрямую\n" s_num
					)

					isCircularSelection = isClosedSpline and knots.count > 0 and knots[1] == 1 and knots[knots.count] == nKnots
					groups = getGroups knots isClosedSpline nKnots
					if groups.count == 0 and knots.count > 0 then (
						format "Ошибка: Некорректная выборка в сплайне %\n" s_num
						continue
					)
					if groups.count == 0 then
						continue
					-- запустить основную функцию для групп
					-- сначала удаляем серединное выделение. Порядок с конца, что бы не нарушить нумерацию
					if isCircularSelection then (
						start_i = 2
						end_i = groups.count-1
					) else (
						start_i = 1
						end_i = groups.count
					)
					for i in end_i to start_i by -1 do (
						vert_selection = groups[i]
						simplifySpline spline s_num vert_selection -- useOriginalDirections:true
					)
					-- в конце, если круговое выделение, то нужно пересчитать индесы выделения, потому что они изменились
					if isCircularSelection then (
						rest_of_knots = numKnots spline s_num
						diff = nKnots - rest_of_knots
						renum_knots = for num_knot in groups[groups.count] collect num_knot - diff
						final_group = renum_knots + groups[1]
						-- format "final_group = % \n" final_group
						simplifySpline spline s_num final_group
					)
				)
			)
		)
	)
	OK
)
