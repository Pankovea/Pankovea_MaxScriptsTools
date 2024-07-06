macroScript Pankov_Copy category:"#PankovScripts" buttontext:"Copy" tooltip:"COPY-paste selected to temporary file" icon:#("PhysX_Main", 25) (
	local FileBuffer = getdir #AutoBack + "\\CopyPaste.max"
	
	on isenabled return (
		selection.count > 0
	)

	on execute do (
		if doesFileExist FileBuffer then deletefile FileBuffer
		saveNodes $ FileBuffer
	)
)

macroScript Pankov_Paste category:"#PankovScripts" buttontext:"Paste" tooltip:"copy-PASTE from temporary file. With Ctrl to clear" icon:#("PhysX_Main", 26) (
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