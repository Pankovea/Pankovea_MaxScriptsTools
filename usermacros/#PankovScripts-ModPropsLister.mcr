/* #PankovScripts - ModPropsLister

Динамический мульти-редактор параметров для выделенных НЕ-ИНСТАНС объектов.
Сравнивает и редактирует общие свойства базового объекта и общих модификаторов
(только верхний экземпляр каждого класса в стеке).

UI:
  Rollout "Modifiers" — список: модификаторы сверху (порядок стека, верхний первым),
      baseobject ПОСЛЕДНИМ внизу; переключатель On (вкл/выкл модификатора),
      кнопка Delete.
  Rollout "Properties" — динамический свиток контролов выбранного элемента
      (генерируется rolloutCreator'ом на лету, пересоздаётся при смене выбора).
  Rollout "About" — инфо (сворачивается при выборе элемента, всегда последний).

Поведение:
  - Запуск безусловный: макрос всегда активен (без on isEnabled) и открывает окно
    при любом выделении. Состояние показывается прямо в интерфейсе:
    "No selection." / "Select 2+ non-instance objects." / "No common modifiers...".
  - Различающиеся значения — контрол в неактивном (enabled:false) состоянии
    с кнопкой «Сделать общим» ("Unify" у float/boolean/color, "Make" у point3).
    Контекстное меню: Maximum / Average / Median / Minimum / Most common.
    После применения значение выравнивается, контрол активируется, кнопка скрывается.
  - Положение и размер окна сохраняются в INI (секция "ModPropsLister" в max.ini)
    и восстанавливаются при открытии.
  - Автовысота окна: сумма высот открытых свитков, не больше размера экрана.
  - Автообновление: при изменении выделения / добавлении / удалении модификаторов
    интерфейс пересобирается через колбэки. При снятии выделения интерфейс
    очищается (старые данные не показываются), высота окна пересчитывается.

Поддерживаемые типы свойств: float, integer, boolean, color, point3.

======================================================================
АРХИТЕКТУРА — важные моменты, которые нельзя делать иначе:
======================================================================
1. ОБЛАСТЬ ВИДИМОСТИ. Динамический rollout (codeStr) и статические rollouts
   выполняются в отдельных scope-контекстах и НЕ видят macro-локальные fn.
   Все функции, вызываемые из обработчиков rollout'ов, codeStr и callbacks,
   объявлены global (см. блок "global ORM_*"). Статические rollouts доступны
   из global-функций только через глобальные псевдонимы g_orm_rollMods /
   g_orm_rollAbout (паттерн BatchViewsManager). rcmenu rmc_common тоже global
   (вызывается из global-функции ORM_onMakeCommon через popUpMenu без pos: —
   меню появляется у курсора).

2. LOOKUP — НЕ ХЕШ. g_orm_propLookup — линейный массив кортежей
   #(key, modIdx, propNameStr, prefix), поиск через ORM_lookupFind.
   Хеш-доступ arr["key"]=... к глобальному #() в MAXScript НЕ работает
   ("array index must be positive number") — не менять на hash.

3. codeStr БЕЗ @...@. Вложенные @ ломают парсинг ("Call needs function or
   class"). Имена/значения подставляются конкатенацией строк.

4. УДАЛЕНИЕ ДИНАМИЧЕСКОГО ROLLOUT. destroyDialog НЕ убирает rollout из
   floater'а — накапливаются копии. Обязательно removeRollout + destroyDialog.
   Пересоздание — только при смене выбора (g_orm_lastSelKey).

5. МОДИФИКАТОРЫ — ПО КЛАССУ, НЕ ПО ИНДЕКСУ. ORM_resolveTarget ищет верхний
   модификатор нужного класса (g_orm_modClasses[modIdx]) на каждом объекте.
   Стековый индекс (topmostIdx) верен только для первого объекта и не
   переживает изменение порядка модификаторов на других объектах.

6. ЖИВОЕ СОСТОЯНИЕ enabled. Кнопку On читаем с живого объекта
   (ORM_getLiveEnabled), а НЕ из кэшированного modDataList[..].enabled.

7. CALLBACKS.
   Все колбэки идут через ORM_cbRefresh с флагом g_orm_refreshing (защита от
   бесконечной рекурсии). Регистрация с id:#ModPropsLister (removeScripts перед
   добавлением — иначе дубли). При ошибке внутри колбэка стек печатается через
   ErrorDump.ms (scripts\ErrorDump.ms, подключается fileIn "ErrorDump.ms",
   форматтер FmtError stackLevels:N), и колбэки САМОУДАЛЯЮТСЯ
   (ORM_unregisterCallbacks), чтобы битый колбэк не спамил ошибками вечно.

8. АВТОВЫСОТА ОКНА. newRolloutFloater создаётся с lockHeight:false lockWidth:true
   (иначе размер .size игнорируется). Высота = заголовки + сумма высот открытых
   свитков, DPI-масштаб ((dotNetClass "System.Drawing.Graphics").fromHwnd 0).dpiX/100,
   лимит sysInfo.DesktopSize (свойства sysInfo.screenSize НЕТ!), минимум 200.
   Пересчёт — по on <rollout> rolledUp (не open/close!) для каждого свитка.

9. СВОРАЧИВАНИЕ About. g_orm_rollAbout.open = false. Функции cw_closeRollout
   НЕ существует — молча проглатывалась catch'ем.

10. ИНИЦИАЛИЗАЦИЯ ОКНА. Позиция/размер читаются getINISetting из секции
    "ModPropsLister", парсятся execute() и передаются в newRolloutFloater.
    Сохранение — setINISetting в обработчике on <rollout> close.

11. ОЧИСТКА ПРИ СНЯТИИ ВЫДЕЛЕНИЯ. При <2 валидных объектов ORM_refreshUI
    вызывает ORM_clearUI() (старые данные не показываем) + ORM_updateFloaterHeight().
    Запоминание объектов «с прошлого раза» не применяется — по требованию.

12. УСТАРЕВШИЕ СВОЙСТВА. edgeChamferType / edgeChamferQuadIntersections (Edit Poly)
    отфильтрованы в ORM_collectSupportedProps, иначе 3ds Max пишет предупреждения
    в Listener.
*/

macroScript ModPropsLister
	category:"#PankovScripts"
	ButtonText:"ModProps Lister"
	tooltip:"ModProps Lister\n\nMulti-editor for parameters\nof selected non-instance objects.\n\nCompares common properties\nof the base object and modifiers.\n\nDiffering values can be\nunified via the Unify button."
	icon:#("brush_preset_manager", 1)
	autoUndoEnabled:false
(
local APP_TITLE = "ModProps Lister"
local VERSION = "1.0.0 (2026-09-05)"

local lbl_ver_caption = APP_TITLE + " " + VERSION


-- ======================================================================
-- СТРУКТУРЫ ДАННЫХ
-- ======================================================================

struct ORM_PropInfo (
	name,           -- #propertyName (Name)
	value,          -- текущее значение (из первого объекта)
	allSame,        -- true если одинаково у ВСЕХ объектов
	ptype           -- #float | #integer | #boolean | #color | #point3
)

struct ORM_ModData (
	modClass,       -- класс модификатора (Bend, Edit_Poly, ...)
	displayName,    -- строковое имя для заголовка свитка
	props,          -- #(ORM_PropInfo)
	topmostIdx,     -- индекс верхнего экземпляра в стеке первого объекта
	lowerCount,     -- число нижних дубликатов этого класса в первом объекте
	enabled         -- bool: включён ли модификатор (первый объект)
)

struct ORM_BaseObjData (
	objClass,       -- класс базового объекта (Box, Sphere, ...)
	props           -- #(ORM_PropInfo)
)

struct ORM_Result (
	uniqueObjs,     -- #(node) — уникальные объекты (>= 2)
	modDataList,    -- #(ORM_ModData) — общие модификаторы
	baseObjData,    -- ORM_BaseObjData | undefined
	totalSelCount   -- общее число выделенных
)


-- ======================================================================
-- ГЛОБАЛЬНОЕ СОСТОЯНИЕ
-- ======================================================================

global g_orm_result         = undefined
global g_orm_uniqueObjs     = #()
global g_orm_modClasses     = #()
global g_orm_floater        = undefined
global g_orm_rlProps        = undefined  -- динамический rollout свойств
-- Глобальные псевдонимы статических rollout'ов (паттерн доступа из global-функций)
global g_orm_rollMods       = undefined
global g_orm_rollAbout      = undefined

-- Lookup: #(#(key, modIdx, propNameStr, prefix), ...)
global g_orm_propLookup     = #()
-- Выбранный элемент: #(type, modDataIdx) ; тип "base" | "mod" (пустой = нет выбора)
global g_orm_selInfo        = #()
-- Соответствие строк listbox -> #("base"|"mod", modDataIdx)
global g_orm_listItems      = #()
-- Контекст кнопки «Сделать общим» (lookupKey), читается из rcmenu
global g_orm_ctxKey         = ""
-- Признак того, что rollout свойств уже построен для текущего выбора (пп. 4)
global g_orm_lastSelKey     = ""
-- Зарегистрированы ли callbacks (пп. 3)
global g_orm_callbacksOn    = false
-- Защита от рекурсии колбэков (пп. 3)
global g_orm_refreshing     = false


-- Функции, вызываемые из статических rollout-обработчиков и codeStr
-- (динамический rollout и static rollout живут в отдельных scope-контекстах,
--  поэтому они должны быть глобальными, а не локальными fn макроса)
global ORM_getPropType
global ORM_getTopmostPerClass
global ORM_countLowerDuplicates
global ORM_collectSupportedProps
global ORM_analyzeSelection
global ORM_resolveTarget
global ORM_applyProperty
global ORM_deleteModifier
global ORM_toggleModifier
global ORM_collectValues
global ORM_isNumeric
global ORM_avgValues
global ORM_medianValues
global ORM_modeValues
global ORM_commonValue
global ORM_propChanged
global ORM_propColorChanged
global ORM_propPoint3Changed
global ORM_lookupFind
global ORM_ctrlByName
global ORM_validTargets
global ORM_getLiveEnabled
global ORM_onListSelect
global ORM_toggleSelected
global ORM_setToggleUI
global ORM_onMakeCommon
global ORM_applyCommon
global ORM_enableAfterCommon
global ORM_onDeleteMod
global ORM_rebuildPropsRollout
global ORM_addPropControls
global ORM_refreshUI
global ORM_clearUI
global ORM_rebuildNow
global ORM_cbRefresh
global ORM_registerCallbacks
global ORM_unregisterCallbacks
global ORM_updateFloaterHeight
global ORM_saveFloaterState
global ORM_showUI
global ORM_closeDialog


-- ======================================================================
-- LAYER 1: ANALYSIS
-- ======================================================================

fn ORM_getPropType val =
(
	case (classOf val) of
	(
		Float:         #float
		Double:        #float
		Integer:       #integer
		BooleanClass:  #boolean
		Color:         #color
		Point3:        #point3
		default:       undefined
	)
)

fn ORM_getTopmostPerClass obj =
(
	local result = #()
	for i = 1 to obj.modifiers.count do
	(
		local m = obj.modifiers[i]
		local c = classOf m
		local found = false
		for item in result do
			if item[1] == c do ( found = true; exit )
		if not found do
			append result #(c, m, i)
	)
	result
)

fn ORM_countLowerDuplicates obj targetClass topmostIdx =
(
	local cnt = 0
	for i = (topmostIdx + 1) to obj.modifiers.count do
		if classOf obj.modifiers[i] == targetClass do cnt += 1
	cnt
)

fn ORM_collectSupportedProps obj modOrBase =
(
	-- Устаревшие свойства Edit Poly, при чтении которых 3ds Max пишет предупреждения
	-- в Listener («is obsolete ... Use ... instead»). Исключаем их, чтобы не спамить.
	local obsoletePropNames = #("edgeChamferType", "edgeChamferQuadIntersections")

	local props = #()
	local pnames = getPropNames modOrBase
	for pname in pnames do
	(
		local pnameStr = pname as string
		if pnameStr[1] == "_" do continue
		if pnameStr == "name" or pnameStr == "enabled" \
			or pnameStr == "enabledInViews" or pnameStr == "enabledInRenders" do continue
		local isObsolete = false
		for ob in obsoletePropNames do
			if pnameStr == ob do ( isObsolete = true; exit )
		if isObsolete do continue
		local val = undefined
		try ( val = getProperty modOrBase pname ) catch ()
		if val == undefined do continue
		local pt = ORM_getPropType val
		if pt != undefined do
			append props (ORM_PropInfo name:pname value:val allSame:true ptype:pt)
	)
	props
)

fn ORM_analyzeSelection sel =
(
	local uniqueObjs = #()
	for obj in sel do
	(
		if not (isValidNode obj) do continue
		local sc = superClassOf obj
		if sc != GeometryClass and sc != Shape do continue
		local isTrueInstance = false
		for u in uniqueObjs do
		(
			if classOf u.baseObject == classOf obj.baseObject \
				and u.baseObject == obj.baseObject \
				do ( isTrueInstance = true; exit )
		)
		if not isTrueInstance do append uniqueObjs obj
	)

	if uniqueObjs.count < 2 do return false

	local normalizedStacks = #()
	for obj in uniqueObjs do
		append normalizedStacks (ORM_getTopmostPerClass obj)

	local allClasses = #()
	for stack in normalizedStacks do
		for item in stack do
		(
			local c = item[1]
			local found = false
			for ac in allClasses do
				if ac == c do ( found = true; exit )
			if not found do append allClasses c
		)

	local commonClasses = #()
	for c in allClasses do
	(
		local isCommon = true
		for stack in normalizedStacks do
		(
			local found = false
			for item in stack do
				if item[1] == c do ( found = true; exit )
			if not found do ( isCommon = false; exit )
		)
		if isCommon do append commonClasses c
	)

	local modDataList = #()
	for c in commonClasses do
	(
		local topmostMod = undefined
		local topmostIdx = 0
		for item in normalizedStacks[1] do
			if item[1] == c do ( topmostMod = item[2]; topmostIdx = item[3]; exit )
		if topmostMod == undefined do continue

		local lowerCount = ORM_countLowerDuplicates uniqueObjs[1] c topmostIdx
		local props = ORM_collectSupportedProps uniqueObjs[1] topmostMod
		if props.count == 0 do continue

		for pi = 1 to props.count do
		(
			local allSame = true
			for ui = 1 to uniqueObjs.count do
			(
				local otherMod = undefined
				for item in normalizedStacks[ui] do
					if item[1] == c do ( otherMod = item[2]; exit )
				if otherMod == undefined do ( allSame = false; exit )
				local otherVal = undefined
				try ( otherVal = getProperty otherMod props[pi].name ) catch ()
				if otherVal == undefined \
					or (classOf props[pi].value) != (classOf otherVal) \
					or props[pi].value != otherVal \
					do ( allSame = false; exit )
			)
			props[pi].allSame = allSame
		)

		local en = undefined
		try ( en = topmostMod.enabled ) catch ( en = false )

		append modDataList (ORM_ModData \
			modClass:c \
			displayName:(c as string) \
			props:props \
			topmostIdx:topmostIdx \
			lowerCount:lowerCount \
			enabled:en)
	)

	local baseObjData = undefined
	local firstBaseClass = classOf uniqueObjs[1].baseObject
	local allSameBaseClass = true
	for ui = 2 to uniqueObjs.count do
		if classOf uniqueObjs[ui].baseObject != firstBaseClass \
			do ( allSameBaseClass = false; exit )

	if allSameBaseClass do
	(
		local props = ORM_collectSupportedProps uniqueObjs[1] uniqueObjs[1].baseObject
		if props.count > 0 do
		(
			for pi = 1 to props.count do
			(
				local allSame = true
				for ui = 2 to uniqueObjs.count do
				(
					local otherVal = undefined
					try ( otherVal = getProperty uniqueObjs[ui].baseObject props[pi].name ) catch ()
					if otherVal == undefined \
						or props[pi].value != otherVal \
						do ( allSame = false; exit )
				)
				props[pi].allSame = allSame
			)
			baseObjData = ORM_BaseObjData objClass:firstBaseClass props:props
		)
	)

	ORM_Result \
		uniqueObjs:uniqueObjs \
		modDataList:modDataList \
		baseObjData:baseObjData \
		totalSelCount:sel.count
)


-- ======================================================================
-- LAYER 3: APPLY
-- ======================================================================

-- Находит target (baseObject или верхний модификатор нужного класса) на объекте
--   modIdx: 0 = базовый объект; 1..N = индекс в g_orm_modClasses (класс модификатора)
--   Класс-ориентированный поиск устойчив к изменению порядка модификаторов (пп. 3)
fn ORM_resolveTarget obj modIdx =
(
	if modIdx == 0 then return obj.baseObject
	local cls
	try ( cls = g_orm_modClasses[modIdx] ) catch ( return undefined )
	if cls == undefined do return undefined
	for i = 1 to obj.modifiers.count do
		if classOf obj.modifiers[i] == cls do return obj.modifiers[i]
	undefined
)

-- Все запомненные объекты ещё существуют? (пп. 3)
fn ORM_validTargets =
(
	for obj in g_orm_uniqueObjs do
		if not (isValidNode obj) do return false
	true
)

-- Текущее состояние enable верхнего модификатора данного модификатора на первом объекте (живое, пп. 3)
fn ORM_getLiveEnabled modIdx =
(
	local obj = g_orm_uniqueObjs[1]
	if obj == undefined do return false
	local t = ORM_resolveTarget obj modIdx
	if t == undefined or not (isProperty t "enabled") do return false
	try ( t.enabled ) catch ( false )
)

fn ORM_applyProperty modIdx propNameStr value =
(
	if not (ORM_validTargets()) do ( ORM_refreshUI quiet:true; return false )
	for obj in g_orm_uniqueObjs do
	(
		if not (isValidNode obj) do continue
		local target
		try ( target = ORM_resolveTarget obj modIdx ) catch ( target = undefined )
		if target != undefined do
			try ( setProperty target propNameStr value ) catch ()
	)
)

fn ORM_deleteModifier modClass =
(
	if not (ORM_validTargets()) do ( ORM_refreshUI quiet:true; return false )
	undo "ModPropsLister Delete Modifier" on
	(
		for obj in g_orm_uniqueObjs do
		(
			if not (isValidNode obj) do continue
			for i = 1 to obj.modifiers.count do
				if classOf obj.modifiers[i] == modClass do
				(
					deleteModifier obj i
					exit
				)
		)
	)
)

-- Вкл/выкл верхний экземпляр модификатора данного класса на всех объектах
fn ORM_toggleModifier modClass state =
(
	if not (ORM_validTargets()) do ( ORM_refreshUI quiet:true; return false )
	local applied = false
	for obj in g_orm_uniqueObjs do
	(
		if not (isValidNode obj) do continue
		for i = 1 to obj.modifiers.count do
			if classOf obj.modifiers[i] == modClass do
			(
				try ( obj.modifiers[i].enabled = state ) catch ()
				applied = true
				exit
			)
	)
	applied
)


-- ======================================================================
-- LAYER 3: STATISTICS (для «Сделать общим»)
-- ======================================================================

-- Собирает значения свойства со всех объектов
fn ORM_collectValues modIdx propName =
(
	local vals = #()
	for obj in g_orm_uniqueObjs do
	(
		if not (isValidNode obj) do continue
		local target
		try ( target = ORM_resolveTarget obj modIdx ) catch ( target = undefined )
		if target != undefined do
		(
			try ( append vals (getProperty target propName) ) catch ()
		)
	)
	vals
)

-- Числовой ли тип
fn ORM_isNumeric v = ( classOf v == Integer or classOf v == Float or classOf v == Double )

-- Среднее (работает для float/integer/point3/color через арифметику)
fn ORM_avgValues vals =
(
	if vals.count == 0 do return undefined
	local acc = if ORM_isNumeric vals[1] then 0 else (vals[1] * 0)
	for v in vals do acc = acc + v
	acc / vals.count
)

-- Медиана (только для чисел)
fn ORM_medianValues vals =
(
	if vals.count == 0 do return undefined
	local nums = for v in vals collect (v as float)
	sort nums
	local n = nums.count
	if mod n 2 == 1 then nums[(n + 1) / 2]
	else (nums[n / 2] + nums[n / 2 + 1]) / 2.0
)

-- Самое частое значение (по строковому представлению)
fn ORM_modeValues vals =
(
	if vals.count == 0 do return undefined
	local best = vals[1]
	local bestCnt = -1
	for a in vals do
	(
		local cnt = 0
		for b in vals do
			if (a as string) == (b as string) do cnt += 1
		if cnt > bestCnt do ( best = a; bestCnt = cnt )
	)
	best
)

-- Вычисляет «общее» значение по режиму (результат приводится к типу источника)
fn ORM_commonValue modIdx propName mode =
(
	local vals = ORM_collectValues modIdx propName
	if vals.count == 0 do return undefined

	local result = case mode of
	(
		#max: ( if ORM_isNumeric vals[1] then (amax (for v in vals collect (v as float))) else ORM_avgValues vals )
		#min: ( if ORM_isNumeric vals[1] then (amin (for v in vals collect (v as float))) else ORM_avgValues vals )
		#avg: ( ORM_avgValues vals )
		#median: ( if ORM_isNumeric vals[1] then ORM_medianValues vals else ORM_avgValues vals )
		#mode: ( ORM_modeValues vals )
		default: undefined
	)
	if result == undefined do return undefined

	-- Приводим результат к типу исходного значения
	local srcType = classOf vals[1]
	case srcType of
	(
		Integer: ( return (result as integer) )
		Float:   ( return (result as float) )
		Double:  ( return (result as double) )
		Color:   ( return (color (result.r) (result.g) (result.b)) )
		Point3:  ( return (result as point3) )
		default: ( return result )
	)
	undefined
)


-- ======================================================================
-- LAYER 4: CALLBACKS (единый обработчик через lookup-таблицу)
-- ======================================================================

fn ORM_lookupFind propNameStr =
(
	for item in g_orm_propLookup do
		if item[1] == propNameStr do return item
	undefined
)

fn ORM_propChanged propNameStr val =
(
	local lookup = ORM_lookupFind propNameStr
	if lookup == undefined do return false
	local modIdx    = lookup[2]
	local realName  = lookup[3]
	local value = val
	if classOf val == String do
		try ( value = val as float ) catch ()
	ORM_applyProperty modIdx realName value
	true
)

fn ORM_propColorChanged propNameStr val =
(
	local lookup = ORM_lookupFind propNameStr
	if lookup == undefined do return false
	ORM_applyProperty lookup[2] lookup[3] val
	true
)

fn ORM_propPoint3Changed propNameStr component val =
(
	local lookup = ORM_lookupFind propNameStr
	if lookup == undefined do return false
	local modIdx   = lookup[2]
	local realName = lookup[3]

	local currentVal = undefined
	local target = ORM_resolveTarget g_orm_uniqueObjs[1] modIdx
	if target != undefined do
		try ( currentVal = getProperty target realName ) catch ()
	if currentVal == undefined do currentVal = [0,0,0]

	case component of
	(
		"x": currentVal.x = val as float
		"y": currentVal.y = val as float
		"z": currentVal.z = val as float
	)
	ORM_applyProperty modIdx realName currentVal
	true
)

-- Удаление модификатора
fn ORM_onDeleteMod idx =
(
	if idx < 1 or idx > g_orm_modClasses.count do return false
	ORM_deleteModifier g_orm_modClasses[idx]
	true
)

-- Активировать контрол и скрыть кнопку «Сделать общим» после применения
fn ORM_ctrlByName rl nameStr =
(
	if rl == undefined do return undefined
	for c in rl.controls do
		if (c.name as string) == nameStr do return c
	undefined
)

fn ORM_enableAfterCommon prefix propName =
(
	local rl = g_orm_rlProps
	if rl == undefined do return undefined
	local main = prefix + propName
	local c = ORM_ctrlByName rl main
	if c != undefined do try ( c.enabled = true ) catch ()
	local b = ORM_ctrlByName rl (main + "_mk")
	if b != undefined do try ( b.visible = false ) catch ()
	for comp in #("x", "y", "z") do
	(
		local cc = ORM_ctrlByName rl (main + "_" + comp)
		if cc != undefined do try ( cc.enabled = true ) catch ()
	)
)

-- Применяет вычисленное «общее» значение (по выбранному из контекстного меню)
fn ORM_applyCommon lookupKey mode =
(
	local lookup = ORM_lookupFind lookupKey
	if lookup == undefined do return false
	local modIdx   = lookup[2]
	local realName = lookup[3]
	local prefix   = lookup[4]

	local val = ORM_commonValue modIdx realName mode
	if val == undefined do return false

	ORM_applyProperty modIdx realName val

	-- Отмечаем свойство как «одинаковое» в данных, чтобы UI не предлагал снова
	local updated = false
	if modIdx == 0 and g_orm_result.baseObjData != undefined then
	(
		for p in g_orm_result.baseObjData.props do
			if (p.name as string) == realName do ( p.allSame = true; p.value = val; updated = true; exit )
	)
	else if modIdx > 0 then
	(
		for md in g_orm_result.modDataList do
			for p in md.props do
				if (p.name as string) == realName do ( p.allSame = true; p.value = val; updated = true; exit )
	)

	-- Активируем контрол и прячем кнопку «Сделать общим»
	ORM_enableAfterCommon prefix realName

	true
)

-- Открывает контекстное меню «Сделать общим» для конкретного свойства
fn ORM_onMakeCommon lookupKey =
(
	g_orm_ctxKey = lookupKey
	popUpMenu rmc_common
	true
)


-- ======================================================================
-- КОНТЕКСТНОЕ МЕНЮ «СДЕЛАТЬ ОБЩИМ» (rcmenu на уровне макроса)
-- rmc_common объявлен global, т.к. вызывается из global-функции ORM_onMakeCommon
-- (global-функции не видят макро-локальные переменные без явного объявления)
-- ======================================================================

global rmc_common

rcmenu rmc_common (
	menuItem cc_max "Maximum"
	menuItem cc_avg "Average"
	menuItem cc_med "Median"
	menuItem cc_min "Minimum"
	menuItem cc_mode "Most common"

	on cc_max  picked do ORM_applyCommon g_orm_ctxKey #max
	on cc_avg  picked do ORM_applyCommon g_orm_ctxKey #avg
	on cc_med  picked do ORM_applyCommon g_orm_ctxKey #median
	on cc_min  picked do ORM_applyCommon g_orm_ctxKey #min
	on cc_mode picked do ORM_applyCommon g_orm_ctxKey #mode
)


-- ======================================================================
-- UI: ВЫБОР ЭЛЕМЕНТА СПИСКА / REBUILD
-- ======================================================================

-- Синхронизация кнопки On: состояние (checked) + иконка (caption).
-- Вызывается везде, где меняется checked, чтобы интерфейс не расходился
-- с реальным состоянием модификатора.
fn ORM_setToggleUI state =
(
	if g_orm_rollMods == undefined do return false
	g_orm_rollMods.btn_toggle.checked = state
	g_orm_rollMods.btn_toggle.caption = if state then "👁️" else "👁️‍🗨️"
	true
)

fn ORM_onListSelect idx =
(
	local info = g_orm_listItems[idx]
	if info == undefined do return false
	g_orm_selInfo = info
	ORM_rebuildPropsRollout()
	-- Кнопка On активна ТОЛЬКО для модификатора, для baseobject — неактивна (пп. 2)
	if info[1] == "mod" and info[2] <= g_orm_result.modDataList.count then
	(
		g_orm_rollMods.btn_toggle.enabled = true
		ORM_setToggleUI (ORM_getLiveEnabled info[2])
	)
	else
	(
		g_orm_rollMods.btn_toggle.enabled = false
		ORM_setToggleUI false
	)
	true
)

-- Вкл/выкл выбранного модификатора (кнопка On/Off)
fn ORM_toggleSelected st =
(
	if g_orm_selInfo.count == 0 do return false
	if g_orm_selInfo[1] != "mod" do return false
	if not (ORM_validTargets()) do ( ORM_refreshUI(); return false )
	local modDataIdx = g_orm_selInfo[2]
	if modDataIdx < 1 or modDataIdx > g_orm_result.modDataList.count do return false
	local cls = g_orm_result.modDataList[modDataIdx].modClass
	ORM_toggleModifier cls st
	-- Синхронизируем toggle с реальным состоянием
	ORM_setToggleUI (ORM_getLiveEnabled modDataIdx)
	true
)

-- Очистка интерфейса: старые данные не показываем, когда выделение снято (пп. 8)
fn ORM_clearUI =
(
	local changed = false
	if g_orm_rollMods != undefined do
	(
		local oldItems = g_orm_rollMods.lst_mods.items
		if oldItems.count != 1 or (oldItems.count == 1 and oldItems[1] != "No selection.") do
		(
			g_orm_rollMods.lst_mods.items = #("No selection.")
			changed = true
		)
		g_orm_rollMods.lst_mods.selection = 0
		ORM_setToggleUI false
		g_orm_rollMods.btn_toggle.enabled = false
	)
	g_orm_listItems = #()
	g_orm_selInfo = #()
	g_orm_lastSelKey = ""
	g_orm_modClasses = #()

	if g_orm_rlProps != undefined and g_orm_floater != undefined do
	(
		try ( removeRollout g_orm_rlProps g_orm_floater ) catch ()
		try ( destroyDialog g_orm_rlProps ) catch ()
		g_orm_rlProps = undefined
		changed = true
	)
	changed
)

-- Обновление интерфейса на месте (без перезапуска макроса, пп. 2)
-- Если выделение снято/недостаточно — чистим интерфейс (старые данные не показываем, пп. 8)
fn ORM_refreshUI quiet:false =
(
	-- Безопасность для callbacks: если floater уже закрыт — не трогаем UI (пп. 3)
	if g_orm_floater == undefined or g_orm_rollMods == undefined do return false

	-- Запоминаем выбранный элемент, чтобы сохранить контекст при автозамёте
	local wasSel = copy g_orm_selInfo

	local sel = selection as array
	local validCount = 0
	for o in sel do if isValidNode o do validCount += 1

	-- Выделение снято или недостаточно объектов: очищаем интерфейс
	if validCount < 2 do
	(
		if ORM_clearUI() do ORM_updateFloaterHeight()
		return true
	)

	local result = ORM_analyzeSelection sel
	if result == undefined do
	(
		if ORM_clearUI() do ORM_updateFloaterHeight()
		return true
	)

	g_orm_result = result
	g_orm_uniqueObjs = result.uniqueObjs
	g_orm_modClasses = for m in result.modDataList collect m.modClass
	g_orm_selInfo = #()

	-- Пересобираем строки списка (модификаторы сверху, baseobject последним внизу)
	local listItems = #()
	g_orm_listItems = #()

	for mi2 = 1 to result.modDataList.count do
	(
		local md = result.modDataList[mi2]
		local label = md.displayName
		if md.lowerCount > 0 do
			label += "  (x" + (md.lowerCount + 1) as string + ")"
		append listItems label
		append g_orm_listItems #("mod", mi2)
	)
	if result.baseObjData != undefined and result.baseObjData.props.count > 0 do
	(
		append listItems ("Base: " + (result.baseObjData.objClass as string))
		append g_orm_listItems #("base", 0)
	)
	if listItems.count == 0 do
	(
		listItems = #("No common modifiers or base properties found.")
		g_orm_listItems = #()
	)

	-- Обновляем listbox без пересоздания floater
	g_orm_rollMods.lst_mods.items = listItems
	g_orm_rollMods.lst_mods.selection = 0
	ORM_setToggleUI false
	g_orm_rollMods.btn_toggle.enabled = false

	-- Убираем rollout свойств из floaterа, если он был (removeRollout, а не только destroyDialog)
	if g_orm_rlProps != undefined and g_orm_floater != undefined do
	(
		try ( removeRollout g_orm_rlProps g_orm_floater ) catch ()
		try ( destroyDialog g_orm_rlProps ) catch ()
		g_orm_rlProps = undefined
	)
	g_orm_lastSelKey = ""

	-- Восстанавливаем прежний выбор, если он ещё валиден в новых данных
	if wasSel.count > 0 do
	(
		for i = 1 to g_orm_listItems.count do
			if g_orm_listItems[i][1] == wasSel[1] and g_orm_listItems[i][2] == wasSel[2] do
			(
				g_orm_rollMods.lst_mods.selection = i
				ORM_onListSelect i
				exit
			)
	)

	-- Автовысота под текущий набор свитков
	ORM_updateFloaterHeight()

	true
)

-- Полный пересоздание floater (используется при первом показе)
fn ORM_rebuildNow =
(
	ORM_refreshUI()
)

-- Обёртка для колбэков с защитой от рекурсии (пп. 3)
-- Колбэки срабатывают очень часто; повторный вход (например, потому что сам
-- refresh меняет выбор/стек, что вновь вызывает колбэк) обрываем на месте.
-- При ошибке: печатаем стек через ErrorDump.ms и УДАЛЯЕМ себя из списка
-- колбэков, чтобы битый колбэк не висел и не спамил ошибками бесконечно.
fn ORM_cbRefresh =
(
	if g_orm_refreshing do return false
	g_orm_refreshing = true
	try
	(
		ORM_refreshUI quiet:true
	)
	catch
	(
		try ( fileIn "ErrorDump.ms" ) catch ()
		if classOf FmtError == MAXScriptFunction then
			print ("ModPropsLister: callback error (callbacks unregistered):\n" + (FmtError stackLevels:4))
		else
			print ("ModPropsLister: callback error (callbacks unregistered): " + (getCurrentException() as string))
		ORM_unregisterCallbacks()
	)
	g_orm_refreshing = false
	true
)

-- Автозамёты: пересборка при изменении выделения или стека модификаторов (пп. 3)
-- Функции вызываются global (доступны из контекста callback). id гарантирует отсутствие дублей.
fn ORM_registerCallbacks =
(
	try ( callbacks.removeScripts id:#ModPropsLister ) catch ()
	callbacks.addScript #selectionSetChanged "ORM_cbRefresh()" id:#ModPropsLister
	callbacks.addScript #postModifierAdded      "ORM_cbRefresh()" id:#ModPropsLister
	callbacks.addScript #postModifierDeleted    "ORM_cbRefresh()" id:#ModPropsLister
	g_orm_callbacksOn = true
)

fn ORM_unregisterCallbacks =
(
	try ( callbacks.removeScripts id:#ModPropsLister ) catch ()
	g_orm_callbacksOn = false
)

-- Закрытие диалога + floater
fn ORM_closeDialog =
(
	ORM_unregisterCallbacks()
	try ( destroyDialog g_orm_rlProps ) catch ()
	g_orm_rlProps = undefined
	try ( closeRolloutFloater g_orm_floater ) catch ()
	g_orm_floater = undefined
)


-- ======================================================================
-- LAYER 2: UI — ДИНАМИЧЕСКИЙ ROLLOUT СВОЙСТВ
-- ======================================================================

-- Генерирует контролы для одного свойства в rolloutCreator
--   modIdx: 0 = базовый объект, 1..N = модификатор
--   prefix: префикс для имён контроллов ("v_" или "m1_")
fn ORM_addPropControls rc modIdx prefix propInfo &height =
(
	local pNameStr = propInfo.name as string
	local ctrlName = prefix + pNameStr
	local lookupKey = prefix + pNameStr

	append g_orm_propLookup #(lookupKey, modIdx, pNameStr, prefix)

	local differing = not propInfo.allSame
	local disStr = if differing then " enabled:false" else ""

	if propInfo.ptype == #float or propInfo.ptype == #integer then
	(
		local initVal = if propInfo.value != undefined then propInfo.value else 0.0
		-- диапазон: зависит от величины значения (пп. 6)
		local mag = abs (initVal as float)
		if mag < 100 do mag = 100
		local rangeMin = -mag * 50
		local rangeMax =  mag * 50
		local typeFlag = if propInfo.ptype == #float then "#float" else "#integer"
		local acrossStr = if differing then " across:2" else ""

		rc.addControl #spinner ctrlName (pNameStr + ":") paramStr:(
			"range:[" + rangeMin as string + "," + rangeMax as string + "," + initVal as string + "] " \
			+ "type:" + typeFlag + " fieldWidth:75 align:#left" + disStr + acrossStr
		)
		height += 22
		if differing do
		(
			rc.addControl #button (ctrlName + "_mk") "Unify" paramStr:"width:50 height:18 align:#right tooltip:\"Make the property general\""
			rc.addHandler (ctrlName + "_mk") #pressed filter:on \
				codeStr:("if ORM_onMakeCommon \"" + lookupKey + "\" do ()")
		)
		rc.addHandler ctrlName #changed paramStr:"val" filter:on \
			codeStr:("if ORM_propChanged \"" + lookupKey + "\" val do ()")
	)
	else if propInfo.ptype == #boolean then
	(
		local initVal = if propInfo.value != undefined then propInfo.value else false
		local acrossStr = if differing then " across:2" else ""
		rc.addControl #checkbox ctrlName pNameStr paramStr:(
			"state:" + initVal as string + " align:#left" + disStr + acrossStr
		)
		height += 22
		if differing do
		(
			rc.addControl #button (ctrlName + "_mk") "Unify" paramStr:"width:50 height:18 align:#right tooltip:\"Make the property general\""
			rc.addHandler (ctrlName + "_mk") #pressed filter:on \
				codeStr:("if ORM_onMakeCommon \"" + lookupKey + "\" do ()")
		)
		rc.addHandler ctrlName #changed paramStr:"val" filter:on \
			codeStr:("if ORM_propChanged \"" + lookupKey + "\" val do ()")
	)
	else if propInfo.ptype == #color then
	(
		local initVal = if propInfo.value != undefined then propInfo.value else (color 128 128 180)
		local acrossStr = if differing then " across:2" else ""
		rc.addControl #colorpicker ctrlName (pNameStr + ":") paramStr:(
			"color:" + initVal as string + " fieldWidth:75 height:18 title:\"\"" + disStr + acrossStr
		)
		height += 22
		if differing do
		(
			rc.addControl #button (ctrlName + "_mk") "Unify" paramStr:"width:50 height:18 align:#right tooltip:\"Make the property general\""
			rc.addHandler (ctrlName + "_mk") #pressed filter:on \
				codeStr:("if ORM_onMakeCommon \"" + lookupKey + "\" do ()")
		)
		rc.addHandler ctrlName #changed paramStr:"val" filter:on \
			codeStr:("if ORM_propColorChanged \"" + lookupKey + "\" " + ctrlName + ".color do ()")
	)
	else if propInfo.ptype == #point3 then
	(
		local initVal = if propInfo.value != undefined then propInfo.value else [0,0,0]
		for ci = 1 to 3 do
		(
			local comp = #("x", "y", "z")[ci]
			local compVal = case comp of (
				"x": initVal.x; "y": initVal.y; "z": initVal.z
			)
			local compCtrl = ctrlName + "_" + comp
			local compLabel = pNameStr + " " + (toUpper comp) + ":"
			local acrossStr = if (differing and ci == 1) then " across:2" else ""
			rc.addControl #spinner compCtrl compLabel paramStr:(
				"range:[-999999,999999," + compVal as string + "] " \
				+ "type:#float fieldWidth:55 align:#left" + disStr + acrossStr
			)
			height += 22
			if differing and ci == 1 do
			(
				rc.addControl #button (ctrlName + "_mk") "Unify" paramStr:"width:50 height:18 align:#right tooltip:\"Make the property general\""
				rc.addHandler (ctrlName + "_mk") #pressed filter:on \
					codeStr:("if ORM_onMakeCommon \"" + lookupKey + "\" do ()")
			)
			rc.addHandler compCtrl #changed paramStr:"val" filter:on \
				codeStr:("if ORM_propPoint3Changed \"" + lookupKey + "\" \"" + comp + "\" val do ()")
		)
	)
)

-- Создаёт/пересоздаёт динамический rollout со свойствами выбранного элемента
fn ORM_rebuildPropsRollout =
(
	-- Только пересоздавать, если выбранная запись реально поменялась (пп. 4)
	local curKey = (g_orm_selInfo[1] as string) + "_" + (g_orm_selInfo[2] as string)
	if curKey == g_orm_lastSelKey and g_orm_rlProps != undefined do
		return true

	-- Удаляем старый rollout из floaterа (именно removeRollout, destroyDialog его не убирает из floaterа)
	if g_orm_rlProps != undefined and g_orm_floater != undefined do
	(
		try ( removeRollout g_orm_rlProps g_orm_floater ) catch ()
		try ( destroyDialog g_orm_rlProps ) catch ()
		g_orm_rlProps = undefined
	)

	if g_orm_selInfo.count == 0 do return false
	if g_orm_result == undefined do return false

	g_orm_propLookup = #()

	local isBaseObj = (g_orm_selInfo[1] == "base")
	local modDataIdx = g_orm_selInfo[2]

	local sectionTitle = ""
	local props = #()
	local modIdx = 0
	local prefix = ""

	if isBaseObj then
	(
		if g_orm_result.baseObjData == undefined do return false
		sectionTitle = "Base: " + (g_orm_result.baseObjData.objClass as string)
		props = g_orm_result.baseObjData.props
		modIdx = 0
		prefix = "v_"
	)
	else
	(
		if modDataIdx < 1 or modDataIdx > g_orm_result.modDataList.count do return false
		local md = g_orm_result.modDataList[modDataIdx]
		sectionTitle = md.displayName
		if md.lowerCount > 0 do
			sectionTitle += "  (" + md.lowerCount as string + " lower duplicates)"
		props = md.props
		modIdx = modDataIdx
		prefix = "m" + modDataIdx as string + "_"
	)

	if props.count == 0 do return false

	local rc = rolloutCreator "g_orm_rlProps" sectionTitle
	rc.begin()

	local h = 10
	for p in props do
		ORM_addPropControls rc modIdx prefix p &h

	h += 10
	if h < 40 do h = 40

	g_orm_rlProps = rc.end()

	-- Переставляем свиток так, чтобы About оставался ПОСЛЕДНИМ (пп. 4)
	local hasAbout = (findItem g_orm_floater.rollouts g_orm_rollAbout) != 0
	if hasAbout do removeRollout g_orm_rollAbout g_orm_floater

	addRollout g_orm_rlProps g_orm_floater

	if hasAbout do addRollout g_orm_rollAbout g_orm_floater

	-- Сворачиваем About при выборе элемента (пп. 2)
	try ( g_orm_rollAbout.open = false ) catch ()

	-- Автовысота под новый набор свитков
	ORM_updateFloaterHeight()

	-- Запоминаем, для какого выбора построен rollout, чтобы не дублировать (пп. 4)
	g_orm_lastSelKey = (g_orm_selInfo[1] as string) + "_" + (g_orm_selInfo[2] as string)

	true
)


-- ======================================================================
-- UI: ROLLOUT "MODIFIERS" (статический)
-- ======================================================================

rollout rollout_mods "Modifiers"
(
	listbox lst_mods "" height:8 width:180 align:#left --across:2
	
	checkbutton btn_toggle "👁‍🗨️" align:#right width:24 height:25 tooltip:"Enable/disable modifier" offset:[0,-8*15]
	button btn_delete "" width:24 height:25 align:#right tooltip:"Remove modifier from the stack" offset:[0,60]

	on lst_mods selected idx do
		ORM_onListSelect idx

	on btn_toggle changed st do (
		ORM_toggleSelected st
		btn_toggle.caption = if st then "👁️" else "👁‍🗨️"
	)

	on btn_delete pressed do
	(
		if g_orm_selInfo.count == 0 do return false
		if g_orm_selInfo[1] != "mod" do
		(
			messageBox "Base object cannot be deleted." title:APP_TITLE
			return false
		)
		local modDataIdx = g_orm_selInfo[2]
		if modDataIdx < 1 or modDataIdx > g_orm_modClasses.count do return false
		if ORM_onDeleteMod modDataIdx do ORM_rebuildNow()
	)

	-- Автовысота при сворачивании/разворачивании свитка; сохранение позиции при закрытии
	on rollout_mods rolledUp state do ORM_updateFloaterHeight()
	on rollout_mods close do ORM_saveFloaterState()
)


-- ======================================================================
-- UI: ROLLOUT "ABOUT" (статистический, по образцу BatchViewsManager)
-- ======================================================================

rollout rollout_about "About"
(
	local colw = 225

	label lbl_ver lbl_ver_caption align:#left
	label lbl_hint1 "Multi-editor for non-instance objects." align:#left
	hyperLink hlnk_repo "https://github.com/Pankovea" address:"https://github.com/Pankovea" align:#left
	on rollout_about rolledUp state do ORM_updateFloaterHeight()
	on rollout_about close do ORM_saveFloaterState()
)


-- ======================================================================
-- UI: СБОРКА И ПОКАЗ
-- ======================================================================

-- Автовысота floater: чтобы все открытые свитки были видны целиком,
-- но не больше размера экрана (паттерн BatchViewsManager: updateFloaterHeight)
fn ORM_updateFloaterHeight =
(
	if g_orm_floater == undefined do return false
	local h = g_orm_floater.rollouts.count * 30
	for i = 1 to g_orm_floater.rollouts.count do
		if g_orm_floater.rollouts[i].open do h += g_orm_floater.rollouts[i].height
	local scale_dpi = ((dotNetClass "System.Drawing.Graphics").fromHwnd 0).dpiX / 100
	local newH = h / scale_dpi
	local maxH = (sysInfo.DesktopSize)[2] / scale_dpi
	if newH > maxH do newH = maxH
	if newH < 200 do newH = 200
	try ( g_orm_floater.size = [g_orm_floater.size[1], newH] ) catch ()
	true
)

-- Сохранить позицию/размер floater в INI (паттерн BatchViewsManager: saveFloaterState)
fn ORM_saveFloaterState =
(
	if g_orm_floater == undefined do return false
	local iniPath = getmaxinifile()
	setINISetting iniPath "ModPropsLister" "Position" (g_orm_floater.pos as string)
	setINISetting iniPath "ModPropsLister" "WindowsSize" (g_orm_floater.size as string)
	true
)

fn ORM_showUI result =
(
	g_orm_selInfo = #()

	-- Коллекция строк списка: модификаторы сверху (порядок стека), baseobject ПОСЛЕДНИМ внизу (пп. 1)
	local listItems = #()
	g_orm_listItems = #()

	if result != undefined do
	(
		for mi2 = 1 to result.modDataList.count do
		(
			local md = result.modDataList[mi2]
			local label = md.displayName
			if md.lowerCount > 0 do
				label += "  (x" + (md.lowerCount + 1) as string + ")"
			append listItems label
			append g_orm_listItems #("mod", mi2)
		)

		if result.baseObjData != undefined and result.baseObjData.props.count > 0 do
		(
			append listItems ("Base: " + (result.baseObjData.objClass as string))
			append g_orm_listItems #("base", 0)
		)

		if listItems.count == 0 do
		(
			listItems = #("No common modifiers or base properties found.")
			g_orm_listItems = #()
		)
	)

	local flW = 255
	local iniPath = getmaxinifile()
	local posStr  = getINISetting iniPath "ModPropsLister" "Position"
	local sizeStr = getINISetting iniPath "ModPropsLister" "WindowsSize"
	-- Восстановление положения/размера из INI; lockHeight:false — разрешаем автовысоту (пп. 7)
	if posStr != "" and sizeStr != "" then
	(
		local p = execute posStr
		local s = execute sizeStr
		try
			g_orm_floater = newRolloutFloater APP_TITLE s[1] s[2] p[1] p[2] lockHeight:false lockWidth:true
		catch
			g_orm_floater = newRolloutFloater APP_TITLE flW 420 lockHeight:false lockWidth:true
	)
	else
		g_orm_floater = newRolloutFloater APP_TITLE flW 420 lockHeight:false lockWidth:true

	-- Сохраняем глобальные псевдонимы статических rollout'ов
	g_orm_rollMods  = rollout_mods
	g_orm_rollAbout = rollout_about

	addRollout rollout_mods g_orm_floater

	-- Запуск без валидного анализа: показываем текущее состояние, а не блокируем
	if result == undefined do
	(
		local validCount = 0
		for o in (selection as array) do if isValidNode o do validCount += 1
		if validCount < 2 then
			listItems = #("No selection.")
		else
			listItems = #("Select 2+ non-instance objects.")
	)

	rollout_mods.lst_mods.items = listItems
	rollout_mods.lst_mods.selection = 0
	ORM_setToggleUI false
	rollout_mods.btn_toggle.enabled = false

	addRollout rollout_about g_orm_floater

	-- Автозамёты: обновление при смене выделения / стека (пп. 3)
	ORM_registerCallbacks()

	ORM_updateFloaterHeight()
)


-- ======================================================================
-- ENTRY POINT
-- ======================================================================

fn ORM_run =
(
	local sel = selection as array
	local validCount = 0
	for o in sel do if isValidNode o do validCount += 1

	local result = undefined
	if validCount >= 2 do
		result = ORM_analyzeSelection sel

	if result != undefined do
	(
		g_orm_result = result
		g_orm_uniqueObjs = result.uniqueObjs
		g_orm_modClasses = for m in result.modDataList collect m.modClass
	)

	ORM_closeDialog()

	ORM_showUI result

	true
)


on execute do ORM_run()

)
