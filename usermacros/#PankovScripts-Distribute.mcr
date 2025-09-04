/* @Pankovea Scripts - 2025.09.04
Distribute: Скрипт для рапределения в пространстве

Особенности:
* Работает в режиме Объектов и в режиме подобъектов. 
Реализовано выравнивание подобъектов в EditableSpline, EditablePoly, и модификатора EditPoly.
модификатор EditSpline технически не доступен и работать не будет)

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
Has been implemented in all subobjects EditableSpline, EditablePoly, and the EditPoly modifier.
The EditSpline modifier does not work)

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

-- Группирует выделенные вершины
fn getSplineVertexGroups spline s_num vertSelection = ( -- in: spline: spline object, s_num: number of selected spline; vertSelection: array of nums selected vertices; out: array of arrays of arrays (groups of (spline number, Vertex numbers))
	
    if vertSelection.count == 0 then return #(#())
	if vertSelection.count == 1 then return #(vertSelection)

	local nKnots = numKnots spline s_num
	local isClosedSpline = isClosed spline s_num
	local isCircularSelection = isClosedSpline and vertSelection[1] == 1 and vertSelection[vertSelection.count] == nKnots
    
	local groups = #()
	local currentGroup = #(vertSelection[1])
    for i = 2 to vertSelection.count do (
        if vertSelection[i] == vertSelection[i-1] + 1 then append currentGroup vertSelection[i] 
        else (append groups currentGroup; currentGroup = #(vertSelection[i]))
    )
    append groups currentGroup
	if isCircularSelection and groups.count >= 2 then (
		groups = #(groups[1] + groups[groups.count]) + (for i in 2 to groups.count - 1 collect groups[i])
	)
    groups
	
)


-------------------------------------
-- Macroscript
-------------------------------------

on isEnabled return (
	try ( 
		-- list of conditions. Copy from the case statement on execute event handler
				-------------------- Editable Spline -----------------------
			(subobjectLevel != 0 \
			and (finditem #(line, SplineShape) (classof (modPanel.getCurrentObject())) ) != 0 ) \
		or	\	-------------------- Editable Poly -----------------------
			(subobjectLevel != 0 \
			and (classof (modPanel.getCurrentObject())) == Editable_Poly) \
		or 	\	----- Instanced modifier in multiple nodes -----
			(selection.count > 0 \
			and subObjectLevel != undefined \
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
		(subobjectLevel != 0 \
		and (finditem #(line, SplineShape) (classof (modPanel.getCurrentObject())) ) != 0 ): (
			base_obj = modPanel.getCurrentObject()
			obj = (refs.dependentNodes base_obj)[1]
			case subobjectLevel of (
				-- Vertex
				1: (vertexArray = array()
					for sp in 1 to numSplines obj do
						for vert in getKnotSelection obj sp do
							append vertexArray (Vertex numSp:sp numVert:vert pos: (getKnotPoint obj sp vert))
					if vertexArray.count > 2 then (
						undo on (
							for vert in calcNewPositions vertexArray do (
								KnotPoint = getKnotPoint obj vert.numSp vert.numVert
								diff = vert.pos - KnotPoint
								outVec = getOutVec obj vert.numSp vert.numVert
								inVec = getinVec obj vert.numSp vert.numVert
								setKnotPoint obj vert.numSp vert.numVert vert.pos
								setOutVec obj vert.numSp vert.numVert (outVec + diff)
								setInVec obj vert.numSp vert.numVert (inVec + diff)
							)
						)
						updateShape obj
					) else (
						print "No Vertex selection to distribute"
					)
				)
				-- Segments
				2: (vertexArray = array()
					for numSp in 1 to numSplines obj do (
						local segSelection = getSegSelection obj numSp
						if segSelection.count == 0 then continue
						local groupedSegments = getSplineVertexGroups obj numSp segSelection
						-- convert seg selection to vert selection
						local knots = numKnots obj numSp
						local isClosedSpline = isClosed obj numSp
						local isCircularSelect = isClosedSpline and segSelection[segSelection.count] == knots
						groupedVertices = for segsGroup in groupedSegments collect (
							vertGroup = (for segNum in segsGroup collect (segNum + 1)) as bitArray
							vertGroup += segsGroup as bitArray
							if isCircularSelect and vertGroup[knots] then (
								vertGroup += #{1}
								vertGroup -= #{knots+1}
							)
							vertGroup as array
						)
						-- get positions of groups
						for verts_group in groupedVertices do (
							groupedVertsPos = for vert_num in verts_group collect (getKnotPoint obj numSp vert_num)
							vert = Vertex obj:obj numSp:numSp numVert:verts_group subs_pos:groupedVertsPos
							bbox = box3()
							expandToInclude bbox groupedVertsPos
							vert.pos = bbox.center
							append vertexArray vert
						)
					)
					-- move vertices
					if vertexArray.count > 2 then (
						undo on (
							for vert in calcNewPositions vertexArray do (
								for i in 1 to vert.numVert.count do (
									vertIndex = vert.numVert[i]
									
									bbox = box3()
									expandToInclude bbox vert.subs_pos
									old_group_pos = bbox.center
									new_group_pos = vert.pos 
									diff = new_group_pos - old_group_pos
									old_vert_pos = vert.subs_pos[i]
									new_vert_pos = old_vert_pos + diff
									
									outVec = getOutVec obj vert.numSp vertIndex
									inVec = getinVec obj vert.numSp vertIndex
									setKnotPoint obj vert.numSp vertIndex new_vert_pos
									setOutVec obj vert.numSp vertIndex (outVec + diff)
									setInVec obj vert.numSp vertIndex (inVec + diff)
								)
							)
						)
						updateShape obj
					) else (
						print "No Segment selection to distribute"
					)
				)
				-- Splines
				3: (vertexArray = array()
					local splinelection = getSplineSelection obj
					for numSp in splinelection do (
						local knots = numKnots obj numSp
						local vertSelection = (#{1..knots} as array)
						local groupedVertices = getSplineVertexGroups obj numSp vertSelection
						-- get positions of groups
						for verts_group in groupedVertices do (
							groupedVertsPos = for vert_num in verts_group collect (getKnotPoint obj numSp vert_num)
							vert = Vertex obj:obj numSp:numSp numVert:verts_group subs_pos:groupedVertsPos
							bbox = box3()
							expandToInclude bbox groupedVertsPos
							vert.pos = bbox.center
							append vertexArray vert
						)
					)
					-- move vertices
					if vertexArray.count > 2 then (
						undo on (
							for vert in calcNewPositions vertexArray do (
								for i in 1 to vert.numVert.count do (
									vertIndex = vert.numVert[i]
									
									bbox = box3()
									expandToInclude bbox vert.subs_pos
									old_group_pos = bbox.center
									new_group_pos = vert.pos 
									diff = new_group_pos - old_group_pos
									old_vert_pos = vert.subs_pos[i]
									new_vert_pos = old_vert_pos + diff
									
									outVec = getOutVec obj vert.numSp vertIndex
									inVec = getinVec obj vert.numSp vertIndex
									setKnotPoint obj vert.numSp vertIndex new_vert_pos
									setOutVec obj vert.numSp vertIndex (outVec + diff)
									setInVec obj vert.numSp vertIndex (inVec + diff)
								)
							)
						)
						updateShape obj
					) else (
						print "No Spline selection to distribute"
					)
				)
			)
		)
		
		-------------------- Editable Poly -----------------------
		(subobjectLevel != 0 \
		and (classof (modPanel.getCurrentObject())) == Editable_Poly): (
			if subobjectLevel == 1 then sub_sel = polyop.getVertSelection selection[1].baseobject
			if subobjectLevel == 2 or subobjectLevel == 3 then sub_sel = polyop.getEdgeSelection selection[1].baseobject
			if subobjectLevel == 4 or subobjectLevel == 5 then sub_sel = polyop.getFaceSelection selection[1].baseobject
			if not sub_sel.isEmpty then (
				base_obj = modPanel.getCurrentObject()
				obj = (refs.dependentNodes base_obj)[1]
				case of (
					-- Vertex
					(subobjectLevel == 1): (
						vertList = polyop.getVertSelection obj.baseobject
						vertexArray = for numVert in vertList collect Vertex numVert:numVert pos:(polyop.getVert obj.baseobject numVert)
						if vertexArray.count > 2 then undo on (
							for vert in calcNewPositions vertexArray do (
								polyop.setVert obj vert.numVert vert.pos
							)
						)
					)
					-- Edge
					(subobjectLevel == 2 or subobjectLevel == 3): (
						local groupCenters = array()
						edgeList = polyop.getEdgeSelection obj.baseobject
						local groupedFaces = groupAdjacent obj.baseobject edgeList #Edge
						for gr_number in 1 to groupedFaces.count do (
							curVertSel = #{}
							for edge in groupedFaces[gr_number] do curVertSel += ((polyOp.getEdgeVerts obj.baseobject edge) as bitArray)
							vert = Vertex obj:obj numVert:gr_number subs_pos:(polyop.getVerts obj.baseobject curVertSel)
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
								for edge in groupedFaces[vert.numVert] do curVertSel += ((polyOp.getEdgeVerts obj.baseobject edge) as bitArray)
								polyop.moveVert obj.baseobject curVertSel (vert.pos - groupCenters[vert.numVert])
							)
						)
					)
					-- Faces
					(subobjectLevel == 4 or subobjectLevel == 5): (
						local groupCenters = array()
						faceList = polyop.getFaceSelection obj.baseobject
						local groupedFaces = groupAdjacent obj.baseobject faceList #Face
						1
						for gr_number in 1 to groupedFaces.count do (
							curVertSel = #{}
							for face in groupedFaces[gr_number] do curVertSel += ((polyOp.getFaceVerts obj.baseobject face) as bitArray)
							vert = Vertex obj:obj numVert:gr_number subs_pos:(polyop.getVerts obj.baseobject curVertSel)
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
								for face in groupedFaces[vert.numVert] do curVertSel += ((polyOp.getFaceVerts obj.baseobject face) as bitArray)
								polyop.moveVert obj.baseobject curVertSel (vert.pos - groupCenters[vert.numVert])
							)
						)
					)
				)
			) else (
				print "No selection to distribute"
			)
		)
		
		----- Instanced modifier in multiple nodes -----
		(selection.count > 0 \
		and subObjectLevel != undefined \
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
									diff = vert.pos - groupCenters[vert.numVert]
									modif.MoveSelection diff
									modif.Commit()
								)
								-- select old Face selection
								for sel in oldFaceSel do (
									select sel[1]
									modif.SetSelection #Face sel[2]
								)
								-- #FIXME Testing in MAX 2023 - uncomment these two lines. if select again, objects are diapearing. It must be deselect and select manualy for work well
								-- deselect $*
								redrawViews()
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
		and (subobjectLevel == 0 or subobjectLevel == undefined)): (
			-- Create Vertex struct for nodes
			local sel = for obj in selection where (finditem (selection as array) obj.parent) == 0 collect Vertex obj:obj pos:obj.pos
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