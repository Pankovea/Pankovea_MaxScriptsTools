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