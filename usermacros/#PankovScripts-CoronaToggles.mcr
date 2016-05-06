macroScript StdBlowUpRenderToggle category:"#PankovScripts" buttontext:"StdBlowUpRenderToggle" tooltip:"Standart BlowUp Render Toggle" icon:#("UVWUnwrapModes", 5)
(
	local state = false
	on isChecked return (getRenderType() == #blowup)
	on execute do (--if the Macro button was pressed,
		if (getRenderType() == #blowup) then state = false else state = true
		if state then (
			setRenderType #blowup
			--EditRenderRegion.IsEditing = true
			EditRenderRegion.EditRegion()
		)else(
			setRenderType #normal
			EditRenderRegion.UpdateRegion()
		)
	)
)

macroScript CoronaRenderSelected category:"#PankovScripts" buttontext:"CoronaRenderSelectedToggle" tooltip:"Corona Render Selected Toggle" icon:#("ViewportNavigationControls", 5)
(	
	on isChecked return (try ( renderers.current.renderSelected_mode == 1) catch false)
	on isEnabled return (
		try (
			if findstring (renderers.current as string) "corona" != undefined then true else false
		) catch false
	)
	on execute do (
		if renderers.current.renderSelected_mode == 1 then (
			renderers.current.renderSelected_mode = 0
		)else(
			renderers.current.renderSelected_mode = 1
		)
	)
)

macroScript CoronaClearVFBonRender category:"#PankovScripts" buttontext:"CoronaClearVFBToggle" tooltip:"Corona Clear VFB inbetween renders Toggle" icon:#("VRayToolbar", 2)
(	
	on isChecked return (try renderers.current.vfb_clearBetweenRenders catch false)
	on isEnabled return (
		try (
			if findstring (renderers.current as string) "corona" != undefined then true else false
		) catch false
	)
	on execute do (
		if renderers.current.vfb_clearBetweenRenders then (
			renderers.current.vfb_clearBetweenRenders = false
		)else(
			renderers.current.vfb_clearBetweenRenders = true
		)
	)
)

macroScript CoronaFinalRender category:"#PankovScripts" buttontext:"FinalRenderToggle" tooltip:"Corona Final Render Settings" icon:#("VRayToolbar", 3)
(
	local state = false

	on isChecked return state
	on isEnabled return (
		try (
			if findstring (renderers.current as string) "corona" != undefined then true else false
		) catch false
	)
	on execute do (
		if renderscenedialog.isOpen() == True then (p = true; renderscenedialog.close()) else p = false
		state = not state
		if state then (
			if rendOutputFilename != "" then (
				rendTimeType = 3
				rendSaveFile = true
				renderers.current.vfb_autosave_enable = true
				renderers.current.vfb_autosave_interval = 30
				exrfname = (getfilenamepath rendOutputFilename)+"EXR\\"
				if not doesFileExist exrfname then (
					if (queryBox ("Path doesn't exist. Create?\n"+exrfname) title:"Warning!") then makeDir exrfname
					else renderers.current.vfb_autosave_enable = false
				)
				renderers.current.vfb_autosave_filename = exrfname+(getfilenamefile rendOutputFilename)
				if (rendEnd - rendStart)+2 > renderers.current.vfb_autosave_countEnd then renderers.current.vfb_autosave_countEnd = (rendEnd - rendStart)+2
			)
		)else(
			rendTimeType = 1
			rendSaveFile = false
			renderers.current.dr_enable = false
			renderers.current.vfb_autosave_enable = false
		)
		if p then (renderscenedialog.open())
	)
)

macroScript HalfResolution category:"#PankovScripts" buttontext:"HalfRes" tooltip:"Divide by Half Resolution" icon:#("TrackViewStatus", 19)
(
	local state = false

	on isChecked return state
		
	on execute do (
		if renderscenedialog.isOpen() == True then (p = true; renderscenedialog.close()) else p = false
		state = not state
		if state then (
			renderWidth = renderWidth/2
			renderHeight = renderHeight/2
		)else(
			renderWidth = renderWidth*2
			renderHeight = renderHeight*2
		)
		if p then (renderscenedialog.open())
	)
)


macroScript CoronaDistributeRenderToggle category:"#PankovScripts" buttontext:"DistrRndrTgl" tooltip:"Corona Distributed Render Toggle" icon:#("FileLinkActionItems", 7)
(
	on isChecked return (try(renderers.current.dr_enable) catch false)
	on isEnabled return (
		try (
			if findstring (renderers.current as string) "corona" != undefined then true else false
		) catch false
	)
	on execute do renderers.current.dr_enable = not renderers.current.dr_enable
)

macroScript CoronaShowVfb category:"#PankovScripts" buttontext:"DistrRndrTgl" tooltip:"Corona Show VFB" icon:#("Maintoolbar", 101)
(
	local state = false
	on isChecked return state
	on isEnabled return ( try (	if findstring (renderers.current as string) "corona" != undefined then true else false	) catch false	)
	on execute do (
		state = not state
		CoronaRenderer.showVfb state
	)
)

macroScript CoronaStartInteractiveRender category:"#PankovScripts" buttontext:"CrnInteractive" tooltip:"Corona Start Interactive Render" icon:#("Render", 11)
(
	on isEnabled return ( try (	if findstring (renderers.current as string) "corona" != undefined then true else false	) catch false	)
	on execute do CoronaRenderer.startInteractive()
)