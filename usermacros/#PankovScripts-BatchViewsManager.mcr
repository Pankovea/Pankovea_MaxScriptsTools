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
* Функции и обработчики названы в camelCase.
*
* РАЗРЕШЕНИЕ
* ===============
* Глобальный масштаб (slider) — единый множитель для всех видов:
* фактическое разрешение вида = база x масштаб.
* Исходное разрешение хранится в ИМЕНИ batch view как база: "CamA (1920x1080)".
* для точного восстановления.
* Смена камеры читает разрешение из её видов (getCamResFromViews).
*
* Галка "Base size" (chk_edit_base) — режим отображения И применения размеров:
*   ON  — поля показывают БАЗУ (100%), ввод трактуется как база;
*   OFF — поля показывают ТЕКУЩИЙ (масштабированный) размер, база = ввод / масштаб.
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
*    Для целей с заданными мегапикселями (поле Мпикс, Preserve MegaPix) —
*    snapResolutionKeepMP(w, h, mpPx): кандидат «точные пиксели × стандартная
*    пропорция» соревнуется со стандартным списком/сеткой по близости к цели.
*
* ВВОД РАЗМЕРОВ (блок Render output в roll_batch)
* =================================================
* СЦЕНА: если камера вида стоит в каком-либо вьюпорте, любое изменение его
* разрешения сразу применяется к сцене (renderWidth/renderHeight) —
* syncSceneResFromView(); критерий именно камера во вьюпорте, а не совпадение
* со старым разрешением сцены.
* LOCK (chk_ratio + пресеты drdwn_re_presets): при вводе одной стороны вторая
* пересчитывается под пропорцию.
* "Preserve MegaPix" (chk_preserve_mp): при смене ratio/копировании обе стороны
* пересчитываются под пропорции с сохранением MP. При вводе ОДНОЙ стороны (W/H)
* приоритет выше LOCK: вторая сторона = округлённые суммарные пиксели вида /
* введённая сторона (данные вида, не текст полей — в поле уже новое значение).
* "MPix" (txt_out_mp): показывает мегапиксели показанных WxH (updateMpixField);
* ввод значения пересчитывает W/H под текущие пропорции. Событие галки Preserve
* MegaPix меняет ТОЛЬКО активность этого поля. Гаснет также без Override/вида.
*   applyFieldRes(w,h)  — ввод размеров (снэп + LOCK), force:true — всегда;
*   applyRatio(r)       — ввод пропорции;
*   applyViewRes(w,h)   — применение размера (без снэпа);
*   applyMultiFieldRes(m,v) — см. МАССОВОЕ РЕДАКТИРОВАНИЕ.
*
* МАССОВОЕ РЕДАКТИРОВАНИЕ (2+ выделенных видов в lst_views)
* ===========================================================
* При выделении 2+ НЕ-групповых видов включается мульти-режим: цели —
* getMultiEditIdxs() (выделенные виды, группы исключаются), активность — isMultiEdit().
* Применимые контролы (batch_multi_controls) активны, неприменимые
* (batch_single_controls — имя, файл, explorer, btn_copy_res) деактивируются.
* updateMultiUI() заполняет поля ОБЩИМ значением (совпадает у всех) либо маркером "*";
* изменение применяется ко ВСЕМ выделенным видам.
* g_multi_ovr_editable — разрешено ли редактирование размера/кадров (Override общий
* ВКЛ или отличается у видов);
* updateOverrideUI() — диспетчер single/multi.
* Применение:
*   applyViewRes(w,h)       — ОБЩАЯ база: установить базу всем целям
*                             (singleMode сохраняет прежнее поведение активного вида);
*   applyMultiFieldRes(m,v) — РАЗНЫЕ базы (поля "*"): как btn_copy_res — каждый вид
*                             получает своё целевое разрешение под свои пропорции;
*                             предупреждение только при смене пропорций (и не включён
 *                             Preserve MegaPix), иначе молча. mode: #w/#h/#ratio/#mp/#swap.
* Путь: txt_view_path/btn_pick_path → setMultiPath/setMultiPathFromPicked — массово
* меняется только папка, имена файлов видов сохраняются.
* Камера: drdwn_cam/btn_use_active_cam — назначается всем, диалог базы — один раз.
* restoreSelectionByReal() — перестроить список и вернуть выделение по реальным индексам.
*
* UI-СОБЫТИЯ И ПРОГРАММНОЕ ЗАПОЛНЕНИЕ
* ====================================
* Программная установка свойств UI (text, selection, value, checked) НЕ триггерит
* обработчики changed/entered/selected (подтверждено тестом) — suppression-флагов
* в коде нет и они не нужны. Обработчики вызываются только действиями пользователя.
*
* КЛЮЧЕВЫЕ ФУНКЦИИ
* =================
*   parseViewName()        — база из имени вида
*   viewNameFor()          — имя с базой из w/h
*   getCleanViewName()     — имя без суффикса базы
*   getViewBase()          — база вида (имя → разрешение вида → render)
*   setViewBase()          — переименовать вид + обновить width/height
*   resFromBase()          — фактическое разрешение из базы и масштаба
*   orientedCopyResForView() — WxH, развёрнутое под ориентацию вида
*   ratioString()          — "W:H" для диалогов
*   getCamResFromViews()   — разрешение камеры из её видов
*   applyCamResToScene()   — загрузить разрешение камеры в сцену
*   applyGlobalScale()     — применить глобальный масштаб ко всем видам
*   syncViewsForCam()      — синхронизировать виды камеры ('Base size': база / текущий)
*   snapResolution()       — конвейер снэпа: список стандартов → округление (галка Snap)
*   findClosestStandardResolution() — прилипание к g_standardResolutions
*   calculateSmartResolution()      — округление к сетке 32/16 и стандартному аспекту
*   updateMultiUI/updateOverrideUI/updateRatioUI/updateCopyResBtn — состояние UI
 *   listViews()/restoreSelectionByReal() — список и восстановление выделения
 *   getViewportCam()       — активная камера: активный вьюпорт, иначе поиск по всем вьюпортам
 *   followSelectionToCam() — при активации камеры: одна камера в выделении сцены —
 *                            выделить новую; прочие выделения не трогаются
*
* КОПИРОВАНИЕ РАЗМЕРА (btn_copy_res)
* ===================================
* Источник — АКТИВНЫЙ вид (загруженный в интерфейс, g_active_view). Копирование в
* текущем представлении ('Base size' ON — база, OFF — текущий размер). При Preserve
* MegaPix OFF каждый вид получает WxH источника, развёрнутое под его ориентацию
* (orientedCopyResForView); при ON — пропорции вида сохраняются, пересчитывается
* мегапиксель. Диалог-подтверждение только если у какого-то из ОСТАЛЬНЫХ видов
* меняются пропорции (и не включён Preserve MegaPix).
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
 * REFRESH / СИНХРОНИЗАЦИЯ ВЫДЕЛЕНИЯ
 * =================================
 * Refresh (оба свитка): активная камера определяется поиском по вьюпортам
 * (getViewportCam) и выделяется в списке камер; в batch выделяется первый
 * вид этой камеры (selectFirstViewForCamera).
 * Активация камеры (setActiveCam / applyViewToScene): если в выделении сцены
 * ровно одна камера — выделение переносится на новую камеру
 * (followSelectionToCam); при любом другом выделении ничего не меняется.
 *
 * ГРУППЫ ВИДОВ
* ============
* Разделители "----- Группа N -----". Перемещаются/удаляются как блок.
* Сворачивание по двойному клику: ▶ свёрнута / ▼ развёрнута.
*
 * СВИТКИ
 * ======
 *   roll_Cams   "Cameras"             — камеры + параметры + rename + create view
 *   roll_batch  "Batch Views"         — виды + база разрешения + sync + render output
 *   roll_global "Batch Views Global"  — global scale + пути
 *   roll_states "Scene States" — scene states: список/apply/save/new/rename/delete
 *   roll_lang   "Language & Info"     — язык интерфейса, версия и репозиторий
 *
 * ЦЕПОЧКА ИНИЦИАЛИЗАЦИИ
 * =====================
 *   showUI()
 *     → rollout roll_Cams / roll_batch / roll_global / roll_states / roll_lang — свитки на уровне макроса
 *     → g_roll_cams/batch/global/states/lang = <свиток> — ссылки для кросс-доступа
 *     → addRollout roll_Cams   → on open: initCamListBox, relistCams, changeActive
 *     → addRollout roll_batch  → on open: initListBox, listViews, chk_snap, updateOverrideUI
 *     → addRollout roll_global → on open: восстановить scale
 *     → addRollout roll_states → on open: refreshStates
 *     → addRollout roll_lang   → on open: язык (или ссылки на скачивание), версия
 */
macroScript Pankovea_BatchViewsManager
	category:     "#PankovScripts"
	ButtonText:   "Batch Views Manager"
	tooltip:      "Manage Cameras and render batch views"
	silentErrors: false
	icon:         #("extratools", 1)
(
	--------------------------------------------------------------
	-- i18n: general wrapper #PankovScripts-L10N.ms (protection against missing file)
	local L10N_VER = 1 -- Expected engine API version
	local L10N
	local thisScriptPath = getThisScriptFilename()
	local scriptBaseName = getFilenamePath thisScriptPath + getFilenameFile thisScriptPath
	local l10n_engine = getFilenamePath thisScriptPath + "#PankovScripts-L10N.ms"
	local l10n_en = Dictionary #(
			"appTitle", "Batch Views Manager") #(
			"titleCameras", "Cameras") #(
			"titleError", "Error") #(
			"titleCameraBase", "Camera Base") #(
			"titleBatchViews", "Batch Views") #(
			"titleApplyState", "Apply Scene State") #(
			"titleManageStates", "Manage Scene States") #(
			"titleNewState", "New Scene State") #(
			"titleUpdateState", "Update Scene State") #(
			"titleRenameState", "Rename Scene State") #(
			"titleDeleteState", "Delete Scene State") #(
			"camerasInfo", "Single click — preview camera parameters and resolution in the UI (scene unchanged).\nDouble click — activate the camera and load its resolution into the scene.") #(
			"selectCameraFirst", "Select a camera first") #(
			"createdBatchViews", "Created batch views: {0}") #(
			"viewExists", "View already exists.\nChange name and try again.") #(
			"dirNotExist", "Directory doesn't exist") #(
			"applyAsBase", "Apply {0}x{1} as base for this view?") #(
			"batchViewsInfoMsg", "Batch Views list.\n\n— Single click — preview view parameters in the UI (scene unchanged).\n— Repeat click on a selected item — toggle enabled (view) / collapse or expand a group.\n— Double click on a view — apply the view to the scene: camera + resolution + scene state (checkbox unchanged).\n— Ctrl/Shift — multi-select: enable/disable and move up/down act on all selected items\n  and on all views inside selected groups.\n— Buttons on the left: refresh list, add, duplicate, delete, move up/down,\n  enable/disable (selected) and enable/disable all.") #(
			"deleteView", "Delete this view(s)?") #(
			"selectStateToApply", "Select a scene state to apply.") #(
			"cantRestoreState", "Can't restore scene state:\n{0}") #(
			"statesInfo", "Scene States manager.\n\nApply — restore the selected scene state.\nUpdate — overwrite the selected state with the current scene.\nNew — create a state from the selected one,\nappending a sequence number.\nDelete — remove the selected state.\n\nState name field: single click on a state\nloads its name — edit it and press Enter\nto rename.\n\n'Parts to capture' — select parts (light/camera/\nobject/layer/material/environment...)\nwith Ctrl+click when creating or overwriting\na state. Single click on a state loads its parts.") #(
			"enterNewStateName", "Enter a name for the new state.") #(
			"stateExists", "A state with this name already exists.") #(
			"selectPartToCapture", "Select at least one part to capture.") #(
			"cantCreateState", "Can't create scene state (Capture failed).") #(
			"cantCreateStateEx", "Can't create scene state:\n{0}") #(
			"selectStateToOverwrite", "Select a scene state to overwrite.") #(
			"overwriteState", "Overwrite \"{0}\" with the current scene?") #(
			"cantUpdateState", "Can't update scene state (Capture failed).") #(
			"cantUpdateStateEx", "Can't update scene state:\n{0}") #(
			"enterNewName", "Enter a new name.") #(
			"cantRenameState", "Can't rename scene state:\n{0}") #(
			"selectStateToDelete", "Select a scene state to delete.") #(
			"deleteStateQuery", "Delete scene state \"{0}\"?") #(
			"cantDeleteState", "Can't delete scene state:\n{0}") #(
			"deleteEmptyGroup", "Delete empty group \"{0}\"?") #(
			"groupWord", "Group") #(
			"scaleText", "Scale: {0}%") #(
			"deleteGroupQuery", "Delete \"{0}\"?") #(
			"delGroupAll", "Group + Views") #(
			"delGroupOnly", "Group Only") #(
			"delViewOk", "Delete") #(
			"selectOutputFolder", "Select output folder") #(
			"selectReFolder", "Select folder for Render Elements") #(
			"copyResConfirm", "Copy current view's resolution to ALL views?\nThis cannot be undone.\n\nThe following views will change their PROPORTIONS:\n{0}") #(
			"roll_batch.btn_copy_res", "Copy cur res to all views") #(
			"roll_batch.btn_copy_res_mp", "Copy MegaPix to all views") #(
			"setFolderConfirm", "Set the output folder for ALL views?\nThis cannot be undone.\n\nCurrent output folders:\n{0}") #(
			"version", "Version")
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
		fn langLabel code = code,
		fn registerDict code dict = true
	)
	-- Load the engine; on failure fall back to English (version check is inside).
	local L10N_struct = L10N_Fallback
	try (
		if doesFileExist l10n_engine then L10N_struct = fileIn l10n_engine
		L10N = L10N_struct scriptBaseName:scriptBaseName enDict:l10n_en engineVer:L10N_VER
	) catch (
		format ">>> L10N: %\n" (getCurrentException())
		L10N = L10N_Fallback scriptBaseName:scriptBaseName enDict:l10n_en
	)
	--------------------------------------------------------------
	-- SHARED STATE (уровень макроса, обмен между свитками)
	--------------------------------------------------------------
	local g_floater
	local g_dialog_width = 250
	local g_roll_cams
	local g_roll_batch
	local g_roll_global
	local g_roll_states
	local g_roll_lang
	local g_version = "1.0.0 (2026-08-09)"
	local g_repoUrl = "https://github.com/Pankovea"
	local g_last_opened_tab = "Cams"

	-- камеры
	local g_active_cam
	local g_cam_list = #()          -- массив камер (node)
	local g_curr_itm = 1
	local g_only_visible = true     -- показывать только видимые камеры

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
	local g_presetNames = #("Free", "1:1", "3:2", "4:3", "16:10", "16:9", "2:1", "21:9", "A series")

	-- контекстное меню удаления: rcmenu rmc_del_group/rmc_del_view определены на
	-- уровне макроса (блок перед rollout roll_batch); их обработчики обращаются
	-- к rollout-локалям свитка через объект g_roll_batch (delApply/delGroupsCtx).

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

	-- Получить отсортированный по имени список камер сцены.
	-- При g_only_visible=true показываются только видимые (не скрытые) камеры,
	-- иначе — все камеры сцены.
	fn getCameraList = (
		local ls
		if g_only_visible then (
			ls = for cam in cameras where (isKindOf cam camera) and not cam.isHidden collect cam
		) else (
			ls = for cam in cameras where (isKindOf cam camera) collect cam
		)
		qsort ls compareCamNames
		ls
	)

	-- Активная камера сцены: камера активного вьюпорта (getActiveCamera),
	-- иначе первая найденная камера среди всех вьюпортов.
	fn getViewportCam = (
		local cam = getActiveCamera()
		if cam == undefined then (
			for i in 1 to viewport.numViews where cam == undefined do (
				local vc = viewport.getCamera index:i
				if vc != undefined and isValidNode vc and (isKindOf vc camera) do cam = vc
			)
		)
		cam
	)

	-- Следование за камерой при её активации: если в выделении сцены ровно
	-- ОДНА камера — перенести выделение на только что активированную камеру.
	-- Любое другое выделение (пусто, несколько объектов, не камера) не меняется.
	fn followSelectionToCam cam = (
		if cam != undefined and isValidNode cam and selection.count == 1 and \
			(isKindOf selection[1] camera) and selection[1] != cam do select cam
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
		-- Кратность высоты НЕ должна ломать распознанную стандартную пропорцию
		-- (иначе масштабированный размер "уезжает" в Free: было 2800x2100 -> 4:3,
		-- становилось 928x704 -> Free). К сетке округляем только если отклонение
		-- от стандарта остаётся в допуске.
		local gh = tryRoundToMultiple newH g_gridH (g_gridTolerance / 2)
		if gh != newH and (stdAspect == undefined or \
			abs((newW as float / gh) - stdAspect) <= g_aspectTolerance) then newH = gh
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

	-- Снэп с приоритетом ЦЕЛЕВЫХ пикселей (поле Мпикс, Preserve MegaPix):
	-- рядом с обычным конвейером строится кандидат «стандартная пропорция ×
	-- точное число целевых пикселей»; побеждает тот, кто ближе к цели.
	-- Так ввод 6 Мпикс при пропорции ~3:2 даёт ровно 3000x2000,
	-- а не ближайший стандарт из списка (+0.3% пикселей).
	fn snapResolutionKeepMP w h mpPx = (
		if w == undefined or h == undefined or mpPx == undefined or mpPx <= 0 then
			return #(w as integer, h as integer)
		local base = snapResolution w h
		if not g_snap then return #(base[1], base[2])
		local stdAsp = findStandardAspect (w as float / h as float)
		if stdAsp == undefined then return #(base[1], base[2])
		local cw = (floor ((sqrt (mpPx * stdAsp)) + 0.5)) as integer
		local ch = (floor ((sqrt (mpPx / stdAsp)) + 0.5)) as integer
		local dBase = abs((base[1] as float * base[2]) - mpPx)
		local dCand = abs((cw as float * ch) - mpPx)
		if dCand < dBase then #(cw, ch) else #(base[1], base[2])
	)

	--------------------------------------------------------------
	--) ЕДИНЫЙ РАСЧЁТ РАЗРЕШЕНИЯ
	--------------------------------------------------------------

	-- Центральная семантика ввода: обработчики строят НАМЕРЕНИЕ (Dictionary),
	-- resolveRes возвращает готовую пару WxH. Применять результат как есть,
	-- НЕ добавляя собственных пересчётов и повторных снэпов.
	--   #mode      — #wh | #width | #height | #ratio | #mp | #swap
	--   #w,#h      — исходное состояние (пространство полей: база или масштаб)
	--   #val,#val2 — значение ввода (#val2 только для #wh)
	--   #ratio     — пропорция пресета/LOCK (для #width/#height/#ratio)
	--   #mpPx      — целевые пиксели (для #mp)
	--   #lock,#preserve — режимы (false по умолчанию)
	--   #snap      — переопределение галки снэпа (по умолчанию g_snap)
	fn resolveRes intent = (
		local rawW = intent[#w]
		local rawH = intent[#h]
		if rawW == undefined or rawH == undefined then return #(0, 0)
		local sw = rawW as integer
		local sh = rawH as integer
		if sw <= 0 or sh <= 0 then return #(0, 0)
		local mode = intent[#mode]
		if mode == undefined then mode = #wh
		local lock = (intent[#lock] == true)
		local preserve = (intent[#preserve] == true)
		local snapOn = if intent[#snap] == undefined then g_snap else (intent[#snap] == true)
		local srcRatio = sw as float / sh
		local srcPx = (sw as float) * sh
		local tw = sw
		local th = sh
		case mode of (
			#wh: ( tw = intent[#val]; th = intent[#val2] )
			#swap: ( tw = sh; th = sw )
			#width: (
				tw = intent[#val]
				th = if preserve and srcPx > 0 then ((floor (srcPx / tw + 0.5)) as integer) else (
					if lock and intent[#ratio] != undefined and intent[#ratio] > 0 \
						then (floor (tw as float / intent[#ratio])) else th
				)
			)
			#height: (
				th = intent[#val]
				tw = if preserve and srcPx > 0 then ((floor (srcPx / th + 0.5)) as integer) else (
					if lock and intent[#ratio] != undefined and intent[#ratio] > 0 \
						then (floor (th as float * intent[#ratio])) else tw
				)
			)
			#ratio: (
				local r = if intent[#ratio] != undefined then intent[#ratio] else srcRatio
				if preserve and srcPx > 0 then (
					tw = (floor ((sqrt (srcPx * r)) + 0.5)) as integer
					th = (floor ((sqrt (srcPx / r)) + 0.5)) as integer
				) else (
					tw = sw
					th = floor(sw as float / r)
				)
			)
			#mp: (
				local mpPx = intent[#mpPx]
				if mpPx != undefined and mpPx > 0 and srcRatio > 0 then (
					tw = (floor ((sqrt (mpPx * srcRatio)) + 0.5)) as integer
					th = (floor ((sqrt (mpPx / srcRatio)) + 0.5)) as integer
				)
			)
			default: ( )
		)
		if tw == undefined or th == undefined or tw <= 0 or th <= 0 do return #(sw, sh)
		-- Swap — без снэпа: перестановка сторон должна быть точной (снэп мог бы
		-- сменить разрешение, напр. 1872x2816 -> 2000x3000)
		if not snapOn or mode == #swap do return #(tw as integer, th as integer)
		-- ФАЗА СНЭПА — единственная во всём скрипте для путей ввода:
		local res = if preserve or mode == #mp then \
			snapResolutionKeepMP tw th (if mode == #mp then intent[#mpPx] else srcPx) \
			else snapResolution tw th
		#(res[1], res[2])
	)
	--) Конец ЕДИНЫЙ РАСЧЁТ РАЗРЕШЕНИЯ
	--------------------------------------------------------------
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

	-- Разобрать имя и хвостовой номер с разделителем: "Cam_2" -> #("Cam", 2),
	-- "Cam 2" -> #("Cam", 2), "Cam" -> #("Cam", 0), "Camera001" -> #("Camera001", 0)
	-- (номер без разделителя считается частью базы и не трогается).
	-- Определены ДО setViewBase: MAXScript однопроходный, вызов функции до
	-- её определения компилируется как неявный глобал и падает в рантайме
	-- ("Type error: Call needs function or class, got: undefined").
	fn parseTrailingNum name = (
		if name == undefined or name == "" then return #("", 0)
		local i = name.count
		while i > 0 and (findstring "0123456789" name[i]) != undefined do i -= 1
		if i == name.count then return #(name, 0)
		if (findstring " _" name[i]) == undefined then return #(name, 0)
		local numStr = subString name (i + 1) (name.count - i)
		local prefix = subString name 1 (i - 1)
		#(prefix, (numStr as integer))
	)

	-- Уникально ли БАЗОВОЕ имя (без суффикса разрешения) среди всех batch views (исключая excludeView)
	fn isBaseNameUnique baseName excludeView = (
		if baseName == undefined or baseName == "" then return false
		for i = 1 to batchRenderMgr.NumViews do (
			local v = batchRenderMgr.GetView i
			if v != undefined and v != excludeView and (getCleanViewName v.name) == baseName then return false
		)
		true
	)

	-- Уникальное имя базы: baseName, baseName_2, baseName_3, ...
	-- Если baseName уже содержит хвостовой номер с разделителем ("Cam_2") —
	-- продолжить с него ("Cam_3"), а не копить суффиксы ("Cam_2_2_2").
	fn getUniqueBaseName baseName excludeView = (
		if baseName == undefined or baseName == "" then return "View"
		local candidate = baseName
		if isBaseNameUnique candidate excludeView then return candidate
		local parsed = parseTrailingNum baseName
		local base = parsed[1]
		local counter = if parsed[2] > 0 then parsed[2] + 1 else 2
		do (
			candidate = base + "_" + (counter as string)
			counter += 1
		) while not (isBaseNameUnique candidate excludeView)
		candidate
	)

	-- Безопасно установить имя виду с проверкой уникальности БАЗОВОГО имени
	fn safeSetViewName the_view newName = (
		if the_view == undefined then return false
		if the_view.name == newName then return true
		local data = parseViewName newName
		local clean = getCleanViewName newName
		local finalName = newName
		if not (isBaseNameUnique clean the_view) then (
			local base = getUniqueBaseName clean the_view
			if data[2] > 0 and data[3] > 0 then finalName = viewNameFor base data[2] data[3] else finalName = base
		)
		the_view.name = finalName
		true
	)

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

	-- Формат пропорций "W:H" (упрощённо через НОД): 1920x1080 -> "16:9"
	fn ratioString w h = (
		if w == undefined or h == undefined or w <= 0 or h <= 0 then return ""
		local a = w as integer
		local b = h as integer
		local x = a
		local y = b
		while y != 0 do (
			local t = y
			y = mod x y
			x = t
		)
		local g = if x <= 0 then 1 else x
		((a / g) as string) + ":" + ((b / g) as string)
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

	-- Построить блоки для перемещения: каждый вид — отдельный блок,
	-- а выделенный заголовок группы — вся группа целиком.
	-- Возвращает #(blocks, blockSel), где blocks[i] = #(origIdx, regionIdx, данные), blockSel = индексы выбранных блоков.
	fn buildMoveBlocks allData selReal = (
		local blocks = #()
		local blockSel = #()
		local flatIdx = 0
		local regionIdx = 0
		for grp in splitIntoGroups allData do (
			regionIdx += 1
			local hasHeader = isGroupName grp[1].name
			local headerFlat = flatIdx + 1
			if hasHeader and findItem selReal headerFlat > 0 then (
				append blocks #(blocks.count + 1, regionIdx, grp)
				append blockSel blocks.count
			) else (
				for k = 1 to grp.count do (
					append blocks #(blocks.count + 1, regionIdx, #(grp[k]))
					local f = flatIdx + k
					if not (hasHeader and k == 1) and findItem selReal f > 0 do append blockSel blocks.count
				)
			)
			flatIdx += grp.count
		)
		#(blocks, blockSel)
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
	--( ХЕЛПЕРЫ ИМЁН BATCH VIEWS
	-- parseTrailingNum / isBaseNameUnique / getUniqueBaseName / safeSetViewName
	-- определены РАНЬШЕ — в разделе "ИМЯ ВИДА И БАЗА РАЗРЕШЕНИЯ" перед setViewBase:
	-- MAXScript однопроходный, вызов функции до её определения компилируется
	-- как неявный глобал и падает в рантайме ("Call needs function or class").

	-- При конфликте копий между собой: "Cam_2" -> "Cam_3", "Cam" -> "Cam_2"
	fn bumpBaseName baseName = (
		local parsed = parseTrailingNum baseName
		if parsed[2] > 0 then parsed[1] + "_" + ((parsed[2] + 1) as string) else baseName + "_2"
	)

	-- Имя для дубликата вида: уникальная база источника + суффикс разрешения
	-- ("Cam (50% of 1920x1280)" -> "Cam_2 (50% of 1920x1280)",
	--  "Cam_2 (50% of 1920x1280)" -> "Cam_3 (50% of 1920x1280)").
	fn duplicateViewName srcName excludeView = (
		if srcName == undefined or srcName == "" then return "View"
		local data = parseViewName srcName
		local suffix = ""
		if data[1].count < srcName.count then suffix = subString srcName (data[1].count + 1) -1
		local base = getUniqueBaseName data[1] excludeView
		base + suffix
	)

	-- Уникальное имя копии ГРУППЫ: " ----- Group 3 -----" -> " ----- Group 4 -----".
	-- Номер извлекается из внутреннего текста заголовка и продолжается с него,
	-- чтобы копии не копили суффиксы ("Group 3 2", "Group 3 3").
	fn duplicateGroupName grName = (
		local clean = stripCollapsePrefix grName
		local inner = clean
		local p1 = findString inner "-----"
		if p1 != undefined do inner = subString inner (p1 + 5) -1
		local p2 = findString inner "-----"
		if p2 != undefined do inner = subString inner 1 (p2 - 1)
		inner = trimLeft (trimRight inner)
		local parsed = parseTrailingNum inner
		local base = parsed[1]
		local counter = if parsed[2] > 0 then parsed[2] + 1 else 2
		local candidate = " ----- " + base + " " + (counter as string) + " -----"
		while not (isGroupNameAvailable candidate) do (
			counter += 1
			candidate = " ----- " + base + " " + (counter as string) + " -----"
		)
		candidate
	)
	--) Конец ХЕЛПЕРЫ ИМЁН BATCH VIEWS
	--------------------------------------------------------------
	
	--------------------------------------------------------------
	--( НАТИВНОЕ ОКНО BATCH RENDER
	-- Закрыть нативное окно Batch Render (Win32 API)
	fn closeBatchWindow = (
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
	fn moveViewIndex from_idx to_idx = (
		closeBatchWindow()
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

	-- Централизованное применение камеры к вьюпорту (используется и свитком камер,
	-- и Batch Views). Не ломаем существующее расположение видов
	-- (например, Top/Front/Left/Camera-Perspective):
	--   1) если эта камера уже стоит в каком-то вьюпорте — используем его;
	--   2) иначе вьюпорт, где уже стоит любая камера — меняем камеру там;
	--   3) иначе перспективный вьюпорт (#view_persp_user) — ставим камеру туда;
	--   4) иначе — текущий активный вьюпорт.
	fn applyCamToViewport cam = (
		if not (isValidNode cam) or not (isKindOf cam camera) then return false
		for i = 1 to viewport.numViews do (
			if (viewport.getCamera index:i) == cam do (
				viewport.activeViewport = i
				return true
			)
		)
		for i = 1 to viewport.numViews do (
			if (viewport.getCamera index:i) != undefined then (
				viewport.activeViewport = i
				if viewport.CanSetToViewport cam do (
					viewport.SetCamera cam
					return true
				)
			)
		)
		for i = 1 to viewport.numViews do (
			if (viewport.getType index:i) == #view_persp_user then (
				viewport.activeViewport = i
				if viewport.CanSetToViewport cam do (
					viewport.SetCamera cam
					return true
				)
			)
		)
		if viewport.CanSetToViewport cam then viewport.SetCamera cam
		true
	)

	-- Загрузить вид в СЦЕНУ: активировать камеру во вьюпорте,
	-- применить разрешение вида и восстановить scene state.
	-- Сцену трогает только эта функция; для UI используется getViewParams.
	fn applyViewToScene the_view = (
		if the_view == undefined then return false
		local cam = the_view.camera
		if isValidNode cam and (isKindOf cam camera) then (
			applyCamToViewport cam
			-- Если в выделении одна камера — следовать за новой активированной
			followSelectionToCam cam
			-- Синхронизировать камеры: выбрать активированную камеру в списке (если она там есть)
			if g_roll_cams != undefined do (
				g_roll_cams.active_cam = cam
				g_roll_cams.changeActive()
				g_roll_cams.syncCameraUI()
			)
		)
		if the_view.overridePreset and the_view.width > 0 then (
			if renderSceneDialog.isOpen() then renderSceneDialog.close()
			renderWidth = the_view.width
			renderHeight = the_view.height
		)
		if the_view.sceneStateName != "" do (
			local ssp = sceneStateMgr.GetParts the_view.sceneStateName
			sceneStateMgr.Restore the_view.sceneStateName ssp
		)
		redrawViews()
	)

	-- Камера стоит в одном из вьюпортов?
	fn isCamInAnyViewport cam = (
		if not (isValidNode cam) or not (isKindOf cam camera) then return false
		local found = false
		for i = 1 to viewport.numViews do (
			if (viewport.getCamera index:i) == cam do ( found = true; exit )
		)
		found
	)

	-- Если камера вида стоит в каком-либо вьюпорте, применить его текущее
	-- (масштабированное) разрешение к сцене немедленно — не дожидаясь повторной
	-- активации вида. Вызывается после ЛЮБОГО изменения разрешения вида.
	-- Если разрешение сцены уже совпадает — ничего не делает (без лишних redraw).
	fn syncSceneResFromView the_view = (
		if the_view == undefined then return false
		if not (isCamInAnyViewport the_view.camera) do return false
		local base = getViewBase the_view
		if base[1] <= 0 or base[2] <= 0 do return false
		local scaled = resFromBase base[1] base[2]
		if scaled[1] == renderWidth and scaled[2] == renderHeight do return true
		if renderSceneDialog.isOpen() then renderSceneDialog.close()
		renderWidth = scaled[1]
		renderHeight = scaled[2]
		redrawViews()
		true
	)

	-- Активирован ли вид в сцене: его камера стоит в каком-либо вьюпорте
	-- И его текущее (масштабированное) разрешение совпадает с разрешением сцены
	-- (renderWidth/renderHeight) — т.е. вид, выделенный в интерфейсе, совпадает
	-- с тем, что сейчас в сцене.
	fn isViewActivated the_view = (
		if the_view == undefined then return false
		if not (isCamInAnyViewport the_view.camera) then return false
		local base = getViewBase the_view
		if base[1] <= 0 or base[2] <= 0 then return false
		local scaled = resFromBase base[1] base[2]
		(scaled[1] == renderWidth and scaled[2] == renderHeight)
	)

	-- Найти активный вид — тот, что загружен в интерфейс:
	-- имя вида определяется текущим значением поля View name.
	fn getActiveView = (
		if g_roll_batch == undefined or not g_roll_batch.open then return undefined
		local uiName = g_roll_batch.txt_view_name.text
		if uiName == "" then return undefined
		for i = 1 to batchRenderMgr.NumViews do (
			local v = batchRenderMgr.GetView i
			if v != undefined and not (isGroupView v) and (stripCollapsePrefix v.name) == uiName do return v
		)
		undefined
	)

	-- Синхронизировать все виды камеры с источником.
	-- srcBase — база источника; srcCur — текущее (масштабированное) разрешение источника.
	-- Зависит от галки "Base size" (chk_edit_base):
	--   ON  — синхронизируется БАЗА (srcBase);
	--   OFF — синхронизируется ТЕКУЩИЙ размер: база пересчитывается делением srcCur на масштаб.
	fn syncViewsForCam cam srcBase srcCur = (
		if cam == undefined or not (isValidNode cam) then return 0
		closeBatchWindow()
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
				-- Камера вида во вьюпорте — новое разрешение сразу в сцену
				syncSceneResFromView bv
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
		closeBatchWindow()
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
		closeBatchWindow()
		local new_view = batchRenderMgr.CreateView cam
		if new_view != undefined then (
			local base = getCamResFromViews cam
			if base[1] <= 0 then base = #(renderWidth, renderHeight)
			if base[1] <= 0 then base = #(1920, 1080)
			new_view.overridePreset = true
			new_view.name = viewNameFor (getUniqueBaseName (getCleanViewName cam.name) new_view) base[1] base[2]
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
		closeBatchWindow()
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
		local rem = maxOps.GetCurRenderElementMgr()
		if folder == undefined then return 0
		local count = 0
		local numElems = rem.NumRenderElements()
		for i = 0 to (numElems - 1) do (
			local fname = filenameFromPath (rem.GetRenderElementFilename i)
			if fname != "" do (
				rem.SetRenderElementFilename i (pathConfig.appendPath folder fname)
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
		setINISetting iniPath "CamManager" "OnlyVisible" (g_only_visible as string)
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
		if state do (
			local keepGlobal = (thisRollout == g_roll_batch)
			local keepBatch  = (thisRollout == g_roll_global)
			for other in #(g_roll_cams, g_roll_batch, g_roll_global, g_roll_states, g_roll_lang) do (
				if other == undefined or other == thisRollout do continue
				if other == g_roll_global and keepGlobal do continue
				if other == g_roll_batch and keepBatch do continue
				other.open = false
			)
		)
		if g_roll_cams != undefined and g_roll_cams.open then g_last_opened_tab = "Cams"
		else if g_roll_batch != undefined and g_roll_batch.open then g_last_opened_tab = "Batch"
		else if g_roll_global != undefined and g_roll_global.open then g_last_opened_tab = "Global"
		else if g_roll_states != undefined and g_roll_states.open then g_last_opened_tab = "States"
		else if g_roll_lang != undefined and g_roll_lang.open then g_last_opened_tab = "Lang"
		updateFloaterHeight()
	)
	--) Конец СЕРВИСНЫЕ ФУНКЦИИ FLOATER
	--------------------------------------------------------------

	--------------------------------------------------------------
	--( ROLLOUT: CAMERAS

	rollout roll_Cams "Cameras" (
		local roll_w = 250
		--------------------------------
		button btn_refresh "🔄️ Refresh" width:100 align:#left offset:[-10, 0] across:2 \
			tooltip:"Update scene cameras list"
		checkbox chk_only_visible "Only Visible" align:#right \
			tooltip:"Show only visible cameras.\nOff — show all cameras in the scene."
		dotNetControl lst_cams "System.Windows.Forms.ListBox" height:265 offset:[-10, 0]
		button btn_cams_info "?" width:20 height:18 align:#right offset:[10,-23] tooltip:"Single click — preview camera parameters and resolution in the UI (scene unchanged).\nDouble click — activate the camera and load its resolution into the scene."
		
		button btn_pick_pathrev_cam "<<" width:60 align:#left across:3 tooltip:"Previous camera" offset:[-10, 0]
		button btn_s "Select" width:80 align:#center tooltip:"Select active camera" offset:[-10, 0]
		button btn_next_cam ">>" width:60 align:#right tooltip:"Next camera" offset:[-10, 0]

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
		-- Контролы блока камер: активны только когда в списке выделена камера.
		-- prev/next дополнительно зависят от положения в списке (см. updateCamControls).
		local cam_controls = #(
			btn_pick_pathrev_cam, btn_s, btn_next_cam,
			btn_create_view, btn_for_all_cams,
			txt_rename_cam,
			spn_fl, spn_fov, chk_fov, chk_dof, spn_f, chk_tilt,
			rd_ex, drp_ev, spn_ev, spn_sh, spn_iso
		)
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

		fn getCamSel = ( lst_cams.SelectedIndex + 1 )
		fn setCamSel idx = (
			local cnt = lst_cams.Items.Count
			if cnt == 0 do return -1
			lst_cams.SelectedIndex = if idx > 0 then (amin idx cnt) - 1 else -1
		)

		fn updateUIForCamera cam = (
			-- Если в списке не выделена камера — контролы остаются отключенными
			if getCamSel() <= 0 do return false
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
		fn getCamProps cam = (
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

		-- Активировать/деактивировать контролы камер в зависимости от того,
		-- выделена ли камера в списке. prev/next — только если есть камера
		-- в этом направлении. updateUIForCamera уточняет доступность
		-- по типу камеры (вызывается после того, как контролы включены).
		fn updateCamControls = (
			local hasSel = getCamSel() > 0
			for c in cam_controls do c.enabled = hasSel
			if hasSel do (
				btn_pick_pathrev_cam.enabled = curr_itm > 1
				btn_next_cam.enabled = curr_itm < list_cam.count
			)
		)
		
		-- Обновить список камер в lst_cams
		fn relistCams = (
			list_cam = getCameraList()
			lst_cams.BeginUpdate()
			lst_cams.Items.Clear()
			for cam in list_cam do lst_cams.Items.Add (getCameraDisplayName cam)
			lst_cams.EndUpdate()
			updateCamControls()
		)

		-- changeActive: определить активную камеру и обновить UI.
		-- НЕ устанавливает selection в lst_cams / drdwn_cam.
		fn changeActive = (
			if active_cam == undefined or not (isvalidnode active_cam) then active_cam = getActiveCamera()
			lbl_rename_warn.visible = false
			updateCamControls()
			if active_cam != undefined then (
				getCamProps active_cam
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

		-- Установить камеру в viewport и вызвать changeActive().
		fn setActiveCam n = (
			if n != undefined then (
				local cam = if (isKindOf n string) then (getNodeByName n) else n
				if isValidNode cam AND (isKindOf cam camera) then (
					applyCamToViewport cam
					active_cam = cam
					-- Если в выделении одна камера — следовать за новой активированной
					followSelectionToCam cam
					changeActive()
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
			relistCams()
			syncCameraUI()
			if g_roll_batch != undefined do g_roll_batch.listViews()
			true
		)

		--------------------------------
		on roll_Cams open do (
			initCamListBox()
			chk_only_visible.checked = g_only_visible
			relistCams()
			changeActive()
			syncCameraUI()
		)

		on roll_Cams close do (
			saveFloaterState()
		)

		on roll_Cams rolledUp state do ( accordion roll_Cams state )

		on btn_refresh pressed do (
			-- Активная камера — по вьюпортам: выделить её в списке
			local vcam = getViewportCam()
			if vcam != undefined do active_cam = vcam
			relistCams()
			changeActive()
			syncCameraUI()
		)

		on chk_only_visible changed state do (
			g_only_visible = state
			relistCams()
			syncCameraUI()
			if g_roll_batch != undefined do g_roll_batch.listViews()
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
			if idx <= 0 do ( updateCamControls(); return false )
			curr_itm = idx
			active_cam = list_cam[idx]
			changeActive()
		)

		on lst_cams MouseDoubleClick sender args do (
			local idx = getCamSel()
			if idx <= 0 do return false
			setActiveCam list_cam[idx]
			if g_roll_batch != undefined do g_roll_batch.selectFirstViewForCamera active_cam
		)

		on btn_cams_info pressed do (
			messageBox (L10N.trMsg "camerasInfo") title:(L10N.trMsg "titleCameras")
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
				messageBox (L10N.trMsg "selectCameraFirst") title:(L10N.trMsg "titleCameras")
				return false
			)
			local bv = createBatchViewForCam active_cam
			if bv != undefined then (
				relistCams()
				if g_roll_batch != undefined then (
					g_roll_batch.listViews()
					g_roll_batch.open = true
					g_roll_batch.selectView bv
				)
			)
		)

		-- CREATE BATCH VIEWS FOR ALL CAMS
		on btn_for_all_cams pressed do (
			local created = createMissingViews()
			relistCams()
			if g_roll_batch != undefined then (
				g_roll_batch.listViews()
				g_roll_batch.open = true
			)
			messageBox (L10N.trMsg "createdBatchViews" args:#(created)) title:(L10N.trMsg "titleCameras")
		)

	)
	--) Конец ROLLOUT: CAMERAS
	--------------------------------------------------------------


	--------------------------------------------------------------
	--( КОНТЕКСТНОЕ МЕНЮ УДАЛЕНИЯ (RCMenu) — уровень макроса
	-- rcmenu (и их обработчики) — члены скоупа макроса, а НЕ rollout'а:
	-- внутри rollout'а rcmenu не допускается (см. Rollout Clauses: только
	-- local | fn | struct | mousetool | item_group | rollout_item | rollout_handler).
	-- Обработчики обращаются к rollout-локалям roll_batch через объект g_roll_batch
	-- (g_roll_batch.delApply, g_roll_batch.delGroupsCtx) — документированный способ
	-- доступа к локальным переменным rollout'а из внешнего кода.
	-- popUpMenu НЕ блокирует выполнение: on <item> picked срабатывает после
	-- возврата из popUpMenu. Пункта «Отмена» нет: отмена = клик вне меню
	-- (тогда ни один picked не сработает; «протухший» контекст обнуляется
	-- при следующем нажатии btn_rem — см. сброс в начале обработчика).
	-- delApply принимает true (удалить группу с содержимым) / false (только заголовок).

	rcmenu rmc_del_group (
		menuItem mi_hdr "" enabled:false
		separator sep_hdr
		menuItem mi_all ""
		menuItem mi_single ""

		on rmc_del_group open do (
			mi_hdr.text = L10N.trMsg "deleteGroupQuery" args:#(g_roll_batch.delGroupsCtx[1][1])
			mi_all.text = L10N.trMsg "delGroupAll"
			mi_single.text = L10N.trMsg "delGroupOnly"
		)
		on mi_all picked do (g_roll_batch.delApply groupWithContent:true)
		on mi_single picked do (g_roll_batch.delApply())
	)

	rcmenu rmc_del_view (
		menuItem vi_hdr "" enabled:false
		separator sep_v
		menuItem vi_ok ""

		on rmc_del_view open do (
			vi_hdr.text = L10N.trMsg "deleteView"
			vi_ok.text = L10N.trMsg "delViewOk"
		)
		on vi_ok picked do (g_roll_batch.delApply())
	)
	--) Конец КОНТЕКСТНОЕ МЕНЮ УДАЛЕНИЯ (RCMenu)
	--------------------------------------------------------------


	--------------------------------------------------------------
	--( ROLLOUT: BATCH

	rollout roll_batch "Batch Views" (
		local roll_w = 250
		--------------------------------
		button btn_open_batch "Batch Views" width:80 height:25 align:#left offset:[-10,0]
		button btn_refresh "🔄️ Refresh" width:125 height:25 align:#left offset:[75,-30] tooltip:"Update the views list"
		button btn_views_info "?" width:20 height:25 align:#right offset:[15,-30] tooltip:"Batch Views list.\n\n— Single click — preview view parameters in the UI (scene unchanged).\n— Repeat click on a selected item — toggle enabled (view) / collapse or expand a group.\n— Double click on a view — apply the view to the scene (camera + resolution + scene state).\n— Ctrl/Shift — multi-select.\n— Buttons on the left: refresh list, add, duplicate, delete, move up/down, enable/disable."
		dotNetControl lst_views "System.Windows.Forms.ListBox" height:265 offset:[-10,0]

		button btn_togleEnabled "☑️" align:#right width:24 height:25 tooltip:"Toggle enabled" offset:[14,-272]
		button btn_togleEnabledAll "✓✓" align:#right width:24 height:25 tooltip:"Toggle enabled ALL" offset:[14,0]
		button btn_up "↑" height:55 align:#right tooltip:"Move view/group up" offset:[14,2]
		button btn_add_sep "—" width:24 align:#right tooltip:"Add group\nGroups can be renamed via View Name field" offset:[14,0]
		button btn_down "↓" height:55 align:#right tooltip:"Move view/group down" offset:[14,0]
		button btn_dup "📋" width:24 height:25 align:#right offset:[14,2] tooltip:"Duplicate view"
		button btn_rem "❌" width:24 height:25 align:#right offset:[14,0]

		button btn_prev_view "<<" width:60 align:#left across:3 tooltip:"Previous view" offset:[-10, 0]
		button btn_select_cam "Select" width:80 align:#center tooltip:"Select active camera" offset:[-10, 0]
		button btn_next_view ">>" width:60 align:#right tooltip:"Next view" offset:[-10, 0]

		checkbutton btn_net_render "🕸️ Net" width:60 height:25 align:#left offset:[-10,0]
		button btn_render "🫖 Render" height:25 width:145 align:#left offset:[55,-30]
		
		--( Edit batch view
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
			checkbox chk_edit_base "Base size" align:#left \
				tooltip:"Off — edits the CURRENT (scaled) size.\nOn — edits the BASE (100%) size.\nActive only when global scale ≠ 100%."
			edittext txt_out_w "Width" type:#integer fieldwidth:50 align:#right across:2
			edittext txt_out_ratio "Ratio" type:#float fieldwidth:40 align:#right
			edittext txt_out_h "Height" type:#integer fieldwidth:50 align:#right across:2
			dropdownlist drdwn_re_presets items:g_presetNames width:75 align:#right offset:[0,-5]
			checkButton chk_ratio "🔗" height:36 width:18 align:#left offset:[roll_w / 2 - 16, -42] 
			button btn_swap "↕" height:36 width:18 align:#left offset:[-4, -42] \
				tooltip:"Swap width and height values\nand invert the aspect ratio"
			edittext txt_out_mp "MegaPix" type:#float fieldwidth:50 align:#right across:2\
				tooltip:"Total megapixels of the shown Width x Height.\nEnter a value — Width and Height are recalculated\nfor the current aspect ratio.\nDisabled while 'Preserve MegaPix' is checked."
			checkbox chk_preserve_mp "Preserve MegaPix" align:#left offset:[3,0] \
				tooltip:"When changing aspect ratio, keep total megapixels\nconstant by recalculating both dimensions.\nEntering one side (W or H): the other side keeps\nthe view's total pixels (rounded).\nSnaps to nearest standard resolution."
			checkbox chk_snap "Use snap 16(8)px" checked:true align:#left across:2 \
				tooltip:"Snap resolution to standard values.\n1. Standard resolution list (big MP tolerance, aspect protected).\n2. Grid multiples (W:32, H:16) + standard aspect.\nOff — values are used as-is."
			checkbox chk_sync_views "Sync by Camera" align:#left offset:[3,0] \
				tooltip:"On — update all batch views using this camera.\n'Base size' ON  — syncs the BASE size.\n'Base size' OFF — syncs the CURRENT (scaled) size."
			button btn_copy_res "Copy active view res to all views" width:(roll_w - 35) height:25 offset:[0,6] \
				tooltip:"Copy the current view's resolution to ALL batch views.\n\n'Preserve MegaPix' OFF — copies WxH as-is,\nswapping for portrait/landscape views.\n'Preserve MegaPix' ON — keeps total megapixels,\nrecalculating both dimensions for each view's proportions."
		)
			
			spinner spn_start_frame "Start" type:#integer range:[0,99999,0] fieldWidth:60 across:2 align:#left offset:[0,10]
			spinner spn_end_frame "End" type:#integer range:[0,99999,100] fieldWidth:60 align:#left offset:[0,10]

			-- Невидимый таймер: задержка применения вида по «второму клику»,
			-- чтобы отличить его от двойного клика (двойной клик — вкл/выкл).
			timer tmr_apply "applyTimer" interval:300 active:false

		--) End Edit batch view


		--------------------------------
		-- В мульти-режиме: можно ли редактировать разрешение/кадры
		-- (override общий ВКЛ или отличается между видами — редактирование разрешено)
		local g_multi_ovr_editable = false
		-- Клики: первый клик — выделение, повторный клик по уже выделенному → загрузка в сцену.
		-- prev_sel — выделение на момент прошлого клика
		local prev_sel = 0
		-- Снапшот выделения на MouseDown (до применения клика). Owner-draw список
		-- не перерисовывает строки сам — обычный клик после Ctrl-мультивыделения
		-- снимает выделение с прочих строк молча; без снапшота их подсветка
		-- «залипает» визуально. По снапшоту MouseUp инвалидирует потерявшие
		-- выделение строки.
		local g_selSnapshot = #()
		-- Флаг: следующий MouseUp — хвост двойного клика (Windows шлёт MouseUp на каждый клик,
		-- а MouseDoubleClick срабатывает между ними). По нему второй клик не делает второе действие.
		local g_dblPending = false
		-- Отложенное применение вида (realIdx) через tmr_apply: повторный клик = «применить в сцену»,
		-- но если до тика придёт MouseDoubleClick — применение отменяется (двойной клик = вкл/выкл).
		local g_pending_apply = 0
		--------------------------------

		-- ПОРЯДОК СОБЫТИЙ WINFORMS (проверено тестовым скриптом, флоатер с ListBox, 3ds Max 2026):
		--   Одинарный клик:  MouseDown → Click → SelectedIndexChanged → MouseUp
		--   Двойной клик:     1-й клик: MouseDown → Click → SelectedIndexChanged → MouseUp
		--                     2-й клик: MouseDown → DoubleClick → MouseDoubleClick → MouseUp
		-- Итого РОВНО два MouseUp, Click на втором клике НЕ приходит — его заменяет DoubleClick.
		-- Следствие: «чистого» разделения одинарного/двойного клика в MouseUp не существует —
		-- первый клик двойного нажатия НЕ отличить от одиночного. Поэтому:
		--   * «второй клик» по выделенному элементу (вид — загрузка в сцену, группа — свернуть/развернуть)
		--     откладывается через tmr_apply;
		--   * если до тика пришёл MouseDoubleClick — отложенное действие отменяется, вместо него
		--     вид — вкл/выкл, группа — свернуть/развернуть;
		--   * второй (хвостовой) MouseUp гасится флагом g_dblPending, иначе было бы лишнее действие.

		-- Маппинг UI-индекс → реальный индекс batch view строится в listViews

		-- Включить двойную буферизацию dotNet-контрола (свойство DoubleBuffered
		-- защищённое — доступ через рефлексию). Owner-draw ListBox без неё мигает
		-- при каждой перерисовке (выделение, Invalidate).
		fn enableDoubleBuffered ctrl = (
			try (
				-- BindingFlags: Instance | NonPublic (свойство DoubleBuffered защищённое)
				local bf = bitor (dotNetClass "System.Reflection.BindingFlags").Instance (dotNetClass "System.Reflection.BindingFlags").NonPublic
				local prop = (dotNetClass "System.Windows.Forms.Control").GetProperty "DoubleBuffered" bf
				if prop != undefined do prop.SetValue ctrl true
			) catch ()
		)

		-- Инициализация dotNet ListBox
		fn initListBox = (
			lst_views.BeginUpdate()
			lst_views.Items.Clear()
			lst_views.SelectionMode = (dotNetClass "System.Windows.Forms.SelectionMode").MultiExtended
			lst_views.IntegralHeight = false
			lst_views.DrawMode = (dotNetClass "System.Windows.Forms.DrawMode").OwnerDrawFixed
			lst_views.BackColor = (dotNetClass "System.Drawing.Color").FromARGB 40 40 43
			lst_views.ForeColor = (dotNetClass "System.Drawing.Color").White
			lst_views.EndUpdate()
			enableDoubleBuffered lst_views
			lst_views.Invalidate()
		)

		fn getSel = (
			local i = lst_views.SelectedIndex
			if i >= 0 then i + 1 else 0
		)

		fn setSel idx = (
			local cnt = lst_views.Items.Count
			if cnt == 0 do return false
			lst_views.SelectedIndex = if idx > 0 then (amin idx cnt) - 1 else -1
		)

		-- Преобразовать UI-индекс lst_views в реальный индекс batchRenderMgr
		fn getRealIndex uiIdx = (
			if uiIdx > 0 and uiIdx <= g_visibleIndices.count then g_visibleIndices[uiIdx] else 0
		)

		-- Включить/выключить вид по UI-индексу (группы не трогаем)
		fn setViewCheckedAtUi uiIdx state = (
			local realIdx = getRealIndex uiIdx
			if realIdx <= 0 do return false
			local the_view = batchRenderMgr.GetView realIdx
			if the_view == undefined or isGroupView the_view do return false
			the_view.enabled = state
			lst_views.Invalidate()
			true
		)

		-- Все выделенные UI-индексы (1-based)
		fn getSelectedUiIndices = (
			local res = #()
			local n = lst_views.Items.Count
			for i = 1 to n do (
				if lst_views.GetSelected (i - 1) do append res i
			)
			res
		)

		-- Все выделенные реальные индексы batch views
		fn getSelectedRealIdxs = (
			local res = #()
			for ui in getSelectedUiIndices() do (
				local r = getRealIndex ui
				if r > 0 and findItem res r == 0 do append res r
			)
			res
		)

		-- Реальные индексы выделенных ВИДОВ (группы-заголовки исключаются) —
		-- цели массового редактирования.
		fn getMultiEditIdxs = (
			local res = #()
			for ui in getSelectedUiIndices() do (
				local r = getRealIndex ui
				if r > 0 then (
					local v = batchRenderMgr.GetView r
					if v != undefined and not (isGroupView v) and findItem res r == 0 do append res r
				)
			)
			res
		)

		-- Активен ли режим массового редактирования (выделено 2+ видов)
		fn isMultiEdit = (
			(getMultiEditIdxs()).count >= 2
		)

		-- Выделить ровно эти UI-индексы
		fn setSelectedUiIndices uiIdxes = (
			local n = lst_views.Items.Count
			for i = 0 to n - 1 do lst_views.SetSelected i false
			for ui in uiIdxes do (
				if ui >= 1 and ui <= n do lst_views.SetSelected (ui - 1) true
			)
			lst_views.Invalidate()
		)


		-- Заполнить drdwn_cam выпадающий список камер.
		-- ВСЕГДА все камеры сцены, независимо от галки "Only Visible".
		fn listCamerasForBatch = (
			local cams = for cam in cameras where (isKindOf cam camera) collect cam
			qsort cams compareCamNames
			local cam_names = for cam in cams collect (getCameraDisplayName cam)
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
			if drdwnIdx != 0 and drdwn_cam.selection != drdwnIdx do drdwn_cam.selection = drdwnIdx
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
			drdwn_re_presets.selection = idx
			chk_ratio.checked = (idx > 1)
			idx
		)

		-- МегаПикс показанных WxH -> поле txt_out_mp ("*" / пусто при нечисловых
		-- значениях). Вызывается из showResForBase и после ручных правок полей.
		fn updateMpixField = (
			local w = try (txt_out_w.text as integer) catch undefined
			local h = try (txt_out_h.text as integer) catch undefined
			if w != undefined and h != undefined and w > 0 and h > 0 then (
				-- округление до 2 знаков вручную: formattedPrint("%.2f") в некоторых
				-- сборках MAXScript возвращает строку формата как есть
				local mp = ((w as float) * h) / 1000000.0
				txt_out_mp.text = ((floor (mp * 100.0 + 0.5)) / 100.0) as string
			) 			else
				txt_out_mp.text = ""
		)

		-- Текущее состояние АКТИВНОГО вида в ПРОСТРАНСТВЕ ПОЛЕЙ (база при
		-- Base size и масштабе ≠ 100%, иначе масштабированный размер).
		-- Источник "старых" значений для resolveRes: поля уже содержат ввод.
		fn getFieldSpaceSrc = (
			local bb = try (getViewBase (getActiveView())) catch undefined
			if bb == undefined or bb[1] <= 0 or bb[2] <= 0 do return undefined
			local scale = if g_globalScale == undefined then 1.0 else g_globalScale
			if chk_edit_base.checked and abs(scale - 1.0) > 0.001 then bb else resFromBase bb[1] bb[2]
		)

		-- Показать в полях Render output базовое или текущее разрешение
		-- (зависит от галки chk_edit_base и глобального масштаба)
		fn showResForBase baseW baseH = (
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
			syncPresetFromRatio (txt_out_ratio.text as float)
			updateMpixField()
		)

		-- Контролы блока "Edit batch view": все, кроме управляющих списком.
		-- Без активированного вида (загруженного в интерфейс) блок недоступен.
		local edit_batch_view_controls = #(
			txt_view_name,
			btn_open_in_explorer, txt_view_path, txt_view_file, btn_pick_path,
			drdwn_cam, btn_use_active_cam,
			drdwn_state, drdwn_render_preset,
			chk_override_preset, chk_edit_base,
			txt_out_w, txt_out_ratio, txt_out_h, txt_out_mp,
			drdwn_re_presets, chk_ratio, btn_swap,
			chk_snap, chk_preserve_mp, chk_sync_views,
			btn_copy_res,
			spn_start_frame, spn_end_frame
		)

		-- Контролы, применимые К НЕСКОЛЬКИМ видам сразу (активны в мульти-режиме).
		-- В мульти-режиме показывают общее значение, если оно совпадает у всех
		-- выделенных видов, иначе маркер "*". Изменение применяется ко всем.
		--
		-- ПРАВИЛО добавления нового контрола в мульти-список:
		--   1) мульти-ветка в его обработчике (if isMultiEdit() then ... return false);
		--   2) отображение общего значения (или "*") в updateMultiUI.
		local batch_multi_controls = #(
								-- СТАТУС мульти-поддержки (ветка `if isMultiEdit() then` в обработчике):
			txt_view_path,		-- setMultiPath()          (on txt_view_path entered)
			btn_pick_path,		-- setMultiPathFromPicked  (on btn_pick_path pressed)
			drdwn_cam,			-- ветка в on drdwn_cam selected + общая камера в updateMultiUI
			btn_use_active_cam,	-- мульти-ветка в on btn_use_active_cam pressed (активная камера всем)
			drdwn_state,		-- on drdwn_state selected
			drdwn_render_preset,-- on drdwn_render_preset selected
			chk_override_preset,-- on chk_override_preset changed
			chk_edit_base,		-- мульти: пересчёт общей базы (on chk_edit_base changed)
			txt_out_w,			-- общие базы: applyFieldRes -> applyViewRes (все виды);
			txt_out_h,			--		разные базы (второе поле "*"): если LOCK (chk_ratio)
								--		ВКЛ — применяем сразу (applyMultiFieldRes #w/#h, вторая
								--		сторона под пропорции каждого вида, молча); если LOCK
								--		ВЫКЛ — ждём ввод второго значения, затем общие W/H
								--		применяются через applyFieldRes -> applyViewRes.
			txt_out_ratio,		-- общие базы: applyRatio -> applyViewRes; разные базы:
								--		applyMultiFieldRes #ratio — как btn_copy_res: предупреждение
								--		при смене пропорций, иначе молча.
			txt_out_mp,			-- общие базы: пересчёт W/H под текущие пропорции через
								--		applyFieldRes; разные базы: applyMultiFieldRes #mp —
								--		каждому виду своё под ЕГО пропорции (как btn_copy_res).
			drdwn_re_presets,	-- общие базы: через applyRatio; разные базы: applyMultiFieldRes #ratio
			chk_ratio,			-- TOGGLE-режим (LOCK), к видам не применяется; updateRatioUI мульти-aware
			btn_swap,			-- общие базы: через applyViewRes; разные базы: applyMultiFieldRes #swap
			chk_snap,			-- глобальный g_snap + applyFieldRes (on chk_snap changed)
			chk_preserve_mp,	-- TOGGLE-режим пересчёта, читается в applyRatio / applyMultiFieldRes / updateCopyResBtn
			chk_sync_views,		-- on chk_sync_views changed
			spn_start_frame,	-- on spn_start_frame
			spn_end_frame		-- spn_end_frame changed
		)

		-- Контролы ТОЛЬКО одиночного вида (деактивируются в мульти-режиме).
		--
		-- Если контрол переносится между списками (или добавляется новый) — кроме самого
		-- переноса обязательны: мульти-ветка в его обработчике, отображение общего значения
		-- в updateMultiUI и suppression-флаг при программном заполнении (см. ПРАВИЛО в
		-- комментарии batch_multi_controls). Пример реализации — btn_use_active_cam (в мульти-списке).
		local batch_single_controls = #(
			txt_view_name,			-- у каждого вида своё имя, общего значения нет
			txt_view_file,			-- имя файла у каждого вида своё (массово меняется только папка через txt_view_path / btn_pick_path)
			btn_open_in_explorer,	-- открывает папку одного вида
			btn_copy_res			-- источник — АКТИВНЫЙ вид, загруженный в интерфейс; в мульти-режиме активного вида нет (g_active_view = undefined).
		)

		-- Активность Ratio и чек-бокса Preserve MegaPix (всегда доступен при Override)
		fn updateRatioUI = (
			if isMultiEdit() then (
				local isFree = (drdwn_re_presets.selection <= 1)
				chk_preserve_mp.enabled = g_multi_ovr_editable
				txt_out_ratio.enabled = g_multi_ovr_editable and isFree
				chk_ratio.enabled = g_multi_ovr_editable
				txt_out_mp.enabled = g_multi_ovr_editable and not chk_preserve_mp.checked
				return false
			)
			local hasActive = (getActiveView() != undefined)
			local ovr = chk_override_preset.checked
			local isFree = (drdwn_re_presets.selection <= 1)
			chk_preserve_mp.enabled = hasActive and ovr
			txt_out_ratio.enabled = hasActive and ovr and isFree
			chk_ratio.enabled = hasActive and ovr
			txt_out_mp.enabled = hasActive and ovr and not chk_preserve_mp.checked
		)

		-- Текст кнопки копирования отражает режим Preserve MegaPix:
		-- ON — мегапиксели сохраняются (пересчёт под пропорции каждого вида),
		-- OFF — копируется как есть (WxH источника).
		fn updateCopyResBtn = (
			local key = if chk_preserve_mp.checked then "roll_batch.btn_copy_res_mp" else "roll_batch.btn_copy_res"
			btn_copy_res.text = L10N.trMsg key
		)

		-- Обновить UI для множественного выделения (2+ видов):
		-- значение показывается только если оно совпадает у всех выделенных видов,
		-- иначе ставится маркер "*" / пустой пункт. Правки применяются ко всем.
		fn updateMultiUI = (
			local idxs = getMultiEditIdxs()
			if idxs.count < 2 do return false

			for c in batch_multi_controls do c.enabled = true
			for c in batch_single_controls do c.enabled = false

			txt_view_name.text = ""
			txt_view_file.text = ""

			-- Путь: общая папка вывода
			local commonPath = undefined
			for r in idxs do (
				local v = batchRenderMgr.GetView r
				local p = if v.outputFilename != undefined and v.outputFilename != "" then getFilenamePath v.outputFilename else ""
				if commonPath == undefined then commonPath = p
				else if commonPath != p do ( commonPath = undefined; exit )
			)
			txt_view_path.text = if commonPath != undefined then commonPath else "*"

			-- Camera: общая камера (совпадает у всех выделенных видов).
			local commonCam = undefined
			for r in idxs do (
				local c = (batchRenderMgr.GetView r).camera
				if commonCam == undefined then commonCam = c
				else if commonCam != c do ( commonCam = undefined; exit )
			)
			if commonCam != undefined and isValidNode commonCam then (
				local ci = findCameraInDropdown commonCam.name
				drdwn_cam.selection = if ci == 0 then 1 else ci
			) else drdwn_cam.selection = 1

			-- Scene State
			local commonState = undefined
			for r in idxs do (
				local s = (batchRenderMgr.GetView r).sceneStateName
				if commonState == undefined then commonState = s
				else if commonState != s do ( commonState = undefined; exit )
			)
			if commonState != undefined then (
				local si = findItem drdwn_state.items commonState
				drdwn_state.selection = if si == 0 then 1 else si
			) else drdwn_state.selection = 1

			-- Render Preset
			local commonPreset = undefined
			for r in idxs do (
				local v = batchRenderMgr.GetView r
				local p = if v.presetFile != undefined and v.presetFile != "" then getFilenameFile v.presetFile else ""
				if commonPreset == undefined then commonPreset = p
				else if commonPreset != p do ( commonPreset = undefined; exit )
			)
			if commonPreset != undefined then (
				local pi = findItem drdwn_render_preset.items commonPreset
				drdwn_render_preset.selection = if pi == 0 then 1 else pi
			) else drdwn_render_preset.selection = 1

			-- Override Preset: галка — только если включён у всех;
			-- редактирование разрешения разрешено при общем ВКЛ или смешанном состоянии.
			local ovr = undefined
			for r in idxs do (
				local o = (batchRenderMgr.GetView r).overridePreset
				if ovr == undefined then ovr = o
				else if ovr != o do ( ovr = undefined; exit )
			)
			g_multi_ovr_editable = (ovr == undefined or ovr)
			chk_override_preset.checked = (ovr == true)

			-- Кадры
			local commonStart = undefined
			local commonEnd = undefined
			for r in idxs do (
				local v = batchRenderMgr.GetView r
				if commonStart == undefined then commonStart = v.startFrame
				else if commonStart != v.startFrame do commonStart = undefined
				if commonEnd == undefined then commonEnd = v.endFrame
				else if commonEnd != v.endFrame do commonEnd = undefined
			)
			spn_start_frame.value = if commonStart != undefined then commonStart as integer else 0
			spn_end_frame.value = if commonEnd != undefined then commonEnd as integer else 0

			-- Разрешение: общая база
			local commonBase = undefined
			for r in idxs do (
				local b = getViewBase (batchRenderMgr.GetView r)
				if commonBase == undefined then commonBase = b
				else if commonBase[1] != b[1] or commonBase[2] != b[2] do ( commonBase = undefined; exit )
			)
			if commonBase != undefined and commonBase[1] > 0 and commonBase[2] > 0 then
				showResForBase commonBase[1] commonBase[2]
			else (
				txt_out_w.text = "*"
				txt_out_h.text = "*"
				txt_out_ratio.text = "*"
				txt_out_mp.text = "*"
			)

			-- Sync by camera: по уникальным камерам выделенных видов
			local sync = undefined
			local cams = #()
			for r in idxs do (
				local bv = batchRenderMgr.GetView r
				if bv != undefined and isValidNode bv.camera and findItem cams bv.camera == 0 do append cams bv.camera
			)
			for cam in cams do (
				local s = getCamSync cam
				if sync == undefined then sync = s
				else if sync != s do ( sync = undefined; exit )
			)
			chk_sync_views.checked = if sync == undefined then false else sync

			-- Включение зависимых от Override контролов (btn_copy_res — одиночный,
			-- уже погашен списком batch_single_controls)
			txt_out_w.enabled = g_multi_ovr_editable
			txt_out_h.enabled = g_multi_ovr_editable
			txt_out_mp.enabled = g_multi_ovr_editable
			btn_swap.enabled = g_multi_ovr_editable
			drdwn_re_presets.enabled = g_multi_ovr_editable
			spn_start_frame.enabled = g_multi_ovr_editable
			spn_end_frame.enabled = g_multi_ovr_editable
			chk_snap.enabled = g_multi_ovr_editable
			chk_sync_views.enabled = g_multi_ovr_editable
			chk_edit_base.enabled = g_multi_ovr_editable and abs(g_globalScale - 1.0) > 0.001
			updateRatioUI()
			true
		)

		-- Активность контролов размера/кадров в зависимости от Override Preset.
		-- Без активированного вида (загруженного в интерфейс) редактировать
		-- нечего — весь блок "Edit batch view" отключен. При Override ВЫКЛ гаснет
		-- ВЕСЬ блок group "Resolution" (кроме самой галки) + кадры.
		fn updateOverrideUI = (
			if isMultiEdit() then (
				updateMultiUI()
				return false
			)
			local hasActive = (getActiveView() != undefined)
			for c in edit_batch_view_controls do c.enabled = hasActive
			if not hasActive do return false
			local ovr = chk_override_preset.checked
			local canEditBase = ovr and abs(g_globalScale - 1.0) > 0.001
			chk_edit_base.enabled = canEditBase
			txt_out_w.enabled = ovr
			txt_out_h.enabled = ovr
			txt_out_mp.enabled = ovr
			btn_swap.enabled = ovr
			drdwn_re_presets.enabled = ovr
			spn_start_frame.enabled = ovr
			spn_end_frame.enabled = ovr
			chk_snap.enabled = ovr
			chk_sync_views.enabled = ovr
			btn_copy_res.enabled = ovr
			updateRatioUI()
		)

		-- Загрузить параметры batch view в UI
		fn getViewParams index = (
			local the_view = try (batchRenderMgr.GetView index) catch undefined
			if the_view == undefined then return undefined

			disableSceneRedraw()
			txt_view_name.text = stripCollapsePrefix the_view.name

			local cam = the_view.camera
			if isValidNode cam then (
				local drdwnIdx = findCameraInDropdown cam.name
				drdwn_cam.selection = if drdwnIdx == 0 then 1 else drdwnIdx
			) else drdwn_cam.selection = 1

			if the_view.outputFilename != "" then (
				txt_view_path.text = getFilenamePath the_view.outputFilename
				txt_view_file.text = filenameFromPath the_view.outputFilename
			) else (
				txt_view_path.text = ""
				txt_view_file.text = ""
			)

			local idx = finditem drdwn_state.items the_view.sceneStateName
			drdwn_state.selection = if idx == 0 then 1 else idx

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

			enableSceneRedraw()
			the_view
		)

		-- Позиция блока с тегом origIdx в массиве blocks
		fn blockPos blocks origIdx = (
			for i = 1 to blocks.count do ( if blocks[i][1] == origIdx do return i )
			0
		)

		-- Является ли блок одиночным видом (не группой и не целым регионом)
		fn isSingleViewBlock b = (
			(b[3].count == 1) and not (isGroupName b[3][1].name)
		)

		-- Можно ли сдвинуть выделенное в направлении direction (#up/#down).
		-- Вид двигается свободно (может перейти в соседнюю группу, перешагнув заголовок);
		-- выделенный заголовок двигает всю группу.
		fn canMoveSelectedAny direction = (
			local allData = collectAllViewData()
			local selReal = getSelectedRealIdxs()
			if selReal.count == 0 do return false
			local mb = buildMoveBlocks allData selReal
			local blocks = mb[1]
			local blockSel = mb[2]
			local n = blocks.count
			for bi in blockSel do (
				local pos = blockPos blocks bi
				if direction == #up then (
					if isSingleViewBlock blocks[pos] then (
						if pos > 1 and findItem blockSel blocks[pos - 1][1] == 0 do return true
					) else (
						if pos > 1 do return true
					)
				) else (
					if isSingleViewBlock blocks[pos] then (
						if pos < n and findItem blockSel blocks[pos + 1][1] == 0 do return true
					) else (
						if pos < n do return true
					)
				)
			)
			false
		)

		-- Переместить все выделенные блоки (виды/группы) на один шаг в направлении direction.
		-- Вид меняется местами с соседним элементом (в т.ч. с заголовком другой группы — так он переходит в неё);
		-- выделенный заголовок двигает всю группу, меняясь с соседней группой целиком.
		-- Возвращает новые реальные индексы первых элементов выбранных блоков.
		fn moveSelectedViews direction = (
			local allData = collectAllViewData()
			local selReal = getSelectedRealIdxs()
			if selReal.count == 0 do return #()
			local mb = buildMoveBlocks allData selReal
			local blocks = mb[1]
			local blockSel = mb[2]
			if blockSel.count == 0 do return #()
			local n = blocks.count

			if direction == #up then (
				blockSel = sort blockSel
				for bi in blockSel do (
					local p = blockPos blocks bi
					if p > 1 then (
						if isSingleViewBlock blocks[p] then (
							if findItem blockSel blocks[p - 1][1] == 0 then (
								local t = blocks[p]
								blocks[p] = blocks[p - 1]
								blocks[p - 1] = t
							)
						) else (
							local rid = blocks[p - 1][2]
							local s = p - 1
							while s > 1 and blocks[s - 1][2] == rid do s -= 1
							local b = blocks[p]
							deleteItem blocks p
							-- insertItem <value> <array> <index> (именно так: значение первым!)
							insertItem b blocks s
						)
					)
				)
			) else (
				local rev = for i = blockSel.count to 1 by -1 collect blockSel[i]
				for bi in rev do (
					local p = blockPos blocks bi
					if p < n then (
						if isSingleViewBlock blocks[p] then (
							if findItem blockSel blocks[p + 1][1] == 0 then (
								local t = blocks[p]
								blocks[p] = blocks[p + 1]
								blocks[p + 1] = t
							)
						) else (
							local rid = blocks[p + 1][2]
							local e = p + 1
							while e < n and blocks[e + 1][2] == rid do e += 1
							local b = blocks[p]
							deleteItem blocks p
							if e > blocks.count then append blocks b else insertItem b blocks e
						)
					)
				)
			)

			local newReal = #()
			local flatIdx = 0
			for bi = 1 to blocks.count do (
				if findItem blockSel blocks[bi][1] > 0 do append newReal (flatIdx + 1)
				flatIdx += blocks[bi][3].count
			)

			closeBatchWindow()
			local newGroups = for w in blocks collect w[3]
			rebuildFromGroups newGroups
			newReal
		)

		-- Найти ближайший UI-индекс вида (НЕ группы) в направлении dir (-1/1) от startIdx.
		-- 0 — если в этом направлении видов больше нет.
		fn findViewUiIndex startIdx dir = (
			local n = g_visibleIndices.count
			local i = startIdx + dir
			while i >= 1 and i <= n do (
				local r = getRealIndex i
				local v = if r > 0 then batchRenderMgr.GetView r else undefined
				if v != undefined and not (isGroupView v) do return i
				i += dir
			)
			0
		)

		-- Обновить состояние кнопок в зависимости от выделения в lst_views
		fn updateViewsListButtons = (
			local selUis = getSelectedUiIndices()
			if selUis.count == 0 then (
				btn_up.enabled = false
				btn_down.enabled = false
				btn_togleEnabled.enabled = false
				btn_rem.enabled = false
			) else (
				btn_togleEnabled.enabled = true
				btn_togleEnabled.tooltip = "Toggle enabled (selected views + group contents)"
				btn_up.enabled = canMoveSelectedAny #up
				btn_down.enabled = canMoveSelectedAny #down
				btn_rem.enabled = true
			)

			-- prev/next/select_cam: неактивны при пустом списке,
			-- prev/next — только если есть вид в этом направлении.
			local hasViews = g_visibleIndices.count > 0
			btn_select_cam.enabled = hasViews
			local cur = getSel()
			if cur == 0 do cur = g_visibleIndices.count + 1
			btn_prev_view.enabled = (findViewUiIndex cur -1) > 0
			btn_next_view.enabled = (findViewUiIndex cur 1) > 0
			-- Разрешение можно редактировать/копировать только при активированном виде
			updateOverrideUI()
		)

		-- Перелистывание видов: выбрать вид по UI-индексу (клампится к границам)
		fn selectViewByUiIndex uiIdx = (
			if g_visibleIndices.count == 0 do return false
			if uiIdx < 1 then uiIdx = 1
			if uiIdx > g_visibleIndices.count then uiIdx = g_visibleIndices.count
			-- MultiExtended: SelectedIndex не снимает остальные выделения — чистим явно
			lst_views.ClearSelected()
			setSel uiIdx
			lst_views.Invalidate()
			local realIdx = getRealIndex uiIdx
			if realIdx > 0 then (
				local the_view = batchRenderMgr.GetView realIdx
				if isGroupView the_view then (
					txt_view_name.text = stripCollapsePrefix the_view.name
				) else (
					applyViewToScene the_view
					g_active_view = getViewParams realIdx
				)
				updateViewsListButtons()
			)
			true
		)

		-- Выбрать первый вид камеры в списке
		fn selectFirstViewForCamera cam = (
			if cam == undefined do return false
			for i = 1 to batchRenderMgr.NumViews do (
				local bv = batchRenderMgr.GetView i
				if bv != undefined and bv.camera == cam then (
					local uiIdx = findItem g_visibleIndices i
					if uiIdx != 0 then (
						lst_views.ClearSelected()
						setSel uiIdx
					)
					g_active_view = getViewParams i
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
					if uiIdx != 0 then (
						-- MultiExtended: SelectedIndex не снимает остальные выделения — чистим явно
						lst_views.ClearSelected()
						setSel uiIdx
					)
					g_active_view = getViewParams i
					updateViewsListButtons()
					return true
				)
			)
			if theName != undefined then (
				for i = 1 to batchRenderMgr.NumViews do (
					local v = batchRenderMgr.GetView i
					if v != undefined and v.name == theName then (
						local uiIdx = findItem g_visibleIndices i
						if uiIdx != 0 then (
							lst_views.ClearSelected()
							setSel uiIdx
						)
						g_active_view = getViewParams i
						updateViewsListButtons()
						return true
					)
				)
			)
			false
		)

		-- Обновить txt_view_path (путь) и txt_view_file (имя файла) из g_view_path
		fn updatePath = (
			if g_view_path != undefined then (
				txt_view_path.text = getFilenamePath g_view_path
				txt_view_file.text = filenameFromPath g_view_path
			) else (
				txt_view_path.text = ""
				txt_view_file.text = ""
			)
		)

		-- Массовое применение пути (txt_view_path) ко всем выделенным видам.
		-- У каждого вида сохраняется его собственное имя файла.
		fn setMultiPath = (
			local idxs = getMultiEditIdxs()
			if idxs.count < 2 do return false
			local p = txt_view_path.text
			if p == "*" do return false
			closeBatchWindow()
			if p == "" then (
				for r in idxs do (batchRenderMgr.GetView r).outputFilename = undefined
			) else (
				for r in idxs do (
					local v = batchRenderMgr.GetView r
					local fn_ = if v.outputFilename != undefined and v.outputFilename != "" then filenameFromPath v.outputFilename else ""
					v.outputFilename = if fn_ != "" then p + fn_ else p
				)
			)
			updateOverrideUI()
			true
		)

		-- Массовое применение папки из диалога сохранения: у каждого вида сохраняется
		-- его собственное имя файла, меняется только папка.
		fn setMultiPathFromPicked fullPath = (
			local idxs = getMultiEditIdxs()
			if idxs.count < 2 do return false
			local folder = getFilenamePath fullPath
			local defaultFn = filenameFromPath fullPath
			closeBatchWindow()
			for r in idxs do (
				local v = batchRenderMgr.GetView r
				local ownFn = if v.outputFilename != undefined and v.outputFilename != "" then filenameFromPath v.outputFilename else ""
				local fn_ = if ownFn != "" then ownFn else defaultFn
				v.outputFilename = if fn_ != "" then folder + fn_ else undefined
			)
			updateOverrideUI()
			true
		)

		-- Обновить lst_views, drdwn_state, drdwn_cam.
		-- Строит g_visibleIndices — маппинг UI-индекс → реальный индекс batch view
		fn listViews restoreName:"" = (
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
						append col the_view.name
						append g_visibleIndices i
					)
				)
			)

			lst_views.BeginUpdate()
			lst_views.Items.Clear()
			for item in col do lst_views.Items.Add item
			lst_views.EndUpdate()
			lst_views.Invalidate()
			updateViewsListButtons()

			listCamerasForBatch()

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

		-- Перестроить список и восстановить выделение по реальным индексам
		fn restoreSelectionByReal realIdxs = (
			g_roll_batch.listViews()
			local selUis = #()
			for r in realIdxs do (
				local ui = findItem g_visibleIndices r
				if ui > 0 and findItem selUis ui == 0 do append selUis ui
			)
			if selUis.count > 0 do setSelectedUiIndices selUis
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

		-- Применить W/H ко ВСЕМ выделенным видам (мульти-режим) или к текущему виду.
		fn applyViewRes w h = (
			if w == undefined or h == undefined or w <= 0 or h <= 0 do return false
			local idxs = getMultiEditIdxs()
			if idxs.count == 0 then (
				-- Одиночный режим: целевой вид — текущий в списке
				if getSel() == 0 do return false
				local r0 = getRealIndex (getSel())
				if r0 <= 0 do return false
				local v0 = batchRenderMgr.GetView r0
				if v0 == undefined or isGroupView v0 do return false
				idxs = #(r0)
			) else (
				for r in idxs do (
					local v = batchRenderMgr.GetView r
					if v == undefined or isGroupView v do return false
				)
			)
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
			local singleMode = idxs.count == 1
			closeBatchWindow()
			for r in idxs do (
				local bv = batchRenderMgr.GetView r
				setViewBase bv baseW baseH
				if chk_sync_views.checked and isValidNode bv.camera do syncViewsForCam bv.camera #(baseW, baseH) #(w, h)
				-- Если камера вида стоит во вьюпорте — новое разрешение сразу в сцену
				-- (критерий — камера, а не совпадение со старым renderWidth/Height)
				syncSceneResFromView bv
			)
			restoreSelectionByReal idxs
			if singleMode then (
				if getSel() > 0 do getViewParams (getRealIndex (getSel()))
			) else updateViewsListButtons()
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
			txt_out_ratio.text = ratio as string
			-- Источник — состояние вида в пространстве полей; при недоступности — поля
			local src = getFieldSpaceSrc()
			if src == undefined then (
				local fw = txt_out_w.text as integer
				local fh = txt_out_h.text as integer
				if fw == undefined or fh == undefined or fw <= 0 or fh <= 0 do return false
				src = #(fw, fh)
			)
			-- Единый расчёт: новая пропорция (Preserve MegaPix учитывается внутри);
			-- результат применяем как есть — снэп уже выполнен в фазе resolveRes
			local t = resolveRes mode:#ratio w:src[1] h:src[2] val:ratio \
				lock:chk_ratio.checked preserve:chk_preserve_mp.checked
			applyViewRes t[1] t[2]
			true
		)

		-- Мульти-режим при РАЗНЫХ базах (res-поля показывают "*"): применить изменение
		-- стороны/пропорции ко всем выделенным видам тем же механизмом, что и btn_copy_res —
		-- каждый вид получает своё целевое разрешение t; предупреждение показывается,
		-- только если у какого-то вида меняются пропорции (и не включён Preserve MegaPix),
			-- иначе применяем молча. mode: #w / #h / #ratio / #mp / #swap.
		fn applyMultiFieldRes mode val = (
			local idxs = getMultiEditIdxs()
			if idxs.count < 2 do return false
			local scale = if g_globalScale == undefined then 1.0 else g_globalScale
			local baseMode = chk_edit_base.checked and abs(scale - 1.0) > 0.001
			local targets = #()
			local propChanged = #()
			for r in idxs do (
				local bv = batchRenderMgr.GetView r
				if bv == undefined or isGroupView bv do continue
				local bb = getViewBase bv
				if bb[1] <= 0 or bb[2] <= 0 do continue
				local cur = if baseMode then #(bb[1], bb[2]) else resFromBase bb[1] bb[2]
				local t
				case mode of (
					#w: (
						if chk_preserve_mp.checked and cur[1] > 0 and cur[2] > 0 then (
							-- Preserve MegaPix: высота из суммарных пикселей вида (округление)
							t = #(val, (floor ((cur[1] as float) * cur[2] / val + 0.5)) as integer)
						) else if chk_ratio.checked and cur[1] > 0 and cur[2] > 0 then (
							-- LOCK: сохранить пропорции вида (пересчёт высоты)
							t = #(val, floor(cur[2] as float * val / cur[1]))
						) else t = #(val, cur[2])
					)
					#h: (
						if chk_preserve_mp.checked and cur[1] > 0 and cur[2] > 0 then (
							-- Preserve MegaPix: ширина из суммарных пикселей вида (округление)
							t = #((floor ((cur[1] as float) * cur[2] / val + 0.5)) as integer, val)
						) else if chk_ratio.checked and cur[1] > 0 and cur[2] > 0 then (
							-- LOCK: сохранить пропорции вида (пересчёт ширины)
							t = #(floor(cur[1] as float * val / cur[2]), val)
						) else t = #(cur[1], val)
					)
					#ratio: (
						-- как applyRatio: Preserve MegaPix ON — обе стороны под новые пропорции
						-- с сохранением мегапикселей (снэп к стандарту), иначе — ширина
						-- сохраняется, высота = w / ratio (снэп к стандарту).
						if chk_preserve_mp.checked and cur[1] > 0 and cur[2] > 0 then (
							local mp = cur[1] as float * cur[2]
							local newW = (sqrt(mp * val)) as integer
							local newH = (sqrt(mp / val)) as integer
							local snapped = snapResolutionKeepMP newW newH mp
							t = #(snapped[1], snapped[2])
						) else (
							local snapped = snapResolution cur[1] (cur[1] as float / val)
							t = #(snapped[1], snapped[2])
						)
					)
					#mp: (
						-- ввод МегаПикс: пропорции вида сохраняются, обе стороны
						-- пересчитываются под заданные мегапиксели (снэп к стандарту).
						local mpPx = val * 1000000.0
						local r = cur[1] as float / cur[2]
						local snapped = snapResolutionKeepMP ((sqrt (mpPx * r)) as integer) \
							((sqrt (mpPx / r)) as integer) mpPx
						t = #(snapped[1], snapped[2])
					)
					#swap: t = #(cur[2], cur[1])
					default: t = cur
				)
				if t[1] <= 0 or t[2] <= 0 do continue
				-- LOCK (chk_ratio при #w/#h) сохраняет пропорции по построению — не предупреждаем;
				-- иначе пропорции меняются, только если cur[1]*t[2] != t[1]*cur[2].
				local ratioKept = false
				if mode == #swap or mode == #mp then ratioKept = true
				else if not chk_preserve_mp.checked and chk_ratio.checked \
					and (mode == #w or mode == #h) then ratioKept = true
				else if cur[1] * t[2] == t[1] * cur[2] then ratioKept = true
				if not ratioKept then append propChanged #(bv, cur, t)
				append targets #(r, bv, t)
			)
			if targets.count == 0 do return false
			-- Переспрашиваем только если у какого-то из видов меняются пропорции и не включён
			-- 'Preserve MegaPix' (при нём каждый вид получает своё разрешение под свои пропорции).
			if propChanged.count > 0 and not chk_preserve_mp.checked then (
				local propChanged_str = ""
				for p in propChanged do (
					propChanged_str += "   " + (getCleanViewName p[1].name) + ": " + \
						(ratioString p[2][1] p[2][2]) + " -> " + (ratioString p[3][1] p[3][2]) + "\n"
				)
				propChanged_str = substring propChanged_str 1 (propChanged_str.count - 1)
				if not (queryBox (L10N.trMsg "copyResConfirm" args:#(propChanged_str)) title:(L10N.trMsg "titleBatchViews")) do return false
			)
			closeBatchWindow()
			for item in targets do (
				local t = item[3]
				local baseW = t[1]
				local baseH = t[2]
				if not baseMode and abs(scale - 1.0) > 0.001 then (
					baseW = (t[1] as float / scale) as integer
					baseH = (t[2] as float / scale) as integer
					if baseW <= 0 or baseH <= 0 do continue
				)
				setViewBase item[2] baseW baseH
				-- Камера вида во вьюпорте — новое разрешение сразу в сцену
				syncSceneResFromView item[2]
			)
			listViews()
			restoreSelectionByReal idxs
			updateOverrideUI()
			true
		)

		-- Обновить batch view из UI (txt_view_name/2/3, drdwn_state, база)
		fn viewUpdate = (
			if getSel() == 0 do return undefined
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined do return undefined
			local any_changed = false
			local name_changed = false

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
						messageBox (L10N.trMsg "viewExists")
						return undefined
					)
					bv.name = newName
					any_changed = true
					name_changed = true
				)
			) else (
				local clean = getCleanViewName txt_view_name.text
				-- База введена прямо в имени — сохранить её масштаб (не глобальный)
				local finalName
				if nameData[2] > 0 and nameData[3] > 0 then (
					if abs (nameData[4] - 1.0) < 0.001 then
						finalName = clean + " (" + (nameData[2] as string) + "x" + (nameData[3] as string) + ")"
					else
						finalName = clean + " (" + ((nameData[4] * 100) as integer) as string + "% of " + (nameData[2] as string) + "x" + (nameData[3] as string) + ")"
				) else (
					finalName = if baseW > 0 and baseH > 0 then viewNameFor clean baseW baseH else clean
				)
				if bv.name != finalName then (
					if batchRenderMgr.FindView finalName and bv.name != finalName then (
						messageBox (L10N.trMsg "viewExists")
						return undefined
					)
					bv.name = finalName
					any_changed = true
					name_changed = true
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
				messageBox (L10N.trMsg "dirNotExist") title:(L10N.trMsg "titleError")
				return undefined
			)

			local selected_scene_state = if drdwn_state.selection > 1 then drdwn_state.items[drdwn_state.selection] else ""
			if selected_scene_state != bv.sceneStateName do (
				bv.sceneStateName = selected_scene_state
				any_changed = true
				-- Если вид активирован в сцене — сразу применить новое состояние сцены
				if selected_scene_state != "" and isViewActivated bv then (
					local ssp = sceneStateMgr.GetParts selected_scene_state
					sceneStateMgr.Restore selected_scene_state ssp
					redrawViews()
				)
			)

			if baseW > 0 and baseH > 0 and chk_sync_views.checked and isValidNode bv.camera do (
				syncViewsForCam bv.camera #(baseW, baseH) (resFromBase baseW baseH)
			)

			if any_changed do (
				-- Список и нативное окно перерисовываем только при смене имени вида
				if name_changed do (
					closeBatchWindow()
					listViews()
				)
				if getSel() > 0 do getViewParams (getRealIndex (getSel()))
			)
		)

		-- Отобразить разрешение камеры в спиннерах (из её видов, уважает галку)
		fn displayCamRes cam = (
			local base = getCamResFromViews cam
			showResForBase base[1] base[2]
		)

		-- Цели переключения enabled: выделенные виды + все виды внутри выделенных групп
		fn collectToggleTargets = (
			local targets = #()
			for ui in getSelectedUiIndices() do (
				local realIdx = getRealIndex ui
				if realIdx > 0 then (
					local v = batchRenderMgr.GetView realIdx
					if v != undefined then (
						if isGroupView v then (
							local bounds = getGroupBounds realIdx
							for j = (bounds[1] + 1) to bounds[2] do (
								local m = batchRenderMgr.GetView j
								if not (isGroupView m) and findItem targets j == 0 do append targets j
							)
						) else (
							if findItem targets realIdx == 0 do append targets realIdx
						)
					)
				)
			)
			targets
		)

		-- Свернуть/развернуть группу (второй клик по выделенной группе)
		fn toggleGroupCollapse realIdx = (
			local the_view = batchRenderMgr.GetView realIdx
			if the_view == undefined or not (isGroupView the_view) do return false
			local prefix = substring the_view.name 1 1
			if prefix == PROP_COLLAPSED then
				the_view.name = PROP_EXPANDED + substring the_view.name 2 -1
			else if prefix == PROP_EXPANDED then
				the_view.name = PROP_COLLAPSED + substring the_view.name 2 -1
			else
				the_view.name = PROP_COLLAPSED + the_view.name
			g_roll_batch.listViews()
			local savedIdx = findItem g_visibleIndices realIdx
			if savedIdx > 0 do setSel savedIdx
			true
		)

		--------------------------------
		on roll_batch open do (
			initListBox()
			listViews()
			setSel 0
			chk_snap.checked = g_snap
			updateOverrideUI()
			updateCopyResBtn()
			local cam = if g_roll_cams != undefined then g_roll_cams.active_cam else undefined
			if isValidNode cam and (isKindOf cam camera) then (
				local camIdx = findCameraInDropdown cam.name
				if camIdx != 0 do drdwn_cam.selection = camIdx
			)
			selectFirstViewForCamera cam
		)

		on roll_batch close do (
			try ( tmr_apply.active = false ) catch ()
			saveFloaterState()
		)
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
			listViews()
			if g_roll_cams != undefined do (
				g_roll_cams.relistCams()
				g_roll_cams.changeActive()
				g_roll_cams.syncCameraUI()
			)
			-- Активная камера (поиск по вьюпортам): выделить первый её вид;
			-- иначе вернуть прежнее выделение вида
			local cam = getViewportCam()
			if cam != undefined and (selectFirstViewForCamera cam) then ()
			else if prevView != undefined then (
				for i = 1 to g_visibleIndices.count do (
					if batchRenderMgr.GetView g_visibleIndices[i] == prevView do (
						setSel i
						getViewParams g_visibleIndices[i]
						exit
					)
				)
			) else if getSel() > 0 do getViewParams (getRealIndex (getSel()))
		)

		on txt_view_name entered txt do viewUpdate()
		on txt_view_path entered txt do (
			if isMultiEdit() then ( setMultiPath(); return false )
			viewUpdate()
		)
		on txt_view_file entered txt do viewUpdate()

		on drdwn_state selected index do (
			if isMultiEdit() then (
				local state = if index > 1 then drdwn_state.items[index] else ""
				for r in getMultiEditIdxs() do (batchRenderMgr.GetView r).sceneStateName = state
				updateOverrideUI()
				return false
			)
			viewUpdate()
		)
		on spn_start_frame changed val do (
			if isMultiEdit() then (
				for r in getMultiEditIdxs() do (batchRenderMgr.GetView r).startFrame = val as integer
				return false
			)
			if getSel() != 0 then (
				local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
				if bv != undefined do (
					bv.startFrame = val as integer
				)
			)
		)
		on spn_end_frame changed val do (
			if isMultiEdit() then (
				for r in getMultiEditIdxs() do (batchRenderMgr.GetView r).endFrame = val as integer
				return false
			)
			if getSel() != 0 then (
				local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
				if bv != undefined do (
					bv.endFrame = val as integer
				)
			)
		)

		on btn_use_current_res pressed do (
			applyViewRes renderWidth renderHeight
		)

		on btn_copy_res pressed do (
			-- Источник — АКТИВНЫЙ вид: загруженный в интерфейс
			-- (его имя — в поле View name). Кн��пка недоступна без активного вида,
			-- поэтому этот guard — лишь страховка.
			local activeView = getActiveView()
			if activeView == undefined or (isGroupView activeView) do return false
			local b = getViewBase activeView
			if b[1] <= 0 or b[2] <= 0 do return false
			local scale = if g_globalScale == undefined then 1.0 else g_globalScale
			-- В каком представлении работает копирование:
			-- 'Base size' ON  — база (100%), OFF — текущий (масштабированный) размер.
			local baseMode = chk_edit_base.checked and abs(scale - 1.0) > 0.001
			-- Разрешение источника в выбранном представлении.
			local srcW = b[1]
			local srcH = b[2]
			if not baseMode then (
				local cur = resFromBase b[1] b[2]
				srcW = cur[1]
				srcH = cur[2]
			)
			-- При 'Preserve MegaPix' OFF ориентация закреплена: каждый вид получает
			-- WxH источника, развёрнутый под его ориентацию (orientedCopyResForView).
			-- Поэтому опираемся не на конкретные значения разрешений, а только на
			-- пропорции: предупреждаем, если у какого-то из ОСТАЛЬНЫХ видов (активный
			-- вид исключаем — сравнение с ним бессмысленно: его разрешение — источник)
			-- пропорции изменятся после копирования.
			local propChanged = #()
			for i = 1 to batchRenderMgr.NumViews do (
				local v = batchRenderMgr.GetView i
				if v != undefined and v != activeView and not (isGroupView v) then (
					local bb = getViewBase v
					if bb[1] > 0 and bb[2] > 0 then (
						local cur = if baseMode then #(bb[1], bb[2]) else resFromBase bb[1] bb[2]
						local r = orientedCopyResForView v srcW srcH
						if cur[1] * r[2] != r[1] * cur[2] then append propChanged #(v, cur, r)
					)
				)
			)
			-- Переспрашиваем только если у какого-то из ОСТАЛЬНЫХ видов изменятся
			-- пропорции и не включён режим 'Preserve MegaPix' (при нём каждый вид
			-- получает своё разрешение под свои пропорции — диалог не нужен).
			-- Действие нельзя отменить; если пропорции не меняются — копируем без диалога.
			if propChanged.count > 0 and not chk_preserve_mp.checked then (
				local propChanged_str = ""
				for p in propChanged do (
					propChanged_str += "   " + (getCleanViewName p[1].name) + ": " + \
						(ratioString p[2][1] p[2][2]) + " -> " + (ratioString p[3][1] p[3][2]) + "\n"
				)
				propChanged_str = substring propChanged_str 1 (propChanged_str.count - 1)
				if not (queryBox (L10N.trMsg "copyResConfirm" args:#(propChanged_str)) title:(L10N.trMsg "titleBatchViews")) do return false
			)
			closeBatchWindow()
			local count = 0
			for i = 1 to batchRenderMgr.NumViews do (
				local v = batchRenderMgr.GetView i
				if v != undefined and not (isGroupView v) then (
					local r
					-- 'Preserve MegaPix' ON — сохранить суммарные мегапиксели,
					-- пересчитав обе стороны под пропорции каждого вида.
					if chk_preserve_mp.checked then (
						local tb = getViewBase v
						local ratio = if tb[1] > 0 and tb[2] > 0 then (tb[1] as float / tb[2]) else (srcW as float / srcH)
						if ratio > 0 then (
							local mp = srcW as float * srcH as float
							local newW = (sqrt(mp * ratio)) as integer
							local newH = (sqrt(mp / ratio)) as integer
							local snapped = snapResolutionKeepMP newW newH mp
							r = #(snapped[1], snapped[2])
						) else r = #(srcW, srcH)
					) else (
						r = orientedCopyResForView v srcW srcH
					)
					-- Пересчитать результат в базу для setViewBase
					local baseW = r[1]
					local baseH = r[2]
					if not baseMode and abs(scale - 1.0) > 0.001 then (
						baseW = (r[1] as float / scale) as integer
						baseH = (r[2] as float / scale) as integer
						if baseW <= 0 or baseH <= 0 do continue
					)
					setViewBase v baseW baseH
					-- Камера вида во вьюпорте — новое разрешение сразу в сцену
					syncSceneResFromView v
					count += 1
				)
			)
			if count > 0 and g_roll_batch != undefined then (
				g_roll_batch.listViews()
				if g_roll_batch.getSel() > 0 do (
					g_roll_batch.getViewParams (g_roll_batch.getRealIndex (g_roll_batch.getSel()))
				)
			)
		)

		on chk_sync_views changed state do (
			-- Массово: флаг — свойство камеры, ставим его всем уникальным камерам
			-- выделенных видов (без автоподбора размера — в мульти-режиме он неоднозначен).
			if isMultiEdit() then (
				local cams = #()
				for r in getMultiEditIdxs() do (
					local bv = batchRenderMgr.GetView r
					if bv != undefined and isValidNode bv.camera and findItem cams bv.camera == 0 do append cams bv.camera
				)
				for cam in cams do setUserProp cam "sync_batch_views" state
				return false
			)
			if getSel() == 0 do return false
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined or not (isValidNode bv.camera) do return false
			setUserProp bv.camera "sync_batch_views" state
			if state do (
				local base = getViewBase bv
				if base[1] > 0 and base[2] > 0 do syncViewsForCam bv.camera base (resFromBase base[1] base[2])
				listViews()
			)
		)

		-- CAMERA SELECTION
		on drdwn_cam selected index do (
			if index <= 1 do return false
			local cam_name = stripCamResSuffix drdwn_cam.items[index]
			local cam = getNodeByName cam_name
			if not (isValidNode cam) or not (isKindOf cam camera) do return false
			-- Массово: назначить камеру ВСЕМ выделенным видам (диалог базы — один раз)
			if isMultiEdit() then (
				local idxs = getMultiEditIdxs()
				for r in idxs do (batchRenderMgr.GetView r).camera = cam
				if g_roll_cams != undefined do (
					g_roll_cams.setActiveCam cam
					g_roll_cams.syncCameraUI()
				)
				local res = getCamResFromViews cam
				if res[1] > 0 and res[2] > 0 then (
					if queryBox (L10N.trMsg "applyAsBase" args:#(res[1], res[2])) title:(L10N.trMsg "titleCameraBase") do (
						closeBatchWindow()
						for r in idxs do setViewBase (batchRenderMgr.GetView r) res[1] res[2]
						listViews()
						restoreSelectionByReal idxs
						-- Камера какого-либо вида во вьюпорте — разрешение сразу в сцену
						for r in idxs do syncSceneResFromView (batchRenderMgr.GetView r)
					)
				)
				updateOverrideUI()
				return false
			)
			if getSel() != 0 then (
				local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
				if bv != undefined then (
					bv.camera = cam
					if g_roll_cams != undefined do (
						g_roll_cams.setActiveCam cam
						g_roll_cams.syncCameraUI()
					)
					local res = getCamResFromViews cam
					if res[1] > 0 and res[2] > 0 then (
						if queryBox (L10N.trMsg "applyAsBase" args:#(res[1], res[2])) title:(L10N.trMsg "titleCameraBase") do (
							closeBatchWindow()
							setViewBase bv res[1] res[2]
							syncSceneResFromView bv
							listViews()
							if getSel() > 0 do getViewParams (getRealIndex (getSel()))
						)
					)
				)
			)
		)

		on btn_use_active_cam pressed do (
			-- Массово: назначить активную камеру ВСЕМ выделенным видам
			if isMultiEdit() then (
				local cam = getViewportCam()
				if isValidNode cam and (isKindOf cam camera) then (
					local idxs = getMultiEditIdxs()
					closeBatchWindow()
					for r in idxs do (batchRenderMgr.GetView r).camera = cam
					if g_roll_cams != undefined do (
						g_roll_cams.setActiveCam cam
						g_roll_cams.syncCameraUI()
					)
					listViews()
					restoreSelectionByReal idxs
				)
				return false
			)
			if getSel() != 0 then (
				local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
				if bv != undefined then (
					local cam = getViewportCam()
					if isValidNode cam and (isKindOf cam camera) then (
						closeBatchWindow()
						bv.camera = cam
						if g_roll_cams != undefined do (
							g_roll_cams.active_cam = cam
							g_roll_cams.changeActive()
							g_roll_cams.syncCameraUI()
						)
						listViews()
					)
				)
			)
		)

		on btn_open_in_explorer pressed do (
			if txt_view_path.text != "" then (
				if doesfileexist txt_view_path.text then (
					ShellLaunch "explorer.exe" ("\"" + txt_view_path.text + "\"")
				) else messageBox (L10N.trMsg "dirNotExist") title:(L10N.trMsg "titleError")
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
				if isMultiEdit() then (
					-- Массово: применяется только папка, имена файлов видов сохраняются
					setMultiPathFromPicked new_path
				) else (
					g_view_path = new_path
					updatePath()
					if g_active_view != undefined and g_view_path != undefined do (
						closeBatchWindow()
						g_active_view.outputFilename = g_view_path
					)
				)
			)
		)

		on btn_render pressed do ( batchRenderMgr.render() )
		on btn_net_render changed state do (
			closeBatchWindow()
			batchRenderMgr.netRender = state
		)


		on btn_prev_view pressed do (
			local uiIdx = getSel()
			if uiIdx == 0 do uiIdx = g_visibleIndices.count + 1
			local target = findViewUiIndex uiIdx -1
			if target > 0 then selectViewByUiIndex target
		)

		on btn_next_view pressed do (
			local uiIdx = getSel()
			local target = findViewUiIndex uiIdx 1
			if target > 0 then selectViewByUiIndex target
		)

		on btn_select_cam pressed do (
			max modify mode
			local cam = if g_roll_cams != undefined then g_roll_cams.active_cam else undefined
			if not (isValidNode cam) and getSel() > 0 then (
				local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
				if bv != undefined do cam = bv.camera
			)
			if isValidNode cam and (isKindOf cam camera) then select cam
		)

		-- SINGLE CLICK: группа — только выделение, вид — загрузка параметров;
		-- 2+ выделенных видов — режим массового редактирования.
		on lst_views SelectedIndexChanged sender args do (
			local index = getSel()
			if index <= 0 do return false
			if isMultiEdit() then (
				g_active_view = undefined
				updateViewsListButtons()
				return false
			)
			local realIdx = getRealIndex index
			if realIdx > 0 then (
				local the_view = batchRenderMgr.GetView realIdx
				if isGroupView the_view then (
					txt_view_name.text = stripCollapsePrefix the_view.name
				) else (
					g_active_view = getViewParams realIdx
				)
				updateViewsListButtons()
			)
		)

		-- Снапшот выделения ДО применения клика (WinForms меняет выделение на
		-- MouseDown, поэтому к MouseUp/SelectedIndexChanged прежний набор уже
		-- недоступен — сравнивать не с чем).
		on lst_views MouseDown sender args do (
			g_selSnapshot = getSelectedUiIndices()
		)

		-- Одиночный клик без Ctrl/Shift:
		--   первый клик — только выделение (галочка не меняется);
		--   повторный клик по выделенному элементу → загрузка вида в сцену (с задержкой через
		--   tmr_apply, чтобы отличить от двойного клика); группа — свернуть/развернуть.
		-- Ctrl/Shift+клик — только управление выделением, галку не трогаем.
		-- Двойной клик по виду — вкл/выкл (см. MouseDoubleClick).
		-- Windows шлёт MouseUp на каждый клик; при двойном клике хвостовые MouseUp гасятся
		-- флагом g_dblPending, а отложенное применение отменяется в MouseDoubleClick.
		-- Invalidate() после клика убирает залипшие подсветки старых строк.
		on lst_views MouseUp sender args do (
			if (args.Button.ToString()) != "Left" do return false
			local uiIdx = (lst_views.IndexFromPoint args.X args.Y) + 1

			-- Строки из снапшота MouseDown, потерявшие выделение этим жестом
			-- (типовой случай: обычный клик по одному виду после Ctrl-мультивыделения —
			-- WinForms снял выделение с остальных ещё на MouseDown, но owner-draw
			-- продолжал рисовать старую подсветку). До возвратов ниже: клик по пустой
			-- области (uiIdx == 0) тоже снимает выделение. Хвостовой MouseUp двойного
			-- клика здесь безвреден — его снапшот совпадает с текущим состоянием.
			for si in g_selSnapshot do (
				if si >= 1 and si <= lst_views.Items.Count and si != uiIdx \
					and not (lst_views.GetSelected (si - 1)) do (
					local r = lst_views.GetItemRectangle (si - 1)
					lst_views.Invalidate r
				)
			)

			if uiIdx <= 0 or uiIdx > g_visibleIndices.count do return false

			-- Второй клик двойного нажатия: действие уже сделал первый клик (или MouseDoubleClick),
			-- этот MouseUp — просто хвост двойного клика.
			if g_dblPending do (
				g_dblPending = false
				return false
			)

			local modStr = (dotNetClass "System.Windows.Forms.Control").ModifierKeys.ToString()
			if matchPattern modStr pattern:"*Control*" or matchPattern modStr pattern:"*Shift*" do (
				prev_sel = 0
				g_pending_apply = 0
				tmr_apply.active = false
				lst_views.Invalidate()
				return false
			)

			local realIdx = getRealIndex uiIdx
			local the_view = if realIdx > 0 then batchRenderMgr.GetView realIdx else undefined

			if uiIdx == prev_sel and getSel() == uiIdx and (getSelectedUiIndices()).count == 1 then (
				-- повторный клик по единственному выделенному элементу:
				-- вид — применить в сцену, группа — свернуть/развернуть (отложено через
				-- tmr_apply, чтобы отличить от двойного клика).
				-- Список при этом не трогаем: содержимое не меняется, полная
				-- перерисовка здесь была бы лишним «обновлением»/миганием.
				if the_view != undefined then (
					tmr_apply.active = false
					g_pending_apply = realIdx
					tmr_apply.active = true
				)
			) else (
				-- новый выбор: только выделяем, галочку не трогаем.
				-- У owner-draw списка в хостинге 3ds Max нативной перерисовки строк при
				-- смене выделения нет (см. камеры — там нативная отрисовка, поэтому контрол
				-- сам обновляет выделение). Поэтому перерисовываем только изменившиеся
				-- строки (старую и новую), а не весь список — полная перерисовка давала
				-- мигание всего списка при каждом выборе.
				local oldUi = prev_sel
				prev_sel = uiIdx
				g_pending_apply = 0
				tmr_apply.active = false
				if oldUi > 0 and oldUi <= lst_views.Items.Count and oldUi != uiIdx do (
					local r = lst_views.GetItemRectangle (oldUi - 1)
					lst_views.Invalidate r
				)
				if uiIdx > 0 and uiIdx <= lst_views.Items.Count do (
					local r = lst_views.GetItemRectangle (uiIdx - 1)
					lst_views.Invalidate r
				)
			)
		)

		-- Нативного чекбокса больше нет (plain ListBox) — toggle делает MouseDoubleClick

		-- OWNER DRAW: у групп галочки нет, у видов рисуем квадрат-галочку сами
		on lst_views DrawItem sender args do (
			local idx = args.Index
			if idx < 0 do return false
			local rect = args.Bounds
			local g = args.Graphics
			local realIdx = getRealIndex (idx + 1)
			local the_view = undefined
			local isGroup = false
			if realIdx > 0 do (
				the_view = batchRenderMgr.GetView realIdx
				if the_view != undefined do isGroup = isGroupView the_view
			)
			local isSelected = lst_views.GetSelected idx

			local backBrush = dotNetObject "System.Drawing.SolidBrush" (
				if isSelected then (dotNetClass "System.Drawing.SystemColors").Highlight else lst_views.BackColor
			)
			g.FillRectangle backBrush rect
			backBrush.Dispose()

			if the_view == undefined do return false

			local textColor
			if isSelected then
				textColor = (dotNetClass "System.Drawing.SystemColors").HighlightText
			else if isGroup then
				textColor = (dotNetClass "System.Drawing.Color").FromARGB 190 190 190
			else
				textColor = lst_views.ForeColor

			local x = rect.X + 2
			if not isGroup then (
				local boxSize = 12
				local boxRect = dotNetObject "System.Drawing.Rectangle" x (rect.Y + ((rect.Height - boxSize) / 2)) boxSize boxSize
				local borderPen = (dotNetClass "System.Drawing.Pens").Gray
				g.DrawRectangle borderPen boxRect
				if the_view.enabled then (
					local blueColor = (dotNetClass "System.Drawing.Color").FromARGB 0 122 204
					local fillBrush = dotNetObject "System.Drawing.SolidBrush" blueColor
					g.FillRectangle fillBrush boxRect
					fillBrush.Dispose()
					local pen2 = (dotNetClass "System.Drawing.Pens").White
					local cx = boxRect.X
					local cy = boxRect.Y
					g.DrawLine pen2 (cx + 3) (cy + 7) (cx + 6) (cy + 9)
					g.DrawLine pen2 (cx + 6) (cy + 9) (cx + 10) (cy + 3)
				)
				x += boxSize + 7
			)

			local textBrush = dotNetObject "System.Drawing.SolidBrush" textColor
			local textRect = dotNetObject "System.Drawing.RectangleF" (x as float) (rect.Y as float) ((rect.Width - (x - rect.X)) as float) (rect.Height as float)
			local sf = dotNetObject "System.Drawing.StringFormat"
			sf.LineAlignment = (dotNetClass "System.Drawing.StringAlignment").Center
			sf.FormatFlags = (dotNetClass "System.Drawing.StringFormatFlags").NoWrap
			sf.Trimming = (dotNetClass "System.Drawing.StringTrimming").EllipsisCharacter
			g.DrawString (lst_views.Items.Item[idx] as string) args.Font textBrush textRect sf
			sf.Dispose()
			textBrush.Dispose()
		)

		on lst_views MouseDoubleClick sender args do (
			local idx = lst_views.IndexFromPoint args.X args.Y
			if idx < 0 do return false
			local realIdx = getRealIndex (idx + 1)
			if realIdx <= 0 do return false
			local the_view = batchRenderMgr.GetView realIdx
			if the_view == undefined do return false
			closeBatchWindow()
			-- Windows шлёт MouseUp на каждый клик + ещё раз после MouseDoubleClick.
			-- Гасим следующие MouseUp: действие двойного клика уже сделано здесь.
			g_dblPending = true
			-- Отменить отложенное действие «второго клика» — двойной клик = toggle.
			tmr_apply.active = false
			g_pending_apply = 0
			-- Двойной клик: группа — свернуть/развернуть, вид — вкл/выкл enabled.
			if isGroupView the_view then (
				toggleGroupCollapse realIdx
			) else (
				setViewCheckedAtUi (idx + 1) (not the_view.enabled)
			)
		)

		-- Тик таймера: отложенное действие по «второму клику» — вид: применить в сцену, группа: свернуть/развернуть.
		on tmr_apply tick do (
			tmr_apply.active = false
			local idx = g_pending_apply
			g_pending_apply = 0
			if idx > 0 then (
				local uiIdx = findItem g_visibleIndices idx
				if uiIdx > 0 and uiIdx == getSel() then (
					local the_view = batchRenderMgr.GetView idx
					if the_view != undefined then (
						if isGroupView the_view then (
							toggleGroupCollapse idx
						) else (
							-- Применение вида не меняет содержимое списка (имя и галочка те же),
							-- поэтому список не перестраиваем — иначе он лишний раз мигает.
							closeBatchWindow()
							applyViewToScene the_view
							getViewParams idx
						)
					)
				)
			)
		)

		on btn_views_info pressed do (
			messageBox (L10N.trMsg "batchViewsInfoMsg") title:(L10N.trMsg "titleBatchViews")
		)

		--( КОНТЕКСТНОЕ МЕНЮ УДАЛЕНИЯ: rollout-локали свитка
		-- rcmenu rmc_del_group/rmc_del_view определены на уровне макроса (см. блок
		-- перед rollout roll_batch); их обработчики обращаются к этим локальным переменным и
		-- delApply через объект свитка: g_roll_batch.delApply, g_roll_batch.delGroupsCtx
		-- (rollout-локальные переменные доступны снаружи как свойства rollout-объекта).
		-- popUpMenu НЕ блокирует выполнение; пункта «Отмена» в меню нет — отмена это
		-- клик вне меню (picked не сработает). Поэтому контекст сбрасывается и
		-- пересобирается при КАЖДОМ нажатии btn_rem, а после применения — в delApply:
		-- так исключается применение «протухшего» контекста от прежнего меню.
		-- Контекст сбора удаления (заполняет btn_rem, читает delApply):
		--
		-- delGroupsCtx — записи выделенных групп (по одной на группу):
		--   #(grpName, srcIdx, headerReal, flatRange):
		--     grpName    — чистое имя группы (без префикса свёрнутости);
		--     srcIdx     — индекс группы в splitIntoGroups (для построения flatRange);
		--     headerReal — реальный индекс строки заголовка группы;
		--     flatRange  — плоские индексы ВСЕХ строк группы (заголовок + виды),
		--                  для варианта «удалить группу с содержимым».
		-- delPlainsCtx — реальные индексы «плоских» строк: одиночные виды и
		--   заголовки ПУСТЫХ групп (такие строки удаляются всегда, при любом выборе).
		local delGroupsCtx = #()
		local delPlainsCtx = #()

		-- groupWithContent = true  — удалить группы целиком (заголовок + все виды внутри);
		-- groupWithContent = false — удалить только строки заголовков групп.
		-- «Плоские» строки (delPlainsCtx) удаляются в обоих случаях.
		fn delApply groupWithContent:false = (
			if delGroupsCtx.count == 0 and delPlainsCtx.count == 0 do return false
			local toDelete = #()
			for entry in delGroupsCtx do (
				local r = entry[3]
				local range = entry[4]
				if groupWithContent then (
					for idx in range do if findItem toDelete idx == 0 do append toDelete idx
				) else (
					if findItem toDelete r == 0 do append toDelete r
				)
			)
			for p in delPlainsCtx do if findItem toDelete p == 0 do append toDelete p
			if toDelete.count > 0 then (
				sort toDelete
				for i = toDelete.count to 1 by -1 do batchRenderMgr.DeleteView toDelete[i]
				g_batch_view = undefined
				g_view_name = ""
				g_active_view = undefined
				setSel 0
				listViews()
				updateViewsListButtons()
			)
			delGroupsCtx = #()
			delPlainsCtx = #()
		)
		--) Конец КОНТЕКСТНОЕ МЕНЮ УДАЛЕНИЯ (rollout-локали)

		-- DELETE VIEW / GROUP (одно выделение или несколько)
		on btn_rem pressed do (
			-- Контекст собирается заново при каждом нажатии: сбрасываем накопленное,
			-- т.к. отмена = клик вне меню (picked не срабатывает, delApply не вызывается).
			delGroupsCtx = #()
			delPlainsCtx = #()
			local selReal = getSelectedRealIdxs()
			if selReal.count == 0 do return false
			closeBatchWindow()

			-- Контекст удаления пишется в rollout-локали delGroupsCtx/delPlainsCtx;
			-- их читает delApply при выборе пункта меню (см. rcmenu выше).
			local allData = collectAllViewData()
			local groups = splitIntoGroups allData
			local addedGroups = #()
			local hasGroups = false
			for r in selReal do (
				local the_view = batchRenderMgr.GetView r
				if the_view != undefined then (
					if isGroupView the_view then (
						local srcIdx = findGroupForView groups r
						if srcIdx == 0 do continue
						if findItem addedGroups srcIdx > 0 do continue
						append addedGroups srcIdx
						local grp = groups[srcIdx]
						local grpName = stripCollapsePrefix grp[1].name
						local hasViews = false
						for vd in grp where not (isGroupName vd.name) do (hasViews = true; exit)
						if hasViews then (
							-- Плоские индексы всего диапазона группы
							local range = #()
							local flatIdx = 0
							for i = 1 to groups.count do (
								for vd in groups[i] do (
									flatIdx += 1
									if i == srcIdx do append range flatIdx
								)
							)
							append delGroupsCtx #(grpName, srcIdx, r, range)
							hasGroups = true
						) else (
							-- Пустая группа — удаляем строку заголовка как простую строку
							if findItem delPlainsCtx r == 0 do append delPlainsCtx r
						)
					) else (
						if findItem delPlainsCtx r == 0 do append delPlainsCtx r
					)
				)
			)

			if delGroupsCtx.count == 0 and delPlainsCtx.count == 0 do return false

			-- popUpMenu без pos: меню появляется в текущей позиции мыши.
			if hasGroups then (
				popUpMenu rmc_del_group
			) else (
				popUpMenu rmc_del_view
			)
		)

		-- DUPLICATE VIEWS / GROUPS (мультивыбор)
		-- Копии вставляются ОДНИМ БЛОКОМ сразу после последнего выделенного источника
		-- (группа копируется целиком: заголовок + все виды внутри, блоком, не вперемешку).
		on btn_dup pressed do (
			local selReal = getSelectedRealIdxs()
			if selReal.count == 0 do return false

			closeBatchWindow()
			local allData = collectAllViewData()
			if allData.count == 0 do return false

			-- Диапазоны источников в порядке выделения: группа = #(start,end), одиночный вид = #(r,r).
			-- Если выбраны и заголовок группы, и её виды — группа считается один раз.
			local ranges = #()
			local covered = #()
			for r in selReal do (
				if findItem covered r > 0 do continue
				if r < 1 or r > allData.count do continue
				local v = batchRenderMgr.GetView r
				if v == undefined do continue
				if isGroupView v then (
					local b = getGroupBounds r
					append ranges b
					for i = b[1] to b[2] do append covered i
				) else (
					append ranges #(r, r)
					append covered r
				)
			)
			if ranges.count == 0 do return false
			qsort ranges (fn cmpRanges a b = a[1] - b[1])

			-- Занятые базовые имена (оригиналы + уже созданные копии)
			local takenBases = #()
			local takenGroups = #()
			for vd in allData do (
				if isGroupName vd.name then (
					local gs = stripCollapsePrefix vd.name
					if findItem takenGroups gs == 0 do append takenGroups gs
				) else (
					local bn = getCleanViewName vd.name
					if bn != "" and findItem takenBases bn == 0 do append takenBases bn
				)
			)

			-- Построить копии (имена уникальны относительно оригиналов И других копий)
			local copyData = #()
			for rg in ranges do (
				local hdr = allData[rg[1]]
				if isGroupName hdr.name then (
					-- ГРУППА: заголовок + все виды внутри
					local srcPrefix = substring hdr.name 1 1
					local hasPrefix = (srcPrefix == PROP_COLLAPSED or srcPrefix == PROP_EXPANDED)
					local grpName = duplicateGroupName hdr.name
					local grpStripped = stripCollapsePrefix grpName
					while findItem takenGroups grpStripped > 0 do (
						grpName = duplicateGroupName grpName
						grpStripped = stripCollapsePrefix grpName
					)
					append takenGroups grpStripped
					local newGrpFull = if hasPrefix then srcPrefix + grpStripped else grpStripped

					local hdrCopy = copy hdr
					hdrCopy.name = newGrpFull
					append copyData hdrCopy
					for i = (rg[1] + 1) to rg[2] do (
						local vd = copy allData[i]
						local oldName = vd.name
						local newName = duplicateViewName oldName undefined
						local newClean = getCleanViewName newName
						while findItem takenBases newClean > 0 do newClean = bumpBaseName newClean
						append takenBases newClean
						-- Суффикс разрешения в новом имени (" (50% of 1920x1280)") сохранить
						local oldClean = getCleanViewName oldName
						local suffix = if oldClean.count < oldName.count then subString oldName (oldClean.count + 1) -1 else ""
						vd.name = newClean + suffix
						-- Обновить имя файла вывода (заменить чистое имя источника на новое)
						if vd.outputFilename != undefined and vd.outputFilename != "" then (
							local path = getFilenamePath vd.outputFilename
							local fname = getFilenameFile vd.outputFilename
							local ftype = getFilenameType vd.outputFilename
							local p = findString fname oldClean
							if p != undefined and oldClean != "" then (
								vd.outputFilename = path + (replace fname p oldClean.count newClean) + ftype
							)
						)
						append copyData vd
					)
				) else (
					-- ОДИНОЧНЫЙ ВИД
					local vd = copy hdr
					local oldName = vd.name
					local newName = duplicateViewName oldName undefined
					local newClean = getCleanViewName newName
					while findItem takenBases newClean > 0 do newClean = bumpBaseName newClean
					append takenBases newClean
					local oldClean = getCleanViewName oldName
					local suffix = if oldClean.count < oldName.count then subString oldName (oldClean.count + 1) -1 else ""
					vd.name = newClean + suffix
					if vd.outputFilename != undefined and vd.outputFilename != "" then (
						local path = getFilenamePath vd.outputFilename
						local fname = getFilenameFile vd.outputFilename
						local ftype = getFilenameType vd.outputFilename
						local p = findString fname oldClean
						if p != undefined and oldClean != "" then (
							vd.outputFilename = path + (replace fname p oldClean.count newClean) + ftype
						)
					)
					append copyData vd
				)
			)
			if copyData.count == 0 do return false

			-- Вставить ВСЕ копии одним блоком сразу после последнего источника
			local insertAfter = ranges[ranges.count][2]
			local newData = #()
			for i = 1 to insertAfter do append newData allData[i]
			for vd in copyData do append newData vd
			for i = (insertAfter + 1) to allData.count do append newData allData[i]
			rebuildBatchViews newData

			-- Показать список и выделить ВСЕ созданные копии (блоком после последнего источника)
			listViews()
			lst_views.ClearSelected()
			local newReal = #()
			for i = (insertAfter + 1) to (insertAfter + copyData.count) do (
				if i <= batchRenderMgr.numViews do append newReal i
			)
			local newUi = #()
			for r in newReal do (
				local ui = findItem g_visibleIndices r
				if ui > 0 and findItem newUi ui == 0 do append newUi ui
			)
			if newUi.count > 0 then (
				setSelectedUiIndices newUi
				local firstReal = insertAfter + 1
				local the_view = batchRenderMgr.GetView firstReal
				if the_view != undefined and isGroupView the_view then (
					txt_view_name.text = stripCollapsePrefix the_view.name
				) else if the_view != undefined then (
					g_active_view = getViewParams firstReal
				)
			) else (
				setSel 0
			)
			updateViewsListButtons()
		)

		-- TOGGLE ENABLED (группа = все виды в ней, одиночный вид = один)
		on btn_togleEnabled pressed do (
			local selReal = getSelectedRealIdxs()
			if selReal.count == 0 do return false
			local targets = collectToggleTargets()
			if targets.count == 0 do return false
			closeBatchWindow()
			local anyOff = false
			for r in targets do (
				if not (batchRenderMgr.GetView r).enabled do (anyOff = true; exit)
			)
			-- любая выключенная цель → включаем все; все включены → выключаем все
			for r in targets do (batchRenderMgr.GetView r).enabled = anyOff
			restoreSelectionByReal selReal
			updateViewsListButtons()
		)

		-- TOGGLE ENABLED ALL
		on btn_togleEnabledAll pressed do (
			closeBatchWindow()
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
			listViews()
		)

		-- MOVE SELECTED UP (вид — свободно, в т.ч. в другую группу; заголовок — вся группа)
		on btn_up pressed do (
			local newReal = moveSelectedViews #up
			if newReal.count == 0 do return false
			listViews()
			local selUis = #()
			for r in newReal do (
				local ui = findItem g_visibleIndices r
				if ui > 0 and findItem selUis ui == 0 do append selUis ui
			)
			if selUis.count > 0 do setSelectedUiIndices selUis
			updateViewsListButtons()
		)

		-- ADD GROUP
		on btn_add_sep pressed do (
			local sep_name
			local n = 0
			do (
				n += 1
				sep_name = " ----- " + L10N.trMsg "groupWord" + " " + n as string + " -----"
			) while not (isGroupNameAvailable sep_name)

			local sep_view = batchRenderMgr.CreateView undefined
			sep_view.name = sep_name
			sep_view.enabled = false

			if getSel() > 0 then (
				local realIdx = getRealIndex (getSel())
				moveViewIndex batchRenderMgr.numViews realIdx
			) else (
				setSel batchRenderMgr.numViews
			)

			listViews()
			-- Выделить созданный заголовок (только его, сбросив мультивыбор)
			lst_views.ClearSelected()
			for i = 1 to g_visibleIndices.count do (
				if (batchRenderMgr.GetView g_visibleIndices[i]).name == sep_name do (
					setSel i; exit
				)
			)
			updateViewsListButtons()
		)

		-- MOVE SELECTED DOWN (вид — свободно, в т.ч. в другую группу; заголовок — вся группа)
		on btn_down pressed do (
			local newReal = moveSelectedViews #down
			if newReal.count == 0 do return false
			listViews()
			local selUis = #()
			for r in newReal do (
				local ui = findItem g_visibleIndices r
				if ui > 0 and findItem selUis ui == 0 do append selUis ui
			)
			if selUis.count > 0 do setSelectedUiIndices selUis
			updateViewsListButtons()
		)

		on chk_preserve_mp changed state do (
			updateCopyResBtn()
			-- Событие галки меняет ТОЛЬКО ОДИН элемент — поле Мпикс
			-- (та же логика, что в updateRatioUI, без каскадного вызова).
			txt_out_mp.enabled = not state and chk_override_preset.checked and \
				(if isMultiEdit() then g_multi_ovr_editable else getActiveView() != undefined)
		)

		-- RENDER OUTPUT (настраивает выделенный batch view)
		-- LOCK: при изменении W/H пропорции держит Ratio (Preserve MegaPix не учитывается)
		on chk_ratio changed status do (
			updateRatioUI()
		)

		on chk_snap changed state do (
			g_snap = state
			-- При включении — пристрелять активный вид через единый расчёт
			-- (#wh: пара как есть -> фаза снэпа)
			if state do (
				local src = getFieldSpaceSrc()
				if src != undefined do (
					local t = resolveRes mode:#wh w:src[1] h:src[2] val:src[1] val2:src[2]
					applyViewRes t[1] t[2]
				)
			)
		)

		-- Текстовые поля: пересчёт только по Enter (entered)
		on txt_out_w entered val do (
			-- Мульти-режим, разные базы: второе поле ещё "*" (высоты у видов различаются).
			-- Если Preserve MegaPix или LOCK включён — применяем сразу: вторая сторона
			-- пересчитывается для КАЖДОГО вида (из его пикселей / под его пропорции).
			-- Если оба выключены — применение первой стороны неоднозначно, ждём ввод
			-- второго значения (тогда общие W/H применятся через applyFieldRes -> applyViewRes).
			if isMultiEdit() and txt_out_h.text == "*" then (
				local w = val as integer
				if w == undefined or w <= 0 do return false
				if chk_preserve_mp.checked or chk_ratio.checked do applyMultiFieldRes #w w
				return false
			)
			if getSel() == 0 do return false
			local w = txt_out_w.text as integer
			if w == undefined or w <= 0 do return false
			local src = getFieldSpaceSrc()
			if src == undefined do return false
			-- Единый расчёт: новая ширина + режимы; результат применяем как есть.
			-- Источник — состояние вида (в поле уже НОВОЕ значение W).
			local t = resolveRes mode:#width w:src[1] h:src[2] val:w \
				ratio:(try (txt_out_ratio.text as float) catch undefined) \
				lock:chk_ratio.checked preserve:chk_preserve_mp.checked
			applyViewRes t[1] t[2]
		)
		on txt_out_h entered val do (
			-- Мульти-режим, разные базы: второе поле ещё "*" (ширины у видов различаются).
			-- Если Preserve MegaPix или LOCK включён — применяем сразу: вторая сторона
			-- пересчитывается для КАЖДОГО вида. Если оба выключены — ждём ввод второго
			-- значения (тогда общие W/H применятся через applyFieldRes -> applyViewRes).
			if isMultiEdit() and txt_out_w.text == "*" then (
				local h = val as integer
				if h == undefined or h <= 0 do return false
				if chk_preserve_mp.checked or chk_ratio.checked do applyMultiFieldRes #h h
				return false
			)
			if getSel() == 0 do return false
			local h = txt_out_h.text as integer
			if h == undefined or h <= 0 do return false
			local src = getFieldSpaceSrc()
			if src == undefined do return false
			-- Единый расчёт: новая высота + режимы; результат применяем как есть
			local t = resolveRes mode:#height w:src[1] h:src[2] val:h \
				ratio:(try (txt_out_ratio.text as float) catch undefined) \
				lock:chk_ratio.checked preserve:chk_preserve_mp.checked
			applyViewRes t[1] t[2]
		)
		on txt_out_ratio entered val do (
			if drdwn_re_presets.selection > 1 do return false
			-- Мульти-режим, разные базы: применяем как btn_copy_res (предупреждение о пропорциях)
			if isMultiEdit() and txt_out_w.text == "*" then (
				local ratio = val as float
				if ratio == undefined or ratio <= 0 do return false
				applyMultiFieldRes #ratio ratio
				return false
			)
			if getSel() == 0 do return false
			local ratio = txt_out_ratio.text as float
			if ratio == undefined or ratio <= 0 do return false
			applyRatio ratio
		)
		on txt_out_mp entered val do (
			local mp = val as float
			if mp == undefined or mp <= 0 do return false
			-- Мульти-режим, разные базы: каждому виду своё разрешение
			-- под ЕГО пропорции (как btn_copy_res, без предупреждений —
			-- пропорции сохраняются по построению).
			if isMultiEdit() and txt_out_w.text == "*" then (
				applyMultiFieldRes #mp mp
				return false
			)
			local src = getFieldSpaceSrc()
			if src == undefined do return false
			-- Единый расчёт: цель в мегапикселях, пропорции из состояния вида.
			-- Фаза снэпа внутри resolveRes (KeepMP — точное попадание в цель);
			-- применяем напрямую через applyViewRes, без повторного снэпа.
			local t = resolveRes mode:#mp w:src[1] h:src[2] mpPx:(mp * 1000000.0)
			applyViewRes t[1] t[2]
		)

		on btn_swap pressed do (
			-- Мульти-режим, разные базы: применяем как btn_copy_res (предупреждение о пропорциях)
			if isMultiEdit() and txt_out_w.text == "*" then (
				applyMultiFieldRes #swap 0
				return false
			)
			local oldW = txt_out_w.text as integer
			local oldH = txt_out_h.text as integer
			if oldW == undefined or oldH == undefined or oldW <= 0 or oldH <= 0 do return false
			-- Единый расчёт: swap (стороны меняются местами, пропорция обратная);
			-- снэп — в фазе resolveRes, результат применяем как есть
			local t = resolveRes mode:#swap w:oldW h:oldH
			txt_out_ratio.text = ((oldW as float) / oldH) as string
			updateMpixField()
			chk_ratio.checked = false
			updateRatioUI()
			applyViewRes t[1] t[2]
		)

		on drdwn_re_presets selected idx do (
			-- Мульти-режим, разные базы: применяем как btn_copy_res (предупреждение о пропорциях)
			if isMultiEdit() and txt_out_w.text == "*" then (
				if idx > 1 do (
					local presetRatio = g_presetRatios[idx]
					if presetRatio != undefined and presetRatio > 0 do applyMultiFieldRes #ratio presetRatio
				)
				updateRatioUI()
				return false
			)
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
			-- В мульти-режиме галка — режим отображения: просто пересчитать общую базу
			if isMultiEdit() do ( updateMultiUI(); return false )
			if getSel() == 0 do return false
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined do return false
			local base = getViewBase bv
			showResForBase base[1] base[2]
		)

		-- OVERRIDE PRESET
		on chk_override_preset changed state do (
			if isMultiEdit() then (
				closeBatchWindow()
				for r in getMultiEditIdxs() do (batchRenderMgr.GetView r).overridePreset = state
				updateOverrideUI()
				return false
			)
			if getSel() == 0 do ( updateOverrideUI(); return false )
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined do return false
			closeBatchWindow()
			bv.overridePreset = state
			updateOverrideUI()
		)

		-- RENDER PRESET
		on drdwn_render_preset selected idx do (
			-- Массово: применить пресет (или сброс) всем выделенным видам
			if isMultiEdit() then (
				local idxs = getMultiEditIdxs()
				closeBatchWindow()
				if idx == 1 then (
					for r in idxs do (
						local bv = batchRenderMgr.GetView r
						bv.presetFile = ""
						bv.overridePreset = true
					)
				) else (
					local pf = renderPresetFileForName drdwn_render_preset.items[idx]
					if pf == undefined do return false
					for r in idxs do (
						local bv = batchRenderMgr.GetView r
						bv.presetFile = pf
						bv.overridePreset = false
					)
				)
				updateOverrideUI()
				return false
			)
			if getSel() == 0 do return false
			local bv = batchRenderMgr.GetView (getRealIndex (getSel()))
			if bv == undefined or isGroupView bv do return false
			closeBatchWindow()
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
	rollout roll_global "Global Batch Views Settings" (
		local roll_w = 250
		--------------------------------
		group "Sizes" (
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
			sld_global_res.text = L10N.trMsg "scaleText" args:#(((displayPercent * 100) as integer) as string)
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
				g_roll_batch.listViews()
				if g_roll_batch.getSel() > 0 do (
					g_roll_batch.getViewParams (g_roll_batch.getRealIndex (g_roll_batch.getSel()))
				)
			)
		)

		-- "Запечь" текущий масштабированный размер как новую базу (100%) для всех видов
		fn applyScaleAsNewBase = (
			if abs(g_globalScale - 1.0) < 0.001 do return false
			closeBatchWindow()
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
				g_roll_batch.listViews()
				if g_roll_batch.getSel() > 0 do (
					g_roll_batch.getViewParams (g_roll_batch.getRealIndex (g_roll_batch.getSel()))
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
			local folder = getSavePath caption:(L10N.trMsg "selectOutputFolder")
			if folder == undefined do return false
			-- Переспрашиваем только если текущие папки вывода различаются (кроме текущего вида;
			-- при включённой галке в проверку входят и пути Render Elements): действие нельзя отменить.
			local uniquePaths = #()
			local selReal = if g_roll_batch != undefined and g_roll_batch.getSel() > 0 then g_roll_batch.getRealIndex (g_roll_batch.getSel()) else 0
			for i = 1 to batchRenderMgr.NumViews do (
				local v = batchRenderMgr.GetView i
				if v != undefined and not (isGroupView v) and i != selReal then (
					local p = if v.outputFilename != undefined then getFilenamePath v.outputFilename else ""
					if p != "" and findItem uniquePaths p == 0 do append uniquePaths p
				)
			)
			if chk_update_re.checked then (
				try (
					local rem = maxOps.GetCurRenderElementMgr()
					local num = rem.NumRenderElements()
					if num > 0 do (
						for i = 0 to (num - 1) do (
							local p = getFilenamePath (rem.GetRenderElementFilename i)
							if p != "" and findItem uniquePaths p == 0 do append uniquePaths p
						)
					)
				) catch ()
			)
			if uniquePaths.count > 1 then (
				local uniquePaths_str = ""
				for p in uniquePaths do uniquePaths_str += "   " + p + "\n"
				uniquePaths_str = substring uniquePaths_str 1 (uniquePaths_str.count - 1)

				if not (queryBox (L10N.trMsg "setFolderConfirm" args:#(uniquePaths_str)) title:(L10N.trMsg "titleBatchViews")) do return false
			)
			local count = setOutputFolderForAll folder
			if chk_update_re.checked do setRePathsForAll folder
			if count > 0 and g_roll_batch != undefined then (
				g_roll_batch.listViews()
				if g_roll_batch.getSel() > 0 do (
					g_roll_batch.getViewParams (g_roll_batch.getRealIndex (g_roll_batch.getSel()))
				)
			)
		)

		on btn_update_re pressed do (
			local folder = getSavePath caption:(L10N.trMsg "selectReFolder")
			if folder == undefined do return false
			setRePathsForAll folder
		)

	)


	--) Конец ROLLOUT: GLOBAL
	--------------------------------------------------------------


	--------------------------------------------------------------
	--( ROLLOUT: SCENE STATES

	rollout roll_states "Scene States" (
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

		fn setStatesSel idx = (
			local cnt = lst_states.Items.Count
			if cnt == 0 do return -1
			lst_states.SelectedIndex = if idx > 0 then (amin idx cnt) - 1 else -1
		)

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
		fn stateRestore = (
			if getStatesSel() <= 0 do ( messageBox (L10N.trMsg "selectStateToApply") title:(L10N.trMsg "titleApplyState"); return false )
			local name = lst_states.SelectedItem as string
			try (
				local ssp = sceneStateMgr.GetParts name
				sceneStateMgr.Restore name ssp
			) catch (
				messageBox (L10N.trMsg "cantRestoreState" args:#(getCurrentException())) title:(L10N.trMsg "titleApplyState")
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
			stateRestore()
		)

		on btn_states_info pressed do (
			messageBox (L10N.trMsg "statesInfo") title:(L10N.trMsg "titleManageStates")
		)

		on btn_parts_all pressed do ( selectAllParts() )
		on btn_parts_none pressed do ( clearParts() )

		on btn_states_new pressed do (
			local name
			if getStatesSel() > 0 then (
				name = nextStateName (lst_states.SelectedItem as string)
			) else (
				name = trimLeft (trimRight txt_states_new.text)
				if name == "" do ( messageBox (L10N.trMsg "enterNewStateName") title:(L10N.trMsg "titleNewState"); return false )
				if findItem (stateNames()) name != 0 do ( messageBox (L10N.trMsg "stateExists") title:(L10N.trMsg "titleNewState"); return false )
			)
			local parts = selectedParts()
			if parts.isEmpty do ( messageBox (L10N.trMsg "selectPartToCapture") title:(L10N.trMsg "titleNewState"); return false )
			try (
				if not (sceneStateMgr.Capture name parts) then (
					messageBox (L10N.trMsg "cantCreateState") title:(L10N.trMsg "titleNewState")
					return false
				)
			) catch (
				messageBox (L10N.trMsg "cantCreateStateEx" args:#(getCurrentException())) title:(L10N.trMsg "titleNewState")
				return false
			)
			refreshStates()
			local idx = findItem (stateNames()) name
			if idx > 0 do setStatesSel idx
			if g_roll_batch != undefined do g_roll_batch.refreshStatesList()
		)

		on btn_states_update pressed do (
			if getStatesSel() <= 0 do ( messageBox (L10N.trMsg "selectStateToOverwrite") title:(L10N.trMsg "titleUpdateState"); return false )
			local name = lst_states.SelectedItem as string
			if not (queryBox (L10N.trMsg "overwriteState" args:#(name)) title:(L10N.trMsg "titleUpdateState")) do return false
			local parts = selectedParts()
			if parts.isEmpty do ( messageBox (L10N.trMsg "selectPartToCapture") title:(L10N.trMsg "titleUpdateState"); return false )
			try (
				sceneStateMgr.Delete name
				if not (sceneStateMgr.Capture name parts) then (
					messageBox (L10N.trMsg "cantUpdateState") title:(L10N.trMsg "titleUpdateState")
					return false
				)
			) catch (
				messageBox (L10N.trMsg "cantUpdateStateEx" args:#(getCurrentException())) title:(L10N.trMsg "titleUpdateState")
				return false
			)
			if g_roll_batch != undefined do g_roll_batch.refreshStatesList()
		)

		-- RENAME по событию Enter в поле имени (без кнопки)
		on txt_states_new entered val do (
			if getStatesSel() <= 0 do return false
			local oldName = lst_states.SelectedItem as string
			local newName = trimLeft (trimRight val)
			if newName == "" do ( messageBox (L10N.trMsg "enterNewName") title:(L10N.trMsg "titleRenameState"); return false )
			if newName == oldName do return false
			if findItem (stateNames()) newName != 0 do ( messageBox (L10N.trMsg "stateExists") title:(L10N.trMsg "titleRenameState"); return false )
			try (
				sceneStateMgr.Rename oldName newName
			) catch (
				messageBox (L10N.trMsg "cantRenameState" args:#(getCurrentException())) title:(L10N.trMsg "titleRenameState")
				return false
			)
			refreshStates()
			local idx = findItem (stateNames()) newName
			if idx > 0 do setStatesSel idx
			if g_roll_batch != undefined do g_roll_batch.refreshStatesList()
		)

		on btn_states_del pressed do (
			if getStatesSel() <= 0 do ( messageBox (L10N.trMsg "selectStateToDelete") title:(L10N.trMsg "titleDeleteState"); return false )
			local name = lst_states.SelectedItem as string
			if not (queryBox (L10N.trMsg "deleteStateQuery" args:#(name)) title:(L10N.trMsg "titleDeleteState")) do return false
			try (
				sceneStateMgr.Delete name
			) catch (
				messageBox (L10N.trMsg "cantDeleteState" args:#(getCurrentException())) title:(L10N.trMsg "titleDeleteState")
				return false
			)
			refreshStates()
			if g_roll_batch != undefined do g_roll_batch.refreshStatesList()
		)
	)
	--) Конец ROLLOUT: MANAGE SCENE STATES
	--------------------------------------------------------------


	--------------------------------------------------------------
	--( ROLLOUT: LANGUAGE & INFO

	rollout roll_lang "Language & Info" (
		local roll_w = 250
		--------------------------------
		group "Language" (
			dropdownlist drp_lang items:#() width:(roll_w - 40) offset:[0,5] visible:false \
				tooltip:"Switch interface language"
			hyperLink hlnkLangEngine "Download language Engine" \
				address:"https://github.com/Pankovea/Pankovea_MaxScriptsTools/tree/main/usermacros/#PankovScripts-L10N.ms" \
				align:#left offset:[0,-33]
			hyperLink hlnkLangRU "Download Russian Translate" \
				address:"https://github.com/Pankovea/Pankovea_MaxScriptsTools/tree/main/usermacros/#PankovScripts-BatchViewsManager.ru.ms" \
				align:#left offset:[0,-7]
		)

		group "About" (
			label lbl_version "" align:#left offset:[0,5]
			hyperLink lbl_repo "https://github.com/Pankovea" address:"https://github.com/Pankovea" align:#left \
				offset:[0,3]
		)
		--------------------------------

		on roll_lang open do (
			-- язык интерфейса: показываем выбор только если есть другие языки
			if L10N.codes.count > 1 then (
				drp_lang.visible = true
				hlnkLangEngine.visible = false
				hlnkLangRU.visible = false
				drp_lang.items = for c in L10N.codes collect (L10N.langLabel c)
				local langIdx = findItem L10N.codes L10N.lang
				if langIdx == 0 then langIdx = 1
				drp_lang.selection = langIdx
			) else (
				drp_lang.visible = false
				hlnkLangRU.visible = true
				hlnkLangEngine.visible = (classof L10N) == _L10N_Fallback
			)
			lbl_version.text = L10N.trMsg "version" + ": " + g_version
		)

		on roll_lang close do ( saveFloaterState() )
		on roll_lang rolledUp state do ( accordion roll_lang state )

		on drp_lang selected idx do (
			if classof L10N == _L10N_Fallback then return false
			local code = L10N.codes[idx]
			if code == undefined do return false
			if code == L10N.lang do return false
			setINISetting (getmaxinifile()) "CamManager" "Language" code
			L10N.setLang code
			-- Применить перевод на месте, без пересоздания окна:
			-- хендлеры свитков не видят функции, объявленные ПОСЛЕ свитков,
			-- поэтому showUI() здесь вызывать нельзя.
			for r in #(g_roll_cams, g_roll_batch, g_roll_global, g_roll_states, g_roll_lang) do (
				try ( L10N.applyRollout r ) catch ()
			)
			try ( g_roll_batch.updateCopyResBtn() ) catch ()
			try ( g_floater.title = L10N.trMsg "appTitle" ) catch ()
			try ( g_roll_global.updateScaleDisplay g_globalScale ) catch ()
			try ( lbl_version.text = L10N.trMsg "version" + ": " + g_version ) catch ()
		)
	)

	--) Конец ROLLOUT: LANGUAGE & INFO
	--------------------------------------------------------------


	--------------------------------------------------------------
	-- TOOL MAIN UI
	fn getLangCode = (
		local code = getINISetting (getmaxinifile()) "CamManager" "Language"
		if code == "" or findItem L10N.codes code == 0 then "en" else code
	)

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
			g_roll_lang   = roll_lang

			L10N.setLang (getLangCode())

			local iniPath = getmaxinifile()
			local posStr = getINISetting iniPath "CamManager" "Position"
			local sizeStr = getINISetting iniPath "CamManager" "WindowsSize"
			if posStr != "" and sizeStr != "" then (
				local p = execute posStr
				local s = execute sizeStr
				g_floater = newRolloutFloater (L10N.trMsg "appTitle") s[1] s[2] p[1] p[2] lockHeight:false lockWidth:true
			) else (
				g_floater = newRolloutFloater (L10N.trMsg "appTitle") g_dialog_width 663 50 50 lockHeight:false lockWidth:true
			)
			local rolloutOpened = getINISetting iniPath "CamManager" "RolloutOpened"
			if not (hasBatchViews()) then rolloutOpened = "Cams"
			if rolloutOpened != "Batch" and rolloutOpened != "Global" and rolloutOpened != "States" and rolloutOpened != "Lang" then rolloutOpened = "Cams"
			local snapStr = getINISetting iniPath "CamManager" "Snap"
			try ( if snapStr != "" then g_snap = (snapStr as BooleanClass) ) catch ()
			local ovStr = getINISetting iniPath "CamManager" "OnlyVisible"
			try ( if ovStr != "" then g_only_visible = (ovStr as BooleanClass) ) catch ()
			addRollout g_roll_cams g_floater rolledup:(rolloutOpened != "Cams")
			addRollout g_roll_batch g_floater rolledUp:(rolloutOpened != "Batch")
			addRollout g_roll_global g_floater rolledUp:(rolloutOpened != "Global")
			addRollout g_roll_states g_floater rolledUp:(rolloutOpened != "States")
			addRollout g_roll_lang g_floater rolledUp:(rolloutOpened != "Lang")
			g_roll_cams.open   = (rolloutOpened == "Cams")
			g_roll_batch.open  = (rolloutOpened == "Batch")
			g_roll_global.open = (rolloutOpened == "Global")
			g_roll_states.open = (rolloutOpened == "States")
			g_roll_lang.open   = (rolloutOpened == "Lang")
			g_last_opened_tab = rolloutOpened

			L10N.applyRollout g_roll_cams
			L10N.applyRollout g_roll_batch
			L10N.applyRollout g_roll_global
			L10N.applyRollout g_roll_states
			L10N.applyRollout g_roll_lang
			try ( g_roll_batch.updateCopyResBtn() ) catch ()

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
