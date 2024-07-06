macroScript Pankov_InstanceAll
category:"#PankovScripts"
buttontext:"InstanceAll"
tooltip:"Instance objects or groups, reference base object"
icon:#("Systems",3)
(

	rollout Pankov_InstanceAll "Instance All 1.0" width:162 height:300
	(
		fn addNodeIerarchyToLayer obj layer = (
			layer.addNode obj
			for child in obj.children do addNodeIerarchyToLayer child layer
		)
		
		fn clearDeadNodes array = (
			if array.count != 0 do (for i = array.count to 1 by -1 where not isValidNode array[i] do deleteItem array i)
			array
		)
		
		group "Main object" (
			pickbutton pick_main "Pick object" toolTip:"" width:130
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
			) else (
				main_name.text = "Object mode"
				Pankov_InstanceAll.go_ref.enabled = true
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
			print ("picked: " + obj as string)
		)
		
		
		group "Make instances" (
			checkbox rep "replace old objects" checked:true	
			label lb1 "Keep old objects params:"
			
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
				
				if old_objects.count>0 then (
					undo on (
						-- create instance
						new_objects = #()
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
								print "If old_obj is in group"
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
								print "assign children"
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
							
						)
					
						if isgrouphead main_obj then (
							setGroupOpen main_obj true
						)
						
						select new_objects		
						
						if rep.checked == true do (
						  old_objects = clearDeadNodes old_objects
						  delete old_objects
						)
					)
				) else (
					messagebox "No valid selection for replace"
				)
			)
		)
	  
		group "Make reference" (
			label lb2 "Reference base object"
			button go_ref "[ make references ]" width:130 enabled:false
		)
	  
		on go_ref pressed do (
			if not isValidNode main_obj then (
				messagebox "No main object picked"
			) else (
				-- Collect only objects, not group heads
				old_objects = for obj in selection where not (isGroupHead obj) collect obj
				if old_objects.count>0 then (
					undo on (
						for old_obj in old_objects do (
							old_obj.baseobject = main_obj.baseobject
						)
					)
				) else (
					messagebox "No valid selection for reference"
				)
			)
		)
	  
		on Pankov_InstanceAll close do (
			setIniSetting (getmaxinifile()) "Pankov_InstanceAll" "WindowPos" (GetDialogPos Pankov_InstanceAll as string)
		)
	  
	)

	pos = getinisetting (getmaxinifile()) "Pankov_InstanceAll" "WindowPos"
	if pos!="" then CreateDialog Pankov_InstanceAll pos:(execute pos) else CreateDialog Pankov_InstanceAll

)

