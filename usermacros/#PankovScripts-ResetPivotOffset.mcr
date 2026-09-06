-- Работает как Reset Xform, но сохраняет поворот. То есть сбрасывает смещение и масштаирование. 

macroScript Pankov_ResetPivotOffset
category:"#PankovScripts"
buttontext:"ResetPivotOffset"
tooltip:"Reset Xform pivot offset after 'Hierarhy -> Affect Pivot Only' Shift+ Reset pivot only"
icon:#("ViewportNavigationControls", 39)
(

fn getObjectOffsetTM obj =
(
	-- Масштаб
	local s = scaleMatrix obj.objectOffsetScale
	-- Поворот (кватернион → матрица)
	local r = obj.objectOffsetRot as Matrix3
	-- Позиция
	local t = transMatrix obj.objectOffsetPos

	return s * r * t
)

fn resetObjectOffsetTM obj =
(
	-- Масштаб
	obj.objectOffsetScale = [1,1,1]
	-- Поворот (кватернион → матрица)
	obj.objectOffsetRot = quat 0 0 0 1
	-- Позиция
	obj.objectOffsetPos = [0,0,0]
)

on enabled do (
	sel = for obj in selection where (finditem #(GeometryClass, Shape) (superclassof obj)) collect obj
	sel.count > 0
)

on execute do (
	sel = for obj in selection where (finditem #(GeometryClass, Shape) (superclassof obj)) do
	(
		if not keyboard.shiftPressed then (
			obj_offset_TM = getObjectOffsetTM(obj)
			
			xf_collect = for modif in obj.modifiers where modif.name == "Reset Pivot XForm" collect modif
			if xf_collect.count > 0 then (
				xf = xf_collect[1]
				obj_offset_TM *= xf.gizmo.transform
			) else (
				xf = xform()
				xf.name = "Reset Pivot XForm"
				addmodifier obj xf
			)
			xf.gizmo.transform = obj_offset_TM
			resetObjectOffsetTM(obj)
		) else (
			obj.transform = (getObjectOffsetTM obj) * obj.transform
			resetObjectOffsetTM(obj)
		)
		
	)
)

)