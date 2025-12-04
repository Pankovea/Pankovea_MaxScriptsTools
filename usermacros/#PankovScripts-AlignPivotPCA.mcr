/* @Pankovea Scripts - 2025.12.03
Выравнивает локальные оси вдоль длинной и короткой части геометрии объекта.

Этот скрипт анализирует геометрию выбранного объекта, вычисляет ковариационную матрицу его вершин
и находит главные компоненты (Principal Component Analysis - PCA) для определения естественной ориентации формы.
При нажатии Shift+ вызов макроскрипта происходит поиск поворота оси так, чтобы ограничивающий бокс был
минимального размера.При этом ось Z остаётся неподвижной
Обычно для квадратных объектов нужно повернуть оси, а для круглых оставить как есть.
Соответсвенно используйте Shift+

Если Ось Z ушла вниз, что координаты автоматически корректируется,
чтобы всегда быть ближе к +Z мировой системы координат.

Затем пивот объекта перемещается в центроид и поворачивается в соответствии с найденной системой координат,
при этом геометрия остаётся неподвижной в сцене.

Скрипт корректно работает даже при изначально смещённом пивоте благодаря точному пересчёту objectOffset-параметров.
Все расчёты происходят в глобальных координатах.

Скрипт работает как с геметрией, так и со сплайнами.

----------------------------------------------------
Aligns local axes along the longer and shorter dimensions of the object’s geometry.

This script analyzes the geometry of the selected object, computes the covariance matrix of its vertices,
and performs Principal Component Analysis (PCA) to determine the object's natural orientation.
When invoked with Shift+, the script searches for a rotation that minimizes the bounding box size,
while keeping the Z-axis fixed.
Typically, square-shaped objects require axis realignment, whereas circular objects should retain their original orientation—
use Shift+ accordingly.

If the object's Z-axis flips downward, its orientation is automatically adjusted
to stay as close as possible to the world +Z direction.

The object's pivot is then moved to its centroid and rotated to align with the computed coordinate system,
while the geometry itself remains fixed in the scene.

The script handles initially offset pivots correctly by precisely recalculating objectOffset parameters.
All calculations are performed in global space.

*/

macroScript Pankov_AlignPivotPCA
category:"#PankovScripts"
buttontext:"ResetPivotOffset"
tooltip:"Align pivot to object's natural orientation PCA. Shift+ to find minimal-area bounding rectangle"
(
	
on isenabled return (
	selection.count != 0
)

-- Умножение 3x3 матрицы (в виде #[[a,b,c],[d,e,f],[g,h,i]]) на вектор
fn mat33MulVec m v =
(
    local x = m[1][1]*v.x + m[1][2]*v.y + m[1][3]*v.z
    local y = m[2][1]*v.x + m[2][2]*v.y + m[2][3]*v.z
    local z = m[3][1]*v.x + m[3][2]*v.y + m[3][3]*v.z
    [x, y, z]
)

-- Вспомогательная функция: нормализация
fn safeNormalize v =
(
    local len = length v
    if len < 0.0001 then [1,0,0] else v / len
)

-- Получить первые две главные компоненты
fn getFirstTwoPC cov33 =
(
	local epsilon = 1e-6   -- Порог изменения (для ~0.01° точности)
	-- Первая компонента
    local x = safeNormalize [1,1,0.1]
    for i = 1 to 100 do
    (
		local x_old = x
        x = safeNormalize (mat33MulVec cov33 x)
		if length (x - x_old) < epsilon then exit  -- Выход при сходимости
    )

    -- Вторая компонента
    local y = [1,0,0]
    if abs(dot y x) > 0.9 then y = [0,1,0]
    if abs(dot y x) > 0.9 then y = [0,0,1]

    y = y - (dot y x) * x
    y = safeNormalize y

    for i = 1 to 100 do
    (
		local y_old = y
        local v = mat33MulVec cov33 y
        v = v - (dot v x) * x
        y = safeNormalize v
		if length (y - y_old) < epsilon then exit  -- Выход при сходимости
    )

    local z = cross x y
    z = safeNormalize z
    if dot (cross x y) z < 0 do z = -z

    #(x, y, z)
)


-- Проекция точек на плоскость (x, y)
fn projectToPlane points origin xDir yDir =
(
    local uv = #()
    for p in points do
    (
        local d = p - origin
        local u = dot d xDir
        local v = dot d yDir
        append uv [u, v, 0] -- используем point3 для удобства
    )
    uv
)

-- Вычислить ширину и высоту по осям для заданного угла
fn getBoundingBoxSize uvPoints ang =
(
    local cosA = cos ang
    local sinA = sin ang
    -- Матрица поворота на -ang (чтобы повернуть точки)
    local uMin = 1e9, uMax = -1e9
    local vMin = 1e9, vMax = -1e9

    for pt in uvPoints do
    (
        -- Поворачиваем точку на -angle (эквивалентно повороту осей на +ang)
        local u = pt.x * cosA + pt.y * sinA
        local v = -pt.x * sinA + pt.y * cosA

        if u < uMin do uMin = u
        if u > uMax do uMax = u
        if v < vMin do vMin = v
        if v > vMax do vMax = v
    )
    local width = uMax - uMin
    local height = vMax - vMin
    #(width, height, width * height)
)

-- Найти угол с минимальной площадью
fn findOptimalAngle uvPoints =
(
    local bestAngle = 0
    local minArea = 1e18

    -- Грубый поиск: от 0 до 90 градусов (остальное — симметрия)
    local step = 10 as float -- градусы
    for deg = 0 to 80 by step do
    (
        local ang = deg
        local res = getBoundingBoxSize uvPoints ang
        if res[3] < minArea do
        (
            minArea = res[3]
            bestAngle = ang
        )
    )

    -- Уточнение вокруг bestAngle
    for i = 1 to 4 do -- делаем 4 итерации для уточнения до тысячных
    (
        local newBest = bestAngle
        for offset = 0 to step by (step/10) do
        (
            local ang = bestAngle + offset
            local res = getBoundingBoxSize uvPoints ang
            if res[3] < minArea do
            (
                minArea = res[3]
                newBest = ang
            )
        )
        bestAngle = newBest
        step /= 10.0 -- уменьшаеи шаг
    )

    bestAngle
)

fn objOffsetTM obj = (
	(ScaleMatrix obj.objectOffsetScale) * \
	(obj.objectOffsetRot as Matrix3) * \
	(TransMatrix obj.objectOffsetPos)
)

fn placePivot obj targetTM = (
	/*Присваеивает новую матрицу трансформаций пивота на объект
	targetTM - в глобальных координатах
	геометрия не двигается
	*/
	local newOffsetTM = (objOffsetTM obj) * obj.transform * inverse(targetTM)
	
	-- перемещаем пивот
	obj.objectOffsetScale = newOffsetTM.scale
	obj.objectOffsetRot = newOffsetTM.rotation
	obj.objectOffsetPos = newOffsetTM.position
	
	-- после перемещения, нужно компенсировать положение 
	obj.transform = targetTM
)

fn sort_axis v = ( -- v: piont3
	/*возвращает отсортированный массив индексов осей по убыванию длины
	*/
	v = [abs v.x, abs v.y, abs v.z]
	case of (
		(v[1] > v[2] and v[2] > v[3]): #(1,2,3)
		(v[1] > v[3] and v[3] > v[2]): #(1,3,2)
		(v[2] > v[1] and v[1] > v[3]): #(2,1,3)
		(v[2] > v[3] and v[3] > v[1]): #(2,3,1)
		(v[3] > v[1] and v[1] > v[2]): #(3,1,2)
		(v[3] > v[2] and v[2] > v[1]): #(3,2,1)
		default: #(1,2,3)
	)
)

fn check_z_up tm = ( -- tm: TransformMatrix
	-- Проверяет: смотрит ли Z вниз
	if tm.row3.z < 0 do (
		-- Переворачиваем Z и одновременно меняем порядок X и Y,
		-- чтобы сохранить правую систему и не нарушить смысл "X — первая компонента"
		-- Но проще: инвертируем Z и Y
        -- cross(x, -y) = -cross(x, y) = -z_old = z_new
		tm.row2 = -tm.row2
		tm.row3 = -tm.row3
	)
	tm
)

-- Основная функция
fn alignPivotToPCA obj search_min_area:true =
(
    if not ((isKindOf obj GeometryClass) or (isKindOf obj Shape)) do
    (
        messagebox "Объект не является геометрией!"
        return false
    )
	local tempObj
	local m = if isKindOf obj Shape then (
		-- Создаём временную копию
		tempObj = copy obj
		-- Конвертируем копию в Editable_Mesh для доступа к вершинам
		convertTo tempObj Editable_Mesh
		tempObj.mesh
	) else (
		obj.mesh
	)

	local verts = for v in m.verts collect (v.pos * (objOffsetTM obj) * obj.transform ) -- в глобальных координатах
	if isvalidnode tempObj do delete tempObj
	
    -- Центроид
    local centroid = [0,0,0]
    for p in verts do centroid += p
    centroid /= verts.count as float
	
    if verts.count < 3 do (
		if verts.count == 2 then (
			local first_vec = verts[2] - verts[1]
			if length first_vec == 0 do (
				messagebox "Вершины совпадают"
				return false
			)
			local sorted_axis = sort_axis first_vec
			local prim_idx = sorted_axis[1]
			local sec_idx = sorted_axis[2]
			local global_dirs = #([1,0,0], [0,1,0], [0,0,1])
			
			local prim_vec = normalize first_vec

			-- Проекция up на плоскость перпендикулярную prim_vec (ортогональная компонента)
			local sec_dir = global_dirs[sec_idx]
			local sec_proj = normalize (sec_dir - (dot sec_dir prim_vec) * prim_vec)
			
			local third_vec = cross prim_vec sec_proj
			
			local targetTM = matrix3 prim_vec sec_proj third_vec centroid
			targetTM = check_z_up targetTM
			
			placePivot obj targetTM
			return true
		) else (messagebox "Недостаточно вершин!"; return false)
	)

    -- Ковариационная матрица как 3x3 массив
    local cov33 = #(
        #(0,0,0),
        #(0,0,0),
        #(0,0,0)
    )
	
    for p in verts do
    (
        local dx = p.x - centroid.x
        local dy = p.y - centroid.y
        local dz = p.z - centroid.z

        cov33[1][1] += dx * dx
        cov33[1][2] += dx * dy
        cov33[1][3] += dx * dz

        cov33[2][1] += dy * dx
        cov33[2][2] += dy * dy
        cov33[2][3] += dy * dz

        cov33[3][1] += dz * dx
        cov33[3][2] += dz * dy
        cov33[3][3] += dz * dz
    )
	
    local n = verts.count as float
    for i = 1 to 3 do
        for j = 1 to 3 do
            cov33[i][j] /= n

    -- Получаем PCA-базис: X — первая, Y — вторая, Z — перпендикуляр
    local basis = getFirstTwoPC cov33
    local x = basis[1]
    local y = basis[2]
    local z = basis[3]

    -- Целевая ориентация (в мировых координатах)
	local targetTM = matrix3 x y z centroid
	-- Проверяем: смотрит ли Z вниз (в мировых координатах "вниз" = отрицательное Z)
	targetTM = check_z_up targetTM
	
	-- Теперь вычислим поворот по Z таким образом, чтобы 
	-- по XY был минимальный bounding box 
	-- 1. Проекция на плоскость XY (вашей PCA-системы)
	local uvPoints = projectToPlane verts centroid x y

	if search_min_area do (
		-- 2. Найти оптимальный угол поворота вокруг Z
		local optimalAngle = findOptimalAngle uvPoints

		-- 3. Повернуть X и Y вокруг Z на этот угол
		targetTM.pos = [0,0,0]
		local targetTM = rotate targetTM (AngleAxis optimalAngle targetTM.row3)
		targetTM.pos = centroid
	)
	
	-- перемещаем пивот
	placePivot obj targetTM

    true
)

on execute do (
	local undoText = if selection.count == 1 then "Align Pivot" else "Align Pivots"
	local workObjs = for obj in selection where (isKindOf obj GeometryClass) or (isKindOf obj Shape) collect obj
	if workObjs.count == 0 then messagebox "Нет подходящих объектов для применения" 
	else undo undoText on (
		for obj in workObjs do alignPivotToPCA obj search_min_area:keyboard.shiftPressed
	)
)

)