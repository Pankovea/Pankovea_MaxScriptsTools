/* @Pankovea Scripts - 2024.11.25
ResetModContextTM: Сбрасывает матрицу трансформаций в контексте модификатора к состоянию как если бы модификатор был только что применён к объектам или одному объекту.

особенности:
* Работает с выделенным модификатором в стеке модификаторов
* при нажатом Shift сбрасывает ModContextBBox для каждого объекта в отдельности
* при нажатом Esc сбрасывает Gizmo
* при изменении точки преобразований не получается сохранить объект в изначальном положении
внимание:
* undo не работает

--------
ResetModContextTM: Resets the transformation matrix in the context of the modifier to the state as if the modifier had just been applied to objects or a single object.

features:
* Works with a dedicated modifier in the modifier stack
* when Shift is pressed, resets the ModContextBBox for each object individually
* when Esc is pressed, Gizmo resets
* when changing the transformation point, it is not possible to keep the object in its original position

attention:
* undo does not work
*/

macroScript Pankov_ResetModContextTM
category:"#PankovScripts"
buttontext:"ResetModTM"
tooltip:"Reset modifier context tranform for multiple seleted objects"
(
local gizmo_modifiers = #(xform, bend, squeeze, taper, wave, twist, skew, stretch, melt, noise, SliceModifier, symmetry, mirror, Vol__Select, Uvwmap)
local ffd_modifiers = #(FFD_2x2x2, FFD_3x3x3, FFD_4x4x4, FFDBox, FFDCyl)
local nullTM = matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]

function make_modifier_unique obj modif = (
	if (refs.dependentnodes modif).count < 2 then return modif
	
	local i = modPanel.getModifierIndex obj modif
	local old_tm = getModContextTM obj modif
	local cp_modif = copy modif
	addModifierWithLocalData obj cp_modif obj modif before:(i-1)
	deleteModifier obj (i+1)
	setModContextTM obj modif old_tm
	return cp_modif
)

on execute do (	
	local modif = modPanel.getCurrentObject()
	if modif != undefined then (
		local work_objects = for obj in selection where (finditem obj.modifiers modif != 0) collect obj
		local me = modif.enabled -- save enabled modif
		
		undo on (
			
			if keyboard.shiftPressed or work_objects.count == 1 then (
				for obj in work_objects do (
					tm = obj.transform -- save transform
					obj.transform = (matrix3 [1,0,0] [0,1,0] [0,0,1] obj.pos) -- reset obj transform
					modif.enabled = false -- turn of modifier
					objBBox = Box3 (obj.min - obj.pos) (obj.max - obj.pos) -- get local bbox
					setModContextTM obj modif nullTM -- reset Mod Context Transform Matrix
					setModContextBBox obj modif objBBox -- reset Mod Context Bounding Box
					obj.transform = tm -- restore transform
					modif.enabled = me -- restore modif enabled
				)
			) else (
				for i in 1 to 20 do ( -- do it several times so that the calculations come to a stable state 
					
					-- calc selected bbox. taken out for optimization. to avoid performing the same calculations in the loop
					--modif.enabled = false -- turn of modifier
					local size = (selection.max - selection.min)/2
					local selectionBBox = Box3 -size size
					--modif.enabled = me -- restore modif enabled
					
					for obj in work_objects do (
						old_tm = getModContextTM obj modif -- save old Mod Context Transform Matrix
						tm = obj.transform -- save transform
						if keyboard.escPressed then (
							modif = make_modifier_unique obj modif -- make unique modifier
							modif.gizmo.transform = nullTM
						)
						case of (
							(finditem gizmo_modifiers (classof modif) > 0) :      modif_tr = modif.gizmo.transform
							(finditem ffd_modifiers (classof modif) > 0) :        modif_tr = modif.Lattice_Transform.transform
							else: try ( modif_tr = modif.gizmo.transform ) catch (modif_tr = nullTM)
						)
						setModContextBBox obj modif selectionBBox
						new_tm = obj.transform * modif_tr
						new_tm.position = -((selection.max - selection.min)/2 + selection.min - obj.position) * modif_tr
						setModContextTM obj modif new_tm
					)
					
					-- update geometry
					modif.enabled = false
					modif.enabled = me
					CompleteRedraw()
				)
			)
			
		) -- end undo
	) -- end modif check
) -- end on execute

) -- end macroscript