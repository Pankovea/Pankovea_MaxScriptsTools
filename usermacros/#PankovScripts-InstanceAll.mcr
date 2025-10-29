/* @Pankovea Scripts - 2025.10.20
InstanceAll: Скрипт для замены объектов инстансами и рефернесами

Возможности:
* Замена любого объекта инстансом выбранного объекта
путём создания инстанса и применения исходных трансформаций, слоя, и материала в зависимости от настроек.
То есть, если были выделены часть инстансов, то невыделенная чать заменена не будет.

* Замена референс части объекта с возможность выбора уровня исходного референса

* При замене большого количества объектов (>100) отображается прогресс

Пдробнее:
1. Группа Make Instances
* Может клонировать инстансом как отдельные обекты, так и сгруппированные объекты
* Может подогнать размер нового инстанса под размер заменяемых обхектов

2. Группа Replace refetence target
Извлекает reference объект из выбранного и заменяет им указанный уровень в выделенных объектах.
Этот раздел работает только в объектном режиме (когда исходный объект является геометрией, но не группой)

Если выделен один объект назначения, то предлагается выбрать место вставки
Если выделено несколько объектов, то можно выбрать:
* верхний слой (Top) - то есть заменить объект целиком. В таком случае невыделенные инстансные объекты не будут затронуты.
* инстансную часть (Instance part) - нижний уровень референса включая модификаторы до первого "отчерка". Может совпадать с базовым.
									В таком случае все объекты, ссылающиеся на данную часть будут изменены.
* базовый объект (Base object) - заменяется только первая строка - базовый объект, на оснве которого строится стек можификаторов.
									В таком случае невыделенные инстансные объекты не будут затронуты.

!!! ВНИМАНИЕ !!!
Экспериментальная реализация.
При выделении объектов назначения другого типа от главного объекта 3dsmax может сломаться.
Нужно тестировать и добавлять проверки прежде замены.

--------
InstanceAll: Script for replacing objects with instances and references

Features:
* Replace any object with an instance of the selected object by creating an instance
  and applying original transforms, layer, and material according to the settings.
  Note: if only some instances were selected, unselected instance objects will not be replaced.

* Replace a reference part of an object with the ability to choose the source reference level.

* When replacing a large number of objects (>100), a progress bar is shown.

Details:

1. Make Instances group
* Can create instances of both individual objects and grouped objects.
* Can fit the new instance size to match the size of the objects being replaced.

2. Replace Reference Target group
Extracts a reference object from the chosen main object and replaces the specified reference level
in the selected objects. This section works only in object mode (when the source object is geometry,
not a group).

Behavior depending on selection:
* If a single destination object is selected, the script will prompt to choose the insertion level.
* If multiple destination objects are selected, you can choose:
  - Top layer (Top) — replace the whole object. In this case, unselected instance objects will not be affected.
  - Instance part (Instance part) — the lower reference level including modifiers up to the first "break".
    This may match the base level. In this case all objects referencing this part will be changed.
  - Base object (Base object) — replace only the base object (the first entry on which the modifier stack is built).
    In this case unselected instance objects will not be affected.

!!! WARNING !!!
Experimental implementation.
Selecting destination objects of a different type than the main object may cause 3ds Max to become unstable.
Test carefully and add validation checks before performing replacements.
*/

macroScript Pankov_InstanceAll
category:"#PankovScripts"
buttontext:"InstanceAll"
tooltip:"Instance objects or groups, reference base object"
icon:#("pankov_instancseAll",1)
(
	local version = "2.0"
	local ini_file = getmaxinifile()
	local ini_section = "Pankov_InstanceAll_" + version
	
	global Pankov_InstanceAll
	
	rollout Pankov_InstanceAll ("Instance All " + version)
	(
		--------------
		--( Variables
		--------------

		local main_obj = undefined
		local selectionChange_callbacksId = #Pankov_InstanceAll_selectionChange

		--) end Variables
		
		--------------
		--( FUNCTIONS
		--------------
			
		--( -- reference help functions
		fn getRefsStack objSub recourse_result:#() = (
			-- return array of reference object (DerivedObject or SingleObject like box, Editable Poly or any other)
			/* пример вывода
			Каждый элемент можно использовать для замены референса в другом объекте
			#(
				Modified_Object, -- TurboSmooth, Mirror, Modified_Object
				Modified_Object, -- Shell, Slice, Modified_Object
				Modified_Object, -- TurboSmooth, FFD_4x4x4, Box__Object
				Box__Object -- base_object
			)
			*/
			if isvalidnode objSub do objSub = objSub[4]
			if classof objSub == SubAnim do objSub = objSub.object
			append recourse_result objSub
			if superclassOf objSub == GenDerivedObjectClass do (
				local modifiedObjSub = objSub
				
				local base_obj
				i = 1
				while modifiedObjSub[i] != undefined do (
					base_obj = modifiedObjSub[i].object
					i += 1
				)
				getRefsStack base_obj recourse_result:recourse_result
			)
			
			return recourse_result
		)

		fn check_ref nd = (
			-- возвращает "copy", "instance" или "reference"
			refsStack = getRefsStack nd[4]
			local dependentnodes_counts = for derived_obj in refsStack collect (
				(refs.dependentNodes derived_obj).count
			)
			local dependentnodes_counts = for derived_obj in refsStack collect (refs.dependentNodes derived_obj).count
			local unique_counts = makeUniqueArray dependentnodes_counts
			if unique_counts.count == 1 and unique_counts[1] == 1 then return "copy"
			if unique_counts.count == 1 then return "instance"
			if unique_counts.count > 1 then return "reference"
		)

		fn isReference nd = (check_ref nd) == "reference"
		fn isInstance nd = (check_ref nd) == "instance"

		fn getInstancePartOfRef_index nd refsStack:undefined = (
			-- возвращает индекс Insatnce часть объекта в списке RefsStack
			if refsStack == undefined do
				refsStack = getRefsStack nd
			local dependentnodes_counts = for derived_obj in refsStack collect (
				(refs.dependentNodes derived_obj).count
			)
			local i = dependentnodes_counts.count
			local cur_count = dependentnodes_counts[i]
			while (i-1) > 0 and cur_count == dependentnodes_counts[i-1] do i -= 1
			return i
		)
		
		fn getInstancePartOfRef nd = (
			-- возвращает insatnce часть объекта (DerivedObject)
			local refsStack = getRefsStack nd
			i = getInstancePartOfRef_index nd refsStack:refsStack
			return refsStack[i]
		)
		--) -- reference help functions

		
		--( -- Callback при обновлении выделения
		local callbackId = #Pankov_InstanceAll -- id функции обработки изменения выделения
		
		fn unregister_callbacks = (
			-- отмена регистрации callback-обработчика для отслеживания изменения выделения
			callbacks.removeScripts id:callbackId
		)
		
		fn register_callbacks = (
			-- Регистрация callback-обработчика для отслеживания изменения выделения
			unregister_callbacks()
			callbacks.addScript #selectionSetChanged "Pankov_InstanceAll.updateTargetRefList()" id:callbackId
			callbacks.addScript #postModifierAdded "Pankov_InstanceAll.updateRefLists()" id:callbackId
			callbacks.addScript #postModifierDeleted "Pankov_InstanceAll.updateRefLists()" id:callbackId
		)
		
		fn get_ref_target_levels_content nd = (
			-- возвращает список строк с содержанием уровней референса в стеке модификторов
			local refsStack = getRefsStack nd
			for indx_ref in 1 to refsStack.count collect (
				local ref_str = (indx_ref as string) + ": "
				local i = 1
				local ref = refsStack[indx_ref]
				if superclassof ref == GenDerivedObjectClass then (
					while ref[i] != undefined do (
						if superclassof ref[i].object != GenDerivedObjectClass then (
							if i > 1 do ref_str += ", "
							ref_str += ref[i].name
						)
						i += 1
					)
				) else (
					ref_str += ref as string + " (base)"
				)
				ref_str
			)
		)
		
		fn set_ui_target_levels nd:undefined = (
			arr = case of (
				(classof nd == array): nd
				(isvalidnode nd): get_ref_target_levels_content nd
				default: #()
			)
			Pankov_InstanceAll.lbx_target_levels.items = arr
			Pankov_InstanceAll.lbx_target_levels.selection = case of (
				(arr.count == 0): 0
				(isvalidnode nd): getInstancePartOfRef_index nd
				default: 2
			)
			Pankov_InstanceAll.go_ref.enabled = (arr.count != 0)
		)

		
		fn updateTargetRefList = ( -- callback function
			if Pankov_InstanceAll != undefined and Pankov_InstanceAll.visible do (
				lbx = Pankov_InstanceAll.lbx_target_levels
				set_ui_target_levels nd:(
					case of (
						(selection.count == 0): #()
						(selection.count == 1 and isvalidnode selection[1]): (
								if selection[1] == main_obj then #() else selection[1]
							)
						(selection.count > 1): (
								if (finditem (selection as array) main_obj) == 0 then (
									#("^ Top ^", "-= Instance part =-", "v Base object v")
								) else (
									#()
								)
							)
					)
				)
			)
		)

		fn updateRefLists = ( -- callback function
			if Pankov_InstanceAll != undefined and Pankov_InstanceAll.visible do (
				updateTargetRefList ()
				lbx = Pankov_InstanceAll.lbx_main_levels
				if isvalidnode main_obj then (
					lbx.items = get_ref_target_levels_content main_obj
				) else (
					lbx.items = #()
				)
			)
		)
		
		--) -- Callback

		
		--( -- Другие вспомогательные функции
		
		-- добавляет объект вместе с его пдетьми в слой
		fn addNodeIerarchyToLayer obj layer = (
			layer.addNode obj
			for child in obj.children do addNodeIerarchyToLayer child layer
		)
		
		-- Очищает массив от удалённых нод
		fn clearDeadNodes arr = (
			if arr.count != 0 do (for i = arr.count to 1 by -1 where not isValidNode arr[i] do deleteItem arr i)
			return arr
		)
		
		-- Функция для определения номеров осей для максимального и минимального размера
		fn getAxisIndices source = (
			-- Получаем размер объекта в локальных осях
			local store_source_tm = source.transform
			source.rotation = quat 0 0 0 1
			local source_size = source.max - source.min
			source.transform = store_source_tm
			-- Сортируем размеры
			local source_size_arr = #(source_size.x, source_size.y, source_size.z)
			local sorted = sort (copy source_size_arr #noMap)
			-- ищем индекс сортированных размеров в соответсующем порядке
			local longAxis = finditem source_size_arr sorted[3]
			local midAxis  = finditem source_size_arr sorted[2]
			local shortAxis = finditem source_size_arr sorted[1]
			return #(longAxis, midAxis, shortAxis)
		)
		
		-- Функция выравнивания поворота исходного объекта по целевому используя длинные и короткие стороны
		fn rotateFit source target tInfo:undefined =
		(
			-- 1. Определяем порядок осей по размеру для каждого из объектов
			local sInfo = getAxisIndices source
			if tInfo == undefined do -- передаётся в случае если стары обхект был заменён и нужно выровнять по старой его форме.
				tInfo = getAxisIndices target

			-- 2. Собираем новые оси для source с исходным масштабом 
			local newRows = #()
			newRows[sInfo[1]] = normalize(target.transform[tInfo[1]]) * source.transform.scale[sInfo[1]]
			newRows[sInfo[2]] = normalize(target.transform[tInfo[2]]) * source.transform.scale[sInfo[2]]
			newRows[sInfo[3]] = normalize(target.transform[tInfo[3]]) * source.transform.scale[sInfo[3]]

			-- 3. Применяем
			source.transform = matrix3 newRows[1] newRows[2] newRows[3] source.pos
		)
		--)

		
		--( -- Settings INI Functions
		fn saveDefaultsToINI fname ini_section roll_list exclude_list:#() = (
			local ctrlName = ""
			for roll in roll_list do (
				for ctrl in (execute (roll+".controls")) do (
					ctrlName = (substring (ctrl as string) ((findstring (ctrl as string) ":")+1) 100)
					if (findItem exclude_list ctrlName)==0 then (
						ctrlData = case (classof ctrl) of (
							SpinnerControl:		#(#value, ctrl.value)
							CheckBoxControl:	#(#state, ctrl.state)
							CheckButtonControl:	#(#state, ctrl.state)
							RadioControl:		#(#state, ctrl.state)
							editTextControl:	#(#text,"\\\""+ctrl.text+"\\\"")
							SliderControl:		#(#range, ctrl.range)
						)
						if ctrlData != undefined then setIniSetting fname ini_section (roll+"."+ctrlName) (ctrlData as string)
					)
				)
			)
		)

		fn loadDefaultsFromINI fname ini_section exclude_list:#() = (
			local data
			local str
			if doesFileExist fname then (
				for ctrl in (getIniSetting fname ini_section) do (
					dot_pos = findstring ctrl "."
					if dot_pos != undefined and finditem exclude_list (substring ctrl (dot_pos+1) 100) == 0 then (
						data = execute (getIniSetting fname ini_section ctrl)
						if data!="" then execute (ctrl+"."+(data[1] as string)+"="+(data[2] as string))
					)
				)
			)
		)
		--) -- Settings INI Functions

		
		--) -- end Functions
	
		--------------
		--( Interface
		--------------
		
		group "Main object:" (
			pickbutton pick_main "Pick the main object" toolTip:"" width:130
			label main_name "mode: Obj/Group"
		)

		group "Make instances" (
			label lbl1 "will create new nodes"
			checkbox chk_replace "and replace old objects" checked:true	
			label lbl2 "and keep old objects params:"
			
			radioButtons rad_pos_type "Position" labels:#("Pivot pos", "Center pos") default:1 columns:2 align:#left
			
			radioButtons rad_rot_type "Rotation" labels:#("main", "target", "fit") default:2 columns:3 align:#left
			radioButtons rad_scale_type "Scale" labels:#("main", "target", "fit") default:1 columns:3 align:#left
			
			--checkbox chk_rotation "Rotation" checked:true
			
			checkbox chk_material "Material" checked:false offset:[0,10] across:2
			checkbox chk_wire_col "Wirecolor" checked:true offset:[0,10]
			checkbox chk_layer "Layer and group" checked:true

			button go_inst "[ make instances ]" width:130 enabled:false
		)
		
		group "Replace reference target" (
			checkbutton btn_show_main_obj "show Main object"
			listBox lbx_main_levels "Main obj Level" height:5
			
			listBox lbx_target_levels "Target obj Level" height:5
			button go_ref "[ replace object ]" width:130 enabled:true
		)
		
		--) end interface
		
		------------------------------
		--( group "Main object"
		------------------------------
		
		on pick_main picked obj do (
			if isGroupMember obj and isGroupHead obj.parent and not isOpenGroupHead obj.parent then (
				--if queryBox "Pick the Group header?" then 
					while obj.parent != undefined and isGroupHead obj.parent and not isOpenGroupHead obj.parent do obj = obj.parent
			)
			main_obj = obj
			if isGroupHead obj then (
				main_name.text = "Group mode"
				Pankov_InstanceAll.go_ref.enabled = false
				unregister_callbacks()
			) else (
				main_name.text = "Object mode"
				lbx_main_levels.items = get_ref_target_levels_content obj
				lbx_main_levels.selection = 1
			)
			Pankov_InstanceAll.go_inst.enabled = true
			pick_main.text = obj.name
			cur_sel = selection as array
			select obj
			completeRedraw() 
			sleep 0.15
			if not isGroupHead obj then (
				register_callbacks() -- регистрируем событие обновления выделения после отображения выделенного
			)
			if cur_sel.count == 0 then deselect obj else select cur_sel
		)
		
		--) end main object goup
		
		------------------------------
		--( group "Make instances"
		------------------------------
		
		on rad_scale_type changed state do (
			case state of (
				3: (Pankov_InstanceAll.rad_pos_type.state = 2
					Pankov_InstanceAll.rad_rot_type.state = 3
				)
			)
		)
		
		on rad_scale_type changed state do (
			case state of (
				3: (Pankov_InstanceAll.rad_pos_type.state = 2
					Pankov_InstanceAll.rad_rot_type.state = 3
				)
			)
		)
		
		local cur_sel
		on btn_show_main_obj changed state do (
			if state then (
				if isvalidnode main_obj do (
					Pankov_InstanceAll.cur_sel = selection as array
					select main_obj
				)
			) else (
				if Pankov_InstanceAll.cur_sel.count == 0 then
					deselect main_obj
				else select cur_sel
			)
		)
		
		on go_inst pressed do (
			if not isValidNode main_obj then (
				messagebox "no main object picked"
			) else (
				obj_list = selection as array
				old_objects = for obj in selection where findItem obj_list obj.parent == 0 collect obj
				main_parent_scale = if main_obj.parent != undefined then main_obj.parent.scale else [1,1,1]
				if old_objects.count > 100 then local use_progress = true else local use_progress = false
				if old_objects.count>0 then (
					undo on (
						-- выясняем, можем ли мы просто заменить ссылку внутри существующего объекта
						-- формируется список суперклассов objlist, которые не соответвуют main_obj. Список должен быть пустым
						local wrong_super_classes = makeuniquearray (for obj in obj_list where (superclassof obj) != (superclassof main_obj) collect true)
						if (
							chk_replace.checked \   -- replace object checked
							and not isgrouphead main_obj \ -- main_obj is not group
							and wrong_super_classes.count == 0 \ -- класс obj_list соответсвует main_obj
						) then (
							inst_derivedObj = main_obj[4].object
							for old_obj in old_objects do (
								-- сохраняем параметры для дальнейшего восстановления
								local old_size = (old_obj.max - old_obj.min)
								local old_center_pos = old_obj.max - old_size / 2
								local old_tinfo = getAxisIndices old_obj
								
								-- главная операция замены
								refs.replaceReference old_obj 2 inst_derivedObj
								notifydependents inst_derivedObj
								local new_obj = old_obj

								-- Скопируем смещение пивота
								new_obj.objectOffsetScale = main_obj.objectOffsetScale
								new_obj.objectOffsetRot = main_obj.objectOffsetRot
								new_obj.objectOffsetPos = main_obj.objectOffsetPos
								
								-- настройка параметров
								case rad_rot_type.state of (
									1: (new_obj.transform *= inverse(transMatrix new_obj.position) \ -- позицию в ноль
										* (new_obj.rotation as matrix3) \ -- вращение в ноль
										* inverse(main_obj.rotation as matrix3) \ -- применить новое вращение
										* (transMatrix new_obj.position) -- вернуть старую позицию
									)
									2: "pass"
									3: rotateFit new_obj old_obj tinfo:old_tinfo
								)
								case rad_scale_type.state of (
									1: new_obj.scale = main_obj.scale
									3: scale new_obj (old_size / (new_obj.max - new_obj.min))
								)
								if rad_pos_type.state == 2 do (
									local new_center_pos = new_obj.max - (new_obj.max - new_obj.min) / 2
									new_obj.position += old_center_pos - new_center_pos
								)
								if not chk_material.checked do new_obj.material = main_obj.material
								if not chk_wire_col.checked do new_obj.wirecolor = main_obj.wirecolor
								if not chk_layer.checked do new_obj.layer = main_obj.layer
								
								if main_obj.target != undefined do (
									if new_obj.target == undefined then (
										new_obj.target.transform = main_obj.target.transform
									) else (
										new_target = dummy()
										new_target.wirecolor = new_obj.wirecolor
										new_target.layer = new_obj.layer
										new_target.name = new_obj.name + ".Target"
										new_target.transform = main_obj.target.transform
									)
								)
								-- update modifier stack and views
								deselect $*
								select old_objects
								completeredraw()
							)
						) else (
						-- create instance
							local new_objects = #()
							
							if use_progress then (
								setWaitCursor()
								progressStart ("Creating Instances...")
								local evaluted_count = 0
							)
							
							for old_obj in old_objects do (
								if isgrouphead main_obj then (
									-- Instance groups with the objects ierarchy
									maxops.cloneNodes main_obj clonetype:#instance newnodes:&instobj -- actualNodelist:&oldobj offset:[50,0,0]
									n = instobj[1]
									if (isGroupMember n) then (detachNodesFromGroup n)
								) else (
									n = instance(main_obj)
								)
								
								append new_objects n
								
								if chk_replace.checked == true do n.name = old_obj.name
								
								if chk_wire_col.checked then 
									(n.wirecolor = old_obj.wirecolor)
								else (n.wirecolor = main_obj.wirecolor)
									
								if main_obj.target != undefined then (
									n.target = instance(main_obj.target)
									if chk_wire_col.checked then n.target.wirecolor = main_obj.target.wirecolor
								)
								
								-- locate new object
								-- If obj have a target
								if n.target == undefined then (
									if old_obj.target == undefined do (
										case rad_rot_type.state of (
											2: (n.rotation = old_obj.rotation)
											3: rotateFit n old_obj
										)
									)
									case rad_scale_type.state of (
										2: n.scale = old_obj.scale * main_parent_scale
										3: scale n ((old_obj.max - old_obj.min) / (n.max - n.min))
									)
								) else (
									if old_obj.target == undefined then (
										n.targeted = false
										case rad_rot_type.state of (
											2: (n.rotation = old_obj.rotation)
											3: rotateFit n old_obj
										)
									) else (
										-- locate target
										if rad_rot_type.state != 1 do ( n.target.rotation = old_obj.target.rotation )
										n.target.position = old_obj.target.position
										-- scale object
										if rad_scale_type.state == 2 do ( n.scale = old_obj.scale * main_parent_scale )
									)
								)
								case rad_pos_type.state of (
									1: n.position = old_obj.position
									2: (old_center_pos = old_obj.max - (old_obj.max - old_obj.min)/2
										new_center_pos = n.max - (n.max - n.min)/2
										n.position += old_center_pos - new_center_pos
									)
								)
								
								-- If old_obj is in group
								if chk_layer.checked and old_obj.parent != undefined then (
									if isGroupHead old_obj.parent then (
										if isGroupMember n then detachNodesFromGroup n
										attachNodesToGroup n old_obj.parent
									) else (
										n.parent = old_obj.parent
										if isGroupMember old_obj then setGroupMember n true
									)
								)
								
								-- assign children from old to new onject
								if not isgrouphead main_obj then (
									if not isGroupHead old_obj then (
										for obj in old_obj.children do (
											obj.parent = n
										)
									)
								)
								
								-- Replace material
								if chk_material.checked then (
									n.material = old_obj.material
									if old_obj.children.count == 0 then (
										for child in n.children do child.material = old_obj.material
									) else (
										local mats = for obj in old_obj.children collect obj.material
										if old_obj.material==undefined then n.material = mats[1]
										for i in 1 to n.children.count do n.children[i].material = mats[(mod (i-1) mats.count)+1]
									)
								)

								-- Replace layer
								if chk_layer.checked then layer = old_obj.layer
													 else layer = main_obj.layer
								addNodeIerarchyToLayer n layer
								
								if use_progress then (
									progressUpdate (100 * evaluted_count / (old_objects.count + 1) ) 
									evaluted_count += 1
								)
								
								if (not isgrouphead main_obj) and (isGroupHead old_obj) and chk_replace.checked then (
									delete old_obj.children
								)
							)
							
							if chk_replace.checked == true do (
								old_objects = clearDeadNodes old_objects
								delete old_objects
							)
							
							select new_objects
							
							if use_progress then (
								progressEnd()
								setArrowCursor()
							)
							
							completeredraw()
						) -- end else block
					) -- end undo block
				) else (
					messagebox "No valid selection for replace"
				)
			)
		)

		--) end Make instances group
		------------------------------
		
		-----------------------------------------
		--( group "Replace reference target" (
		-----------------------------------------		
	
		on go_ref pressed do (
			local work = false
			local clear_main_obj_arter_all = false
			sel = for obj in selection where not isgrouphead obj collect obj

			if not isValidNode main_obj then (
				case of (
					(sel.count == 0): messagebox "Select one or more objects"
					(sel.count == 1): ( 
						if queryBox "No main object picked.\nUse first object of selection as main object?" do (
							main_obj = sel[1]
							clear_main_obj_arter_all = true
							deselect; completeRedraw()
							sleep 0.5
							select main_obj; completeRedraw()
							sleep 1.5
							deselect
							deleteItem sel 1
						)
					)
					(sel.count > 1): (
						if queryBox "No main object picked.\nUse first object of selection as main object?" do (
							main_obj = sel[1]
							clear_main_obj_arter_all = true
							deleteItem sel 1
							work = true
						)
					)
				)
			) else (
				if sel.count == 0 then messagebox "Select one or more objects"
				else work = true
			)
			if work then (
				-- Collect only objects, not group heads and the same superclass of base object
				target_objects = for obj in sel where (superclassof obj.baseobject == superclassof main_obj.baseobject) collect obj
				
				if target_objects.count > 100 then local use_progress = true else local use_progress = false
				if target_objects.count > 0 then (
					local DependencyLoop_objects = #()
					local Error_objects = #()
					undo "Replace references" on (
						if use_progress then (
							setWaitCursor()
							progressStart ("Creating References...")
							local evaluted_count = 0
						)
						
						-- inst_derivedObj = getInstancePartOfRef main_obj
						local main_level = lbx_main_levels.selection
						local main_derivedObj = (getRefsStack main_obj)[main_level]
						
						for target_obj in target_objects do (
							-- выбираем объект для замены в соответсвии с настройками
							
							local target_derivedObj = if target_objects.count == 1 then (
								-- если единственный выделенный, то используем выдеоеный уровень
								(getRefsStack target_obj)[lbx_target_levels.selection] 
							) else (
								-- иначе смотрим настройку
								case lbx_target_levels.selection of (
									1: target_obj[4].object            -- Top level
									2: getInstancePartOfRef target_obj -- Instance Part
									3: target_obj.baseobject           -- Base object
									default: target_obj.baseobject
								)
							)
							
							dependecyTest = ((refs.DependencyLoopTest main_derivedObj target_derivedObj) \
											or refs.DependencyLoopTest target_derivedObj main_derivedObj)
							case of (
								(dependecyTest): append DependencyLoop_objects target_obj
								(target_derivedObj == target_obj.baseobject): target_obj.baseobject = main_derivedObj
								(target_derivedObj == target_obj[4].object): (
									refs.replaceReference target_obj 2 main_derivedObj
									notifydependents main_derivedObj
								)
								default: (
									-- Находим родителя instance-части (immediate dependant)
									local parents = refs.dependents target_derivedObj immediateOnly:true
									local parent = parents[1]  -- Обычно один immediate parent в стеке
									-- заменяем объект
									if isvalidnode parent then ( -- refs.dependents может вернуть ноду
										-- тогда эта нода содержит искомый объкт в baseobject
										parent.baseobject = main_derivedObj
									) else ( -- или ObRefModApp
										-- тогда нужно заменять через refs.replaceReference
										try (
											refs.replaceReference parent 1 main_derivedObj
											notifydependents main_derivedObj
										) catch (
											append Error_objects target_obj
										)
									)
								)
							)
						)
						
						updateTargetRefList()
						
						if use_progress then (
							progressEnd()
							setArrowCursor()
						)
							
						if clear_main_obj_arter_all then (
							append target_objects main_obj
							select target_objects
							main_obj = undefined
						) else (
							select target_objects
						)
						redrawviews()
					)
					
					if DependencyLoop_objects.count > 0 or Error_objects.count > 0 do (
						local query_text = "There were several skipped objects:"
						if DependencyLoop_objects.count > 0 do (
							query_text += "\n\nDependency Loop:"
							for obj in DependencyLoop_objects do (query_text += "\n" + obj.name)
						)
						if Error_objects.count > 0 do (
							query_text += "\n\nErrors on:"
							for obj in Error_objects do (query_text += "\n" + obj.name)
						)
						query_text += "\n\nAre you satisfied with the result?"
						if not (queryBox query_text) do max undo
					)
					
				) else (
					messagebox "No valid selection for reference.\nThe base objects in the selection must be of the same superclass as the main object"
				)
			)
		)
		
		--) end Replace reference target group
		------------------------------
		
		button btn_save_defaults "Save settings"
		
		on btn_save_defaults pressed do (
			saveDefaultsToINI ini_file ini_section #("Pankov_InstanceAll")
		)

		on Pankov_InstanceAll close do (
			-- Удаление callback-обработчика при закрытии окна
			unregister_callbacks()
			setIniSetting ini_file ini_section "WindowPos" (GetDialogPos Pankov_InstanceAll as string)
		)
		
		HyperLink link_copyright "PankovEA @ Github" align:#center hovercolor:(color 255 133 85) color:(color 85 189 255) visitedColor:(color 155 17 6) address:"https://github.com/Pankovea/Pankovea_MaxScriptsTools"
	)
	
	on execute do (
		pos = getinisetting ini_file ini_section "WindowPos"
		if pos!="" then CreateDialog Pankov_InstanceAll pos:(execute pos) else CreateDialog Pankov_InstanceAll
		Pankov_InstanceAll.loadDefaultsFromINI ini_file ini_section
	)
)
