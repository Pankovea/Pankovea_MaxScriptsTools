/* @Pankovea Scripts - 2026.01.29
Distribute: Скрипт для рапределения в пространстве

Особенности:
* Работает в режиме Объектов и в режиме подобъектов. 
Реализовано выравнивание подобъектов в EditableSpline, EditablePoly, EditableMesh и модификатора EditPoly.
(модификаторы EditSpline и EditMesh технически не доступны в Maxscript и работать не будут)

* объекты распределяет равномерно учитывая размер объекта таким боразом, чтобы расстояние между ними было одинаковым
(нужно доработать смещение пивота от центра и точность определения размера. Сейчас размер определяется по Bounding box)
* Автоматически определяет первый и последний объекты по наибольшему расстоянию между ними.
* работает если модификатор наложен инстансом на месколько объектов
* Распределяет группированные объекты

* для запуска необходимо находиться в нужном режиме выделения.
--------
Distribute: A script for distribution in space

Features:
* Works in Object mode and in subobject mode. 
Has been implemented in all subobjects EditableSpline, EditablePoly, EditableMesh and the EditPoly modifier.
(The EditSpline and EditMesh modifiers are not available in Maxscript and does not work)

* distributes objects evenly, taking into account the size of the object in such a way that the distance between them is the same
(you need to refine the pivot offset from the center and the accuracy of sizing. Now the size is determined by the Bounding box)
* Automatically detects the first and last objects by the largest distance between them.
* works if the modifier is imposed by the instance on several objects
* Distributes grouped objects

* To start, you must be in the desired selection mode.
*/

macroScript Distibute_objects
category:"#PankovScripts"
toolTip:"Distibute objects. Shift+ Distribute projected"
icon:#("AutoGrid",2)
buttontext:"Distr" 	
(
local distribute_projected -- parametr
	
struct Vertex (
	obj,		-- Current object. For all cases
	numSp,		-- if working on splines, number of spline, else undefined
	numVert,	-- if working on splines, number of vertex or array of numbers, else undefined 
	pos,		-- Current object position. For all cases
	pos_offset=[0,0,0], -- point3 value difference to move current object
	size=0,		-- Current object size. For all cases
	subs_pos,	-- if working on subobjects, positions of grouped verts
	subs_sel,	-- if working on subobjects, bitarray selection of (verts, edges, faces) when workin on poly object.
	pivot_offset=[0,0,0], -- in objects pivot offset of the center object
	dist=0		-- Calculated distantion current object from the previus object according object size
)


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
	local distributedVerts = projectVertexToVector arrOfVerts FurthestVertsInd[1] FurthestVertsInd[2]
	local startVert = distributedVerts[FurthestVertsInd[1]]
	
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
	local obj_TM
	if arrOfVerts[1].numVert == undefined then (
		for vert in arrOfVerts do (
			-- определяем размер по оси vec
			-- cтроим ортонормированную матрицу: vec как X-ось, y и z перпендикулярны
			up = [0, 0, 1]
			if abs (dot vec up) > 0.99 then up = [0, 1, 0]  -- избегаем коллинеарности
			y = normalize (cross vec up)
			z = cross vec y
			tm = matrix3 vec y z [0, 0, 0]  -- трансформация в пространство, ориентированное по vec
			
			bbox = nodeGetBoundingBox vert.obj tm asBox3:true
			vert.size = bbox.max.x - bbox.min.x
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

		-- store old positions if not distribute_projected
		if not distribute_projected do
			for vert in arrOfVerts do vert.pos_offset = vert.pos
				
		local newArr = sortPoints arrOfVerts -- that copies of Vertex struct array and project positions to the line
		
		-- or store old positions if distribute_projected
		if distribute_projected do
			for vert in arrOfVerts do vert.pos_offset = vert.pos
			
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
					
		for i=2 to newArr.count-1 do (
			-- calc new position
			newArr[i].pos = newArr[i-1].pos + path_vec_nrm*newArr[i-1].size/2 + path_vec_nrm*step + path_vec_nrm*newArr[i].size/2
			-- calc difference
			newArr[i].pos_offset = newArr[i].pos - newArr[i].pos_offset -- new minus old pos
		)
		-- the extreme ones remain motionless
		StartVert.pos_offset = [0,0,0]
		EndVert.pos_offset = [0,0,0]
		return newArr
	) else (
		return arr
	)
)

-------------------------------------
-- Группировка полигонов
-------------------------------------

-- возвращает прилегающие полигоны к заданному
fn getAdjacent obj index type modif:undefined =
(
    local adj = #()
    local verts, connected

	if classOf modif == Edit_Poly then (
		verts = case type of (
			#Face: (degree = modif.GetFaceDegree index; for i=1 to degree collect modif.GetFaceVertex index i)
			#Edge: #(modif.GetEdgeVertex index 1, modif.GetEdgeVertex index 2)
		)
		numVerts = modif.GetNumVertices()
		for v in verts do (
			vertSet = #{v}
			vertSet.count = numVerts -- leave the initial count for successful further selections.
			connected = #{}
			case type of (
				#Face: modif.getFacesUsingVert &connected vertSet
				#Edge: modif.getEdgesUsingVert &connected vertSet
			)
			for el in connected do (
				if el != index and findItem adj el == 0 do
					append adj el
			)
		)
		return adj
	)
	
	if classOf obj == Editable_Poly then (
		verts = case type of (
			#Face: polyOp.getFaceVerts obj index
			#Edge: polyOp.getEdgeVerts obj index
		)
		for v in verts do (
			connected = case type of (
				#Face: polyOp.getFacesUsingVert obj v
				#Edge: polyOp.getEdgesUsingVert obj v
			)
			for el in connected do (
				if el != index and findItem adj el == 0 then (
					append adj el
				)
			)
		)
		return adj
	)
	
	if classOf obj == Editable_Mesh then (
        verts = case type of (
            #Face: meshop.getVertsUsingFace obj index
            #Edge: meshop.getVertsUsingEdge obj index
        )
        for v in verts do (
            connected = case type of (
                #Face: meshop.getFacesUsingVert obj v
                #Edge: meshop.getEdgesUsingVert obj v
            )
            for el in connected do (
                if el != index and findItem adj el == 0 then (
                    append adj el
                )
            )
        )
		return adj
    )
	return adj
)

-- группирует прилегающие полигоны. Рабтает как с Editable Poly, так и с Edit Poly
fn groupAdjacent obj selected type modif:undefined = ( -- in: obj,  selected: bitarray; out: array of bitarrays (groups of Face numbers)
    local grouped = #()
    local visited = #{}
    
    for index in selected do (
        if not visited[index] then (
            local _group = #{}
			_group.count = case of (  -- leave the initial count for successful further selections.
				(classof modif == Edit_Poly): (	
					if selection.count != 1 or selection[1] != obj do (
						modPanel.setCurrentObject modif node:obj
					)
					case type of (
						#Face: modif.getNumFaces() 
						#Edge: modif.getNumEdges() 
					)
				)
				(classof obj == Editable_Poly): 
					case type of (
						#Face: polyop.getNumFaces obj
						#Edge: polyop.getNumEdges obj
					)
				(classof obj == Editable_Mesh): 
					case type of (
						#Face: meshop.getNumFaces obj
						#Edge: (meshop.getNumFaces obj) * 3
					)
			)
            local queue = #(index)
            
            while queue.count > 0 do (
                local current = queue[1]
                deleteItem queue 1
                
                if not visited[current] then (
                    _group[current] = true
                    visited[current] = true
                    
                    local adj = getAdjacent obj current type modif:modif
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
		modPanelCurObj = modPanel.getCurrentObject()
		-- list of conditions. Copy from the case statement on execute event handler
				-------------------- Editable Spline -----------------------
			(subobjectLevel != 0 \
			and (finditem #(line, SplineShape) (classof modPanelCurObj) ) != 0 ) \
		or	\	-------------------- Editable Mesh -----------------------
			(subobjectLevel != 0 \
			and (classof modPanelCurObj== Editable_Mesh)) \
		or	\	-------------------- Editable Poly -----------------------
			(subobjectLevel != 0 \
			and (classof modPanelCurObj) == Editable_Poly) \
		or 	\	----- Instanced modifier in multiple nodes -----
			(selection.count > 0 \
			and subObjectLevel != undefined \
			and subObjectLevel > 0 \
			and modPanelCurObj != selection[1].baseobject) \
		or 	\	--------------------- Objects -----------------------
			(selection.count > 1 \
			and (subobjectLevel == 0 or subobjectLevel == undefined))
	) catch false
)

on execute do (
	local vertexArray = #()
	distribute_projected = keyboard.shiftPressed
	
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
						with redraw off ( undo on (
							for vert in calcNewPositions vertexArray do (
								KnotPoint = getKnotPoint obj vert.numSp vert.numVert
								diff = vert.pos - KnotPoint
								outVec = getOutVec obj vert.numSp vert.numVert
								inVec = getinVec obj vert.numSp vert.numVert
								setKnotPoint obj vert.numSp vert.numVert vert.pos
								setOutVec obj vert.numSp vert.numVert (outVec + diff)
								setInVec obj vert.numSp vert.numVert (inVec + diff)
							)
							updateShape obj
						))
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
						with redraw off ( undo on (
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
							updateShape obj
						))
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
						with redraw off ( undo on (
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
							updateShape obj
						))
					) else (
						print "No Spline selection to distribute"
					)
				)
			)
		)
		
		
		-------------------- Editable Mesh -----------------------
		(subobjectLevel != 0 \
		and (classof (modPanel.getCurrentObject())) == Editable_Mesh): (
			local sub_sel = case of (
				(subobjectLevel == 1): selection[1].selectedVerts as bitarray
				(subobjectLevel == 2 or subobjectLevel == 3): selection[1].selectedEdges as bitarray
				(subobjectLevel == 4 or subobjectLevel == 5): selection[1].selectedFaces as bitarray
			)
			if not sub_sel.isEmpty then (
				base_obj = modPanel.getCurrentObject()
				obj = selection[1]
				case of (
					-- Vertex
					(subobjectLevel == 1): (
						vertexArray = for numVert in sub_sel collect Vertex numVert:numVert pos:(meshop.getVert obj numVert)
						if vertexArray.count > 2 then with redraw off ( undo on (
							for vert in calcNewPositions vertexArray do (
								meshop.setVert obj vert.numVert vert.pos
							)
						))
					)
					-- Edge
					(subobjectLevel == 2 or subobjectLevel == 3): (
						local subs_pos, vert, bbox
						local groupedEdges = groupAdjacent obj sub_sel #Edge
						for gr_number in 1 to groupedEdges.count do (
							curVertSel = meshop.getVertsUsingEdge obj groupedEdges[gr_number]
							subs_pos = meshop.getVerts obj curVertSel
							vert = Vertex obj:obj numVert:gr_number subs_pos:subs_pos subs_sel:curVertSel
							bbox = box3()
							expandToInclude bbox vert.subs_pos
							vert.pos = bbox.center
							append vertexArray vert
						)
						-- move vertices
						if vertexArray.count > 2 then with redraw off ( undo on (
							for vert in calcNewPositions vertexArray do
								for i in vert.subs_sel do
									obj.verts[i].pos += vert.pos_offset
							update obj
						))
					)
					-- Faces
					(subobjectLevel == 4 or subobjectLevel == 5): (
						local groupedFaces = groupAdjacent obj sub_sel #Face
						for gr_number in 1 to groupedFaces.count do (
							curVertSel = meshop.getVertsUsingFace obj groupedFaces[gr_number]
							subs_pos = meshop.getVerts obj curVertSel
							vert = Vertex obj:obj numVert:gr_number subs_pos:subs_pos subs_sel:curVertSel
							bbox = box3()
							expandToInclude bbox vert.subs_pos
							vert.pos = bbox.center
							append vertexArray vert
						)
						-- move vertices
						if vertexArray.count > 2 then with redraw off ( undo on (
							for vert in calcNewPositions vertexArray do
								for i in vert.subs_sel do
									obj.verts[i].pos += vert.pos_offset
							update obj
						))
					)
				)
			) else (
				print "No selection to distribute"
			)
		)
		
		-------------------- Editable Poly -----------------------
		(subobjectLevel != 0 \
		and (classof (modPanel.getCurrentObject())) == Editable_Poly): (
			local sub_sel = case of (
				(subobjectLevel == 1): polyop.getVertSelection selection[1].baseobject
				(subobjectLevel == 2 or subobjectLevel == 3): polyop.getEdgeSelection selection[1].baseobject
				(subobjectLevel == 4 or subobjectLevel == 5): polyop.getFaceSelection selection[1].baseobject
			)
			if not sub_sel.isEmpty then (
				base_obj = modPanel.getCurrentObject()
				obj = (refs.dependentNodes base_obj)[1]
				case of (
					-- Vertex
					(subobjectLevel == 1): (
						vertList = polyop.getVertSelection obj.baseobject
						vertexArray = for numVert in vertList collect Vertex numVert:numVert pos:(polyop.getVert obj.baseobject numVert)
						if vertexArray.count > 2 then with redraw off ( undo on (
							for vert in calcNewPositions vertexArray do (
								polyop.setVert obj.baseobject vert.numVert vert.pos
							)
						))
					)
					-- Edge
					(subobjectLevel == 2 or subobjectLevel == 3): (
						edgeList = polyop.getEdgeSelection obj.baseobject
						local groupedEdges = groupAdjacent obj.baseobject edgeList #Edge
						for gr_number in 1 to groupedEdges.count do (
							curVertSel = #{}
							for edge in groupedEdges[gr_number] do curVertSel += ((polyOp.getEdgeVerts obj.baseobject edge) as bitArray)
							vert = Vertex obj:obj numVert:gr_number subs_pos:(polyop.getVerts obj.baseobject curVertSel) subs_sel:curVertSel
							local bbox = box3()
							expandToInclude bbox vert.subs_pos
							vert.pos = bbox.center
							append vertexArray vert
						)
						-- move vertices
						if vertexArray.count > 2 then with redraw off ( undo on (
							for vert in calcNewPositions vertexArray do (
								polyop.moveVert obj.baseobject vert.subs_sel vert.pos_offset
							)
						))
					)
					-- Faces
					(subobjectLevel == 4 or subobjectLevel == 5): (
						faceList = polyop.getFaceSelection obj.baseobject
						local groupedFaces = groupAdjacent obj.baseobject faceList #Face
						for gr_number in 1 to groupedFaces.count do (
							curVertSel = #{}
							for face in groupedFaces[gr_number] do curVertSel += ((polyOp.getFaceVerts obj.baseobject face) as bitArray)
							vert = Vertex obj:obj numVert:gr_number subs_pos:(polyop.getVerts obj.baseobject curVertSel) subs_sel:curVertSel
							bbox = box3()
							expandToInclude bbox vert.subs_pos
							vert.pos = bbox.center
							append vertexArray vert
						)
						-- move vertices
						if vertexArray.count > 2 then with redraw off ( undo on (
							for vert in calcNewPositions vertexArray do (
								polyop.moveVert obj.baseobject vert.subs_sel vert.pos_offset
							)
						))
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
				)
				
				--------------------------------------------------------------------
				
				Edit_Mesh: (
					print "Have not access to Edit Mesh modifier selection. Please, do select on the base object"
				)
				
				--------------------------------------------------------------------
				
				Edit_Poly: (
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
								if selection[1] != obj then (
									modpanel.setCurrentObject modif node:obj
								)
								curVertSel = modif.EditPolyMod.GetSelection #Vertex
								append oldVertSel #(obj, curVertSel)
								for vert in curVertSel do (
									append vertexArray (Vertex obj:obj numVert:vert pos:(modif.GetVertex vert))
								)
							)
							if vertexArray.count > 2 then (
								with redraw off ( undo on (
									-- set new vertex pos
									local vertSel
									for vert in calcNewPositions vertexArray do (
										if selection[1] != vert.obj then (
											modpanel.setCurrentObject modif node:sel[1]
										)
										vertSel = #{vert.numVert}
										vertSel.count = modif.getNumVertices()
										modif.SetSelection #Vertex vertSel
										modif.MoveSelection vert.pos_offset
										modif.Commit()
									)
									-- select old vertex selection
									for s in oldVertSel do (
										select s[1]
										modif.SetSelection #Vertex s[2]
									)
									-- select old objects selection
									if sel.count == 1 then (
										modpanel.setCurrentObject modif node:sel[1]
									) else (
										select sel
									)
								))
							) else (
								print "No Vertex selection to distribute"
							)
						)
						-- Edge
						(subobjectLevel == 2 or subobjectLevel == 3): (
							local oldEdgeSel = array() -- #(obj, curEdgeSel: bitarray) remember old vertex selection
							local curEdgeSel
							local groupedEdges
							-- get Edge positions
							for obj in nodes do (
								if selection[1] != obj then (
									modpanel.setCurrentObject modif node:obj
								)
								curEdgeSel = modif.GetSelection #Edge
								append oldEdgeSel #(obj, curEdgeSel)
								groupedEdges = groupAdjacent obj curEdgeSel #Edge modif:modif
								for gr_number in 1 to groupedEdges.count do (
									curVertSel = #{}
									for edge in groupedEdges[gr_number] do curVertSel += ((polyOp.getEdgeVerts obj edge) as bitArray)
									vert = Vertex obj:obj numVert:gr_number subs_pos:(for v in curVertSel collect polyOp.getVert obj v) subs_sel:groupedEdges[gr_number]
									bbox = box3()
									expandToInclude bbox vert.subs_pos
									vert.pos = bbox.center
									append vertexArray vert
								)
							)
							if vertexArray.count > 2 then (
								with redraw off ( undo on (
									-- set new vertex pos
									for vert in calcNewPositions vertexArray do (
										if vert.pos_offset != [0,0,0] then (
											if selection[1] != vert.obj then (
												modpanel.setCurrentObject modif node:vert.obj
											)
											modif.SetSelection #Edge vert.subs_sel
											modif.MoveSelection vert.pos_offset
											modif.Commit()
										)
									)
									-- select old edge selection
									for s in oldEdgeSel do (
										select s[1]
										modif.SetSelection #Edge s[2]
									)
									-- select old objects selection
									if sel.count > 1 do select sel
								))
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
							-- get Face positions
							for obj in nodes do (
								modpanel.setCurrentObject modif node:obj
								curFaceSel = modif.GetSelection #Face
								append oldFaceSel #(obj, curFaceSel)
								groupedFaces = groupAdjacent obj curFaceSel #Face modif:modif
								for gr_number in 1 to groupedFaces.count do (
									curVertSel = #{}
									for face in groupedFaces[gr_number] do curVertSel += ((polyOp.getFaceVerts obj face) as bitArray)
									vert = Vertex obj:obj numVert:gr_number subs_pos:(for v in curVertSel collect polyOp.getVert obj v) subs_sel:groupedFaces[gr_number]
									bbox = box3()
									expandToInclude bbox vert.subs_pos
									vert.pos = bbox.center
									append vertexArray vert
								)
							)
							if vertexArray.count > 2 then (
								with redraw off ( undo on (
									-- set new vertex pos
									for vert in calcNewPositions vertexArray do (
										if vert.pos_offset != [0,0,0] then (
											if selection[1] != vert.obj then (
												modpanel.setCurrentObject modif node:vert.obj
											)
											modif.SetSelection #Face vert.subs_sel
											modif.MoveSelection vert.pos_offset
											modif.Commit()
										)
									)
									-- select old Face selection
									for s in oldFaceSel do (
										select s[1]
										modif.SetSelection #Face s[2]
									)
									-- select old objects selection
									if sel.count > 1 do select sel
								))
							) else (
								print "No Face selection to distribute"
							)
						)
					)
					-- close groups
					for obj in groups do setGroupOpen obj false
				)
				
			)
		)
			
		--------------------- Objects -----------------------
		(selection.count > 1 \
		and (subobjectLevel == 0 or subobjectLevel == undefined)): (
			-- Create Vertex struct for nodes
			local sel = for obj in selection where (finditem (selection as array) obj.parent) == 0 collect (
				--bbox_center = obj.center
				Vertex obj:obj pos:obj.center pivot_offset: (obj.pos - obj.center)
			)
			-- set new positions
			if sel.count > 2 then with redraw off ( undo on (
				for vert in calcNewPositions sel do (
					--vert.obj.pos = vert.pos + vert.pivot_offset
					vert.obj.pos += vert.pos_offset
				)
			))
		)
		
		else: print "Can not do it."
	)
)

) -- End of macroscript