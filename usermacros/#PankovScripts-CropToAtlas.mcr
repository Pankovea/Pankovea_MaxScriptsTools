-- CropToAtlas version 1.1
-- 17.05.2021
-- added CoronaBitmap Support

macroScript CropToAtlas category:"#PankovScripts" buttontext:"CropToAtlas" tooltip:"CropToAtlas - Convert xml to crop" icon:#("Patches", 1)
(
	global MapToAtlasRollout
	
	try(destroyDialog MapToAtlasRollout) catch()
	
	rollout MapToAtlasRollout "Crop To Atlas" width:500
	(
		local xmlDoc,Atlas,TextureArray,modTag
		
		group "Texture Packer GenericXML"
		(
			editText edtXML "" text:"" width:410 across:2 align:#left readOnly:true
			button btnPickXML "Browse..."  align:#right width:64
			
			checkbox chExtChk "Change extention of atlas image" checked:true across:2
			radioButtons atlasExt "" labels:#(".JPG",".PNG") default:1 columns:1 align:#left Enabled:true
			
			checkbox nrmSufChk "Use normal suffix for maps" checked:false across:2  
			editText AtlNrmSuf "Atlas file suffix:" text:"_n.jpg" width:230 across:2  align:#left readOnly:true
			editText MapNrmSuf "Maps suffix:" text:"_NRM.jpg" width:230  align:#right readOnly:true
			button btnMapList "Maps info" width:230 across:2 align:#left
			button btnMap "Crop Selected To Atlas" width:230 across:2 align:#right
		)
		
		fn commandPanelRedraw bool =
		(
			WM_SETREDRAW=0xB
			
			commandHWND = windows.getChildHWND #max "Command Panel"	 
			if bool then
			(
				windows.sendmessage commandHWND[1]  WM_SETREDRAW 1 0  -- enable
			)
			else
			(
				windows.sendmessage commandHWND[1]  WM_SETREDRAW 0 0 -- disable
			)

		)
		
		--TextureStruct
		struct atlasTexture
		(
			name=undefined,
			x=undefined,
			y=undefined,
			w=undefined,
			h=undefined,
			r=undefined
		)
		
		--SAVES ALL CONTROLS TO AN INI
		fn SaveControlSettings thisRol thisINI =
		(
			for c in thisRol.controls do
			(
				case classof c of
				(
					SpinnerControl : setINISetting thisINI thisRol.name c.name (c.value as string)
					EditTextControl : setINISetting thisINI thisRol.name c.name c.text
					CheckboxControl : setINISetting thisINI thisRol.name c.name (c.checked as string)
					ComboBoxControl : setINISetting thisINI thisRol.name c.name (c.selection as string)
					ColorPickerControl : setINISetting thisINI thisRol.name c.name (c.color as string)
				)
			)
		)
	
		--LOADS ALL CONTROLS FROM AN INI
		fn LoadControlSettings thisRol thisINI =
		(
			if doesFileExist thisINI do
			(
				for c in thisRol.controls do
				(
					local cName 
					
					try(cName = c.Name)catch(cName = "")
					
					local controlValue = getINISetting thisINI thisRol.name cName
					
					if controlValue != "" do
					(
						case classof c of
						(
							SpinnerControl : c.value = controlValue as number
							EditTextControl : c.text = controlValue
							CheckboxControl : c.checked = controlValue as BooleanClass
							ComboBoxControl : c.selection = controlValue as number
							ColorPickerControl : c.color = execute (controlValue)
						)
					)
				)
			)
		)
			
		fn BrowseForFolder editBox captionText initDir:maxFilePath =
		(
			dir = getSavePath caption:("Please locate this folder: " + captionText) initialDir:initDir
			if dir != undefined do
			(
				setIniSetting (getMaxINIFile()) "MapToAtlasSettings" captionText dir
				editBox.text = dir
			)
		)
		
		--CREATE A STRUCT TO HOLD THE MATERIAL AND IT'S MATERIAL ID
		struct matAndID
		(
			mat,
			id
		)

		--THIS FUNCTION APPLIES A UV CROP TEXTURE TO AN MATERIAL
		fn ApplyBitmapCrop tex sheetWidth sheetHeight x y w h r nrmFile =
		(
			--GET THE PERCENT ON THE NEW SPRITE ATLUS
			if tex.apply == off then (
				uOffset = ((x+.5)/sheetWidth)
				vOffset = ((y+.5)/sheetHeight)
				wOffset = ((w-1)/sheetWidth) --1-((sheetWidth-w)/sheetWidth)
				hOffset = ((h-1)/sheetHeight) --1-((sheetHeight-h)/sheetHeight)
			)else(
				uOffset = (x/sheetWidth) + (tex.clipu * (w/sheetWidth))
				vOffset = (y/sheetHeight) + (tex.clipv * (h/sheetHeight))
				wOffset = (w/sheetWidth) * tex.clipw
				hOffset = (h/sheetHeight) * tex.cliph
			)
			if nrmFile != "" then (
				tex.filename = nrmFile
			) else (
				if chExtChk.enabled then (
					case atlasExt.state of (
					1: tex.filename = ((getFilenamePath edtXML.text) + (getFilenameFile Atlas.name) + ".jpg")
					2: tex.filename = ((getFilenamePath edtXML.text) + (getFilenameFile Atlas.name) + ".png")
					)
				)else(
					tex.filename = ((getFilenamePath edtXML.text) + Atlas.name)
				)
			)
			tex.apply = on
			tex.clipu = uOffset
			tex.clipv = vOffset
			tex.clipw = wOffset
			tex.cliph = hOffset
			tex.coords.W_angle = r
			tex.filtering = 1
		)

		fn ApplyCoronaBitmapCrop tex sheetWidth sheetHeight x y w h r nrmFile =
		(
			--GET THE PERCENT ON THE NEW SPRITE ATLUS
			if tex.clippingOn == off then (
				uOffset = ((x+.5)/sheetWidth)
				vOffset = ((y+.5)/sheetHeight)
				wOffset = ((w-1)/sheetWidth) --1-((sheetWidth-w)/sheetWidth)
				hOffset = ((h-1)/sheetHeight) --1-((sheetHeight-h)/sheetHeight)
			)else(
				uOffset = (x/sheetWidth) + (tex.clippingU * (w/sheetWidth))
				vOffset = (y/sheetHeight) + (tex.clippingV * (h/sheetHeight))
				wOffset = (w/sheetWidth) * tex.clippingWidth
				hOffset = (h/sheetHeight) * tex.clippingHeight
			)
			if nrmFile != "" then (
				tex.filename = nrmFile
			) else (
				if chExtChk.enabled then (
					case atlasExt.state of (
					1: tex.filename = ((getFilenamePath edtXML.text) + (getFilenameFile Atlas.name) + ".jpg")
					2: tex.filename = ((getFilenamePath edtXML.text) + (getFilenameFile Atlas.name) + ".png")
					)
				)else(
					tex.filename = ((getFilenamePath edtXML.text) + Atlas.name)
				)
			)
			tex.clippingOn = on
			tex.clippingU = uOffset
			tex.clippingV = vOffset
			tex.clippingWidth = wOffset
			tex.clippingHeight = hOffset
			tex.wAngle = r
			-- tex.interpolation = 1
		)
		
		fn GetBitmapTextures theObjects = 
		(
			texMaps = #()
			for obj in theObjects do
			(
				join texMaps (getClassInstances bitmapTexture target:obj asTrackViewPick:off)
				join texMaps (getClassInstances CoronaBitmap target:obj asTrackViewPick:off)
			)
			makeUniqueArray texMaps
		)

		fn mapObjToAtlas obj =
		(
			
			objMaps = (GetBitmapTextures obj)
			
			for tex in objMaps do (
				--IF WE FIND THE TEXTURE IN THE TEXTURE ATLAS ARRAY MAP THE OBJ
				if tex.filename != undefined do
				(
					tName = filenameFromPath tex.Filename
				
					for t in TextureArray do
					(
						local functionName = "ApplyBitmapCrop"
						local rot
						case classof tex of (
							Bitmaptexture: functionName = "ApplyBitmapCrop"
							CoronaBitmap: functionName = "ApplyCoronaBitmapCrop" 
						)
						print functionName
						if t.r == "y" then rot = -90 else rot = 0
						if matchPattern tName pattern:t.name ignoreCase:true do
							case functionName of
							(	"ApplyBitmapCrop": ApplyBitmapCrop tex Atlas.w Atlas.h t.x t.y t.w t.h rot ""
								"ApplyCoronaBitmapCrop": ApplyCoronaBitmapCrop tex Atlas.w Atlas.h t.x t.y t.w t.h rot ""
							)
						if nrmSufChk.checked then (
							atlNameSuf = (getFilenameFile t.name) + MapNrmSuf.text --+ (getFilenameType t.name)
							atlNrmFile = 	(getFilenamePath edtXML.text) + (getFilenameFile Atlas.name) + AtlNrmSuf.text --+ (getFilenameType Atlas.name)
							if matchPattern tName pattern:atlNameSuf ignoreCase:true do
							case functionName of
							(	"ApplyBitmapCrop": ApplyBitmapCrop tex Atlas.w Atlas.h t.x t.y t.w t.h rot atlNrmFile
								"ApplyCoronaBitmapCrop": ApplyCoronaBitmapCrop tex Atlas.w Atlas.h t.x t.y t.w t.h rot atlNrmFile
							)
						)
					)
				)
			)
		)

		fn loadXML thisDoc =
		(
			--CLEAR THE VARIABLES
			Atlas = undefind
			TextureArray = #()
			
			if doesFileExist thisDoc do
			(
				--LOAD XML FROM DISK
				xmlDoc = dotNetObject "system.xml.xmlDocument"
				xmlDoc.load thisDoc
				
				--GET ATLAS PROPERTIES
				docEle = xmlDoc.documentElement
				atlasAttributes = docEle.attributes
				Atlas = atlasTexture name:((atlasAttributes.ItemOf "imagePath").value) w:((atlasAttributes.ItemOf "width").value as float) h:((atlasAttributes.ItemOf "height").value as float)
				
				--GET TEXTURE PROPERTIES
				TextureElements = docEle.GetElementsByTagName "sprite"
				for i = 0 to TextureElements.count-1 do
				(
					texAttributes = TextureElements.item[i].attributes
					try (
						texNode = atlasTexture name:((texAttributes.ItemOf "n").value) x:((texAttributes.ItemOf "x").value as float) y:((texAttributes.ItemOf "y").value as float) w:((texAttributes.ItemOf "w").value as float) h:((texAttributes.ItemOf "h").value as float) r:((texAttributes.ItemOf "r").value)
					)catch(
						texNode = atlasTexture name:((texAttributes.ItemOf "n").value) x:((texAttributes.ItemOf "x").value as float) y:((texAttributes.ItemOf "y").value as float) \
					w:((texAttributes.ItemOf "w").value as float) h:((texAttributes.ItemOf "h").value as float)
					)
					append TextureArray texNode
				)
			)
		)
		
	
		on MapToAtlasRollout open do
		(
			clearlistener()
			
			--CREAT THE TEMP ATTRIBUTE TO ATTACH TO TEMP MODS, USED TO DELTE THEM LATER
			modTag = attributes tag ( parameters tagparams (tempMod type:#float default:0) )
			
			--LOAD DIRECTORIES
			LoadControlSettings MapToAtlasRollout "$temp/MapToAtlasRollout.ini"
			
			RollPos = getIniSetting (getMaxINIFile()) "MapToAtlasSettings" "WindowPos"
			if RollPos != "" and RollPos != undefined do
			(
				if not keyboard.escPressed do SetDialogPos MapToAtlasRollout (execute RollPos)
			)
			
			loadXML edtXML.text
			
		)
		
		on MapToAtlasRollout close do
		(
			SaveControlSettings MapToAtlasRollout "$temp/MapToAtlasRollout.ini"
			
			RollPos = GetDialogPos MapToAtlasRollout
			setIniSetting (getMaxINIFile()) "MapToAtlasSettings" "WindowPos" (RollPos as string)
		)
		
		on btnPickXML pressed do
		(
			-- serch maps folder
			local p=""
			if doesfileexist (maxfilepath+"maps\\") then p=(maxfilepath+"maps\\") else 
				(
					local a = filterstring maxfilepath "\\"
					for i in 1 to (a.count - 1) do p = p + a[i]+"\\"
					p=p+"maps\\"
				)
			--
			XMLFile = getOpenFileName caption:"Open an XML File" filename:(if (doesfileexist p) then p else maxfilepath) types:"XML File(*.xml)|*.xml" historyCategory:"MaxScript"
			
			if XMLFile != undefined do
			(
				edtXML.text = XMLFile
				loadXML edtXML.text
			)
		)

		fn showInfo m title:"Maps Info" width: 260 =
		(
			global AtlasMapsInfo
			try(DestroyDialog AtlasMapsInfo)catch()	
			global szStat = m
			global iWidth = width
	
			rollout AtlasMapsInfo title
			(
				edittext edtStat "" height: 260 width: iWidth offset: [-15, -2] readOnly: true
				button btnCopy "Copy" align: #left width: 50 across: 2
				button btnOK "Ok" align: #right  width: 35
				
				on btnOK pressed do try(DestroyDialog AtlasMapsInfo)catch()
				on AtlasMapsInfo open do edtStat.text = szStat	
				on btnCopy pressed do setClipBoardText (stripTab edtStat.text)
				
			)

			createDialog AtlasMapsInfo width 295
		)
		
		on btnMapList pressed do
		(
			local textinfo = ""
			objMaps = GetBitmapTextures selection
			listed = sort(for i in objMaps collect (if i.filename != undefined then filenamefrompath i.filename else ""))
			listed = makeuniquearray listed
			for map in listed do textinfo = textinfo + map + "\n"
			
			--print (listed as string)-- textinfo
			showInfo textinfo
			
		)
		
		on btnMap pressed do with undo "Crop To Atlas" on
		(
			max create mode

			loadXML edtXML.text
			
			if edtXML.text != "" do
			(
				selObjects = getCurrentSelection()
				
				for obj in selObjects do with redraw off
				(
					
					mapObjToAtlas obj
				)
				
				select selObjects
				
				try(destroyDialog AtlasMapsInfo) catch()
				try(destroyDialog MapToAtlasRollout) catch()
			)
		)
		
		on nrmSufChk changed theState do
		(
			if nrmSufChk.checked  then
			(
				AtlNrmSuf.readOnly = false
				MapNrmSuf.readOnly = false
			) else (
				AtlNrmSuf.readOnly = true
				MapNrmSuf.readOnly = true
			)
		)

		on chExtChk changed theState do
		(
			if chExtChk.checked  then
			(
				atlasExt.enabled = true
			) else (
				atlasExt.enabled = false
			)
		)
		
	)	
	
	createDialog MapToAtlasRollout
	
) --end script