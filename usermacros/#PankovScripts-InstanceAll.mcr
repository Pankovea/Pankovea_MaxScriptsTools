macroScript Pankov_InstanceAll
category:"#PankovScripts"
buttontext:"InstanceAll"
tooltip:"Instance objects or groups, reference base object"
icon:#("pankov_instancseAll",1)
(

	rollout Pankov_InstanceAll "Instance All 1.0" width:162 height:360
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
			global main_obj = obj
		)
		
		
		group "Make instances" (
			label lbl1 "will create new nodes"
			checkbox rep "and replace old objects" checked:true	
			label lbl2 "and keep old objects params:"
			
			checkbox pos "pos" checked:true enabled:false across:2
			checkbox wire_col "wirecolor" checked:true

			checkbox sca "scale" checked:true across:2
			checkbox mat "material" checked:true
			
			checkbox rot "rotation" checked:true across:2	
			checkbox lay "layer" checked:true
			
			button go_inst "[ make instances ]" width:130 enabled:false
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
							
							n.name = old_obj.name
							if wire_col.checked then 
								(n.wirecolor = old_obj.wirecolor)
							else (n.wirecolor = main_obj.wirecolor)
								
							if main_obj.target != undefined then (
								n.target = instance(main_obj.target)
								if wire_col.checked then n.target.wirecolor = main_obj.target.wirecolor
							)
							
							-- locate new object
							-- If obj have a target
							if n.target == undefined then (
								if old_obj.target == undefined then (
									if rot.checked == true do ( n.rotation = old_obj.rotation )
									if sca.checked == true do ( n.scale = old_obj.scale )
								) else (
									if sca.checked == true do ( n.scale = old_obj.scale )
								)
							) else (
								if old_obj.target == undefined then (
									n.targeted = false
									if rot.checked == true do ( n.rotation = old_obj.rotation )
									--if sca.checked == true do ( n.scale = old_obj.scale )
								) else (
									-- locate target
									if rot.checked == true do ( n.target.rotation = old_obj.target.rotation )
									n.target.position = old_obj.target.position
									-- scale object
									if sca.checked == true do ( n.scale = old_obj.scale )
								)
							)
							n.position = old_obj.position
							
							-- If old_obj is in group
							if old_obj.parent != undefined then (
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
							-- #FIXME not works with groups
							if not mat.checked then (
								n.material = old_obj.material
							)

							-- Replace layer
							if not lay.checked then (
								layer = old_obj.layer
								addNodeIerarchyToLayer n layer
							)
							
							if use_progress then (
								progressUpdate (100 * evaluted_count / (old_objects.count + 1) ) 
								evaluted_count += 1
							)
						)
					
						if isgrouphead main_obj then (
							setGroupOpen main_obj true
						)
						
						if rep.checked == true do (
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
			checkbox make_new "Make new object" checked:true tooltip:"Create new object instead use of selection. You get instance part of the reference object"
			checkbox replace_modifiers "Replace modifiers" checked:true tooltip:"When turned off, only the base object will be replaced, and the stack of modifiers will remain in place" enabled:false
			button go_ref "[ make references ]" width:130 enabled:true
		)
		
		on make_new changed checked do (
			replace_modifiers.enabled = not checked
			if checked then (
				replace_modifiers.checked = true
			)
		)
		
		on go_ref pressed do (
			local work = false
			if (not isValidNode main_obj) and (make_new.checked) then (
				if selection.count == 1 and not isgrouphead selection[1] then (
					main_obj = selection[1]
					work = true
				) else (
					messagebox "Select one object to get reference"
				)
			) else (
				if not isValidNode main_obj	then messagebox "No main object picked" else work = true
			)
			if work then (
				if make_new.checked then (
					target_obj = copy main_obj
					for i in 1 to target_obj.modifiers.count do deleteModifier target_obj 1
					if isgroupmember main_obj then (
						setGroupMember target_obj true
						setgroupopen target_obj.parent false
						setgroupopen target_obj.parent true
					)
					target_objects = #(target_obj)
				) else (
					-- Collect only objects, not group heads and the same superclass of base object
					target_objects = for obj in selection where not (isGroupHead obj) and (superclassof obj.baseobject == superclassof main_obj.baseobject) collect obj
				)
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

						select target_objects 
						completeredraw()
					)
				) else (
					messagebox "No valid selection for reference.\nThe base objects in the selection must be of the same superclass as the main object"
				)
			)
		)

		on Pankov_InstanceAll close do (
			setIniSetting (getmaxinifile()) "Pankov_InstanceAll" "WindowPos" (GetDialogPos Pankov_InstanceAll as string)
		)
	  
	)

	on execute do
	(
		pos = getinisetting (getmaxinifile()) "Pankov_InstanceAll" "WindowPos"
		if pos!="" then CreateDialog Pankov_InstanceAll pos:(execute pos) else CreateDialog Pankov_InstanceAll
		global main_obj = undefined
	)
)
