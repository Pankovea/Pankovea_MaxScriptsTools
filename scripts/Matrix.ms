/*
Matrix @ PankovEA scripts. 1.04.2025

Структура (класс) для операций с прямоугольными матрицами любого размера
Использовать осторожно. Не прошла всевозмоные тесты. Работает в частном порядке.

Пример использования:

-- задание числом
A = Matrix 5 5 1 -- единичая матрица 5х5
(Matrix rows:5 cols:5 data:#(#(1, 0, 0, 0, 0), #(0, 1, 0, 0, 0), #(0, 0, 1, 0, 0), #(0, 0, 0, 1, 0), #(0, 0, 0, 0, 1)))
A.print()
Matrix 5x5:
  [1 0 0 0 0 ]
  [0 1 0 0 0 ]
  [0 0 1 0 0 ]
  [0 0 0 1 0 ]
  [0 0 0 0 1 ]

-- Здание массивом данных
M = Matrix 3 3 #(1, 2, 3, 0, 1, 4, 5, 6, 0)
M.print()
(Matrix rows:3 cols:3 data:#(#(1, 2, 3), #(0, 1, 4), #(5, 6, 0)))
Matrix 3x3:
  [1 2 3 ]
  [0 1 4 ]
  [5 6 0 ]

-- Операции:
-- Функции каждый раз возвращают новый объект. старый не изменяется.

-- Транспонирование матрицы
(M.transpose()).print()
Matrix 3x3:
  [1 0 5 ]
  [2 1 6 ]
  [3 4 0 ]
OK

-- Умножение на вектор
V = #(1, 2, 3)
MV = V.multiplyByVector V
Matrix 3x1:
  [14.0 ]
  [14.0 ]
  [17.0 ]
OK

-- Умножение на матрицу
M2 = Matrix 3 2 #(1, 2, 3, 4, 5, 6)
MM2 = M.multiplyByMatrix M2
Matrix 3x2:
  [22.0 28.0 ]
  [23.0 28.0 ]
  [23.0 34.0 ]
OK

Minv = M.inverse()
Matrix 3x3:
  [-24.0 18.0 5.0 ]
  [20.0 -15.0 -4.0 ]
  [-5.0 4.0 1.0 ]
OK

Получать данные можно двумя способами:
M.getVal 1 2
2 -- вывод
M.data[1][2]
2 -- вывод

Записывать аналогично:
M.setVal 1 2 5
5
M.data[1][2] = 5
5
M.print()
Matrix 3x3:
  [1 5 3 ]
  [0 1 4 ]
  [5 6 0 ]

*/

-- Структура для матрицы
struct Matrix
(
    rows, cols, data, -- строки, столбцы, данные (двумерный массив)
	
	
	-- Инициализация матрицы заданного размера
	-- ожидается data массив значений или одно значение для заполнения матрицы
    on create do 
    (
		if classof data == Array and classof data[1] == array then return this -- если уже вложенный массив то предполагаем что его не нужно трасформировать
		
		if classof data == Integer or classof data == Float then (
			if rows == cols then (
				data = for i = 1 to rows collect (
					for j = 1 to cols collect 
						if i==j and data == 1 then 1 else 0 -- единичная диагональная матрица, если data == 1, иначе нулевая матрица
				)
			) else
				data = for i = 1 to rows collect (for j = 1 to cols collect data)
		) else if classof data == Array and data.count >= rows * cols and classof data[1] != array then (
			local k = 0
			data = for i = 1 to rows collect
				for j = 1 to cols collect
				(	k += 1
					data[k]
				)
		) else if data == undefined then
			data = for i = 1 to rows collect #() -- пустые массивы для заполнения
		
        this
    ),

	
    -- Установка значения в позицию (i,j)
    fn setVal i j val = 
    (
        if i > 0 and i <= rows and j > 0 and j <= cols then
            data[i][j] = val
    ),
    
	
    -- Получение значения из позиции (i,j)
    fn getVal i j = 
    (
        if i > 0 and i <= rows and j > 0 and j <= cols then
            data[i][j]
        else undefined
    ),
    
	
	fn count = (
		return rows * cols
	),


    -- Вывод матрицы для отладки
    fn print = 
    (
        format "Matrix %x%:\n" rows cols
        for i = 1 to rows do
        (
            format "  ["
            for j = 1 to cols do
                format "% " data[i][j]
            format "]\n"
        )
    ),

	
	-- Умножение матрицы на вектор
	fn multiplyByVector vec =
	(	local result = undefined

		if classof vec == Array then vec = Matrix vec.count 1 vec

		if classof (getProperty vec "count") == MAXScriptFunction and vec.cols == 1 then (

			if cols != vec.count() then
			(
				format "multiplyByVector: Dimension mismatch (% cols vs % vector length)\n" cols vec.count()
				return undefined
			)
			
			result = Matrix rows 1 (
				for i = 1 to rows collect (
					local sum = 0.0
					for j = 1 to cols do
						sum += data[i][j] * vec.data[j][1]
					sum
				)
			)
		)
		result
	),

	
	-- Умножение матрицы на матрицу
	fn multiplyByMatrix matrixB =
	(
		if cols != matrixB.rows then
		(
			format "multiplyByMatrix: Dimension mismatch (% cols vs % rows)\n" cols matrixB.rows
			return undefined
		)
		local result = Matrix rows matrixB.cols
		Matrix rows matrixB.cols (
			for i = 1 to rows collect
				for j = 1 to matrixB.cols collect
				(
					local sum = 0.0
					for k = 1 to cols do
						sum += data[i][k] * matrixB.data[k][j]
					sum
				)
		)
	),
	
	
	-- Транспонирование матрицы
	fn transposeSelf = (
		data = for j = 1 to cols collect
				for i = 1 to rows collect data[i][j]
		this
	),
	
	fn transpose = (
		Matrix cols rows (
			for j = 1 to cols collect
				for i = 1 to rows collect data[i][j]
		)
	),
	

	-- Обратная матрица (метод Гаусса-Жордана для квадратных матриц)
	fn inverse =
	(
		if rows != cols then
		(
			format "inverseMatrix: Matrix must be square (%x%)\n" rows cols
			return undefined
		)
		
		if rows == 1 and cals == 1 then return 1/data[1][1]
		
		local n = rows
		local aug = Matrix n (2*n) 0.0 -- Augmented matrix Расширенная матрица [A|I]
		
		-- Заполняем расширенную матрицу
		for i = 1 to n do
		(
			for j = 1 to n do (
				aug.data[i][j] = data[i][j]
				aug.data[i][n+j] = (if i == j then 1.0 else 0.0)
			)
		)
		
		-- Полный метод Гаусса-Жордана
		for i = 1 to n do
		(
			-- Нормализуем строку i
			local piv = aug.data[i][i]
			if abs(piv) < 1e-6 then
			(
				format "inverseMatrix: Matrix is singular (piv=% at %,%)\n" piv i i
				return undefined
			)
			for j = 1 to 2*n do
				aug.data[i][j] = aug.data[i][j] / piv
			
			-- Обнуляем столбец i для всех строк k != i
			for k = 1 to n do
			(
				if k != i then
				(
					local factor = aug.data[k][i]
					for j = 1 to 2*n do -- Обновляем всю строку, включая правую часть
						aug.data[k][j] -= factor * aug.data[i][j]
				)
			)
		)
		
		-- Извлекаем обратную матрицу
		local inv = Matrix n n 0.0
		for i = 1 to n do
			for j = 1 to n do
				inv.data[i][j] = aug.data[i][j+n]
		
		inv
	)
)

/*
-- Пример использования
fn testMatrixOperations =
(
    -- Тестовая матрица 3x3
    local m = Matrix 3 3 #(1, 2, 3, 0, 1, 4, 5, 6, 0)
    m.print()
    
    -- Умножение на вектор
    local v = #(1, 2, 3)
    local mv = m.multiplyByVector v
    format "Matrix * Vector = %\n" mv
    
    -- Умножение на матрицу
    local m2 = Matrix 3 2 #(1, 2, 3, 4, 5, 6)
    local mm = m.multiplyByMatrix m2
    if mm != undefined then
    (
        format "Matrix * Matrix:\n"
        mm.print()
    )
    
    -- Обратная матрица
    local invM = m.inverse()
    if invM != undefined then
    (
        format "Inverse Matrix:\n"
        invM.print()
        
        -- Проверка: A * A^-1 = I
        local identity = m.multiplyByMatrix invM
        format "A * A^-1 (должна получиться единичная):\n"
        identity.print()
    )
)

-- Запуск теста
testMatrixOperations()
*/