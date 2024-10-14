/* @Pankovea Scripts - 2024.07.10
Скрипт для рапределения в пространстве

Особенности:
* Работает в режиме Объектов и в режиме подобъектов. 
(пока реализованj только выравнивание вершин в EditableSpline
Технически это озможно делать только на базовом объекте стека модификаторов - 
на более высоком уровне в стеке - EditSpline не работает)

* объекты распределяет равномерно по пивотам
* Автоматически определяет первый и последний объекты
* Распределяет группированные объекты

* для запуска необходимо находиться в нужном режиме выделения.
*/

macroScript Distibute_objects
category:"#PankovScripts"
toolTip:"Distibute objects"
icon:#("AutoGrid",2)
buttontext:"Distr" 	
(

struct Vertex (numSp, numVert, pos)

-------------------------------------
-- Find maximum dimension and sort dimension order from max to min
-------------------------------------

-- Get minimum and maximum values from array
fn getMinMaxVal arr = ( -- in: array of float
	local minVal = arr[1]
	local maxVal = arr[1]
	for i in 1 to arr.count-1 do (
		if arr[i] > arr[i+1] then minVal = arr[i+1]
		if arr[i] < arr[i+1] then maxVal = arr[i+1]
	)
	local subrtaction = maxVal - minVal
	return #(minVal, maxVal, subrtaction)
)

-- Get maximum value index in array
fn getMaxValueIndex arr = ( -- in: array of float
	local k=1
	case of (
		(arr.count==0): k=0
		(arr.count==1): k=1
		(arr.count>1): (	k=1
							max_val = arr[k]
							for n=1 to arr.count-1 do if arr[n]>max_val then (
								k=n+1
								max_val = arr[k]
							)
						)
	)
	return k
)

-- Find longest dimension of selection. 1 = x, 2 = y, 3 = z
fn getDimOrder arr = ( -- in: array of Vertex struct; out: array indexes of dimensions
	local dim = #()
	local dimOrder = #()
	xArr = (getMinMaxVal (for vert in arr collect vert.pos[1]))[3]
	yArr = (getMinMaxVal (for vert in arr collect vert.pos[2]))[3]
	zArr = (getMinMaxVal (for vert in arr collect vert.pos[3]))[3]
	dim = #(xArr, yArr, zArr)
	-- Find order sortion by dimensions (XYZ)
	for n=1 to 3 do (
		dimOrder[n] = getMaxValueIndex dim
		dim[dimOrder[n]] = -10^9 -- fill big negativ number for find next maximum
	)
	return dimOrder
)

-------------------------------------
-- Sort functions
-------------------------------------

-- sort order 1
fn sortPoints_st1 arr dimNum = ( -- In: array of Vertex struct, dimNum: integer; out = array of Vertex struct
	for i=1 to arr.count-1 do (
    for j=1 to arr.count-i do (
        if arr[j].pos[dimNum] > arr[j+1].pos[dimNum] then (
            local k = arr[j]
            arr[j] = arr[j+1]
			arr[j+1] = k
	)))
return arr)

-- sort order 2
fn sortPoints_st2 arr dimNum1 dimNum2 = ( -- In: array of Vertex struct; dimNum1, dimNum2: integer; out = array of Vertex struct
	for i=1 to arr.count-1 do (
    for j=1 to arr.count-i do (
		if (arr[j].pos[dimNum1] == arr[j+1].pos[dimNum1]) AND (arr[j].pos[dimNum2] > arr[j+1].pos[dimNum2]) then
		(
            local k = arr[j]
            arr[j] = arr[j+1]
			arr[j+1] = k
		)
	))
	return arr
)


fn getSelectedKnotsPos obj = ( -- Out array of Vertex struct
	local VertexArray = #()

	if classof obj.baseobject == SplineShape then (
		for sp in 1 to numSplines obj do
			for vert in getKnotSelection obj sp do
				append VertexArray (Vertex numSp:sp numVert:vert pos: (getKnotPoint obj sp vert))
		return VertexArray
	) else return #()

)


fn calcNewPositions arr = ( -- In and Out: array of Vertex struct
	local dimOrder = getDimOrder arr
	
	local newArr = sortPoints_st1 arr dimOrder[1]
	newArr = sortPoints_st2 newArr dimOrder[1] dimOrder[2]

	local step_X = (arr[arr.count].pos[1] - arr[1].pos[1]) / (arr.count - 1)
	local step_Y = (arr[arr.count].pos[2] - arr[1].pos[2]) / (arr.count - 1)
	local step_Z = (arr[arr.count].pos[3] - arr[1].pos[3]) / (arr.count - 1)
	
	for n = 1 to arr.count do newArr[n].pos = Point3 (newArr[1].pos.x+step_X*(n-1)) (newArr[1].pos.y+step_Y*(n-1)) (newArr[1].pos.z+step_Z*(n-1))
	
	return newArr
)

on execute do (
	if selection.count == 1 and classof selection[1].baseobject == SplineShape and subobjectLevel != 0 then (
		case subobjectLevel of (
			-- Vertex
			1: (
				vertArray = getSelectedKnotsPos selection[1]
				undo on (
					for vert in calcNewPositions vertArray do
						setKnotPoint selection[1] vert.numSp vert.numVert vert.pos
				)
				updateShape selection[1]
			)
			-- Segments
			2: (
				print "Segments on EditSpline Not implemented yet"
			)
			-- Splines
			3: (
				print "Splines on EditSpline Not implemented yet"
			)
		)
	)
	
	if selection.count == 1 and classof selection[1].baseobject == Editable_Poly and subobjectLevel != 0 then (
		case subobjectLevel of (
			-- Vertex
			1: (
				print "Vertex on EditPoly Not implemented yet"
			)
			-- Edge
			2: (
				print "Edges on EditPoly Not implemented yet"
			)
			-- Faces
			4: (
				print "Faces on EditPoly Not implemented yet"
			)
			-- Objects
			5: (
				print "Objects on EditPoly Not implemented yet"
			)
		)
	)
	
	if selection.count > 1 then (
		local sel = #()
		sel = selection as array
		for n in selection do (
			if n.children.count > 0 then (
				for i in n.children do (
					deleteItem sel (findItem sel i)
				)
			)
		)
		undo on (
			calcNewPositions sel
		)
	)
)

) -- End of macroscript