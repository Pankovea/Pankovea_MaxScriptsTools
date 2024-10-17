/* @Pankovea Scripts - 2024.10.15
Distribute: Скрипт для рапределения в пространстве

Особенности:
* Работает в режиме Объектов и в режиме подобъектов. 
(пока реализовано только выравнивание вершин в EditableSpline, EditaplePoly, и модификатор EditPoly
модификатор EditSpline не работает)

* объекты распределяет равномерно по пивотам
* Автоматически определяет первый и последний объекты
* Распределяет группированные объекты

* для запуска необходимо находиться в нужном режиме выделения.
--------
Distribute: A script for distribution in space

Features:
* Works in Object mode and in subobject mode. 
(so far, only vertex alignment has been implemented in EditableSpline, EditaplePoly, and the EditPoly modifier the EditSpline
modifier does not work)

* distributes objects evenly across pivots
* Automatically detects the first and last objects
* Distributes grouped objects

* To start, you must be in the desired selection mode.
*/

macroScript Distibute_objects
category:"#PankovScripts"
toolTip:"Distibute objects"
icon:#("AutoGrid",2)
buttontext:"Distr" 	
(

struct Vertex (obj, numSp, numVert, pos)

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
	local subtraction
	if minVal != undefined then subtraction = maxVal - minVal
	return #(minVal, maxVal, subtraction)
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


fn calcNewPositions arr = ( -- In and Out: array of Vertex struct
	if arr.count > 0 then ( 
		local dimOrder = getDimOrder arr
		
		local newArr = sortPoints_st1 arr dimOrder[1]
		newArr = sortPoints_st2 newArr dimOrder[1] dimOrder[2]

		local step_X = (arr[arr.count].pos[1] - arr[1].pos[1]) / (arr.count - 1)
		local step_Y = (arr[arr.count].pos[2] - arr[1].pos[2]) / (arr.count - 1)
		local step_Z = (arr[arr.count].pos[3] - arr[1].pos[3]) / (arr.count - 1)
		
		for n = 1 to arr.count do newArr[n].pos = Point3 (newArr[1].pos.x+step_X*(n-1)) (newArr[1].pos.y+step_Y*(n-1)) (newArr[1].pos.z+step_Z*(n-1))
		
		return newArr
	) else ( 
		return arr
	)
)

on isEnabled return (
	try ( 
		-- list of conditions. Copy from the case statement on execute event handler
				-------------------- Editable Spline -----------------------
			(selection.count == 1 \
			and (finditem #(line, SplineShape) (classof selection[1])) != 0 \
			and modPanel.getCurrentObject() == selection[1].baseobject \
			and subobjectLevel != 0) \
		or	\	-------------------- Editable Poly -----------------------
			(selection.count == 1 \
			and classof selection[1].baseobject == Editable_Poly \
			and subobjectLevel != 0 \
			and modpanel.getCurrentObject() == selection[1].baseobject) \
		or 	\	----- Instanced modifier in multiple nodes -----
			(selection.count > 0 \
			and subObjectLevel > 0 \
			and modpanel.getCurrentObject() != selection[1].baseobject) \
		or 	\	--------------------- Objects -----------------------
			(selection.count > 1 \
			and subobjectLevel == 0)
	) catch false
)

on execute do (
	local vertexArray
	
	case of (
		-------------------- Editable Spline -----------------------
		(selection.count == 1 \
		and (finditem #(line, SplineShape) (classof selection[1])) != 0 \
		and modPanel.getCurrentObject() == selection[1].baseobject \
		and subobjectLevel != 0): (
			case subobjectLevel of (
				-- Vertex
				1: (vertexArray = array()
					for sp in 1 to numSplines selection[1] do
						for vert in getKnotSelection selection[1] sp do
							append vertexArray (Vertex numSp:sp numVert:vert pos: (getKnotPoint selection[1] sp vert))
					if vertexArray.count > 0 then (
						undo on (
							for vert in calcNewPositions vertexArray do
								setKnotPoint selection[1] vert.numSp vert.numVert vert.pos
						)
						updateShape selection[1]
					) else (
						print "No Vertex selection to distribute"
					)
				)
				-- Segments
				2: (
					print "Segments on EditSpline not implemented yet"
				)
				-- Splines
				3: (
					print "Splines on EditSpline not implemented yet"
				)
			)
		)
		
		-------------------- Editable Poly -----------------------
		(selection.count == 1 \
		and classof selection[1].baseobject == Editable_Poly \
		and subobjectLevel != 0 \
		and modpanel.getCurrentObject() == selection[1].baseobject): (
			if not (polyop.getVertSelection selection[1]).isEmpty then (
				case subobjectLevel of (
					-- Vertex
					1: (
						obj = selection[1]
						vertList = polyop.getVertSelection obj
						vertexArray = for numVert in vertList collect Vertex numVert:numVert pos:(polyop.getVert obj numVert)
						for vert in calcNewPositions vertexArray do (
							polyop.setVert obj vert.numVert vert.pos
						)
					)
					-- Edge
					2: (
						print "Edges on EditablePoly not implemented yet"
					)
					-- Faces
					4: (
						print "Faces on EditablePoly not implemented yet"
					)
					-- Objects
					5: (
						print "Objects on EditablePoly not implemented yet"
					)
				)
			) else (
				print "No Vertex selection to distribute"
			)
		)
		
		----- Instanced modifier in multiple nodes -----
		(selection.count > 0 \
		and subObjectLevel > 0 \
		and modpanel.getCurrentObject() != selection[1].baseobject): (
			local sel = selection as array
			local modif = modpanel.getCurrentObject()
			local nodes = for o in selection where (finditem o.modifiers modif)!=0 collect o
			vertexArray = array()
			case classof modif of (
				Edit_Spline: (
					print "Have not access to Edit Spline modifier selection. Please, do select on the base object"
					/* -- Code to test this issue
					case subobjectLevel of (
						-- Vertex
						1: (for obj in nodes do (
								for spl = 1 to (numsplines obj) do (
									for vert in (getKnotSelection obj spl) do (
										append vertexArray (Vertex obj:obj numSp:spl numVert:vert pos:(getKnotPoint obj spl vert))
									)
								)				
							)
							print vertexArray
							undo on (
								for vert in calcNewPositions vertexArray do
									setKnotPoint vert.obj vert.numSp vert.numVert vert.pos
							)
							updateShape selection[1]
						)
					)
					*/
				)

				Edit_Poly: (undo on (
					-- if objects in group then open it and remeber to close
					groups = for obj in selection where isgrouphead obj collect obj
					for obj in groups do setGroupOpen obj true
						
					case subobjectLevel of (
						-- Vertex
						1: (
							local oldVertSel = array() -- remember old vertex selection
							local curVertSel
							-- get vertex positions
							for obj in nodes do (
								select obj
								curVertSel = modif.EditPolyMod.GetSelection #Vertex
								append oldVertSel #(obj, curVertSel)
								for vert in curVertSel do (
									append vertexArray (Vertex obj:obj numVert:vert pos:(modif.GetVertex vert))
								)
							)
							if vertexArray.count > 0 then (
								-- set new vertex pos
								for vert in calcNewPositions vertexArray do (
									if selection[1] != vert.obj then select vert.obj
									modif.SetSelection #Vertex #{vert.numVert}
									modif.Select #Vertex #{vert.numVert}
									modif.MoveSelection (vert.pos - (modif.GetVertex vert.numVert))
									modif.Commit()
									)
								-- select old vertex selection
								for sel in oldVertSel do (
								select sel[1]
								modif.SetSelection #Vertex sel[2]
								)
								-- #FIXME if select again, objects are diapearing. Testing in MAX 2023. It must be deselect and select manualy for work well
								deselect $*
								completeredraw()
							) else (
								print "No Vertex selection to distribute"
							)
						)
						-- Edge
						2: (
							print "Edges on EditPoly not implemented yet"
						)
						-- Faces
						4: (
							print "Faces on EditPoly not implemented yet"
						)
						-- Objects
						5: (
							print "Objects on EditPoly not implemented yet"
						)
					)
					-- close groups
					for obj in groups do setGroupOpen obj false
					-- #FIXME if select then objects are diapearing from the viewport. Testing in MAX 2023
					--select groups
				))
			)
		)
			
		--------------------- Objects -----------------------
		(selection.count > 1 \
		and subobjectLevel == 0): (
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
		
		else: print "Can not do it."
	)
)

) -- End of macroscript