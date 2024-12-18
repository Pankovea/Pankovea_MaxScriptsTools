/* @Pankovea Scripts - 2024.11.28
Distribute: Скрипт для рапределения в пространстве

Особенности:
* Работает в режиме Объектов и в режиме подобъектов. 
(пока реализовано только выравнивание вершин в EditableSpline,
всех подобъектов EditablePoly, и модификатора EditPoly
модификатор EditSpline не работает)

* объекты распределяет равномерно учитывая размер объекта таким боразом, чтобы расстояние между ними было одинаковым
(нужно доработать смещение пивота от центра и точность определения размера. Сейчас размер определяется по Bounding box)
* Автоматически определяет первый и последний объекты по наибольшему расстоянию между ними.
* работает если модификатор наложен инстансом на месколько объектов (#FIXME пока отрабатывает не корректно в max2025)
* Распределяет группированные объекты

* для запуска необходимо находиться в нужном режиме выделения.
--------
Distribute: A script for distribution in space

Features:
* Works in Object mode and in subobject mode. 
(so far, only vertex alignment has been implemented in EditableSpline,
all EditablePoly subobjects, and the EditPoly modifier the EditSpline
modifier does not work)

* distributes objects evenly, taking into account the size of the object in such a way that the distance between them is the same
(you need to refine the pivot offset from the center and the accuracy of sizing. Now the size is determined by the Bounding box)
* Automatically detects the first and last objects by the largest distance between them.
* works if the modifier is imposed by the instance on several objects (#FIXME is not working correctly in max2025 yet)
* * Distributes grouped objects

* To start, you must be in the desired selection mode.
*/

macroScript Distibute_objects
category:"#PankovScripts"
toolTip:"Distibute objects"
icon:#("AutoGrid",2)
buttontext:"Distr" 	
(

struct Vertex (obj, numSp, numVert, pos, size=0, subs_pos, pivot_offset=[0,0,0], dist=0)

-- Функция для нахождения индексов двух наиболее удалённых точек. Между ними будем распределять точки / A function for finding the indices of the two most distant points. We will distribute the points between them
fn findFurthestPoints arrOfVerts = ( -- in: array of Vertex struct; out: it's array indexes
    local maxDistance = 0
    local furthestPoints
    local dist
    for i = 1 to arrOfVerts.count-1 do (
        for j = i+1 to arrOfVerts.count do (
            dist = length (arrOfVerts[i].pos - arrOfVerts[j].pos)
            if dist > maxDistance then (
                maxDistance = dist
                furthestPoints = #(i, j)
            )
        )
    )
    return furthestPoints
)


-- Функция проецирует точки на линию между двумя точками. не создаётся новый массив, а меняется старый / The function projects points onto a line between two points. a new array is not created, but the old one is changed
fn projectVertexToVector arrOfVerts p1 p2 = ( -- in: Vertex struct, point_start index, point_end index; out: array of Vertex struct
	local p1_pos = arrOfVerts[p1].pos
	local p2_pos = arrOfVerts[p2].pos
	local vec = p2_pos - p1_pos
	local t
	for vert in arrOfVerts do (
		t = (dot (vert.pos - p1_pos) vec) / (length vec)^2
		vert.pos = p1_pos + t * vec
	)
	return arrOfVerts
)


-- Sort function
fn sortPoints arrOfVerts = ( -- In: array of Vertex struct; out = sorted array of Vertex struct
	local dist
	local tmp
	local FurthestVertsInd = findFurthestPoints arrOfVerts
	-- Распределяем все точки вдоль вектора / We distribute all points along the vector
	distributedVerts = projectVertexToVector arrOfVerts FurthestVertsInd[1] FurthestVertsInd[2]
	startVert = distributedVerts[FurthestVertsInd[1]]
	
	-- Calc distances
	for vert in distributedVerts do vert.dist = length (startVert.pos - vert.pos)
	-- sort array
	for i=1 to distributedVerts.count-1 do (
		for j=1 to distributedVerts.count-i do (
			if distributedVerts[j].dist > distributedVerts[j+1].dist then (
				-- swap items
				tmp = distributedVerts[j]
				distributedVerts[j] = distributedVerts[j+1]
				distributedVerts[j+1] = tmp
			)
		)
	)
	return distributedVerts
)

-- Calc sizes function
fn calcSizes arrOfVerts = ( -- In and Out: array of Vertex struct
	local vec = normalize (arrOfVerts[arrOfVerts.count].pos - arrOfVerts[1].pos)
	local old_rotation
	if arrOfVerts[1].numVert == undefined then (
		for vert in arrOfVerts do (
			obj = vert.obj
			-- Поворачиваем объект, совмещая вектор распределения объектов с осью х / Rotate the object by combining the object distribution vector with the x-axis
			old_rotation = obj.rotation
			targetAxis = [1, 0, 0]
			ang = acos(dot vec targetAxis)
			rotationAxis = normalize (cross vec targetAxis)
			rotate obj (angleAxis ang rotationAxis)
			-- определяем размер по оси x и возвращаем поворот / we determine the size on the x axis and return the rotation
			vert.size = (obj.max - obj.min).x
			obj.rotation = old_rotation
		)
	)
	if arrOfVerts[1].subs_pos != undefined then (
		local _min, _max
		local i_min, i_max
		for vert in arrOfVerts do (
			projectedVals = for sub in vert.subs_pos collect dot sub vec
			_min = 1e9; _max = -1e9
			for val in projectedVals do (
				if val < _min do _min = val
				if val > _max do _max = val
			)
			vert.size = _max - _min
		)
	)
	return arrOfVerts
)

-------------------------------------
-- Calc new positions
-------------------------------------

fn calcNewPositions arrOfVerts = ( -- In and Out: array of Vertex struct
	if arrOfVerts.count > 2 then (
		local newArr = sortPoints arrOfVerts
		StartVert = newArr[1]
		EndVert = newArr[newArr.count]
		
		calcSizes newArr
		
		sum_radiuses = StartVert.size/2
		for i in 2 to newArr.count-1 do sum_radiuses += newArr[i].size
		sum_radiuses += EndVert.size / 2
		---
		path_vec = EndVert.pos - StartVert.pos
		path_length = length path_vec
		path_vec_nrm = normalize path_vec
		---
		step = (path_length - sum_radiuses) / (newArr.count - 1)
					
		for i=2 to newArr.count-1 do newArr[i].pos = newArr[i-1].pos + path_vec_nrm*newArr[i-1].size/2 + path_vec_nrm*step + path_vec_nrm*newArr[i].size/2

		return newArr
	) else ( 
		return arr
	)
)

-------------------------------------
-- Группировка полигонов
-------------------------------------

-- возвращает прилегающие полигоны к заданному
fn getAdjacent obj index type =
(
    local adj = #()
    local verts
	case type of (
		#Face: verts = polyOp.getFaceVerts obj index
		#Edge: verts = polyOp.getEdgeVerts obj index
    )
    for v in verts do (
        local connected
		case type of (
			#Face: connected = polyOp.getFacesUsingVert obj v
			#Edge: connected = polyOp.getEdgesUsingVert obj v
		)
        for el in connected do (
            if el != index and findItem adj el == 0 then (
                append adj el
            )
        )
    )
    return adj
)

-- группирует прилегающие полигоны. Рабтает как с Editable Poly, так и с Edit Poly
fn groupAdjacent obj selected type = ( -- in: obj,  selected: bitarray; out: array of bitarrays (groups of Face numbers)
    local grouped = #()
    local visited = #{}
    
    for index in selected do (
        if not visited[index] then (
            local _group = #{}
            local queue = #(index)
            
            while queue.count > 0 do (
                local current = queue[1]
                deleteItem queue 1
                
                if not visited[current] then (
                    _group[current] = true
                    visited[current] = true
                    
                    local adj = getAdjacent obj current type
                    for el in adj do (
                        if selected[el] and not visited[el] then (
                            append queue el
                        )
                    )
                )
            )
            append grouped _group
        )
    )
    return grouped
)


-------------------------------------
-- Macroscript
-------------------------------------

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
			and (subobjectLevel == 0 or subobjectLevel == undefined))
	) catch false
)

on execute do (
	local vertexArray = #()
	
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
					if vertexArray.count > 2 then (
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
				case of (
					-- Vertex
					(subobjectLevel == 1): (
						obj = selection[1]
						vertList = polyop.getVertSelection obj
						vertexArray = for numVert in vertList collect Vertex numVert:numVert pos:(polyop.getVert obj numVert)
						if vertexArray.count > 2 then undo on (
							for vert in calcNewPositions vertexArray do (
								polyop.setVert obj vert.numVert vert.pos
							)
						)
					)
					-- Edge
					(subobjectLevel == 2 or subobjectLevel == 3): (
						local groupCenters = array()
						obj = selection[1]
						edgeList = polyop.getEdgeSelection obj
						local groupedFaces = groupAdjacent obj edgeList #Edge
						for gr_number in 1 to groupedFaces.count do (
							curVertSel = #{}
							for edge in groupedFaces[gr_number] do curVertSel += ((polyOp.getEdgeVerts obj edge) as bitArray)
							vert = Vertex obj:obj numVert:gr_number subs_pos:(polyop.getVerts obj curVertSel)
							bbox = box3()
							expandToInclude bbox vert.subs_pos
							vert.pos = bbox.center
							append groupCenters vert.pos
							append vertexArray vert
						)
						-- move vertices
						if vertexArray.count > 2 then undo on (
							for vert in calcNewPositions vertexArray do (
								curVertSel = #{}
								for edge in groupedFaces[vert.numVert] do curVertSel += ((polyOp.getEdgeVerts obj edge) as bitArray)
								polyop.moveVert obj curVertSel (vert.pos - groupCenters[vert.numVert])
							)
						)
					)
					-- Faces
					(subobjectLevel == 4 or subobjectLevel == 5): (
						local groupCenters = array()
						obj = selection[1]
						faceList = polyop.getFaceSelection obj
						local groupedFaces = groupAdjacent obj faceList #Face
						1
						for gr_number in 1 to groupedFaces.count do (
							curVertSel = #{}
							for face in groupedFaces[gr_number] do curVertSel += ((polyOp.getFaceVerts obj face) as bitArray)
							vert = Vertex obj:obj numVert:gr_number subs_pos:(polyop.getVerts obj curVertSel)
							bbox = box3()
							expandToInclude bbox vert.subs_pos
							vert.pos = bbox.center
							append groupCenters vert.pos
							append vertexArray vert
						)
						-- move vertices
						if vertexArray.count > 2 then undo on (
							for vert in calcNewPositions vertexArray do (
								curVertSel = #{}
								for face in groupedFaces[vert.numVert] do curVertSel += ((polyOp.getFaceVerts obj face) as bitArray)
								polyop.moveVert obj curVertSel (vert.pos - groupCenters[vert.numVert])
							)
						)
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
						
					case of (
						-- Vertex
						(subobjectLevel == 1): (
							local oldVertSel = array() -- remember old vertex selection
							local curVertSel
							-- get vertex positions
							for obj in nodes do (
								select obj
								modpanel.setCurrentObject modif
								curVertSel = modif.EditPolyMod.GetSelection #Vertex
								append oldVertSel #(obj, curVertSel)
								for vert in curVertSel do (
									append vertexArray (Vertex obj:obj numVert:vert pos:(modif.GetVertex vert))
								)
							)
							if vertexArray.count > 2 then undo on (
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
								-- #FIXME Testing in MAX 2023 - uncomment these two lines. if select again, objects are diapearing. It must be deselect and select manualy for work well
								--deselect $*
								--completeredraw()
							) else (
								print "No Vertex selection to distribute"
							)
						)
						-- Edge
						(subobjectLevel == 2 or subobjectLevel == 3): (
							local oldEdgeSel = array() -- #(obj, curEdgeSel: bitarray) remember old vertex selection
							local curEdgeSel
							local curVertSel
							local groupedEdges
							local groupCenters = array()
							-- get Edge positions
							for obj in nodes do (
								select obj
								modpanel.setCurrentObject modif
								curEdgeSel = modif.GetSelection #Edge
								append oldEdgeSel #(obj, curEdgeSel)
								groupedEdges = groupAdjacent obj curEdgeSel #Edge
								for gr_number in 1 to groupedEdges.count do (
									curVertSel = #{}
									for edge in groupedEdges[gr_number] do curVertSel += ((polyOp.getEdgeVerts obj edge) as bitArray)
									vert = Vertex obj:obj numVert:gr_number subs_pos:(for v in curVertSel collect polyOp.getVert obj v)
									bbox = box3()
									expandToInclude bbox vert.subs_pos
									vert.pos = bbox.center
									append groupCenters vert.pos
									append vertexArray vert
								)
							)
							if vertexArray.count > 2 then undo on (
								-- set new vertex pos
								for vert in calcNewPositions vertexArray do (
									if selection[1] != vert.obj then select vert.obj
									modif.SetSelection #Edge groupedEdges[vert.numVert]
									modif.Select #Edge groupedEdges[vert.numVert]
									modif.MoveSelection (vert.pos - groupCenters[vert.numVert])
									modif.Commit()
								)
								-- select old edge selection
								for sel in oldEdgeSel do (
									select sel[1]
									modif.SetSelection #Edge sel[2]
								)
								-- #FIXME Testing in MAX 2023 - uncomment these two lines. if select again, objects are diapearing. It must be deselect and select manualy for work well
								-- deselect $*
								-- completeredraw()
							) else (
								print "No edge selection to distribute"
							)
						)
						-- Faces
						(subobjectLevel == 4 or subobjectLevel == 5): (
							local oldFaceSel = array() -- #(obj, curFaceSel: bitarray) remember old vertex selection
							local curFaceSel
							local curVertSel
							local groupedFaces
							local groupCenters = array()
							-- get Face positions
							for obj in nodes do (
								select obj
								modpanel.setCurrentObject modif
								curFaceSel = modif.GetSelection #Face
								append oldFaceSel #(obj, curFaceSel)
								groupedFaces = groupAdjacent obj curFaceSel #Face
								for gr_number in 1 to groupedFaces.count do (
									curVertSel = #{}
									for face in groupedFaces[gr_number] do curVertSel += ((polyOp.getFaceVerts obj face) as bitArray)
									vert = Vertex obj:obj numVert:gr_number subs_pos:(for v in curVertSel collect polyOp.getVert obj v)
									bbox = box3()
									expandToInclude bbox vert.subs_pos
									vert.pos = bbox.center
									append groupCenters vert.pos
									append vertexArray vert
								)
							)
							if vertexArray.count > 2 then undo on (
								-- set new vertex pos
								for vert in calcNewPositions vertexArray do (
									if selection[1] != vert.obj then select vert.obj
									modif.SetSelection #Face groupedFaces[vert.numVert]
									modif.Select #Face groupedFaces[vert.numVert]
									modif.MoveSelection (vert.pos - groupCenters[vert.numVert])
									modif.Commit()
								)
								-- select old Face selection
								for sel in oldFaceSel do (
									select sel[1]
									modif.SetSelection #Face sel[2]
								)
								-- #FIXME Testing in MAX 2023 - uncomment these two lines. if select again, objects are diapearing. It must be deselect and select manualy for work well
								-- deselect $*
								-- completeredraw()
							) else (
								print "No Face selection to distribute"
							)
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
			-- Create Vertex struct for nodes
			local sel = for obj in selection where obj.children.count == 0 collect Vertex obj:obj pos:obj.pos
			-- set new positions
			if sel.count > 2 then undo on (
				for vert in calcNewPositions sel do (
					vert.obj.pos = vert.pos
				)
			)
		)
		
		else: print "Can not do it."
	)
)

) -- End of macroscript