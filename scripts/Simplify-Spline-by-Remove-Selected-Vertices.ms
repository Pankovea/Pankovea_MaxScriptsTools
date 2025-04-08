/* @PankovEA scripts - 2025.04.01 alpha

Удаляет группу последовательных вершин в сплайне и стремится созранить форму.

Для работы необходим Matrix.ms в папке со скриптом.

Нужно выделить удаляемые вершины в сплайне (не в модификаторе) и запустить run_simplifySpline(). Пока общумываю в каком виде оформить макроскрипт.

Пока не обрабатывает крайние вершины. Первую и последнюю в замкнутом сплайне удалить не получится.
Так же есть проблемы, если вершины угловые. Они все должны иметь направляющие в данной реализации

--

Removes a group of consecutive vertices in a spline and strives to create a shape.

To work, you need Matrix.ms in the script folder. Matrix docs

You need to select the vertices to be deleted in the spline (not in the modifier) and run run_simplifySpline().
I'm still trying to figure out how to format the macro script.

It doesn't process the extreme vertices yet. You will not be able to delete the first and last in a closed spline.
There are also problems if the vertices are angular. They should all have guides in this implementation.
*/


fileIn "Matrix.ms" -- Добавить функционал для работы с матриами. Файл должен лежать в одной папке с данным скриптом

-- Вспомогательная функция сэмплирования с выводом координат сэмплов и их расстояния от начала участка.
fn sampleSpline spline s_num vertSelection totalSamples:100 = (
    local segDataCum = getSegLengths spline s_num cum:true
	local segData = getSegLengths spline s_num 
	local totalLength = segData[segData.count]
	/*
    format "segDataCum %\n" segDataCum
	format "segData %\n" segData
	format "vertSelection %\n" vertSelection
	format "totalLength %\n" totalLength
	*/
    if vertSelection.count < 2 then return #()

    -- Вычисляем длины сегментов и общую длину
	local selParamLen = 0.0
    local segLengths = for i = 1 to vertSelection.count - 1 do (
		selParamLen += segData[vertSelection[i]]
	)
	
	--format "selParamLen %\n" selParamLen
	
    -- Распределяем сэмплы пропорционально длинам сегментов
    local samples = #()
	local cumLen = 0.0
    for i = 1 to vertSelection.count - 1 do (
        local seg = vertSelection[i]
        local segParamLen = segData[seg]
        local numSegSamples = if i == vertSelection.count - 1 then (
            totalSamples - samples.count -- Оставшиеся сэмплы для последнего сегмента
        ) else (
            floor (segParamLen / selParamLen * totalSamples + 0.5) -- Пропорциональное количество сэмплов
        )
		--format "seg segParamLen numSegSamples: % % % \n" seg segParamLen numSegSamples
		-- Сэмплируем
        if numSegSamples > 0 then (
            local step = segParamLen / (numSegSamples - (if numSegSamples > 1 then 1 else 0)) -- Шаг внутри сегмента
            local startParam = if seg>1 then segDataCum[seg-1] else 0
            local endParam = segDataCum[seg]
            --format "step startParam endParam: % % % \n" step startParam endParam
			for paramAbs in startParam to endParam by step do (
				local currentLen = cumLen + (paramAbs - startParam) * totalLength
                local pos = interpCurve3D spline s_num paramAbs
                append samples #(pos, currentLen)
			)
        )
		cumLen += segParamLen * totalLength
    )
	format "samples.count: %\n" samples.count
    samples
)


-- Функция для проверки результата. Рассчитывает ошибку вычислений
fn checkSamples spline s_num segment samples =
(
    format "CheckSamples для сегмента %:\n" segment
    local errors = #()
    local totalError = 0.0
    local totalLength = samples[samples.count][2] -- Общая длина аппроксимируемого участка
    
    for i = 1 to samples.count do
    (
        local param = samples[i][2] / totalLength
        local samplePos = samples[i][1]
        local computedPos = interpCurve3D spline s_num param
        local error = distance samplePos computedPos
        append errors error
        totalError += error
		--format "%\. param %, samplePos %, computedPos %, error=%\n" i param samplePos computedPos error
    )
    
    local avgErrorPercent = (totalError / samples.count) / totalLength * 100.0
    local maxErrorPercent = (amax errors) / totalLength * 100.0
    local totalErrorPercent = totalError / totalLength * 100.0
    
    format "  Samples: %\n" samples.count
    format "  Length: %\n" totalLength
    format "  Avg error: % \%\n" avgErrorPercent
    format "  Max error: % \%\n" maxErrorPercent
    #(errors, totalError, totalErrorPercent, avgErrorPercent, maxErrorPercent)
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


-- функция для решения системы уравнений минимизирующих ошибку
fn fitBezierToSamples samples origOutVec:[0,0,0] origInVec:[0,0,0] =
(
    local numSamples = samples.count
    if numSamples < 2 then return #(samples[1][1], samples[numSamples][1])
    
    local P0 = samples[1][1]
    local P3 = samples[numSamples][1]
    local totalLength = samples[numSamples][2]
    --format "Total Length from samples: %\n" totalLength
    
    local useDirections = (origOutVec != [0,0,0] or origInVec != [0,0,0])
    --format "fitBezierToSamples: Using directions=%\n" useDirections
    
    local A = Matrix (numSamples * 3 + (if useDirections then 4 else 0)) 6 0.0
    local b = Matrix (numSamples * 3 + (if useDirections then 4 else 0)) 1 0.0
    
    -- Аппроксимация кривой
    for i = 1 to numSamples do
    (
        local t = samples[i][2] / totalLength
        local mt = 1 - t
        local mt2 = mt * mt
        local mt3 = mt2 * mt
        local t2 = t * t
        local t3 = t2 * t
        
        local coeffV0 = 3 * mt2 * t
        local coeffV1 = 3 * mt * t2
        local known = mt3 * P0 + t3 * P3
        local residual = samples[i][1] - known
        
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
    
    if useDirections then
    (
        local dirV0 = normalize(origOutVec)
        local dirV1 = normalize(origInVec)
        --format "dirV0=% dirV1=%\n" dirV0 dirV1
        
        local perpV0 = [dirV0.y, -dirV0.x, 0]
        local perpV1 = [dirV1.y, -dirV1.x, 0]
        local weight = 100.0 -- Веса для направлений
        
        -- Штрафуем отклонение от направлений
        local rowDir0 = numSamples * 3 + 1
        A.data[rowDir0][1] = perpV0.x * weight
        A.data[rowDir0][2] = perpV0.y * weight
        b.data[rowDir0][1] = (dot perpV0 P0) * weight
        
        local rowDir1 = numSamples * 3 + 2
        A.data[rowDir1][1] = perpV0.z * weight
        b.data[rowDir1][1] = (dot perpV0 P0) * weight
        
        local rowDir2 = numSamples * 3 + 3
        A.data[rowDir2][4] = perpV1.x * weight
        A.data[rowDir2][5] = perpV1.y * weight
        b.data[rowDir2][1] = (dot perpV1 P3) * weight
        
        local rowDir3 = numSamples * 3 + 4
        A.data[rowDir3][4] = perpV1.z * weight
        b.data[rowDir3][1] = (dot perpV1 P3) * weight
    )
    
    local AT_ = A.transpose()
    local AT_A = AT_.multiplyByMatrix A
    local AT_b = AT_.multiplyByVector b
    
    local invAT_A = AT_A.inverse()
    if invAT_A == undefined then return #(P0, P3)
    
    local solution = invAT_A.multiplyByVector AT_b
    if solution == undefined then return #(P0, P3)
    
    local P1 = [solution.data[1][1], solution.data[2][1], solution.data[3][1]]
    local P2 = [solution.data[4][1], solution.data[5][1], solution.data[6][1]]
    
    if useDirections then
    (
        -- Проекция на направления для неотрицательности
        local lenV0 = dot (P1 - P0) dirV0
        local lenV1 = dot (P2 - P3) dirV1
        if lenV0 < 0 then P1 = P0 + dirV0 * 0
        if lenV1 < 0 then P2 = P3 + dirV1 * 0
    )
    
    --format "fitBezierToSamples (%): P1=% P2=%\n" (if useDirections then "with directions" else "no directions") P1 P2
    return #(P1, P2)
)


-- Основная функция для удаления подряд идущих вершин (не крайних) с сохранением кривизны
fn simplifySpline spline s_num vert_selection samplesPerSegment:100 = -- useOriginalDirections:true
(
	local test = false 
	local start = vert_selection[1]
	local end = vert_selection[vert_selection.count]
	local nknots = numknots spline s_num
	
	local pre_start = if vert_selection[1] == 1 then nknots else (vert_selection[1] - 1)
	local after_end = if vert_selection[vert_selection.count] == nknots then 1 else (vert_selection[vert_selection.count] + 1)		

	local work_range = for i in vert_selection collect i -- code replace `copy vert_selection`, that returns `OK`
	insertitem pre_start work_range 1
	append work_range after_end
	format "work_range=% \n" work_range
	
    local samples = sampleSpline spline s_num work_range totalSamples:samplesPerSegment
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
	
	local origOutVec = getOutVec spline s_num pre_start - P0
	local origInVec = getInVec spline s_num after_end - P3
	--format "origOutVec=% origInVec=%\n" origOutVec origInVec

	local params = fitBezierToSamples samples origOutVec:origOutVec origInVec:origInVec

	local P1 = params[1]
	local P2 = params[2]
	
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
		
		local sortedVertSel = sort vert_selection
		for i = sortedVertSel.count to 1 by -1 do (
			deleteKnot spline s_num sortedVertSel[i]
		)
		
		updateShape spline
		CompleteRedraw()
		
		checkSamples spline s_num pre_start samples 
	) else (		
		-- вариант с созданием сплайна для тестов вместо удаления --
		local newSpline = splineShape()
		newSpline.steps = 12
		newSpline.name = "result_with_directions_" + useOriginalDirections as string
		addNewSpline newSpline
		addKnot newSpline 1 #bezier #curve P0 P0 P1
		addKnot newSpline 1 #bezier #curve P3 P2 P3
		updateShape newSpline
		
		--format "Final Control Points: P1=% P2=%\n" P1 P2
		checkSamples spline s_num 1 samples 
	)
)

-- вспомогательная функция для выделения групп выделенных вершин
fn getGroups knots isClosedSpline nknots = (
    if knots.count == 0 then return #()
    groups = #(); currentGroup = #(knots[1])
    for i = 2 to knots.count do (
        if knots[i] == knots[i-1] + 1 or (isClosedSpline and knots[i-1] == nknots and knots[i] == 1) then append currentGroup knots[i] 
        else (append groups currentGroup; currentGroup = #(knots[i]))
    )
    append groups currentGroup
    if isClosedSpline and (findItem knots 1 > 0 and findItem knots nknots > 0) then (
        endIdx = findItem knots nknots; group = #()
        for i = endIdx to knots.count do append group knots[i]
        for i = 1 to endIdx - 1 do append group knots[i]
        return #(group)
    )
    if not isClosedSpline then groups = for g in groups where (findItem g 1 == 0 and findItem g nknots == 0) collect g
    groups
)


-- функция обработки выделения в интерфейсе и передача данных в овновную функцию
fn run_simplifySpline = (
	local obj = selection[1]
	if selection.count == 1 \
		and modPanel.getCurrentObject() == obj.baseobject \
		and subObjectLevel == 1 \ 
		and finditem #(SplineShape, Line) (classof obj.baseobject) > 0 \
	then (
		local spline = obj
		undo on (
			for s_num = 1 to numSplines spline do (
				knots = getKnotSelection spline s_num
				nKnots = numKnots spline s_num
				isClosedSpline = isClosed spline s_num
				groups = getGroups knots isClosedSpline nKnots
				if groups.count == 0 and knots.count > 0 then format "Ошибка: Некорректная выборка в сплайне %\n" s_num
				-- запустить основную функцию для групп
				for vert_selection in groups do (
					--format "simplifySpline % % % %\n" spline s_num g[1] g[g.count]
					if (vert_selection[1] != 1 and vert_selection[vert_selection.count] != nknots) \
					or ((vert_selection[1] == 1 or vert_selection[vert_selection.count] == nknots) and isClosedSpline) then (
						simplifySpline spline s_num vert_selection -- useOriginalDirections:true
					)
				)
			)
		)
	)
	OK
)
