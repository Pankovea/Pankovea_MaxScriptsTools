macroScript CameraAnimator
category:"#PankovScripts"
tooltip:"Camera Animator (+Shift - Denimator)"
buttontext:"CameraAnimator"
icon:#("Cameras", 1)
(
local mycams
local mysel

fn nDig i n = (
	if (i as string).count<n then (
		str = ""
		for m in 1 to (n-(i as string).count) do str+="0"
		str+=i as string
		return str
	)else return i as string
)

fn dgtsCount n = ( 
	return case of (
		(n<10):1
		(n<100):2
		(n<1000):3
		(n<10000):4
		(n<100000):5
	)
)

on isenabled return (
	(selection.count > 0) AND
	(
		(classof selection[1] == Freecamera) OR
		(classof selection[1] == Targetcamera) OR
		(classof selection[1] == VRayPhysicalCamera)
	)
)

on execute do
(
	--try delete $vraycam catch()
if keyboard.shiftPressed == false then (
	mysel = selection
	clearlistener()

	mycams = #()

	for i = 1 to mysel.count where ((superclassof mysel[i] == camera) and (mysel[i].name != "VrayCam")) do
	(
		append mycams mysel[i]
	)

	cliping = 0
	for i = 1 to mycams.count do
	(
		if classof mycams[i] == VRayPhysicalCamera and mycams[i].clip_on == True then cliping = 1
		if classof mycams[i] == Targetcamera and mycams[i].clipManually == True then cliping = 1
		if classof mycams[i] == Freecamera and mycams[i].clipManually == True then cliping = 1
	)--end for
	
	if mycams.count > 1 then
	(
		try( if mycams[1].position.keys.count > 1 then an = true else an = false) catch (an = false) -- ??????????, ??????????? ?? ???????? ??????
		if not an then
		(
			if  classof(mycams[1]) == VRayPhysicalCamera then (
				vraycam = VRayPhysicalCamera name:"VrayAniCam_"
			) else (
				vraycam = freecamera name:"StandAniCam_"
			)
			vraycam.position.controller = linear_position()
			vraycam.rotation.controller = linear_rotation()
			st = 1
			sh = 0
			if animationRange.end>mycams.count then
			(	animationRange = (interval 1 (animationRange.end))
			)else(
				animationRange = (interval 1 (mycams.count))
			)
		)else(
			vraycam = mycams[1]
			st = 2
			sh = int (mycams[1].rotation.keys[mycams[1].rotation.keys.count].time) - 1
			if animationRange.end>(int (mycams[1].rotation.keys[mycams[1].rotation.keys.count].time) - 1 + mycams.count) then
			(	animationRange = (interval 1 (animationRange.end))
			)else(
				animationRange = (interval 1 (int (mycams[1].rotation.keys[mycams[1].rotation.keys.count].time) - 1 + mycams.count))
			)
		)

		if  classof(mycams[1]) == VRayPhysicalCamera then
        (
            with animate on
            (  sh2=0
				for c = st to mycams.count do
				(
					try( curCamKeys = mycams[c].position.keys.count ) catch (curCamKeys = 1) -- ??????????, ??????????? ?? ??????? ??????
					for n = 1 to curCamKeys do (
						if n>1 then (sh2=sh2+1)
						at time (c+sh+sh2) vraycam.transform           = at time (n) mycams[c].transform
						--at time (c) vraycam.target.transform    = at time (n) mycams[c].target.transform
						at time (c+sh+sh2) vraycam.targeted            = false --mycams[c].targeted
						at time (c+sh+sh2) vraycam.film_width          = at time (n) mycams[c].film_width
						at time (c+sh+sh2) vraycam.focal_length        = at time (n) mycams[c].focal_length
						--at time (c+sh+sh2) vraycam.specify_fov		=	mycams[c].specify_fov
						at time (c+sh+sh2) vraycam.fov        			= at time (n) mycams[c].fov
						at time (c+sh+sh2) vraycam.zoom_factor         = at time (n) mycams[c].zoom_factor
						at time (c+sh+sh2) vraycam.distortion          = at time (n) mycams[c].distortion
						at time (c+sh+sh2) vraycam.distortion_type     = at time (n) mycams[c].distortion_type
						at time (c+sh+sh2) vraycam.f_number            = at time (n) mycams[c].f_number
						at time (c+sh+sh2) vraycam.target_distance     = at time (n) mycams[c].target_distance
						at time (c+sh+sh2) vraycam.lens_tilt         = at time (n) mycams[c].lens_tilt
						at time (c+sh+sh2) vraycam.lens_tilt_auto     = at time (n) mycams[c].lens_tilt_auto
						at time (c+sh+sh2) vraycam.specify_focus       = at time (n) mycams[c].specify_focus
						at time (c+sh+sh2) vraycam.focus_distance      = at time (n) mycams[c].focus_distance
						at time (c+sh+sh2) vraycam.dof_display_thresh  = at time (n) mycams[c].dof_display_thresh
						at time (c+sh+sh2) vraycam.exposure            = at time (n) mycams[c].exposure
						at time (c+sh+sh2) vraycam.vignetting          = at time (n) mycams[c].vignetting
						at time (c+sh+sh2) vraycam.vignetting_amount   = at time (n) mycams[c].vignetting_amount
						at time (c+sh+sh2) vraycam.type                = at time (n) mycams[c].type
						at time (c+sh+sh2) vraycam.shutter_speed       = at time (n) mycams[c].shutter_speed
						at time (c+sh+sh2) vraycam.shutter_angle       = at time (n) mycams[c].shutter_angle
						at time (c+sh+sh2) vraycam.shutter_offset      = at time (n) mycams[c].shutter_offset
						at time (c+sh+sh2) vraycam.latency             = at time (n) mycams[c].latency
						at time (c+sh+sh2) vraycam.ISO                 = at time (n) mycams[c].ISO
						at time (c+sh+sh2) vraycam.systemLightingUnits = at time (n) mycams[c].systemLightingUnits
						at time (c+sh+sh2) vraycam.whiteBalance        = at time (n) mycams[c].whiteBalance
						at time (c+sh+sh2) vraycam.whiteBalance_preset = at time (n) mycams[c].whiteBalance_preset
						at time (c+sh+sh2) vraycam.use_blades          = at time (n) mycams[c].use_blades
						at time (c+sh+sh2) vraycam.blades_number       = at time (n) mycams[c].blades_number
						at time (c+sh+sh2) vraycam.blades_rotation     = at time (n) mycams[c].blades_rotation
						at time (c+sh+sh2) vraycam.center_bias         = at time (n) mycams[c].center_bias
						at time (c+sh+sh2) vraycam.use_dof             = at time (n) mycams[c].use_dof
						at time (c+sh+sh2) vraycam.use_moblur          = at time (n) mycams[c].use_moblur
						at time (c+sh+sh2) vraycam.subdivs             = at time (n) mycams[c].subdivs
						if cliping == 1 then
						(
							if mycams[c].clip_on == True then
							(
								at time (c+sh+sh2) vraycam.clip_on = True
								at time (c+sh+sh2) vraycam.clip_near           = at time (n) mycams[c].clip_near
								at time (c+sh+sh2) vraycam.clip_far            = at time (n) mycams[c].clip_far
							) else 
							(
								at time (c+sh+sh2) vraycam.clip_on = True
								at time (c+sh+sh2) vraycam.clip_near           = 0
								at time (c+sh+sh2) vraycam.clip_far            = 999999
							)--end if
						) else (
							at time (c+sh+sh2) vraycam.clip_on             = at time (n) mycams[c].clip_on
							at time (c+sh+sh2) vraycam.clip_near           = at time (n) mycams[c].clip_near
							at time (c+sh+sh2) vraycam.clip_far            = at time (n) mycams[c].clip_far
						)
						at time (c+sh+sh2) vraycam.environment_near    = at time (n) mycams[c].environment_near
						at time (c+sh+sh2) vraycam.environment_far     = at time (n) mycams[c].environment_far
						at time (c+sh+sh2) vraycam.horizon_on          = at time (n) mycams[c].horizon_on
						at time (c+sh+sh2) vraycam.legacy_ISO          = at time (n) mycams[c].legacy_ISO
					)
				)
			)
			select vraycam

		) else
		(
			with animate on
			(	sh2=0
				for c = st to mycams.count do
				(
					try( curCamKeys = mycams[c].position.keys.count ) catch (curCamKeys = 1) -- ??????????, ??????????? ?? ??????? ??????
					for n = 1 to curCamKeys do (
						if n>1 then (sh2=sh2+1)
						at time (c+sh+sh2) vraycam.transform = at time (n) mycams[c].transform
						at time (c+sh+sh2) vraycam.fov = at time (n) mycams[c].fov
						at time (c+sh+sh2) vraycam.orthoProjection = at time (n) mycams[c].orthoProjection
						at time (c+sh+sh2) vraycam.baseObject.targetdistance      = at time (n) mycams[c].baseObject.targetdistance
						if mycams[c].clipManually == True then
						(
							at time (c+sh+sh2) vraycam.nearclip = at time (n) mycams[c].nearclip
							at time (c+sh+sh2) vraycam.farclip  = at time (n) mycams[c].farclip
							vraycam.clipManually = True
						)else (
							at time (c+sh+sh2) vraycam.nearclip = 0
							at time (c+sh+sh2) vraycam.farclip  = 1000000
						)--end if
					)
				)
			)
			select vraycam
		)
	)
)else(
	local curCam
	local curTime = sliderTime
	local keyTime
	for i in 1 to (selection[1].position.keys.count) do (
		keyTime = (getKeyTime selection[1].position.controller i)
		at time keyTime curCam = snapshot selection[1]
		sliderTime = i
		deleteKeys curCam #allKeys
		curCam.name = selection[1].name + "-"+(nDig keyTime (dgtsCount selection[1].position.keys.count))
	)
	sliderTime = curTime
)
)

)
