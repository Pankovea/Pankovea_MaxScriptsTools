/*
* -------------------------------------------------------------------------------------------
* Batch Views Manager
* https://github.com/Pankovea
* Pankovea 2024-2026
* -------------------------------------------------------------------------------------------
*
* АРХИТЕКТУРА
* ================
* Общее состояние живёт в переменных уровня макроса (префикс g_),
* свитки обмениваются данными напрямую через них.
* Одно поведение = одна функция. owner-цепочки отсутствуют.
*
* РАЗРЕШЕНИЕ
* ===============
* Глобальный масштаб (slider) — единый множитель для всех видов:
* фактическое разрешение вида = база x масштаб.
* Исходное разрешение хранится в ИМЕНИ batch view как база: "CamA (1920x1080)".
* для точного восстановления.
* Смена камеры читает разрешение из её видов (getCamResFromViews).
*
* РАСЧЁТ / ОКРУГЛЕНИЕ / ПРИЛИПАНИЕ (Snap)
* =========================================
* 1. РАСЧЁТ:  фактическое = база x g_globalScale (resFromBase).
*    Смена пропорции с Preserve MegaPix:
*      W' = sqrt(MP * ratio),  H' = sqrt(MP / ratio),  где MP = W * H.
*    Без Preserve MegaPix: H' = W / ratio (ширина сохраняется).
* 2. ПРИЛИПАНИЕ К СПИСКУ СТАНДАРТНЫХ РАЗРЕШЕНИЙ (findClosestStandardResolution):
*    в g_standardResolutions ищется запись с той же пропорцией (аспект в пределах
*    g_aspectTolerance) и мегапикселями, отличающимися от целевых не более чем на
*    g_mpSnapThreshold (большой допуск). Прилипло — берём стандарт целиком.
* 3. УМНОЕ ОКРУГЛЕНИЕ (calculateSmartResolution), если список не прилип:
*    — W округляется к кратному g_gridW (32, допуск 16), иначе к кратному 8 (допуск 4);
*    — аспект притягивается к ближайшему из g_standardAspects (g_aspectTolerance);
*    — H = W / аспект, затем кратно g_gridH (16, допуск 8).
* 4. Галка "Snap" (по умолчанию ВКЛ, сохраняется в INI): включает/выключает
*    конвейер 2-3 целиком. Единая точка входа — snapResolution(w, h).
*
*   parseViewName()        — база из имени вида
*   viewNameFor()          — имя с базой из w/h
*   getCleanViewName()     — имя без суффикса базы
*   getViewBase()          — база вида (имя → разрешение вида → render)
*   setViewBase()          — переименовать вид + обновить width/height
*   getCamResFromViews()   — разрешение камеры из её видов
*   applyCamResToScene()   — загрузить разрешение камеры в сцену
*   applyGlobalScale()     — применить глобальный масштаб ко всем видам
*   syncViewsForCam()      — синхронизировать виды камеры ('Base size': база / текущий)
*   snapResolution()       — конвейер снэпа: список стандартов → округление (галка Snap)
*   findClosestStandardResolution() — прилипание к g_standardResolutions
*   calculateSmartResolution()      — округление к сетке 32/16 и стандартному аспекту
*
* СИНХРОНИЗАЦИЯ ВИДОВ (sync)
* ==========================
* Флаг "sync_batch_views" в user props камеры — ТОЛЬКО поведение, не разрешение.
* При включённом флаге изменение разрешения одного вида распространяется на все виды
* с этой камерой. По умолчанию ВЫКЛЮЧЕН.
* Что распространяется, зависит от галки "Base size":
*   ON  — база (как в полях при Base size);
*   OFF — текущий (масштабированный) размер.
*
* ПЕРЕИМЕНОВАНИЕ КАМЕРЫ
* =====================
* renameCamera() — переименовать узел камеры, затем find/replace старого имени
* в названиях видов этой камеры (только если старое имя найдено в названии).
*
* ГРУППЫ ВИДОВ
* ============
* Разделители "----- Группа N -----". Перемещаются/удаляются как блок.
* Сворачивание по двойному клику: ▶ свёрнута / ▼ развёрнута.
*
* СВИТКИ
* ======
*   roll_Cams   "Cameras"                     — камеры + параметры + rename + create view
*   roll_batch  "Batch Views"                 — виды + база разрешения + sync + render output
*   roll_global "Global Batch Views Settings" — global scale + пути
*   roll_states "Manage Scene States"         — scene states: список/apply/save/new/rename/delete
*
* ЦЕПОЧКА ИНИЦИАЛИЗАЦИИ
* =====================
*   showUI()
*     → local roll_Cams / roll_batch / roll_global / roll_states — свитки на уровне макроса
*     → g_roll_cams/batch/global/states = <свиток> — ссылки для кросс-доступа
*     → addRollout roll_Cams   → on open: initCamListBox, relist_cams, change_active
*     → addRollout roll_batch  → on open: initListBox, list_views, set scale checkbox state
*     → addRollout roll_global → on open: восстановить scale
*     → addRollout roll_states → on open: refreshStates
*/
macroScript Pankovea_BatchViewsManager
	category:     "#PankovScripts"
	ButtonText:   "Batch Views Manager"
	tooltip:      "Manage Cameras and render batch views"
	silentErrors: false
	icon:         #("extratools", 1)
(
	--------------------------------------------------------------
	-- SHARED STATE (уровень макроса, обмен между свитками)
	--------------------------------------------------------------
	local g_floater
	local g_dialog_width = 250
	local g_roll_cams
	local g_roll_batch
	local g_roll_global
	local g_roll_states
	local g_last_opened_tab = "Cams"
	local g_accordion_lock = false

	-- камеры
	local g_active_cam
	local g_cam_list = #()          -- массив камер (node)
	local g_curr_itm = 1

	-- batch views
	local g_visibleIndices = #()    -- UI-индекс -> реальный индекс batch view
	local g_batch_view
	local g_view_name = ""
	local g_view_path = undefined
	local g_active_view = undefined
	local PROP_COLLAPSED = "▶"
	local PROP_EXPANDED = "▼"

	-- глобальный масштаб разрешения
	local g_globalScale = 1.0
	local g_scaleValues = #(0.25, 1.0/3.0, 0.5, 2.0/3.0, 1.0, 1.25, 1.5, 2.0, 3.0)

	-- снэп разрешений (галка "Snap")
	local g_snap = true

	-- стандартные пропорции и разрешения для умного округления
	local g_standardAspects = #(
		1.0,
		4.0/3.0, 3.0/2.0, 16.0/10.0, 16.0/9.0, 2.0, 21.0/9.0,
		3.0/4.0, 2.0/3.0, 5.0/8.0, 9.0/16.0, 1.0/2.0
	)
	local g_aspectTolerance = 0.01
	local g_gridW = 32
	local g_gridH = 16
	local g_gridTolerance = 16
	local g_standardResolutions = #(
		-- VGA / SD
		#(640, 480), #(720, 480), #(720, 576),
		-- HD
		#(960, 540), #(1024, 768), #(1280, 720), #(1280, 960), #(1600, 900), #(1600, 1200),
		-- Full HD
		#(1920, 1080), #(1920, 1200), #(2048, 1536),
		-- QHD / 2K
		#(2560, 1440), #(2560, 1600), #(2560, 1080),
		-- 4K
		#(3840, 2160), #(3840, 2400), #(4096, 2160), #(4096, 1716), #(4096, 3112),
		-- 5K / 6K
		#(5120, 2880), #(5120, 3200), #(5760, 3240),
		-- 8K
		#(7680, 4320), #(7680, 4800),
		-- Print (A6/A5/A4/A3 @ 300dpi, portrait + landscape)
		#(1240, 1748), #(1748, 1240), #(1748, 2480), #(2480, 1748),
		#(2480, 3508), #(3508, 2480), #(3508, 4961), #(4961, 3508), #(4961, 7016),
		-- Photo
		#(3000, 2000), #(4000, 3000), #(6000, 4000), #(8000, 6000)
	)
	local g_mpSnapThreshold = 0.10

	-- пресеты пропорций для dropdown (1 = Free, не фиксирует пропорции)
	local g_presetRatios = #(0.0, 1.0, 3.0/2.0, 4.0/3.0, 16.0/10.0, 16.0/9.0, 2.0, 21.0/9.0, sqrt(2.0))
	local g_presetNames = #("Free", "1:1", "3:2", "4:3", "16:10", "16:9", "2:1", "21:9", "A серия")

	-- результат диалога удаления группы
	local g_deleteGroupResult = 0

	--------------------------------------------------------------
	-- ДАННЫЕ BATCH VIEW (для перемещения позиций)
	--------------------------------------------------------------
	struct viewData (
		name, enabled, overridePreset, startFrame, endFrame,
		width, height, pixelAspect, outputFilename,
		camera, sceneStateName, presetFile
	)

	--------------------------------------------------------------
	--( КАРТА СВОЙСТВ КАМЕР
	-- camPropMap: тип камеры → (generic name → real property name)
	-- #unsuplyed = параметр не поддерживается для этого типа
	--
	-- UI-параметры (маппятся в uiPropMap внутри roll_Cams):
	--   #focal_length, #specify_fov, #use_dof, #f_number,
	--   #auto_tilt, #iso, #exposure_value
	-- Структурные (внутренние, НЕ в uiPropMap):
	--   #exposure_mode — свойство режима ISO/EV (0=ISO, 1=EV)
	-- Разрешение в v2 НЕ хранится на камере — только в batch views.
	--------------------------------------------------------------
	local g_camPropMap = Dictionary #(
		#physical, Dictionary #(
			#focal_length, #focal_length_mm) #(
			#specify_fov, #specify_fov) #(
			#use_dof, #use_dof) #(
			#f_number, #f_number) #(
			#auto_tilt, #auto_vertical_tilt_correction) #(
			#iso, #iso) #(
			#exposure_value, #exposure_value) #(
			#exposure_mode, #exposure_gain_type)
	) #(
		#corona, Dictionary #(
			#focal_length, #focalLength) #(
			#use_dof, #enableDof) #(
			#f_number, #fStop) #(
			#auto_tilt, #autoVerticalTilt) #(
			#iso, #iso) #(
			#exposure_value, #unsuplyed) #(
			#exposure_mode, #unsuplyed)
	) #(
		#vray, Dictionary #(
			#focal_length, #focal_length) #(
			#specify_fov, #specify_fov) #(
			#use_dof, #use_dof) #(
			#f_number, #f_number) #(
			#auto_tilt, #lens_tilt_auto) #(
			#iso, #ISO) #(
			#exposure_value, #exposure_value) #(
			#exposure_mode, #exposure)
	)

	-- Определить тип камеры как ключ для g_camPropMap
	fn getCameraTypeKey cam = (
		case (classOf cam) of (
			Physical:           #physical
			CoronaCam:          #corona
			VRayPhysicalCamera: #vray
			default:            undefined
		)
	)
	-- Прочитать свойство камеры по generic name.
	-- Возвращает значение или undefined если не поддерживается.
	fn getCamProp cam genericName = (
		local typeKey = getCameraTypeKey cam
		if typeKey == undefined do return undefined
		if not (HasDictValue g_camPropMap typeKey) do return undefined
		local typeDict = g_camPropMap[typeKey]
		if not (HasDictValue typeDict genericName) do return undefined
		local realName = typeDict[genericName]
		if realName == #unsuplyed do return undefined
		if isProperty cam realName then getProperty cam realName else undefined
	)

	-- Записать свойство камеры по generic name.
	fn setCamProp cam genericName val = (
		local typeKey = getCameraTypeKey cam
		if typeKey == undefined do return false
		if not (HasDictValue g_camPropMap typeKey) do return false
		local typeDict = g_camPropMap[typeKey]
		if not (HasDictValue typeDict genericName) do return false
		local realName = typeDict[genericName]
		if realName == #unsuplyed do return false
		if isProperty cam realName then setProperty cam realName val
	)

	-- Проверить поддержку параметра для типа камеры.
	fn isCamPropSupported cam genericName = (
		local typeKey = getCameraTypeKey cam
		if typeKey == undefined do return false
		if not (HasDictValue g_camPropMap typeKey) do return false
		local typeDict = g_camPropMap[typeKey]
		if not (HasDictValue typeDict genericName) do return false
		typeDict[genericName] != #unsuplyed
	)
	--) Конец КАРТА СВОЙСТВ КАМЕР
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( СПИСОК КАМЕР
	-- Compares two cameras by name for sorting (alphabetical order)
	fn compareCamNames a b = case of (
		(a.name < b.name): -1
		(a.name > b.name): 1
		default: 0
	)

	-- Получить отсортированный по имени список видимых камер сцены
	fn getCameraList = (
		local ls = for cam in cameras where (isKindOf cam camera) and not cam.isHidden collect cam
		qsort ls compareCamNames
		ls
	)
	--) Конец СПИСОК КАМЕР
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( УМНОЕ ОКРУГЛЕНИЕ
	fn roundToNearestMultiple value multiple = (
		if multiple <= 0 then return value
		local remainder = mod value multiple
		local half = multiple / 2.0
		if remainder < half then value - remainder else value + (multiple - remainder)
	)

	fn tryRoundToMultiple value multiple tolerance = (
		local nearest = roundToNearestMultiple value multiple
		if abs(value - nearest) <= tolerance then nearest else value
	)

	fn findStandardAspect ratio = (
		local closest = undefined
		local minDiff = 999999.0
		for asp in g_standardAspects do (
			local diff = abs(ratio - asp)
			if diff < minDiff then (minDiff = diff; closest = asp)
		)
		if closest != undefined and minDiff <= g_aspectTolerance then closest else undefined
	)

	fn findClosestStandardResolution targetW targetH = (
		local targetMP = targetW as float * targetH as float
		local targetAspect = targetW as float / targetH as float
		local bestRes = undefined
		local bestDiff = 999999.0
		for res in g_standardResolutions do (
			-- Снэп только к стандарту с близкой пропорцией (защита аспекта)
			local aspect = res[1] as float / res[2] as float
			if abs(aspect - targetAspect) <= g_aspectTolerance then (
				local stdMP = res[1] as float * res[2] as float
				local diff = abs(stdMP - targetMP) / targetMP
				if diff < bestDiff then (bestDiff = diff; bestRes = res)
			)
		)
		if bestRes != undefined and bestDiff <= g_mpSnapThreshold then bestRes else #(targetW, targetH)
	)
	
	fn calculateSmartResolution w h = (
		local newW = w
		local newH = h
		newW = tryRoundToMultiple w g_gridW g_gridTolerance
		if newW == w then newW = tryRoundToMultiple w 8 4
		local currentAspect = w as float / h as float
		local stdAspect = findStandardAspect currentAspect
		local useAspect = if stdAspect != undefined then stdAspect else currentAspect
		newH = (newW / useAspect) as integer
		newH = tryRoundToMultiple newH g_gridH (g_gridTolerance / 2)
		#(newW, newH, stdAspect != undefined)
	)

	-- Конвейер снэпа: сначала список стандартных разрешений (большой допуск по MP,
	-- аспект защищён), если не прилипло — умное округление к сетке/пропорции.
	-- При выключенной галке Snap значения возвращаются без изменений.
	fn snapResolution w h = (
		if w == undefined or h == undefined then return #(w, h)
		if not g_snap then return #(w as integer, h as integer, false)
		local std = findClosestStandardResolution w h
		if std[1] == w and std[2] == h then calculateSmartResolution w h else #(std[1], std[2], false)
	) 
	--) Конец УМНОЕ ОКРУГЛЕНИЕ
	--------------------------------------------------------------

	
	--------------------------------------------------------------
	--( ИМЯ ВИДА И БАЗА РАЗРЕШЕНИЯ
	-- База хранится в имени вида как суффикс " (WxH)".

	-- Собрать имя вида из чистого имени и базы.
	-- При масштабе 100%: "CamA", иначе "CamA (50% of 1920x1080)".
	fn viewNameFor baseName w h = (
		local scale = if g_globalScale == undefined then 1.0 else g_globalScale
		if abs(scale - 1.0) < 0.001 then baseName else (
			baseName + " (" + ((scale * 100) as integer) as string + "% of " + \
			(w as integer) as string + "x" + (h as integer) as string + ")"
		)
	)

	-- Разобрать имя вида: #(cleanName, w, h, scale). w/h = 0 если базы нет,
	-- scale = 1.0 если масштаб в имени не указан.
	-- Поддерживает форматы "CamA (1920x1080)" и "CamA (50% of 1920x1080)".
	fn parseViewName viewName = (
		if viewName == undefined or viewName == "" then return #("", 0, 0, 1.0)
		local patternPercent = "\\(\\s*(\\d+)\\s*%\\s*of\\s+(\\d+)\\s*x\\s*(\\d+)\\s*\\)\\s*$"
		local regexPercent = dotNetObject "System.Text.RegularExpressions.Regex" patternPercent
		local m = regexPercent.Match viewName
		if m.Success then (
			local pct = m.Groups.Item[1].Value as integer
			local w = m.Groups.Item[2].Value as integer
			local h = m.Groups.Item[3].Value as integer
			local clean = regexPercent.Replace viewName ""
			#(trimRight clean, w, h, (pct as float) / 100.0)
		) else (
			local pattern = "\\(\\s*(\\d+)\\s*x\\s*(\\d+)\\s*\\)\\s*$"
			local regex = dotNetObject "System.Text.RegularExpressions.Regex" pattern
			local match = regex.Match viewName
			if match.Success then (
				local w = match.Groups.Item[1].Value as integer
				local h = match.Groups.Item[2].Value as integer
				local clean = regex.Replace viewName ""
				#(trimRight clean, w, h, 1.0)
			) else (
				#(viewName, 0, 0, 1.0)
			)
		)
	)

	-- Имя вида без суффикса базы
	fn getCleanViewName viewName = (
		local data = parseViewName viewName
		if data[1] == "" then "View" else data[1]
	)

	-- База вида: из имени (приоритет), иначе из его разрешения, иначе из render.
	fn getViewBase the_view = (
		if the_view == undefined then return #(0, 0)
		local data = parseViewName the_view.name
		if data[2] > 0 and data[3] > 0 then return #(data[2], data[3])
		if the_view.overridePreset and the_view.width > 0 and the_view.height > 0 then return #(the_view.width, the_view.height)
		#(renderWidth, renderHeight)
	)
	
	-- Фактическое разрешение = база x глобальный масштаб (с умным округлением)
	fn resFromBase w h = (
		local scale = if g_globalScale == undefined then 1.0 else g_globalScale
		if abs(scale - 1.0) < 0.001 then #(w as integer, h as integer) else (
			local rawW = (w as float * scale) as integer
			local rawH = (h as float * scale) as integer
 			local smart = snapResolution rawW rawH
			#(smart[1], smart[2])
		)
	)

	--------------------------------------------------------------
	--( ХЕЛПЕРЫ ИМЁН BATCH VIEWS

	-- Уникально ли имя среди всех batch views (исключая excludeView)
	fn isViewNameUnique name excludeView = (
		if name == undefined or name == "" then return false
		for i = 1 to batchRenderMgr.NumViews do (
			local v = batchRenderMgr.GetView i
			if v != undefined and v != excludeView and v.name == name then return false
		)
		true
	)

	-- Уникальное имя: baseName, baseName_2, baseName_3, ...
	fn getUniqueViewName baseName excludeView = (
		local candidate = baseName
		local counter = 2
		while not (isViewNameUnique candidate excludeView) do (
			candidate = baseName + "_" + (counter as string)
			counter += 1
		)
		candidate
	)

	-- Безопасно установить имя виду с проверкой уникальности (без ошибок дублирования)
	fn safeSetViewName the_view newName = (
		if the_view == undefined then return false
		if the_view.name == newName then return true
		local finalName = newName
		if not (isViewNameUnique newName the_view) then (
			local clean = getCleanViewName newName
			local data = parseViewName newName
			finalName = getUniqueViewName clean the_view
			if data[2] > 0 and data[3] > 0 then finalName = viewNameFor finalName data[2] data[3]
		)
		the_view.name = finalName
		true
	)
	--) Конец ХЕЛПЕРЫ ИМЁН BATCH VIEWS
	--------------------------------------------------------------

	-- Переименовать вид с новой базой + обновить width/height (с учётом масштаба)
	fn setViewBase the_view w h = (
		if the_view == undefined or w == undefined or h == undefined do return false
		if w <= 0 or h <= 0 do return false
		local clean = getCleanViewName the_view.name
		safeSetViewName the_view (viewNameFor clean w h)
		the_view.overridePreset = true
		local scaled = resFromBase w h
		the_view.width = scaled[1]
		the_view.height = scaled[2]
		true
	)
	--) Конец ИМЯ ВИДА И БАЗА РАЗРЕШЕНИЯ
	--------------------------------------------------------------

	-- Скопировать разрешение w/h с учётом ориентации вида (портрет/альбом)
	fn orientedCopyResForView the_view w h = (
		local base = getViewBase the_view
		if base[1] > 0 and base[2] > 0 and base[1] != base[2] then (
			local srcIsLand = w >= h
			local viewIsLand = base[1] >= base[2]
			if srcIsLand != viewIsLand then return #(h, w)
		)
		#(w, h)
	)
	--) Конец ИМЯ ВИДА И БАЗА РАЗРЕШЕНИЯ
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( ГРУППЫ ВИДОВ
	-- Определить, является ли имя именем группы (содержит "-----")
	fn isGroupName gr_name = (
		(findString gr_name "-----") != undefined
	)

	-- Проверить, является ли batch view группой (разделителем)
	fn isGroupView v = isGroupName v.name

	-- Убрать префикс ▶/▼ из имени группы: "▼ Group_1" → "Group_1"
	fn stripCollapsePrefix n = (
		if n == undefined then return n
		local c = substring n 1 1
		if c == PROP_COLLAPSED or c == PROP_EXPANDED then substring n 2 -1 else n
	)

	-- Проверить, уникально ли имя группы (с учётом ▶/▼ префикса)
	fn isGroupNameAvailable gr_name = (
		local stripped = stripCollapsePrefix gr_name
		for i = 1 to batchRenderMgr.NumViews do (
			local v = batchRenderMgr.GetView i
			if isGroupName v.name and stripCollapsePrefix v.name == stripped do return false
		)
		true
	)

	-- Вернуть #(startIdx, endIdx) группы, содержащей realIdx
	fn getGroupBounds realIdx = (
		local gv = batchRenderMgr.GetView
		local num = batchRenderMgr.numViews
		local startIdx = realIdx
		for i = realIdx to 1 by -1 do (
			if isGroupView (gv i) do (startIdx = i; exit)
		)
		local endIdx = num
		for i = (startIdx + 1) to num do (
			if isGroupView (gv i) do (endIdx = i - 1; exit)
		)
		#(startIdx, endIdx)
	)

	-- Собрать данные всех batch views в массив
	fn collectAllViewData = (
		for i = 1 to batchRenderMgr.numViews collect (
			local v = batchRenderMgr.GetView i
			viewData v.name v.enabled v.overridePreset v.startFrame v.endFrame \
				v.width v.height v.pixelAspect v.outputFilename v.camera \
				v.sceneStateName v.presetFile
		)
	)

	-- Пересоздать batch views из массива данных
	fn rebuildBatchViews allData = (
		local num = batchRenderMgr.numViews
		for i = num to 1 by -1 do batchRenderMgr.DeleteView i
		for vd in allData do (
			local new_v = batchRenderMgr.CreateView vd.camera
			if new_v != undefined then (
				new_v.name = vd.name
				new_v.enabled = vd.enabled
				new_v.overridePreset = vd.overridePreset
				new_v.startFrame = vd.startFrame
				new_v.endFrame = vd.endFrame
				new_v.width = vd.width
				new_v.height = vd.height
				new_v.pixelAspect = vd.pixelAspect
				new_v.outputFilename = vd.outputFilename
				new_v.sceneStateName = vd.sceneStateName
				new_v.presetFile = vd.presetFile
			)
		)
	)

	-- Разбить плоский массив viewData на массив групп
	-- Каждый разделитель (с "-----" в имени) начинает новую группу
	fn splitIntoGroups allData = (
		local groups = #()
		local current = #()
		for vd in allData do (
			if isGroupName vd.name then (
				if current.count > 0 do append groups current
				current = #(vd)
			) else (
				append current vd
			)
		)
		if current.count > 0 do append groups current
		groups
	)

	-- Найти индекс группы, содержащую вид с плоским индексом realIdx
	fn findGroupForView groups realIdx = (
		local flatIdx = 0
		for i = 1 to groups.count do (
			for vd in groups[i] do (
				flatIdx += 1
				if flatIdx == realIdx do return i
			)
		)
		0
	)

	-- Пересоздать batch views из массива групп
	fn rebuildFromGroups groups = (
		local flat = #()
		for grp in groups do for vd in grp do append flat vd
		rebuildBatchViews flat
	)
	--) Конец ГРУППЫ ВИДОВ
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( НАТИВНОЕ ОКНО BATCH RENDER
	-- Закрыть нативное окно Batch Render (Win32 API)
	fn close_batch_window = (
		local batch_window = windows.getChildHWND 0 "Batch Render" parent:#max
		if batch_window != undefined and batch_window[4] == "#32770" do (
			windows.sendMessage batch_window[1] 0x0010 0 0
			return true
		)
		false
	)
	--) Конец НАТИВНОЕ ОКНО BATCH RENDER
	--------------------------------------------------------------
	
	--------------------------------------------------------------
	--( ПЕРЕМЕЩЕНИЕ ВИДОВ / ГРУПП

	-- Переместить batch view из позиции from_idx в позицию to_idx
	fn move_view_index from_idx to_idx = (
		close_batch_window()
		if from_idx == to_idx or from_idx < 1 or to_idx < 1 then return false
		local num = batchRenderMgr.numViews
		if from_idx > num or to_idx > num then return false
		local allData = collectAllViewData()
		local item = allData[from_idx]
		deleteItem allData from_idx
		insertItem item allData to_idx
		rebuildBatchViews allData
		true
	)

	-- Проверить, можно ли двигать группу, содержащую realIdx
	fn canMoveGroup realIdx direction = (
		local allData = collectAllViewData()
		local groups = splitIntoGroups allData
		local srcIdx = findGroupForView groups realIdx
		if srcIdx == 0 do return false
		local hasSeparator = isGroupName groups[srcIdx][1].name
		if not hasSeparator do return false
		if direction == #up do (
			if srcIdx <= 1 do return false
			return isGroupName groups[srcIdx - 1][1].name
		)
		if direction == #down do return srcIdx < groups.count
		false
	)

	-- Переместить группу, содержащую realIdx, в направлении direction
	fn moveGroup realIdx direction = (
		close_batch_window()
		local allData = collectAllViewData()
		local groups = splitIntoGroups allData
		local srcIdx = findGroupForView groups realIdx
		if srcIdx == 0 do return false
		local dstIdx = srcIdx + (if direction == #up then -1 else 1)
		if dstIdx < 1 or dstIdx > groups.count do return false
		local temp = groups[srcIdx]
		groups[srcIdx] = groups[dstIdx]
		groups[dstIdx] = temp
		rebuildFromGroups groups
		true
	)
	--) Конец ПЕРЕМЕЩЕНИЕ ВИДОВ / ГРУПП
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( КАМЕРА <-> BATCH VIEWS

	-- Все batch views, использующие камеру
	fn getViewsForCam cam = (
		if cam == undefined then return #()
		local result = #()
		for i = 1 to batchRenderMgr.NumViews do (
			local v = batchRenderMgr.GetView i
			if v != undefined and v.camera == cam then append result v
		)
		result
	)

	-- Разрешение камеры из её batch views (база из имени). #(w, h) или #(0, 0)
	fn getCamResFromViews cam = (
		if cam == undefined or not (isValidNode cam) then return #(0, 0)
		local views = getViewsForCam cam
		local w = 0
		local h = 0
		for bv in views do (
			local base = parseViewName bv.name
			if base[2] > 0 and base[3] > 0 then (w = base[2]; h = base[3]; exit)
		)
		if w == 0 and views.count > 0 then (
			local bv = views[1]
			if bv.overridePreset and bv.width > 0 then (w = bv.width; h = bv.height)
		)
		#(w, h)
	)

	-- Загрузить разрешение камеры (база x масштаб) в renderWidth/Height.
	fn applyCamResToScene cam = (
		local base = getCamResFromViews cam
		if base[1] > 0 and base[2] > 0 then (
			local scaled = resFromBase base[1] base[2]
			if renderSceneDialog.isOpen() then renderSceneDialog.close()
			renderWidth = scaled[1]
			renderHeight = scaled[2]
			redrawViews()
		)
	)

	-- Загрузить фактическое разрешение вида в renderWidth/Height.
	fn applyViewToScene the_view = (
		if the_view == undefined then return false
		if the_view.overridePreset and the_view.width > 0 then (
			if renderSceneDialog.isOpen() then renderSceneDialog.close()
			renderWidth = the_view.width
			renderHeight = the_view.height
			redrawViews()
		)
	)

	-- Синхронизировать все виды камеры с источником.
	-- srcBase — база источника; srcCur — текущее (масштабированное) разрешение источника.
	-- Зависит от галки "Base size" (chk_edit_base):
	--   ON  — синхронизируется БАЗА (srcBase);
	--   OFF — синхронизируется ТЕКУЩИЙ размер: база пересчитывается делением srcCur на масштаб.
	fn syncViewsForCam cam srcBase srcCur = (
		if cam == undefined or not (isValidNode cam) then return 0
		close_batch_window()
		local scale = if g_globalScale == undefined then 1.0 else g_globalScale
		local baseW = srcBase[1] as integer
		local baseH = srcBase[2] as integer
		if not g_roll_batch.chk_edit_base.checked and abs(scale - 1.0) > 0.001 then (
			baseW = (srcCur[1] as float / scale) as integer
			baseH = (srcCur[2] as float / scale) as integer
			if baseW <= 0 or baseH <= 0 do return 0
		)
		local count = 0
		for bv in (getViewsForCam cam) do (
			if bv != undefined then (
				setViewBase bv baseW baseH
				count += 1
			)
		)
		count
	)

	-- Флаг sync камеры (user props "sync_batch_views")
	fn getCamSync cam = (
		if cam == undefined or not (isValidNode cam) then return false
		getUserProp cam "sync_batch_views" == true
	)

	-- Применить глобальный масштаб ко всем видам (affect-all всегда вкл).
	-- Меняет width/height у видов, у которых база записана в имени.
	-- Применить глобальный масштаб ко всем видам:
	-- width/height = база x масштаб, имя пересобирается с процентом масштаба
	fn applyGlobalScale = (
		close_batch_window()
		local count = 0
		for i = 1 to batchRenderMgr.NumViews do (
			local v = batchRenderMgr.GetView i
			if v != undefined and not (isGroupView v) then (
				local base = getViewBase v
				if base[1] > 0 and base[2] > 0 then (
					local scaled = resFromBase base[1] base[2]
					if not v.overridePreset then v.overridePreset = true
					v.width = scaled[1]
					v.height = scaled[2]
					v.name = viewNameFor (getCleanViewName v.name) base[1] base[2]
					count += 1
				)
			)
		)
		if g_roll_batch != undefined then (
			g_roll_batch.chk_override_preset.checked = true
			if abs(g_globalScale - 1.0) < 0.001 do g_roll_batch.chk_edit_base.checked = false
			g_roll_batch.updateOverrideUI()
		)
		count
	)
	--) Конец КАМЕРА <-> BATCH VIEWS
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( RENDER PRESETS

	-- Имена доступных render presets (.rps из папки $renderPresets)
	fn getRenderPresetNames = (
		local names = #()
		try (
			local files = getFiles "$renderPresets\\*.rps"
			for f in files do append names (getFilenameFile f)
		) catch ()
		if names.count == 0 then (
			try ( names = renderPresets.names ) catch ()
		)
		sort names
		names
	)

	-- Полный путь к .rps по имени пресета (или undefined)
	fn renderPresetFileForName name = (
		try (
			local f = "$renderPresets\\" + name + ".rps"
			if doesFileExist f then return f
		) catch ()
		undefined
	)
	--) Конец RENDER PRESETS
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( СОЗДАНИЕ / ПЕРЕИМЕНОВАНИЕ / ПУТИ

	-- Создать batch view для камеры. База = разрешение камеры (из её видов)
	-- или текущие renderWidth/renderHeight.
	fn createBatchViewForCam cam = (
		if cam == undefined or not (isValidNode cam) then return undefined
		close_batch_window()
		local new_view = batchRenderMgr.CreateView cam
		if new_view != undefined then (
			local base = getCamResFromViews cam
			if base[1] <= 0 then base = #(renderWidth, renderHeight)
			if base[1] <= 0 then base = #(1920, 1080)
			new_view.overridePreset = true
			new_view.name = viewNameFor (getUniqueViewName cam.name "") base[1] base[2]
			new_view.pixelAspect = 1
			if new_view.outputFilename == undefined or new_view.outputFilename == "" do (
				local outName = (getCleanViewName new_view.name) + ".jpg"
				-- Путь по умолчанию: папка текущего max-файла,
				-- а если в ней есть подпапка "Render" — то в неё.
				local basePath = maxFilePath
				if basePath != undefined and basePath != "" then (
					if doesFileExist (basePath + "Render") then basePath = basePath + "Render\\"
					outName = basePath + outName
				)
				new_view.outputFilename = outName
			)
			local scaled = resFromBase base[1] base[2]
			new_view.width = scaled[1]
			new_view.height = scaled[2]
		)
		new_view
	)

	-- Создать batch views для камер, у которых нет ни одного вида.
	fn createMissingViews = (
		local cams = getCameraList()
		local created = 0
		for cam in cams do (
			if (getViewsForCam cam).count == 0 then (
				if createBatchViewForCam cam != undefined then created += 1
			)
		)
		created
	)

	-- Установить output folder для всех видов (только у тех, где задан filename)
	fn setOutputFolderForAll folder = (
		if folder == undefined then return 0
		close_batch_window()
		local count = 0
		for i = 1 to batchRenderMgr.NumViews do (
			local v = batchRenderMgr.GetView i
			if v != undefined and not (isGroupView v) then (
				local fname = filenameFromPath v.outputFilename
				if fname != "" then (
					v.outputFilename = pathConfig.appendPath folder fname
					count += 1
				)
			)
		)
		count
	)

	-- Установить output folder для всех Render Elements
	fn setRePathsForAll folder = (
		if folder == undefined then return 0
		local elems = renderElementMgr.getElements()
		local count = 0
		for e in elems do (
			local fname = filenameFromPath e.filename
			if fname != "" do (
				e.filename = pathConfig.appendPath folder fname
				count += 1
			)
		)
		count
	)

	-- Обновить пути Render Elements из папки текущего основного выхода
	fn updateRePathsForAll = (
		local mainFile = renderOutput.filename
		if mainFile == undefined or mainFile == "" then return 0
		setRePathsForAll (getFilenamePath mainFile)
	)

	-- Переименовать камеру: узел + find/replace старого имени в названиях её видов.
	fn renameCamera cam newName = (
		if cam == undefined or not (isValidNode cam) then return false
		newName = trimLeft newName
		newName = trimRight newName
		if newName == "" then return false
		if newName == cam.name then return true
		local oldName = cam.name
		if (getNodeByName newName) != undefined then return false
		cam.name = newName
		for i = 1 to batchRenderMgr.NumViews do (
			local bv = batchRenderMgr.GetView i
			if bv != undefined then (
				local data = parseViewName bv.name
				local clean = data[1]
				local sameCam = (try (bv.camera == cam) catch false)
				local p = findString clean oldName
				if sameCam or p != undefined then (
					local newClean = clean
					if p != undefined then newClean = replace clean p oldName.count newName
					if newClean != clean then (
						if data[2] > 0 and data[3] > 0 then
							safeSetViewName bv (viewNameFor newClean data[2] data[3])
						else
							safeSetViewName bv newClean
					)
				)
			)
		)
		true
	)

	-- Убрать суффикс разрешения из имени камеры: "Cam (1920x1080)" -> "Cam"
	fn stripCamResSuffix displayName = (
		local p = findString displayName " ("
		if p != undefined then substring displayName 1 (p - 1) else displayName
	)

	-- Имя камеры для списков: "CameraName (1920x1080)" — база из её видов
	fn getCameraDisplayName cam = (
		if cam == undefined or not (isValidNode cam) then return ""
		cam.name
	)
	--) Конец СОЗДАНИЕ / ПЕРЕИМЕНОВАНИЕ / ПУТИ
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( ДИАЛОГ УДАЛЕНИЯ ГРУППЫ
	local roll_del_confirm = rollout _rollDelConfirm "Delete Group" (
		label lbl_msg "" align:#center
		button btn_all "Group + Views" width:100 across:3
		button btn_sep "Group Only" width:100
		button btn_cancel "Cancel" width:100
		on btn_all pressed do (g_deleteGroupResult = 1; destroyDialog roll_del_confirm)
		on btn_sep pressed do (g_deleteGroupResult = 2; destroyDialog roll_del_confirm)
		on btn_cancel pressed do (g_deleteGroupResult = 0; destroyDialog roll_del_confirm)
	)

	-- Показать диалог удаления группы.
	-- hasViews=true: 3 кнопки (1=group+views, 2=group only, 0=cancel)
	-- hasViews=false: простой queryBox (true=delete, false=cancel)
	fn confirmDeleteGroup grpName hasViews = (
		if not hasViews then (
			if queryBox ("Delete empty group \"" + grpName + "\"?") then 2 else 0
		) else (
			g_deleteGroupResult = 0
			roll_del_confirm.lbl_msg.text = "Delete \"" + grpName + "\"?"
			createDialog roll_del_confirm modal:true width:340
			g_deleteGroupResult
		)
	)
	--) Конец ДИАЛОГ УДАЛЕНИЯ ГРУППЫ
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( СЕРВИСНЫЕ ФУНКЦИИ FLOATER
	-- Изменить размер floater в зависимости от количества и состояния rollout'ов
	fn updateFloaterHeight = (
		if g_floater == undefined then return false
		local h = g_floater.rollouts.count * 30
		for i in 1 to g_floater.rollouts.count do (
			if g_floater.rollouts[i].open then h += g_floater.rollouts[i].height
		)
		local scale_dpi = ((dotNetClass "System.Drawing.Graphics").fromHwnd 0).dpiX / 100
		g_floater.size = [g_floater.size[1], h / scale_dpi]
	)

	-- Сохранить позицию/размер floater и открытый rollout в INI
	fn saveFloaterState = (
		if g_floater == undefined then return false
		local iniPath = getmaxinifile()
		setINISetting iniPath "CamManager" "Position" (g_floater.pos as string)
		setINISetting iniPath "CamManager" "WindowsSize" (g_floater.size as string)
		local opened = g_last_opened_tab
		if opened == undefined or opened == "" then opened = "Cams"
		setINISetting iniPath "CamManager" "RolloutOpened" opened
		setINISetting iniPath "CamManager" "Snap" (g_snap as string)
	)

		-- Есть ли реальные batch views (не только группы-разделители)?
		fn hasBatchViews = (
			try (
				for i = 1 to batchRenderMgr.NumViews do (
					local v = batchRenderMgr.GetView i
					if v != undefined and not (isGroupView v) then return true
				)
				false
			) catch ( true )
		)

	-- Аккордеон:
	--  сворачивание любого свитка    -> ничего не меняется
	--  открытие Camera / States      -> сворачиваются все остальные (и Global тоже)
	--  открытие Batch Views          -> сворачиваются Camera и States, Global остаётся
	--  открытие Global               -> сворачиваются Camera и States, Batch остаётся
	--  (Global может быть открыт вместе с Batch, в остальных случаях закрыт)
	fn accordion thisRollout state = (
		if g_floater == undefined do return false
		if g_accordion_lock do return false
		if state do (
			local keepGlobal = (thisRollout == g_roll_batch)
			local keepBatch  = (thisRollout == g_roll_global)
			for other in #(g_roll_cams, g_roll_batch, g_roll_global, g_roll_states) do (
				if other == undefined or other == thisRollout do continue
				if other == g_roll_global and keepGlobal do continue
				if other == g_roll_batch and keepBatch do continue
				g_accordion_lock = true
				other.open = false
				g_accordion_lock = false
			)
		)
		if g_roll_cams != undefined and g_roll_cams.open then g_last_opened_tab = "Cams"
		else if g_roll_batch != undefined and g_roll_batch.open then g_last_opened_tab = "Batch"
		else if g_roll_global != undefined and g_roll_global.open then g_last_opened_tab = "Global"
		else if g_roll_states != undefined and g_roll_states.open then g_last_opened_tab = "States"
		updateFloaterHeight()
	)
	--) Конец СЕРВИСНЫЕ ФУНКЦИИ FLOATER
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( ROLLOUT: CAMERAS

	local roll_Cams = rollout roll_Cams "Cameras" (
		local roll_w = 250
		--------------------------------
		button btn_refresh "🔄️ Refresh" width:(roll_w / 2) align:#left offset:[roll_w / 2 - 45, 0] \
			tooltip:"Update scene cameras list"
		dotNetControl lst_cams "System.Windows.Forms.ListBox" height:265 offset:[-10, 0]
		button btn_cams_info "?" width:20 height:18 align:#right offset:[10,-23] tooltip:"Single click — preview camera parameters and resolution in the UI (scene unchanged).\nDouble click — activate the camera and load its resolution into the scene."
		button btn_pick_pathrev_cam "<<" width:60 align:#left across:3 tooltip:"Previous camera"
		button btn_s "Select" width:80 align:#center tooltip:"Select active camera"
		button btn_next_cam ">>" width:60 align:#right tooltip:"Next camera"

		group "Parameters" (
			label lbl_fl "Focal length" align:#left across:2
			spinner spn_fl "mm" fieldWidth:70 align:#right
			checkbox chk_fov "Use FOV" align:#left across:2
			spinner spn_fov "FOV" fieldWidth:70 align:#right
			checkbox chk_dof "Enable DOF" across:2
			spinner spn_f "f-" align:#right fieldWidth:70 align:#right
			checkbox chk_tilt "Perspective: Auto Vertical Tilt"
			label lbl_ex "Exposure:" align:#left
			radiobuttons rd_ex labels:#("Manual", "Target") align:#left offsets:#([0,0], [80,0])
			dropdownList drp_ev "Shutter" items:#("1 / seconds", "seconds", "degrees", "frames") width:112 align:#left across:2
			spinner spn_ev "EV" range:[0,1.0E6,6] fieldWidth:80 align:#right offset:[0,20]
			spinner spn_sh "Duration" range:[0,1.0E6,100] fieldWidth:60 align:#left
			spinner spn_iso "ISO" range:[0,1.0E6,100] fieldWidth:60 align:#left offset:[23,0]
		)

		group "Rename" (
			edittext txt_rename_cam fieldWidth:(roll_w - 40) labelOnTop:true \
				tooltip:"Rename camera node and update batch view names"
			label lbl_rename_warn "⚠ Name is already in use" align:#left visible:false \
				color:(color 200 40 40) offset:[0,-2]
		)

		button btn_create_view "➕ Create Batch View" width:135 height:25 align:#left across:2 \
			tooltip:"Create a batch view for the active camera\nand switch to the Batch Views tab"
		button btn_for_all_cams "For All Cams" width:80 height:25 align:#right \
			tooltip:"Create batch views for all cameras\nthat don't have a view yet"
		--------------------------------
		local active_cam
		local list_cam
		local curr_itm = 1
		--------------------------------

		--------------------------------
		-- UI MAPPING: generic name → UI controls
		--------------------------------
		local uiPropMap = #(
			#(#focal_length,   #(spn_fl)),
			#(#specify_fov,    #(chk_fov, spn_fov)),
			#(#use_dof,        #(chk_dof)),
			#(#f_number,       #(spn_f)),
			#(#auto_tilt,      #(chk_tilt)),
			#(#iso,            #(spn_iso)),
			#(#exposure_value, #(spn_ev))
		)

		fn updateUIForCamera cam = (
			for item in uiPropMap do (
				local genName = item[1]
				local controls = item[2]
				local supported = isCamPropSupported cam genName
				for ctrl in controls do ctrl.enabled = supported
			)
			local typ = classOf cam
			drp_ev.enabled = (typ == Physical)
			spn_sh.enabled = (typ == Physical or typ == CoronaCam or typ == VRayPhysicalCamera)
			rd_ex.enabled  = (typ == Physical or typ == VRayPhysicalCamera)
			local modeVal = getCamProp cam #exposure_mode
			if modeVal != undefined do (
				spn_iso.enabled = (modeVal == 0)
				spn_ev.enabled  = (modeVal == 1)
			)
		)

		-- Shutter: чтение/запись (отдельная логика, т.к. разная семантика)
		fn getShutterValue cam = (
			case (classOf cam) of (
				Physical: (
					case cam.shutter_unit_type of (
						0: 1.0 / cam.shutter_length_seconds
						1: cam.shutter_length_seconds
						2: cam.shutter_length_frames * 360
						3: cam.shutter_length_frames
					)
				)
				CoronaCam: cam.shutterSpeed
				VRayPhysicalCamera: cam.shutter_speed
				default: undefined
			)
		)

		-- Преобразовать значение UI (spn_sh) в тип затвора камеры
		fn shutterValue cam val = (
			case drp_ev.selection of (
				1: (cam.shutter_length_seconds = val / 1.0)
				2: (cam.shutter_length_seconds = val)
				3: (cam.shutter_length_frames = val / 360)
				4: (cam.shutter_length_frames = val)
			)
		)

		fn setShutterValue cam val = (
			case (classOf cam) of (
				Physical: shutterValue cam val
				CoronaCam: cam.shutterSpeed = val
				VRayPhysicalCamera: cam.shutter_speed = val
			)
		)

		-- Преобразовать тип затвора камеры в значение для UI (spn_sh)
		fn shutterType2Values cam = (
			case drp_ev.selection of (
				1: (spn_sh.value = 1.0 / cam.shutter_length_seconds)
				2: (spn_sh.value = cam.shutter_length_seconds)
				3: (spn_sh.value = cam.shutter_length_frames * 360)
				4: (spn_sh.value = cam.shutter_length_frames)
			)
		)

		-- Загрузить свойства камеры в UI
		fn get_camprops cam = (
			if not (isValidNode cam) do return false
			local typ = classOf cam
			local fov_state = getCamProp cam #specify_fov
			if fov_state != undefined do (
				chk_fov.state = fov_state
				spn_fl.enabled = not fov_state
				spn_fov.enabled = fov_state
			)
			local fl = getCamProp cam #focal_length
			if fl != undefined do spn_fl.value = fl
			if typ == Physical or typ == CoronaCam or typ == VRayPhysicalCamera then spn_fov.value = cam.fov
			local dof = getCamProp cam #use_dof
			if dof != undefined do chk_dof.state = dof
			local fn_val = getCamProp cam #f_number
			if fn_val != undefined do spn_f.value = fn_val
			local tilt = getCamProp cam #auto_tilt
			if tilt != undefined do chk_tilt.state = tilt
			local sh = getShutterValue cam
			if sh != undefined do spn_sh.value = sh
			if typ == Physical then (
				drp_ev.selection = cam.shutter_unit_type + 1
				rd_ex.state = cam.exposure_gain_type + 1
			) else if typ == VRayPhysicalCamera then (
				rd_ex.state = cam.exposure + 1
			)
			local iso = getCamProp cam #iso
			if iso != undefined do spn_iso.value = iso
			local ev = getCamProp cam #exposure_value
			if ev != undefined do spn_ev.value = ev
			updateUIForCamera cam
		)

		-- Инициализировать dotNet ListBox для камер
		fn initCamListBox = (
			lst_cams.SelectionMode = (dotNetClass "System.Windows.Forms.SelectionMode").One
			lst_cams.IntegralHeight = false
			lst_cams.BackColor = (dotNetClass "System.Drawing.Color").FromARGB 40 40 43
			lst_cams.ForeColor = (dotNetClass "System.Drawing.Color").White
		)

		fn getCamSel = ( lst_cams.SelectedIndex + 1 )
		fn setCamSel idx = ( lst_cams.SelectedIndex = if idx > 0 then idx - 1 else -1 )

		-- Обновить список камер в lst_cams
		fn relist_cams = (
			list_cam = getCameraList()
			lst_cams.BeginUpdate()
			lst_cams.Items.Clear()
			for cam in list_cam do lst_cams.Items.Add (getCameraDisplayName cam)
			lst_cams.EndUpdate()
		)

		-- change_active: определить активную камеру и обновить UI.
		-- НЕ устанавливает selection в lst_cams / drdwn_cam.
		fn change_active = (
			if active_cam == undefined or not (isvalidnode active_cam) then active_cam = getActiveCamera()
			lbl_rename_warn.visible = false
			if active_cam != undefined then (
				get_camprops active_cam
				txt_rename_cam.text = active_cam.name
				if g_roll_batch != undefined do g_roll_batch.syncCamDropdown active_cam
				if g_roll_batch != undefined do g_roll_batch.displayCamRes active_cam
			) else (
				txt_rename_cam.text = ""
				if g_roll_batch != undefined do g_roll_batch.displayCamRes undefined
			)
			RedrawViews()
		)

		-- syncCameraUI: синхронизировать выделение в lst_cams с активной камерой.
		fn syncCameraUI = (
			if active_cam != undefined and isvalidnode active_cam then (
				local camIdx = findItem list_cam active_cam
				if camIdx != 0 and getCamSel() != camIdx then (
					setCamSel camIdx
					curr_itm = camIdx
				)
				if g_roll_batch != undefined do g_roll_batch.syncCamDropdown active_cam
			)
		)

		-- Установить камеру в viewport и вызвать change_active().
		fn setActiveCam n = (
			if n != undefined then (
				local cam = if (isKindOf n string) then (getNodeByName n) else n
				local store_old_active_cam = viewport.activeViewport
				for i in 1 to viewport.numViews do (
					if (viewport.getCamera index:i) == active_cam do viewport.activeViewport = i
				)
				if isValidNode cam AND (isKindOf cam camera) then (
					if viewport.CanSetToViewport cam then viewport.SetCamera cam
					viewport.activeViewport = store_old_active_cam
					active_cam = cam
					change_active()
					applyCamResToScene cam
					syncCameraUI()
				)
			)
		)

		-- Выделить камеру в viewport (переключение в modify mode)
		fn selCam n = (
			max modify mode
			if isValidNode n then select n
		)

		-- Переименовать активную камеру
		fn doRename = (
			if active_cam == undefined or not (isValidNode active_cam) do return false
			local newName = trimLeft (trimRight txt_rename_cam.text)
			if newName == "" then (
				lbl_rename_warn.visible = false
				return false
			)
			if newName == active_cam.name then (
				lbl_rename_warn.visible = false
				return true
			)
			if (getNodeByName newName) != undefined then (
				lbl_rename_warn.visible = true
				return false
			)
			lbl_rename_warn.visible = false
			renameCamera active_cam newName
			relist_cams()
			syncCameraUI()
			if g_roll_batch != undefined do g_roll_batch.list_views()
			true
		)

		--------------------------------
		on roll_Cams open do (
			initCamListBox()
			relist_cams()
			change_active()
			syncCameraUI()
		)

		on roll_Cams close do (
			saveFloaterState()
		)

		on roll_Cams rolledUp state do ( accordion roll_Cams state )

		on btn_refresh pressed do (
			relist_cams()
			change_active()
			syncCameraUI()
		)

		on btn_s pressed do ( selCam active_cam )

		on btn_pick_pathrev_cam pressed do (
			if curr_itm > 1 then curr_itm -= 1
			setCamSel curr_itm
			setActiveCam list_cam[curr_itm]
			if g_roll_batch != undefined do g_roll_batch.selectFirstViewForCamera active_cam
		)

		on btn_next_cam pressed do (
			if curr_itm < lst_cams.Items.Count then curr_itm += 1
			setCamSel curr_itm
			setActiveCam list_cam[curr_itm]
			if g_roll_batch != undefined do g_roll_batch.selectFirstViewForCamera active_cam
		)

		on lst_cams SelectedIndexChanged sender args do (
			local idx = getCamSel()
			if idx <= 0 do return false
			curr_itm = idx
			active_cam = list_cam[idx]
			change_active()
		)

		on lst_cams MouseDoubleClick sender args do (
			local idx = getCamSel()
			if idx <= 0 do return false
			setActiveCam list_cam[idx]
			if g_roll_batch != undefined do g_roll_batch.selectFirstViewForCamera active_cam
		)

		on btn_cams_info pressed do (
			messageBox "Один клик — просмотр параметров и разрешения камеры в UI (сцена не меняется).\nДвойной клик — активировать камеру и загрузить её разрешение в сцену." title:"Cameras"
		)

		-- CAMERA PARAMETERS
		on chk_fov changed state do (
			spn_fl.enabled = NOT state
			spn_fov.enabled = state
			setCamProp active_cam #specify_fov state
		)
		on spn_fl changed val do setCamProp active_cam #focal_length val
		on spn_fov changed val do (
			local c = classOf active_cam
			if c == Physical or c == CoronaCam or c == VRayPhysicalCamera then active_cam.fov = val
		)
		on chk_dof changed state do setCamProp active_cam #use_dof state
		on chk_tilt changed state do setCamProp active_cam #auto_tilt state
		on drp_ev selected idx do (
			if classOf active_cam == Physical then (
				shutterType2Values active_cam
				active_cam.shutter_unit_type = (idx - 1)
			)
		)
		on spn_sh changed val do setShutterValue active_cam val
		on rd_ex changed state do (
			setCamProp active_cam #exposure_mode (state - 1)
			updateUIForCamera active_cam
		)
		on spn_iso changed val do setCamProp active_cam #iso val
		on spn_ev changed val do setCamProp active_cam #exposure_value val

		-- RENAME CAMERA (живое переименование при вводе текста)
		on txt_rename_cam entered txt do ( doRename() )

		-- CREATE BATCH VIEW
		on btn_create_view pressed do (
			if active_cam == undefined or not (isValidNode active_cam) then (
				messageBox "Select a camera first" title:"Cameras"
				return false
			)
			local bv = createBatchViewForCam active_cam
			if bv != undefined then (
				relist_cams()
				if g_roll_batch != undefined then (
					g_roll_batch.list_views()
					g_roll_batch.open = true
					g_roll_batch.selectView bv
				)
			)
		)

		-- CREATE BATCH VIEWS FOR ALL CAMS
		on btn_for_all_cams pressed do (
			local created = createMissingViews()
			relist_cams()
			if g_roll_batch != undefined then (
				g_roll_batch.list_views()
				g_roll_batch.open = true
			)
			messageBox ("Created batch views: " + (created as string)) title:"Cameras"
		)

	)
	--) Конец ROLLOUT: CAMERAS
	--------------------------------------------------------------


	--------------------------------------------------------------
	--( ROLLOUT: BATCH

	local roll_batch = rollout roll_batch "Batch Views" (
		local roll_w = 250
		--------------------------------
		button btn_open_batch "Batch Views" width:80 height:25 align:#left offset:[-10,0]
		button btn_refresh "🔄️ Refresh" width:(roll_w - 120) height:25 align:#left offset:[65,-30] tooltip:"Update the views list"
		button btn_views_info "?" width:20 height:25 align:#right offset:[15,-30] tooltip:"Batch Views list.\n\n— Single click — preview view parameters in the UI (scene unchanged).\n— Double click — toggle enabled / collapse or expand a group.\n— Buttons on the left: refresh list, add, duplicate, delete, move up/down, enable/disable."
		dotNetControl lst_views "System.Windows.Forms.ListBox" height:265 offset:[-10,0]

		button btn_togleEnabled "☑️" align:#right width:24 height:25 tooltip:"Toggle enabled" offset:[14,-272]
		button btn_togleEnabledAll "✓✓" align:#right width:24 height:25 tooltip:"Toggle enabled ALL" offset:[14,0]
		button btn_up "↑" height:55 align:#right tooltip:"Move view/group up" offset:[14,2]
		button btn_add_sep "—" width:24 align:#right tooltip:"Add group\nGroups can be renamed via View Name field" offset:[14,0]
		button btn_down "↓" height:55 align:#right tooltip:"Move view/group down" offset:[14,0]
		button btn_dup "📋" width:24 height:25 align:#right offset:[14,2] tooltip:"Duplicate view"
		button btn_rem "❌" width:24 height:25 align:#right offset:[14,0]

		checkbutton btn_net_render "🕸️ Net" width:80 height:25 align:#left offset:[-10,0]
		button btn_render "🫖 Render" height:25 width:(roll_w - 120) align:#left offset:[65,-30]

		--group "Edit batch view" (
			edittext txt_view_name "View name" fieldWidth:(roll_w - 35) bold:true labelOnTop:true
			
			button btn_open_in_explorer "Open" align:#right width:40 height:18 offset:[5,0] tooltip:"Open folder in explorer"
			edittext txt_view_path "Output path" fieldWidth:(roll_w - 35) labelOnTop:true offset:[0,-18]
			
			edittext txt_view_file "File name" fieldWidth:(roll_w - 80) labelOnTop:true
			button btn_pick_path "..." align:#right width:40 offset:[5,-25] tooltip:"Use save file dialog"

			dropdownlist drdwn_cam "Camera" Width:(roll_w - 80) items:#("---------------------")
			button btn_use_active_cam "🎥" align:#right width:40 offset:[5,-28] tooltip:"Use active camera"
			
			dropdownlist drdwn_state "Scene State" items:#("---------------------")
			dropdownlist drdwn_render_preset "Render Preset" items:#("---------------------") width:(roll_w - 35)
			
		group "Resolution" (
			checkbox chk_override_preset "Override Preset" align:#left across:2 \
				tooltip:"On — the view uses its OWN resolution and frames.\nOff — the view uses the selected Render Preset."
			checkbox chk_edit_base "Base size" align:#ыleft \
				tooltip:"Off — edits the CURRENT (scaled) size.\nOn — edits the BASE (100%) size.\nActive only when global scale ≠ 100%."
			edittext txt_out_w "Width" type:#integer fieldwidth:50 align:#right across:2
			edittext txt_out_ratio "Ratio" type:#float fieldwidth:40 align:#right
			edittext txt_out_h "Height" type:#integer fieldwidth:50 align:#right across:2
			dropdownlist drdwn_re_presets items:g_presetNames width:75 align:#right offset:[0,-5]
			checkButton chk_ratio "🔗" height:36 width:18 align:#left offset:[roll_w / 2 - 16, -42] 
			button btn_swap "↕" height:36 width:18 align:#left offset:[-4, -42] \
				tooltip:"Swap width and height values\nand invert the aspect ratio"
			checkbox chk_snap "Use snap" checked:true align:#left across:2 \
				tooltip:"Snap resolution to standard values.\n1. Standard resolution list (big MP tolerance, aspect protected).\n2. Grid multiples (W:32, H:16) + standard aspect.\nOff — values are used as-is."
			checkbox chk_preserve_mp "Preserve MegaPix" align:#left \
				tooltip:"When changing aspect ratio, keep total megapixels\nconstant by recalculating both dimensions.\nSnaps to nearest standard resolution."
			checkbox chk_sync_views "Sync by Camera" align:#left \
				tooltip:"On — update all batch views using this camera.\n'Base size' ON  — syncs the BASE size.\n'Base size' OFF — syncs the CURRENT (scaled) size."
		)
			
			spinner spn_start_frame "Start" type:#integer range:[0,99999,0] fieldWidth:60 across:2 align:#left offset:[0,10]
			spinner spn_end_frame "End" type:#integer range:[0,99999,100] fieldWidth:60 align:#left offset:[0,10]

		--)


		--------------------------------
		local suppress_cam_dropdown = false
		local loading_view = false
		local suppress_res_events = false
		local suppress_preset_events = false
		--------------------------------

		-- Маппинг UI-индекс → реальный индекс batch view строится в list_views

		-- Инициализация dotNet ListBox
		fn initListBox = (
			lst_views.BeginUpdate()
			lst_views.Items.Clear()
			lst_views.SelectionMode = (dotNetClass "System.Windows.Forms.SelectionMode").One
			lst_views.IntegralHeight = false
			lst_views.BackColor = (dotNetClass "System.Drawing.Color").FromARGB 40 40 43
			lst_views.ForeColor = (dotNetClass "System.Drawing.Color").White
			lst_views.EndUpdate()
		)

		fn getSel = (
			local i = lst_views.SelectedIndex
			if i >= 0 then i + 1 else 0
		)

		fn setSel idx = (
			lst_views.SelectedIndex = if idx > 0 then idx - 1 else -1
		)

		-- Преобразовать UI-индекс lst_views в реальный индекс batchRenderMgr
		fn getRealIndex uiIdx = (
			if uiIdx > 0 and uiIdx <= g_visibleIndices.count then g_visibleIndices[uiIdx] else 0
		)

		-- Обновить состояние кнопок в зависимости от выделения в lst_views
		fn lst_views_update_buttons = (
			local uiIdx = getSel()
			local realIdx = getRealIndex uiIdx
			local isGroup = false
			if realIdx > 0 then (
				local the_view = batchRenderMgr.GetView realIdx
				isGroup = isGroupView the_view
			)
			if realIdx == 0 then (
				btn_up.enabled = false
				btn_down.enabled = false
			) else if isGroup then (
				btn_up.enabled = canMoveGroup realIdx #up
				btn_down.enabled = canMoveGroup realIdx #down
			) else (
				btn_up.enabled = realIdx > 1
				btn_down.enabled = realIdx < batchRenderMgr.numViews
			)
			btn_togleEnabled.enabled = realIdx > 0
			btn_togleEnabled.tooltip = if isGroup then "Toggle all views in group" else "Toggle enabled"
			btn_rem.enabled = realIdx > 0
		)

		-- Заполнить drdwn_cam выпадающий список камер
		fn list_cameras_for_batch = (
			local cam_names = for cam in (getCameraList()) collect (getCameraDisplayName cam)
			drdwn_cam.items = #("---------------------") + cam_names
		)

		-- Найти индекс камеры в drdwn_cam по имени (поддерживает суффикс разрешения)
		fn findCameraInDropdown camName = (
			for i in 2 to drdwn_cam.items.count do (
				if matchPattern drdwn_cam.items[i] pattern:(camName + "*") do return i
			)
			0
		)

		-- Синхронизировать выделение в drdwn_cam с камерой (без побочных эффектов)
		fn syncCamDropdown cam = (
			if cam == undefined do return false
			local drdwnIdx = findCameraInDropdown cam.name
			if drdwnIdx != 0 and drdwn_cam.selection != drdwnIdx then (
				suppress_cam_dropdown = true
				drdwn_cam.selection = drdwnIdx
				suppress_cam_dropdown = false
			)
		)

		-- Синхронизировать пресет с текущим ratio (Free если нет совпадения).
		-- Для вертикального кадра (h > w) ratio нормализуется к пейзажному.
		-- LOCK включается при совпадении с пресетом, иначе выключается.
		fn syncPresetFromRatio ratio = (
			local idx = 1
			if ratio != undefined and ratio > 0 then (
				local cmp = ratio
				local w = txt_out_w.text as integer
				local h = txt_out_h.text as integer
				if h != undefined and w != undefined and h > w then cmp = 1.0 / ratio
				for i = 2 to g_presetRatios.count do (
					if abs(g_presetRatios[i] - cmp) < 0.01 then (idx = i; exit)
				)
			)
			if not suppress_preset_events then (
				suppress_preset_events = true
				drdwn_re_presets.selection = idx
				suppress_preset_events = false
			)
			chk_ratio.checked = (idx > 1)
			idx
		)

		-- Показать в полях Render output базовое или текущее разрешение
		-- (зависит от галки chk_edit_base и глобального масштаба)
		fn showResForBase baseW baseH = (
			suppress_res_events = true
			if baseW > 0 and baseH > 0 then (
				if chk_edit_base.checked and abs(g_globalScale - 1.0) > 0.001 then (
					txt_out_w.text = (baseW as integer) as string
					txt_out_h.text = (baseH as integer) as string
				) else (
					local scaled = resFromBase baseW baseH
					txt_out_w.text = (scaled[1] as integer) as string
					txt_out_h.text = (scaled[2] as integer) as string
				)
				if (txt_out_h.text as integer) > 0 then (
					local w = txt_out_w.text as integer
					local h = txt_out_h.text as integer
					txt_out_ratio.text = (w as float / h) as string
				)
			) else (
				txt_out_w.text = renderWidth as string
				txt_out_h.text = renderHeight as string
				if renderHeight > 0 then txt_out_ratio.text = (renderWidth as float / renderHeight) as string
			)
			suppress_res_events = false
			syncPresetFromRatio (txt_out_ratio.text as float)
		)

		-- Активность Ratio и чек-бокса Preserve MegaPix (всегда доступен при Override)
		fn updateRatioUI = (
			local ovr = chk_override_preset.checked
			local isFree = (drdwn_re_presets.selection <= 1)
			chk_preserve_mp.enabled = ovr
			txt_out_ratio.enabled = ovr and isFree
			chk_ratio.enabled = ovr
		)

		-- Активность контролов размера/кадров в зависимости от Override Preset
		fn updateOverrideUI = (
			local ovr = chk_override_preset.checked
			local canEditBase = ovr and abs(g_globalScale - 1.0) > 0.001
			chk_edit_base.enabled = canEditBase
			txt_out_w.enabled = ovr
			txt_out_h.enabled = ovr
			btn_swap.enabled = ovr
			drdwn_re_presets.enabled = ovr
			spn_start_frame.enabled = ovr
			spn_end_frame.enabled = ovr
			updateRatioUI()
		)

		-- Загрузить параметры batch view в UI
		fn get_view_params index = (
			local the_view = try (batchRenderMgr.GetView index) catch undefined
			if the_view == undefined then return undefined

			disableSceneRedraw()
			loading_view = true

			txt_view_name.text = stripCollapsePrefix the_view.name

			local cam = the_view.camera
			if isValidNode cam then (
				if g_roll_cams != undefined do g_roll_cams.setActiveCam cam
				local drdwnIdx = findCameraInDropdown cam.name
				suppress_cam_dropdown = true
				drdwn_cam.selection = if drdwnIdx == 0 then 1 else drdwnIdx
				suppress_cam_dropdown = false
			) else (
				suppress_cam_dropdown = true
				drdwn_cam.selection = 1
				suppress_cam_dropdown = false
			)

			if the_view.outputFilename != "" then (
				txt_view_path.text = getFilenamePath the_view.outputFilename
				txt_view_file.text = filenameFromPath the_view.outputFilename
			) else (
				txt_view_path.text = ""
				txt_view_file.text = ""
			)

			local idx = finditem drdwn_state.items the_view.sceneStateName
			drdwn_state.selection = if idx == 0 then 1 else idx
			if the_view.sceneStateName != "" do (
				local ssp = sceneStateMgr.GetParts the_view.sceneStateName
				sceneStateMgr.Restore the_view.sceneStateName ssp
			)

			-- Отразить масштаб из имени вида в глобальном слайдере
			local nameData = parseViewName the_view.name
			local nameScale = nameData[4]
			if nameScale != undefined and nameScale > 0 and abs(nameScale - g_globalScale) > 0.001 do (
				g_globalScale = nameScale
				if g_roll_global != undefined do g_roll_global.updateScaleDisplay nameScale
			)

			local base = getViewBase the_view
			showResForBase base[1] base[2]
			chk_sync_views.checked = getCamSync cam

			chk_override_preset.checked = the_view.overridePreset
			updateOverrideUI()
			local pf = the_view.presetFile
			local presetIdx = 1
			if pf != undefined and pf != "" then (
				presetIdx = findItem drdwn_render_preset.items (getFilenameFile pf)
				if presetIdx == 0 then presetIdx = 1
			)
			drdwn_render_preset.selection = presetIdx

			spn_start_frame.value = the_view.startFrame
			spn_end_frame.value = the_view.endFrame

			loading_view = false
			enableSceneRedraw()
			the_view
		)

		-- Выбрать первый вид камеры в списке
		fn selectFirstViewForCamera cam = (
			if cam == undefined do return false
			for i = 1 to batchRenderMgr.NumViews do (
				local bv = batchRenderMgr.GetView i
				if bv != undefined and bv.camera == cam then (
					local uiIdx = findItem g_visibleIndices i
					if uiIdx != 0 then setSel uiIdx
					get_view_params i
					return true
				)
			)
			false
		)

		-- Выделить конкретный batch view в списке и загрузить его параметры в UI
		fn selectView the_view = (
			if the_view == undefined do return false
			local theName = the_view.name
			for i = 1 to batchRenderMgr.NumViews do (
				local v = batchRenderMgr.GetView i
				if v != undefined and v == the_view then (
					local uiIdx = findItem g_visibleIndices i
					if uiIdx != 0 then setSel uiIdx
					g_active_view = get_view_params i
					lst_views_update_buttons()
					return true
				)
			)
			if theName != undefined then (
				for i = 1 to batchRenderMgr.NumViews do (
					local v = batchRenderMgr.GetView i
					if v != undefined and v.name == theName then (
						local uiIdx = findItem g_visibleIndices i
						if uiIdx != 0 then setSel uiIdx
						g_active_view = get_view_params i
						lst_views_update_buttons()
						return true
					)
				)
			)
			false
		)

		-- Обновить txt_view_path (путь) и txt_view_file (имя файла) из g_view_path
		fn update_Path = (
			if g_view_path != undefined then (
				txt_view_path.text = getFilenamePath g_view_path
				txt_view_file.text = filenameFromPath g_view_path
			) else (
				txt_view_path.text = ""
				txt_view_file.text = ""
			)
		)

		-- Обновить lst_views, drdwn_state, drdwn_cam.
		-- Строит g_visibleIndices — маппинг UI-индекс → реальный индекс batch view
		fn list_views restoreName:"" = (
			local gv = batchRenderMgr.GetView
			local num = batchRenderMgr.numViews
			local col = #()
			-- Запомнить текущее выделение (реальный индекс) и позицию прокрутки
			local prevReal = getRealIndex (getSel())
			local prevTop = if lst_views.Items.Count > 0 then lst_views.TopIndex else 0
			g_visibleIndices = #()
			local collapsed = false

			for i = 1 to num do (
				local the_view = gv i
				local isGroup = isGroupView the_view

				if isGroup then (
					local hasViews = false
					for j = (i + 1) to num do (
						local v2 = gv j
						if isGroupView v2 then exit
						hasViews = true
					)
					if hasViews then (
						local firstChar = substring the_view.name 1 1
						if firstChar != PROP_COLLAPSED and firstChar != PROP_EXPANDED do (
							the_view.name = PROP_EXPANDED + the_view.name
							firstChar = PROP_EXPANDED
						)
						collapsed = (firstChar == PROP_COLLAPSED)
						if collapsed then (
							local enb = 0
							local dsb = 0
							for j = (i + 1) to num do (
								local v2 = gv j
								if isGroupView v2 then exit
								if v2.enabled then enb += 1 else dsb += 1
							)
							append col (the_view.name + "  " + (enb as string) + "/" + (enb + dsb) as string)
						) else (
							append col the_view.name
						)
						append g_visibleIndices i
					) else (
						append col the_view.name
						append g_visibleIndices i
						collapsed = false
					)
				) else (
					if not collapsed then (
						local st = if the_view.enabled then "☑ " else "☐ "
						append col (st + the_view.name)
						append g_visibleIndices i
					)
				)
			)

			lst_views.BeginUpdate()
			lst_views.Items.Clear()
			for item in col do lst_views.Items.Add item
			lst_views.EndUpdate()
			lst_views_update_buttons()

			list_cameras_for_batch()

			local states_names = for i in 1 to sceneStateMgr.getCount() collect (sceneStateMgr.GetSceneState i)
			qsort states_names (fn cmp a b = ( stricmp a b ))
			drdwn_state.items = #("---------------------") + states_names

			drdwn_render_preset.items = #("---------------------") + getRenderPresetNames()

			btn_net_render.checked = batchRenderMgr.netRender

			-- Восстановить выделение (пересборка списка сбрасывает его).
			-- Сначала по имени restoreName (вид/группа сохраняет имя при перестроении),
			-- иначе по реальному индексу (позиция не менялась).
			local selUi = 0
			if restoreName != "" do (
				for i = 1 to g_visibleIndices.count do (
					if (batchRenderMgr.GetView g_visibleIndices[i]).name == restoreName do ( selUi = i; exit )
				)
			)
			if selUi == 0 and prevReal > 0 do (
				selUi = findItem g_visibleIndices prevReal
			)
			if selUi != 0 do setSel selUi
			-- Восстановить позицию прокрутки (не сбрасывать к началу списка)
			if prevTop >= 0 and lst_views.Items.Count > 0 then (
				if prevTop >= lst_views.Items.Count do prevTop = lst_views.Items.Count - 1
				lst_views.TopIndex = prevTop
			)
		)

		-- Обновить drdwn_state (список scene states) после изменения состояний
		fn refreshStatesList = (
			local prevName = if drdwn_state.selection > 1 then drdwn_state.items[drdwn_state.selection] else ""
			local states_names = for i in 1 to sceneStateMgr.getCount() collect (sceneStateMgr.GetSceneState i)
			qsort states_names (fn cmp a b = ( stricmp a b ))
			drdwn_state.items = #("---------------------") + states_names
			if prevName != "" then (
				local idx = findItem drdwn_state.items prevName
				drdwn_state.selection = if idx == 0 then 1 else idx
			)
		)

		-- Применить W/H из спиннеров Render output к выделенному виду
		fn applyViewRes w h = (
			if getSel() == 0 do return false
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined or isGroupView bv do return false
			if w == undefined or h == undefined or w <= 0 or h <= 0 do return false
			local scale = if g_globalScale == undefined then 1.0 else g_globalScale
			local baseW = w as integer
			local baseH = h as integer
			if chk_edit_base.checked and abs(scale - 1.0) > 0.001 then (
				baseW = w as integer
				baseH = h as integer
			) else (
				baseW = (w as float / scale) as integer
				baseH = (h as float / scale) as integer
				if baseW <= 0 or baseH <= 0 do return false
			)
			close_batch_window()
			setViewBase bv baseW baseH
			if chk_sync_views.checked and isValidNode bv.camera do syncViewsForCam bv.camera #(baseW, baseH) #(w, h)
			list_views()
			if getSel() > 0 do get_view_params (getRealIndex (getSel()))
			true
		)

		-- Применить w/h с снэпом к выделенному виду.
		-- force:true — применять всегда (ввод может отличаться от состояния вида,
		-- даже если снэп его не меняет, напр. LOCK-пересчёт второй стороны).
		-- force:false — применять, только если снэп реально изменил значения.
		fn applyFieldRes w h force:false = (
			if w == undefined or h == undefined or w <= 0 or h <= 0 then return false
			local smart = snapResolution w h
			if not force and smart[1] == w and smart[2] == h then return false
			applyViewRes smart[1] smart[2]
			true
		)

		-- Применить ratio к выделенному виду.
		-- preserve_mp: сохранить мегапиксели (пересчитать обе стороны, снэп к стандарту).
		-- иначе: сохранить ширину, пересчитать высоту.
		fn applyRatio ratio = (
			if ratio == undefined or ratio <= 0 do return false
			local w = txt_out_w.text as integer
			local h = txt_out_h.text as integer
			if w == undefined or w <= 0 do w = 0
			if h == undefined or h <= 0 do h = 0
			-- Preserve MegaPix учитывается всегда при изменении Ratio
			if chk_preserve_mp.checked and w > 0 and h > 0 then (
				local mp = w as float * h as float
				local newW = (sqrt(mp * ratio)) as integer
				local newH = (sqrt(mp / ratio)) as integer
				-- Снэп: сначала список стандартных разрешений, затем сетка/пропорция
				local snapped = snapResolution newW newH
				suppress_res_events = true
				txt_out_w.text = (snapped[1] as integer) as string
				txt_out_h.text = (snapped[2] as integer) as string
				txt_out_ratio.text = ratio as string
				suppress_res_events = false
				applyViewRes snapped[1] snapped[2]
			) else (
				local newH = if w > 0 then floor(w as float / ratio) else h
				if newH > 0 then (
					-- Снэп: сначала список стандартных разрешений, затем сетка/пропорция
					local snapped = snapResolution w newH
					suppress_res_events = true
					txt_out_h.text = (snapped[2] as integer) as string
					txt_out_ratio.text = ratio as string
					suppress_res_events = false
					applyViewRes snapped[1] snapped[2]
				)
			)
			true
		)

		-- Обновить batch view из UI (txt_view_name/2/3, drdwn_state, база)
		fn view_update = (
			if getSel() == 0 do return undefined
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined do return undefined
			local any_changed = false

			-- База из имени или текущего вида
			local nameData = parseViewName txt_view_name.text
			local baseW = nameData[2]
			local baseH = nameData[3]
			if baseW <= 0 or baseH <= 0 then (
				local fb = getViewBase bv
				if baseW <= 0 then baseW = fb[1]
				if baseH <= 0 then baseH = fb[2]
			)

			if isGroupView bv then (
				local prefix = substring bv.name 1 1
				local newName = txt_view_name.text
				if prefix == PROP_COLLAPSED or prefix == PROP_EXPANDED do newName = prefix + newName
				if bv.name != newName then (
					if batchRenderMgr.FindView newName then (
						messageBox "View already exists.\nChange name and try again."
						return undefined
					)
					bv.name = newName
					any_changed = true
				)
			) else (
				local clean = getCleanViewName txt_view_name.text
				local finalName = if baseW > 0 and baseH > 0 then viewNameFor clean baseW baseH else clean
				if bv.name != finalName then (
					if batchRenderMgr.FindView finalName and bv.name != finalName then (
						messageBox "View already exists.\nChange name and try again."
						return undefined
					)
					bv.name = finalName
					any_changed = true
				)
			)

			if txt_view_path.text == "" or txt_view_file.text == "" then (
				g_view_path = undefined
				bv.outputFilename = undefined
				txt_view_path.text = ""
				txt_view_file.text = ""
				any_changed = true
			) else if doesfileexist txt_view_path.text then (
				g_view_path = txt_view_path.text + txt_view_file.text
				bv.outputFilename = g_view_path
				any_changed = true
			) else (
				messageBox "Directory doesn't exist" title:"Error"
				return undefined
			)

			local selected_scene_state = if drdwn_state.selection > 1 then drdwn_state.items[drdwn_state.selection] else ""
			if selected_scene_state != bv.sceneStateName do (
				bv.sceneStateName = selected_scene_state
				any_changed = true
			)

			if baseW > 0 and baseH > 0 and chk_sync_views.checked and isValidNode bv.camera do (
				syncViewsForCam bv.camera #(baseW, baseH) (resFromBase baseW baseH)
			)

			if any_changed do (
				close_batch_window()
				list_views()
				if getSel() > 0 do get_view_params (getRealIndex (getSel()))
			)
		)

		-- Отобразить разрешение камеры в спиннерах (из её видов, уважает галку)
		fn displayCamRes cam = (
			local base = getCamResFromViews cam
			showResForBase base[1] base[2]
		)

		--------------------------------
		on roll_batch open do (
			initListBox()
			list_views()
			setSel 0
			chk_snap.checked = g_snap
			updateOverrideUI()
			local cam = if g_roll_cams != undefined then g_roll_cams.active_cam else undefined
			if isValidNode cam and (isKindOf cam camera) then (
				local camIdx = findCameraInDropdown cam.name
				suppress_cam_dropdown = true
				if camIdx != 0 do drdwn_cam.selection = camIdx
				suppress_cam_dropdown = false
			)
			selectFirstViewForCamera cam
		)

		on roll_batch close do ( saveFloaterState() )
		on roll_batch rolledUp state do ( accordion roll_batch state )

		on btn_open_batch pressed do ( actionMan.executeAction -43434444 "4096" )
		on btn_refresh pressed do (
			local prevView = undefined
			if getSel() > 0 then (
				local prevReal = getRealIndex (getSel())
				if prevReal > 0 then prevView = batchRenderMgr.GetView prevReal
			)
			g_batch_view = undefined
			g_view_name = ""
			g_active_view = undefined
			list_views()
			if g_roll_cams != undefined do (
				g_roll_cams.relist_cams()
				g_roll_cams.change_active()
				g_roll_cams.syncCameraUI()
			)
			if prevView != undefined then (
				for i = 1 to g_visibleIndices.count do (
					if batchRenderMgr.GetView g_visibleIndices[i] == prevView do (
						setSel i
						get_view_params g_visibleIndices[i]
						exit
					)
				)
			) else if getSel() > 0 do get_view_params (getRealIndex (getSel()))
		)

		on txt_view_name entered txt do view_update()
		on txt_view_path entered txt do view_update()
		on txt_view_file entered txt do view_update()

		on drdwn_state selected index do view_update()
		on spn_start_frame changed val do (
			if loading_view then return false
			if getSel() != 0 then (
				local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
				if bv != undefined do (
					close_batch_window()
					bv.startFrame = val as integer
					list_views()
				)
			)
		)
		on spn_end_frame changed val do (
			if loading_view then return false
			if getSel() != 0 then (
				local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
				if bv != undefined do (
					close_batch_window()
					bv.endFrame = val as integer
					list_views()
				)
			)
		)

		on btn_use_current_res pressed do (
			applyViewRes renderWidth renderHeight
		)

		on chk_sync_views changed state do (
			if loading_view then return false
			if getSel() == 0 do return false
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined or not (isValidNode bv.camera) do return false
			setUserProp bv.camera "sync_batch_views" state
			if state do (
				local base = getViewBase bv
				if base[1] > 0 and base[2] > 0 do syncViewsForCam bv.camera base (resFromBase base[1] base[2])
				list_views()
			)
		)

		-- CAMERA SELECTION
		on drdwn_cam selected index do (
			if suppress_cam_dropdown do return false
			if getSel() != 0 and index > 1 then (
				local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
				if bv != undefined then (
					local cam_name = stripCamResSuffix drdwn_cam.items[index]
					local cam = getNodeByName cam_name
					if isValidNode cam and (isKindOf cam camera) then (
						close_batch_window()
						bv.camera = cam
						if g_roll_cams != undefined do (
							g_roll_cams.setActiveCam cam
							g_roll_cams.syncCameraUI()
						)
						local res = getCamResFromViews cam
						if res[1] > 0 and res[2] > 0 then (
							if queryBox ("Apply " + res[1] as string + "x" + res[2] as string + " as base for this view?") title:"Camera Base" do (
								close_batch_window()
								setViewBase bv res[1] res[2]
								list_views()
								if getSel() > 0 do get_view_params (getRealIndex (getSel()))
							)
						)
						list_views()
					)
				)
			)
		)

		on btn_use_active_cam pressed do (
			if getSel() != 0 then (
				local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
				if bv != undefined then (
					local cam = getActiveCamera()
					if cam == undefined then (
						for i in 1 to viewport.numViews where cam == undefined do (
							local vc = viewport.getCamera index:i
							if vc != undefined and isValidNode vc and (isKindOf vc camera) do cam = vc
						)
					)
					if isValidNode cam and (isKindOf cam camera) then (
						close_batch_window()
						bv.camera = cam
						if g_roll_cams != undefined do (
							g_roll_cams.active_cam = cam
							g_roll_cams.change_active()
							g_roll_cams.syncCameraUI()
						)
						list_views()
					)
				)
			)
		)

		on btn_open_in_explorer pressed do (
			if txt_view_path.text != "" then (
				if doesfileexist txt_view_path.text then (
					ShellLaunch "explorer.exe" ("\"" + txt_view_path.text + "\"")
				) else messageBox "Directory doesn't exist" title:"Error"
			)
		)

		on btn_pick_path pressed do (
			local new_path
			if g_view_path != undefined then (
				new_path = getBitmapSaveFileName filename:g_view_path
			) else if txt_view_file.text != "" then (
				new_path = getBitmapSaveFileName filename:txt_view_file.text
			) else (
				new_path = getBitmapSaveFileName()
			)
			if new_path != undefined then (
				g_view_path = new_path
				update_Path()
				if g_active_view != undefined and g_view_path != undefined do (
					close_batch_window()
					g_active_view.outputFilename = g_view_path
				)
			)
		)

		on btn_render pressed do ( batchRenderMgr.render() )
		on btn_net_render changed state do (
			close_batch_window()
			batchRenderMgr.netRender = state
		)

		-- SINGLE CLICK: группа — только выделение, вид — загрузка параметров
		on lst_views SelectedIndexChanged sender args do (
			local index = getSel()
			if index <= 0 do return false
			local realIdx = getRealIndex index
			if realIdx > 0 then (
				local the_view = batchRenderMgr.GetView realIdx
				if isGroupView the_view then (
					txt_view_name.text = stripCollapsePrefix the_view.name
				) else (
					g_active_view = get_view_params realIdx
				)
				lst_views_update_buttons()
			)
		)

		-- DOUBLE CLICK: группы — toggle collapse, виды — toggle enabled
		on lst_views MouseDoubleClick sender args do (
			local idx = lst_views.IndexFromPoint args.X args.Y
			if idx < 0 do return false
			local realIdx = getRealIndex (idx + 1)
			if realIdx <= 0 do return false
			local the_view = batchRenderMgr.GetView realIdx
			close_batch_window()
			if isGroupView the_view then (
				local prefix = substring the_view.name 1 1
				if prefix == PROP_COLLAPSED then
					the_view.name = PROP_EXPANDED + substring the_view.name 2 -1
				else if prefix == PROP_EXPANDED then
					the_view.name = PROP_COLLAPSED + substring the_view.name 2 -1
				else
					the_view.name = PROP_COLLAPSED + the_view.name
				local savedIdx = idx + 1
				list_views()
				if savedIdx <= lst_views.Items.Count then setSel savedIdx
			) else (
				the_view.enabled = not the_view.enabled
				local savedIdx = idx + 1
				list_views()
				if savedIdx <= lst_views.Items.Count then setSel savedIdx
				get_view_params realIdx
			)
		)

		on btn_views_info pressed do (
			messageBox "Список Batch Views.\n\n— Один клик — просмотр параметров вида в UI (сцена не меняется).\n— Двойной клик — переключить enabled / свернуть-развернуть группу.\n— Кнопки слева: обновить список, добавить, дублировать, удалить, вверх/вниз, вкл/выкл." title:"Batch Views"
		)

		-- DELETE VIEW / GROUP
		on btn_rem pressed do (
			local uiSel = getSel()
			if uiSel <= 0 do return false
			local realIdx = getRealIndex uiSel
			if realIdx <= 0 do return false
			local the_view = batchRenderMgr.GetView realIdx

			close_batch_window()

			if isGroupView the_view then (
				local allData = collectAllViewData()
				local groups = splitIntoGroups allData
				local srcIdx = findGroupForView groups realIdx
				if srcIdx == 0 do return false
				local grp = groups[srcIdx]
				local grpName = stripCollapsePrefix grp[1].name
				local hasViews = false
				for vd in grp where not isGroupName vd.name do (hasViews = true; exit)
				local result = confirmDeleteGroup grpName hasViews
				if result == 0 do return false
				if result == 1 then (
					local toDelete = #()
					local flatIdx = 0
					for i = 1 to groups.count do (
						for vd in groups[i] do (
							flatIdx += 1
							if i == srcIdx do append toDelete flatIdx
						)
					)
					for i = toDelete.count to 1 by -1 do batchRenderMgr.DeleteView toDelete[i]
				) else (
					batchRenderMgr.DeleteView realIdx
				)
			) else (
				if not (queryBox "Delete this view?") do return false
				batchRenderMgr.DeleteView realIdx
			)

			g_batch_view = undefined
			g_view_name = ""
			g_active_view = undefined
			setSel 0
			list_views()
			lst_views_update_buttons()
		)

		-- DUPLICATE VIEW
		on btn_dup pressed do (
			if getSel() != 0 then (
				local realIdx = getRealIndex (getSel())
				local viewName = (batchRenderMgr.GetView realIdx).name
				batchRenderMgr.DuplicateView realIdx
				move_view_index batchRenderMgr.numViews (realIdx + 1)
				list_views()
				for i = 1 to g_visibleIndices.count do (
					if (batchRenderMgr.GetView g_visibleIndices[i]).name == viewName do (
						setSel (i + 1); exit
					)
				)
			)
		)

		-- TOGGLE ENABLED (группа = все виды в ней, одиночный вид = один)
		on btn_togleEnabled pressed do (
			local realIdx = getRealIndex (getSel())
			if realIdx <= 0 then return false
			local the_view = batchRenderMgr.GetView realIdx
			close_batch_window()

			if isGroupView the_view then (
				local bounds = getGroupBounds realIdx
				local gv = batchRenderMgr.GetView
				local newState = true
				for j = (bounds[1] + 1) to bounds[2] do (
					local v = gv j
					if not isGroupView v do (newState = not v.enabled; exit)
				)
				for j = (bounds[1] + 1) to bounds[2] do (
					local v = gv j
					if not isGroupView v do v.enabled = newState
				)
			) else (
				the_view.enabled = not the_view.enabled
			)
			list_views()
		)

		-- TOGGLE ENABLED ALL
		on btn_togleEnabledAll pressed do (
			close_batch_window()
			local num = batchRenderMgr.numViews
			local enb = 0
			local dsb = 0
			for i = 1 to num do (
				local v = batchRenderMgr.GetView i
				if not (isGroupView v) do (
					if v.enabled then enb += 1 else dsb += 1
				)
			)
			local action = not (enb > dsb)
			for i = 1 to num do (
				local the_view = batchRenderMgr.GetView i
				if not (isGroupView the_view) do the_view.enabled = action
			)
			list_views()
		)

		-- MOVE VIEW UP (группа = вся группа, одиночный вид = один)
		on btn_up pressed do (
			local realIdx = getRealIndex (getSel())
			if realIdx <= 0 do return false
			local the_view = batchRenderMgr.GetView realIdx
			local viewName = the_view.name
			if isGroupView the_view then (
				if not canMoveGroup realIdx #up do return false
				moveGroup realIdx #up
			) else (
				if realIdx <= 1 do return false
				move_view_index realIdx (realIdx - 1)
			)
			list_views restoreName:viewName
			lst_views_update_buttons()
		)

		-- ADD GROUP
		on btn_add_sep pressed do (
			local sep_name
			local n = 0
			do (
				n += 1
				sep_name = " ----- Группа " + n as string + " -----"
			) while not (isGroupNameAvailable sep_name)

			local sep_view = batchRenderMgr.CreateView undefined
			sep_view.name = sep_name
			sep_view.enabled = false

			if getSel() > 0 then (
				local realIdx = getRealIndex (getSel())
				move_view_index batchRenderMgr.numViews realIdx
			) else (
				setSel batchRenderMgr.numViews
			)

			list_views()
			for i = 1 to g_visibleIndices.count do (
				if (batchRenderMgr.GetView g_visibleIndices[i]).name == sep_name do (
					setSel i; exit
				)
			)
			lst_views_update_buttons()
		)

		-- MOVE VIEW DOWN (группа = вся группа, одиночный вид = один)
		on btn_down pressed do (
			local realIdx = getRealIndex (getSel())
			if realIdx <= 0 do return false
			local the_view = batchRenderMgr.GetView realIdx
			local viewName = the_view.name
			if isGroupView the_view then (
				if not canMoveGroup realIdx #down do return false
				moveGroup realIdx #down
			) else (
				if realIdx >= batchRenderMgr.numViews do return false
				move_view_index realIdx (realIdx + 1)
			)
			list_views restoreName:viewName
			lst_views_update_buttons()
		)

		-- RENDER OUTPUT (настраивает выделенный batch view)
		-- LOCK: при изменении W/H пропорции держит Ratio (Preserve MegaPix не учитывается)
		on chk_ratio changed status do (
			updateRatioUI()
		)

		on chk_snap changed state do (
			g_snap = state
			-- При включении — сразу применить снэп к текущим значениям
			if state do applyFieldRes (txt_out_w.text as integer) (txt_out_h.text as integer)
		)

		-- Текстовые поля: пересчёт только по Enter (entered)
		on txt_out_w entered val do (
			if suppress_res_events then return false
			if getSel() == 0 do return false
			local w = txt_out_w.text as integer
			if w == undefined or w <= 0 do return false
			local h = txt_out_h.text as integer
			if chk_ratio.checked then (
				local ratio = txt_out_ratio.text as float
				if ratio != undefined and ratio > 0 then (
					h = floor(w as float / ratio)
					if h < 1 do h = 1
				)
			)
			if h == undefined or h <= 0 do return false
			-- Снэп: сначала список стандартных разрешений, затем сетка/пропорция
			applyFieldRes w h force:true
		)
		on txt_out_h entered val do (
			if suppress_res_events then return false
			if getSel() == 0 do return false
			local h = txt_out_h.text as integer
			if h == undefined or h <= 0 do return false
			local w = txt_out_w.text as integer
			if chk_ratio.checked then (
				local ratio = txt_out_ratio.text as float
				if ratio != undefined and ratio > 0 then (
					w = floor(h as float * ratio)
					if w < 1 do w = 1
				)
			)
			if w == undefined or w <= 0 do return false
			-- Снэп: сначала список стандартных разрешений, затем сетка/пропорция
			applyFieldRes w h force:true
		)
		on txt_out_ratio entered val do (
			if suppress_res_events then return false
			if getSel() == 0 do return false
			if drdwn_re_presets.selection > 1 do return false
			local ratio = txt_out_ratio.text as float
			if ratio == undefined or ratio <= 0 do return false
			applyRatio ratio
		)

		on btn_swap pressed do (
			local oldW = txt_out_w.text as integer
			local oldH = txt_out_h.text as integer
			local oldR = txt_out_ratio.text as float
			suppress_res_events = true
			txt_out_w.text = (oldH as integer) as string
			txt_out_h.text = (oldW as integer) as string
			txt_out_ratio.text = if oldR != undefined and oldR > 0 then (1.0 / oldR) as string else "1.0"
			suppress_res_events = false
			chk_ratio.checked = false
			updateRatioUI()
			if oldW != undefined and oldH != undefined and oldW > 0 and oldH > 0 do applyViewRes oldH oldW
		)

		on drdwn_re_presets selected idx do (
			if suppress_preset_events then return false
			if idx == 1 then (
				chk_ratio.checked = false
			) else (
				chk_ratio.checked = true
				local presetRatio = g_presetRatios[idx]
				local w = txt_out_w.text as integer
				local h = txt_out_h.text as integer
				local ratio = if h != undefined and w != undefined and h > w then (1.0 / presetRatio) else presetRatio
				applyRatio ratio
			)
			updateRatioUI()
		)

		on chk_edit_base changed status do (
			if getSel() == 0 do return false
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined do return false
			local base = getViewBase bv
			showResForBase base[1] base[2]
		)

		-- OVERRIDE PRESET
		on chk_override_preset changed state do (
			if loading_view then return false
			if getSel() == 0 do ( updateOverrideUI(); return false )
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined do return false
			close_batch_window()
			bv.overridePreset = state
			updateOverrideUI()
		)

		-- RENDER PRESET
		on drdwn_render_preset selected idx do (
			if loading_view then return false
			if getSel() == 0 do return false
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined or isGroupView bv do return false
			close_batch_window()
			if idx == 1 then (
				-- Сброс: убрать render preset, вид использует свои настройки
				bv.presetFile = ""
				bv.overridePreset = true
				if not chk_override_preset.checked then chk_override_preset.checked = true
				else updateOverrideUI()
			) else (
				local pf = renderPresetFileForName drdwn_render_preset.items[idx]
				if pf == undefined do return false
				bv.presetFile = pf
				bv.overridePreset = false
				if chk_override_preset.checked then chk_override_preset.checked = false
				else updateOverrideUI()
			)
		)

	)

	--) Конец ROLLOUT: BATCH
	--------------------------------------------------------------


	--------------------------------------------------------------
	--( ROLLOUT: GLOBAL
	local roll_global = rollout roll_global "Global Batch Views Settings" (
		local roll_w = 250
		--------------------------------
		group "Sizes" (
			button btn_copy_res "Copy current resolution to all views" width:(roll_w - 40) height:25 offset:[0,5] \
				tooltip:"Set the current render resolution\nas the base for ALL batch views.\nKeeps each view's orientation:\nlandscape source is swapped\nfor portrait views and vice versa."
			slider sld_global_res "Scale:  100%" range:[1, g_scaleValues.count, 1] type:#integer ticks:g_scaleValues.count width:(roll_w / 2 - 20) \
				tooltip:"Global multiplier for ALL batch views.\nActual resolution = base in view name x scale."
			button btn_apply_res "Apply" width:(roll_w / 2 - 20) height:25 align:#left offset:[roll_w / 2 - 20, -35] \
				tooltip:"Set the current scaled resolution as the new base\nfor ALL batch views and reset scale to 100%"
		)
		
		group "Output paths" (
			button btn_set_folder "Set output folder for all views" width:(roll_w - 40) height:25 offset:[0,5]
			checkbox chk_update_re "Also update Render Elements paths" checked:true align:#left \
				tooltip:"When changing output folder,\nalso update all Render Elements output paths"
			button btn_update_re "Update Render Elements paths" width:(roll_w - 40) height:25 \
				tooltip:"Update Render Elements output paths\nusing the main render output folder"
		)
		--------------------------------
		local updating_scale = false
		--------------------------------

		-- Получить процент по индексу слайдера
		fn getPercentFromSlider = (
			local idx = sld_global_res.value as integer
			if idx < 1 then idx = 1
			if idx > g_scaleValues.count then idx = g_scaleValues.count
			g_scaleValues[idx]
		)

		-- Найти ближайшее значение из g_scaleValues
		fn getClosestScaleValue percent = (
			local closest = 1
			local minDiff = 999999
			for val in g_scaleValues do (
				local diff = abs(val - percent)
				if diff < minDiff then (minDiff = diff; closest = val)
			)
			if minDiff > 0.05 then (
				append g_scaleValues percent
				sort g_scaleValues
				sld_global_res.range = [1, g_scaleValues.count, 1]
				return percent
			)
			closest
		)

		-- Получить индекс слайдера по проценту
		fn getSliderIndexByPercent percent = (
			local bestIdx = 1
			local bestDiff = 999.0
			for i = 1 to g_scaleValues.count do (
				local diff = abs(g_scaleValues[i] - percent)
				if diff < bestDiff then (bestDiff = diff; bestIdx = i)
			)
			if bestDiff > 0.02 then (
				append g_scaleValues percent
				sort g_scaleValues
				sld_global_res.range = [1, g_scaleValues.count, 1]
				for i = 1 to g_scaleValues.count do (
					if g_scaleValues[i] == percent then return i
				)
			)
			bestIdx
		)

		-- Обновить текст и позицию слайдера
		fn updateScaleDisplay percent = (
			if percent == undefined then percent = 1
			local displayPercent = getClosestScaleValue percent
			sld_global_res.text = "Scale: " + ((displayPercent * 100) as integer) as string + "%"
			updating_scale = true
			sld_global_res.value = getSliderIndexByPercent displayPercent
			updating_scale = false
		)

		-- Применить масштаб из слайдера ко всем видам и обновить roll_batch
		fn applyGlobalScaleFromSlider = (
			local percent = getPercentFromSlider()
			g_globalScale = percent
			updateScaleDisplay percent
			applyGlobalScale()
			if g_roll_batch != undefined then (
				g_roll_batch.list_views()
				if g_roll_batch.getSel() > 0 do (
					g_roll_batch.get_view_params (g_roll_batch.getRealIndex (g_roll_batch.getSel()))
				)
			)
		)

		-- "Запечь" текущий масштабированный размер как новую базу (100%) для всех видов
		fn applyScaleAsNewBase = (
			if abs(g_globalScale - 1.0) < 0.001 do return false
			close_batch_window()
			local count = 0
			for i = 1 to batchRenderMgr.NumViews do (
				local v = batchRenderMgr.GetView i
				if v != undefined and not (isGroupView v) then (
					local base = getViewBase v
					if base[1] > 0 and base[2] > 0 then (
						local scaled = resFromBase base[1] base[2]
						local clean = getCleanViewName v.name
						v.name = clean
						v.overridePreset = true
						v.width = scaled[1]
						v.height = scaled[2]
						count += 1
					)
				)
			)
			g_globalScale = 1.0
			updateScaleDisplay 1.0
			if g_roll_batch != undefined then (
				g_roll_batch.chk_override_preset.checked = true
				g_roll_batch.chk_edit_base.checked = false
				g_roll_batch.updateOverrideUI()
				g_roll_batch.list_views()
				if g_roll_batch.getSel() > 0 do (
					g_roll_batch.get_view_params (g_roll_batch.getRealIndex (g_roll_batch.getSel()))
				)
			)
			count
		)

		--------------------------------
		on roll_global open do (
			updateScaleDisplay g_globalScale
			btn_update_re.enabled = not chk_update_re.checked
		)

		on roll_global close do ( saveFloaterState() )
		on roll_global rolledUp state do ( accordion roll_global state )

		on chk_update_re changed status do (
			btn_update_re.enabled = not status
		)

		on sld_global_res changed val do (
			if updating_scale then return false
			applyGlobalScaleFromSlider()
		)

		on btn_apply_res pressed do (
			applyScaleAsNewBase()
		)

		on btn_set_folder pressed do (
			local folder = getSavePath caption:"Select output folder"
			if folder == undefined do return false
			local count = setOutputFolderForAll folder
			if chk_update_re.checked do setRePathsForAll folder
			if count > 0 and g_roll_batch != undefined then (
				g_roll_batch.list_views()
				if g_roll_batch.getSel() > 0 do (
					g_roll_batch.get_view_params (g_roll_batch.getRealIndex (g_roll_batch.getSel()))
				)
			)
		)

		on btn_update_re pressed do (
			local folder = getSavePath caption:"Select folder for Render Elements"
			if folder == undefined do return false
			setRePathsForAll folder
		)

		on btn_copy_res pressed do (
			if renderWidth <= 0 or renderHeight <= 0 do return false
			close_batch_window()
			local count = 0
			for i = 1 to batchRenderMgr.NumViews do (
				local v = batchRenderMgr.GetView i
				if v != undefined and not (isGroupView v) then (
					local r = orientedCopyResForView v renderWidth renderHeight
					setViewBase v r[1] r[2]
					count += 1
				)
			)
			if count > 0 and g_roll_batch != undefined then (
				g_roll_batch.list_views()
				if g_roll_batch.getSel() > 0 do (
					g_roll_batch.get_view_params (g_roll_batch.getRealIndex (g_roll_batch.getSel()))
				)
			)
		)

	)

	--) Конец ROLLOUT: GLOBAL
	--------------------------------------------------------------


	--------------------------------------------------------------
	--( ROLLOUT: MANAGE SCENE STATES

	local roll_states = rollout roll_states "Manage Scene States" (
		local roll_w = 250
		--------------------------------
		button btn_states_info "?" width:20 height:18 align:#right offset:[10,0] \
			tooltip:"Scene states. Single click — select.\nDouble click — apply."
		dotNetControl lst_states "System.Windows.Forms.ListBox" height:265 offset:[-10, -22] \
		button btn_states_del "❌" width:24 height:25 align:#right offset:[14,-30] \
			tooltip:"Delete the selected state"
		edittext txt_states_new "State name" fieldWidth:(roll_w - 40) labelOnTop:true offset:[-10, 0]\
			tooltip:"Enter — rename the selected state.\nNew — used when no state is selected."
		button btn_states_new "➕ New" width:(roll_w / 2 - 20) height:22 across:2 offset:[-10, 0]\
			tooltip:"Create a state from the selected one,\nappending a sequence number.\nSelects the new state for editing."
		button btn_states_update "Update" width:(roll_w / 2 - 20) height:22 offset:[-10, 0]\
			tooltip:"Overwrite the selected state\nwith the current scene"

		group "Parts to capture" (
			button btn_parts_info "?" width:20 height:18 align:#right offset:[10,0] \
				tooltip:"Parts to save. Ctrl+click — toggle.\nSingle click on a state above loads its parts."
			dotNetControl lst_states_parts "System.Windows.Forms.ListBox" height:140 offset:[-10, -22] \
			button btn_parts_all "Select all" width:70 height:20 align:#left across:2 offset:[-10,0]
			button btn_parts_none "Clear" width:60 height:20 align:#right offset:[-10,0]
		)
		--------------------------------

		fn stateNames = (
			local names = for i in 1 to sceneStateMgr.GetCount() collect (sceneStateMgr.GetSceneState i)
			qsort names (fn cmp a b = ( stricmp a b ))
			names
		)

		fn getStatesSel = ( lst_states.SelectedIndex + 1 )

		fn setStatesSel idx = ( lst_states.SelectedIndex = if idx > 0 then idx - 1 else -1 )

		fn initStatesListBox = (
			lst_states.SelectionMode = (dotNetClass "System.Windows.Forms.SelectionMode").One
			lst_states.IntegralHeight = false
			lst_states.BackColor = (dotNetClass "System.Drawing.Color").FromARGB 40 40 43
			lst_states.ForeColor = (dotNetClass "System.Drawing.Color").White
		)

		fn updateStateButtons = (
			local hasSel = getStatesSel() > 0
			btn_states_update.enabled = hasSel
			btn_states_del.enabled = hasSel
		)

		fn refreshStates = (
			local prevName = if getStatesSel() > 0 then lst_states.SelectedItem as string else ""
			local names = stateNames()
			lst_states.BeginUpdate()
			lst_states.Items.Clear()
			for n in names do lst_states.Items.Add n
			lst_states.EndUpdate()
			if prevName != "" then (
				local idx = findItem names prevName
				if idx > 0 do setStatesSel idx
			)
			updateStateButtons()
		)

		-- Список частей состояния (имена)
		fn partNames = (
			for i in 1 to sceneStateMgr.PartsCount() collect (sceneStateMgr.MapIndexToPart i)
		)

		-- Заполнить список частей
		fn refreshPartsList = (
			local parts = partNames()
			lst_states_parts.BeginUpdate()
			lst_states_parts.Items.Clear()
			for p in parts do lst_states_parts.Items.Add p
			lst_states_parts.EndUpdate()
		)

		fn initPartsListBox = (
			lst_states_parts.SelectionMode = (dotNetClass "System.Windows.Forms.SelectionMode").MultiExtended
			lst_states_parts.IntegralHeight = false
			lst_states_parts.BackColor = (dotNetClass "System.Drawing.Color").FromARGB 40 40 43
			lst_states_parts.ForeColor = (dotNetClass "System.Drawing.Color").White
		)

		-- Выделить части согласно bitArray (1-based индексы частей)
		fn setPartsSelection ba = (
			if ba == undefined do ba = #{}
			lst_states_parts.BeginUpdate()
			for i = 0 to lst_states_parts.Items.Count - 1 do lst_states_parts.SetSelected i (ba[(i + 1)] == true)
			lst_states_parts.EndUpdate()
		)

		-- bitArray выделенных частей (для sceneStateMgr.Capture)
		fn selectedParts = (
			local ba = #{}
			for i = 0 to lst_states_parts.Items.Count - 1 do (
				if lst_states_parts.GetSelected i do ba[i + 1] = true
			)
			ba
		)

		fn selectAllParts = (
			lst_states_parts.BeginUpdate()
			for i = 0 to lst_states_parts.Items.Count - 1 do lst_states_parts.SetSelected i true
			lst_states_parts.EndUpdate()
		)

		fn clearParts = (
			lst_states_parts.BeginUpdate()
			for i = 0 to lst_states_parts.Items.Count - 1 do lst_states_parts.SetSelected i false
			lst_states_parts.EndUpdate()
		)

		-- Загрузить состояние в UI: имя в поле + части в список
		fn loadStateIntoUI name = (
			txt_states_new.text = name
			setPartsSelection (sceneStateMgr.GetParts name)
		)

		-- Разобрать имя: префикс, разделитель и хвостовой номер.
		-- "Cam 3" -> #("Cam", " ", 3); "Cam1" -> #("Cam", "", 1);
		-- "Cam_1" -> #("Cam", "_", 1);  "3" -> #("", "", 3); без номера -> undefined
		fn parseStateName name = (
			local end = name.count
			while end > 0 and (findstring "0123456789" name[end]) != undefined do end -= 1
			local numStr = subString name (end + 1) (name.count - end)
			if numStr.count == 0 do return undefined
			local num = (numStr as integer)
			local prefix = subString name 1 end
			local sep = ""
			if prefix.count > 0 then (
				local lastCh = prefix[prefix.count]
				if lastCh == " " or lastCh == "_" or lastCh == "-" then (
					sep = lastCh
					prefix = subString prefix 1 (prefix.count - 1)
				)
			)
			#(prefix, sep, num)
		)

		-- Следующее имя: максимальный номер среди состояний с тем же префиксом + 1,
		-- с разделителем выбранного состояния ("Cam 3" -> "Cam 4", "Cam1" -> "Cam2", "3" -> "4")
		fn nextStateName baseName = (
			local parsed = parseStateName baseName
			local prefix = baseName, sep = " "
			if parsed != undefined do ( prefix = parsed[1]; sep = parsed[2] )
			local maxNum = 0
			for n in stateNames() do (
				local p = parseStateName n
				if p != undefined and p[1] == prefix do maxNum = amax maxNum p[3]
			)
			prefix + sep + ((maxNum + 1) as string)
		)

		-- Восстановить состояние сцены
		fn state_retore = (
			if getStatesSel() <= 0 do ( messageBox "Select a scene state to apply." title:"Apply Scene State"; return false )
			local name = lst_states.SelectedItem as string
			try (
				local ssp = sceneStateMgr.GetParts name
				sceneStateMgr.Restore name ssp
			) catch (
				messageBox ("Can't restore scene state:\n" + (getCurrentException() as string)) title:"Apply Scene State"
				return false
			)
		)
		
		on roll_states open do (
			initStatesListBox()
			initPartsListBox()
			refreshStates()
			refreshPartsList()
			selectAllParts()
		)
		on roll_states close do ( saveFloaterState() )
		on roll_states rolledUp state do ( accordion roll_states state )

		on lst_states SelectedIndexChanged sender args do (
			updateStateButtons()
			if getStatesSel() > 0 do loadStateIntoUI (lst_states.SelectedItem as string)
		)

		-- DOUBLE CLICK: применить состояние
		on lst_states MouseDoubleClick sender args do (
			local idx = lst_states.IndexFromPoint args.X args.Y
			if idx < 0 do return false
			lst_states.SelectedIndex = idx
			state_retore()
		)

		on btn_states_info pressed do (
			messageBox "Scene States manager.\n\nApply — restore the selected scene state.\nUpdate — overwrite the selected state with the current scene.\nNew — create a state from the selected one,\nappending a sequence number.\nDelete — remove the selected state.\n\nState name field: single click on a state\nloads its name — edit it and press Enter\nto rename.\n\n'Parts to capture' — select parts (light/camera/\nobject/layer/material/environment...)\nwith Ctrl+click when creating or overwriting\na state. Single click on a state loads its parts." title:"Manage Scene States"
		)

		on btn_parts_all pressed do ( selectAllParts() )
		on btn_parts_none pressed do ( clearParts() )

		on btn_states_new pressed do (
			local name
			if getStatesSel() > 0 then (
				name = nextStateName (lst_states.SelectedItem as string)
			) else (
				name = trimLeft (trimRight txt_states_new.text)
				if name == "" do ( messageBox "Enter a name for the new state." title:"New Scene State"; return false )
				if findItem (stateNames()) name != 0 do ( messageBox "A state with this name already exists." title:"New Scene State"; return false )
			)
			local parts = selectedParts()
			if parts.isEmpty do ( messageBox "Select at least one part to capture." title:"New Scene State"; return false )
			try (
				if not (sceneStateMgr.Capture name parts) then (
					messageBox "Can't create scene state (Capture failed)." title:"New Scene State"
					return false
				)
			) catch (
				messageBox ("Can't create scene state:\n" + (getCurrentException() as string)) title:"New Scene State"
				return false
			)
			refreshStates()
			local idx = findItem (stateNames()) name
			if idx > 0 do setStatesSel idx
			if g_roll_batch != undefined do g_roll_batch.refreshStatesList()
		)

		on btn_states_update pressed do (
			if getStatesSel() <= 0 do ( messageBox "Select a scene state to overwrite." title:"Update Scene State"; return false )
			local name = lst_states.SelectedItem as string
			if not (queryBox ("Overwrite \"" + name + "\" with the current scene?") title:"Update Scene State") do return false
			local parts = selectedParts()
			if parts.isEmpty do ( messageBox "Select at least one part to capture." title:"Update Scene State"; return false )
			try (
				sceneStateMgr.Delete name
				if not (sceneStateMgr.Capture name parts) then (
					messageBox "Can't update scene state (Capture failed)." title:"Update Scene State"
					return false
				)
			) catch (
				messageBox ("Can't update scene state:\n" + (getCurrentException() as string)) title:"Update Scene State"
				return false
			)
			if g_roll_batch != undefined do g_roll_batch.refreshStatesList()
		)

		-- RENAME по событию Enter в поле имени (без кнопки)
		on txt_states_new entered val do (
			if getStatesSel() <= 0 do return false
			local oldName = lst_states.SelectedItem as string
			local newName = trimLeft (trimRight val)
			if newName == "" do ( messageBox "Enter a new name." title:"Rename Scene State"; return false )
			if newName == oldName do return false
			if findItem (stateNames()) newName != 0 do ( messageBox "A state with this name already exists." title:"Rename Scene State"; return false )
			try (
				sceneStateMgr.Rename oldName newName
			) catch (
				messageBox ("Can't rename scene state:\n" + (getCurrentException() as string)) title:"Rename Scene State"
				return false
			)
			refreshStates()
			local idx = findItem (stateNames()) newName
			if idx > 0 do setStatesSel idx
			if g_roll_batch != undefined do g_roll_batch.refreshStatesList()
		)

		on btn_states_del pressed do (
			if getStatesSel() <= 0 do ( messageBox "Select a scene state to delete." title:"Delete Scene State"; return false )
			local name = lst_states.SelectedItem as string
			if not (queryBox ("Delete scene state \"" + name + "\"?") title:"Delete Scene State") do return false
			try (
				sceneStateMgr.Delete name
			) catch (
				messageBox ("Can't delete scene state:\n" + (getCurrentException() as string)) title:"Delete Scene State"
				return false
			)
			refreshStates()
			if g_roll_batch != undefined do g_roll_batch.refreshStatesList()
		)
	)
	--) Конец ROLLOUT: MANAGE SCENE STATES
	--------------------------------------------------------------


	--------------------------------------------------------------
	-- TOOL MAIN UI
	fn showUI =
	(
		local res = false
		if (g_floater != undefined AND g_floater.open) then (
			try (closeRolloutFloater g_floater) catch ()
			g_floater = undefined
		) else (
			g_roll_cams   = roll_Cams
			g_roll_batch  = roll_batch
			g_roll_global = roll_global
			g_roll_states = roll_states

			local iniPath = getmaxinifile()
			local posStr = getINISetting iniPath "CamManager" "Position"
			local sizeStr = getINISetting iniPath "CamManager" "WindowsSize"
			if posStr != "" and sizeStr != "" then (
				local p = execute posStr
				local s = execute sizeStr
				g_floater = newRolloutFloater "Batch Views Manager" s[1] s[2] p[1] p[2] lockHeight:false lockWidth:true
			) else (
				g_floater = newRolloutFloater "Batch Views Manager" g_dialog_width 663 50 50 lockHeight:false lockWidth:true
			)
			local rolloutOpened = getINISetting iniPath "CamManager" "RolloutOpened"
			if not (hasBatchViews()) then rolloutOpened = "Cams"
			if rolloutOpened != "Batch" and rolloutOpened != "Global" and rolloutOpened != "States" then rolloutOpened = "Cams"
			local snapStr = getINISetting iniPath "CamManager" "Snap"
			try ( if snapStr != "" then g_snap = (snapStr as BooleanClass) ) catch ()
			g_accordion_lock = true
			addRollout g_roll_cams g_floater rolledup:(rolloutOpened != "Cams")
			addRollout g_roll_batch g_floater rolledUp:(rolloutOpened != "Batch")
			addRollout g_roll_global g_floater rolledUp:(rolloutOpened != "Global")
			addRollout g_roll_states g_floater rolledUp:(rolloutOpened != "States")
			g_roll_cams.open   = (rolloutOpened == "Cams")
			g_roll_batch.open  = (rolloutOpened == "Batch")
			g_roll_global.open = (rolloutOpened == "Global")
			g_roll_states.open = (rolloutOpened == "States")
			g_accordion_lock = false
			g_last_opened_tab = rolloutOpened
			updateFloaterHeight()

			res = true
		)
		res
	)
	------------------------------------------------------

	on execute do (
		showUI()
	)
)
