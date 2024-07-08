macroScript Pankov_ExtractInstanceFromReference
category:"#PankovScripts"
buttontext:"ExtractInstanceFromReference"
tooltip:"Extract instance from reference"
icon:#("pankov_instancseAll",2)
(
	fn isEqualListObjects a b = (
		-- Used to compare the list of the reference nodes for the modifier
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
	
	on isenabled return (
		selection.count == 1 AND
		selection[1].modifiers.count > 0 AND
		(refs.dependentNodes selection[1].baseobject).count > 1 AND
		not isEqualListObjects (refs.dependentNodes selection[1].baseobject) (refs.dependentNodes selection[1].modifiers[1])
	)
	
	on execute do
	(
		main_obj = selection[1]
		target_obj = copy main_obj
		for i in 1 to target_obj.modifiers.count do deleteModifier target_obj 1
		if isgroupmember main_obj then (
			setGroupMember target_obj true
			setgroupopen target_obj.parent false
			setgroupopen target_obj.parent true
		)

		undo on (
			local baseInstanceModifiersCount = getBaseInstanceModifiersCount main_obj
			-- reference base object to target
			target_obj.baseobject = main_obj.baseobject
			-- clear old modifiers stack
			for i in 1 to target_obj.modifiers.count do deleteModifier target_obj 1
			-- move modifiers to target object
			for i in 1 to baseInstanceModifiersCount do (
				local current_mod = main_obj.modifiers[main_obj.modifiers.count-i+1]
				addModifierWithLocalData target_obj current_mod main_obj current_mod
				deleteModifier main_obj main_obj.modifiers[main_obj.modifiers.count-i]
			)
			select target_obj
			completeredraw()
		)
	)
)