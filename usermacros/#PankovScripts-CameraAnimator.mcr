macroScript CameraAnimator
category:"#PankovScripts"
tooltip:"Camera Animator (+Shift - Deanimator) Supports: Standart, Vray, Corona cameras"
buttontext:"CameraAnimator"
icon:#("Cameras", 1)
(
local mycams
local mysel

-- #FIXME on error: getPropNames $ and find problem proprerty
local excluded_params = #(#MultiPass_Effect)
	
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

fn is_various_params arr_of_obj param = (
	first_obj_param = getProperty arr_of_obj[1] param
	for obj in arr_of_obj do(
		if first_obj_param != getProperty obj param then return true
	)
	return false
)

on isenabled return (
	(selection.count > 1) AND
	(
		(classof selection[1] == Freecamera) OR
		(classof selection[1] == Targetcamera) OR
		(classof selection[1] == VRayPhysicalCamera) OR
		(classof selection[1] == CoronaCam)
	)
)

on execute do
(
	--try delete $AniCam catch()
if keyboard.shiftPressed == false then (
	mysel = selection
	clearlistener()

	mycams = for cam in mysel where ((superclassof cam == camera) and (cam.name != "AniCam")) collect cam

	cliping = 0
	case classof(mycams[1]) of (
		freecamera :    for cam in mycams where cam.clipManually == True do cliping = 1
		Targetcamera :  for cam in mycams where cam.clipManually == True do cliping = 1
	)
	-- Filter cameras by the first camera
	mycams = for cam in mycams where (classof cam == classof mycams[1]) collect cam
	
	if mycams.count > 1 then
	(
		try( if mycams[1].position.keys.count > 1 then an = true else an = false) catch (an = false) -- ??????????, ??????????? ?? ???????? ??????
		if not an then
		(
			case classof(mycams[1]) of (
				freecamera : AniCam = freecamera name:"StandAniCam_"
				Targetcamera : AniCam = freecamera name:"StandAniCam_"
				VRayPhysicalCamera : AniCam = VRayPhysicalCamera name:"VrayAniCam_"
				CoronaCam : (AniCam = CoronaCam name:"CoronaAniCam_"
							AniCam.targeted = false
							)
			)
				
			AniCam.position.controller = linear_position()
			--AniCam.rotation.controller = linear_rotation()
			st = 1
			sh = 0
			-- change animation range if not enouth
			if animationRange.end>mycams.count then
			(	animationRange = (interval 1 (animationRange.end))
			)else(
				animationRange = (interval 1 (mycams.count))
			)
		)else(
			AniCam = mycams[1]
			st = 2
			sh = int (mycams[1].rotation.controller.keys[mycams[1].rotation.controller.keys.count].time) - 1
			-- change animation range if not enouth
			if animationRange.end>(int (mycams[1].rotation.controller.keys[mycams[1].rotation.controller.keys.count].time) - 1 + mycams.count) then
			(	animationRange = (interval 1 (animationRange.end))
			)else(
				animationRange = (interval 1 (int (mycams[1].rotation.controller.keys[mycams[1].rotation.controller.keys.count].time) - 1 + mycams.count))
			)
		)
		
		with animate on
		(	sh2=0
			for c = st to mycams.count do (	
				curCamKeys = mycams[c].rotation.controller.keys.count
				if curCamKeys == 0 then curCamKeys = 1
				for n = 1 to curCamKeys do (
					if n>1 then (sh2=sh2+1)
					print c+sh+sh2
					at time (c+sh+sh2) AniCam.transform = at time (n) mycams[c].transform
					for prop in getPropNames mycams[c] do (
						if (findItem excluded_params prop == 0) and (is_various_params mycams prop) then (
							at time (c+sh+sh2) setProperty AniCam prop (at time (n) getProperty mycams[c] prop)
						)
					)
					
					if (classof AniCam == Freecamera or classof AniCam == Targetcamera) and cliping == 1 then
						AniCam.clipManually = True
				)
			)
		)
	)
	AniCam.wirecolor = (color 87 225 87)
	select AniCam
)else(
	local curCam
	local curTime = sliderTime
	local keyTime
	for i in 1 to (selection[1].position.controller.keys.count) do (
		keyTime = (getKeyTime selection[1].position.controller i)
		at time keyTime curCam = snapshot selection[1]
		sliderTime = i
		deleteKeys curCam #allKeys
		curCam.name = selection[1].name + "-"+(nDig keyTime (dgtsCount selection[1].position.controller.keys.count))
	)
	sliderTime = curTime
)
)

)
