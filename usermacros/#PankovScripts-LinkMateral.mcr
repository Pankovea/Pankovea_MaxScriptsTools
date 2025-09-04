macroScript Pankov_LinkMaterial
category:"#PankovScripts"
buttontext:"LinkMat"
tooltip:"Link Material from one object to anoter"
icon:#("PhysX_Main", 23)
(
	on isenabled return (
		selection.count > 1
	)

	on execute do
	(
		if selection.count > 1 then (
			local mat, modif
			local i = selection.count
			do (mat = selection[i].material; i-=1) while (mat == udefined and i>0)
			if mat != undefined do (
				ref_obj = selection[i+1]
				i=1; do (modif=ref_obj.modifiers[i];i+=1) while not (i<ref_obj.modifiers.count or classof modif != Materialmodifier)
				deselect ref_obj
				for obj in selection do obj.material = mat
				if modif == Materialmodifier then for obj in selection do addmodifier obj modif
			)
			redrawViews()
		)
	)
)

macroScript Pankov_SelByMaterial
category:"#PankovScripts"
buttontext:"SelectByMat"
tooltip:"Select by material"
icon:#("Main toolbar", 73)
(
	on isenabled return (
		selection.count > 0
	)

	on execute do
	(
		local mats = for obj in selection collect obj.material
		mats = makeUniqueArray mats
		i = findItem mats undefined
		if i != 0 then deleteitem mats i
		if mats.count == 0 then mats = #(undefined)
		actionMan.executeAction 0 "40021"  -- Selection: Select All
		visible_sel = selection as array
		clearSelection()
		local new_sel = for obj in visible_sel where findItem mats obj.material > 0 and findItem #(geometryclass, shape) (superclassof obj) > 0 collect obj
		select new_sel
	)
)
