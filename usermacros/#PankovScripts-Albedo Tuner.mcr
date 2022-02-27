macroScript AlbedoTune category:"#PankovScripts" buttontext:"Albedo" tooltip:"Albedo Tunner (Corona, Vray)" icon:#("VRayToolbar", 27)
(
try ( destroydialog AlbedoTune )catch()

rollout AlbedoTune "Tune Levels (albedo)" width:200 height:130
(
	checkbox chkSel "Only for selected" pos:[13,7] width:103 height:15 checked:true across:2
	checkbox chkMlt "Multiply" pos:[122,7] width:59 height:15 checked:true
	label lbl1 "Thresholds" pos:[60,27] width:52 height:13
	label lbl2 "Levels" pos:[154,27] width:31 height:13
	checkbox chkDiff "" pos:[106,45] width:15 height:15 checked:true
	spinner spnDiffThres "Diffuse" pos:[28,44] width:76 height:16 range:[0,1,0.6]
	spinner spnDiffLvl "level" pos:[131,44] width:67 height:16 range:[0,1,0.6]
	checkbox chkRefl "" pos:[106,65] width:15 height:15 checked:true
	spinner spnReflThres "Reflection" pos:[19,64] width:84 height:16 range:[0,1,0.8]
	spinner spnReflLvl "level" pos:[131,65] width:67 height:16 range:[0,1,0.8]
	button btnStart "Start Tune" pos:[67,86] width:66 height:40

	fn getRender =
	(
		local r = renderers.current as string
		if matchpattern r pattern:"*Corona*" do return "Corona"
		if matchpattern r pattern:"*V_Ray_Adv*" do return "VRay"
		if matchpattern r pattern:"*Default_Scanline*" do return "Scanline"
		if matchpattern r pattern:"*mental_ray*" do return "MentalRay"
		if matchpattern r pattern:"*iray_Renderer*" do return "IRay"
		return ""
	)
	
	on btnStart pressed do
	(
		success = false
		Cmats = #()
		if chkSel.checked then (
			if selection.count>0 then objs = selection else if (queryBox "Tune all materials in the scene?" title:"There is nothing selected")then(objs = $*)else objs=#()
		)else( objs = $*)
		if getRender() == "Corona" then (
			for obj in objs do (join Cmats (getClassInstances CoronaMtl target:obj))
			Cmats = makeUniqueArray Cmats
			if chkDiff.checked then for mat in Cmats do (
				if mat.levelDiffuse > spnDiffThres.value then
					if chkMlt.checked then mat.levelDiffuse = mat.levelDiffuse * spnDiffLvl.value else mat.levelDiffuse = spnDiffLvl.value
			)
			if chkRefl.checked then for mat in Cmats do (
				if mat.levelReflect > spnReflThres.value then
					if chkMlt.checked then mat.levelReflect = mat.levelReflect * spnReflLvl.value else mat.levelReflect = spnReflLvl.value
			)
			
			Cmats = #()
			for obj in objs do (join Cmats (getClassInstances CoronaPhysicalMtl target:obj))
			Cmats = makeUniqueArray Cmats
			if chkDiff.checked then for mat in Cmats do (
				if mat.metalnessMode == 0 then (
				if mat.baseLevel > spnDiffThres.value then
					if chkMlt.checked then mat.baseLevel = mat.baseLevel * spnDiffLvl.value else mat.baseLevel = spnDiffLvl.value
				)
			)
			if chkRefl.checked then for mat in Cmats do (
				if mat.metalnessMode == 1 then (
				if mat.baseLevel > spnReflThres.value then
					if chkMlt.checked then mat.baseLevel = mat.baseLevel * spnReflLvl.value else mat.baseLevel = spnReflLvl.value
				)
			)
			
			success = true
		)
		

		
		if getRender() == "VRay" then (
			for obj in objs do (join Cmats (getClassInstances VrayMtl target:obj))
			Cmats = makeUniqueArray Cmats
			if chkDiff.checked then for mat in Cmats do (
				if mat.texmap_diffuse!=undefined then (
					if not (classof mat.texmap_diffuse == output) OR (classof mat.texmap_diffuse == vraycolor)  then (mat.texmap_diffuse = output MAP1:( mat.texmap_diffuse )	)
					if classof mat.texmap_diffuse == output then (
						if mat.texmap_diffuse.output.rgb_level > spnDiffThres.value then
							if chkMlt.checked then mat.texmap_diffuse.output.rgb_level = mat.texmap_diffuse.output.rgb_level * spnDiffLvl.value else mat.texmap_diffuse.output.rgb_level = spnDiffLvl.value
					)
					if classof mat.texmap_diffuse == vraycolor then (
						if mat.texmap_diffuse.rgb_multiplier > spnDiffThres.value then
							if chkMlt.checked then mat.texmap_diffuse.rgb_multiplier = mat.texmap_diffuse.rgb_multiplier * spnDiffLvl.value else mat.texmap_diffuse.rgb_multiplier = spnDiffLvl.value
					)
				)else (
					if mat.diffuse != (color 0 0 0) then (
						mat.texmap_diffuse = VRayColor (); mat.texmap_diffuse.color = mat.diffuse
						if chkMlt.checked then mat.texmap_diffuse.rgb_multiplier = mat.texmap_diffuse.rgb_multiplier * spnDiffLvl.value else mat.texmap_diffuse.rgb_multiplier = spnDiffLvl.value
					)
				)
			)
			if chkRefl.checked then for mat in Cmats do (
				
				
				if mat.texmap_reflection!=undefined then (
					if not (classof mat.texmap_reflection == output) OR (classof mat.texmap_reflection == vraycolor)  then (mat.texmap_reflection = output MAP1:( mat.texmap_reflection )	)
					if classof mat.texmap_reflection == output then (
						if mat.texmap_reflection.output.rgb_level > spnReflThres.value then
							if chkMlt.checked then mat.texmap_reflection.output.rgb_level = mat.texmap_reflection.output.rgb_level * spnReflLvl.value else mat.texmap_reflection.output.rgb_level = spnReflLvl.value
					)
					if classof mat.texmap_reflection == vraycolor then (
						if mat.texmap_diffuse.rgb_multiplier > spnReflThres.value then
							if chkMlt.checked then mat.texmap_reflection.rgb_multiplier = mat.texmap_reflection.rgb_multiplier * spnReflLvl.value else mat.texmap_reflection.rgb_multiplier = spnReflLvl.value
					)
				)else (
					if mat.reflection != (color 0 0 0) then (
						mat.texmap_reflection = VRayColor (); mat.texmap_reflection.color = mat.reflection
						if chkMlt.checked then mat.texmap_reflection.rgb_multiplier = mat.texmap_reflection.rgb_multiplier * spnReflLvl.value else mat.texmap_reflection.rgb_multiplier = spnReflLvl.value
					)
				)
			)
			success = true
		)
		if not success then messagebox "Nothing has been changed"
		try ( destroydialog AlbedoTune )catch()
	)
	
	on AlbedoTune open do
	(
		modTag = attributes tag ( parameters tagparams (tempMod type:#float default:0) )
		
		RollPos = getIniSetting (getMaxINIFile()) "AlbedoRollout" "WindowPos"
		if RollPos != "" and RollPos != undefined do
		(
			if not keyboard.escPressed do SetDialogPos AlbedoTune (execute RollPos)
		)
	)
	
	on AlbedoTune close do
	(
		RollPos = GetDialogPos AlbedoTune
		setIniSetting (getMaxINIFile()) "AlbedoRollout" "WindowPos" (RollPos as string)
	)
	
)

createdialog AlbedoTune
)