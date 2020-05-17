/*
Скрипт для рапределения в пространстве
Особенности:
* Работает по пивотам
* Автоматически определяет первый и последний объекты
* Распределяет группированные объекты
*/

macroScript Distibute_objects
category:"#PankovScripts"
toolTip:"Distibute objects"
icon:#("AutoGrid",2)
buttontext:"Distr" 	
(
	global DistibuteObjRollout
	
	try(destroyDialog DistibuteObjRollout) catch()

	rollout DistibuteObjRollout "Distribute objects" width:300
	(
		button btDistr1 "Simple" width:64
		checkbox Chk "Add spaces at the ends" checked:true
		button btDistr2 "Unify spaces between bounding boxes" width:64
	)
	
	on isEnabled return (try ( selection.count > 1 ) catch false)
	
	on execute do (
		
local s = #()
s = selection as array	
for n in selection do (
	if n.children.count > 0 then (
		for i in n.children do (
			deleteItem s (findItem s i)
		)
	)
)
-- sort order

fn mx ar = 
(	local k=1
	case of (
		(ar.count>1): (for n=1 to ar.count-1 do if ar[n]<ar[n+1] then k=n+1)
		(ar.count<1): k=0
		(ar.count==1): k=1
	)
return k)

local d=#()
local ord=#()
for n=1 to 3 do d[n] = selection.max[n] - selection.min[n]
for n=1 to 3 do (
	ord[n] = mx d
	d[ord[n]] = -10^9
)

---------------

-- sort order 1
fn srt ar d = (
	for i=1 to ar.count-1 do (
    for j=1 to ar.count-i do (
        if ar[j].pos[d] > ar[j+1].pos[d] then (
            local k = ar[j]
            ar[j] = ar[j+1]
			ar[j+1] = k
	)))
return ar)

-- sort order 2
fn srt2 ar d1 d2 = (
	for i=1 to ar.count-1 do (
    for j=1 to ar.count-i do (
		if (ar[j].pos[d1] == ar[j+1].pos[d1]) AND (ar[j].pos[d2] > ar[j+1].pos[d2]) then
		(
            local k = ar[j]
            ar[j] = ar[j+1]
			ar[j+1] = k
		)
	))
return ar)

s = srt s ord[1]
s = srt2 s ord[1] ord[2]

local step_X = (s[s.count].pos[1] - s[1].pos[1]) / (s.count - 1)
local step_Y = (s[s.count].pos[2] - s[1].pos[2]) / (s.count - 1)
local step_Z = (s[s.count].pos[3] - s[1].pos[3]) / (s.count - 1)
undo on
for n = 1 to s.count do s[n].pos = Point3 (s[1].pos.x+step_X*(n-1)) (s[1].pos.y+step_Y*(n-1)) (s[1].pos.z+step_Z*(n-1))

)

)
