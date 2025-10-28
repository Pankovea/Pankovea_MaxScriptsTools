/* @Pankovea Scripts - 2025.10.28
ResetModContextTM: Сбрасывает матрицу трансформаций в контексте модификатора к состоянию как если бы модификатор был только что применён к объектам или одному объекту.

особенности:
* Работает с выделенным модификатором в стеке модификаторов
* при нажатом Shift сбрасывает ModContextBBox для каждого объекта в отдельности
* при нажатом Esc сбрасывает Gizmo
* при изменении точки преобразований не получается сохранить объект в изначальном положении
внимание:
* undo не работает

--------
ResetModContextTM: Resets the transformation matrix in the context of the modifier to the state as if the modifier had just been applied to objects or a single object.

features:
* Works with a dedicated modifier in the modifier stack
* when Shift is pressed, resets the ModContextBBox for each object individually
* when Esc is pressed, Gizmo resets
* when changing the transformation point, it is not possible to keep the object in its original position

attention:
* undo does not work
*/


macroScript Pankov_ResetModContextTM
category:"#PankovScripts"
buttontext:"ResetModTM"
tooltip:"Reset modifier context tranform for multiple seleted objects. Shift+ reset to zero. Esc+ make unique modifier"
(
local gizmo_modifiers = #(xform, bend, squeeze, taper, wave, twist, skew, stretch, melt, noise, Vol__Select, Uvwmap)
local ffd_modifiers = #(FFD_2x2x2, FFD_3x3x3, FFD_4x4x4, FFDBox, FFDCyl)
local others = #(SliceModifier, symmetry, mirror)
local nullTM = matrix3 1

function make_modifier_unique obj modif = (
	if (refs.dependentnodes modif).count < 2 then return modif
	
	local i = modPanel.getModifierIndex obj modif
	local old_tm = getModContextTM obj modif
	local cp_modif = copy modif
	addModifierWithLocalData obj cp_modif obj modif before:(i-1)
	deleteModifier obj (i+1)
	setModContextTM obj modif old_tm
	return cp_modif
)

function tmObjPivotOffset obj = (
	(scaleMatrix obj.objectOffsetScale) * (obj.objectOffsetRot as Matrix3) * (transMatrix obj.objectOffsetPos)
)

function get_gizmoTM modif = (
	case of (
		(finditem gizmo_modifiers (classof modif) > 0) : modif_tr = modif.gizmo.transform
		(finditem ffd_modifiers (classof modif) > 0) : modif_tr = modif.Lattice_Transform.transform
		default: try ( modif_tr = modif.gizmo.transform ) catch (modif_tr = nullTM)
	)
	return modif_tr
)

on isenabled do (
	local modif = modPanel.getCurrentObject()
	(superclassof modif == modifier) and (modPanel.validModifier modif)
)

on execute do (	
	local use_gizmo_avg_center = true -- calculate parametr
	local modif = modPanel.getCurrentObject()
	if modif != undefined then (
		local work_objects = for obj in selection where (finditem obj.modifiers modif != 0) collect obj
		local me = modif.enabled -- save enabled modif
		
		undo on (
			
			if keyboard.shiftPressed or work_objects.count == 1 then (
				for obj in work_objects do (
					tm = obj.transform -- save transform
					obj.transform = (matrix3 [1,0,0] [0,1,0] [0,0,1] obj.pos) -- reset obj transform
					modif.enabled = false -- turn of modifier
					objBBox = Box3 (obj.min - obj.pos) (obj.max - obj.pos) -- get local bbox
					tmObjPiv = tmObjPivotOffset obj
					setModContextTM obj modif tmObjPiv -- reset Mod Context Transform Matrix
					setModContextBBox obj modif objBBox -- reset Mod Context Bounding Box
					obj.transform = tm -- restore transform
					modif.enabled = me -- restore modif enabled
				)
			) else with redraw off (

				-- calc selected bbox based on old gizmo positions instead of selection center
				modif.enabled = false -- turn off modifier

				-- Calculate bbox size based on selection
				local selection_center = (selection.max + selection.min) / 2 
				local half_size = (selection.max - selection.min) / 2
				modif.enabled = me -- restore modifier state
				
				-- Determine the center to use
				local new_center_in_world = if use_gizmo_avg_center then (
					-- Collect old gizmo global positions
					local old_tms = for obj in work_objects collect (
						modTM = getModContextTM obj modif -- store old mod context transform matrices
						gizmoTM = get_gizmoTM modif
						tmObjPiv = tmObjPivotOffset obj
						gizmoTM * inverse(modTM) * obj.transform * tmObjPiv
					)
					-- Calculate average gizmo position (new center)
					/*
					local avg_gizmo_pos = [0,0,0]
					for tm in old_tms do avg_gizmo_pos += tm.position
					avg_gizmo_pos /= old_tms.count
					avg_gizmo_pos
					*/
					-- Calculate median position
					local count = old_tms.count
					-- Sort each axis separately
					local xs = for tm in old_tms collect tm.position.x
					local ys = for tm in old_tms collect tm.position.y
					local zs = for tm in old_tms collect tm.position.z
					sort xs
					sort ys
					sort zs
					-- Get median
					local mid = (count + 1) / 2.0
					local idx1 = floor mid
					local idx2 = ceil mid
					
					local median_x = (xs[idx1] + xs[idx2]) / 2.0
					local median_y = (ys[idx1] + ys[idx2]) / 2.0
					local median_z = (zs[idx1] + zs[idx2]) / 2.0
					
					[median_x, median_y, median_z]

				) else (
					selection_center
				)
				
				-- Calculate bbox offset relative to new center
				local bbox_offset = new_center_in_world - selection_center
				local selectionBBox = Box3 (- half_size - bbox_offset) (half_size - bbox_offset)
				
				for i in 1 to 20 do ( -- do it several times so that the calculations come to a stable state 

					
					for obj in work_objects do (
						if keyboard.escPressed then (
							modif = make_modifier_unique obj modif -- make unique modifier
							modif.gizmo.transform = nullTM
						)
						gizmoTM = get_gizmoTM modif
						setModContextBBox obj modif selectionBBox
						local new_center_in_world_TM = matrix3 1
						new_center_in_world_TM.position = new_center_in_world
						tmObjPiv = tmObjPivotOffset obj
						new_tm = tmObjPiv * obj.transform * inverse(new_center_in_world_TM) * gizmoTM
						setModContextTM obj modif new_tm
					)
					
					-- update geometry
					modif.enabled = false
					modif.enabled = me
					RedrawViews()
				)
			)
			
		) -- end undo
	) -- end modif check
) -- end on execute

) -- end macroscript



/*
==========================================================

ResetModContextTM: Сбрасывает контекстный BBox модификатора

==========================================================
*/


macroScript Pankov_ResetModContextBBox
category:"#PankovScripts"
buttontext:"ResetModBBox"
tooltip:"Reset modifier context bounding box for multiple seleted objects."
(
	function resetBBoxSize nodes modif = ( -- Подгоняет bbox под объект после трансформаций gizmo модификатора
		local modif_enabled = modif.enabled -- store modif enabled
		modif.enabled = false -- turn of modifier
		local half_size = (selection.max - selection.min) / 2
		local selection_center = (selection.max + selection.min) / 2
		
		modif.enabled = modif_enabled -- restore modif enabled
		
		for obj in nodes do (
			local contextTM = getModContextTM obj modif
			local objTM = obj.transform
			local tmObjPivOffset = (scaleMatrix obj.objectOffsetScale) * (obj.objectOffsetRot as Matrix3) * (transMatrix obj.objectOffsetPos)
			local bbox_offset = (inverse(contextTM) * objTM * tmObjPivOffset ).row4 - selection_center
			local selectionBBox = Box3 (- half_size - bbox_offset) (half_size - bbox_offset) 
			
			setModContextBBox obj modif selectionBBox
		)

		RedrawViews()
	)
	
	on isenabled do (
		local modif = modPanel.getCurrentObject()
		(superclassof modif == modifier) and (modPanel.validModifier modif)
	)

	on execute do (
		local modif = modPanel.getCurrentObject()
		local dependent_nodes = (refs.dependentNodes modif)
		nodes = for obj in selection where (finditem dependent_nodes obj) > 0 collect obj
		with undo on (
			resetBBoxSize nodes modif
		)
	)
	
)



/*
==========================================================

Copy_ModContextTM: Позволяет копировать контекстную матрицу трансформаций с одного модификатора на другой
Так же можно копировать BBox размеры gizmo и странформации самого объекта

==========================================================
*/



macroScript Pankov_Copy_ModContextTM
category:"#PankovScripts"
buttontext:"CopyModTM"
tooltip:"Copy modifier context tranform"
(
	global Pankov_Copy_ModContextTM_buffer = Dictionary #(#object_TM, undefined) #(#ModContextTM, undefined)
	
	rollout Copy_ModContextTM "Copy ModContextTM" width:162 (
		label lbl1 "Transform"
		checkbox TM_type_pos "pos" checked:true across:3
		checkbox TM_type_rot "rot" checked:true
		checkbox TM_type_scale "scale" checked:true
		button cp_TM "Copy" across:4
		pickbutton pick_TM "Pick"
		checkbox tm_buffer "" enabled:false
		button pst_TM "Paste"
		
		label lbl2 "Modif Context"
		checkbox context_TM "TM" checked:true across:2
		checkbox context_BBox "BBox" checked:true
		button cp_contextTM "Copy" across:3
		checkbox contextTM_buffer "" enabled:false
		button pst_contextTM "Paste"

		on pick_TM picked obj do (
			Pankov_Copy_ModContextTM_buffer[#object_TM] = obj.transform
			tm_buffer.checked = true
		)

		on cp_TM pressed do (
			if selection.count > 0 then (
				local srcObj = selection[1]
				Pankov_Copy_ModContextTM_buffer[#object_TM] = srcObj.transform
				tm_buffer.checked = true
			)
		)

		on pst_TM pressed do (
			if Pankov_Copy_ModContextTM_buffer[#object_TM] != undefined do undo "Paste Transform" on (
				for obj in selection do (
					if (TM_type_pos.checked and TM_type_rot.checked and TM_type_scale.checked) then (
						obj.transform = Pankov_Copy_ModContextTM_buffer[#object_TM]
					) else (
						if TM_type_scale.checked do (
							obj.scale = Pankov_Copy_ModContextTM_buffer[#object_TM].scale
						)
						if TM_type_rot.checked do (
							local stored_pos = obj.pos
							obj.rotation = Pankov_Copy_ModContextTM_buffer[#object_TM].rotation
							obj.pos = stored_pos
						)
						if TM_type_pos.checked do (
							obj.pos = Pankov_Copy_ModContextTM_buffer[#object_TM].pos
						)
					)
				)
			)
		)
		
		on cp_contextTM pressed do (
			if selection.count > 0 then (
				local modif = modPanel.getCurrentObject()
				local srcObj = selection[1]
				if modPanel.validModifier modif then (
                    -- Сохраняем мировую трансформацию объекта и трансформацию контекста модификатора
					Pankov_Copy_ModContextTM_buffer[#ModContextTM] = #(srcObj, (getModContextTM srcObj modif), (getModContextBBox srcObj modif))
					contextTM_buffer.checked = true
				)
			)
		)
		
		on pst_contextTM pressed do (
			if (context_TM.checked or context_BBox.checked) and selection.count > 0 and Pankov_Copy_ModContextTM_buffer[#ModContextTM] != undefined then (
				local modif = modPanel.getCurrentObject()
				if modPanel.validModifier modif then (
					-- Получаем сохраненные матрицы
					local src = Pankov_Copy_ModContextTM_buffer[#ModContextTM][1] -- Мировая трансформация исходного объекта
					local srcWorldTM = src.transform -- Мировая трансформация исходного объекта
					local srcPivOffsetTM = (scaleMatrix src.objectOffsetScale) * (src.objectOffsetRot as Matrix3) * (transMatrix src.objectOffsetPos)
					local srcModContextTM = Pankov_Copy_ModContextTM_buffer[#ModContextTM][2] -- Трансформация контекста модификатора
					local srcModContextBBox = Pankov_Copy_ModContextTM_buffer[#ModContextTM][3] -- BBox модификатора
					undo on (
						for trgetObj in selection do (
							-- Вычисляем новую матрицу контекста модификатора
							local trgetPivOffsetTM = (scaleMatrix trgetObj.objectOffsetScale) * (trgetObj.objectOffsetRot as Matrix3) * (transMatrix trgetObj.objectOffsetPos)
							local trgetTM = trgetPivOffsetTM * trgetObj.transform * (inverse (srcPivOffsetTM * srcWorldTM)) * srcModContextTM
							-- Применяем новую матрицу к целевому объекту
							if context_TM.checked do
								setModContextTM trgetObj modif trgetTM
							if context_BBox.checked do
								setModContextBBox trgetObj modif srcModContextBBox
						)
					)
					modif.enabled = not modif.enabled
					modif.enabled = not modif.enabled
					redrawViews()
				)
			)
		)
		
		on Copy_ModContextTM open do (
			if Pankov_Copy_ModContextTM_buffer[#object_TM] != undefined do tm_buffer.checked = true
			if Pankov_Copy_ModContextTM_buffer[#ModContextTM] != undefined do contextTM_buffer.checked = true
		)
	)
	
	
	on execute do (
		CreateDialog Copy_ModContextTM
	)
)




/*
==========================================================

TransformModContextTM: Позволяет трансформировать матрицу контекста для модификатора
для визуализации используется объект Dummy

==========================================================
*/




macroScript TransformModContextTM
category:"#PankovScripts"
tooltip:"Transform Modifier's Context TM"
(
    global targetMod, targetNodes, gizmoHelper
	targetNodes = #()
    local rotDialog
    local transformCallbackID = #ModContextTMRotatorCallback
    local transformWhenHandle -- Переменная для хранения when-обработчика
	
	local gizmo_project_modifiers = #(Displace, Uvwmap) -- without bbox
	local gizmo_slice_modifiers = #(SliceModifier, symmetry, mirror)
	local gizmo_with_bbox = #(xform, bend, squeeze, taper, wave, Ripple, twist, skew, stretch, melt, noise, Vol__Select)
	local gizmo_modifiers = gizmo_with_bbox + gizmo_project_modifiers
	local ffd_modifiers = #(FFD_2x2x2, FFD_3x3x3, FFD_4x4x4, FFDBox, FFDCyl)
	local bbox_modifiers = gizmo_with_bbox + ffd_modifiers 
	
    local enabledOnMods = gizmo_modifiers + ffd_modifiers + gizmo_slice_modifiers
	local nullTM = matrix3 1
	
	fn getGizmoTM modif = (
		return case of (
			(finditem gizmo_modifiers (classof modif) > 0) : modif.gizmo.transform
			(classOf modif == SliceModifier):  modif.Slice_Plane.transform
			(classOf modif == Symmetry):       modif.Mirror.transform
			(classOf modif == Mirror):         modif.Mirror_Center.transform
			(finditem ffd_modifiers (classof modif) > 0) :   modif.Lattice_Transform.transform
			default: try ( modif.gizmo.transform ) catch (nullTM)
		)
	)
	
	fn DummyForwardTransform modif nd = (
		local gizmoTM = getGizmoTM modif
		local modTM = getmodcontextTM nd modif
		local targetNodeTM = nd.transform
		local pivotOffsetTM = (scaleMatrix nd.objectOffsetScale) * (nd.objectOffsetRot as Matrix3) * (transMatrix nd.objectOffsetPos)
		return gizmoTM * inverse(modTM) * targetNodeTM * pivotOffsetTM
	)
	
	fn DummyReverseTransform dummyTM modif nd = (
		local gizmoTM = getGizmoTM modif
		local targetNodeTM = nd.transform
		local pivotOffsetTM = (scaleMatrix nd.objectOffsetScale) * (nd.objectOffsetRot as Matrix3) * (transMatrix nd.objectOffsetPos)
		local newTM = pivotOffsetTM * targetNodeTM * inverse(dummyTM) * gizmoTM
		setModContextTM nd modif newTM
		return newTM
	)
	
	-- Функция для усреднения bbox
	fn averageBBoxSize targetNodes targetMod = (
		local bbox
		local bbox_size__collection = for obj in targetNodes collect (
			bbox = getModContextBBox obj targetMod
			bbox.max - bbox.min -- output Point3
		)
		bbox_avg = [0,0,0]
		for bb in bbox_size__collection do bbox_avg += bb
		bbox_avg /= bbox_size__collection.count
		return bbox_avg
	)
	
	-- Функция для усреднения bbox
	fn averageBBoxCenter targetNodes targetMod = (
		local bbox
		local bbox_center_collection = for obj in targetNodes collect (
			bbox = getModContextBBox obj targetMod
			(bbox.max + bbox.min) / 2  -- output Point3
		)
		bbox_avg = [0,0,0]
		for bb in bbox_center_collection do bbox_avg += bb
		bbox_avg /= bbox_center_collection.count
		return bbox_avg
	)
	
    -- Функция обновления матрицы
    fn updateModContextTM = (
        if isValidNode gizmoHelper and targetMod != undefined do (
			local valid_targetNodes = for nd in targetNodes where isvalidnode nd collect nd
			local bboxCenterOffset = averageBBoxCenter valid_targetNodes targetMod
			for nd in valid_targetNodes do (
				try (
					local gizmoTM = getGizmoTM targetMod
					-- Учитываем bbox смещение при обратном преобразовании
					if (finditem bbox_modifiers (classOf targetMod) > 0) then (
						local bboxTransform = matrix3 1
						bboxTransform.row4 = bboxCenterOffset
						gizmoTM = gizmoTM * bboxTransform
					)
					DummyReverseTransform gizmoHelper.transform targetMod nd
					
				) catch (
					messageBox "Failed to update ModContextTM"
					format "Error: %\n" (getCurrentException())
				)
			)
        )
    )
    
    -- Функция для обновления отображения
    fn show_result = (
        targetMod.enabled = false
        targetMod.enabled = true
    )
    
    -- Callback для отслеживания изменений трансформации
    fn onTransformChanged nd = (
        if nd == gizmoHelper do (
            updateModContextTM()
            show_result()
        )
    )
	
	-- Функция для усреднения матриц трансформаций
	fn averageTransforms matrixArray = (
		if matrixArray.count == 0 then return (matrix3 1)
		if matrixArray.count == 1 then return matrixArray[1]
		
		local avgPos = [0,0,0]
		local qSum = quat 0 0 0 1

		-- Масштабы с знаком по осям
		local avgScaleX = 0.0
		local avgScaleY = 0.0
		local avgScaleZ = 0.0

		-- Базовая "референсная" ориентация для определения знака
		-- Нужна, чтобы определить, в какую сторону "смотрит" ось при отражении
		local refAxisX = [1,0,0]
		local refAxisY = [0,1,0]
		local refAxisZ = [0,0,1]

		-- Для каждой матрицы из массива суммируем позицию, масштаб и вращение (кватернионы)
		for tm in matrixArray do
		(
			-- 1. Позиция
			avgPos += tm.row4

			-- 2. Извлечение масштаба с знаком
			local ax = tm.row1
			local ay = tm.row2
			local az = tm.row3

			local sx = length ax
			local sy = length ay
			local sz = length az

			-- Определяем знак масштаба по направлению осей относительно референса
			-- Используем скалярное произведение
			local signX = if (dot ax refAxisX) < 0 then -1 else 1
			local signY = if (dot ay refAxisY) < 0 then -1 else 1
			local signZ = if (dot az refAxisZ) < 0 then -1 else 1

			-- Учитываем отражения через чётность: если отражений нечётное число — определитель отрицательный
			-- Но для масштаба просто сохраняем знак
			avgScaleX += sx * signX
			avgScaleY += sy * signY
			avgScaleZ += sz * signZ

			-- 3. Ориентация: удаляем масштаб, получаем чистое вращение
			local cleanTM = matrix3 1
			if sx != 0 then cleanTM.row1 = ax / sx else cleanTM.row1 = ax
			if sy != 0 then cleanTM.row2 = ay / sy else cleanTM.row2 = ay
			if sz != 0 then cleanTM.row3 = az / sz else cleanTM.row3 = az
			cleanTM.row4 = tm.row4

			-- Преобразуем в кватернион
			local q = cleanTM.rotation as quat

			-- Выравниваем кватернион по направлению (чтобы q и -q не мешали)
			if qSum.w != 0 and q.w * qSum.w < 0 then q = -q
			qSum += q
		)

		-- Усредняем позицию, масштаб и вращение
		avgPos /= matrixArray.count
		avgScaleX /= matrixArray.count
		avgScaleY /= matrixArray.count
		avgScaleZ /= matrixArray.count
		local avgQuat = normalize qSum

		-- Собираем итоговую матрицу
		local resultTM = avgQuat as matrix3  -- чистое вращение

		-- Применяем масштаб с знаком: умножаем каждую ось итогового вращения на средний масштаб (включая минус)
		-- Так мы сохраняем отражения (например, отзеркаливание по X)
		resultTM.row1 *= avgScaleX
		resultTM.row2 *= avgScaleY
		resultTM.row3 *= avgScaleZ

		-- Устанавливаем позицию
		resultTM.row4 = avgPos

		return resultTM
	)
	
    rollout rotDialog "ModContext TM Transformer" width:200
    (
        button btResetPosition "Reset Position" width:180
        button btResetRotation "Reset Rotation" width:180
        button btnFinish "Finish" width:180

        on btResetPosition pressed do (
			-- Вычисляем усредненную позицию
			local collectionNodeTM = for nd in targetNodes collect nd.transform
			local newTM = gizmoHelper.transform
			avg = averageTransforms collectionNodeTM
			newTM.position = avg.position
			gizmoHelper.transform = newTM
			redrawViews()
        )
        
        on btResetRotation pressed do (
			local newTM = gizmoHelper.transform
			local stored_pos = newTM.pos
			newTM.rotation = quat 0 0 0 1e
			newTM.pos = stored_pos
			gizmoHelper.transform = newTM
			redrawViews()
        )
        
        on btnFinish pressed do (
            -- Отключаем when-обработчик
            if transformWhenHandle != undefined do (
				deleteChangeHandler transformWhenHandle
				transformWhenHandle == undefined
			)
            -- Возвращаем выделение на исходный объект и модификатор
			targetNodes = (for obj in targetNodes where isValidNode obj collect obj)
			select targetNodes
			if targetNodes.count == 1 then modPanel.setCurrentObject targetMod node:targetNodes[1]
            if isValidNode gizmoHelper do (
				delete gizmoHelper
				gizmoHelper = undefined
			)
            destroyDialog rotDialog
        )
		
		on rotDialog close do (
			try (
				if isValidNode gizmoHelper do (
					btnFinish.pressed()
				)
			) catch ()
		)
    )
    
    on isEnabled return (modPanel.getCurrentObject() != undefined and finditem enabledOnMods (classOf (modPanel.getCurrentObject())) )
    
    on execute do (
		targetMod = modPanel.getCurrentObject()
        targetNodes = for obj in selection where finditem obj.modifiers targetMod collect obj
        if targetMod == undefined or targetNodes.count == 0 do (
			return false
		)
        
		-- Определяем, является ли модификатор bbox-модификатором
		local isBBoxMod = (finditem bbox_modifiers (classOf targetMod) > 0)
		
		-- Для bbox-модификаторов вычисляем центр bbox
		local bboxCenterOffset = if isBBoxMod then (
			averageBBoxCenter targetNodes targetMod
		) else ([0,0,0])

		-- определяем размер коробки
		local boxsize = case of (
			(finditem gizmo_project_modifiers (classOf targetMod) > 0): (
					if targetMod.maptype == 0 then [targetMod.width, targetMod.length, 0]
					else [targetMod.width, targetMod.length, targetMod.height]
				)
			(finditem bbox_modifiers (classOf targetMod) > 0): averageBBoxSize targetNodes targetMod
			(finditem gizmo_slice_modifiers (classOf targetMod) > 0): (
					case units.SystemType of (
						#meters: [1,1,0]
						#millimeters: [1000,1000,0]
						#inches: [39.37,39.37,0]
					)
				)
		)

		-- контекстная матрица трансформация модификатора
		local gizmoTM = getGizmoTM targetMod 

        -- Создаем dummy с размерами гизмо UVWMap
        gizmoHelper = dummy name:"ModContextGizmoHelper" boxsize:boxsize
        gizmoHelper.wirecolor = color 255 0 0
		
		-- Вычисляем усредненную позицию гизмо с учетом bbox
		local collectionGlobalTransforms = for nd in targetNodes collect (
			local contextTM = getModContextTM nd targetMod
			local nodeTM = nd.transform
			local pivotOffsetTM = (scaleMatrix nd.objectOffsetScale) * (nd.objectOffsetRot as Matrix3) * (transMatrix nd.objectOffsetPos)
			-- Для bbox-модификаторов учитываем центр bbox
			if isBBoxMod then gizmoTM.position += bboxCenterOffset
			gizmoTM * inverse(contextTM) * pivotOffsetTM * nodeTM
		)
        
		gizmoHelper.transform = averageTransforms collectionGlobalTransforms
        select gizmoHelper

        -- Регистрируем when-обработчик для отслеживания изменений трансформации
        transformWhenHandle = when transform gizmoHelper changes do (
            onTransformChanged gizmoHelper
        )
        
        -- Создаем немодальный диалог
        createDialog rotDialog style:#(#style_titlebar, #style_border, #style_sysmenu)
    )
	
) -- end macroscript