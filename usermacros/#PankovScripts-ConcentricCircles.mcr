macroScript Pankov_ConcentricCircles
category:"#PankovScripts"
buttontext:"ConcentricCirclesShape"
tooltip:"Create Concentric Circles Shape"
icon:#("ViewportNavigationControls",42)
(	local Pankov_ConcentricCircles
	local undo_continues = false
	local tmp_sel
	local tmp_objcts
	
	function update_interface_fron_obj_values = (
		-- если выделен изменяемый объект, то загрузить данные о нём в интерфейс
		if selection.count==1 and isProperty selection[1] #isConcentricCircles and classof selection[1].baseobject == SplineShape then (
			Pankov_ConcentricCircles.spnNumCircles.value = selection[1].NumCircles
			Pankov_ConcentricCircles.spnStartRadius.value = selection[1].StartRadius
			Pankov_ConcentricCircles.spnEndRadius.value = selection[1].EndRadius
			return true
		) else (
			return false
		)
	)
	
	rollout Pankov_ConcentricCircles "Concentric Circles Parameters"
	(
		spinner spnSteps "Interpolation:" type:#integer range:[1,100,16]
        spinner spnNumCircles "Num Circles:" type:#integer range:[2,100,10] scale:1
        spinner spnStartRadius "Start Radius:" type:#float range:[1,10000,100] scale:10
        spinner spnEndRadius "End Radius:" type:#float range:[1,10000,1000] scale:10
		button create_shape "Create/update shape" toolTip:"" width:130

		function update_geom obj = (
			local radiusStep = (spnEndRadius.value - spnStartRadius.value) / (spnNumCircles.value - 1)

			-- очистить старые сплайны
			for i = numSplines obj to 1 by -1 do deleteSpline obj i
			-- построить новые
			for i = 1 to spnNumCircles.value do (
				addNewSpline obj
				local currentRadius = spnStartRadius.value + (i - 1) * radiusStep
				local angleStep = 360.0 / 4
				for j = 0 to 3 do (
					local ang = j * angleStep
					local x = currentRadius * cos ang
					local y = currentRadius * sin ang
					local x_in = currentRadius * cos(ang - 32)
					local y_in = currentRadius * sin(ang - 32)
					local x_out = currentRadius * cos(ang + 32)
					local y_out = currentRadius * sin(ang + 32)
					addKnot obj i #bezier #curve ([x, y, 0]+obj.pos) ([x_in, y_in, 0]+obj.pos) ([x_out, y_out, 0]+obj.pos)
				)
				close obj i
			)
			updateShape obj
			-- обновить параметры фигуры в объекте
			obj.NumCircles = spnNumCircles.value
			obj.StartRadius = spnStartRadius.value
			obj.EndRadius = spnEndRadius.value
		)
		
		function undo_begin = (
			if not undo_continues then (
				tmp_sel = selection as array
				tmp_objcts = for obj in selection collect copy obj
				hide tmp_sel
				select tmp_objcts
				undo_continues = true
			)
		)

		function undo_end str = (
			if undo_continues then (
				delete tmp_objcts
				unhide tmp_sel
				select tmp_sel
				undo str on (
					for obj in selection where isProperty obj #isConcentricCircles and classof obj.baseobject == SplineShape do (
						if str == "Set interpolation" then
							obj.steps = spnSteps.value
						else (
							update_geom obj
						)
					)
				)
				undo_continues = false
			)
		)
		
		
		on spnSteps changed val do (
			for obj in selection where classof obj.baseobject == SplineShape do (
				if not undo_continues then undo_begin()
				obj.steps = val
			)
		)
		on spnSteps entered do (
			if undo_continues then undo_end "Set interpolation"
		)
		
		
		on spnNumCircles changed val do (
			for obj in selection where isProperty obj #isConcentricCircles and classof obj.baseobject == SplineShape do (
				if not undo_continues then undo_begin()
				update_geom obj
			)
		)
		on spnNumCircles entered do (
			if undo_continues then undo_end "Set Num Circles"
		)
		
		
		on spnStartRadius changed val do (
			for obj in selection where isProperty obj #isConcentricCircles and classof obj.baseobject == SplineShape do (
				if not undo_continues then undo_begin()
				update_geom obj
			)
		)
		on spnStartRadius entered do (
			if undo_continues then undo_end "Set Start Radius"
		)
		
		
		on spnEndRadius changed val do (
			for obj in selection where isProperty obj #isConcentricCircles and classof obj.baseobject == SplineShape do (
				if not undo_continues then undo_begin()
				update_geom obj
			)
		)
		on spnEndRadius entered do (
			if undo_continues then undo_end "Set End Radius"
		)
		
		
		on create_shape pressed do (
			if not update_interface_fron_obj_values() then (
				-- если нет выделеного изменяемого объекта, то создать новый
				undo on (
					-- вычислить положение создания объекта по центру выделенного
					local centerPoint = [0,0,0]
					if selection.count>0 do centerPoint = selection.min + (selection.max - selection.min)/2
					-- Создать объект
					new_shape = SplineShape()
					new_shape.pos = centerPoint
					new_shape.steps = spnSteps.value
					-- Создать параметры в объекте для хранения данных о фигуре
					local attr = attributes attr (parameters main (isConcentricCircles type:#boolean)); custAttributes.add new_shape attr
					attr = attributes attr (parameters main (NumCircles type:#integer)); custAttributes.add new_shape attr
					attr = attributes attr (parameters main (StartRadius type:#float)); custAttributes.add new_shape attr
					attr = attributes attr (parameters main (EndRadius type:#float)); custAttributes.add new_shape attr
					new_shape.isConcentricCircles = true
					-- Создать геометрию внутри
					update_geom new_shape
					select new_shape
				)
			)
		)

		on Pankov_ConcentricCircles close do (
			setIniSetting (getmaxinifile()) "Pankov_ConcentricCircles" "WindowPos" (GetDialogPos Pankov_ConcentricCircles as string)
		)
	)
	
	on execute do
	(
		pos = getinisetting (getmaxinifile()) "Pankov_ConcentricCircles" "WindowPos"
		if pos!="" then CreateDialog Pankov_ConcentricCircles pos:(execute pos) else CreateDialog Pankov_ConcentricCircles
		update_interface_fron_obj_values()
	)
)