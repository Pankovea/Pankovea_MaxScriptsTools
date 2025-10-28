/* @Pankovea Scripts - 2025.09.30
Выравнивает локальные оси вдоль длинной и короткой части геометрии объекта.

Этот скрипт анализирует геометрию выбранного объекта, вычисляет ковариационную матрицу его вершин
и находит главные компоненты (Principal Component Analysis - PCA) для определения естественной ориентации формы.
Первая и вторая главные оси задают плоскость, в которой методом поиска по углам находится ориентация
с минимальной площадью охватывающего прямоугольника. Ось Z автоматически корректируется,
чтобы всегда быть направленной вверх (в сторону +Z мировой системы координат).
Затем пивот объекта перемещается в центроид и поворачивается в соответствии с найденной системой координат,
при этом геометрия остаётся неподвижной в сцене.
Скрипт корректно работает даже при изначально смещённом пивоте благодаря точному пересчёту objectOffset-параметров. 

----------------------------------------------------
Aligns the local axes along the long and short dimensions of the object's geometry.

This script analyzes the geometry of the selected object, computes the covariance matrix of its vertices,
and extracts the principal components (Principal Component Analysis - PCA) to determine the natural orientation
of the shape. The first and second principal axes define the plane in which an angular search is performed
to find the orientation with the minimal-area bounding rectangle. The Z axis is automatically adjusted
so that it always points upward (toward +Z in world coordinates).
The object's pivot is then moved to the centroid and rotated to match the found coordinate system,
while the geometry itself remains stationary in the scene.
The script also handles initially offset pivots correctly by precisely recalculating the objectOffset parameters.

*/

macroScript Pankov_AlignPivotPCA
category:"#PankovScripts"
buttontext:"ResetPivotOffset"
tooltip:"Align pivot to object's natural orientation PCA"
(
	
on isenabled return (
	selection.count == 1 and ((isKindOf selection[1] GeometryClass) or (isKindOf selection[1] Shape))
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
	-- Первая компонента
    local x = safeNormalize [1,1,0.1]
    for i = 1 to 10 do
    (
        x = safeNormalize (mat33MulVec cov33 x)
    )

    -- Вторая компонента
    local y = safeNormalize [1,0,0]
    if abs(dot y x) > 0.9 then y = [0,1,0]
    if abs(dot y x) > 0.9 then y = [0,0,1]

    y = y - (dot y x) * x
    y = safeNormalize y

    for i = 1 to 10 do
    (
        local v = mat33MulVec cov33 y
        v = v - (dot v x) * x
        y = safeNormalize v
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
    local step = 5 as float -- градусы
    for deg = 0 to 89.9 by step do
    (
        local ang = deg --* (pi / 180.0)
        local res = getBoundingBoxSize uvPoints ang
        if res[3] < minArea do
        (
            minArea = res[3]
            bestAngle = ang
        )
    )

    -- Уточнение вокруг bestAngle
    local refineStep = 1.0
    for i = 1 to 3 do
    (
        local newMin = 1e18
        local newBest = bestAngle
        for offset = -refineStep to refineStep by (refineStep / 10.0) do
        (
            local ang = bestAngle + offset --* (pi / 180.0)
            local res = getBoundingBoxSize uvPoints ang
            if res[3] < newMin do
            (
                newMin = res[3]
                newBest = ang
            )
        )
        bestAngle = newBest
        refineStep /= 10.0
    )

    bestAngle
)


-- Основная функция
fn alignPivotToPCA obj =
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

	local verts = for v in m.verts collect (v.pos + obj.pos + obj.objectOffsetPos)
	if isvalidnode tempObj do delete tempObj
	
    if verts.count < 3 do ( messagebox "Недостаточно вершин!"; return false )

    -- Центроид
    local centroid = [0,0,0]
    for p in verts do centroid += p
    centroid /= verts.count as float

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

	-- Проверяем: смотрит ли Z вниз (в мировых координатах "вниз" = отрицательное Z)
	if z.z < 0 do
	(
		-- Переворачиваем Z и одновременно меняем порядок X и Y,
		-- чтобы сохранить правую систему и не нарушить смысл "X — первая компонента"
		-- Но проще: инвертируем Z и Y
        -- cross(x, -y) = -cross(x, y) = -z_old = z_new
		y = -y
		z = -z
	)

    -- Целевая ориентация (в мировых координатах)
	local targetTM = matrix3 x y z centroid
		
	-- Теперь вычислим поворот по Z таким образом, чтобы 
	-- по XY был минимальный bounding box 
	-- 1. Проекция на плоскость XY (вашей PCA-системы)
	local uvPoints = projectToPlane verts centroid x y

	-- 2. Найти оптимальный угол поворота вокруг Z
	local optimalAngle = findOptimalAngle uvPoints

	-- 3. Повернуть X и Y вокруг Z на этот угол
	--local targetTM_minBBox = rotate targetTM (AngleAxis optimalAngle targetTM.row3)
	
	local cosA = cos optimalAngle
	local sinA = sin optimalAngle

	local newX = x * cosA + y * sinA
	local newY = -x * sinA + y * cosA
	local newZ = z -- не меняется
	
	format "X: %\nY: %\nZ: %\n" x y z
	
	targetTM_minBBox = matrix3 newX newY newZ centroid

	local localTargetTMOfset = obj.transform * inverse(targetTM_minBBox)
	
	local oldObjOffsetTM = (
		(ScaleMatrix obj.objectOffsetScale) * \
		(obj.objectOffsetRot as Matrix3) * \
		(TransMatrix obj.objectOffsetPos)
	)
	
	local newOffsetTM = oldObjOffsetTM * localTargetTMOfset
	
	-- перемещаем пивот
    undo "Place Pivot" on (
		
		obj.objectOffsetScale = newOffsetTM.Scale
		obj.objectOffsetRot = newOffsetTM.rotation
		obj.objectOffsetPos = newOffsetTM.position
		
		-- после перемещения, нужно компенсировать положение 
		obj.transform = targetTM_minBBox
	)
    true
)

on execute do (
	alignPivotToPCA selection[1]
)

)