macroScript StandartRegionRender category:"#PankovScripts" buttontext:"StdRegionRenderToggle" tooltip:"Standart Region Render Toggle" icon:#("UVWUnwrapModes", 23)
(
	local state = false
	on isChecked return (getRenderType() == #region)
	on execute do (--if the Macro button was pressed,
		if (getRenderType() == #region) then state = false else state = true
		if state then (
			EditRenderRegion.EditRegion()
			if findstring (renderers.current as string) "corona" != undefined then renderers.current.vfb_clearBetweenRenders = false
		)else(
			setRenderType #normal
			EditRenderRegion.UpdateRegion()
			if findstring (renderers.current as string) "corona" != undefined then renderers.current.vfb_clearBetweenRenders = true
		)
	)
)

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

macroScript CoronaRenderSelected category:"#PankovScripts" buttontext:"CoronaRenderSelectedToggle" tooltip:"Corona Render Selected Toggle" icon:#("PankovScripts", 2)
(	
	on isChecked return (try ( renderers.current.renderSelected_mode == 1) catch false)
	on isEnabled return (
		try (
			if findstring (renderers.current as string) "corona" != undefined then true else false
		) catch false
	)
	on execute do (
		if renderers.current.renderSelected_mode == 0 then (
			renderers.current.renderSelected_mode = 1
			renderers.current.vfb_clearBetweenRenders = false
		)else(
			renderers.current.renderSelected_mode = 0
			renderers.current.vfb_clearBetweenRenders = true
		)
	)
	/*
	on isChecked return (try ( renderers.current.renderSelected_mode == 0) catch false)
	on isEnabled return (
		try (
			if findstring (renderers.current as string) "corona" != undefined then true else false
		) catch false
	)
	on execute do (
		if renderers.current.renderSelected_mode == -1 then (
			renderers.current.renderSelected_mode = 0
		)else(
			renderers.current.renderSelected_mode = -1
		)
	)
	*/
)

/*
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
*/

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


macroScript CoronaDenoiseOnRenderToggle category:"#PankovScripts" buttontext:"DenoiseOnRndrTgl" tooltip:"Corona Denoise on Render Toggle" icon:#("PankovScripts", 1)
(
	on isChecked return (try renderers.current.denoise_duringRender catch false)
	on isEnabled return (
		try (
			if findstring (renderers.current as string) "corona" != undefined then true else false
		) catch false
	)
	on execute do (
		if renderers.current.denoise_duringRender then (
			renderers.current.denoise_duringRender = false
		)else(
			renderers.current.denoise_duringRender = true
		)
	)
)

macroScript CoronRenderMaskToggle category:"#PankovScripts" buttontext:"RenderMaskOnlyTgl" tooltip:"Corona Render Mask Only Toggle" icon:#("PankovScripts", 3)
(
	on isChecked return (try renderers.current.shading_onlyElements catch false)
	on isEnabled return (
		try (
			if findstring (renderers.current as string) "corona" != undefined then true else false
		) catch false
	)
	on execute do (
		if renderers.current.shading_onlyElements then (
			renderers.current.shading_onlyElements = false
		)else(
			renderers.current.shading_onlyElements = true
		)
	)
)