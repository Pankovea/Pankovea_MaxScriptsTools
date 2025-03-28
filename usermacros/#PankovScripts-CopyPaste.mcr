macroScript Pankov_Copy
category:"#PankovScripts"
buttontext:"Copy"
tooltip:"COPY-paste selected to temporary file"
icon:#("pankov_CopyPaste", 1)
(
	local FileBuffer = getdir #AutoBack + "\\CopyPaste.max"
	
	on isenabled return (
		selection.count > 0
	)

	on execute do (
		if doesFileExist FileBuffer then deletefile FileBuffer
		saveNodes $ FileBuffer
	)
)

macroScript Pankov_Paste
category:"#PankovScripts"
buttontext:"Paste"
tooltip:"copy-PASTE from temporary file. With Ctrl to clear"
icon:#("pankov_CopyPaste", 2)
(
	local FileBuffer = getdir #AutoBack + "\\CopyPaste.max"	
	
	on isenabled return (
		doesFileExist FileBuffer
	)

	on execute do
	(
		if keyboard.controlPressed == false then (
			mergemaxfile FileBuffer #select #mergeDups --#useSceneMtlDups
		) else (
			deletefile FileBuffer
		)
	)
)

macroScript Pankov_Copy_Modif
category:"#PankovScripts"
buttontext:"CopyMod"
tooltip:"COPY-paste Modifier"
icon:#("pankov_CopyPaste", 1)
(
	global Pankov_Copy_Modif_buffer
	
	on isenabled return (
		superclassof (modpanel.getCurrentObject()) == modifier
	)

	on execute do (
		local modif = modpanel.getCurrentObject()
		if superclassof modif == modifier then Pankov_Copy_Modif_buffer = modif
		print (format "Copy modif '%' is " modif.name)
	)
)

macroScript Pankov_Paste_Modif
category:"#PankovScripts"
buttontext:"PasteMod"
tooltip:"copy-PASTE Modifier"
icon:#("pankov_CopyPaste", 2)
(
	global Pankov_Copy_Modif_buffer
	
	on isenabled return (
		selection.count > 0 and Pankov_Copy_Modif_buffer != undefined
	)

	on execute do (
		-- Стандартная функция. добвляет сверху выделенного модификатора
		if Pankov_Copy_Modif_buffer != undefined then modpanel.addModToSelection Pankov_Copy_Modif_buffer
		-- Своя функция. добавляет снизу выделенного модификатора
		/*
		local sel = selection as array
		local i = 0
		local modif = modpanel.getCurrentObject()
		for obj in selection where finditem #(GeometryClass, shape) (superclassof obj) > 0 do (
			if superclassof modif == modifier then i = finditem obj.modifiers modif
			addmodifier obj Pankov_Copy_Modif_buffer before:i
		)
		deselect $*
		select sel
		max modify mode
		*/
		completeRedraw()
	)
)
