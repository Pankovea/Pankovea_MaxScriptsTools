/* @Pankovea Scripts - 2024.12.17
InstanceAll: Скрипт для замены объектов инстансами и рефернесами

Возможности:
* Замена любого объекта инстансом выбранного объекта
путём создания инстанса и применения исходных трансформаций, слоя, и материала в зависимости от настроек.
То есть, если были выделены часть инстансов, то невыделенная чать заменена не будет.

* При замене большого количества объектов (>100) отображается прогресс бар

1. Группа Make Instances
* Может клонировать инстансом как отжельные обекты, так и сгруппированные объекты
* Может подогнать размер нового инстанса под размер заменяемых обхектов

2. Группа Get instance part from refetence object
Извлекает базовый объект (нижний в теке модификаторов) и заменяет им выделенные объекты.
При этом не создаётся новых объектов и все зависимоти в сцене сохраняются.
* Так же может заменить весь стек модификаторов

--------
InstanceAll: Script for replacing objects with instances and references

Features:
* Replacing any object with an instance of the selected object
by creating an instance and applying the original transformations, layer, and material, depending on the settings.
That is, if some instances were selected, then the unselected part will not be replaced.

* When replacing a large number of objects (>100), the progress bar is displayed

1. Make Instances Group
* Can clone both individual objects and grouped objects by instance
* Can adjust the size of the new instance to the size of the objects being replaced

2. The Getinstance part from reference object group
Retrieves the base object (the bottom one in the modifier stack) and replaces the selected objects with it.
At the same time, no new objects are created and all dependencies in the scene are saved.
* Can also replace the entire modifier stack
*/

macroScript Pankov_InstanceAll
category:"#PankovScripts"
buttontext:"InstanceAll"
tooltip:"Instance objects or groups, reference base object"
icon:#("pankov_instancseAll",1)
(
	local version = "1.02"
	local ini_file = getmaxinifile()
	local ini_section = "Pankov_InstanceAll_" + version
	local main_obj = undefined
	global Pankov_InstanceAll
	
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

	
	rollout Pankov_InstanceAll ("Instance All " + version)
	(
		--------------
		-- FUNCTIONS
		--------------
		
		fn addNodeIerarchyToLayer obj layer = (
			layer.addNode obj
			for child in obj.children do addNodeIerarchyToLayer child layer
		)
		
		fn clearDeadNodes array = (
			if array.count != 0 do (for i = array.count to 1 by -1 where not isValidNode array[i] do deleteItem array i)
			return array
		)
		
		fn isEqualListObjects a b = (
			-- Used to compare the list of the reference nodes for the modifier in the next function
			if a.count != b.count then return false
			for i in 1 to a.count do if a[i] != b[i] then return false
			return true
		)

		fn getBaseInstanceModifiersCount obj = (
			local count = 0
			if obj.modifiers.count > 0 then (
				-- Collect only those modifiers on which the same objects depend as on the base object
				for i in obj.modifiers.count to 1 by -1 do (
					if isEqualListObjects (refs.dependentNodes obj.baseobject) (refs.dependentNodes obj.modifiers[i]) then count += 1 else break
				)
			)
			return count
		)
		

		--------------
		-- Interface
		--------------
		
		group "Main object:" (
			pickbutton pick_main "Pick the main object" toolTip:"" width:130
			label main_name "mode: Obj/Group"
		)

		on pick_main picked obj do (
			if isGroupMember obj and isGroupHead obj.parent and not isOpenGroupHead obj.parent then (
				if queryBox "Pick the Group header?" then 
					while obj.parent != undefined and isGroupHead obj.parent and not isOpenGroupHead obj.parent do obj = obj.parent
			)
			if isGroupHead obj then (
				main_name.text = "Group mode"
				Pankov_InstanceAll.go_ref.enabled = false
				Pankov_InstanceAll.lbl3.caption = "! Works only in object mode"
			) else (
				main_name.text = "Object mode"
				Pankov_InstanceAll.go_ref.enabled = true
				Pankov_InstanceAll.lbl3.caption = "from reference object"
			)
			Pankov_InstanceAll.go_inst.enabled = true
			pick_main.text = obj.name
			cur_sel = #() + selection
			select obj
			completeRedraw() 
			sleep 0.15
			select cur_sel
			if cur_sel.count == 0 then deselect obj
			main_obj = obj
		)
		
		
		group "Make instances" (
			label lbl1 "will create new nodes"
			checkbox chk_replace "and replace old objects" checked:true	
			label lbl2 "and keep old objects params:"
			
			radioButtons rad_pos_type "Position" labels:#("Pivot pos", "Center pos") default:1 columns:2 align:#left
			
			radioButtons rad_scale_type "Scale" labels:#("off", "obj", "fit") default:2 columns:3 align:#left
			checkbox chk_rotation "Rotation" checked:true
			
			checkbox chk_material "Material" checked:true offset:[0,10] across:2
			checkbox chk_wire_col "Wirecolor" checked:true offset:[0,10]
			checkbox chk_layer "Layer and group" checked:true

			button go_inst "[ make instances ]" width:130 enabled:false
		)
		
		on rad_scale_type changed state do (
			case state of (
				3: Pankov_InstanceAll.rad_pos_type.state = 2
			)
		)
		
		on go_inst pressed do (
			if not isValidNode main_obj then (
				messagebox "no main object picked"
			) else (
				obj_list = #() + selection
				old_objects = for obj in selection where findItem obj_list obj.parent == 0 collect obj
				if old_objects.count > 100 then local use_progress = true else local use_progress = false
				if old_objects.count>0 then (
					undo on (
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
								if old_obj.target == undefined then (
									if chk_rotation.checked == true do ( n.rotation = old_obj.rotation )
								)
								case rad_scale_type.state of (
									2: n.scale = old_obj.scale
									3: scale n ((old_obj.max - old_obj.min) / (n.max - n.min))
								)
							) else (
								if old_obj.target == undefined then (
									n.targeted = false
									if chk_rotation.checked == true do ( n.rotation = old_obj.rotation )
								) else (
									-- locate target
									if chk_rotation.checked == true do ( n.target.rotation = old_obj.target.rotation )
									n.target.position = old_obj.target.position
									-- scale object
									if rad_scale_type.state == 2 do ( n.scale = old_obj.scale )
								)
							)
							case rad_pos_type.state of (
								1: n.position = old_obj.position
								2: (old_center_pos = old_obj.max - (old_obj.max - old_obj.min)
									new_center_pos = n.max - (n.max - n.min)
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
								) else (
									delete old_obj.children
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
					)
				) else (
					messagebox "No valid selection for replace"
				)
			)
		)

		group "Get instance part" (
			label lbl3 "from reference object"
			label lbl4 "and replace base object"
			checkbox replace_modifiers "Replace modifiers too" checked:true tooltip:"When turned off, only the base object will be replaced, and the stack of modifiers will remain in place" enabled:true
			button go_ref "[ replace base object ]" width:130 enabled:true
		)
		
	
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
					undo on (
						if use_progress then (
							setWaitCursor()
							progressStart ("Creating References...")
							local evaluted_count = 0
						)
						try (
							disableSceneRedraw()
							suspendEditing()
							for target_obj in target_objects do (
								if replace_modifiers.checked then (
									local baseInstanceModifiersCount = getBaseInstanceModifiersCount main_obj
								)
								
								-- reference base object to target
								target_obj.baseobject = main_obj.baseobject
								
								-- clear old modifiers stack
								if replace_modifiers.checked do for i in 1 to target_obj.modifiers.count do deleteModifier target_obj 1
								
								-- move modifiers to target object
								if replace_modifiers.checked then (
									for i in 1 to baseInstanceModifiersCount do (
										local current_mod = main_obj.modifiers[main_obj.modifiers.count-i+1]
										addModifierWithLocalData target_obj current_mod main_obj current_mod
										deleteModifier main_obj main_obj.modifiers[main_obj.modifiers.count-i]
									)
								)
								
								if use_progress then (
									progressUpdate (100 * evaluted_count / (target_objects.count + 1) )
									evaluted_count += 1
								)
							)
							resumeEditing()
							enableSceneRedraw()
							if use_progress then (
								progressEnd()
								setArrowCursor()
							)
						) catch (
							resumeEditing()
							enableSceneRedraw()
							if use_progress then (
								progressEnd()
								setArrowCursor()
							)
						)
						
						if clear_main_obj_arter_all then (
							append target_objects main_obj
							select target_objects
							main_obj = undefined
						) else (
							select target_objects
						)
						completeredraw()
					)
				) else (
					messagebox "No valid selection for reference.\nThe base objects in the selection must be of the same superclass as the main object"
				)
			)
		)
		
		button btn_save_defaults "Save settings"
		
		on btn_save_defaults pressed do (
			saveDefaultsToINI ini_file ini_section #("Pankov_InstanceAll")
		)

		on Pankov_InstanceAll close do (
			setIniSetting ini_file ini_section "WindowPos" (GetDialogPos Pankov_InstanceAll as string)
		)
		
		HyperLink link_copyright "PankovEA @ Github" align:#center hovercolor:(color 255 133 85) color:(color 85 189 255) visitedColor:(color 155 17 6) address:"https://github.com/Pankovea/Pankovea_MaxScriptsTools"
	)
	
	on execute do (
		pos = getinisetting ini_file ini_section "WindowPos"
		if pos!="" then CreateDialog Pankov_InstanceAll pos:(execute pos) else CreateDialog Pankov_InstanceAll
		loadDefaultsFromINI ini_file ini_section
	)
)
