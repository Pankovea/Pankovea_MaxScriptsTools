/* @Pankovea Scripts - 2024.11.24
ResetModContextTM: Сбрасывает матрицу трансформаций в контексте модификатора к состоянию как если бы модификатор был только что применён к объектам или одному объекту.

особенности:
* Работает с выделенным модификатором в стеке модификаторов
* при нажатом Shift сбрасывает ModContextBBox для каждого объекта в отдельности

--------
ResetModContextTM: Resets the transformation matrix in the context of the modifier to the state as if the modifier had just been applied to objects or a single object.

features:
* Works with a dedicated modifier in the modifier stack
* when Shift is pressed, resets the ModContextBBox for each object individually
*/

macroScript Pankov_ResetModContextTM
category:"#PankovScripts"
buttontext:"ResetModTM"
tooltip:"Reset modifier context tranform for multiple seleted objects"
(
	
on execute do (	
	modif = modPanel.getCurrentObject()
	if modif != undefined then (
		work_objects = for obj in selection where (finditem obj.modifiers modif != 0) collect obj
		size = (selection.max - selection.min)/2 / modif.gizmo.scale
		bbox = Box3 -size size
		for obj in work_objects do (
			if keyboard.shiftPressed or work_objects.count == 1 then (
				tm = obj.transform -- save transform
				obj.transform = (matrix3 [1,0,0] [0,1,0] [0,0,1] obj.pos)
				size = (obj.max - obj.min) / 2 -- get local bbox
				bbox = Box3 -size size
				obj.transform = tm -- restore transform
				setModContextTM obj modif (matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0])
				setModContextBBox obj modif bbox
			) else (
				tm = getModContextTM obj obj.modifiers[1]
				new_tm = obj.transform
				new_tm.position = -((selection.max - selection.min)/2 + selection.min - obj.position)
				setModContextTM obj modif new_tm
				setModContextBBox obj modif bbox
			)
		)
	)
)

)