macroScript Pankov_ConcentricCircles
category:"#PankovScripts"
buttontext:"ConcentricCirclesShape"
tooltip:"Create Concentric Circles Shape"
icon:#("ViewportNavigationControls",42)
(
	rollout Pankov_ConcentricCircles "Concentric Circles Parameters"
	(
		spinner spnSteps "Interpolation:" type:#integer range:[1,100,16]
        spinner spnNumCircles "Number of Circles:" type:#integer range:[2,100,10] scale:1
        spinner spnStartRadius "Start Radius:" type:#float range:[1,10000,100] scale:10
        spinner spnEndRadius "End Radius:" type:#float range:[1,10000,1000] scale:10
		button create_shape "Create/update shape" toolTip:"" width:130
	
		function update_geom obj =
		(	local radiusStep = (spnEndRadius.value - spnStartRadius.value) / (spnNumCircles.value - 1)
			
			-- clear old splines
			for i = numSplines obj to 1 by -1 do deleteSpline obj i

			for i = 1 to spnNumCircles.value do
			(	addNewSpline obj
				local currentRadius = spnStartRadius.value + (i - 1) * radiusStep
				local angleStep = 360.0 / 4
				for j = 0 to 3 do
				(
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
			obj.NumCircles = spnNumCircles.value
			obj.StartRadius = spnStartRadius.value
			obj.EndRadius = spnEndRadius.value
		)
		on spnSteps changed val do (
			try (
				if selection.count==1 and classof selection[1].baseobject == SplineShape do selection[1].steps = val
			) catch ()
		)
		on spnNumCircles changed val do (
			try (
				if selection[1].isConcentricCircles do update_geom selection[1]
			) catch ()
		)
		on spnStartRadius changed val do (
			try (
				if selection[1].isConcentricCircles do update_geom selection[1]
			) catch ()
		)
		on spnEndRadius changed val do (
			try (
				if selection[1].isConcentricCircles do update_geom selection[1]
			) catch ()
		)
		
		on create_shape pressed do (
			local updated = false
			try (
				if selection.count==1 and selection[1].isConcentricCircles then (
					spnNumCircles.value = selection[1].NumCircles
					spnStartRadius.value = selection[1].StartRadius
					spnEndRadius.value = selection[1].EndRadius
					updated = true
				) 
			) catch ()
			
			if not updated then (
				undo on (
					local centerPoint = [0,0,0]
					if selection.count>0 do centerPoint = selection.min + (selection.max - selection.min)/2
					new_shape = SplineShape()
					new_shape.pos = centerPoint
					new_shape.steps = spnSteps.value
					local attr = attributes attr (parameters main (isConcentricCircles type:#boolean)); custAttributes.add new_shape attr
					attr = attributes attr (parameters main (NumCircles type:#integer)); custAttributes.add new_shape attr
					attr = attributes attr (parameters main (StartRadius type:#float)); custAttributes.add new_shape attr
					attr = attributes attr (parameters main (EndRadius type:#float)); custAttributes.add new_shape attr
					new_shape.isConcentricCircles = true
					new_shape.NumCircles = spnNumCircles.value
					new_shape.StartRadius = spnStartRadius.value
					new_shape.EndRadius = spnEndRadius.value
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
		try (
			if selection.count==1 and selection[1].isConcentricCircles then (
				Pankov_ConcentricCircles.spnNumCircles.value = selection[1].NumCircles
				Pankov_ConcentricCircles.spnStartRadius.value = selection[1].StartRadius
				Pankov_ConcentricCircles.spnEndRadius.value = selection[1].EndRadius
			) 
		) catch ()
	)
)