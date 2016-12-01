macroScript RandomMatID category:"#PankovScripts" buttontext:"Rnd MatID" tooltip:"Random MaterialID Channel for selected (+Shift for reset)" icon:#("Material_Modifiers", 2)
(
local elements = selection
local materials = #()
local exec = true
local shift = false
	if keyboard.shiftPressed then shift = true
if elements.count==0 then if (queryBox "Run script for all objects?" title:"There is nothing selected!") then elements = $* else exec = false
if exec then (
for i in 1 to elements.count do (if elements[i].material!= undefined then appendIfUnique materials elements[i].material)

if not shift then ( -- random IDs
	print "shift false"
-- Random Mat_ID
	for n=1 to materials.count do (
		try (
			for n1=1 to materials[n].count do (
				materials[n][n1].effectsChannel = (random 0 15))
		)
		catch (
			try (materials[n].effectsChannel = (random 0 15)) catch ()
		)
	)
-- Random Object_ID	
	for n=1 to elements.count do (
		elements[n].gbufferchannel = n
	)
) else ( -- Reset IDs
	print "shift true"
-- Reset Mat_ID
	for n=1 to scenematerials.count do ( 
		try (
			for n1=1 to materials[n].count do (
				materials[n][n1].effectsChannel = 0)
		)
		catch (
			try (materials[n].effectsChannel = 0) catch ()
		)
	)
-- Reset Object_ID	
	for n=1 to elements.count do (
		elements[n].gbufferchannel = 0
	)
)
)
) --end script