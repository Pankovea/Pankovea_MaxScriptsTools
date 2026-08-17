macroScript ExtractMapsFromArchive
	category:"#PankovScripts"
	toolTip:"Найти потерянные файлы, извлечь из архива/папки и переназначить"
	buttonText:"Extract Maps"
	icon: #("pankov_ExtractMissing", 1)
(
	local VERSION = "v0.1 (2026.08.16)"
	local iniFile = "$temp/ExtractMapsFromArchive.ini"
	local iniSection = getFilenameFile (getThisScriptFilename())
	local myRollout
    
	local extractMA_missingFiles = #()
	local extractMA_allMissingFiles = #()
	local extractMA_cancel = false

	-- Ожидаемые пути установки 7-Zip (для предупреждения в логе)
	local sevenZipPaths = #(
		"C:\\Program Files\\7-Zip\\7z.exe",
		"C:\\Program Files (x86)\\7-Zip\\7z.exe"
	)

	-------------------------------------------------------------------------
	-- i18n: general wrapper #PankovScripts-L10N.ms (protection against missing file)
	local L10N_VER = 1 -- Expected engine API version
	local L10N
	local thisScriptPath = getThisScriptFilename()
	local scriptBaseName = getFilenamePath thisScriptPath + getFilenameFile thisScriptPath
	local l10n_engine = getFilenamePath thisScriptPath + "#PankovScripts-L10N.ms"
	local l10n_en = Dictionary #(
		-- Messages
		"msgErrNoSource", "Specify an existing archive or folder!") #(
		"msgErrNoDest", "Specify the destination folder!") #(
		"msgErrEmptyList", "The list of missing files is empty.") #(
		"msgWarnNo7zip", "7-Zip not found. Expected: {0}\nArchives will be skipped.\nDownload: {1}") #(
		"msgBtnRunNo7z", "FIND → RELINK") #(
		"msgInfoSelectObj", "Select objects in the scene.") #(
		"msgInfoNoMatMissing", "No missing files found in the materials of the selected objects.") #(
		"msgInfoSelectFiles", "Select files in the list first.") #(
		"msgSelObjects", "Selected objects: {0}") #(
		"msgNoObjects", "Objects with these files were not found.") #(
		"msgLoadedMat", "Loaded: {0}\nSlot 1 — map\nSlot 2 — material") #(
		"msgNoMats", "Materials with these files were not found.") #(
		"msgResultNone", "Nothing found.") #(
		"msgResultSuccess", "Relinked from folder: {0}\nExtracted from archives: {1}\nRelinked in scene: {2}\nLeft missing: {3}\n\nSave the scene!") #(
		"msgResultNoRelink", "Extracted: {0}\n(relinking was not performed)") #(
		"msgErrEmptyListAll", "The list of assets is empty.") #(
		"msgInfoNoMatAll", "No assets found in the materials of the selected objects.") #(
		"msgCanceled", "Canceled by user.") #(

		"titleInfo", "Info") #(
		"titleError", "Error") #(
		"titleResult", "Result") #(
		"titleDone", "Done") #(
		"titleSuccess", "Success") #(
		
		"lblCountFormat", "Missing files: {0}") #(
		"lblCountAll", "All files: {0}") #(
		
		"stSearchMissing", "Searching for missing files...") #(
		"stMissing", "Missing: {0}") #(
		"stScanFolders", "Scanning folders...") #(
		"stScanFolder", "Scanning folder: {0}") #(
		"stRelinkFolder", "Relinking from folder...") #(
		"stCheck", "Checking: {0} ({1}/{2})") #(
		"stExtract", "Extracting: {0} ({1} files)") #(
		"stRelinkArchives", "Relinking from archives...") #(
		"stCanceled", "Canceled") #(
		"stReady", "Ready") #(
		"stPreparing", "Preparing...") #(
		"stTaken", "Taken from selection: {0}") #(
		"stExcluded", "Excluded files: {0}") #(
		"stSearchAll", "Searching for assets...") #(
		"stAssets", "Assets: {0}") #(
		-- Logs
		"logFound",          "Missing assets found: {0}") #(
		"logTakenFound",     "Taken from selection: found {0} missing assets") #(
		"logTakeSelectObj",  "Select objects in the scene.\n") #(
		"logFolderFiles",    "Files in folder: {0}") #(
		"logArchivesFound",  "Archives found: {0}") #(
		"logInArchive",      "In archive {0} found files: {1}") #(
		"logMissingFiles",   "Missing files: {0}") #(
		"logLeftMissing",    "Left missing after relink: {0}") #(
		"logStatsHeader",    "=== STATISTICS ===") #(
		"logStatTotal",      "Missing total\t: {0}") #(
		"logStatFolder",     "Relinked from folder\t: {0}") #(
		"logStatArchives",   "Extracted from archives\t: {0}") #(
		"logStatScene",      "Relinked in scene\t: {0}") #(
		"logStatNotFound",   "Not found\t: {0}") #(
		"logFoldersHeader",  "Folders where files were found:") #(
		"logArchivesHeader", "Archives where files were found:") #(
		"logItem",           "  - {0} ({1} files)") #(
		"logAllFound",       "Assets found: {0}") #(
		"logTakenFoundAll",  "Taken from selection: found {0} assets") #(
		"logAssets",         "Assets: {0}") #(
		"logLeftMissingAll", "Not relocated after relink: {0}") #(
		"logStatTotalAll",   "Assets total\t: {0}")

	-- Fallback (English only) for a missing or broken engine file.
	local L10N_Fallback = struct _L10N_Fallback (
		scriptBaseName,
		enDict = Dictionary #string,
		engineVer = L10N_VER,
		codes = #(),
		fn trMsg key args: = (
			local r = enDict[key]
			if args != unsupplied and args.count > 0 then
				for i = 1 to args.count do r = substituteString r ("{" + ((i - 1) as string) + "}") (args[i] as string)
			r
		),
		fn setLang code = true,
		fn applyRollout roll = true,
		fn applyRollouts arrOfRoll = true,
		fn langLabel code = code,
		fn registerDict code dict = true
	)
	-- Load the engine; on failure fall back to English (version check is inside).
	local L10N_struct = L10N_Fallback
	try (
		if doesFileExist l10n_engine then L10N_struct = fileIn l10n_engine
		L10N = L10N_struct scriptBaseName:scriptBaseName enDict:l10n_en engineVer:L10N_VER
	) catch (
		format ">>> L10N: %:%\n%\n" (getErrorSourceFileName()) (getErrorSourceFileLine()) (getCurrentException())
		L10N = L10N_Fallback scriptBaseName:scriptBaseName enDict:l10n_en
	)
	-- load ini setting
	L10N.setLang (getINISetting iniFile iniSection "Lang")
	-------------------------------------------------------------------------

	-- Имя файла из пути (с нормализацией "/" и отрезанием "[...")
	fn cleanFilename str_line =
	(
		if str_line == undefined or str_line.count == 0 then return ""
		local idx = findString str_line "["
		if idx != undefined then str_line = substring str_line 1 (idx-1)
		str_line = trimRight (trimLeft str_line)
		str_line = substituteString str_line "/" "\\"
		filenameFromPath str_line
	)

	-- Сцена (.max) — её не восстанавливаем
	fn isSceneMaxFile p =
	(
		(toLower (getFileNameType p)) == ".max"
	)

	fn isDirectory p =
	(
		try ((dotNetClass "System.IO.Directory").Exists p) catch (false)
	)

	fn isArchiveFile p =
	(
		local ext = toLower (getFileNameType p)
		(ext == ".zip" or ext == ".7z" or ext == ".rar")
	)

	-- Сбор всех файлов в папке (рекурсивно или нет)
	fn collectFiles root recursive =
	(
		local files = #()
		local dirs = #(root)
		local i = 1
		while i <= dirs.count do
		(
			local d = dirs[i]; i += 1
			for f in (getFiles (d + "\\*")) do append files f
			if recursive then
				for sd in (getDirectories (d + "\\*")) do append dirs sd
		)
		files
	)

	-- Имя архива без расширения (для папки maps\{имя архива}\)
	fn archiveBaseName p =
	(
		local n = filenameFromPath p
		local ext = getFileNameType p
		if ext.count > 0 then n = substring n 1 (n.count - ext.count)
		n
	)

	fn sevenZipPath =(
		for p in sevenZipPaths where doesFileExist(p) do return p
		""
	)

	-- Рекурсивно удаляет пустые папки (keepRoot не трогаем)
	fn removeEmptyDirs root keepRoot =
	(
		for sd in (getDirectories (root + "\\*")) do removeEmptyDirs sd keepRoot
		local hasFiles = (getFiles (root + "\\*")).count > 0
		local hasDirs = (getDirectories (root + "\\*")).count > 0
		if (not hasFiles) and (not hasDirs) and (root != keepRoot) then try (removeDirectory root) catch ()
	)

	-- Поиск потерянных ассетов через Asset Tracker
	fn scanMissingFiles =
	(
		local missing = #()
		try
		(
			ATSOps.Refresh()
			local m = #()
			ATSOps.GetFilesByFileSystemStatus #Missing &m
			for f in m do
				if not (isSceneMaxFile f) then append missing f
			local net = #()
			ATSOps.GetFilesByFileSystemStatus #NetworkPath &net
			for f in net do
				if (not (isSceneMaxFile f)) and (not (doesFileExist f)) then append missing f
		) catch ()
		missing
	)

	-- Поиск ВСЕХ файловых ассетов сцены (включая найденные)
	fn scanAllAssets =
	(
		local files = #()
		try
		(
			ATSOps.Refresh()
			local ok = #()
			ATSOps.GetFilesByFileSystemStatus #ok &ok
			for f in ok do if not (isSceneMaxFile f) then appendIfUnique files f
			local m = #()
			ATSOps.GetFilesByFileSystemStatus #Missing &m
			for f in m do if not (isSceneMaxFile f) then appendIfUnique files f
			local net = #()
			ATSOps.GetFilesByFileSystemStatus #NetworkPath &net
			for f in net do if not (isSceneMaxFile f) then appendIfUnique files f
		) catch ()
		files
	)

	-- Скан по режиму: все ассеты или только потерянные
	fn scanAssetsByMode all =
	(
		if all then scanAllAssets() else scanMissingFiles()
	)

	-- Запуск 7-Zip без окна консоли, возвращает #(exitCode, stdout, stderr)
	fn run7z args =
	(
		local psi = dotNetObject "System.Diagnostics.ProcessStartInfo"
		psi.FileName = sevenZipPath()
		psi.Arguments = args
		psi.UseShellExecute = false
		psi.RedirectStandardOutput = true
		psi.RedirectStandardError = true
		psi.CreateNoWindow = true
		local p = dotNetObject "System.Diagnostics.Process"
		p.StartInfo = psi
		if not (p.Start()) then return #(-1, "", "Failed to start 7z")
		local out = p.StandardOutput.ReadToEnd()
		local err = p.StandardError.ReadToEnd()
		p.WaitForExit()
		local code = p.ExitCode
		p.Dispose()
		#(code, out, err)
	)

	-- Переназначение одного файла на точный путь
	fn relinkOne orig newPath =
	(
		local ok = false
		try
		(
			ATSOps.ClearSelection()
			ATSOps.SelectFiles #(orig)
			if ATSOps.NumFilesSelected() > 0 do ok = ATSOps.SetPathOnSelection newPath
			ATSOps.ClearSelection()
		) catch ()
		ok
	)

	-- Переназначение группы файлов в одну папку (сохраняя имена файлов)
	fn relinkBatch origs folder =
	(
		local n = 0
		if origs.count > 0 then
		(
			try
			(
				ATSOps.ClearSelection()
				ATSOps.SelectFiles origs
				local selCount = ATSOps.NumFilesSelected()
				if selCount > 0 then
				(
					local ok = ATSOps.SetPathOnSelection folder
					if ok then n = selCount
				)
				ATSOps.ClearSelection()
			) catch ()
		)
		n
	)

	-- Использует ли материал заданный файл (по имени)
	fn materialUsesFile mat targetLower =
	(
		if mat == undefined then return false
		if isKindOf mat BitmapTexture then
		(
			local bmap = mat.filename
			if bmap != undefined and (toLower (cleanFilename bmap)) == targetLower then return true
			return false
		)
		local n = getNumSubTexmaps mat
		for i = 1 to n do
		(
			local sub = getSubTexmap mat i
			if sub != undefined and (materialUsesFile sub targetLower) then return true
		)
		if isKindOf mat MultiMaterial then
			for i = 1 to mat.numsubs do
				if mat[i] != undefined and (materialUsesFile mat[i] targetLower) then return true
		false
	)

	-- Возвращает #(материал-родитель, битмап) для заданного файла
	fn findMapAndParent mat targetLower =
	(
		if mat == undefined then return undefined
		if isKindOf mat BitmapTexture then
		(
			local bmap = mat.filename
			if bmap != undefined and (toLower (cleanFilename bmap)) == targetLower then return #(undefined, mat)
			return undefined
		)
		local n = getNumSubTexmaps mat
		for i = 1 to n do
		(
			local sub = getSubTexmap mat i
			if sub != undefined then
			(
				local r = findMapAndParent sub targetLower
				if r != undefined then return #(mat, r[2])
			)
		)
		if isKindOf mat MultiMaterial then
			for i = 1 to mat.numsubs do
			(
				local r = findMapAndParent mat[i] targetLower
				if r != undefined then return #(mat[i], r[2])
			)
		undefined
	)
	rollout extractRollout "Extract Missing Assets from Archive" width:500
	(
		group "Missing assets" (
			button btnRescan "Refresh missing list" width:150 height:24 across:3 align:#left
			button btnTakeSelected "Take from selection" width:150 height:24 align:#center
			checkbox chkOnlyMissing "Find only missing assets" align:#left checked:true offset:[5,5]\
				tooltip:"On: missing files only. Off: all scene assets."

			label lblCount "Missing files: 0" height:16 align:#left
			listbox lbxMissing items:#() height:13 width:475 multiSelect:true

			button btnSelScene "Select in scene" width:150 height:24 across:3 align:#left
			button btnLoadMat "Load to material editor" width:150 height:24 align:#center
			button btnExclude "Exclude from search" width:150 height:24 align:#right
		)
		group "Options" (
			label lblSource "Archive or folder for searching:" align:#left
			edittext edtSource text:"" width:350
			button btnBrowseFile "File" width:55 align:#right offset:[0, -26]
			button btnBrowseFolder "Folder" width:55 align:#right  offset:[-60, -26]

			label lblDest "Destination folder (maps):" align:#left
			edittext edtDest text:"" width:350 across:2
			button btnBrowseDest "..." width:40 align:#right

			checkbox chkRecursive "Search in subfolders" checked:true across:2
			checkbox chkRelink "Relink found files in the scene" checked:true align:#left
			checkbox chkRelinkInPlace "Relink in place" align:#left across:2 \
				tooltip:"On: relink found files in place without copying them to the destination folder (archives are always extracted)."
			checkbox chkKeepPath "Keep found folder/archive" align:#left checked:true \
				tooltip:"On: keep the parent folder/archive of the found texture. Off: put everything into the destination root."
		)
		button btnRun "FIND → EXTRACT → RELINK" height:40 width:475 align:#center
		
		button btnCancel "Cancel" height:20 width:140 align:#right visible:false offset:[0,-43]
		progressBar pbar width:475 height:14 visible:false color:(color 30 120 200)

		label lblStatus "Ready" height:16

		label lblLog "Log:" align:#left
		dotNetControl edtLog "System.Windows.Forms.RichTextBox" height:110 width:475

		group "About" (
			label lblVersion VERSION height:16 across:3 align:#left
			hyperLink hlnkGitHub "PankovEA @ github.com" align:#left offset:[0,3] \
				address:"https://github.com/Pankovea/Pankovea_MaxScriptsTools"
			dropdownlist drpLang items:#() width:120 align:#right visible:false
			hyperLink hlnkLangEngine "Download language Engine" align:#right offset:[0,-33] \
				address:"https://github.com/Pankovea/Pankovea_MaxScriptsTools/tree/main/usermacros/%23PankovScripts-L10N.ms"
			hyperLink hlnkLangRU "Download Russian Translate" align:#right offset:[0,-7] \
				address:"https://github.com/Pankovea/Pankovea_MaxScriptsTools/tree/main/usermacros/%23PankovScripts-ExtractMissingFromArchive.ru.ms"
		)

		fn refreshMissingList list =
		(
			lbxMissing.items = list
			lbxMissing.selection = 0
			if chkOnlyMissing.checked then
				lblCount.text = L10N.trMsg "lblCountFormat" args:#(list.count)
			else
				lblCount.text = L10N.trMsg "lblCountAll" args:#(list.count)
		)

		-- Дописать в лог с автопрокруткой вниз
		fn logText s =
		(
			edtLog.AppendText s
			--edtLog.SelectionStart = edtLog.TextLength
			edtLog.ScrollToCaret()
		)

		-- Строка статистики: колонки выравниваются таб-стопом (любой шрифт)
		fn logStatLine s =
		(
			edtLog.SelectionTabs = #(210)
			edtLog.AppendText s
			edtLog.ScrollToCaret()
		)

		-- Переключение кнопок во время работы
		fn setRunningUI running =
		(
			btnRun.visible = not running
			btnCancel.visible = running
			pbar.visible = running
		)

		fn getSelectedIndices =
		(
			local s = lbxMissing.selection
			local idxs = #()
			if s != 0 then
			(
				if classof s == Array then idxs = s else append idxs s
			)
			idxs
		)

		-- Создать папку вместе с родительскими папками
		fn ensureDir dir =
		(
			try ((dotNetClass "System.IO.Directory").CreateDirectory dir; true) catch ( false )
		)

		-- Скопировать файл с перезаписью (false при ошибке)
		fn copyFileOverwrite src dst =
		(
			try
			(
				(dotNetClass "System.IO.File").Copy src dst true
				true
			) catch ( false )
		)

		-- Подпапка папки назначения по имени родителя найденного файла.
		-- keepPath=true: только имя родителя (не весь путь); иначе корень назначения.
		fn destSubDir srcFull dest keepPath =
		(
			local dir = dest
			if keepPath then
			(
				local parent = getFilenamePath srcFull
				parent = trimRight parent "\\"
				if parent.count > 0 then
				(
					local pn = filenameFromPath parent
					if pn.count > 0 then dir = dest + "\\" + pn
				)
			)
			dir
		)

		-- Текст кнопки: без "EXTRACT" (Извлечь), если 7-Zip не найден
		fn refreshRunButton =
		(
			if sevenZipPath() == "" then btnRun.text = L10N.trMsg "msgBtnRunNo7z"
		)
		on extractRollout open do
		(
			-- настройка dotNet-лога: свойства применяются только после создания окна
			edtLog.ReadOnly = true
			edtLog.Multiline = true
			edtLog.WordWrap = true
			edtLog.ScrollBars = (dotNetClass "System.Windows.Forms.RichTextBoxScrollBars").Vertical
			edtLog.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
			edtLog.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 68 68 68
			edtLog.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 255 255 255

			-- очистка лога
			edtLog.text = ""

			-- язык интерфейса: показываем выбор только если есть другие языки
			if L10N.codes.count > 1 then
			(
				drpLang.visible = true
				hlnkLangEngine.visible = false
				hlnkLangRU.visible = false
				drpLang.items = for c in L10N.codes collect (L10N.langLabel c)
				local cur = findItem L10N.codes L10N.lang
				if cur > 0 then drpLang.selection = cur
				if L10N.lang != "en" do L10N.applyRollout extractRollout
			) else (
				drpLang.visible = false
				hlnkLangRU.visible = true
				hlnkLangEngine.visible = (classof L10N) == _L10N_Fallback
			)
			-- кнопка: без "EXTRACT", если 7-Zip не найден (после применения перевода)
			refreshRunButton()

			-- Предупреждение об отсутствии 7-Zip (если нужно) в лог при запуске
			local sevenZipPaths_str = ""
			for s in sevenZipPaths do sevenZipPaths_str += "\n" + s
			if sevenZipPath() == "" then logText ((L10N.trMsg "msgWarnNo7zip" args:#(sevenZipPaths_str, "https://www.7-zip.org/")) + "\n")

			if maxfilepath != "" then edtDest.text = maxfilepath + "maps"
			lblStatus.text = if chkOnlyMissing.checked then L10N.trMsg "stSearchMissing" else L10N.trMsg "stSearchAll"
			extractMA_allMissingFiles = scanAssetsByMode (not chkOnlyMissing.checked)
			extractMA_missingFiles = deepCopy extractMA_allMissingFiles
			refreshMissingList extractMA_missingFiles
			local logLine = if chkOnlyMissing.checked then L10N.trMsg "logFound" args:#(extractMA_allMissingFiles.count) else L10N.trMsg "logAllFound" args:#(extractMA_allMissingFiles.count)
			logText (logLine + "\n")
			lblStatus.text = if chkOnlyMissing.checked then L10N.trMsg "stMissing" args:#(extractMA_allMissingFiles.count) else L10N.trMsg "stAssets" args:#(extractMA_allMissingFiles.count)
		)

		on btnBrowseFile pressed do
			(local f = getOpenFileName types:"Archive|*.zip;*.7z;*.rar;*.*|All|*.*"; if f != undefined do edtSource.text = f)

		on btnBrowseFolder pressed do
			(local d = getSavePath(); if d != undefined do edtSource.text = d)

		on btnBrowseDest pressed do
			(local d = getSavePath(); if d != undefined do edtDest.text = d)

		on btnRescan pressed do
		(
			lblStatus.text = if chkOnlyMissing.checked then L10N.trMsg "stSearchMissing" else L10N.trMsg "stSearchAll"
			extractMA_allMissingFiles = scanAssetsByMode (not chkOnlyMissing.checked)
			extractMA_missingFiles = deepCopy extractMA_allMissingFiles
			refreshMissingList extractMA_missingFiles
			local logLine = if chkOnlyMissing.checked then L10N.trMsg "logFound" args:#(extractMA_allMissingFiles.count) else L10N.trMsg "logAllFound" args:#(extractMA_allMissingFiles.count)
			logText (logLine + "\n")
			lblStatus.text = if chkOnlyMissing.checked then L10N.trMsg "stMissing" args:#(extractMA_allMissingFiles.count) else L10N.trMsg "stAssets" args:#(extractMA_allMissingFiles.count)
		)

		on btnTakeSelected pressed do
		(
			local all = not chkOnlyMissing.checked
			local selObjs = selection as array
			if selObjs.count == 0 then
			(
				logText (L10N.trMsg "msgInfoSelectObj" + "\n")
				return false
			)
			-- всегда пересканируем по текущему режиму, чтобы галочка "Все ассеты" учитывалась
			extractMA_allMissingFiles = scanAssetsByMode all
			local newList = #()
			for i = 1 to extractMA_allMissingFiles.count do
			(
				local targetLower = toLower (cleanFilename extractMA_allMissingFiles[i])
				local used = false
				for o in selObjs do
				(
					local m = o.material
					if m != undefined and (materialUsesFile m targetLower) then
					(
						used = true
						exit
					)
				)
				if used then append newList extractMA_allMissingFiles[i]
			)
			if newList.count == 0 then
			(
				if all then
				(
					logText (L10N.trMsg "msgInfoNoMatAll" + "\n")
				)
				else
				(
					logText (L10N.trMsg "msgInfoNoMatMissing" + "\n")
				)
			)
			else
			(
				extractMA_missingFiles = deepCopy newList
				refreshMissingList extractMA_missingFiles
				local logLine = if all then L10N.trMsg "logTakenFoundAll" args:#(extractMA_missingFiles.count) else L10N.trMsg "logTakenFound" args:#(extractMA_missingFiles.count)
				logText (logLine + "\n")
				for f in extractMA_missingFiles do logText (f + "\n")
				lblStatus.text = L10N.trMsg "stTaken" args:#(extractMA_missingFiles.count)
			)
		)
		on btnSelScene pressed do
		(
			local idxs = getSelectedIndices()
			if idxs.count == 0 then
			(
				logText (L10N.trMsg "msgInfoSelectFiles" + "\n")
				return false
			)
			local targets = #()
			for idx in idxs do append targets (toLower (cleanFilename extractMA_missingFiles[idx]))
			local objsToSelect = #()
			for o in objects do
			(
				local m = o.material
				if m != undefined then
					for t in targets do
					(
						if materialUsesFile m t then
						(
							appendIfUnique objsToSelect o
							exit
						)
					)
			)
			if objsToSelect.count > 0 then
			(
				select objsToSelect
				logText ((L10N.trMsg "msgSelObjects" args:#(objsToSelect.count)) + "\n")
			)
			else logText (L10N.trMsg "msgNoObjects" + "\n")
		)

		on btnLoadMat pressed do
		(
			local idxs = getSelectedIndices()
			if idxs.count == 0 then
			(
				logText (L10N.trMsg "msgInfoSelectFiles" + "\n")
				return false
			)
			local loaded = 0
			local firstBitmap = undefined
			local firstMat = undefined
			for idx in idxs do
			(
				local t = toLower (cleanFilename extractMA_missingFiles[idx])
				for o in objects do
				(
					local m = o.material
					if m != undefined then
					(
						local r = findMapAndParent m t
						if r != undefined then
						(
							if firstBitmap == undefined then
							(
								firstBitmap = r[2]
								firstMat = r[1]
							)
							loaded += 1
							exit
						)
					)
				)
			)
			if firstBitmap != undefined then
			(
				meditMaterials[1] = firstBitmap
				if firstMat != undefined then meditMaterials[2] = firstMat
				logText ((L10N.trMsg "msgLoadedMat" args:#(loaded)) + "\n")
			)
			else logText (L10N.trMsg "msgNoMats" + "\n")
		)

		on btnExclude pressed do
		(
			local idxs = getSelectedIndices()
			if idxs.count == 0 then
			(
				logText (L10N.trMsg "msgInfoSelectFiles" + "\n")
				return false
			)
			sort idxs
			local rev = for i = idxs.count to 1 by -1 collect idxs[i]
			for i in rev do deleteItem extractMA_missingFiles i
			refreshMissingList extractMA_missingFiles
			lblStatus.text = L10N.trMsg "stExcluded" args:#(idxs.count)
		)
		on btnCancel pressed do
			(extractMA_cancel = true)

		on chkOnlyMissing changed state do
		(
			lblStatus.text = if state then L10N.trMsg "stSearchMissing" else L10N.trMsg "stSearchAll"
			extractMA_allMissingFiles = scanAssetsByMode (not state)
			extractMA_missingFiles = deepCopy extractMA_allMissingFiles
			refreshMissingList extractMA_missingFiles
			local logLine = if state then L10N.trMsg "logFound" args:#(extractMA_allMissingFiles.count) else L10N.trMsg "logAllFound" args:#(extractMA_allMissingFiles.count)
			logText (logLine + "\n")
			lblStatus.text = if state then L10N.trMsg "stMissing" args:#(extractMA_allMissingFiles.count) else L10N.trMsg "stAssets" args:#(extractMA_allMissingFiles.count)
		)

		on drpLang selected idx do
		(
			if classof L10N == _L10N_Fallback then return false
			local code = L10N.codes[idx]
			if code == undefined or code == L10N.lang then return false
			setINISetting iniFile iniSection "Lang" code
			L10N.setLang code
			-- применить перевод на месте, без пересоздания окна
			for roll in #(extractRollout) do (
				L10N.applyRollout roll
			)
			refreshRunButton()
			refreshMissingList extractMA_missingFiles
			lblStatus.text = L10N.trMsg "stReady"
		)

		on btnRun pressed do
		(
			setRunningUI true
			edtLog.text = ""
			pbar.value = 0
			lblStatus.text = L10N.trMsg "stPreparing"
			extractMA_cancel = false

			local srcPath = trimRight edtSource.text "\\"
			local destPath = trimRight edtDest.text "\\"
			local recursive = chkRecursive.checked
			local all = not chkOnlyMissing.checked

			if not (doesFileExist srcPath) then
			(
				messageBox (L10N.trMsg "msgErrNoSource" ) title:(L10N.trMsg "titleError")
				setRunningUI false
				return false
			)
			if destPath == "" then
			(
				messageBox (L10N.trMsg "msgErrNoDest" ) title:(L10N.trMsg "titleError")
				setRunningUI false
				return false
			)
			makeDir destPath

			if extractMA_missingFiles.count == 0 then
			(
				extractMA_allMissingFiles = scanAssetsByMode all
				if extractMA_allMissingFiles.count == 0 then
				(
					if all then (
						messageBox (L10N.trMsg "msgErrEmptyListAll") title:(L10N.trMsg "titleError")
					) else (
						messageBox (L10N.trMsg "msgErrEmptyList") title:(L10N.trMsg "titleError")
					)
					lblStatus.text = L10N.trMsg "stReady"
					setRunningUI false
					return false
				)
				extractMA_missingFiles = deepCopy extractMA_allMissingFiles
				refreshMissingList extractMA_missingFiles
			)

			local countLine = if all then L10N.trMsg "logAssets" args:#(extractMA_missingFiles.count) else L10N.trMsg "logMissingFiles" args:#(extractMA_missingFiles.count)
			logText (countLine + "\n")

			local missingResolved = for i = 1 to extractMA_missingFiles.count collect false
			local sourceIsFolder = isDirectory srcPath

			local archives = #()
			local fileNames = #()
			local filePaths = #()

			if sourceIsFolder then
			(
				lblStatus.text = L10N.trMsg "stScanFolders"
				pbar.value = 10
				local allFiles = #()
				local scanDirs = #(srcPath)
				local si = 1
				while si <= scanDirs.count do
				(
					local d = scanDirs[si]; si += 1
					local rel = ""
					if d.count > srcPath.count then rel = substring d (srcPath.count + 1) -1
					if rel.count > 0 and (substring rel 1 1) == "\\" then rel = substring rel 2 -1
					if rel.count == 0 then rel = filenameFromPath srcPath
					lblStatus.text = L10N.trMsg "stScanFolder" args:#(rel)
					windows.processPostedMessages()
					if extractMA_cancel then
					(
						logText ("\n" + L10N.trMsg "msgCanceled")
						lblStatus.text = L10N.trMsg "stCanceled"
						setRunningUI false
						return false
					)
					for f in (getFiles (d + "\\*")) do append allFiles f
					if recursive then
						for sd in (getDirectories (d + "\\*")) do append scanDirs sd
				)
				for f in allFiles do
				(
					if isArchiveFile f then
						append archives f
					else
					(
						local nm = toLower (filenameFromPath f)
						if (findItem fileNames nm) == 0 then
						(
							append fileNames nm
							append filePaths f
						)
					)
				)
				logText ((L10N.trMsg "logFolderFiles" args:#(allFiles.count)) + "\n")
				logText ((L10N.trMsg "logArchivesFound" args:#(archives.count)) + "\n")
			)
			else
				append archives srcPath

			-- 1) Прямое переназначение из папки (если файл уже лежит в папке).
			--    По умолчанию найденные файлы копируются в папку назначения;
			--    при включённом "Relink in place" — только переназначаются на месте.
			local directRelinked = 0
			local folderFound = #()
			local dirN = 0
			if (chkRelink.checked or (not chkRelinkInPlace.checked)) and filePaths.count > 0 then
			(
				lblStatus.text = L10N.trMsg "stRelinkFolder"
				for i = 1 to extractMA_missingFiles.count do
				(
					dirN += 1
					if mod dirN 100 == 0 then
					(
						windows.processPostedMessages()
						if extractMA_cancel then
						(
							logText ("\n" + L10N.trMsg "msgCanceled")
							lblStatus.text = L10N.trMsg "stCanceled"
							setRunningUI false
							return false
						)
					)
					if not missingResolved[i] then
					(
						local nm = toLower (cleanFilename extractMA_missingFiles[i])
						local idx = findItem fileNames nm
						if idx != 0 then
						(
							local srcFull = filePaths[idx]
							local target = srcFull
							local copiedOK = false
							if not chkRelinkInPlace.checked then
							(
								local tdir = destSubDir srcFull destPath chkKeepPath.checked
								target = tdir + "\\" + (filenameFromPath srcFull)
								if (toLower srcFull) == (toLower target) then
									copiedOK = true
								else
								(
									copiedOK = (ensureDir tdir) and (copyFileOverwrite srcFull target)
									-- если копирование не удалось — переназначаем как раньше, на место находки
									if not copiedOK then target = srcFull
								)
							)
							local relinkOK = false
							if chkRelink.checked then relinkOK = relinkOne extractMA_missingFiles[i] target
							if relinkOK or (copiedOK and (not chkRelink.checked)) then
							(
								missingResolved[i] = true
								directRelinked += 1
								local fd = getFilenamePath filePaths[idx]
								local pi = 0
								for k = 1 to folderFound.count do
									if folderFound[k][1] == fd then (pi = k; exit)
								if pi == 0 then
									append folderFound #(fd, 1)
								else
									folderFound[pi][2] += 1
							)
						)
					)
				)
			)
			pbar.value = 40

			-- 2) Извлечение из архивов в папку назначения (архивы извлекаются всегда)
			local extractDirs = #()
			local foundArchives = #()
			if archives.count > 0 then
			(
				local toExtract = #()
				for i = 1 to extractMA_missingFiles.count do
				(
					if not missingResolved[i] then
					(
						local clean = cleanFilename extractMA_missingFiles[i]
						if (findItem toExtract clean) == 0 then append toExtract clean
					)
				)

				if toExtract.count > 0 then
				(
					-- 7-Zip не установлен: архивы пропускаем, предупреждаем в логе
					if sevenZipPath() == "" then
					(
						logText ((L10N.trMsg "msgWarnNo7zip" args:#(sevenZipPaths as string, "https://www.7-zip.org/")) + "\n")
					)
					else
					(
					local ai = 0
					for ar in archives do
					(
						ai += 1
						windows.processPostedMessages()
						if extractMA_cancel then
						(
							logText ("\n" + L10N.trMsg "msgCanceled")
							lblStatus.text = L10N.trMsg "stCanceled"
							setRunningUI false
							return false
						)
						local adisplay = filenameFromPath ar
						local archLabel = adisplay
						if sourceIsFolder then
						(
							local adir = getFilenamePath ar
							local rel = ""
							if adir.count > srcPath.count then rel = substring adir (srcPath.count + 1) -1
							if rel.count > 0 and (substring rel 1 1) == "\\" then rel = substring rel 2 -1
							if rel.count > 0 then archLabel = rel + "\\" + adisplay
						)

						lblStatus.text = L10N.trMsg "stCheck" args:#(archLabel, ai, archives.count)
						pbar.value = 40 + (40.0 * ai / archives.count)

						-- Полный список содержимого архива (-slt), пропускаем первую запись (сам архив)
						local listArgs = "l \"" + ar + "\" -r -spd -slt -bso1 -bsp0"
						local lres = run7z listArgs
						local storedPaths = #()
						local gotFirst = false
						for line in (filterString lres[2] "\n") do
						(
							if (matchPattern line pattern:"Path = *") then
							(
								if not gotFirst then
									gotFirst = true
								else
								(
									local sp = trimRight (substring line 8 -1) "\r"
									if sp.count > 0 then append storedPaths sp
								)
							)
						)

						-- Сопоставляем имена потерянных файлов с содержимым архива
						local matchedStored = #()
						for clean in toExtract do
						(
							local c = toLower clean
							for sp in storedPaths do
							(
								local spName = toLower (filenameFromPath (substituteString sp "/" "\\"))
								if spName == c and (findItem matchedStored sp) == 0 then append matchedStored sp
							)
						)

						if matchedStored.count > 0 then
						(
							-- Куда извлекать каждый файл: папка назначения (+ подпапка родителя при "Keep found folder/archive")
							local targets = #() -- #(storedPath, targetDir, targetFullPath)
							for sp in matchedStored do
							(
								local spWin = substituteString sp "/" "\\"
								local fname = filenameFromPath spWin
								local tdir = destSubDir spWin destPath chkKeepPath.checked
								append targets #(sp, tdir, tdir + "\\" + fname)
							)

							-- Группируем по целевой папке, чтобы извлекать один раз на папку
							local groups = #() -- #(targetDir, #(storedPaths))
							for t in targets do
							(
								local gi = 0
								for k = 1 to groups.count do
									if groups[k][1] == t[2] then (gi = k; exit)
								if gi == 0 then append groups #(t[2], #(t[1]))
								else append groups[gi][2] t[1]
							)

							lblStatus.text = L10N.trMsg "stExtract" args:#(archLabel, matchedStored.count)
							for g in groups do
							(
								ensureDir g[1]
								appendIfUnique extractDirs g[1]
								local incArgs = ""
								for sp in g[2] do incArgs += " \"" + sp + "\""
								local args = "e \"" + ar + "\" -o\"" + g[1] + "\"" + incArgs + " -r -y -aos -spd -bso1 -bsp0"
								run7z args
							)

							local foundInThis = 0
							for t in targets do
								if doesFileExist t[3] then foundInThis += 1
							if foundInThis > 0 then
							(
								append foundArchives #(adisplay, foundInThis)
								logText ((L10N.trMsg "logInArchive" args:#(adisplay, foundInThis)) + "\n")
							)
						)
					)

					-- убрать оставшиеся пустые папки
					removeEmptyDirs destPath destPath
					)
				)
			)
			pbar.value = 80

			-- 3) Переназначение извлечённых файлов
			local extractedCount = 0
			local relinkedCount = 0
			if chkRelink.checked and extractDirs.count > 0 then
			(
				lblStatus.text = L10N.trMsg "stRelinkArchives"
				local edN = 0
				for ed in extractDirs do
				(
					edN += 1
					windows.processPostedMessages()
					if extractMA_cancel then
					(
						logText ("\n" + L10N.trMsg "msgCanceled")
						lblStatus.text = L10N.trMsg "stCanceled"
						setRunningUI false
						return false
					)
					local group = #()
					for i = 1 to extractMA_missingFiles.count do
					(
						if not missingResolved[i] then
						(
							local clean = cleanFilename extractMA_missingFiles[i]
							if doesFileExist (ed + "\\" + clean) then
							(
								append group extractMA_missingFiles[i]
								missingResolved[i] = true
								extractedCount += 1
							)
						)
					)
					if group.count > 0 then relinkedCount += relinkBatch group ed
				)
				ATSOps.Refresh()
			)

			pbar.value = 100
			lblStatus.text = L10N.trMsg "stReady"

			-- Повторный подсчёт оставшихся потерянных
			local leftMissing = 0
			if chkRelink.checked then
			(
				try
				(
					local m2 = #()
					ATSOps.GetFilesByFileSystemStatus #Missing &m2
					for f in m2 do
						if not (isSceneMaxFile f) then leftMissing += 1
					local n2 = #()
					ATSOps.GetFilesByFileSystemStatus #NetworkPath &n2
					for f in n2 do
						if (not (isSceneMaxFile f)) and (not (doesFileExist f)) then leftMissing += 1
				) catch ()
				local leftLine = if all then L10N.trMsg "logLeftMissingAll" args:#(leftMissing) else L10N.trMsg "logLeftMissing" args:#(leftMissing)
				logText (leftLine + "\n")
			)

			local notFound = 0
			for i = 1 to extractMA_missingFiles.count do
				if not missingResolved[i] then notFound += 1

			logText ("\n" + L10N.trMsg "logStatsHeader" + "\n")
			local totalLine = if all then L10N.trMsg "logStatTotalAll" args:#(extractMA_missingFiles.count) else L10N.trMsg "logStatTotal" args:#(extractMA_missingFiles.count)
			logStatLine (totalLine + "\n")
			logStatLine ((L10N.trMsg "logStatFolder" args:#(directRelinked)) + "\n")
			logStatLine ((L10N.trMsg "logStatArchives" args:#(extractedCount)) + "\n")
			logStatLine ((L10N.trMsg "logStatScene" args:#(relinkedCount)) + "\n")
			logStatLine ((L10N.trMsg "logStatNotFound" args:#(notFound)) + "\n")

			if folderFound.count > 0 then
			(
				logText (L10N.trMsg "logFoldersHeader" + "\n")
				for p in folderFound do logText ((L10N.trMsg "logItem" args:#(p[1], p[2])) + "\n")
			)

			setRunningUI false
		)

		on extractRollout close do
		(
			try
			(
				local p = getDialogPos extractRollout
				setINISetting iniFile iniSection "PosX" (p.x as string)
				setINISetting iniFile iniSection "PosY" (p.y as string)
				if L10N != undefined then setINISetting iniFile iniSection "Lang" L10N.lang
			) catch ()
		)
	)

	on execute do
	(
		-- язык из настроек (до создания окна)
		if L10N != undefined do
		(
			local saved = getINISetting iniFile iniSection "Lang"
			if saved != "" and (findItem L10N.codes saved) != 0 then L10N.setLang saved
			-- заголовок окна на текущем языке
			try ( extractRollout.title = L10N.trMsg "extractRollout" ) catch ()
		)
		try (destroyDialog extractRollout) catch()
		-- сохранённая позиция окна загружается ДО создания и передаётся в pos:
		local loadedPos = undefined
		try
		(
			local px = getINISetting iniFile iniSection "PosX"
			local py = getINISetting iniFile iniSection "PosY"
			if px != "" and py != "" then loadedPos = [px as integer, py as integer]
		) catch ()
		if loadedPos != undefined then createDialog extractRollout pos:loadedPos
		else createDialog extractRollout
	)
)
