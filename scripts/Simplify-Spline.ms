/* @PankovEA scripts - 2026.08.27

Скрипт упрощения и восстановления сплайнов.
Базовый объект: Editable Spline (SplineShape/Line/Editable_Spline); работает и при
наличии модификаторов в стеке и при МНОЖЕСТВЕННОМ выделении — обрабатывается каждый
выбранный объект, чей базовый объект является сплайном.

Точки входа (run_rebuildLines, run_rebuildArcs, run_rebuildBezier и мастер
run_simplifySpline) используют единую логику выделения: subobject 0 — все сплайны
(автоматически), 1 — выделенные вершины, 2 — сегменты → обе вершины сегмента
(начало и конец), 3 — выделенные сплайны.
Для subobject 2 режима упрощения крайние вершины каждого выбранного диапазона
СОХРАНЯЮТСЯ (упрощается только внутренность), после обработки диапазоны выделяются
заново по сохранённым позициям границ.

Единая точка входа run_simplifySpline вызывает проходы ПО ПОРЯДКУ:
   1) run_rebuildLines  — слияние коллинеарных сегментов (линии);
   2) run_rebuildArcs   — восстановление дуг;
   3) run_rebuildBezier — сокращение вершин (Шнайдер/эвристика) + сглаживание.
Так после очистки линий положение границ дуг определяется точнее, а узлы дуг
защищены от удаления на проходе Безье (SS_ARC_PROTECTED).

--- Линии (run_rebuildLines) ---

Слияние подряд идущих коллинеарных сегментов ЛЮБОЙ длины в один прямой
сегмент: удаляются внутренние узлы сплошных «прямых» прогонов. Сегмент считается
прямым, если его фактическая длина (buildSplineCumLengths — квадратура по касательной
Безье) равна расстоянию между узлами — у дуг ручки отогнуты, поэтому их узлы этот проход не
трогает даже при большой SS_LINE_STRAIGHT_TOL (допуск поворота на узел, по
умолчанию 2°). Вырожденные сегменты (дублирующиеся узлы, длина ~1e-9) удаляются
с восстановлением ручек Безье соседних узлов.

--- Упрощение (run_rebuildBezier) ---

Удаляет избыточные вершины, сохраняя форму кривой.
Два метода выбора опорных точек:
  1) Schneider (SS_USE_SCHNEIDER = true) — адаптивный рекурсивный фит Безье по плотной
     выборке сплайна; порог острого узла SS_SCHNEIDER_SHARP_ANGLE защищает углы.
  2) Эвристика углов (false) — накопленный планарный/торсионный угол между сегментами.

Защита границы длинного и короткого сегментов (SS_LONGSEG_RATIO / SS_LONGSEG_ANGLE_TOL),
аналогичная run_rebuildArcs: если у вершины соседние сегменты сильно различаются по длине,
а локальный поворот мал, вершина остаётся опорной — длинная прямая не изгибается в фит.

Пост-обработка: выравнивание хендлов почти-прямых узлов (SS_SMOOTH_ANGLE).

--- Восстановление дуг (run_rebuildArcs) ---

Поиск и замена дискретизированных дуг окружности на кубики Безье с точными ручками.
Алгоритм:
  1) Цепочки сегментов с почти одинаковой длиной (допуск SS_ARC_LEN_TOL_PCT).
     Для замкнутых сплайнов цепочка может переходить через шов.
  2) Разбивка по скачкам знаковой кривизне внутри цепочки.
  3) Фит окружности (3 точки + МНК Коса) для каждого поддиапазона.
  4) Замена на ceil(θ/90) кубиков Безье; промежуточные узлы перемещаются на окружность.
  5) Граничные узлы дуг фиксируются на исходных позициях.
   Границы заменённых дуг сохраняются в SS_ARC_PROTECTED и исключаются из удаления.
В режиме сегментов (subobject 2) после обработки выбранные диапазоны сегментов
выделяются заново (границы сохраняются позициями, индексы пересчитываются).

Уточнения к алгоритму:
  - Полная окружность (замкнутый сплайн, цепочка покрывает все сегменты): обрабатывается
    как виртуальный диапазон через шов #(1,segsT); фикс. угол = ±360 (незамкнутый учёт
    шагов недосчитывал 360), узлы-границы дуги ставятся строго равномерно по nSeg, чтобы
    каждый кубик Безье охватывал ровно 360/nSeg (без небольших смещений/перекосов).
    Плотность кольца задаётся SS_ARC_FULLCIRCLE_MAX_SEG_DEG (90° → 4 сегмента).
  - Ручки Безье полной окружности: для шовного узла (startK==headEnd) out-вектор
    НЕ перезаписывается исходным, чтобы касательная оставалась касательной окружности.
  - Защита узлов дуги хранит ПОЗИЦИИ (Point3), а не индексы: после deleteKnot индексы
    промежуточных узлов уезжают («индекс вне диапазона»).
  - Отсечение выбросов по отклонению (SS_ARC_MAX_DEVIATION): дуга определяется по
    «хорошим» точкам (ssArc_fitWithDeviationTrim + ssArc_longestInlierRun), выбросы
    не притягиваются и не удаляются.
  - Проверка ГОТОВОЙ дуги против исходной кривой (как в упрощении): по математике
    ssArc_replaceGroup/replaceGroupWrap заранее воспроизводится полилиния кубиков
    Безье, которые ПОЛУЧАТСЯ, и измеряется max отклонение исходных точек диапазона
    от этой полилинии (ssArc_maxDevToArc). Если дуга не ложится на исходную кривую
    (допуск SS_ARC_VALIDATE_TOL_MULT × радиальный допуск фита), диапазон замены
    сужается до inlier-прогона фита и попытка повторяется; если и это не помогло —
    дуга не создаётся (фильтруется). Так отсекаются дуги, «стартующие не там».


ВАЖНО: глобальные переменные объявлены на верхнем уровне, иначе ссылки внутри функций
компилируются как неявные локальные (всегда undefined).

*/
-- == Настройки ==

-- == Отладка ================================================================
global SS_DEBUG = false


-- == Упрощение (Schneider) ==================================================
-- Использовать адаптивный метод Шнайдера (true) или эвристику углов (false)
global SS_USE_SCHNEIDER = true

-- Допуск отклонения формы Schneider, % от общей длины сплайна
global SS_TOLERANCE_PCT = 0.1

-- Порог острого узла (градусы): угол между in/out касательными
-- Меньше порога → узел считается опорным и не удаляется
global SS_SCHNEIDER_SHARP_ANGLE = 160

-- Защита границы длинного и короткого сегментов (как в run_rebuildArcs/эвристике):
-- если хорды соседних у вершины сегментов различаются >= порога, а локальный поворот
-- (текущий и предыдущий) мал — вершина становится опорной. Иначе длинная прямая рядом
-- с плотной дугой попадает в фит плавного поворота и изгибается.
-- Отношение длин соседних сегментов.
global SS_LONGSEG_RATIO = 4.0
-- Допуск поворота (градусы): считаем продолжение "локально прямым".
global SS_LONGSEG_ANGLE_TOL = 5.0


-- == Восстановление дуг =====================================================
-- Защищённые вершины-границы дуг по индексу сплайна (заполняет run_rebuildArcs)
global SS_ARC_PROTECTED = #()

-- Минимальное число сегментов цепочки для распознавания дуги
global SS_ARC_MIN_CHAIN_SEG = 4

-- Минимальное число сегментов в под-диапазоне для принятия окружности
global SS_ARC_MIN_ARC_SEG = 1

-- Максимальный угловой размер дуги на один кубик Безье (градусы)
global SS_ARC_MAX_SEG_DEGREE = 125

-- Минимальный суммарный угол дуги для распознавания (градусы)
global SS_ARC_MIN_SEG_DEGREE = 25

-- Максимальный угловой размер сегмента Безье для полной окружности (градусы):
-- 45° → кольцо из 8 сегментов, визуально ровная окружность
global SS_ARC_FULLCIRCLE_MAX_SEG_DEG = 90

-- Допуск относительного расхождения длин сегментов при формировании цепочек дуг (%)
global SS_ARC_LEN_TOL_PCT = 25

-- Максимальное отклонение точки от дуги (градусы): если максимальное "отступание"
-- назад по углу больше — группа точек не считается дугой
global SS_ARC_MAX_BACK_DEGREES = 150

-- Максимальный средний шаг по углу для распознавания ПОЛНОЙ окружности (градусы).
-- Окружность дискретизирована множеством мелких сегментов (шаг по углу мал,
-- у типового кольца ~360/N). У правильного многоугольника (квадрат: 4 стороны,
-- 90° на сторону) шаг велик — это не дуга, а геометрическая фигура, которую менять
-- нельзя. Если avgStep > этого порога — полную окружность НЕ заменяем.
global SS_ARC_MAX_STEP_DEG = 45

-- Максимальное радиальное отклонение точки от окружности как доля радиуса.
-- Точки, отклонившиеся сильнее, ИСКЛЮЧАЮТСЯ из замены дугой (не притягиваются и
-- не удаляются), но дуга определяется по оставшимся "хорошим" точкам.
-- Меньше порога — меньше точек попадает в дугу (отсекаются выбросы).
-- 0 = отсечение выключено (дуга заменяется целиком, если все точки в допусках фита).
global SS_ARC_MAX_DEVIATION = 0.01

-- Множитель радиального допуска для ПОВТОРНОЙ проверки готовой дуги против исходных
-- точек (по аналогии с упрощением: исходные сэмплы против новой кривой).
-- Допуск проверки = SS_ARC_VALIDATE_TOL_MULT * max(radTolAbs, radTolRel * R).
-- Допуск фита уже гарантирует «хорошие» точки на окружности; здесь проверяется,
-- что ПОСТРОЕННЫЙ кубик Безье действительно лёг на исходную кривую (старт/конец
-- дуги из верного места). Больше значение = слабее проверка, больше риск дуг мимо
-- кривой; меньше = чаще отсекаются/сужаются даже корректные дуги.
global SS_ARC_VALIDATE_TOL_MULT = 2.0


-- == Сглаживание ============================================================
-- Угол (градусы): если угол между in/out касательными >= порога, хендлы
-- выравниваются в одну линию; 0 — отключить
global SS_SMOOTH_ANGLE = 175.0

-- Допуск (градусы) распознавания "прямой" стороны:
-- Ручка лежит на хорде своего сегмента
global SS_SMOOTH_STRAIGHT_TOL = 5.0

-- Допуск (градусы) коллинеарности для run_rebuildLines: узел удаляется, если
-- входящий и исходящий сегменты продолжают друг друга прямолинейно (длина сегментов
-- не важна). Сами сегменты при этом должны быть прямыми (Безье-длина из
-- buildSplineCumLengths равна хорде) — дуги с отогнутыми ручками такой тест не трогает
-- независимо от допуска.
global SS_LINE_STRAIGHT_TOL = 2.0


/* --------------------
--
-- Функции
--
*/ --------------------

-- SS_ARC_PROTECTED хранит записи #(shp, splineIdx, protList) — защищённые дугами
-- узлы по объекту и номеру сплайна (поддержка нескольких объектов). Ниже — доступ.
fn ssArc_protectedFor shp s_num = (
	local res = #()
	if SS_ARC_PROTECTED == undefined or SS_ARC_PROTECTED.count == 0 then return res
	for rec in SS_ARC_PROTECTED do
		if rec[1] == shp and rec[2] == s_num do (res = rec[3]; exit)
	res
)

fn ssArc_setProtected shp s_num list = (
	global SS_ARC_PROTECTED
	for i = 1 to SS_ARC_PROTECTED.count do (
		local rec = SS_ARC_PROTECTED[i]
		if rec[1] == shp and rec[2] == s_num do (
			SS_ARC_PROTECTED[i] = #(shp, s_num, list)
			return undefined
		)
	)
	append SS_ARC_PROTECTED #(shp, s_num, list)
)

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

fn findSupportPoints points isClosedSpline cornerAngleThreshold:30.0 straightRatioThreshold:4.0 straightAngleTol:5.0 =
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
	local prevTurnSmall = false -- поворот в предыдущей вершине был мал (локально прямое продолжение)
	
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
						prevTurnSmall = false
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
		local absPlanarAngle = abs planarAngle
		local v1len = length v1
		local v2len = length v2
		
		if absPlanarAngle < 2.0 then ( -- MIN_ANGLE_THRESHOLD
			prevTurnSmall = true -- почти идеально прямо
			continue
		)
		
		-- ГРАНИЦА ПРЯМОГО УЧАСТКА И ПОВОРОТА: оба соседних отрезка локально прямые,
		-- но длины сильно различаются. Без опорной точки длинная прямая попадает в фит
		-- плавного поворота и не восстанавливается.
		if prevTurnSmall and absPlanarAngle < straightAngleTol and \
		   (amax #(v1len, v2len)) >= straightRatioThreshold * (amin #(v1len, v2len)) then (
			append supportPoints i
			currentPlanarAngleSum = 0.0
			currentTorsionAngleSum = 0.0
			inflectionCount = 0
			torsionInflectionCount = 0
			lastPlanarAngleSign = 0
			lastTorsionAngleSign = 0
			planarDirectionAfterInflection = 0
			torsionDirectionAfterInflection = 0
			prevTurnSmall = true
			continue
		)
		
		-- ОДНОШАГОВЫЙ РЕЗКИЙ ПОВОРОТ (угол/излом): сама вершина обязана остаться опорной,
		-- иначе упрощение сгладит угол (например 90 градусов). Накопительные счётчики сбрасываем.
		if absPlanarAngle >= cornerAngleThreshold then (
			append supportPoints i
			currentPlanarAngleSum = 0.0
			currentTorsionAngleSum = 0.0
			inflectionCount = 0
			torsionInflectionCount = 0
			lastPlanarAngleSign = 0
			lastTorsionAngleSign = 0
			planarDirectionAfterInflection = 0
			torsionDirectionAfterInflection = 0
			prevTurnSmall = false
			continue
		)
		
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
				prevTurnSmall = false
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
		prevTurnSmall = absPlanarAngle < straightAngleTol
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

-- Ближайший к длине дуги L номер узла; для замкнутого сплайна учитываем переход через шов
fn nearestKnotAtArcLen cum totalLen closedS L nk = (
	local bestK = 1
	local bestDD = 1e30
	for k = 1 to nk do (
		local dd = abs (cum[k] - L)
		if closedS do (
			local dw = totalLen - dd
			if dw < dd do dd = dw
		)
		if dd < bestDD do ( bestDD = dd; bestK = k )
	)
	bestK
)

fn splineSegCount spline s_num = (
	local nk = numknots spline s_num
	if nk >= 2 and (isClosed spline s_num) then nk else nk - 1
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

-- Кумулятивные длины сегментов: массив из nseg+1 значений, cum[i] = длина до узла i.
-- Длина сегмента считается квадратурой Гаусса-Лежандря (8 точек) - точно для кубик.
fn buildSplineCumLengths spline s_num = (
	local nseg = splineSegCount spline s_num
	local glT = #(-0.96028985649753620, -0.79666647741362670, -0.52546409566427920, -0.18343464249564980,
				   0.18343464249564980,  0.52546409566427920,  0.79666647741362670,  0.96028985649753620)
	local glW = #( 0.10122853629037624,  0.22238103445337450,  0.31370664587788730,  0.36268378337836198,
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

	if SS_DEBUG do (
		format "CheckSamples: knots %->% samples=% regionLen % -> % closed=% totalLen=% cumN=%\n" work_range[1] work_range[work_range.count] samples.count origRegionLen newRegionLen (isClosed spline s_num) totalLen cum.count
		if newRegionLen <= 0.0 do format "  ВНИМАНИЕ: длина участка после удаления нулевая - проверьте closed/индексы!\n"
		format "  Nearest-point: Avg % % Max % % (отклонение формы)\n" avgNearPercent "%" maxNearPercent "%"
		format "  Param-matched: Avg % % Max % % (справочно)\n" avgParamPercent "%" maxParamPercent "%"
	)
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

	-- Свободный фит без ограничений (направления не заданы).
	-- Система распадается на три независимые 2x2 системы (по осям X/Y/Z),
	-- решаем аналитически с защитой от вырождения - без обращения матриц.
	local s00 = 0.0
	local s01 = 0.0
	local s11 = 0.0
	local c0 = [0,0,0]
	local c1 = [0,0,0]
	local rel = P3 - P0
	for i = 1 to numSamples do
	(
		local t = ts[i]
		local mt = 1 - t
		local f0 = 3 * mt * mt * t
		local f1 = 3 * mt * t * t
		s00 += f0 * f0
		s01 += f0 * f1
		s11 += f1 * f1
		local r = (samples[i][1] - P0) - (t * t * t) * rel
		c0 += f0 * r
		c1 += f1 * r
	)

	local det = s00 * s11 - s01 * s01
	-- относительный тест на вырождение (почти коллинеарные базисные функции)
	if abs(det) <= 1e-9 * amax #(s00 * s11, 1.0) then
		return #((P0 + rel / 3.0), (P0 + 2.0 * rel / 3.0))

	local v0 = ((s11 * c0) - (s01 * c1)) / det
	local v1 = ((s00 * c1) - (s01 * c0)) / det

	return #(P0 + v0, P0 + v1)
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


-- --------------------
-- SCHNEIDER «fitCurves»: адаптивный выбор опорных вершин.
-- Фитим кубик Безье к плотной (по длине дуги) выборке участка; если максимальное
-- ортогональное отклонение больше допуска - разрезаем участок в точке худшей ошибки
-- и повторяем для обеих половин (явный стек вместо рекурсии). Границы принятых
-- участков привязываем к ближайшим узлам сплайна - они и становятся опорными.
fn findSupportPointsSchneider spline s_num samplesPerSegment:20 tolerancePct:0.1 maxSamples:2000 = (
	local nk = numknots spline s_num
	local closedS = isClosed spline s_num
	local cum = buildSplineCumLengths spline s_num
	local totalLen = cum[cum.count]
	local nsegTotal = cum.count - 1
	if totalLen <= 0.0 or nk < 3 then return #(1, nk)

	local avgSegLen = totalLen / nsegTotal

	-- плотная равномерная по длине дуги выборка всего сплайна
	local N = amin #(amax #(samplesPerSegment * nsegTotal, 200), maxSamples)
	local samples = for j = 1 to N collect (
		local l = (j - 1) as float * totalLen / (N - 1)
		#(getSplinePosAtLen spline s_num cum l, l)
	)

	local tolErr = totalLen * tolerancePct * 0.01

	local supports = #(0.0) -- границы принятых участков в длинах дуги
	local stackArr = #(#(1, N))
	local guardIter = 0
	local floorHits = 0 -- участки, принятые из-за пола разрешения узлов (ошибка > допуска)
	local worstFloorD = 0.0 -- худшая ошибка среди таких участков
	while stackArr.count > 0 do (
		local rng = stackArr[stackArr.count]
		deleteItem stackArr stackArr.count
		local i0 = rng[1]
		local i1 = rng[2]
		guardIter += 1

		-- поддиапазон с длинами ОТ НАЧАЛА участка (конвенция fitBezier*)
		local l0 = samples[i0][2]
		local sub = for j = i0 to i1 collect #(samples[j][1], samples[j][2] - l0)
		local subLen = sub[sub.count][2]
		local ts = for pnt in sub collect ((pnt[2] / (if subLen > 0.0 then subLen else 1.0)))

		local params = fitBezierIterative sub iterations:5
		local P0 = sub[1][1]
		local P3 = sub[sub.count][1]
		local P1 = params[1]
		local P2 = params[2]

		-- худшая по ортогональному отклонению точка участка
		local maxD = 0.0
		local maxJ = i0
		for j = (i0 + 1) to (i1 - 1) do (
			local t = bezierClosestT P0 P1 P2 P3 samples[j][1] ts[j - i0 + 1]
			local dd = distance (bezierPointAt P0 P1 P2 P3 t) samples[j][1]
			if dd > maxD do ( maxD = dd; maxJ = j )
		)

		-- резать бессмысленно, если участок короче двух сегментов сплайна:
		-- опорную точку можно поставить только в существующий узел
		local canSplit = subLen >= 2.0 * avgSegLen and (i1 - i0) >= 8 and guardIter < 300
		if maxD <= tolErr or not canSplit then (
			append supports samples[i1][2]
			if maxD > tolErr do (
				floorHits += 1
				if maxD > worstFloorD do worstFloorD = maxD
			)
		)
		else (
			append stackArr #(i0, maxJ)
			append stackArr #(maxJ, i1)
		)
	)

	sort supports

	-- привязка границ к узлам + гарантии минимального набора
	local result = #()
	for idx = 1 to supports.count do (
		local bestK = nearestKnotAtArcLen cum totalLen closedS supports[idx] nk
		if (finditem result bestK) == 0 do append result bestK
	)
	if (finditem result 1) == 0 do append result 1
	if not closedS and (finditem result nk) == 0 do append result nk
	if closedS and result.count < 3 then (
		for frac in #(0.25, 0.5, 0.75) do (
			local bk = nearestKnotAtArcLen cum totalLen closedS (frac * totalLen) nk
			if (finditem result bk) == 0 do append result bk
		)
	)
	sort result
	local clean = #()
	for k in result do (
		if clean.count == 0 or clean[clean.count] != k then append clean k
	)

	-- Пост-проход: узлы с острым углом (направления in/out касательных сильно отличаются
	-- от 180°) — гарантируем их как опорные, даже если Schneider не достала их из-за
	-- низкого разрешения (subLen < 2·avgSegLen). Это ловит внутренние точки дуг,
	-- оказавшиеся на стыке двух под-диапазонов при разбивке по кривизне.
	local sharpAngleCos = cos SS_SCHNEIDER_SHARP_ANGLE -- угол между normalized in/out касательными
	for k = 1 to nk do (
		if not closedS and (k == 1 or k == nk) then continue
		if (finditem clean k) > 0 then continue
		local kp = getKnotPoint spline s_num k
		local din = getInVec spline s_num k - kp
		local dout = getOutVec spline s_num k - kp
		local lin = length din; local lout = length dout
		if lin < 1e-9 or lout < 1e-9 then (
			-- Угловой узел (corner) — ручки нулевые; берём направления от хорд
			-- соседних сегментов, чтобы проверку угла всё равно выполнить.
			local prevK = if k == 1 then nk else k - 1
			local nextK = if k == nk then 1 else k + 1
			din = (getKnotPoint spline s_num prevK) - kp
			dout = (getKnotPoint spline s_num nextK) - kp
			lin = length din; lout = length dout
			if lin < 1e-9 or lout < 1e-9 do continue
		)
		din /= lin; dout /= lout
		if (dot din dout) > sharpAngleCos do (
			if (finditem clean k) == 0 do append clean k
		)
	)

	-- Пост-проход: защита границы ДЛИННОГО и КОРОТКОГО сегментов (аналог эвристики
	-- findSupportPoints и цепочек run_rebuildArcs). Если у вершины соседние сегменты
	-- различаются по длине >= SS_LONGSEG_RATIO и направление до и после неё почти
	-- совпадает (локально прямое продолжение) — вершину делаем опорной. Без неё длинная
	-- прямая рядом с плотной дугой/кривой попадает в фит плавного поворота, изгибается.
	local lgRatio = if SS_LONGSEG_RATIO == undefined then 4.0 else SS_LONGSEG_RATIO
	local lgAngTol = if SS_LONGSEG_ANGLE_TOL == undefined then 5.0 else SS_LONGSEG_ANGLE_TOL
	local lgCos = cos lgAngTol
	for k = 1 to nk do (
		if not closedS and (k == 1 or k == nk) then continue
		if (finditem clean k) > 0 then continue
		local kp = getKnotPoint spline s_num k
		local kpPrev = getKnotPoint spline s_num (if k == 1 then nk else k - 1)
		local kpNext = getKnotPoint spline s_num (if k == nk then 1 else k + 1)
		local v1 = kp - kpPrev
		local v2 = kpNext - kp
		local l1 = length v1
		local l2 = length v2
		if l1 < 1e-9 or l2 < 1e-9 do continue
		if (amax #(l1, l2)) < lgRatio * (amin #(l1, l2)) then continue

		-- поворот в самой вершине
		local d1 = v1 / l1
		local d2 = v2 / l2
		if (dot d1 d2) < lgCos then continue

		-- поворот в предыдущей вершине (локально прямое продолжение до этой)
		local prevPrev = if closedS then (if k == 1 then nk - 1 else (if k == 2 then nk else k - 2)) else (if k == 2 then 0 else k - 2)
		if prevPrev == 0 do continue
		local v0 = kpPrev - (getKnotPoint spline s_num prevPrev)
		local l0 = length v0
		if l0 < 1e-9 do continue
		local d0 = v0 / l0
		if (dot d0 d1) < lgCos then continue

		append clean k
	)
	sort clean
	if SS_DEBUG do format "Schneider: участков=% опорных=% допуск=% | уперлись в разрешение узлов: % (худшая ошибка %)\n" supports.count clean.count tolErr floorHits worstFloorD
	clean
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
			if SS_DEBUG do format "  pickBoundaryDir: хендл соседа противоречит данным участка (dot=%), беру направление данных\n" agree
			dd
		)
	) else dd
)


-- Основная функция для удаления подряд идущих вершин (не крайних) с сохранением кривизны
 fn simplifySpline spline s_num vert_selection samplesPerSegment:100 refitIterations:5 dirWeight:100.0 preserveBoundaries:false =
 (
	local test = false
	local iStart = vert_selection[1]
	local iEnd = vert_selection[vert_selection.count]
	local nknots = numknots spline s_num

	-- Какие узлы удаляем и какие служат граничными опорами (P0/P3 фита).
	local pre_start
	local after_end
	local deletable
	if preserveBoundaries then (
		-- Границы группы (iStart, iEnd) сохраняются не тронутыми:
		-- работаем только по внутренним точкам. Опоры фита — сами границы.
		pre_start = iStart
		after_end = iEnd
		deletable = for i = 2 to (vert_selection.count - 1) collect vert_selection[i]
	) else (
		pre_start = if iStart == 1 then nknots else (iStart - 1)
		after_end = if iEnd == nknots then 1 else (iEnd + 1)
		deletable = vert_selection
	)
	if deletable.count == 0 then (
		if SS_DEBUG do format "simplifySpline: нечего удалять (сохранены границы %)\n" vert_selection
		return OK
	)

	local work_range = #(pre_start)
	for i in deletable do append work_range i
	append work_range after_end
	if SS_DEBUG do format "work_range=% \n" work_range

	local samples = sampleSpline spline s_num work_range totalSamples:samplesPerSegment
	if samples.count < 2 then (
		if SS_DEBUG do format "simplifySpline: участок некорректен, узлы не удаляю (выделение %)\n" vert_selection
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
		if SS_DEBUG do (
			format "pre_start: %\n" (getknottype spline s_num pre_start)
			format "after_end: %\n" (getknottype spline s_num after_end)
		)

		setOutVec spline s_num pre_start P1
		setInVec spline s_num after_end P2

		local sortedVertSel = sort (for i in deletable collect i)
		for i = sortedVertSel.count to 1 by -1 do (
			deleteKnot spline s_num sortedVertSel[i]
		)

		updateShape spline
		if SS_DEBUG do format "after delete: numknots=% isClosed=% (было %)\n" (numknots spline s_num) (isClosed spline s_num) nknots

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
-- Сглаживание почти-прямых узлов результата.
-- Если угол между входящим и исходящим направлениями касательной >= angleDeg,
-- хендлы узла выравниваются в одну линию (длины сохраняются):
--  - одна сторона "прямая" (её хендл лежит на хорде своего сегмента) ->
--	противоположная сторона разворачивается вдоль этой прямой;
--  - обе стороны кривые -> обе поворачиваются на среднее направление
--	(взвешенная бисектриса, как btnAlignBoth в SplineTangentAligner).
-- Возвращает число сглаженных узлов.
fn smoothNearStraightKnots spline s_num angleDeg:179.0 straightTolDeg:1.0 = (
	local nk = numknots spline s_num
	if nk < 2 then return 0
	local closedS = isClosed spline s_num
	local cosSmooth = cos angleDeg -- угол >= порога <=> dot(dIn,dOut) <= cosSmooth
	local straightCos = cos straightTolDeg -- сторона "прямая" <=> dot(dir, chord) >= straightCos
	-- защищённые дугами узлы не сглаживать — их хендлы рассчитаны по окружности
	local arcP = ssArc_protectedFor spline s_num
	local smoothed = 0
	for k = 1 to nk do (
		if not closedS and (k == 1 or k == nk) then continue
		if (finditem arcP k) > 0 then continue
		local kp = getKnotPoint spline s_num k
		local din = getInVec spline s_num k - kp -- от узла к входному хендлу (назад по кривой)
		local dout = getOutVec spline s_num k - kp -- от узла к выходному хендлу (вперёд)
		local lin = length din
		local lout = length dout
		if lin < 1e-9 or lout < 1e-9 then continue
		din /= lin
		dout /= lout
		if (dot din dout) > cosSmooth then continue -- изгиб больше порога - не трогаем

		local prevK = if k == 1 then nk else k - 1
		local nextK = if k == nk then 1 else k + 1
		local chordIn = kp - (getKnotPoint spline s_num prevK)
		local chordOut = (getKnotPoint spline s_num nextK) - kp
		local lci = length chordIn
		local lco = length chordOut
		if lci < 1e-9 or lco < 1e-9 then continue
		chordIn /= lci
		chordOut /= lco
		-- сторона "прямая", если её хендл коллинеарен хорде своего сегмента
		-- (din смотрит назад, поэтому знак минус)
		local inStraight = (-(dot din chordIn)) >= straightCos
		local outStraight = (dot dout chordOut) >= straightCos

		local newDin = undefined
		local newDout = undefined
		if inStraight and not outStraight then
			newDout = -din -- разворачиваем исходящий вдоль прямой входящей стороны
		else if outStraight and not inStraight then
			newDin = -dout -- выравниваем входящий вдоль прямой исходящей стороны
		else (
			-- обе кривые (или обе прямые): среднее направление, как btnAlignBoth
			local w = din * lin - dout * lout
			local lw = length w
			if lw < 1e-9 then continue -- уже гладко
			newDin = w / lw
			newDout = -newDin
		)
		setKnotType spline s_num k #bezierCorner
		if newDin != undefined do setInVec spline s_num k (kp + newDin * lin)
		if newDout != undefined do setOutVec spline s_num k (kp + newDout * lout)
		smoothed += 1
	)
	if smoothed > 0 do updateShape spline
	smoothed
)

-- ==================== ВОССТАНОВЛЕНИЕ ДУГ ОКРУЖНОСТЕЙ ====================
-- Принцип: в плотно насэмплированном сплайне
-- ищутся цепочки почти равных сегментов (признак дискретизации дуги), режутся
-- по скачкам знаковой кривизны, каждая группа проверяется круговым фитам
-- (затравка - окружность через 3 точки, уточнение - алгебраический МНК Коса),
-- и заменяется ОДНИМ кубиком Безье с точными хендлами круговой дуги:
-- касательные n x r, длина хендла (4/3)*R*tan(theta/4).

fn ssArc_cmpArcGroups a b = (if a[1] < b[1] then -1 else (if a[1] > b[1] then 1 else 0))
fn ssArc_cmpArcGroupsDesc a b = (if a[1] > b[1] then -1 else (if a[1] < b[1] then 1 else 0))
fn ssArc_cmpNumbers a b = (if a < b then -1 else (if a > b then 1 else 0))

-- Индекс узла сплайна, ближайшего к позиции p (или 0, если узел не найден).
fn ssArc_findKnotByPos shp s p = (
	local nK = numKnots shp s
	local bestIdx = 0
	local bestDist = 1e30
	for ci = 1 to nK do (
		local d = distance (getKnotPoint shp s ci) p
		if d < bestDist do (bestDist = d; bestIdx = ci)
	)
	bestIdx
)

fn ssArc_safeNormalize v eps:1e-12 = (
	local l = length v
	if l < eps then [0,0,0] else (v / l)
)

fn ssArc_projectToPlane v n = (v - n * (dot v n))

fn ssArc_maxBulgeIndex pts = (
	local m = pts.count
	if m < 4 do return 2
	local chord = pts[m] - pts[1]
	local chordLen = length chord
	if chordLen < 1e-12 do return 2
	local chordDir = chord / chordLen
	local bestIdx = 2
	local bestDev = -1.0
	for i = 2 to (m - 1) do (
		local dev = length (cross (pts[i] - pts[1]) chordDir)
		if dev > bestDev do (bestDev = dev; bestIdx = i)
	)
	bestIdx
)

fn ssArc_avgNormal pts = (
	local m = pts.count
	if m < 3 do return [0,0,0]
	local sum = [0,0,0]
	for i = 2 to (m - 1) do sum += cross (pts[i] - pts[i-1]) (pts[i+1] - pts[i])
	ssArc_safeNormalize sum
)

-- знаковые углы поворота в градусах (проекция на плоскость c нормалью n)
fn ssArc_turnAngles pts n = (
	local m = pts.count
	local a = #()
	a.count = m
	for i = 1 to m do a[i] = 0.0
	if m < 3 do return a
	for i = 2 to (m - 1) do (
		local v1 = ssArc_projectToPlane (pts[i] - pts[i-1]) n
		local v2 = ssArc_projectToPlane (pts[i+1] - pts[i]) n
		local l1 = length v1
		local l2 = length v2
		if l1 < 1e-12 or l2 < 1e-12 then a[i] = 0.0
		else (
			v1 /= l1
			v2 /= l2
			a[i] = atan2 (dot (cross v1 v2) n) (dot v1 v2)
		)
	)
	a
)

-- окружность через 3 точки: #(центр, нормаль, радиус) или undefined
fn ssArc_fitCircle3D p1 p2 p3 sinMin:1e-6 eps:1e-12 = (
	local a = p2 - p1
	local b = p3 - p1
	local la = length a
	local lb = length b
	if la < eps or lb < eps do return undefined
	local nrm = cross a b
	local nlen = length nrm
	local s = nlen / (la * lb)
	if s < sinMin do return undefined
	nrm /= nlen
	local u = a / la
	local v = ssArc_safeNormalize (cross nrm u)
	if (length v) < eps do return undefined
	local x2 = la
	local x3 = dot b u
	local y3 = dot b v
	local D = 2.0 * x2 * y3
	if abs(D) < eps do return undefined
	local ux = x2 / 2.0
	local uy = ((-(x2*x2*x3)) + ((x3*x3 + y3*y3) * x2)) / D
	local c = p1 + u * ux + v * uy
	local R = distance c p1
	if R < eps do return undefined
	#(c, nrm, R)
)

-- решение 3x3 по Крамеру
fn ssArc_solve3x3 a11 a12 a13 a21 a22 a23 a31 a32 a33 b1 b2 b3 eps:1e-12 = (
	local detA = a11*(a22*a33 - a23*a32) - a12*(a21*a33 - a23*a31) + a13*(a21*a32 - a22*a31)
	if abs(detA) < eps do return undefined
	local detX = b1*(a22*a33 - a23*a32) - a12*(b2*a33 - a23*b3) + a13*(b2*a32 - a22*b3)
	local detY = a11*(b2*a33 - a23*b3) - b1*(a21*a33 - a23*a31) + a13*(a21*b3 - b2*a31)
	local detZ = a11*(a22*b3 - b2*a32) - a12*(a21*b3 - b2*a31) + b1*(a21*a32 - a22*a31)
	#(detX/detA, detY/detA, detZ/detA)
)

-- алгебраический МНК-фит окружности в плоскости с нормалью n (метод Коса)
fn ssArc_fitCircleLSQ pts n = (
	local nPts = pts.count
	if nPts < 3 do return undefined
	local origin = [0,0,0]
	for p in pts do origin += p
	origin /= nPts
	local u = ssArc_projectToPlane (pts[nPts] - pts[1]) n
	if (length u) < 1e-8 do u = ssArc_projectToPlane (pts[2] - pts[1]) n
	u = ssArc_safeNormalize u
	if (length u) < 1e-8 do return undefined
	local v = ssArc_safeNormalize (cross n u)
	if (length v) < 1e-8 do return undefined

	local Sx=0.0; local Sy=0.0; local Sxx=0.0; local Syy=0.0; local Sxy=0.0
	local Sxz=0.0; local Syz=0.0; local Sz=0.0
	for p in pts do (
		local d = p - origin
		local x = dot d u
		local y = dot d v
		local z = (x*x + y*y)
		Sx += x;   Sy += y
		Sxx += x*x; Syy += y*y; Sxy += x*y
		Sxz += x*z; Syz += y*z; Sz += z
	)
	local sol = ssArc_solve3x3 Sxx Sxy Sx Sxy Syy Sy Sx Sy nPts (-Sxz) (-Syz) (-Sz)
	if sol == undefined do return undefined
	local cx = -(sol[1] / 2.0)
	local cy = -(sol[2] / 2.0)
	local R2 = (cx*cx + cy*cy) - sol[3]
	if R2 <= 1e-12 do return undefined
	#(origin + u * cx + v * cy, sqrt R2)
)

fn ssArc_residuals pts c n R = (
	local maxPlane = 0.0
	local maxRad = 0.0
	local sum2 = 0.0
	local p0 = pts[1]
	for p in pts do (
		local pd = abs (dot (p - p0) n)
		if pd > maxPlane do maxPlane = pd
		local rd = abs ((distance p c) - R)
		if rd > maxRad do maxRad = rd
		sum2 += rd * rd
	)
	#(maxPlane, maxRad, sqrt (sum2 / pts.count))
)

-- робастный фит: затравка через 3 точки + уточнение МНК; проверки допусков.
-- Возвращает #(центр, нормаль, радиус, знаковый угол дуги в градусах, макс. радиальное отклонение) или undefined
fn ssArc_robustFit pts planeTol radTolAbs radTolRel = (
	if pts.count < 4 do return undefined
	local bIdx = ssArc_maxBulgeIndex pts
	local circ3 = ssArc_fitCircle3D pts[1] pts[bIdx] pts[pts.count]
	if circ3 == undefined do return undefined
	local c = circ3[1]
	local n = circ3[2]
	local R = circ3[3]
	local res = ssArc_residuals pts c n R

	local circLS = ssArc_fitCircleLSQ pts n
	if circLS != undefined then (
		local resLS = ssArc_residuals pts circLS[1] n circLS[2]
		if resLS[3] <= res[3] then (c = circLS[1]; R = circLS[2]; res = resLS)
	)

	if res[1] > planeTol do return undefined
	local radTol = amax radTolAbs (radTolRel * R)
	if res[2] > radTol do return undefined

	local r0 = ssArc_safeNormalize (pts[1] - c)
	local r1 = ssArc_safeNormalize (pts[pts.count] - c)
	if (length r0) < 1e-12 or (length r1) < 1e-12 do return undefined

	local thetaCenter = atan2 (dot (cross r0 r1) n) (dot r0 r1)
	local tCCW = normalize (cross n r0)
	local seg0 = ssArc_safeNormalize (ssArc_projectToPlane (pts[2] - pts[1]) n)
	if (length seg0) < 1e-12 do return undefined

	local thetaSigned = abs thetaCenter
	if (dot tCCW seg0) < 0 then thetaSigned = -thetaSigned
	#(c, n, R, thetaSigned, res[2])
)

-- Накопленный угол вдоль цепочки точек относительно центра c.
-- Обходит точки последовательно и суммирует приращения углов.
-- Возвращает угол в градусах (знак: + = CCW, - = CW).
fn ssArc_accumulatedAngle pts c n = (
	local totalAngle = 0.0
	local maxBack = 0.0
	for i = 2 to pts.count do (
		local rPrev = ssArc_safeNormalize (pts[i-1] - c)
		local rCurr = ssArc_safeNormalize (pts[i] - c)
		if (length rPrev) > 1e-12 and (length rCurr) > 1e-12 then (
			local d = dot rPrev rCurr
			if d < -1.0 do d = -1.0
			if d > 1.0 do d = 1.0
			local crossVal = dot (cross rPrev rCurr) n
			local stepAng = acos d
			if crossVal > 0 do stepAng = -stepAng
			totalAngle += stepAng
			if (abs stepAng) > maxBack do maxBack = abs stepAng
		)
	)
	#(totalAngle, maxBack)
)

-- замена группы узлов [startK..endK] дугой Безье.
-- Дуги >90° разбиваются на ceil(thetaDeg/90) сегментов через промежуточные узлы.
-- Промежуточные узлы ПЕРЕМЕЩАЮТСЯ на вычисленную позицию на окружности.
-- Возвращает #(true, numKnots) или #(false, 0).
fn ssArc_replaceGroup shp s startK endK c n thetaSigned = (
	if endK <= startK + 2 do return #(false, 0)
	local p0 = getKnotPoint shp s startK
	local pE = getKnotPoint shp s endK

	local thetaAbs = abs thetaSigned
	if thetaAbs < 1e-9 do return #(false, 0)
	local dirSign = if thetaSigned >= 0 then 1.0 else -1.0
	local R = distance c p0
	if R < 1e-12 do return #(false, 0)

	local r0 = ssArc_safeNormalize (p0 - c)
	if (length r0) < 1e-12 do return #(false, 0)
	local t0 = normalize (cross n r0) * dirSign
	local rEnd = ssArc_safeNormalize (pE - c)

	local oldInStart = getInVec shp s startK
	local oldOutEnd = getOutVec shp s endK

	local nSegMin = amax 1 ((ceil (thetaAbs / SS_ARC_MAX_SEG_DEGREE)) as integer)
	local nSegMax = amax SS_ARC_MIN_ARC_SEG ((floor (thetaAbs / SS_ARC_MIN_SEG_DEGREE)) as integer)
	local nSeg = amin nSegMax (amax nSegMin SS_ARC_MIN_ARC_SEG)
	local nKeep = nSeg - 1
	local totalInterior = endK - startK - 1
	local nUse = amin nKeep (amax 0 totalInterior)

	local keepSet = #()
	keepSet.count = endK + 1
	for i = 1 to endK + 1 do keepSet[i] = false

	if nUse > 0 and totalInterior > 0 then (
		local nSlot = amin nUse totalInterior
		for i = 1 to nSlot do (
			local origIdx = (startK + 1 + (i * totalInterior / (nSlot + 1) + 0.5)) as integer
			if origIdx >= startK + 1 and origIdx <= endK - 1 do
				keepSet[origIdx] = true
		)
	)

	for kDel = (endK - 1) to (startK + 1) by -1 do (
		if not keepSet[kDel] do deleteKnot shp s kDel
	)
	local newEndK = startK + nUse + 1

	local subTheta = thetaAbs / nSeg
	local hl = (4.0 / 3.0) * R * (tan (subTheta / 4.0))

	setKnotType shp s startK #bezierCorner
	try(setSegType shp s startK #curve)catch()
	setOutVec shp s startK (p0 + t0 * hl)
	setInVec shp s startK oldInStart

	for i = 1 to nUse do (
		local ang = thetaAbs * (i as float) / nSeg
		local ri = ssArc_safeNormalize (r0 * (cos ang) + (cross n r0) * (sin ang) * dirSign)
		local ptOnCircle = c + ri * R
		local ki = startK + i
		setKnotPoint shp s ki ptOnCircle
		setKnotType shp s ki #bezierCorner
		try(setSegType shp s ki #curve)catch()
		local ti = normalize (cross n ri) * dirSign
		setInVec shp s ki (ptOnCircle - ti * hl)
		setOutVec shp s ki (ptOnCircle + ti * hl)
	)

	setKnotType shp s newEndK #bezierCorner
	try(setSegType shp s newEndK #curve)catch()
	if (length rEnd) > 1e-12 then (
		local tEnd = normalize (cross n rEnd) * dirSign
		setInVec shp s newEndK (pE - tEnd * hl)
	)
	setOutVec shp s newEndK oldOutEnd

	#(true, newEndK - startK + 1)
)

-- Замена дуги, переходящей через шов замкнутого сплайна.
-- Виртуальный диапазон [startK..endK] где endK > segsT (виртуальные индексы).
-- Все точки собираются по порядку через шов, фитится одна окружность,
-- и замена идёт на двух частях: tail (startK..segsT) и head (1..endK-segsT).
fn ssArc_replaceGroupWrap shp s startK endK segsT c n thetaSigned = (
	if endK <= startK + 2 do return #(false, 0)
	local nk = numknots shp s
	local p0 = getKnotPoint shp s startK
	local headEnd = endK - segsT
	local pE = getKnotPoint shp s headEnd

	local thetaAbs = abs thetaSigned
	if thetaAbs < 1e-9 do return #(false, 0)
	local dirSign = if thetaSigned >= 0 then 1.0 else -1.0
	local R = distance c p0
	if R < 1e-12 do return #(false, 0)

	local r0 = ssArc_safeNormalize (p0 - c)
	if (length r0) < 1e-12 do return #(false, 0)
	local t0 = normalize (cross n r0) * dirSign
	local rEnd = ssArc_safeNormalize (pE - c)

	local oldInStart = getInVec shp s startK
	local oldOutEnd = getOutVec shp s headEnd

	-- Полная окружность (виртуальный конец возвращается к начальному узлу):
	-- используем более мелкий шаг сегмента, чтобы кольцо было визуально ровным.
	local isFullCircle = (headEnd == startK)
	local maxLeg = if isFullCircle then SS_ARC_FULLCIRCLE_MAX_SEG_DEG else SS_ARC_MAX_SEG_DEGREE
	local nSegMin = amax 1 ((ceil (thetaAbs / maxLeg)) as integer)
	local nSegMax = amax SS_ARC_MIN_ARC_SEG ((floor (thetaAbs / SS_ARC_MIN_SEG_DEGREE)) as integer)
	local nSeg = amin nSegMax (amax nSegMin SS_ARC_MIN_ARC_SEG)
	local nKeep = nSeg - 1

	local totalInterior = endK - startK - 1
	local nUse = amin nKeep totalInterior

	-- Виртуальные промежуточные индексы: startK+1 .. endK-1 (все через шов)
	-- Выбираем какие сохранить (равномерно)
	local keepVirtualSet = #()
	keepVirtualSet.count = totalInterior
	for i = 1 to totalInterior do keepVirtualSet[i] = false
	if nUse > 0 and totalInterior > 0 then (
		for i = 1 to nUse do (
			local vIdx = (i * totalInterior / (nUse + 1) + 0.5) as integer
			if vIdx >= 1 and vIdx <= totalInterior do
				keepVirtualSet[vIdx] = true
		)
	)

	-- 1) ВСЕ setKnotPoint/setInVec/setOutVec — ДО удалений, пока индексы не сдвинулись
	local subTheta = thetaAbs / nSeg
	local hl = (4.0 / 3.0) * R * (tan (subTheta / 4.0))

	-- Начальный узел (startK) — фиксируем позицию, не двигаем на окружность
	setKnotType shp s startK #bezierCorner
	try(setSegType shp s startK #curve)catch()
	setOutVec shp s startK (p0 + t0 * hl)
	setInVec shp s startK oldInStart

	-- Промежуточные узлы — считаем их позиции и ставим ДО удалений
	local keptPos = #() -- позиции сохранённых промежуточных узлов (для защиты)
	local keptCounter = 0
	for vi = 1 to totalInterior do (
		if keepVirtualSet[vi] then (
			keptCounter += 1
			-- Для полной окружности узлы ставятся строго равномерно (по nSeg),
			-- чтобы каждый кубик Безье охватывал ровно 360/nSeg и кольцо было
			-- идеально круглым (иначе некратные деления дают небольшие смещения).
			local ang = if isFullCircle then (thetaAbs * ((keptCounter as float) / nSeg)) else (thetaAbs * ((vi as float) / totalInterior))
			local ri = ssArc_safeNormalize (r0 * (cos ang) + (cross n r0) * (sin ang) * dirSign)
			local ptOnCircle = c + ri * R
			local realIdx = startK + vi
			if realIdx > segsT do realIdx -= segsT
			setKnotPoint shp s realIdx ptOnCircle
			setKnotType shp s realIdx #bezierCorner
			try(setSegType shp s realIdx #curve)catch()
			local ti = normalize (cross n ri) * dirSign
			setInVec shp s realIdx (ptOnCircle - ti * hl)
			setOutVec shp s realIdx (ptOnCircle + ti * hl)
			append keptPos ptOnCircle
		)
	)

	-- Конечный узел (headEnd) — фиксируем позицию, не двигаем на окружность
	setKnotType shp s headEnd #bezierCorner
	try(setSegType shp s headEnd #curve)catch()
	if (length rEnd) > 1e-12 then (
		local tEnd = normalize (cross n rEnd) * dirSign
		setInVec shp s headEnd (pE - tEnd * hl)
	)
	-- Для полной окружности headEnd==startK: out-вектор уже выставлен стартовым
	-- блоком как касательная окружности; НЕ перезаписывать исходным старым out-вектором.
	if headEnd != startK do setOutVec shp s headEnd oldOutEnd

	-- 2) Удаляем ненужные промежуточные узлы — ПОСЛЕ всех set*, в обратном порядке
	--	Сначала tail (высокие индексы), потом head (низкие), чтобы не сбивать друг друга
	--	Tail: segsT .. startK+1 (в обратном порядке)
	for kDel = segsT to (startK + 1) by -1 do (
		local vi = kDel - startK
		if vi >= 1 and vi <= totalInterior and not keepVirtualSet[vi] do
			deleteKnot shp s kDel
	)
	-- Head: headEnd-1 .. 1 (в обратном порядке)
	for kDel = (headEnd - 1) to 1 by -1 do (
		local vi = (segsT - startK) + kDel
		if vi >= 1 and vi <= totalInterior and not keepVirtualSet[vi] do
			deleteKnot shp s kDel
	)

	-- 3) Собираем позиции защищённых узлов —oundary на исходных позициях
	local protPos = #()
	append protPos p0
	for pp in keptPos do append protPos pp
	append protPos pE

	local nTotal = nUse + 2
	#(true, nTotal, protPos)
)

fn ssArc_median arr = (
	local a = deepcopy arr
	qsort a ssArc_cmpNumbers
	local n = a.count
	if n == 0 then 0.0
	else if (mod n 2) == 1 then a[(n+1)/2]
	else (a[n/2] + a[n/2+1]) / 2.0
)

fn ssArc_strictnessToTols strict typicalLen = (
	local t = (amax 0.0 (amin 100.0 strict)) / 100.0
	local planeTol = typicalLen * (0.50 - 0.40 * t) -- 0.50 -> 0.10
	local radAbs = typicalLen * (0.80 - 0.65 * t)   -- 0.80 -> 0.15
	local radRel = 0.006 - 0.0048 * t			   -- 0.006 -> 0.0012
	local curvTolRel = 0.85 - 0.35 * t			  -- 0.85 -> 0.50
	#(planeTol, radAbs, radRel, curvTolRel)
)

-- разрезка цепочки точек на поддиапазоны постоянной знаковой кривизны.
-- Устойчива к шуму на стыках (переходные узлы с половинным шагом по углу
-- втягиваются в дугу): дуга = непрерывный прогон узлов с |угол поворота| >=
-- половины типичного шага дуги; прямые прогоны (поворот ~0) отделяются и в
-- результат не попадают. Возвращает поддиапазоны узлов #(kLo, kHi) в системе
-- отсчёта pStart (ptsChain[1] соответствует индексу pStart), по возрастанию.
fn ssArc_curvatureSubranges ptsChain Larr pStart curvTolRel = (
	local res = #()
	local nChain = ssArc_avgNormal ptsChain
	if (length nChain) < 1e-8 do return res

	local angs = ssArc_turnAngles ptsChain nChain

	-- типичный шаг дуги = медиана ненулевых углов поворота
	local posAng = #()
	for v = 1 to angs.count do
		if (abs angs[v]) > 1e-6 do append posAng (abs angs[v])
	if posAng.count < 2 do return res
	qsort posAng ssArc_cmpNumbers
	local arcStep = posAng[((posAng.count + 1) / 2) as integer]
	if arcStep < 1e-6 do return res
	local thr = arcStep * 0.45

	-- интерьерные узлы, реально поворачивающие (принадлежат дуге)
	local curved = #()
	curved.count = ptsChain.count
	for v = 1 to curved.count do curved[v] = false
	for v = 2 to (ptsChain.count - 1) do
		if (abs angs[v]) >= thr do curved[v] = true

	-- непрерывные прогоны дуги (индексы интерьерных узлов)
	local runs = #()
	local rStart = 0
	for v = 2 to (ptsChain.count - 1) do (
		if curved[v] and rStart == 0 do rStart = v
		if (not curved[v]) and rStart > 0 do (
			append runs #(rStart, v - 1)
			rStart = 0
		)
	)
	if rStart > 0 do append runs #(rStart, ptsChain.count - 1)

	-- ДУГА, РАЗРЕЗАННАЯ ШВОМ ЦЕПОЧКИ: если и головной, и хвостовой прогоны
	-- примыкают к концам цепочки И поворачивают в одну сторону — это одна
	-- непрерывная дуга, пересекающая шов. Склеиваем в один «обёрнутый» прогон
	-- #(kLo, kHi) с kLo > kHi (голова расположена в массиве ПЕРЕД хвостом).
	local headIdx = 0
	local tailIdx = 0
	for i = 1 to runs.count do (
		if runs[i][1] == 2 do headIdx = i
		if runs[i][2] == (ptsChain.count - 1) do tailIdx = i
	)
	if runs.count >= 2 and headIdx > 0 and tailIdx > 0 and headIdx != tailIdx then (
		local sumHead = 0.0
		local sumTail = 0.0
		for vv = runs[headIdx][1] to runs[headIdx][2] do sumHead += angs[vv]
		for vv = runs[tailIdx][1] to runs[tailIdx][2] do sumTail += angs[vv]
		if (sumHead * sumTail) > 0 then (
			-- хвост и голова — одна дуга через шов: обёрнутый прогон
			append res #((pStart + runs[tailIdx][1] - 2), (pStart + runs[headIdx][2]))
			-- удаляем head и tail из обхода (индекс удаления — по убыванию)
			if tailIdx > headIdx then (
				deleteItem runs tailIdx
				deleteItem runs headIdx
			) else (
				deleteItem runs headIdx
				deleteItem runs tailIdx
			)
		)
	)

	-- расширяем каждый прогон на переходные узлы с обеих сторон, чтобы
	-- захватить дугу/полукруг целиком
	for r in runs do
		append res #((pStart + r[1] - 2), (pStart + r[2]))
	res
)

-- Самая длинная непрерывная полоса точек pts, лежащих на окружности (c,R)
-- в пределах радиального допуска tol. Возвращает #(idxLo, idxHi) индексы
-- ОТНОСИТЕЛЬНО pts (1-based); если полосы нет — #(0, 0).
fn ssArc_longestInlierRun pts c R tol = (
	local runLo = 0
	local runHi = 0
	local curLo = 0
	for i = 1 to pts.count do (
		local dev = abs ((distance pts[i] c) - R)
		if dev <= tol then (
			if curLo == 0 do curLo = i
		) else (
			if curLo > 0 and (i - curLo) > (runHi - runLo) do (runLo = curLo; runHi = i - 1)
			curLo = 0
		)
	)
	if curLo > 0 and (pts.count - curLo + 1) > (runHi - runLo) do (runLo = curLo; runHi = pts.count)
	#(runLo, runHi)
)

-- Фит окружности по точкам с ОТСЕЧЕНИЕМ точек, отклонившихся от дуги сильнее
-- maxDev (доля радиуса; 0 = без отсечения). Выбросы не притягиваются к дуге и
-- не удаляются — дуга определяется по оставшимся "хорошим" точкам.
-- Возвращает #(центр, нормаль, радиус, знаковый угол, idxLo, idxHi) — индексы
-- под-диапазона в pts (1-based), которые лежат на дуге; либо undefined.
fn ssArc_fitWithDeviationTrim pts planeTol radTolAbs radTolRel maxDev = (
	local npts = pts.count
	if npts < 4 do return undefined

	local lo = 1
	local hi = npts
	local fit = ssArc_robustFit pts planeTol radTolAbs radTolRel

	if fit != undefined and maxDev <= 0.0 do
		return #(fit[1], fit[2], fit[3], fit[4], 1, npts)

	for iter = 1 to npts do (
		local cF = fit
		if cF == undefined do (
			local midI = ((lo + hi) / 2) as integer
			local circ = ssArc_fitCircle3D pts[lo] pts[midI] pts[hi]
			if circ == undefined do return undefined
			cF = #(circ[1], circ[2], circ[3], 0.0, 0.0)
		)
		local tol = if maxDev > 0.0 then maxDev * cF[3] else 1e30
		local subPts = for sIdx = lo to hi collect pts[sIdx]
		local run = ssArc_longestInlierRun subPts cF[1] cF[3] tol
		local rLo = run[1] + lo - 1
		local rHi = run[2] + lo - 1
		if rHi < rLo do return undefined

		if rLo == lo and rHi == hi then (
			fit = cF
			exit
		)
		lo = rLo
		hi = rHi
		if hi - lo + 1 < 4 do return undefined
		subPts = #()
		for sIdx = lo to hi do append subPts pts[sIdx]
		fit = ssArc_robustFit subPts planeTol radTolAbs radTolRel
		if fit != undefined then exit
	)

	if fit == undefined do return undefined
	subPts = #()
	for sIdx = lo to hi do append subPts pts[sIdx]
	local finalFit = ssArc_robustFit subPts planeTol radTolAbs radTolRel
	if finalFit == undefined do return undefined
	#(finalFit[1], finalFit[2], finalFit[3], finalFit[4], lo, hi)
)


fn ssArc_drawnArcPoly p0 pE c n thetaSigned R totalInterior wrapped isFullCircle:false = (
	local thetaAbs = abs thetaSigned
	if thetaAbs < 1e-9 or R < 1e-12 do return #()
	local dirSign = if thetaSigned >= 0 then 1.0 else -1.0

	local maxLeg = if isFullCircle then SS_ARC_FULLCIRCLE_MAX_SEG_DEG else SS_ARC_MAX_SEG_DEGREE
	local nSegMin = amax 1 ((ceil (thetaAbs / maxLeg)) as integer)
	local nSegMax = amax SS_ARC_MIN_ARC_SEG ((floor (thetaAbs / SS_ARC_MIN_SEG_DEGREE)) as integer)
	local nSeg = amin nSegMax (amax nSegMin SS_ARC_MIN_ARC_SEG)
	local nUse = amin (nSeg - 1) (amax 0 totalInterior)
	local subTheta = thetaAbs / nSeg
	local hl = (4.0 / 3.0) * R * (tan (subTheta / 4.0))

	local r0 = ssArc_safeNormalize (p0 - c)
	if (length r0) < 1e-12 do return #()
	local t0 = normalize (cross n r0) * dirSign

	local kPts = #(p0)
	local kT = #(t0)
	for i = 1 to nUse do (
		local ang
		if isFullCircle or not wrapped then ang = thetaAbs * (i as float) / nSeg
		else ang = thetaAbs * (i as float) / (nUse + 1)
		local ri = ssArc_safeNormalize (r0 * (cos ang) + (cross n r0) * (sin ang) * dirSign)
		append kPts (c + ri * R)
		append kT (normalize (cross n ri) * dirSign)
	)
	append kPts pE
	local rEnd = ssArc_safeNormalize (pE - c)
	if (length rEnd) > 1e-12 then append kT (normalize (cross n rEnd) * dirSign)
	else append kT kT[kT.count]

	local poly = #()
	local steps = 10
	for j = 1 to (kPts.count - 1) do (
		local hOut = kPts[j] + kT[j] * hl
		local hIn = kPts[j + 1] - kT[j + 1] * hl
		for st = 0 to steps do (
			local tt = st as float / steps
			append poly (bezierPointAt kPts[j] hOut hIn kPts[j + 1] tt)
		)
	)
	poly
)

-- Максимальное отклонение исходных точек originals от дуги Безье, которую получится
-- построить (см. ssArc_drawnArcPoly). Та же мера, что и в упрощении: исходные сэмплы
-- против новой кривой (геометрическое отклонение формы). 0 = точки лежат на дуге.
fn ssArc_maxDevToArc originals p0 pE c n thetaSigned R totalInterior wrapped isFullCircle:false = (
	local poly = ssArc_drawnArcPoly p0 pE c n thetaSigned R totalInterior wrapped isFullCircle:isFullCircle
	if poly.count < 2 do return 1e30
	local worst = 0.0
	for i = 1 to originals.count do (
		local p = originals[i]
		local dBest = 1e30
		for j = 1 to (poly.count - 1) do (
			local dd = pointSegDist p poly[j] poly[j + 1]
			if dd < dBest do dBest = dd
		)
		if dBest > worst do worst = dBest
	)
	worst
)

-- Обработка одной поддуги контура, полученной разбивкой замкнутой цепочки по кривизне
-- (фолбэк для случая, когда весь периметр НЕ является одной окружностью — капсула и т.п.).
-- subPts - упорядоченные точки поддуги; curLo/curHi - ТЕКУЩИЕ реальные индексы граничных
-- узлов (найдены по позициям); crossesSeam - пересекает ли поддуга шов замкнутого сплайна
-- (виртуальный диапазон). Возвращает #(заменено, отфильтровано, protPos).
fn ssArc_fallbackSub shp s subPts curLo curHi crossesSeam segsT planeTol radTolAbs radTolRel minArcSeg minArcAng = (
	local replaced = 0
	local filtered = 0
	local protPos = #()
	if subPts.count < (minArcSeg + 1) do return #(0, 0, #())
	local tr = ssArc_fitWithDeviationTrim subPts planeTol radTolAbs radTolRel SS_ARC_MAX_DEVIATION
	if tr != undefined then (
		local cFit = tr[1]
		local nFit = tr[2]
		local subLo = tr[5]
		local subHi = tr[6]
		local goodPts = for i = subLo to subHi collect subPts[i]
		local accRes = ssArc_accumulatedAngle goodPts cFit nFit
		local accAng = accRes[1]
		local maxBack = accRes[2]
		local avgStep = if goodPts.count > 1 then (abs accAng) / (goodPts.count - 1) else 0.0
		local isArc = true
		if maxBack > SS_ARC_MAX_BACK_DEGREES do isArc = false
		if avgStep > 1e-6 and maxBack > avgStep * 8.0 do isArc = false
		if SS_DEBUG and not isArc do
			format "  [fallback sub reject] maxBack=%.1f avgStep=%.1f pts=%\n" maxBack avgStep goodPts.count
		if isArc then (
			local thetaFit = (if tr[4] >= 0 then 1.0 else -1.0) * (abs accAng)
			if (abs thetaFit) >= minArcAng then (
				local Rfit = distance cFit subPts[1]
				local vMult = if SS_ARC_VALIDATE_TOL_MULT == undefined then 2.0 else SS_ARC_VALIDATE_TOL_MULT
				local arcTol = vMult * (amax radTolAbs (radTolRel * Rfit))
				-- Проверка готовой дуги против исходной кривой (как в упрощении):
				-- по математике замены заранее воспроизводим полилинию кубиков Безье,
				-- которые ПОЛУЧАТСЯ, и меряем max отклонение исходных точек диапазона.
				-- Если дуга "не стартует" из верного места (мимо кривой) — сужаем
				-- диапазон до inlier-прогона фита и пробуем ещё раз; иначе фильтруем.
				local rr = undefined
				local tryLo = curLo
				local tryHi = curHi
				local clamped = false
				for attempt = 0 to 1 while rr == undefined do (
					local chkPts = #()
					local loP = if clamped then subLo else 1
					local hiP = if clamped then subHi else subPts.count
					for kk = loP to hiP do append chkPts subPts[kk]
					if chkPts.count < (minArcSeg + 1) do chkPts = #()
					local totalInt = if crossesSeam then (tryHi + segsT - tryLo - 1) else (tryHi - tryLo - 1)
					local arcDev = if chkPts.count > 0 then (
						ssArc_maxDevToArc chkPts subPts[loP] subPts[hiP] cFit nFit thetaFit Rfit totalInt crossesSeam
					) else 1e30
					if SS_DEBUG do
						format "  [arc validate] dev=% tol=% range=%..% pts=%\n" arcDev arcTol tryLo tryHi chkPts.count
					if arcDev <= arcTol then (
						if crossesSeam then (
							rr = ssArc_replaceGroupWrap shp s tryLo (tryHi + segsT) segsT cFit nFit thetaFit
						) else (
							rr = ssArc_replaceGroup shp s tryLo tryHi cFit nFit thetaFit
						)
					) else if attempt == 0 and not clamped and (subLo > 1 or subHi < subPts.count) then (
						-- дуга не легла на исходную кривую: сужаем диапазон до участка,
						-- реально лежащего на окружности (inlier-прогон фита)
						local nLo = ssArc_findKnotByPos shp s subPts[subLo]
						local nHi = ssArc_findKnotByPos shp s subPts[subHi]
						local spanOk = if crossesSeam then (nLo - nHi) >= minArcSeg else (nHi - nLo) >= minArcSeg
						if nLo > 0 and nHi > 0 and spanOk then (
							tryLo = nLo
							tryHi = nHi
							clamped = true
						) else (
							rr = #(false, 0)
						)
					) else (
						rr = #(false, 0)
					)
				)
				if rr != undefined and rr[1] then (
					replaced += 1
					if crossesSeam then (
						for pp in rr[3] do
							if (finditem protPos pp) == 0 do append protPos pp
					) else (
						local nK = rr[2]
						for k = tryLo to (tryLo + nK - 1) do (
							local pp = getKnotPoint shp s k
							if (finditem protPos pp) == 0 do append protPos pp
						)
					)
				) else (
					filtered += 1
				)
			) else (
				filtered += 1
			)
		)
	)
	#(replaced, filtered, protPos)
)

-- обработка одного непрерывного диапазона узлов: резка по кривизне + фит + замена.
-- Диапазон может содержать примыкающие прямые и дугу (напр. [верхняя прямая +
-- полукруг + нижняя прямая]); разбиваем его по кривизне, чтобы фитить каждую
-- дугу целиком, а прямые просто отсеивались фитом.
-- Поддиапазоны обрабатываются С КОНЦА, чтобы индексы не плыли после deleteKnot.
-- Возвращает #(заменено, отфильтровано, позицииPoint3 границ дуг)
fn ssArc_processRange shp s gStartP gEndP Larr planeTol radTolAbs radTolRel curvTolRel minArcSeg minArcAng = (
	local replaced = 0
	local filtered = 0
	local protPos = #()
	if (gEndP - gStartP) >= minArcSeg then (
		local rangePts = for k = gStartP to gEndP collect (getKnotPoint shp s k)
		-- разбивка на поддуги по кривизне; прямые участки в результат не входят
		local subs = ssArc_curvatureSubranges rangePts Larr gStartP curvTolRel
		if subs.count > 0 then (
			local uniRanges = #() -- #(kLo, kHi, posLo, posHi) в глобальных индексах узлов
			for sb in subs do (
				local kLo = amax gStartP sb[1]
				local kHi = amin gEndP sb[2]
				if (kHi - kLo) >= minArcSeg do
					append uniRanges #(kLo, kHi, getKnotPoint shp s kLo, getKnotPoint shp s kHi)
			)
			if uniRanges.count > 0 then (
				qsort uniRanges ssArc_cmpArcGroupsDesc
				local segsT = if isClosed shp s then (numKnots shp s) else (numKnots shp s - 1)
				for ent in uniRanges do (
					local curLo = ssArc_findKnotByPos shp s ent[3]
					local curHi = ssArc_findKnotByPos shp s ent[4]
					if curLo > 0 and curHi > 0 and (curHi - curLo) >= minArcSeg and curLo != curHi then (
						local subPts = #()
						for k = curLo to curHi do append subPts (getKnotPoint shp s k)
						local r = ssArc_fallbackSub shp s subPts curLo curHi false segsT planeTol radTolAbs radTolRel minArcSeg minArcAng
						replaced += r[1]
						filtered += r[2]
						for pp in r[3] do
							if (finditem protPos pp) == 0 do append protPos pp
					)
				)
			)
		) else (
			-- дуг-участков не нашлось: единичный фит с отсечением выбросов
			local tr = ssArc_fitWithDeviationTrim rangePts planeTol radTolAbs radTolRel SS_ARC_MAX_DEVIATION
			if tr != undefined then (
				local cFit = tr[1]
				local nFit = tr[2]
				local subLoP = gStartP + tr[5] - 1
				local subHiP = gStartP + tr[6] - 1
				local subPts = for k = subLoP to subHiP collect (getKnotPoint shp s k)
				local accRes = ssArc_accumulatedAngle subPts cFit nFit
				local accAng = accRes[1]
				local maxBack = accRes[2]
				local avgStep = if subPts.count > 1 then (abs accAng) / (subPts.count - 1) else 0.0
				local isArc = true
				if maxBack > SS_ARC_MAX_BACK_DEGREES do isArc = false
				if avgStep > 1e-6 and maxBack > avgStep * 8.0 do isArc = false
				if SS_DEBUG and not isArc do (
					format "  [arc reject] maxBack=%.1f avgStep=%.1f (sub %..%, pts=%)\n" maxBack avgStep subLoP subHiP subPts.count
				)
				if isArc then (
					local thetaFit = (if tr[4] >= 0 then 1.0 else -1.0) * (abs accAng)
					if (abs thetaFit) >= minArcAng then (
						local rr = ssArc_replaceGroup shp s subLoP subHiP cFit nFit thetaFit
						if rr[1] then (
							replaced += 1
							local nK = rr[2]
							for k = subLoP to (subLoP + nK - 1) do
								append protPos (getKnotPoint shp s k)
						)
					) else (
						filtered += 1
					)
				)
			)
		)
	)
	#(replaced, filtered, protPos)
)

-- Плотная полилиния дуги Безье, которую ПОСТРОИТ ssArc_replaceGroup /
-- ssArc_replaceGroupWrap для окружности (c, n, thetaSigned, R) между узлами-границами
-- p0/pE. Воспроизводит РОВНО ту же раскладку, что и при реальной замене (количество
-- сегментов nSeg, углы интерьерных узлов, касательные n×r, длина хендла
-- (4/3)*R*tan(subTheta/4)), поэтому отклонение исходных точек от этой полилинии =
-- отклонение от дуги ПОСЛЕ её создания (не нужно откатывать deleteKnot).
-- wrapped: true = диапазон пересекает шов замкнутого сплайна (интерьер разбивается
-- равномерно по nUse+1); isFullCircle: намотка ровно 360° (равномерно по nSeg).

-- Обработка ОДНОЙ шовной цепочки замкнутого сплайна: виртуальный диапазон [a..bU]
-- (bU в индексах сегментов, для шовных дуг bU > segsT либо bU == segsT — цепочка,
-- кончающаяся РОВНО на шовном сегменте, т.е. её последний узел — узел 1).
-- Собирает точки через шов, фитирует окружность, валидирует и заменяет участок
-- дугой Безье через ssArc_replaceGroupWrap; если весь периметр не одна окружность
-- (пришли прямые/острая ломаная) — фолбэк режет цепочку по кривизне и обрабатывает
-- поддуги через ssArc_fallbackSub (шовные — с crossesSeam=true). Корнер-узел,
-- НЕ лежащий на окружности, при этом корректно отсеется фитом (дуга не "приклеится"
-- к острому углу, а остановится в точке касания).
-- Возвращает #(заменено, отфильтрованоПоУглу, protPos).
fn ssArc_processWrapChain shp s a bU segsT planeTol radTolAbs radTolRel curvTolRel minArcSeg minArcAng = (
	local replaced = 0
	local filteredByMinAngle = 0
	local protPos = #()
	local fullPts = #()
	for k = a to (bU + 1) do (
		local ki = k
		if ki > segsT do ki -= segsT
		-- Не дублировать узел-шов: если возврат через шов попадает ровно на
		-- начальный узел (полная окружность, startK==headEnd), дубль ломает
		-- фит окружности (fitCircle3D по 3 точкам, где первая==последняя).
		if k == (bU + 1) and ki == a then exit
		append fullPts (getKnotPoint shp s ki)
	)
	if fullPts.count < 3 do (
		if SS_DEBUG do format "  [wrap skip] недостаточно точек (%)\n" fullPts.count
		return #(replaced, filteredByMinAngle, protPos)
	)
	if SS_DEBUG do
		format "  [wrap] segs %..% (virtual) pts=%\n" a bU fullPts.count

	local fullFit = ssArc_robustFit fullPts planeTol radTolAbs radTolRel
	if fullFit != undefined then (
		local accRes = ssArc_accumulatedAngle fullPts fullFit[1] fullFit[2]
		local accAng = accRes[1]
		local maxBack = accRes[2]
		local avgStep = if fullPts.count > 1 then (abs accAng) / (fullPts.count - 1) else 0.0
		local isArc = true
		if maxBack > SS_ARC_MAX_BACK_DEGREES do isArc = false
		if avgStep > 1e-6 and maxBack > avgStep * 8.0 do isArc = false
		if SS_DEBUG and not isArc do
			format "  [wrap reject] maxBack=%.1f avgStep=%.1f\n" maxBack avgStep
		-- Полная окружность охвачена, если цепочка покрывает все сегменты
		-- (в т.ч. через шов со стартом не с сегмента 1 — после склейки цепочек).
		local perimCovered = ((bU - a + 1) >= segsT)
		-- Полная окружность может оказаться правильным многоугольником
		-- (квадрат/треугольник): 4 равные стороны = 90° на шаг по углу — это
		-- НЕ дуга. Требуем достаточно мелкую угловую дискретизацию входных точек.
		if perimCovered and avgStep > SS_ARC_MAX_STEP_DEG do isArc = false
		local thetaFit = (if fullFit[4] >= 0 then 1.0 else -1.0) * (if perimCovered then 360.0 else (abs accAng))
		if SS_DEBUG do
			format "  [wrap] R=%.3f accAng=%.1f maxBack=%.1f avgStep=%.3f thetaFit=%.1f minArcAng=%.1f isArc=%\n" (distance fullFit[1] fullPts[1]) accAng maxBack avgStep thetaFit minArcAng isArc
		if isArc and (abs thetaFit) >= minArcAng then (
			local rr = ssArc_replaceGroupWrap shp s a (bU + 1) segsT fullFit[1] fullFit[2] thetaFit
			if SS_DEBUG do
				format "  [wrap replaceGroupWrap] ok=% nTotal=%\n" rr[1] rr[2]
			if rr[1] then (
				replaced += 1
				for pp in rr[3] do
					if (finditem protPos pp) == 0 do append protPos pp
			)
		) else if isArc then (
			filteredByMinAngle += 1
		)
	) else (
		-- Весь периметр НЕ является одной окружностью (капсула/многодуговой контур).
		-- Универсальный фолбэк: разбиваем цепочку по скачкам знаковой кривизны и
		-- обрабатываем каждую поддугу отдельно (прямые участки отсеиваются фитом).
		if SS_DEBUG do
			format "  [wrap] fullFit=undefined (не одна окружность) — фолбэк по кривизне\n"
		local Lfull = #()
		for i = 1 to (fullPts.count - 1) do append Lfull (distance fullPts[i] fullPts[i + 1])
		if Lfull.count >= 2 then (
			local subs = ssArc_curvatureSubranges fullPts Lfull 1 curvTolRel
			if SS_DEBUG do format "  [fallback] поддиапазонов по кривизне: %\n" subs.count
			local fbRanges = #() -- #(virtStart, subPts, wrapped)
			for rng in subs do (
				local s0 = rng[1]
				local s1 = rng[2]
				local rwrapped = (s0 > s1)
				local rsubPts = #()
				if rwrapped then (
					-- обёрнутая дуга: хвост (s0..конец) + голова (начало..s1)
					for i = s0 to fullPts.count do append rsubPts fullPts[i]
					for i = 1 to s1 do append rsubPts fullPts[i]
				) else (
					for i = s0 to s1 do append rsubPts fullPts[i]
				)
				local cntJudged = if rwrapped then ((fullPts.count - s0 + 1) + s1 - 1) else (s1 - s0)
				if rsubPts.count >= (minArcSeg + 1) and cntJudged >= minArcSeg do
					append fbRanges #((a + s0 - 1), rsubPts, rwrapped)
			)
			qsort fbRanges ssArc_cmpArcGroupsDesc
			for ent in fbRanges do (
				local subPts = ent[2]
				local wrapped = ent[3]
				if subPts.count >= (minArcSeg + 1) then (
					local curLo = ssArc_findKnotByPos shp s subPts[1]
					local curHi = ssArc_findKnotByPos shp s subPts[subPts.count]
					if curLo > 0 and curHi > 0 then (
						local crossesSeam = wrapped or (curLo > curHi)
						local r = ssArc_fallbackSub shp s subPts curLo curHi crossesSeam segsT planeTol radTolAbs radTolRel minArcSeg minArcAng
						replaced += r[1]
						filteredByMinAngle += r[2]
						for pp in r[3] do
							if (finditem protPos pp) == 0 do append protPos pp
					)
				)
			)
		)
	)
	#(replaced, filteredByMinAngle, protPos)
)


-- Возвращает #(заменено, отфильтрованоПоУглу, индексы защищённых вершин-границ дуг)
-- Внутри работает с позициями (Point3) и конвертирует в индексы ПОСЛЕ всех удалений,
fn ssArc_rebuildSpline shp s segTolPct:25 minChainSeg:8 minArcSeg:6 strictness:70 minAngleDeg:0 selectedKnots:unsupplied = (
	local replaced = 0
	local filteredByMinAngle = 0
	local allProtPos = #() -- позиции (Point3) границ дуг
	local knots = numKnots shp s
	if knots < 4 do return #(replaced, filteredByMinAngle, #())

	local closedS = isClosed shp s
	-- для замкнутых учитываем и закрывающий сегмент (шов): сегменты 1..knots
	local segsT = if closedS then knots else knots - 1

	local P = for k = 1 to knots collect (getKnotPoint shp s k)
	local L = #()
	L.count = segsT
	for i = 1 to knots - 1 do L[i] = distance P[i] P[i+1]
	if closedS do L[segsT] = distance P[knots] P[1]

	local typicalLen = ssArc_median L
	if typicalLen < 1e-6 do typicalLen = 1.0

	local tl = ssArc_strictnessToTols strictness typicalLen
	local planeTol = tl[1]
	local radTolAbs = tl[2]
	local radTolRel = tl[3]
	local curvTolRel = tl[4]

	local minArcAng = minAngleDeg
	local lenTolRel = (amax 0.1 (amin 50.0 segTolPct)) / 100.0
	local lenTolAbs = typicalLen * 0.05

	-- РЕЖИМ ВЫДЕЛЕННЫХ ВЕРШИН: группируем связные выделенные узлы,
	-- обрабатываем каждую группу как дугу, пропускаем автоматический поиск цепочек.
	if selectedKnots != unsupplied and selectedKnots.count > 0 then (
		local sortedSel = sort (deepcopy selectedKnots)
		local groups = #()
		local grpStart = sortedSel[1]
		local grpEnd = sortedSel[1]
		for i = 2 to sortedSel.count do (
			if sortedSel[i] == grpEnd + 1 then (
				grpEnd = sortedSel[i]
			) else (
				if (grpEnd - grpStart) >= minArcSeg do
					append groups #(grpStart, grpEnd)
				grpStart = sortedSel[i]
				grpEnd = sortedSel[i]
			)
		)
		if (grpEnd - grpStart) >= minArcSeg do
			append groups #(grpStart, grpEnd)

		-- Для замкнутых: проверяем группу через шов (knots и 1 соседи)
		if closedS and sortedSel.count >= 3 then (
			local hasFirst = (sortedSel[1] == 1)
			local hasLast = (sortedSel[sortedSel.count] == knots)
			if hasFirst and hasLast then (
				-- Склеиваем голову и хвост в одну группу через шов
				local headEnd = 0
				for i = 1 to sortedSel.count while sortedSel[i] == i do headEnd = i
				local tailStart = knots + 1
				for i = sortedSel.count to 1 by -1 while sortedSel[i] > (knots - (sortedSel.count - i + 1)) do tailStart = sortedSel[i]
				local wrapLen = headEnd + (knots - tailStart + 1)
				if wrapLen >= minArcSeg then (
					-- Удаляем группы head/tail если они были добавлены отдельно
					local newGroups = #()
					for gr in groups do (
						local overlaps = false
						if gr[1] <= headEnd do overlaps = true
						if gr[2] >= tailStart do overlaps = true
						if not overlaps do append newGroups gr
					)
					append newGroups #(-tailStart, headEnd) -- виртуальная: отрицательный = через шов
					groups = newGroups
				)
			)
		)

		if SS_DEBUG do (
			format "  [selected] groups.count=%\n" groups.count
			for gi = 1 to groups.count do (
				local gr = groups[gi]
				if gr[1] < 0 then
					format "	group %: wrap knots %..% (virtual)\n" gi (-gr[1]) gr[2]
				else
					format "	group %: knots %..%\n" gi gr[1] gr[2]
			)
		)

		-- Порядок обработки (важно для индексов после deleteKnot/addKnot!):
		--  1) дуги через шов — первыми, пока индексы ещё исходные;
		--  2) обычные группы: границы сохранены по ПОЗИЦИЯМ и пересчитаны в текущие
		--     индексы после замены шва, обрабатываются по УБЫВАНИЮ индекса, чтобы
		--     удаления в старшей группе не сдвигали узлы младших групп.
		local plainRanges = #() -- #(origStart, pLo, pHi)
		for gr in groups do (
			if gr[1] >= 0 do
				append plainRanges #(gr[1], getKnotPoint shp s gr[1], getKnotPoint shp s gr[2])
		)

		-- 1) Дуги через шов
		for gr in groups do (
			if gr[1] >= 0 then continue
			local tailStartK = -gr[1]
			local headEndK = gr[2]
			local fullPts = #()
			for k = tailStartK to knots do append fullPts (getKnotPoint shp s k)
			for k = 1 to headEndK do append fullPts (getKnotPoint shp s k)
			if fullPts.count >= 3 then (
				local fullFit = ssArc_robustFit fullPts planeTol radTolAbs radTolRel
				if fullFit != undefined then (
					local accRes = ssArc_accumulatedAngle fullPts fullFit[1] fullFit[2]
					local accAng = accRes[1]
					local maxBack = accRes[2]
					local avgStep = if fullPts.count > 1 then (abs accAng) / (fullPts.count - 1) else 0.0
					local isArc = true
					if maxBack > SS_ARC_MAX_BACK_DEGREES do isArc = false
					if avgStep > 1e-6 and maxBack > avgStep * 8.0 do isArc = false
					-- Вся окружность охвачена, если головная и хвостовая части вместе
					-- покрывают все узлы. Именно такой "полный периметр" важно проверять
					-- на правильный многоугольник ниже (не только когда шов в узле 1).
					local perimCovered = ((knots - tailStartK + 1) + headEndK) >= knots
					-- Полное кольцо замкнутого может оказаться правильным многоугольником
					-- (квадрат/треугольник) — шаг по углу велик, это не дуга.
					if perimCovered and avgStep > SS_ARC_MAX_STEP_DEG do isArc = false
					if isArc then (
						-- Полная окружность: дуга замыкает ровно 360°. avgStep/accAng
						-- недосчитывают последний шаг (без дубля шва), поэтому фиксируем
						-- угол = ±360, чтобы кольцо замкнулось в точку.
						local thetaFit = (if fullFit[4] >= 0 then 1.0 else -1.0) * (if perimCovered then 360.0 else (abs accAng))
						if (abs thetaFit) >= minArcAng then (
							local aVirt = tailStartK
							local bVirt = knots + headEndK
							local rr = ssArc_replaceGroupWrap shp s aVirt bVirt segsT fullFit[1] fullFit[2] thetaFit
							if rr[1] then (
								replaced += 1
								for pp in rr[3] do
									if (finditem allProtPos pp) == 0 do append allProtPos pp
							)
						) else (
							filteredByMinAngle += 1
						)
					)
				)
			)
		)

		-- 2) Обычные группы: по убыванию исходного начала, с пересчётом индексов по позициям.
		qsort plainRanges ssArc_cmpArcGroupsDesc
		for ent in plainRanges do (
			local curLo = ssArc_findKnotByPos shp s ent[2]
			local curHi = ssArc_findKnotByPos shp s ent[3]
			if curLo > 0 and curHi > 0 and (curHi - curLo) >= minArcSeg then (
				local r = ssArc_processRange shp s curLo curHi L planeTol radTolAbs radTolRel curvTolRel minArcSeg minArcAng
				replaced += r[1]
				filteredByMinAngle += r[2]
				for pp in r[3] do
					if (finditem allProtPos pp) == 0 do append allProtPos pp
			)
		)

		-- Переходим к pos→idx
	) else (
	-- 1) цепочки почти равных сегментов; для замкнутых обход циклический,
	--	поэтому цепочка может переходить через шов (bU > segsT)
	local chains = #()
	local i = 1
	local scanned = 0
	while scanned < segsT do (
		local meanLen = L[i]
		local cnt = 1
		while cnt < segsT do (
			-- Не сканировать дальше segsT — остатокbelongs to следующей цепочки.
			-- Иначе цепочка через шов «заезжает» в сегменты головы и merge
			-- дважды считает перекрытие.
			if (scanned + cnt) >= segsT do exit
			local nextU = i + cnt
			local q = (nextU - 1) / segsT
			local nextSeg = (nextU - 1) - q * segsT + 1
			local tol = amax lenTolAbs (lenTolRel * meanLen)
			if abs(L[nextSeg] - meanLen) > tol then exit
			meanLen = (meanLen * 0.8 + L[nextSeg] * 0.2)
			cnt += 1
		)
		append chains #(i, i + cnt - 1, meanLen)
		scanned += cnt
		i = i + cnt
		if i > segsT do i -= segsT
	)

	if SS_DEBUG do (
		format "  [chains] segsT=% closed=% chains.count=%\n" segsT closedS chains.count
		for ci2 = 1 to chains.count do
			format "	цепочка %: segs %..% (% шт) meanLen=%\n" ci2 chains[ci2][1] chains[ci2][2] (chains[ci2][2]-chains[ci2][1]+1) chains[ci2][3]
	)

	-- скан всегда стартует с сегмента 1, поэтому дуга, переходящая через шов,
	-- оказывается разрезана надвое: голова (с сегмента 1) и хвост (до segsT).
	-- Склеиваем если длина шовного сегмента (segsT) и первого (1) совпадают
	-- (реальные длины, без сглаживания — دقнее для коротких цепочек)
	if closedS and chains.count >= 2 then (
		local fst = chains[1]
		local lst = chains[chains.count]
		if fst[1] == 1 and lst[2] >= segsT then (
			local seamTol = amax lenTolAbs (lenTolRel * (amax L[segsT] L[1]))
			if (abs (L[segsT] - L[1])) <= seamTol then (
				chains[chains.count] = #(lst[1], lst[2] + fst[2], lst[3])
				deleteItem chains 1
				if SS_DEBUG do format "  Дуги: склеена цепочка через шов (L[segsT]=% L[1]=%)\n" L[segsT] L[1]
			)
		)
	)

	-- 2) диапазоны узлов.
	--	Обычные дуги: диапазон [a..bU+1] в реальных индексах узлов.
	--	Дуга через шов: виртуальный диапазон [a..bU+1] где bU+1 > segsT.
	--	Полная окружность (цепочка покрывает всё): узел 1 служит и началом и
	--	концом, поэтому обрабатываем как виртуальный диапазон через шов
	--	#(1, segsT), который в шаге 3 соберёт сегменты 1..segsT с возвратом к 1
	--	(виртуальный конец segsT+1) и заменит всё кольцо дугами Безье (14 сегментов
	--	по SS_ARC_MIN_SEG_DEGREE=25° для полной окружности).
	local ranges = #()
	local wrapChains = #() -- дуги через шов: #(a, bU, meanLen)
	for ch in chains do (
		local a = ch[1]
		local bU = ch[2]
		local chainLen = bU - a + 1
		local isFullCircle = closedS and a == 1 and chainLen >= segsT
		local passed = chainLen >= minChainSeg
		if SS_DEBUG do
			format "  [range] chain segs %..% len=% minChainSeg=% fullCircle=% → %\n" a bU chainLen minChainSeg isFullCircle (if isFullCircle then "ПОЛНАЯ ОКРУЖНОСТЬ (через шов)" else (if passed then "ПРОШЛА" else "ОТКЛОНЕНА"))
		if isFullCircle then (
			-- Узел 1 — единственная граница: всю окружность обрабатываем как шов
			append wrapChains #(1, segsT, ch[3])
		) else if passed then (
			if bU <= segsT then (
				-- Обычная дуга (не через шов)
				if closedS and bU == segsT then append ranges #(a, knots)
				else append ranges #(a, bU + 1)
			)
			else (
				-- Дуга через шов: сохраняем как виртуальный диапазон
				append wrapChains #(a, bU, ch[3])
			)
		)
	)

	-- 3) обработка дуг через шов ПЕРВОЙ, пока индексы узлов не сдвинуты
	for wc in wrapChains do (
		local r = ssArc_processWrapChain shp s wc[1] wc[2] segsT planeTol radTolAbs radTolRel curvTolRel minArcSeg minArcAng
		replaced += r[1]
		filteredByMinAngle += r[2]
		for pp in r[3] do
			if (finditem allProtPos pp) == 0 do append allProtPos pp
	)

	-- 4) обработка обычных диапазонов: пересчитываем цепочки
	--	после удаления дуг через шов (узлов могло стать меньше)
	local curNk = numknots shp s
	local curSegsT = if isClosed shp s then curNk else (curNk - 1)
	local L2 = #()
	for kk = 1 to curSegsT do (
		local pA = getKnotPoint shp s kk
		local pB = getKnotPoint shp s (if kk < curNk then kk+1 else 1)
		append L2 (distance pA pB)
	)
	local ranges2 = #()
	local wrap2 = #() -- шага 4: цепочки, заканчивающиеся РОВНО на шовном сегменте
	if curSegsT > 1 then (
		local i2 = 1
		local scanned2 = 0
		while scanned2 < curSegsT do (
			local meanLen2 = L2[i2]
			local cnt2 = 1
			while cnt2 < curSegsT do (
				if (scanned2 + cnt2) >= curSegsT do exit
				local nextU2 = i2 + cnt2
				local q2 = (nextU2 - 1) / curSegsT
				local nextSeg2 = (nextU2 - 1) - q2 * curSegsT + 1
				local tol2 = amax lenTolAbs (lenTolRel * meanLen2)
				if abs(L2[nextSeg2] - meanLen2) > tol2 then exit
				meanLen2 = (meanLen2 * 0.8 + L2[nextSeg2] * 0.2)
				cnt2 += 1
			)
			if cnt2 >= minChainSeg then (
				local a2 = i2
				local b2 = i2 + cnt2 - 1
				local fullCircle2 = (cnt2 >= curSegsT)
				if not fullCircle2 then (
					if closedS and b2 == curSegsT then (
						-- Цепочка заканчивается РОВНО на шовном сегменте: её последний
						-- узел — узел 1 (шов). Раньше endVtx зажимался на curNk и шовная
						-- точка терялась: дуга прилипала к точке касания вместо того,
						-- чтобы замкнуться через шов. Теперь обрабатываем как дугу через
						-- шов с виртуальным концом curSegsT+1 (замена защитит узел-шов
						-- как границу через ssArc_replaceGroupWrap).
						append wrap2 #(a2, b2)
						if SS_DEBUG do format "  [range2] segs %..% len=% → ШОВНАЯ (вирт. конец %)\n" a2 b2 cnt2 (b2 + 1)
					) else (
						local endVtx = b2 + 1
						if endVtx > curNk do endVtx = curNk
						append ranges2 #(a2, endVtx)
						if SS_DEBUG do format "  [range2] segs %..% len=%\n" a2 b2 cnt2
					)
				)
			)
			scanned2 += cnt2
			i2 = i2 + cnt2
			if i2 > curSegsT do i2 -= curSegsT
		)
	)

	-- 4a) шовные цепочки шага 4 обрабатываем до обычных диапазонов:
	--	их удаления лежат на индексах не ниже начала цепочки (последняя из
	--	последовательных цепочек с максимальным a2), поэтому индексы остальных
	--	диапазонов (ниже по номеру) не сдвигаются.
	for wc2 in wrap2 do (
		local r = ssArc_processWrapChain shp s wc2[1] wc2[2] curSegsT planeTol radTolAbs radTolRel curvTolRel minArcSeg minArcAng
		replaced += r[1]
		filteredByMinAngle += r[2]
		for pp in r[3] do
			if (finditem allProtPos pp) == 0 do append allProtPos pp
	)

	if SS_DEBUG do (
		format "  [ranges2] curSegsT=% ranges=%\n" curSegsT ranges2.count
	)
	qsort ranges2 ssArc_cmpArcGroups
	for idx = ranges2.count to 1 by -1 do (
		local rng = ranges2[idx]
		local r = ssArc_processRange shp s rng[1] rng[2] L2 planeTol radTolAbs radTolRel curvTolRel minArcSeg minArcAng
		replaced += r[1]
		filteredByMinAngle += r[2]
		for pp in r[3] do
			if (finditem allProtPos pp) == 0 do append allProtPos pp
	)
	) -- end else (auto chain detection)

	-- 5) Преобразование позиций -> ТЕКУЩИЕ индексы узлов.
	local protected = #()
	local nkFinal = numKnots shp s
	if SS_DEBUG do (
		format "  [pos→idx] nkFinal=% allProtPos.count=%\n" nkFinal allProtPos.count
		format "  [pos→idx] allProtPos=\n"
		for ii = 1 to allProtPos.count do (
			local pp = allProtPos[ii]
			format "	[%] pos=(%,%,%)\n" ii pp.x pp.y pp.z
		)
		format "  [pos→idx] Текущие узлы сплайна (%):\n" nkFinal
		for ci = 1 to nkFinal do (
			local kp = getKnotPoint shp s ci
			format "	[%] pos=(%,%,%)\n" ci kp.x kp.y kp.z
		)
	)
	for pp in allProtPos do (
		local foundIdx = 0
		local bestDist = 1e30
		for ci = 1 to nkFinal do (
			local d = distance (getKnotPoint shp s ci) pp
			if d < bestDist do (bestDist = d; foundIdx = ci)
			if d < 1.0 do (
				if (finditem protected ci) == 0 do append protected ci
				exit
			)
		)
		if SS_DEBUG do format "  [pos→idx] pos=(%,%,%) bestDist=% idx=%\n" pp.x pp.y pp.z bestDist foundIdx
	)
	sort protected
	if SS_DEBUG do format "  [pos→idx] ИТОГО protected=%\n" protected
	#(replaced, filteredByMinAngle, protected)
)

-- Повторное выделение диапазона [pLo..pHi] после удаления избыточных узлов.
-- Границы диапазона сохранены по позициям (Point3) — находим их новые индексы
-- по ближайшему узлу. Возвращает МАССИВ для выделения (сам выбор НЕ выполняет,
-- чтобы несколько диапазонов можно было накопить и выделить одним вызовом с
-- keep:false, а не затирать друг друга):
--   mode:1 → массив индексов узлов;  mode:2 → массив индексов сегментов.
fn ssReselectRange obj s_num pLo pHi mode:1 = (
	local nk = numKnots obj s_num
	if nk < 1 do return #()
	local idxLo = 0
	local idxHi = 0
	local dLo = 1e30
	local dHi = 1e30
	for k = 1 to nk do (
		local d = distance (getKnotPoint obj s_num k) pLo
		if d < dLo do (dLo = d; idxLo = k)
	)
	for k = 1 to nk do (
		local d = distance (getKnotPoint obj s_num k) pHi
		if d < dHi do (dHi = d; idxHi = k)
	)
	-- Почти всегда ближайшие узлы — это сами сохранившиеся границы. Не отбрасываем
	-- диапазон по жёсткому расстоянию: после фита дуг границы могут сместиться на
	-- доли/единицы. Достаточно, что обе границы найдены.
	if idxLo == 0 or idxHi == 0 do return #()
	if mode == 2 then (
		-- Режим сегментов: сегменты между найденными узлами-границами.
		local segs = #()
		if idxLo <= idxHi then (
			for k = idxLo to (idxHi - 1) do append segs k
		) else (
			for k = idxLo to nk do append segs k
			for k = 1 to (idxHi - 1) do append segs k
		)
		return segs
	)
	local sel = #()
	if idxLo <= idxHi then (
		for k = idxLo to idxHi do append sel k
	) else (
		for k = idxLo to nk do append sel k
		for k = 1 to idxHi do append sel k
	)
	sel
)

-- ТОЧКА ВХОДА: восстановление дуг во всех сплайнах выбранной формы.
-- Запускать ДО упрощения (кнопка удаления вершин). Не вызываете - механизм выключен.
-- Границы заменённых дуг запоминаются в SS_ARC_PROTECTED (по индексу сплайна)
-- и исключаются из удаления в run_rebuildBezier.
--
-- Логика выделения (идентична run_rebuildBezier):
--   subobject 0 (object): автоматический режим по ВСЕМ сплайнам
--   subobject 1 (vertex): только выделенные вершины (если ничего не выделено — пропуск)
--   subobject 2 (segment): сегменты → обе вершины сегмента (начало и конец), как subobject 1
--   subobject 3 (spline): только выделенные сплайны, автоматический поиск дуг
fn run_rebuildArcs = (
	global SS_ARC_PROTECTED
	SS_ARC_PROTECTED = #()
	local savedSubObjLevel = subObjectLevel
	if selection.count == 0 then (
		format "Дуги: не выбрано ни одного объекта\n"
		return OK
	)
	local processed = 0
	local noneFound = true

	for obj in selection do (
		if not (superclassof obj.baseobject == Shape) then continue

		-- per-object: resolve splines to process + selected knots
		local splinesToProcess = #()
		local knotsPerSpline = #()

		if savedSubObjLevel == 0 then (
			for s = 1 to numSplines obj do (
				append splinesToProcess s
				append knotsPerSpline unsupplied
			)
		) else if savedSubObjLevel == 1 then (
			for s_num = 1 to numSplines obj do (
				local sel = getKnotSelection obj s_num
				if sel != undefined and sel.count > 0 then (
					append splinesToProcess s_num
					append knotsPerSpline sel
				)
			)
		) else if savedSubObjLevel == 2 then (
			for s_num = 1 to numSplines obj do (
				local selSeg = getSegSelection obj s_num
				if selSeg != undefined and selSeg.count > 0 then (
					local nk = numKnots obj s_num
					local knots = #()
					for seg in selSeg do (
						append knots seg
						local k2 = if seg < nk then (seg + 1) else 1
						append knots k2
					)
					knots = makeUniqueArray knots
					append splinesToProcess s_num
					append knotsPerSpline knots
				)
			)
		) else if savedSubObjLevel == 3 then (
			local selSplines = getSplineSelection obj
			if selSplines != undefined and selSplines.count > 0 then (
				for s in selSplines do (
					append splinesToProcess s
					append knotsPerSpline unsupplied
				)
			)
		)

		if splinesToProcess.count == 0 then continue

		local savedSel = #() -- режим 1: #(s_num, #positions); режим 2: #(s_num, pLo, pHi)
		if savedSubObjLevel == 1 then (
			for i = 1 to splinesToProcess.count do (
				local s_num = splinesToProcess[i]
				local sel = knotsPerSpline[i]
				if sel != unsupplied and sel.count > 0 then (
					local positions = for k in sel collect (getKnotPoint obj s_num k)
					append savedSel #(s_num, positions)
				)
			)
		) else if savedSubObjLevel == 2 then (
			-- Запоминаем границы каждого сплошного диапазона выбранных сегментов
			-- (крайние узлы) для повторного выделения сегментов после обработки.
			for i = 1 to splinesToProcess.count do (
				local s_num = splinesToProcess[i]
				local sel = knotsPerSpline[i]
				if sel != unsupplied and sel.count > 0 then (
					local nk = numKnots obj s_num
					local grpL = getGroups sel (isClosed obj s_num) nk
					for grp in grpL do (
						if grp.count >= 2 do
							append savedSel #(s_num, getKnotPoint obj s_num grp[1], getKnotPoint obj s_num grp[grp.count])
					)
				)
			)
		)

		undo "Rebuild Arcs" on (
			local objRepl = 0
			local objProt = 0
			for i = 1 to splinesToProcess.count do (
				local s_num = splinesToProcess[i]
				local selK = knotsPerSpline[i]
				local r = ssArc_rebuildSpline obj s_num segTolPct:SS_ARC_LEN_TOL_PCT minChainSeg:SS_ARC_MIN_CHAIN_SEG minArcSeg:SS_ARC_MIN_ARC_SEG minAngleDeg:SS_ARC_MIN_SEG_DEGREE selectedKnots:selK
				local nk = numknots obj s_num
				ssArc_setProtected obj s_num r[3]
				local protList = ssArc_protectedFor obj s_num
				objRepl += r[1]
				objProt += protList.count
				format "Дуги [сплайн %]: заменено %, защищено % вершин (отфильтровано %)\n" s_num r[1] protList.count r[2]
				if SS_DEBUG do (
					format "  [rebuild s%] arc-boundary indices=%\n" s_num r[3]
					format "  [rebuild s%] protected indices=%\n" s_num protList
					format "  [rebuild s%] итого узлов=%\n" s_num nk
					for idx in protList do (
						if idx >= 1 and idx <= nk do
							format "  [rebuild s%] prot[%] узел % позиция=(%,%,%)\n" s_num idx idx (getKnotPoint obj s_num idx).x (getKnotPoint obj s_num idx).y (getKnotPoint obj s_num idx).z
					)
				)
			)
			updateShape obj
			if objRepl > 0 do noneFound = false
			processed += 1
			if objRepl > 0 then format "Всего [%]: дуг %, защищённых вершин %\n" obj.name objRepl objProt
		)
		if savedSel.count > 0 then (
			if savedSubObjLevel == 2 then (
				-- Режим сегментов: накапливаем сегменты ВСЕХ диапазонов и выделяем одним
				-- setSegSelection на сплайн, чтобы диапазоны не затирали друг друга.
				local perSpline = #() -- #(#s_num, #segs)
				for entry in savedSel do (
					local s_num = entry[1]
					local segs = ssReselectRange obj s_num entry[2] entry[3] mode:2
					if segs.count > 0 then (
						local bucket = undefined
						for ps in perSpline do (
							if ps[1] == s_num do bucket = ps
						)
						if bucket == undefined then (
							bucket = #(s_num, #())
							append perSpline bucket
						)
						for sg in segs do
							if (finditem bucket[2] sg) == 0 do append bucket[2] sg
					)
				)
				for ps in perSpline do setSegSelection obj ps[1] ps[2]
			) else (
				for entry in savedSel do (
					local s_num = entry[1]
					local positions = entry[2]
					local newSel = #()
					local nk = numknots obj s_num
					for pos in positions do (
						local bestIdx = 0
						local bestDist = 1e30
						for k = 1 to nk do (
							local d = distance (getKnotPoint obj s_num k) pos
							if d < bestDist do (bestDist = d; bestIdx = k)
						)
						if bestIdx > 0 and bestDist < 1.0 do (
							if (finditem newSel bestIdx) == 0 do append newSel bestIdx
						)
					)
					setKnotSelection obj s_num newSel
				)
			)
		)
	)

	if processed == 0 then format "Выберите форму, базовым объектом которой является сплайн (SplineShape/Line)\n"
	else if noneFound then format "Дуги: окружностей не найдено\n"
	OK
)


/* --------------------
--
-- Восстановление линий (run_rebuildLines)
--
*/ --------------------

-- Слияние подряд идущих коллинеарных сегментов (ЛЮБОЙ длины) в один прямой сегмент:
-- удаляются внутренние узлы сплошных прямых прогонов. После этого границы дуг
-- определяются по чистым линиям (в мастере run_simplifySpline этот проход идёт
-- ПЕРВЫМ). Сегмент считается прямым, если его фактическая длина (buildSplineCumLengths,
-- квадратура по касательной Безье) равна расстоянию между узлами — у дуг ручки отогнуты,
-- поэтому их узлы этот проход не трогает даже при большой SS_LINE_STRAIGHT_TOL.
-- Допуск поворота на узел SS_LINE_STRAIGHT_TOL (по умолчанию 2°). Вырожденные
-- сегменты (дублирующиеся узлы, длина ~1e-9) удаляются с восстановлением ручек
-- Безье соседних узлов.
-- Логика выделения идентична run_rebuildArcs:
--   subobject 0 — все сплайны, 1 — выделенные вершины, 2 — сегменты,
--   3 — выделенные сплайны. Для 1/2 после обработки выборка восстанавливается
-- по позициям границ (индексы пересчитываются).
fn run_rebuildLines = (
	global SS_ARC_PROTECTED
	local savedSubObjLevel = subObjectLevel
	if selection.count == 0 then (
		format "Линии: не выбрано ни одного объекта\n"
		return OK
	)
	local tolDeg = if SS_LINE_STRAIGHT_TOL == undefined then 2.0 else SS_LINE_STRAIGHT_TOL
	local straightCos = cos tolDeg
	local processed = 0

	for obj in selection do (
		if not (superclassof obj.baseobject == Shape) then continue

		-- per-object: resolve splines to process + selected knots
		local splinesToProcess = #()
		local knotsPerSpline = #()

		if savedSubObjLevel == 0 then (
			for s = 1 to numSplines obj do (
				append splinesToProcess s
				append knotsPerSpline unsupplied
			)
		) else if savedSubObjLevel == 1 then (
			for s_num = 1 to numSplines obj do (
				local sel = getKnotSelection obj s_num
				if sel != undefined and sel.count > 0 then (
					append splinesToProcess s_num
					append knotsPerSpline sel
				)
			)
		) else if savedSubObjLevel == 2 then (
			for s_num = 1 to numSplines obj do (
				local selSeg = getSegSelection obj s_num
				if selSeg != undefined and selSeg.count > 0 then (
					local nk = numKnots obj s_num
					local knots = #()
					for seg in selSeg do (
						append knots seg
						local k2 = if seg < nk then (seg + 1) else 1
						append knots k2
					)
					knots = makeUniqueArray knots
					append splinesToProcess s_num
					append knotsPerSpline knots
				)
			)
		) else if savedSubObjLevel == 3 then (
			local selSplines = getSplineSelection obj
			if selSplines != undefined and selSplines.count > 0 then (
				for s in selSplines do (
					append splinesToProcess s
					append knotsPerSpline unsupplied
				)
			)
		)

		if splinesToProcess.count == 0 then continue

		local savedSel = #() -- режим 1: #(s_num, #positions); режим 2: #(s_num, pLo, pHi)
		if savedSubObjLevel == 1 then (
			for i = 1 to splinesToProcess.count do (
				local s_num = splinesToProcess[i]
				local sel = knotsPerSpline[i]
				if sel != unsupplied and sel.count > 0 then (
					local positions = for k in sel collect (getKnotPoint obj s_num k)
					append savedSel #(s_num, positions)
				)
			)
		) else if savedSubObjLevel == 2 then (
			for i = 1 to splinesToProcess.count do (
				local s_num = splinesToProcess[i]
				local sel = knotsPerSpline[i]
				if sel != unsupplied and sel.count > 0 then (
					local nk = numKnots obj s_num
					local grpL = getGroups sel (isClosed obj s_num) nk
					for grp in grpL do (
						if grp.count >= 2 do
							append savedSel #(s_num, getKnotPoint obj s_num grp[1], getKnotPoint obj s_num grp[grp.count])
					)
				)
			)
		)

		undo "Rebuild Lines" on (
			local objDel = 0
			for i = 1 to splinesToProcess.count do (
				local s_num = splinesToProcess[i]
				local selK = knotsPerSpline[i]
				local nk = numKnots obj s_num
				if nk < 3 then continue
				local closedS = isClosed obj s_num
				local pts = for k = 1 to nk collect (getKnotPoint obj s_num k)
				-- Таблица кумулятивных длин сегментов (встроенная здесь sqrt-квадратура
				-- по касательной Безье, см. buildSplineCumLengths): cum[i] = длина дуги
				-- до узла i. Длина сегмента seg = cum[seg+1] - cum[seg]. Сегмент считается
				-- ПРЯМЫМ, если его Безье-длина равна хорде (ручки лежат на хорде). Если
				-- ручки отогнуты (длина > хорды) — это дуга, её узлы НЕ трогаем, даже
				-- когда хорды почти коллинеарны. Такая проверка не зависит от индексов
				-- и сама защищает дуги.
				local cum = buildSplineCumLengths obj s_num
				local relTol = 1e-4
				local epsL = 1e-9
				local deletable = #()
				local degenerate = #()
				local degSave = #() -- #(prevPos, prevOut, nextPos, nextIn) — ручки Безье для восстановления
				for k = 1 to nk do (
					if not closedS and (k == 1 or k == nk) then continue
					if selK != unsupplied and (finditem selK k) == 0 then continue
					local prev = if k == 1 then nk else (k - 1)
					local next = if k == nk then 1 else (k + 1)
					local d1 = pts[k] - pts[prev]
					local d2 = pts[next] - pts[k]
					local l1 = length d1
					local l2 = length d2
					if l2 < epsL then (
						-- вырожденный сегмент (дублирующиеся узлы): удаляем его узел,
						-- но запоминаем ручки Безье соседей для восстановления кривой
						if (finditem degenerate k) == 0 do append degenerate k
						append degSave #(pts[prev], getOutVec obj s_num prev, pts[next], getInVec obj s_num next)
					) else if l1 < epsL then (
						continue -- дубль уже обработан как начало своего нулевого сегмента
					) else (
						local slIn = cum[prev + 1] - cum[prev]
						local slOut = cum[k + 1] - cum[k]
						local tolIn = amax #((l1 * relTol), 1e-6)
						local tolOut = amax #((l2 * relTol), 1e-6)
						if SS_DEBUG do (
							format "  [point %] prev=% next=% (l1=% l2=%) dot=% slIn=% slOut=%\n" k d1 d2 l1 l2 (dot (d1 / l1) (d2 / l2)) slIn slOut
						)
						if slIn - l1 > tolIn then continue
						if slOut - l2 > tolOut then continue
						if (dot (d1 / l1) (d2 / l2)) < straightCos then continue
						append deletable k
					)
				)
				local todel = deletable + degenerate
				if todel.count == 0 then continue
				-- Замкнутый сплайн не должен схлопнуться менее чем до 3 узлов (иначе
				-- кольцо вырождается): избыточные для этого узлы вычёркиваем из списка.
				if closedS and (nk - todel.count) < 3 do (
					local keep = todel.count - (nk - 3)
					todel = for dd = 1 to (todel.count - keep) collect todel[dd]
				)
				if todel.count == 0 then continue
				local sorted = sort todel
				local nDel = 0
				for dk = sorted.count to 1 by -1 do (
					deleteKnot obj s_num sorted[dk]
					nDel += 1
				)
				updateShape obj
				-- Восстанавливаем ручки Безье, чтобы удаление вырожденных сегментов не
				-- исказило кривую: границы находим по позициям (индексы уехали).
				for rec in degSave do (
					local nk2 = numKnots obj s_num
					local idx = 0
					local bestD = 1e30
					for kk = 1 to nk2 do (
						local dd = distance (getKnotPoint obj s_num kk) rec[1]
						if dd < bestD do (bestD = dd; idx = kk)
					)
					if idx > 0 and bestD < epsL and (length rec[2]) > epsL do setOutVec obj s_num idx rec[2]
					idx = 0; bestD = 1e30
					for kk = 1 to nk2 do (
						local dd = distance (getKnotPoint obj s_num kk) rec[3]
						if dd < bestD do (bestD = dd; idx = kk)
					)
					if idx > 0 and bestD < epsL and (length rec[4]) > epsL do setInVec obj s_num idx rec[4]
				)
				updateShape obj
				objDel += nDel
				if nDel > 0 then format "Линии [сплайн %]: удалено узлов % (было %)\n" s_num nDel nk
				if SS_DEBUG do (
					format "  [lines s%] nKnots=% del=% deg=% (tol=%)\n" s_num nk nDel degenerate.count tolDeg
					format "  [lines s%] deletedIndices=% degenerate=%\n" s_num sorted degenerate
				)
			)
			processed += 1
			if objDel > 0 then format "Всего [%]: слито узлов линий %\n" obj.name objDel
		)

		if savedSel.count > 0 then (
			if savedSubObjLevel == 2 then (
				local perSpline = #() -- #(#s_num, #segs)
				for entry in savedSel do (
					local s_num = entry[1]
					local segs = ssReselectRange obj s_num entry[2] entry[3] mode:2
					if segs.count > 0 then (
						local bucket = undefined
						for ps in perSpline do (
							if ps[1] == s_num do bucket = ps
						)
						if bucket == undefined then (
							bucket = #(s_num, #())
							append perSpline bucket
						)
						for sg in segs do
							if (finditem bucket[2] sg) == 0 do append bucket[2] sg
					)
				)
				for ps in perSpline do setSegSelection obj ps[1] ps[2]
			) else (
				for entry in savedSel do (
					local s_num = entry[1]
					local positions = entry[2]
					local newSel = #()
					local nk = numknots obj s_num
					for pos in positions do (
						local bestIdx = 0
						local bestDist = 1e30
						for k = 1 to nk do (
							local d = distance (getKnotPoint obj s_num k) pos
							if d < bestDist do (bestDist = d; bestIdx = k)
						)
						if bestIdx > 0 and bestDist < 1.0 do (
							if (finditem newSel bestIdx) == 0 do append newSel bestIdx
						)
					)
					setKnotSelection obj s_num newSel
				)
			)
		)
	)

	if processed == 0 then format "Выберите форму, базовым объектом которой является сплайн (SplineShape/Line)\n"
	OK
)




-- Логика выделения (идентична run_rebuildArcs):
--   subobject 0 (object): автоматический режим по ВСЕМ сплайнам (автовыбор опорных)
--   subobject 1 (vertex): только выделенные вершины (если ничего не выделено — пропуск)
--   subobject 2 (segment): сегменты → обе вершины сегмента (начало и конец),
--                          границы выбранных диапазонов СОХРАНЯЮТСЯ (не удаляются),
--                          упрощается только внутренность; после обработки диапазоны
--                          повторно выделяются (по сохранённым позициям границ).
--   subobject 3 (spline): только выделенные сплайны, автовыбор опорных
fn run_rebuildBezier = (
	global SS_ARC_PROTECTED
	local savedSubObjLevel = subObjectLevel
	if selection.count == 0 then (
		format "Упрощение: не выбрано ни одного объекта\n"
		return OK
	)
		local processed = 0
		local rangesToReselect = #() -- #(s_num, pLo, pHi) — диапазоны для повторного выделения

		for obj in selection do (
		if not (superclassof obj.baseobject == Shape) then continue

		local autoDetectSplines = #()
		if savedSubObjLevel == 0 then (
			for s = 1 to numSplines obj do append autoDetectSplines s
		) else if savedSubObjLevel == 2 then (
			for s_num = 1 to numSplines obj do (
				local selSeg = getSegSelection obj s_num
				if selSeg != undefined and selSeg.count > 0 then (
					local nk = numKnots obj s_num
					local knots = #()
					for seg in selSeg do (
						append knots seg
						local k2 = if seg < nk then (seg + 1) else 1
						append knots k2
					)
					knots = makeUniqueArray knots
					-- Сохраняем границы используемых диапазонов (крайние точки) для
					-- повторного выделения после оптимизации.
					local grpL = getGroups knots (isClosed obj s_num) nk
					for grp in grpL do (
						if grp.count >= 2 do
							append rangesToReselect #(s_num, getKnotPoint obj s_num grp[1], getKnotPoint obj s_num grp[grp.count])
					)
					subobjectlevel = 1
					setKnotSelection obj s_num knots
				)
			)
		) else if savedSubObjLevel == 1 then (
			for s_num = 1 to numSplines obj do (
				local sel = getKnotSelection obj s_num
				if sel != undefined and sel.count > 0 then (
					local nk = numKnots obj s_num
					local grpL = getGroups (makeUniqueArray (sort sel)) (isClosed obj s_num) nk
					for grp in grpL do (
						if grp.count >= 2 do
							append rangesToReselect #(s_num, getKnotPoint obj s_num grp[1], getKnotPoint obj s_num grp[grp.count])
					)
				)
			)
		) else if savedSubObjLevel == 3 then (
			local selSplines = getSplineSelection obj
			if selSplines != undefined and selSplines.count > 0 then (
				for s in selSplines do append autoDetectSplines s
			)
		)

		undo on (
			if autoDetectSplines.count > 0 then (
				for s_num in autoDetectSplines do (
					local isClosedSpline = isClosed obj s_num
					local nKnots = numKnots obj s_num
					local points = for i = 1 to nKnots collect (getKnotPoint obj s_num i)

					local useSchneider = if SS_USE_SCHNEIDER == undefined then true else SS_USE_SCHNEIDER
					local tolPct = if SS_TOLERANCE_PCT == undefined then 0.1 else SS_TOLERANCE_PCT
					local supportPoints = if useSchneider \
						then findSupportPointsSchneider obj s_num tolerancePct:tolPct \
						else findSupportPoints points isClosedSpline
					local arcProt = ssArc_protectedFor obj s_num
					local deletePoints = for i = 1 to nKnots where ((finditem supportPoints i) == 0 \
						and (finditem arcProt i) == 0) collect i
					if SS_DEBUG do (
						format "  [simplify s%] nKnots=% support=% arcProt=% delete=%\n" s_num nKnots supportPoints.count arcProt.count deletePoints.count
						format "  [simplify s%] supportPoints=%\n" s_num supportPoints
						format "  [simplify s%] arcProt=%\n" s_num arcProt
						format "  [simplify s%] deletePoints=%\n" s_num deletePoints
					)
					--subobjectlevel = 1
					setKnotSelection obj s_num deletePoints
				)
			)

			if savedSubObjLevel == 1 or savedSubObjLevel == 2 or autoDetectSplines.count > 0 then (
				for s_num = 1 to numSplines obj do (
					knots = getKnotSelection obj s_num
					nKnots = numKnots obj s_num
					isClosedSpline = isClosed obj s_num
					if knots == undefined or knots.count == 0 then continue
					if nKnots - knots.count < 2 then (
						format "Ошибка: после удаления в сплайне % останется менее 2 вершин. выделено % из %\n" s_num knots.count nKnots
						continue
					)

					if savedSubObjLevel == 2 and not isClosedSpline and ((finditem knots 1) > 0 or (finditem knots nKnots) > 0) then (
						local interior = for k in knots where (k != 1 and k != nKnots) collect k
						if (finditem knots nKnots) > 0 do deleteKnot obj s_num nKnots
						if (finditem knots 1) > 0 do (
							deleteKnot obj s_num 1
							for ik = 1 to interior.count do interior[ik] -= 1
						)
						updateShape obj
						knots = interior
						nKnots = numKnots obj s_num
						format "Разомкнутый сплайн %: крайние выделенные узлы удалены напрямую\n" s_num
					)

					isCircularSelection = isClosedSpline and knots.count > 0 and knots[1] == 1 and knots[knots.count] == nKnots
					-- Сохраняем границы в режиме сегментов (кроме выбираемого всем кольцом —
					-- там границ нет, полный цикл упрощается целиком).
					local preserveBnd = (savedSubObjLevel == 2 and not isCircularSelection)
					groups = getGroups knots isClosedSpline nKnots
					if groups.count == 0 and knots.count > 0 then (
						format "Ошибка: Некорректная выборка в сплайне %\n" s_num
						continue
					)
					if groups.count == 0 then
						continue
					if isCircularSelection then (
						start_i = 2
						end_i = groups.count-1
					) else (
						start_i = 1
						end_i = groups.count
					)
				for i in end_i to start_i by -1 do (
					vert_selection = groups[i]
					simplifySpline obj s_num vert_selection preserveBoundaries:preserveBnd
				)
				if isCircularSelection then (
					rest_of_knots = numKnots obj s_num
					diff = nKnots - rest_of_knots
					renum_knots = for num_knot in groups[groups.count] collect num_knot - diff
					final_group = renum_knots + groups[1]
					simplifySpline obj s_num final_group preserveBoundaries:preserveBnd
				)

					local smAng = if SS_SMOOTH_ANGLE == undefined then 175.0 else SS_SMOOTH_ANGLE
					if smAng > 0.0 do (
						local smTol = if SS_SMOOTH_STRAIGHT_TOL == undefined then 5.0 else SS_SMOOTH_STRAIGHT_TOL
						local nSm = smoothNearStraightKnots obj s_num angleDeg:smAng straightTolDeg:smTol
						if nSm > 0 do format "Сглажено почти-прямых узлов: % (сплайн %)\n" nSm s_num
					)
				)
			)
		)
		-- Повторно выделяем диапазоны, чтобы выделение соответствовало выбору
		-- до оптимизации (границы сохраняются позициями, индексы пересчитываются).
		-- В режиме сегментов (2) выбираем сегменты, иначе — вершины. Накапливаем
		-- все диапазоны по сплайнам и выделяем одним вызовом, чтобы диапазоны
		-- не затирали друг друга.
		local perSpline = #() -- #(#s_num, #items)
		for rr in rangesToReselect do (
			local items = ssReselectRange obj rr[1] rr[2] rr[3] mode:savedSubObjLevel
			if items.count > 0 then (
				local bucket = undefined
				for ps in perSpline do (
					if ps[1] == rr[1] do bucket = ps
				)
				if bucket == undefined then (
					bucket = #(rr[1], #())
					append perSpline bucket
				)
				for it in items do
					if (finditem bucket[2] it) == 0 do append bucket[2] it
			)
		)
		for ps in perSpline do (
			if savedSubObjLevel == 2 then
				setSegSelection obj ps[1] ps[2]
			else
				setKnotSelection obj ps[1] ps[2]
		)
		processed += 1
	)

	if processed == 0 then format "Выберите форму, базовым объектом которой является сплайн (SplineShape/Line)\n"
	subobjectlevel = savedSubObjLevel
	OK
)


/* --------------------
--
-- Единая точка входа (run_simplifySpline)
--
*/ --------------------

-- Мастер всех проходов восстановления, вызывается ПО ПОРЯДКУ:
--   1) линии   (run_rebuildLines)  — слияние коллинеарных сегментов, границы линий
--                                    становятся точным ориентиром для дуг;
--   2) дуги    (run_rebuildArcs)   — поиск и замена дискретизированных окружностей,
--                                    узлы-границы защищаются (SS_ARC_PROTECTED);
--   3) безье   (run_rebuildBezier) — сокращение избыточных вершин с учётом защиты дуг
--                                    и выравнивание хендлов почти-прямых узлов.
-- Каждый проход сохраняет и восстанавливает subobjectlevel и собственную выборку.
-- Параметр skipArcs:true — для повторной попытки без этапа дуг (REMS_autoSimplify).
fn run_simplifySpline skipArcs:false = (
	run_rebuildLines()
	if not skipArcs do
		run_rebuildArcs()
	run_rebuildBezier()
	OK
)
