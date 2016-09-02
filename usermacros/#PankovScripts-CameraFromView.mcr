macroScript CameraFromView
category:"#PankovScripts"
tooltip:"Camera From View"
buttontext:"CamFromView"
icon:#("CamP", 1)
(
	FocalDist = gw.GetFocalDist() ; stwRay = mapscreentoworldray (getviewsize()/2)
	camTarg = TargetObject position:(stwRay.pos+(stwRay.dir*FocalDist)) name:"camTarg" ; fovVal = getViewFOV()
	if findstring (renderers.current as string) "Corona" != undefined then (
		undo on (
			NewCamera = CoronaCam pos:stwRay.pos targeted:on target:camTarg specify_fov:on
			if classof NewCamera != Main_Camera then (NewCamera.fov = fovVal) else (NewCamera.lens.fov = fovVal)
			NewCamera.target.name = NewCamera.name + ".Target"
			NewCamera.wirecolor = NewCamera.target.wirecolor = [87, 120, 204]
			if (classof (viewport.getcamera()) == Freecamera) OR (classof (viewport.getcamera()) == Targetcamera) then (
				NewCamera.enableClipping=(viewport.getcamera()).clipManually
				if NewCamera.enableClipping then (
					NewCamera.clippingNear = (viewport.getcamera()).near_clip
					NewCamera.clippingFar = (viewport.getcamera()).far_clip
				)
			)
			viewport.setCamera NewCamera
			select NewCamera
		)
	)
	if findstring (renderers.current as string) "Vray" != undefined then (
		undo on (
			NewCamera = VRayPhysicalCamera pos:stwRay.pos targeted:on target:camTarg specify_fov:on
			if classof NewCamera != Main_Camera then (NewCamera.fov = fovVal) else (NewCamera.lens.fov = fovVal)
			NewCamera.target.name = NewCamera.name + ".Target"
			NewCamera.wirecolor = NewCamera.target.wirecolor = [87, 120, 204]
			if (classof (viewport.getcamera()) == Freecamera) OR (classof (viewport.getcamera()) == Targetcamera) then (
				NewCamera.clip_on=(viewport.getcamera()).clipManually
				if NewCamera.clip_on then (
					NewCamera.clip_near = (viewport.getcamera()).near_clip
					NewCamera.clip_far = (viewport.getcamera()).far_clip
				)
			)
			viewport.setCamera NewCamera
			select NewCamera
			NewCamera.specify_fov = false
		)
	)
)