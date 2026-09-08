/* #PankovScripts - ModPropsLister

Динамический мульти-редактор параметров для выделенных НЕ-ИНСТАНС объектов.
Сравнивает и редактирует общие свойства базового объекта и общих модификаторов
(только верхний экземпляр каждого класса в стеке).

UI:
  Rollout "Modifiers" — список: модификаторы сверху (порядок стека, верхний первым),
      baseobject ПОСЛЕДНИМ внизу; переключатель On (вкл/выкл модификатора),
      кнопка Delete. Состояние enabled показывается ИКОНКОЙ глаза в начале строки
      (owner-draw, кадры 9/10/11 BMP): открытый — все вкл, закрытый — все выкл,
      смешанный — часть объектов вкл, часть выкл.
  Rollout "Properties" — динамический свиток контролов выбранного элемента
      (генерируется rolloutCreator'ом на лету, пересоздаётся при смене выбора).
  Rollout "About" — инфо (сворачивается при выборе элемента, всегда последний).

Поведение:
  - Запуск безусловный: макрос всегда активен (без on isEnabled) и открывает окно
    при любом выделении. Состояние показывается прямо в интерфейсе:
    "No selection." / "Single Selection" / "No Match".
  - Различающиеся значения — контрол в неактивном (enabled:false) состоянии
    с кнопкой «Сделать общим» ("Unify" у float/boolean/color, "Make" у point3).
    Контекстное меню: Maximum / Average / Median / Minimum / Most common.
    После применения значение выравнивается, контрол активируется, кнопка скрывается.
  - Базовый объект: при одинаковом классе базы у выделенных показывается пункт
    "Base: <Класс>" со свойствами базового объекта. Если общих модификаторов нет,
    а базовые объекты ИДЕНТИЧНЫ (инстансы обменивают один baseObject) — всё равно
    показываем свойства базы (все контролы активны, значения у всех одинаковые).
    Пункт показывается даже когда у базы НЕТ «простых» параметров (напр. Editable
    Mesh) — чтобы одинаковые объекты распознавались; свиток свойств в этом случае
    содержит заглушку "No adjustable parameters.".
  - Base: MIXED — если базовые классы РАЗНЫЕ (напр. Circle и Line), но у всех баз
    есть свойства с СОВПАДАЮЩИМИ именем и типом (напр. steps у Shapes), показываем
    пункт "Base: MIXED" только с этими совпавшими свойствами; если у всех баз
    одинаковый суперкласс — добавляем его в скобках ("Base: MIXED (Shape)").
    Различающиеся значения по-прежнему дают кнопку «Сделать общим».
  - Положение окна сохраняется в INI (секция "ModPropsLister" в max.ini)
    и восстанавливается при открытии.
  - Автовысота окна: сумма высот открытых свитков, не больше размера экрана.
  - Автообновление: при изменении выделения / добавлении / удалении модификаторов
    интерфейс пересобирается через колбэки. При снятии выделения интерфейс
    очищается (старые данные не показываются), высота окна пересчитывается.
  - При смене выделения автоматически выделяется первый элемент списка
    (верхний модификатор стека) — его свойства открываются сразу для редактирования.
  - Объекты класса Dummy (заголовки групп, болванки) НИКОГДА не участвуют в анализе.
  - Фильтр по типу (галочки Ignore: Geometry / Shapes / Light / Camera / Helpers
    под списком) работает ТОЛЬКО с внутренними массивами анализа — сценное
    выделение не меняется. Нажатая галочка ИСКЛЮЧАЕТ соответствующий тип из
    анализа (по умолчанию все выключены = ничего не игнорируем, можно всё
    редактировать). По умолчанию (настройка g_orm_saveFilter=false) состояние
    фильтра НЕ сохраняется и НЕ восстанавливается — при запуске всегда «всё
    включено»; при g_orm_saveFilter=true состояние пишется/читается из INI.
  - Выключенные модификаторы НЕ исключаются из списка: мод без поддерживаемых
    свойств (например, выключенный) всё равно остаётся в списке (раньше мог
    молча пропадать). При СМЕШАННОМ состоянии (часть вкл, часть выкл) клик по
    глазу не переключает вслепую, а открывает popupmenu Enable / Disable.

Поддерживаемые типы свойств: float, integer, boolean, color, point3.

======================================================================
АРХИТЕКТУРА — важные моменты, которые нельзя делать иначе:
======================================================================
1. ОБЛАСТЬ ВИДИМОСТИ. Динамический rollout (codeStr) и статические rollouts
   выполняются в отдельных scope-контекстах и НЕ видят macro-локальные fn.
   Все функции, вызываемые из обработчиков rollout'ов, codeStr и callbacks,
   объявлены global (см. блок "global ORM_*"). Статические rollouts доступны
   из global-функций только через глобальные псевдонимы g_orm_rollMods /
   g_orm_rollAbout (паттерн BatchViewsManager). rcmenu rmc_* (типовые меню
   «Сделать общим») тоже global (вызываются из global-функции ORM_onMakeCommon
   через popUpMenu без pos: — меню появляется у курсора).

2. LOOKUP — НЕ ХЕШ. g_orm_propLookup — линейный массив кортежей
   #(key, modIdx, propNameStr, prefix), поиск через ORM_lookupFind.
   Хеш-доступ arr["key"]=... к глобальному #() в MAXScript НЕ работает
   ("array index must be positive number") — не менять на hash.
   ИНДЕКС 0 И ЗА ПРЕДЕЛЫ: g_orm_listItems[0] бросает "array index must be
   positive number, got: 0", лишний индекс даёт undefined (в части версий 0 ->
   OK). Поэтому ВСЕ чтения g_orm_selInfo / g_orm_listItems[..] guard'ятся
   classOf == Array И idx >= 1 ДО индексации — иначе runtime error.

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
   Смешанное состояние (часть вкл, часть выкл) определяется через
   ORM_getEnabledStates (per-object) + ORM_isMixedEnabled: тогда клик по
   глазу открывает popupmenu rmc_toggle (Enable / Disable), пункты которого
   сами применяют выбор через ORM_toggleSelected. Мод без поддерживаемых
   свойств в список ВКЛЮЧАЕТСЯ (props.count == 0 не отбрасывает) — иначе
   выключенный мод мог молча пропасть из списка. Иконка глаза: 9 — открытый,
   10 — закрытый, 11 — смешанный (ORM_setToggleUI подменяет images по mixedState).
   Отдельного колбэка на смену enabled в Max нет (только pre/postModifierAdded|Deleted),
   поэтому после toggle строки списка пересобираются явно (ORM_refreshList).
   МАССОВЫЕ ПРАВКИ СТЕКА: циклы .enabled= / deleteModifier по всем объектам оборачиваются
   в `with redraw off` — он не только гасит крас viewport'ов, но и ПРИОСТАНАВЛИВАЕТ
   Modify-панель (документация: redraw Context), поэтому панель обновляется один раз,
   а не на каждый объект цикла; явный ORM_refreshModPanel остаётся один на операцию.

7. CALLBACKS.
   Все колбэки идут через ORM_cbRefresh с флагом g_orm_refreshing (защита от
   бесконечной рекурсии). Регистрация с id:#ModPropsLister (removeScripts перед
   добавлением — иначе дубли). Обработчики: #selectionSetChanged,
   #postModifierAdded, #postModifierDeleted (#modStackChanged НЕ существует).
   При ошибке внутри колбэка стек печатается через ErrorDump.ms
   (scripts\ErrorDump.ms, fileIn "ErrorDump.ms", FmtError stackLevels:N),
   после чего колбэки УДАЛЯЮТСЯ (self-unregister по id:#ModPropsLister):
   разовый сбой не должен оставлять «зомби»-колбэки, спамящие ошибками
   после закрытия окна.
   #selectionSetChanged регистрируется как "ORM_cbRefresh autoSel:true" —
   при смене выделения список авто-выделяет первый элемент (верхний стек).

8. АВТОВЫСОТА ОКНА. newRolloutFloater создаётся с lockHeight:false lockWidth:true
   (иначе размер .size игнорируется). Высота = заголовки + сумма высот открытых
   свитков, DPI-масштаб ((dotNetClass "System.Drawing.Graphics").fromHwnd 0).dpiX/100,
   лимит sysInfo.DesktopSize (свойства sysInfo.screenSize НЕТ!), минимум 200.
   Пересчёт — по on <rollout> rolledUp (не open/close!) для каждого свитка.

9. СВОРАЧИВАНИЕ About. g_orm_rollAbout.open = false. Функции cw_closeRollout
   НЕ существует — молча проглатывалась catch'ем.

10. ИНИЦИАЛИЗАЦИЯ ОКНА. Позиция читается getINISetting из секции
    "ModPropsLister", парсится execute() и передаётся в newRolloutFloater.
    РАЗМЕР НЕ СОХРАНЯЕТСЯ: это расчётная величина (автовысота), при создании
    floater'а используется фиксированная стартовая высота. Сохранение —
    setINISetting в обработчике on <rollout> close.

11. ОЧИСТКА ПРИ СНЯТИИ ВЫДЕЛЕНИЯ. При <2 валидных объектов ORM_refreshUI
    вызывает ORM_clearUI() (старые данные не показываем) + ORM_updateFloaterHeight().
    Запоминание объектов «с прошлого раза» не применяется — по требованию.

12. УСТАРЕВШИЕ СВОЙСТВА. edgeChamferType / edgeChamferQuadIntersections (Edit Poly)
    отфильтрованы в ORM_collectSupportedProps, иначе 3ds Max пишет предупреждения
    в Listener.

13. ШАГ СПИННЕРОВ: БЕЗ РАЗГОНА, СКАЧКОВ И ПРОСКАЛЬЗЫВАНИЯ. Целевой шаг — НЕПРЕРЫВНЫЙ
     1% от величины (ORM_stepScale: 1 → 0.01, 5000 → 50), БЕЗ квантования 1-2-5
     (давало неожиданные скачки ×2/×2.5 внутри декады). Нижняя граница шага — от
     СРЕДНЕЙ величины параметров свитка (g_orm_avgMag, 1% от неё): с нуля (или малым
     значением) шаг не схлопывается в 0.01, а остаётся комфортным для работы с тысячными.
     scale ставится ОДИН раз на СТАРТЕ драга (событие buttondown: обычное вращение —
     адаптивный шаг от текущего значения; с зажатым Alt — точный степенной шаг формулой
     (abs(v)+1)/1000, ~0.001 на малых и ~0.1% от величины на больших) и ВО ВРЕМЯ драга
     НЕ меняется. Почему: смена scale в середине драга пересчитывает накопленное
     движение мыши с новым множителем (резкий скачок), а «коррекция значения» поверх
     аккумулятора 3ds Max копит расхождение и даёт проскальзывание при смене
     направления. Между драгами (buttonup) scale обновляется под новое значение.
     Исключение — групповой режим Scale (см. g_orm_incrMap): спиннер показывает ФАКТОР
     в %, а не величину, поэтому шаг тоже степенной, но ОТ БАЗЫ 100 — (abs(100)+1)/1000
     = 0.101 (1 единица = 0.1%), независимо от средней величины параметров (ORM_spinStep) —
     иначе на тысячном avgMag фактор «скакал» бы на 7% за тик.

======================================================================
ИЗВЕСТНЫЕ ОГРАНИЧЕНИЯ (невозможно исправить штатно):
=====================================================================
A. ДИАПАЗОНЫ СПИННЕРОВ НЕ ЧИТАЮТСЯ. Минимальные/максимальные значения
   контролов модификатора заданы в ParamBlock2 плагина и НЕ экспозятся
   через MAXScript. setProperty пишет значение «как есть» — ошибку не даёт,
   но если значение вне UI-диапазона (например, отрицательные inner/outer
   у Shell), спиннер UI просто не отображает его. getProperty вернёт
   то же «кривое» значение, поэтому эвристика «установил-прочитал» тоже
   не работает для плагинов, не клипающих при скриптовой записи.
*/

macroScript ModPropsLister
	category:"#PankovScripts"
	ButtonText:"ModProps Lister"
	tooltip:"ModProps Lister\n\nMulti-editor for parameters\nof selected non-instance objects.\n\nCompares common properties\nof the base object and modifiers.\n\nDiffering values can be\nunified via the Unify button."
	icon:#("ModProps", 1)
	autoUndoEnabled:false
(
local APP_TITLE = "ModProps Lister"
local VERSION = "1.0.1 (2026-09-05)"

local lbl_ver_caption = APP_TITLE + " " + VERSION

-- Иконки в usericons\ModProps_16i.bmp (число кадров — locIconCount в rollout_mods):
--   1 — приложение, 2-8 — типы нодов, 9 — открытый глаз, 10 — закрытый,
--   11 — смешанный, 12 — удаление, 13 — обновить (Refresh)
local icon_path = (getDir #usericons) + "\\ModProps_16i.bmp"


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
	objClass,       -- класс базового объекта (Box, Sphere, ...); для MIXED — класс первого объекта (не используется)
	props,          -- #(ORM_PropInfo)
	isMixed,        -- true = базовые классы разные, показаны ТОЛЬКО совпадающие по имени/типу свойства (Base: MIXED)
	commonSuper     -- строка общего суперкласса ("Shape", "Geometry"...) или undefined (Base: MIXED (Shape))
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
global g_orm_debug -- true для дебаг вывода в listener

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
-- dotNet списка: иконки и флаги инстанса по индексам строк (см. ORM_buildListItems/ORM_drawListItem)
global g_orm_listIcons      = #()
global g_orm_listFlags      = #()
-- Кадры ModProps_16i.bmp для owner-draw (загружаются в ORM_initModList)
global g_orm_iconFrames     = #()
-- Размер иконки/высоты строки списка (px) — простая переменная в коде
global g_orm_iconSize        = 16
-- Количество иконок в полоске ModProps_16i.bmp (полоска 208px / 16px = 13).
-- Меняется при дорисовке новых иконок в PNG; от него зависят и кнопки rollout'ов
-- (images: ... count), и нарезка кадров для dotNet (g_orm_iconFrames).
-- Число кадров НЕ хранится глобально: в rollout_mods это rollout-локальная locIconCount
-- (для images: ... count), а ORM_loadIconFrames считает кадры из ширины bmp / g_orm_iconSize.
-- ФИЛЬТР ПО ТИПАМ — «Игнор»: #(geometry, shape, light, camera, helper).
-- true = этот тип ИСКЛЮЧАЕТСЯ из анализа (галочка нажата); по умолчанию все false
-- (ничего не игнорируем = всё участвует), чтобы кнопки не выглядели нажатыми.
global g_orm_typeFilter     = #(false, false, false, false, false)
-- Защита от рекурсии при синхронизации галочек фильтра
global g_orm_syncFilter     = false
-- НАСТРОЙКА: сохранять/восстанавливать ли состояние фильтра в INI.
-- false (по умолчанию) — фильтр всегда сбрасывается на «ничего не игнорируем» при запуске,
-- его состояние НЕ пишется в max.ini и НЕ читается из него. true — прежнее поведение.
global g_orm_saveFilter     = false
-- Контекст кнопки «Сделать общим» (lookupKey), читается из rcmenu
global g_orm_ctxKey         = ""
-- Признак того, что rollout свойств уже построен для текущего выбора (см. архитектура п. 4)
global g_orm_lastSelKey     = ""
-- Защита от рекурсии колбэков (см. архитектура п. 3)
global g_orm_refreshing     = false
-- Групповой режим спиннера (см. «Сделать общим»): lookupKey ->
--   #( #(obj, baseVal, modIdx, realName), ... , mode ) где mode = #incr | #scale.
--   #incr:  контрол стартует с 0, изменение ПРИБАВЛЯЕТ дельту к запомненной базе
--           (0 = «прибавить ноль», ничего не меняем).
--   #scale: контрол стартует со 100 (%), изменение УМНОЖАЕТ базы на значение/100
--           (100 = «умножить на 1»).
--   И в том, и в другом случае показанное число — фактор (дельту/процент),
--   НЕ абсолютное значение свойства.
global g_orm_incrMap        = #()


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
global ORM_refreshModPanel
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
global ORM_setFilterUI
global ORM_onFilterChanged
global ORM_onMakeCommon
global ORM_applyCommon
global ORM_enableAfterCommon
global ORM_syncCtrlValue
global ORM_incrFind
global ORM_incrBegin
global ORM_applyTick
global ORM_incrApplyPairs
-- Групповой undo (см. блок «ГРУППОВОЙ UNDO» ниже): одна запись Undo на весь цикл
-- нажатие-отпускание спиннера, реализуется через theHold.Begin()/Accept().
-- Функции и флаги global, потому что их вызывает код, живущий в чужом scope:
-- события динамического rollout'а и codeStr (см. блок «Для codeStr важно...» ниже).
global ORM_gestureBegin
global ORM_gestureCommit
-- Имя текущей undo-записи для theHold.Accept; перезаписывается при каждом begin
-- (например "ModPropsLister Edit", "ModPropsLister Point3", "ModPropsLister Incremental").
global g_orm_incrUndoLabel = "ModPropsLister Edit"
-- true = theHold открыт НАМИ (между Begin и Accept/Cancel). Защита от повторного
-- Begin на следующих changed внутри одного цикла нажатие-отпускание.
global g_orm_gestureActive = false
global ORM_ctxPtype
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
-- Функции owner-draw списка вызываются из dotNet-событий (DrawItem, SelectedIndexChanged)
-- и из глобальных ORM_*-функций, т.е. из скоупа, ОТДЕЛЬНОГО от макроса. В .mcr обычный
-- fn локален макроскоупу — без этого предобъявления global dotNet-событие увидело бы
-- имя как Global:undefined.
global ORM_enableDoubleBuffered
global ORM_loadIconFrames
global ORM_initModList
global ORM_listSetItems
global ORM_listSelectChanged
global ORM_drawListItem
global ORM_refreshList
-- Точность спиннеров и подавление программных `changed`. Тоже global по той же
-- причине (оживает в codeStr динамического rollout'а — он вне scope макроса,
-- поэтому без global из события переменная рисуется как undefined).
-- g_orm_uiSuppress: во время ПРОГРАММНОЙ установки контрола (ORM_syncCtrlValue после
-- Unify, обнуление в ORM_incrBegin) изменившееся `changed` НЕ должно начать групповой
-- undo — хендлеры спиннеров/чекбоксов/цвета на это проверяют флаг.
global g_orm_uiSuppress   = false
-- Средняя ВЕЛИЧИНА параметров текущего свитка (float/int + компоненты point3,
-- ненулевые). Нижняя граница шага спиннеров (ORM_stepScale): при значении 0 шаг не
-- схлопывается до фиксированного минимума, а даёт комфортную скорость для работы
-- с тысячными значениями (1% от средней величины). Global — читается из codeStr
-- (ROLLOUT-скоуп, см. ниже).
global g_orm_avgMag = 1.0
-- Для codeStr важно, чтобы глобальные объявления были ДО определений fn
-- (см. паттерн остальных global ORM_* в блоке выше) — иначе из rollout'а
-- переменная видна как Global:undefined.
global ORM_setSpinnerScale
global ORM_spinStep
global ORM_stepScale
global ORM_logExcept

-- Логирование исключений: ВСЕ catch идут через этот хелпер, пустых catch в скрипте нет.
-- g_orm_debug=false — молчание допускается только там, где сбой заведомо безопасен
-- (в таких местах это отмечено комментарием); g_orm_debug=true — всё в Listener.
fn ORM_logExcept ctx msg =
(
	if g_orm_debug do format "ModPropsLister[%]: %\n" ctx msg
	undefined
)

-- Целевой шаг спиннера по величине значения: НЕПРЕРЫВНО, 1% от величины
-- (1 → 0.01, 5000 → 50), БЕЗ квантования 1-2-5 и без разгона. Нижняя граница шага
-- НЕ фиксированная, а от СРЕДНЕЙ величины параметров свитка (g_orm_avgMag, 1% от неё):
-- когда значение в нуле, а остальные параметры на тысячах, шаг всё равно комфортный.
-- Применяется на СТАРТЕ каждого драга (buttondown) — во время драга scale фиксирован.
fn ORM_stepScale v =
(
	amax 0.01 ( (amax (abs (v as float)) g_orm_avgMag) * 0.01 )
)

-- Установка scale спиннера. В codeStr напрямую .scale = ... не пишем: сборка строки
	-- с try/catch была бы многословной, а сбой здесь заведомо безопасен — оборачиваем
	-- в этот хелпер и логгируем (без него при сбое события умрут молча).
	fn ORM_setSpinnerScale ctrl s =
	(
		try ( ctrl.scale = s ) catch ( ORM_logExcept "spinScale" (getCurrentException() as string) )
		true
	)

	-- Шаг спиннера для codeStr-хендлеров buttondown/buttonup.
	-- В обычном режиме (и в #incr) — адаптивный: 1% от ТЕКУЩЕГО значения с нижней
	-- границей от средней величины свитка (ORM_stepScale). В Scale-режиме контрол
	-- показывает ФАКТОР (%), поэтому шаг тоже степенной, но ОТ 100 (базы фактора):
	-- (abs(100)+1)/1000 = 0.101, т.е. 1 единица = 0.1%, без нижней границы от среднего —
	-- иначе на большом avgMag фактор скакал бы на 7% за тик.
	-- Alt — тот же принцип, от текущего показания.
	fn ORM_spinStep ctrlName lookupKey alt:false =
	(
		local v = try ( ctrlName.value as float ) catch ( 0.0 )
		if alt do return ( (abs v) + 1.0 ) / 1000.0
		local item = ORM_incrFind lookupKey
		if item != undefined and item[3] == #scale do return ( (abs 100) + 1.0 ) / 1000.0
		ORM_stepScale v
	)


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
	local mods = obj.modifiers
	if mods == undefined do return result
	for i = 1 to mods.count do
	(
		local m = mods[i]
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
	local mods = obj.modifiers
	if mods == undefined do return cnt
	for i = (topmostIdx + 1) to mods.count do
		if classOf mods[i] == targetClass do cnt += 1
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
		try ( val = getProperty modOrBase pname ) catch ( ORM_logExcept "readProp" (getCurrentException() as string) )
		if val == undefined do continue
		local pt = ORM_getPropType val
		if pt != undefined do
			append props (ORM_PropInfo name:pname value:val allSame:true ptype:pt)
	)
	props
)

-- Разрешает ли фильтр участие объекта в анализе: true = тип НЕ игнорируется.
fn ORM_matchesFilter obj =
(
	local sc = superClassOf obj
	if sc == GeometryClass then return not g_orm_typeFilter[1]
	if sc == Shape        then return not g_orm_typeFilter[2]
	if sc == Light        then return not g_orm_typeFilter[3]
	if sc == Camera       then return not g_orm_typeFilter[4]
	-- Прочие суперклассы (Helpers и спец.) — категория "Helpers"
	not g_orm_typeFilter[5]
)

-- Имя суперкласса объекта для заголовка Base: MIXED (чистое, без "Class")
fn ORM_superClassName obj =
(
	local sc = superClassOf obj
	if sc == GeometryClass then return "Geometry"
	if sc == Shape        then return "Shape"
	if sc == Light        then return "Light"
	if sc == Camera       then return "Camera"
	"--"
)

fn ORM_analyzeSelection sel =
(
	local uniqueObjs = #()
	for obj in sel do
	(
		if not (isValidNode obj) do continue
		-- Dummy (заголовки групп, вспомогательные болванки) не участвуют никогда
		if classOf obj == Dummy do continue
		-- Фильтр по типу позволяет отсечь лишнее из выделения (см. архитектура п. 2)
		if not (ORM_matchesFilter obj) do continue
		local isTrueInstance = false
		for u in uniqueObjs do
		(
			if classOf u.baseObject == classOf obj.baseObject \
				and u.baseObject == obj.baseObject \
				do ( isTrueInstance = true; exit )
		)
		if not isTrueInstance do append uniqueObjs obj
	)

	if uniqueObjs.count < 1 do return undefined

	local singleGroup = (uniqueObjs.count == 1)

	local normalizedStacks = #()
	for obj in uniqueObjs do
		append normalizedStacks (ORM_getTopmostPerClass obj)

	local modDataList = #()

	if not singleGroup do
	(
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

	for c in commonClasses do
	(
		local topmostMod = undefined
		local topmostIdx = 0
		for item in normalizedStacks[1] do
			if item[1] == c do ( topmostMod = item[2]; topmostIdx = item[3]; exit )
		if topmostMod == undefined do continue

		local lowerCount = ORM_countLowerDuplicates uniqueObjs[1] c topmostIdx
		local props = ORM_collectSupportedProps uniqueObjs[1] topmostMod
		-- Мод без поддерживаемых свойств НЕ выкидываем: он должен остаться в списке
		-- (например, выключенный мод, у которого свойства не собираются — см. архитектура п. 2)

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
				try ( otherVal = getProperty otherMod props[pi].name ) catch ( ORM_logExcept "diffProps" (getCurrentException() as string) )
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
	)

	local baseObjData = undefined

	if singleGroup then
	(
		-- Идентичные базовые объекты (инстансы) или одна уникальная геометрия:
		-- общих модификаторов нет, показываем свойства БАЗОВОГО объекта.
		-- Значения одинаковые у всех по определению, поэтому все контролы активны.
		-- Base-пункт показываем ДАЖЕ БЕЗ поддерживаемых свойств (props пуст) —
		-- иначе «одинаковые» объекты без «простых» параметров (напр. Editable Mesh)
		-- вместо распознавания давали No Match.
		local props = ORM_collectSupportedProps uniqueObjs[1] uniqueObjs[1].baseObject
		baseObjData = ORM_BaseObjData objClass:(classOf uniqueObjs[1].baseObject) props:props isMixed:false commonSuper:undefined
	)
	else
	(
		local firstBaseClass = classOf uniqueObjs[1].baseObject
		local allSameBaseClass = true
		for ui = 2 to uniqueObjs.count do
			if classOf uniqueObjs[ui].baseObject != firstBaseClass \
				do ( allSameBaseClass = false; exit )

		if allSameBaseClass then
		(
			-- Base-пункт показываем даже без поддерживаемых свойств: одинаковые по классу
			-- объекты без «простых» параметров (напр. Editable Mesh) должны распознаваться.
			local props = ORM_collectSupportedProps uniqueObjs[1] uniqueObjs[1].baseObject
			for pi = 1 to props.count do
			(
				local allSame = true
				for ui = 2 to uniqueObjs.count do
				(
					local otherVal = undefined
					try ( otherVal = getProperty uniqueObjs[ui].baseObject props[pi].name ) catch ( ORM_logExcept "diffBaseProps" (getCurrentException() as string) )
					if otherVal == undefined \
						or props[pi].value != otherVal \
						do ( allSame = false; exit )
				)
				props[pi].allSame = allSame
			)
			baseObjData = ORM_BaseObjData objClass:firstBaseClass props:props isMixed:false commonSuper:undefined
		)
		else
		(
			-- Base: MIXED — базовые классы РАЗНЫЕ (напр. Circle и Line). Показываем ТОЛЬКО
			-- свойства, совпадающие у всех баз ПО ИМЕНИ И ТИПУ (напр. steps у всех Shapes).
			-- Различающиеся значения по-прежнему дают «Unify» (контрол неактивен).
			local baseObjs = for obj in uniqueObjs collect obj.baseObject
			local cand = ORM_collectSupportedProps uniqueObjs[1] baseObjs[1]
			local shared = #()
			for p in cand do
			(
				local ok = true
				for ui = 2 to baseObjs.count do
				(
					local otherVal = undefined
					try ( otherVal = getProperty baseObjs[ui] p.name ) catch ( ORM_logExcept "sharedBaseProps" (getCurrentException() as string) )
					if otherVal == undefined or (ORM_getPropType otherVal) != p.ptype \
						do ( ok = false; exit )
				)
				if ok do append shared p
			)
			if shared.count > 0 do
			(
				-- allSame: значение одинаково у всех баз
				for pi = 1 to shared.count do
				(
					local allSame = true
					for ui = 2 to baseObjs.count do
					(
						local otherVal = undefined
						try ( otherVal = getProperty baseObjs[ui] shared[pi].name ) catch ( ORM_logExcept "sharedSameProps" (getCurrentException() as string) )
						if otherVal == undefined or shared[pi].value != otherVal \
							do ( allSame = false; exit )
					)
					shared[pi].allSame = allSame
				)
				-- Общий суперкласс: если у всех баз одинаковый (напр. Shape) — покажем в скобках
				local curaSc = ORM_superClassName baseObjs[1]
				local commonSc = curaSc
				for ui = 2 to baseObjs.count do
					if ORM_superClassName baseObjs[ui] != curaSc do ( commonSc = undefined; exit )
				baseObjData = ORM_BaseObjData objClass:firstBaseClass props:shared isMixed:true commonSuper:commonSc
			)
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
--   Класс-ориентированный поиск устойчив к изменению порядка модификаторов (см. архитектура п. 3)
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

-- Все запомненные объекты ещё существуют? (см. архитектура п. 3)
fn ORM_validTargets =
(
	for obj in g_orm_uniqueObjs do
		if not (isValidNode obj) do return false
	true
)

-- Текущее состояние enable верхнего модификатора данного модификатора на первом объекте (живое, см. архитектура п. 3)
fn ORM_getLiveEnabled modIdx =
(
	local obj = g_orm_uniqueObjs[1]
	if obj == undefined do return false
	local t = ORM_resolveTarget obj modIdx
	if t == undefined or not (isProperty t "enabled") do return false
	try ( t.enabled ) catch ( false )
)

-- Состояния enabled класса модификатора на ВСЕХ объектах (для mixed-детекции)
fn ORM_getEnabledStates modIdx =
(
	local states = #()
	if g_orm_uniqueObjs == undefined do return states
	for obj in g_orm_uniqueObjs do
	(
		if not (isValidNode obj) do continue
		local t = ORM_resolveTarget obj modIdx
		if t == undefined or not (isProperty t "enabled") do continue
		append states (try ( t.enabled ) catch ( false ))
	)
	states
)

-- Смешанное ли состояние enabled (часть объектов вкл, часть выкл)
fn ORM_isMixedEnabled modIdx =
(
	if classOf modIdx != Integer or modIdx < 1 do return false
	if g_orm_result == undefined do return false
	if modIdx > g_orm_result.modDataList.count do return false
	local sts = ORM_getEnabledStates modIdx
	if sts.count < 2 do return false
	local f = sts[1]
	for e in sts do if e != f do return true
	false
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
			try ( setProperty target propNameStr value ) catch ( ORM_logExcept ("setProp " + propNameStr) (getCurrentException() as string) )
	)
)

-- Построение строк списка: модификаторы сверху (порядок стека), baseobject ПОСЛЕДНИМ внизу.
-- Состояние enabled — ИКОНКОЙ глаза в начале строки (owner-draw, не текст).
-- Единая точка: используется и при полном refresh (ORM_refreshUI), и при открытии окна (ORM_showUI).
fn ORM_buildListItems result =
(
	local listItems = #()
	g_orm_listItems = #()
	g_orm_listIcons = #()
	g_orm_listFlags = #()
	if result == undefined do return listItems
	g_orm_uniqueObjs = result.uniqueObjs
	for mi2 = 1 to result.modDataList.count do
	(
		local md = result.modDataList[mi2]
		-- Иконка глаза: 9 — открытый (все вкл), 10 — закрытый (все выкл), 11 — смешанный
		local eyeIdx = 9
		local sts = ORM_getEnabledStates mi2
		local refEn = undefined
		local isMixed = false
		local allOff = true
		for e in sts do
		(
			if refEn == undefined do refEn = e
			if e != refEn do isMixed = true
			if e do allOff = false
		)
		if sts.count > 0 and allOff do eyeIdx = 10
		if isMixed do eyeIdx = 11
		-- Инстанс: у всех выделенных объектов это один и тот же общий инстанс модификатора
		local isInst = false
		if g_orm_uniqueObjs.count > 1 then
		(
			local m1 = ORM_resolveTarget g_orm_uniqueObjs[1] mi2
			if m1 != undefined then
			(
				isInst = true
				for k = 2 to g_orm_uniqueObjs.count do
				(
					local mk = ORM_resolveTarget g_orm_uniqueObjs[k] mi2
					if mk == undefined or mk != m1 do ( isInst = false; exit )
				)
			)
		)
		local label = md.displayName
		if md.lowerCount > 0 do
			label += "  (x" + (md.lowerCount + 1) as string + ")"
		append listItems label
		append g_orm_listItems #("mod", mi2)
		append g_orm_listIcons eyeIdx
		append g_orm_listFlags isInst
	)
	if result.baseObjData != undefined do
	(
		local bd = result.baseObjData
		local baseLabel = if bd.isMixed then
			"Base: MIXED" + (if bd.commonSuper != undefined then " (" + bd.commonSuper + ")" else "")
		else
			("Base: " + (bd.objClass as string))
		append listItems baseLabel
		append g_orm_listItems #("base", 0)
		append g_orm_listIcons 0
		append g_orm_listFlags false
	)
	if listItems.count == 0 do
	(
		listItems = #("No Match")
		g_orm_listItems = #()
		g_orm_listIcons = #()
		g_orm_listFlags = #()
	)
	listItems
)

-- Пересборка ТОЛЬКО строк списка (метки enabled в начале), выделение сохраняется.
-- Отдельного колбэка на смену enabled в Max НЕТ (только pre/postModifierAdded|Deleted),
-- поэтому после ORM_toggleModifier обновляемся явно.
fn ORM_refreshList =
(
	if g_orm_rollMods == undefined or g_orm_result == undefined do return false
	local lb = g_orm_rollMods.lst_mods
	local selIdx0 = lb.SelectedIndex
	ORM_listSetItems (ORM_buildListItems g_orm_result)
	if selIdx0 >= 0 and selIdx0 < lb.Items.Count do
		lb.SelectedIndex = selIdx0
	true
)

fn ORM_deleteModifier modClass =
(
	if not (ORM_validTargets()) do ( ORM_refreshUI quiet:true; return false )
	undo "ModPropsLister Delete Modifier" on
	(
		with redraw off
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
)

-- Вкл/выкл верхний экземпляр модификатора данного класса на всех объектах
fn ORM_toggleModifier modClass state =
(
	if not (ORM_validTargets()) do ( ORM_refreshUI quiet:true; return false )
	-- Подавляем лишние крас всех вьюпортов: каждый .enabled= заново пересчитывает стек.
	local applied = false
	with redraw off
	(
		for obj in g_orm_uniqueObjs do
		(
			if not (isValidNode obj) do continue
			for i = 1 to obj.modifiers.count do
				if classOf obj.modifiers[i] == modClass do
				(
					try ( obj.modifiers[i].enabled = state ) \
						catch ( ORM_logExcept ("toggle " + (modClass as string)) (getCurrentException() as string) )
					applied = true
					exit
				)
		)
	)
	-- Глазок и rollups на Modify-панели не перечитываются сами после скриптового
	-- изменения enabled — обновляем панель один раз, если она открыта.
	if applied do ORM_refreshModPanel()
	applied
)

-- Обновляет модификационную панель (Modify) после изменения стека скриптом.
-- Callback'а на смену enabled в Max нет, поэтому панель повторно открываем на
-- том же объекте/модификаторе. Документация (Command Panels, modPanel):
--  * getCurrentObject() возвращает undefined, если панель Modify НЕ открыта —
--    в этом случае ничего не делаем;
--  * setCurrentObject <obj> node:<node> ui:true — открывает стек указанного
--    узла на этом объекте, ui:true переводит командную панель в режим Modify.
-- setCurrentObject сужает выделение до одного узла, поэтому исходный выбор
-- восстанавливаем; на время этого прикрываемся g_orm_refreshing, чтобы колбэк
-- selectionSetChanged не пересобрал наш список.
fn ORM_refreshModPanel =
(
	if not (ORM_validTargets()) do return false
	local curObj = modPanel.getCurrentObject()
	if curObj == undefined do return false
	local savedSel = selection as array
	if savedSel.count == 0 do return false
	-- Узел, которому принадлежит показываемый панелью объект. Узлы направленных
	-- инстансов общие, но на всякий случай ищем владельца: иначе не рискуем
	-- перещёлкивать панель на чужой стек.
	local panelOwner = undefined
	if isKindOf curObj Node do panelOwner = curObj
	for obj in g_orm_uniqueObjs do
	(
		if panelOwner != undefined do exit
		if curObj == obj.baseObject do ( panelOwner = obj; exit )
		for m in obj.modifiers do
			if m == curObj do ( panelOwner = obj; exit )
	)
	if panelOwner == undefined do return false
	g_orm_refreshing = true
	try ( modPanel.setCurrentObject curObj node:panelOwner ui:true ) \
		catch ( ORM_logExcept "setCurrentObject" (getCurrentException() as string) )
	try ( select savedSel ) \
		catch ( ORM_logExcept "select" (getCurrentException() as string) )
	g_orm_refreshing = false
	true
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
			try ( append vals (getProperty target propName) ) \
				catch ( ORM_logExcept ("collect " + propName) (getCurrentException() as string) )
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

-- Медиана: для чисел — классическая; для булевых — большинство голосов (true если больше половины).
fn ORM_medianValues vals =
(
	if vals.count == 0 do return undefined
	if classOf vals[1] == BooleanClass then
	(
		local t = 0
		for v in vals do if v do t += 1
		return (t * 2 > vals.count)
	)
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
		#median: ( ORM_medianValues vals )
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

-- Групповой undo: первый changed открывает theHold (ORM_gestureBegin), значение
-- применяется ВНУТРЬ открытого hold (записывается в него); событие спиннера
-- `entered` на отпускании закроет его одним undo-шагом (ORM_gestureCommit).
-- Чекбокс — ДИСКРЕТНОЕ действие (клик = одно изменение, нет группировки):
-- дискретная запись явной undo-клаузой, без hold.
fn ORM_propChanged propNameStr val =
(
	-- Групповой режим (Incremental/Scale, см. g_orm_incrMap): спиннер показывает фактор
	-- (дельту, старт 0, или процент, старт 100), изменение уходит в ORM_applyTick.
	if ORM_incrFind propNameStr != undefined do return (ORM_applyTick propNameStr val)
	local lookup = ORM_lookupFind propNameStr
	if lookup == undefined do return false
	local modIdx    = lookup[2]
	local realName  = lookup[3]
	if classOf val == BooleanClass do
	(
		undo "ModPropsLister Toggle" on ( ORM_applyProperty modIdx realName val )
		return true
	)
	local value = val
	if classOf val == String do
		try ( value = val as float ) catch ( value = val )
	ORM_gestureBegin label:"ModPropsLister Edit"
	ORM_applyProperty modIdx realName value
	true
)

-- Цвет — тоже ДИСКРЕТНОЕ действие (смена в диалоге = одна запись, группировки нет):
-- явная undo-клауза на каждое событие changed.
fn ORM_propColorChanged propNameStr val =
(
	local lookup = ORM_lookupFind propNameStr
	if lookup == undefined do return false
	undo "ModPropsLister Color" on ( ORM_applyProperty lookup[2] lookup[3] val )
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
		try ( currentVal = getProperty target realName ) catch ( ORM_logExcept "readVal" (getCurrentException() as string) )
	if currentVal == undefined do currentVal = [0,0,0]

	case component of
	(
		"x": currentVal.x = val as float
		"y": currentVal.y = val as float
		"z": currentVal.z = val as float
	)
	ORM_gestureBegin label:"ModPropsLister Point3"
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
	if c != undefined do c.enabled = true
	local b = ORM_ctrlByName rl (main + "_mk")
	if b != undefined do b.visible = false
	for comp in #("x", "y", "z") do
	(
		local cc = ORM_ctrlByName rl (main + "_" + comp)
		if cc != undefined do cc.enabled = true
	)
)

-- После применения «общего» значения обновляем ОТОБРАЖЕНИЕ контрола,
-- чтобы он не оставался со старым значением из времени создания rollout'а
-- (например, галочка checkbox, если применяли Disable/Enable).
-- Программная установка .value/.color/.checked тоже генерит `changed` — чтобы
-- она НЕ начала групповой undo, глушим её флагом g_orm_uiSuppress (см. codeStr).
fn ORM_syncCtrlValue prefix realName val =
(
	local rl = g_orm_rlProps
	if rl == undefined do return false
	local main = prefix + realName
	g_orm_uiSuppress = true
	if classOf val == Point3 then
	(
		for comp in #("x", "y", "z") do
		(
			local cc = ORM_ctrlByName rl (main + "_" + comp)
			if cc != undefined do
				cc.value = case comp of ( "x": val.x; "y": val.y; "z": val.z )
		)
		g_orm_uiSuppress = false
		return true
	)
	local c = ORM_ctrlByName rl main
	if c != undefined do
	(
		case classOf val of
		(
			BooleanClass: c.checked = val
			Integer:      c.value  = val
			Float:        c.value  = val
			Double:       c.value  = val
			Color:        c.color  = val
		)
	)
	g_orm_uiSuppress = false
	true
)

-- Применяет вычисленное «общее» значение (по выбранному из контекстного меню)
fn ORM_applyCommon lookupKey mode =
(
	local lookup = ORM_lookupFind lookupKey
	if lookup == undefined do return false
	local modIdx   = lookup[2]
	local realName = lookup[3]
	local prefix   = lookup[4]

	local val = case mode of
	(
		#enable:  true
		#disable: false
		default:  ORM_commonValue modIdx realName mode
	)
	if val == undefined do return false

	undo "ModPropsLister Unify" on
	(
		ORM_applyProperty modIdx realName val
	)

	-- Отмечаем свойство как «одинаковое» в данных, чтобы UI не предлагал снова
	if modIdx == 0 and g_orm_result.baseObjData != undefined then
	(
		for p in g_orm_result.baseObjData.props do
			if (p.name as string) == realName do ( p.allSame = true; p.value = val; exit )
	)
	else if modIdx > 0 then
	(
		for md in g_orm_result.modDataList do
			for p in md.props do
				if (p.name as string) == realName do ( p.allSame = true; p.value = val; exit )
	)

	-- Активируем контрол, прячем кнопку «Сделать общим» и обновляем отображение значения
	ORM_enableAfterCommon prefix realName
	ORM_syncCtrlValue prefix realName val

	true
)

-- ======================================================================
-- ГРУППОВОЙ UNDO: одно действие Undo от НАЖАТИЯ до ОТПУСКАНИЯ мыши на спиннере.
-- Первый `changed` открывает theHold.Begin(), `entered` (отпускание/Enter)
-- закрывает theHold.Accept — 3ds Max сам группирует всё в одну undo-запись.
-- Правый клик (entered inCancel:true) — theHold.Cancel(). theHold — прямые
-- пробросы SDK без защиты, поэтому Begin/Accept/Cancel обёрнуты в try/catch.
-- ======================================================================

-- Первый тик изменения открывает hold; следующие тики пишут в уже открытый.
-- Если снаружи уже идёт другая операция (theHold.Holding()) — свой hold не
-- открываем (изменения запишутся во внешний, закрывать его не наша забота).
fn ORM_gestureBegin label: =
(
	if label != undefined do g_orm_incrUndoLabel = label
	if g_orm_gestureActive do return true
	if theHold.Holding() do return true
	try ( theHold.Begin() ) catch ( ORM_logExcept "gestureBegin" (getCurrentException() as string); return false )
	g_orm_gestureActive = true
	true
)

-- Завершение группового undo (событие спиннера `entered`, а также rebuild/close/refresh):
-- Accept — одна undo-запись на весь цикл нажатие-отпускание, inCancel:true — откат через Cancel.
fn ORM_gestureCommit inCancel:false =
(
	if not g_orm_gestureActive do return true
	g_orm_gestureActive = false
	if not theHold.Holding() do return true
	try
	(
		if inCancel then theHold.Cancel() else theHold.Accept g_orm_incrUndoLabel
	)
	catch ( ORM_logExcept "gestureCommit" (getCurrentException() as string) )
	true
)

-- Групповой режим: снапшот базовых значений свойства со всех объектов.
-- Возвращает запись g_orm_incrMap (см. её комментарий) или undefined, если режим не активен.
fn ORM_incrFind lookupKey =
(
	for item in g_orm_incrMap do
		if item[1] == lookupKey do return item
	undefined
)

-- Начать групповой режим для свойства: запомнить текущие значения каждого объекта
-- и активировать спиннер со стартовым фактором (0 — приращение, 100% — масштаб).
-- mode: #incr = спиннер прибавляет дельту к базе, #scale = умножает базы на значение/100.
-- Кнопка Unify НЕ прячется: её видимость показывает, что значения всё ещё разные.
fn ORM_incrBegin lookupKey mode:#incr =
(
	local lookup = ORM_lookupFind lookupKey
	if lookup == undefined do return false
	local modIdx   = lookup[2]
	local realName = lookup[3]
	local prefix   = lookup[4]

	local pairs = #()
	for obj in g_orm_uniqueObjs do
	(
		if not (isValidNode obj) do continue
		local target
		try ( target = ORM_resolveTarget obj modIdx ) catch ( target = undefined )
		if target == undefined do continue
		local v
		try ( v = getProperty target realName ) catch ( v = undefined )
		if v != undefined do append pairs #(obj, v, modIdx, realName)
	)
	if pairs.count == 0 do return false

	-- Держим по одному снапшоту на ключ, старые ключи не трогаем
	g_orm_incrMap = for item in g_orm_incrMap where item[1] != lookupKey collect item
	append g_orm_incrMap #(lookupKey, pairs, mode)

	-- Активируем спиннер (при differ он создан enabled:false) и ставим стартовый фактор.
	-- Программная установка .value стреляет `changed` (фактор «ничего не меняет» нельзя
	-- применять) — глушим, чтобы не начать групповой undo.
	local main = prefix + realName
	local c = ORM_ctrlByName g_orm_rlProps main
	if c != undefined do
	(
		c.enabled = true
		g_orm_uiSuppress = true
		c.value = if mode == #scale then 100 else 0
		g_orm_uiSuppress = false
	)
	true
)

-- Применить фактор к базовым значениям каждого объекта.
-- #incr:  новое = база + d
-- #scale: новое = база * (d / 100)
-- Вызывается прямо ВНУТРЬ открытого theHold (ORM_applyTick): всё накопленное
-- за цикл нажатие-отпускание «запомнит» ORM_gestureCommit (entered спиннера)
-- одной undo-записью. Сама функция без undo-клаузы — записывается ровно тем hold,
-- что держим.
fn ORM_incrApplyPairs lookupKey d =
(
	local item = ORM_incrFind lookupKey
	if item == undefined do return false
	local pairs   = item[2]
	local isScale = (item[3] == #scale)
	local addend = if isScale then 0.0 else (d as float)
	local mult   = if isScale then (d as float) / 100.0 else 1.0
	if not (ORM_validTargets()) do ( ORM_refreshUI quiet:true; return false )
	for pair in pairs do
	(
		local obj    = pair[1]
		local base   = pair[2]
		local modIdx = pair[3]
		local realNm = pair[4]
		if not (isValidNode obj) do continue
		local target
		try ( target = ORM_resolveTarget obj modIdx ) catch ( target = undefined )
		if target == undefined do continue
		local newVal
		try
		(
			newVal = case classOf base of
			(
				Integer: ( ( (base as float) * mult ) + addend ) as integer
				Float:   ( ( (base as float) * mult ) + addend ) as float
				Double:  ( ( (base as double) * mult ) + addend ) as double
				default: base
			)
			setProperty target realNm newVal
		)
		catch ( ORM_logExcept "applyIncr" (getCurrentException() as string) )
	)
	true
)

-- Тик группового режима: фактор применяется ВНУТРЬ открытого theHold (ORM_gestureBegin),
-- `entered` спиннера закроет его одним undo-шагом.
-- Стартовый фактор игнорируем (дельту 0 / 100% — они ничего не меняют).
fn ORM_applyTick lookupKey val =
(
	local item = ORM_incrFind lookupKey
	if item == undefined do return true
	local isScale = (item[3] == #scale)
	local d = try ( val as float ) catch ( ( ORM_logExcept "incrDelta" (getCurrentException() as string); undefined ) )
	if d == undefined do return true
	if isScale then
		( if (abs (d - 100.0)) < 0.0001 do return true )
	else
		( if d == 0 do return true )
	ORM_gestureBegin label:(if isScale then "ModPropsLister Scale" else "ModPropsLister Incremental")
	ORM_incrApplyPairs lookupKey d
	true
)

-- Тип свойства по lookupKey (из данных текущего результата)
fn ORM_ctxPtype lookupKey =
(
	local lookup = ORM_lookupFind lookupKey
	if lookup == undefined do return undefined
	local modIdx   = lookup[2]
	local realName = lookup[3]
	local theProps = undefined
	if modIdx == 0 then
	(
		if g_orm_result != undefined and g_orm_result.baseObjData != undefined do
			theProps = g_orm_result.baseObjData.props
	)
	else
	(
		if g_orm_result != undefined and modIdx <= g_orm_result.modDataList.count do
			theProps = g_orm_result.modDataList[modIdx].props
	)
	if theProps == undefined do return undefined
	for p in theProps do
		if (p.name as string) == realName do return p.ptype
	undefined
)


-- ======================================================================
-- КОНТЕКСТНЫЕ МЕНЮ «СДЕЛАТЬ ОБЩИМ» (rcmenu на уровне макроса)
-- Набор пунктов зависит от ТИПА свойства (см. ORM_onMakeCommon):
--   числовое (float/integer/double): максимум/среднее/медиана/минимум/большинство + Incremental + Scale
--   boolean: включить/выключить/большинство/медиана (арифметика с булевым невозможна)
--   color/point3: среднее/большинство (медиана и min/max через as float невозможны)
--   строки/прочее: только большинство
-- g_orm_ctxKey — lookupKey свойства, по которому открыто меню.
-- rmc_* объявлены global, т.к. вызываются из global-функций ORM_onMakeCommon/ORM_incrBegin.

global rmc_num_common

rcmenu rmc_num_common (
	menuItem nc_max  "Maximum"
	menuItem nc_avg  "Average"
	menuItem nc_med  "Median"
	menuItem nc_min  "Minimum"
	menuItem nc_mode "Most common"
	separator nc_sep
	menuItem nc_incr  "Incremental"
	menuItem nc_scale "Scale"

	on nc_max   picked do ORM_applyCommon g_orm_ctxKey #max
	on nc_avg   picked do ORM_applyCommon g_orm_ctxKey #avg
	on nc_med   picked do ORM_applyCommon g_orm_ctxKey #median
	on nc_min   picked do ORM_applyCommon g_orm_ctxKey #min
	on nc_mode  picked do ORM_applyCommon g_orm_ctxKey #mode
	on nc_incr  picked do ORM_incrBegin g_orm_ctxKey mode:#incr
	on nc_scale picked do ORM_incrBegin g_orm_ctxKey mode:#scale
)

global rmc_bool_common

rcmenu rmc_bool_common (
	menuItem bc_on   "Enable"
	menuItem bc_off  "Disable"
	menuItem bc_mode "Most common"
	menuItem bc_med  "Median"

	on bc_on   picked do ORM_applyCommon g_orm_ctxKey #enable
	on bc_off  picked do ORM_applyCommon g_orm_ctxKey #disable
	on bc_mode picked do ORM_applyCommon g_orm_ctxKey #mode
	on bc_med  picked do ORM_applyCommon g_orm_ctxKey #median
)

global rmc_vec_common

rcmenu rmc_vec_common (
	menuItem vc_avg  "Average"
	menuItem vc_mode "Most common"

	on vc_avg  picked do ORM_applyCommon g_orm_ctxKey #avg
	on vc_mode picked do ORM_applyCommon g_orm_ctxKey #mode
)

global rmc_mode_common

rcmenu rmc_mode_common (
	menuItem mc_mode "Most common"

	on mc_mode picked do ORM_applyCommon g_orm_ctxKey #mode
)

-- Контекстное меню кнопки On/Off при СМЕШАННОМ состоянии модификатора
-- (часть объектов вкл, часть выкл): клик по глазу не переключает вслепую,
-- а спрашивает, что применить. Вызывается из обработчика кнопки в rollout_mods.
global rmc_toggle

rcmenu rmc_toggle (
	menuItem tm_enable "Enable"
	menuItem tm_disable "Disable"

	on tm_enable  picked do ORM_toggleSelected true
	on tm_disable picked do ORM_toggleSelected false
)

-- Открывает контекстное меню «Сделать общим»: набор пунктов зависит от типа свойства,
-- чтобы не предлагать арифметику, которая для boolean/color/point3/строк бросает ошибку.
fn ORM_onMakeCommon lookupKey =
(
	g_orm_ctxKey = lookupKey
	local menu = case ORM_ctxPtype lookupKey of
	(
		#float:   rmc_num_common
		#integer: rmc_num_common
		#double:  rmc_num_common
		#boolean: rmc_bool_common
		#color:   rmc_vec_common
		#point3:  rmc_vec_common
		default:  rmc_mode_common
	)
	popUpMenu menu
	true
)


-- ======================================================================
-- UI: ВЫБОР ЭЛЕМЕНТА СПИСКА / REBUILD
-- ======================================================================

-- Синхронизация кнопки On: состояние (checked) + иконка (caption).
-- Вызывается везде, где меняется checked, чтобы интерфейс не расходился
-- с реальным состоянием модификатора.
fn ORM_setToggleUI state mixedState:false =
(
	if g_orm_rollMods == undefined do return false
	local bt = g_orm_rollMods.btn_toggle
	-- Иконка глаза: 9 (открытый, вкл) / 10 (закрытый, выкл) / 11 (смешанный).
	-- При mixedState меняем images всех состояний на кадр смешанного глаза.
	-- Число кадров берём из загруженных g_orm_iconFrames (путь: ORM_initModList
	-- грузит и режет bmp ДО первого вызова setToggleUI); если кадры не загружены —
	-- не трогаем images (контрол создан с корректным locIconCount в rollout-определении).
	local cnt = 0
	if g_orm_iconFrames != undefined do
		try ( cnt = g_orm_iconFrames.count ) catch ( ORM_logExcept "iconFrames" (getCurrentException() as string) )
	if cnt >= 1 then try (
		bt.images = if mixedState then \
			#(icon_path, undefined, cnt, 11, 11, 11, 11, true) \
		else \
			#(icon_path, undefined, cnt, 10, 9, 9, 9, true)
	)
	catch ( ORM_logExcept "setImages" (getCurrentException() as string) )
	bt.checked = state
	true
)

-- Фильтр по типам (галочки под списком). Синхронизация UI <-> глобальное состояние.
fn ORM_setFilterUI =
(
	if g_orm_rollMods == undefined do return false
	if classOf g_orm_typeFilter != Array or g_orm_typeFilter.count != 5 do
		g_orm_typeFilter = #(false, false, false, false, false)
	g_orm_syncFilter = true
	try
	(
		g_orm_rollMods.chk_geom.checked   = g_orm_typeFilter[1]
		g_orm_rollMods.chk_shape.checked  = g_orm_typeFilter[2]
		g_orm_rollMods.chk_light.checked  = g_orm_typeFilter[3]
		g_orm_rollMods.chk_camera.checked = g_orm_typeFilter[4]
		g_orm_rollMods.chk_helper.checked = g_orm_typeFilter[5]
	)
	catch
	(
		if g_orm_debug do format "ModPropsLister: setFilterUI failed: %\n" (getCurrentException() as string)
	)
	g_orm_syncFilter = false
	true
)

-- При изменении фильтра пересчитываем анализ текущего выделения
-- (работаем только с внутренними массивами, сценное выделение НЕ трогаем)
fn ORM_onFilterChanged =
(
	if g_orm_syncFilter do return false
	g_orm_typeFilter = #(
		g_orm_rollMods.chk_geom.checked,
		g_orm_rollMods.chk_shape.checked,
		g_orm_rollMods.chk_light.checked,
		g_orm_rollMods.chk_camera.checked,
		g_orm_rollMods.chk_helper.checked
	)
	if g_orm_saveFilter do ORM_saveFloaterState()
	ORM_refreshUI autoSel:true
	true
)

fn ORM_onListSelect idx =
(
	-- guard ДО индексации: listbox может прислать idx=0 (сброс при смене items),
	-- а g_orm_listItems[0] бросает "array index must be positive number" (см. архитектура п. 2)
	if classOf idx != Integer or idx < 1 do return false
	local info = g_orm_listItems[idx]
	if classOf info != Array do return false
	g_orm_selInfo = info
	ORM_rebuildPropsRollout()
	-- Кнопки On и Delete активны ТОЛЬКО для модификатора,
	-- для baseobject — неактивны (см. архитектура п. 2): базу нельзя ни выключить, ни удалить
	if info[1] == "mod" and info[2] <= g_orm_result.modDataList.count then
	(
		g_orm_rollMods.btn_toggle.enabled = true
		g_orm_rollMods.btn_delete.enabled = true
		ORM_setToggleUI (ORM_getLiveEnabled info[2]) mixedState:(ORM_isMixedEnabled info[2])
	)
	else
	(
		g_orm_rollMods.btn_toggle.enabled = false
		g_orm_rollMods.btn_delete.enabled = false
		ORM_setToggleUI false
	)
	true
)

-- Вкл/выкл выбранного модификатора (кнопка On/Off)
fn ORM_toggleSelected st =
(
	if classOf g_orm_selInfo != Array or g_orm_selInfo.count == 0 do return false
	if g_orm_selInfo[1] != "mod" do return false
	if not (ORM_validTargets()) do ( ORM_refreshUI(); return false )
	local modDataIdx = g_orm_selInfo[2]
	if modDataIdx < 1 or modDataIdx > g_orm_result.modDataList.count do return false
	local cls = g_orm_result.modDataList[modDataIdx].modClass
	ORM_toggleModifier cls st
	-- Колбэка на смену enabled в Max нет — пересобираем метки списка явно
	ORM_refreshList()
	true
)

-- Очистка интерфейса: старые данные не показываем, когда выделение снято (см. архитектура п. 8)
fn ORM_clearUI msg:"No selection." =
(
	local changed = false
	if g_orm_rollMods != undefined do
	(
		local lb = g_orm_rollMods.lst_mods
		local oldCnt = lb.Items.Count
		local oldText = ""
		if oldCnt == 1 do try ( oldText = lb.Items.Item[0] as string ) \
			catch ( ORM_logExcept "listItemRead" (getCurrentException() as string) )
		if oldCnt != 1 or oldText != msg do
		(
			ORM_listSetItems #(msg)
			changed = true
		)
		g_orm_rollMods.lst_mods.SelectedIndex = -1
		ORM_setToggleUI false
		g_orm_rollMods.btn_toggle.enabled = false
		g_orm_rollMods.btn_delete.enabled = false
	)
	g_orm_listItems = #()
	g_orm_listIcons = #()
	g_orm_listFlags = #()
	g_orm_selInfo = #()
	g_orm_lastSelKey = ""
	g_orm_modClasses = #()
	ORM_gestureCommit()
	g_orm_incrMap = #()

	if g_orm_rlProps != undefined and g_orm_floater != undefined do
	(
		try ( removeRollout g_orm_rlProps g_orm_floater ) \
			catch ( ORM_logExcept "removeRollout" (getCurrentException() as string) )
		try ( destroyDialog g_orm_rlProps ) \
			catch ( ORM_logExcept "destroyProps" (getCurrentException() as string) )
		g_orm_rlProps = undefined
		changed = true
	)
	changed
)

-- Обновление интерфейса на месте (без перезапуска макроса, см. архитектура п. 2)
-- Если выделение снято/недостаточно — чистим интерфейс (старые данные не показываем, см. архитектура п. 8)
fn ORM_refreshUI quiet:false autoSel:false =
(
	-- Безопасность для callbacks: если floater уже закрыт — не трогаем UI (см. архитектура п. 3)
	if g_orm_floater == undefined or g_orm_rollMods == undefined do return false

	-- Запоминаем выбранный элемент, чтобы сохранить контекст при автозамёте.
	-- wasLabel: текст строки — она и будет критерием «имя совпадает» при восстановлении.
	-- wasSel: кортеж (#("mod", mi) / #("base", 0)) берём напрямую из ЖИВОГО списка
	-- (глобал g_orm_selInfo оказался ненадёжным — в дебаге держал ok вместо массива).
	local prevIdx0 = g_orm_rollMods.lst_mods.SelectedIndex   -- 0-based, -1 = ничего не выбрано
	local wasSel = undefined
	local wasLabel = ""
	if prevIdx0 >= 0 and prevIdx0 < g_orm_listItems.count do
		wasSel = deepcopy g_orm_listItems[prevIdx0 + 1]
	if prevIdx0 >= 0 and prevIdx0 < g_orm_rollMods.lst_mods.Items.Count do
		wasLabel = try ( g_orm_rollMods.lst_mods.Items.Item[prevIdx0] as string ) catch ( "" )
	if g_orm_debug do
		format "ModPropsLister[refresh]: STEP 1 capture — prevIdx0=% Items.Count=% wasLabel='%' wasSel=% wasSelCnt=% g_orm_selInfo=%\n" \
			prevIdx0 g_orm_rollMods.lst_mods.Items.Count wasLabel wasSel \
			(if classOf wasSel == Array then wasSel.count else 0) (g_orm_selInfo as string)

	local sel = selection as array
	local validCount = 0
	for o in sel do if isValidNode o do validCount += 1

	-- Выделение снято или один объект: очищаем интерфейс с соответствующим сообщением
	if validCount < 2 do
	(
		local msg = if validCount < 1 then "No selection." else "Single Selection"
		if ORM_clearUI msg:msg do ORM_updateFloaterHeight()
		return true
	)

	local result = ORM_analyzeSelection sel
	if result == undefined do
	(
		if ORM_clearUI msg:"No Match" do ORM_updateFloaterHeight()
		return true
	)

	g_orm_result = result
	g_orm_uniqueObjs = result.uniqueObjs
	g_orm_modClasses = for m in result.modDataList collect m.modClass
	g_orm_selInfo = #()

	-- Строки списка (символ enabled в начале; см. архитектура п. 1/2)
	local listItems = ORM_buildListItems result

	-- Обновляем listbox без пересоздания floater
	ORM_listSetItems listItems
	ORM_setToggleUI false
	g_orm_rollMods.btn_toggle.enabled = false
	g_orm_rollMods.btn_delete.enabled = false
	if g_orm_debug do
		format "ModPropsLister[refresh]: STEP 2 rebuilt — g_orm_listItems.count=% listItems.count=% (SelectedIndex now %)\n" \
			g_orm_listItems.count listItems.count g_orm_rollMods.lst_mods.SelectedIndex

	-- Убираем rollout свойств из floaterа, если он был (removeRollout, а не только destroyDialog)
	if g_orm_rlProps != undefined and g_orm_floater != undefined do
	(
		try ( removeRollout g_orm_rlProps g_orm_floater ) \
			catch ( ORM_logExcept "removeRollout" (getCurrentException() as string) )
		try ( destroyDialog g_orm_rlProps ) \
			catch ( ORM_logExcept "destroyProps" (getCurrentException() as string) )
		g_orm_rlProps = undefined
	)
	g_orm_lastSelKey = ""

	-- При изменении выделения сразу выделяем первый элемент списка:
	-- это верхний модификатор стека, его свойства открываются сразу (см. архитектура п. 2).
	-- SelectedIndex вызывает SelectedIndexChanged → ORM_listSelectChanged → ORM_onListSelect.
	if autoSel then
	(
		if g_orm_listItems.count > 0 do
			g_orm_rollMods.lst_mods.SelectedIndex = 0
	)
	else if classOf wasSel == Array and wasSel.count > 0 then
	(
		-- Восстанавливаем выбор ТОЛЬКО если на той же позиции (i) и имя строки (label)
		-- совпадает с сохранённым: позиция могла сдвинуться, а modDataIdx — указывать
		-- на другой модификатор после изменения стека.
		local restored = false
		for i = 1 to g_orm_listItems.count do
			if g_orm_listItems[i][1] == wasSel[1] and g_orm_listItems[i][2] == wasSel[2] \
				and listItems[i] == wasLabel do
			(
				-- SelectedIndex вызывает SelectedIndexChanged → ORM_listSelectChanged →
				-- ORM_onListSelect → ORM_rebuildPropsRollout (свойства выбранного модификатора).
				g_orm_rollMods.lst_mods.SelectedIndex = i - 1
				restored = true
				if g_orm_debug do
					format "ModPropsLister[refresh]: RESTORED row=% label='%'\n" (i - 1) listItems[i]
				exit
			)
		if not restored do
		(
			local doPrint = g_orm_debug
			if doPrint do
			(
				local labelMatch = -1
				local typeMatch = -1
				for i = 1 to listItems.count do
				(
					if listItems[i] == wasLabel do ( if labelMatch < 0 do labelMatch = i )
					if g_orm_listItems[i][1] == wasSel[1] and g_orm_listItems[i][2] == wasSel[2] do ( if typeMatch < 0 do typeMatch = i )
				)
				format "ModPropsLister[refresh]: NOT restored — wasLabel='%' labelMatch=% typeMatch=% want=%/% items=%\n" \
					wasLabel labelMatch typeMatch (wasSel[1] as string) (wasSel[2] as string) listItems.count
				for i = 1 to listItems.count do
					format "    [%] '%' %/%\n" (i - 1) listItems[i] (g_orm_listItems[i][1] as string) (g_orm_listItems[i][2] as string)
			)
		)
	)
	else if g_orm_debug do
		format "ModPropsLister[refresh]: STEP 3 no selInfo to restore (wasSel empty, autoSel=%)\n" autoSel

	-- Автовысота под текущий набор свитков
	ORM_updateFloaterHeight()
	if g_orm_debug do
		format "ModPropsLister[refresh]: STEP 4 final — SelectedIndex=% Items.Count=%\n" \
			g_orm_rollMods.lst_mods.SelectedIndex g_orm_rollMods.lst_mods.Items.Count

	true
)

-- Полный пересоздание floater (используется при первом показе)
fn ORM_rebuildNow =
(
	ORM_refreshUI()
)

-- Обёртка для колбэков с защитой от рекурсии (см. архитектура п. 3)
-- Колбэки срабатывают очень часто; повторный вход (например, потому что сам
-- refresh меняет выбор/стек, что вновь вызывает колбэк) обрываем на месте.
-- При ошибке печатаем стек через ErrorDump.ms и УДАЛЯЕМ колбэки (self-unregister):
-- разовый сбой (например, после закрытия окна) не должен оставлять «зомби»-колбэки,
-- спамящие ошибками. Перезапуск окна заново регистрирует колбэки в ORM_showUI.
fn ORM_cbRefresh autoSel:false =
(
	if g_orm_refreshing do return false
	g_orm_refreshing = true
	try
	(
		ORM_refreshUI quiet:true autoSel:autoSel
	)
	catch
	(
		try ( fileIn "ErrorDump.ms" ) \
		catch ( ORM_logExcept "errorDumpLoad" (getCurrentException() as string) )
		if classOf FmtError == MAXScriptFunction then
			print ("ModPropsLister: callback error:\n" + (FmtError stackLevels:4))
		else
			print ("ModPropsLister: callback error: " + (getCurrentException() as string))
		try ( callbacks.removeScripts id:#ModPropsLister ) \
		catch ( ORM_logExcept "removeCallbacks" (getCurrentException() as string) )
		if g_orm_debug do
			format "ModPropsLister: callbacks removed after error (id:#ModPropsLister)\n"
	)
	g_orm_refreshing = false
	true
)

-- Автозамёты: пересборка при изменении выделения или стека модификаторов (см. архитектура п. 3)
-- Функции вызываются global (доступны из контекста callback). id гарантирует отсутствие дублей.
fn ORM_registerCallbacks =
(
	try ( callbacks.removeScripts id:#ModPropsLister ) \
		catch ( ORM_logExcept "removeCallbacks" (getCurrentException() as string) )
	callbacks.addScript #selectionSetChanged       "ORM_cbRefresh autoSel:true" id:#ModPropsLister
	callbacks.addScript #postModifierAdded         "ORM_cbRefresh()" id:#ModPropsLister
	callbacks.addScript #postModifierDeleted       "ORM_cbRefresh()" id:#ModPropsLister
)

fn ORM_unregisterCallbacks =
(
	try ( callbacks.removeScripts id:#ModPropsLister ) \
		catch ( ORM_logExcept "removeCallbacks" (getCurrentException() as string) )
)

-- Закрытие диалога + floater
fn ORM_closeDialog =
(
	ORM_gestureCommit()
	ORM_unregisterCallbacks()
	try ( destroyDialog g_orm_rlProps ) \
		catch ( ORM_logExcept "destroyPropsClose" (getCurrentException() as string) )
	g_orm_rlProps = undefined
	try ( closeRolloutFloater g_orm_floater ) \
		catch ( ORM_logExcept "closeFloater" (getCurrentException() as string) )
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
		-- диапазон: зависит от величины значения (шаг — см. архитектура п. 13)
		local mag = abs (initVal as float)
		if mag < 100 do mag = 100
		local rangeMin = -mag * 50
		local rangeMax =  mag * 50
		-- Адаптивный шаг вращения (scale) до первого драга — от СТАРТОВОГО значения
		-- (1% величины, ORM_stepScale). Дальше scale живёт от buttondown, см. ниже.
		-- Для integer шаг — целый, минимум 1.
		local step = ORM_stepScale initVal
		if propInfo.ptype == #integer do step = amax 1 (ceil step)
		local typeFlag = if propInfo.ptype == #float then "#float" else "#integer"
		local acrossStr = if differing then " across:2" else ""

		rc.addControl #spinner ctrlName (pNameStr + ":") paramStr:(
			"range:[" + rangeMin as string + "," + rangeMax as string + "," + initVal as string + "] " \
			+ "type:" + typeFlag + " scale:" + step as string + " fieldWidth:75 align:#left" + disStr + acrossStr
		)
		height += 22
		if differing do
		(
			rc.addControl #button (ctrlName + "_mk") "Unify" paramStr:"width:50 height:18 align:#right tooltip:\"Make the property general\""
			rc.addHandler (ctrlName + "_mk") #pressed filter:on \
				codeStr:("if ORM_onMakeCommon \"" + lookupKey + "\" do ()")
		)
		-- Шаг спиннера ставится НА СТАРТЕ драга (buttondown): обычное вращение — адаптивный
		-- 1% от ТЕКУЩЕГО значения (ORM_stepScale), с зажатым Alt — точный шаг по формуле
		-- (abs(v)+1)/1000 (степенной: ~0.1% от величины на больших значениях, ~0.001 на малых).
		-- В Scale-режиме (см. g_orm_incrMap) контрол показывает ФАКТОР в %, а не величину:
		-- шаг тоже степенной, но ОТ базы 100 — (abs(100)+1)/1000 = 0.101 (1 единица = 0.1%),
		-- а не от средней величины параметров.
		-- Решение — в ORM_spinStep. Во время драга scale НЕ меняется (см. архитектура п. 13),
		-- поэтому value в changed не переписываем — Max сам шагает выбранным множителем.
		-- После отпускания (buttonup) scale пересчитывается под новое значение (следующий драг).
		local isInt = (propInfo.ptype == #integer)
		local castExpr = if isInt then "val" else "val as float"
		local spinStepExpr = if isInt \
			then "(amax 1 (ceil (ORM_spinStep " + ctrlName + " \"" + lookupKey + "\" alt:keyboard.altPressed)))" \
			else "(ORM_spinStep " + ctrlName + " \"" + lookupKey + "\" alt:keyboard.altPressed)"
		local spinStepUpExpr = if isInt \
			then "(amax 1 (ceil (ORM_spinStep " + ctrlName + " \"" + lookupKey + "\")))" \
			else "(ORM_spinStep " + ctrlName + " \"" + lookupKey + "\")"
		rc.addHandler ctrlName #buttondown \
			codeStr:(
				"local _s = " + spinStepExpr + "\n" +
				"ORM_setSpinnerScale " + ctrlName + " _s\n"
			)
		rc.addHandler ctrlName #buttonup \
			codeStr:("ORM_setSpinnerScale " + ctrlName + " " + spinStepUpExpr + "\n")
		rc.addHandler ctrlName #changed paramStr:"val" filter:on \
			codeStr:(
				"if g_orm_uiSuppress do return false\n" +
				"local _cv = " + castExpr + "\n" +
				"ORM_propChanged \"" + lookupKey + "\" _cv\n"
			)
		-- Завершение группового undo: entered вызывается и при отпускании мыши, и при вводе
		-- с клавиатуры (доки Spinner). ORM_gestureCommit закрывает theHold.
		rc.addHandler ctrlName #entered paramStr:"_inSpin _inCancel" \
			codeStr:("ORM_gestureCommit inCancel:_inCancel")
	)
	else if propInfo.ptype == #boolean then
	(
		local initVal = if propInfo.value != undefined then propInfo.value else false
		local acrossStr = if differing then " across:2" else ""
		-- иницилизация checkbox — декларационный ключ checked: (state: игнорируется,
		-- из-за этого галочка не ставилась даже при true)
		rc.addControl #checkbox ctrlName pNameStr paramStr:(
			"checked:" + initVal as string + " align:#left" + disStr + acrossStr
		)
		height += 22
		if differing do
		(
			rc.addControl #button (ctrlName + "_mk") "Unify" paramStr:"width:50 height:18 align:#right tooltip:\"Make the property general\""
			rc.addHandler (ctrlName + "_mk") #pressed filter:on \
				codeStr:("if ORM_onMakeCommon \"" + lookupKey + "\" do ()")
		)
		rc.addHandler ctrlName #changed paramStr:"val" filter:on \
			codeStr:("if not g_orm_uiSuppress and ORM_propChanged \"" + lookupKey + "\" val do ()")
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
			codeStr:("if not g_orm_uiSuppress and ORM_propColorChanged \"" + lookupKey + "\" " + ctrlName + ".color do ()")
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
			-- Стартовый шаг при создании: 1% от величины компонента (ORM_stepScale). В рантайме
			-- scale ставится на старте каждого драга (buttondown), см. архитектура п. 13.
			local step = ORM_stepScale compVal
			rc.addControl #spinner compCtrl compLabel paramStr:(
				"range:[-999999,999999," + compVal as string + "] " \
				+ "type:#float scale:" + step as string + " fieldWidth:55 align:#left" + disStr + acrossStr
			)
			height += 22
			if differing and ci == 1 do
			(
				rc.addControl #button (ctrlName + "_mk") "Unify" paramStr:"width:50 height:18 align:#right tooltip:\"Make the property general\""
				rc.addHandler (ctrlName + "_mk") #pressed filter:on \
					codeStr:("if ORM_onMakeCommon \"" + lookupKey + "\" do ()")
			)
			-- Scale на старте драга: обычное вращение — 1% от текущего (ORM_stepScale),
			-- с зажатым Alt — точный шаг по формуле (abs(v)+1)/1000 (степенной);
			-- во время драга scale фиксирован, value не переписываем (см. архитектура п. 13).
			rc.addHandler compCtrl #buttondown \
				codeStr:(
					"local _s = if keyboard.altPressed then ((abs (" + compCtrl + ".value as float) + 1.0) / 1000.0) else (ORM_stepScale " + compCtrl + ".value)\n" +
					"ORM_setSpinnerScale " + compCtrl + " _s\n"
				)
			rc.addHandler compCtrl #buttonup \
				codeStr:("ORM_setSpinnerScale " + compCtrl + " (ORM_stepScale " + compCtrl + ".value)\n")
			rc.addHandler compCtrl #changed paramStr:"val" filter:on \
				codeStr:(
					"if g_orm_uiSuppress do return false\n" +
					"local _cv = val as float\n" +
					"ORM_propPoint3Changed \"" + lookupKey + "\" \"" + comp + "\" _cv\n"
				)
			rc.addHandler compCtrl #entered paramStr:"_inSpin _inCancel" \
				codeStr:("ORM_gestureCommit inCancel:_inCancel")
		)
	)
)

-- Модификаторы «редактирования геометрии» (Edit Mesh / Edit Spline / Edit Poly),
-- у которых НЕТ «простых» параметров — для них показываем свиток-заглушку
-- "No adjustable parameters.", а не оставляем без свитка.
fn ORM_isEditableGeomMod modDataIdx =
(
	if g_orm_result == undefined or modDataIdx < 1 or modDataIdx > g_orm_result.modDataList.count \
		do return false
	local c = g_orm_result.modDataList[modDataIdx].modClass
	local cs = c as string
	matchpattern cs pattern:"*Edit*Mesh*" \
		or matchpattern cs pattern:"*Edit*Spline*" \
		or matchpattern cs pattern:"*Edit*Poly*"
)

-- Создаёт/пересоздаёт динамический rollout со свойствами выбранного элемента
fn ORM_rebuildPropsRollout =
(
	-- guard по типу: g_orm_selInfo может оказаться НЕ массивом (OK), см. архитектура п. 2
	if classOf g_orm_selInfo != Array or g_orm_selInfo.count == 0 do return false
	ORM_gestureCommit()
	g_orm_incrMap = #()

	-- Только пересоздавать, если выбранная запись реально поменялась (см. архитектура п. 4)
	local curKey = (g_orm_selInfo[1] as string) + "_" + (g_orm_selInfo[2] as string)
	if curKey == g_orm_lastSelKey and g_orm_rlProps != undefined do
		return true

	-- Удаляем старый rollout из floaterа (именно removeRollout, destroyDialog его не убирает из floaterа)
	if g_orm_rlProps != undefined and g_orm_floater != undefined do
	(
		try ( removeRollout g_orm_rlProps g_orm_floater ) \
			catch ( ORM_logExcept "removeRollout" (getCurrentException() as string) )
		try ( destroyDialog g_orm_rlProps ) \
			catch ( ORM_logExcept "destroyProps" (getCurrentException() as string) )
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
		local bd = g_orm_result.baseObjData
		sectionTitle = if bd.isMixed then
			"Base: MIXED" + (if bd.commonSuper != undefined then " (" + bd.commonSuper + ")" else "")
		else
			("Base: " + (bd.objClass as string))
		props = bd.props
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

	-- База и «редакторы геометрии» (Edit Mesh/Spline/Poly) без поддерживаемых свойств
	-- показываем свиток-заглушку. Прочие моды без свойств — без свитка (ничего не показываем).
	if props.count == 0 and not isBaseObj and not (ORM_isEditableGeomMod modDataIdx) do return false

	-- Средняя величина числовых параметров свитка (см. глобал g_orm_avgMag):
	-- только ненулевые значения, точка3 считается по компонентам; всё нулевое → 1.0,
	-- чтобы шаг спиннеров не схлопывался в 0.01 на пустых (нулевых) контролах.
	g_orm_avgMag = 1.0
	local avgAcc = 0.0
	local avgCnt = 0
	for p in props do
	(
		if p.value == undefined do continue
		local vals = case p.ptype of
		(
			#float:   #(p.value)
			#integer: #(p.value)
			#point3:  #(p.value.x, p.value.y, p.value.z)
			default:  #()
		)
		for vv in vals do
			if (abs (vv as float)) > 0.0001 do
			( avgAcc += abs (vv as float); avgCnt += 1 )
	)
	if avgCnt > 0 do g_orm_avgMag = avgAcc / avgCnt

	local rc = rolloutCreator "g_orm_rlProps" sectionTitle
	rc.begin()

	local h = 10
	if props.count == 0 then
	(
		-- Объекты/редакторы геометрии распознаны, но у них нет «простых»
		-- параметров (float/integer/boolean/color/point3) — править нечего.
		rc.addControl #label "lbl_noParams" "No adjustable parameters." paramStr:"align:#left"
		h += 30
	)
	else
	(
		for p in props do
			ORM_addPropControls rc modIdx prefix p &h
	)

	h += 10
	if h < 40 do h = 40

	g_orm_rlProps = rc.end()

	-- Переставляем свиток так, чтобы About оставался ПОСЛЕДНИМ (см. архитектура п. 4)
	local hasAbout = (findItem g_orm_floater.rollouts g_orm_rollAbout) != 0
	if hasAbout do removeRollout g_orm_rollAbout g_orm_floater

	addRollout g_orm_rlProps g_orm_floater

	if hasAbout do addRollout g_orm_rollAbout g_orm_floater

	-- Сворачиваем About при выборе элемента (см. архитектура п. 2)
	if g_orm_rollAbout != undefined do g_orm_rollAbout.open = false

	-- Автовысота под новый набор свитков
	ORM_updateFloaterHeight()

	-- Запоминаем, для какого выбора построен rollout, чтобы не дублировать (см. архитектура п. 4)
	g_orm_lastSelKey = (g_orm_selInfo[1] as string) + "_" + (g_orm_selInfo[2] as string)

	true
)


-- ======================================================================
-- DOTNET LIST (owner-draw ListBox): иконки-глаза из BMP + курсив для инстансов
-- Паттерн взят из BatchViewsManager (initListBox/DrawItem/DoubleBuffered).
-- ======================================================================

global g_orm_iconFrames = #()   -- кадры ModProps_16i.bmp (1..locIconCount), резаные по g_orm_iconSize px
global g_orm_listIcons   = #()   -- параллельно g_orm_listItems: индекс иконки для строки (9/10/11; base = 0)
global g_orm_listFlags   = #()   -- параллельно g_orm_listItems: true = инстанс (курсив)
global g_orm_debug       = false -- включить для логирования всех catch в Listener
-- ПРИМЕЧАНИЕ: шрифты (plain/italic) хранит сам rollout rollout_mods как локальные переменные
-- и рисует ими в DrawItem (closure, как в рабочем примере). Глобалов не нужно.

-- Двойная буферизация owner-draw ListBox (свойство защищённое, доступ через рефлексию)
fn ORM_enableDoubleBuffered ctrl =
(
	try
	(
		-- BindingFlags.Instance(4) | BindingFlags.NonPublic(32) = 36
		local bf = (dotNetClass "System.Enum").ToObject ((dotNetClass "System.Reflection.BindingFlags")) 36
		local prop = (ctrl.GetType()).GetProperty "DoubleBuffered" bf
		if prop != undefined do prop.SetValue ctrl true
	)
	catch
	(
		if g_orm_debug do format "ModPropsLister: enableDoubleBuffered failed: %\n" (getCurrentException() as string)
	)
)

-- Загрузка иконок для owner-draw. Штатный загрузчик 3ds Max: openBitMap + getPixels
-- с форматом #rgba — Max честно отдаёт альфу из 32-бит BMP (GDI+ видит файл как
-- Format32bppRgb и выбрасывает 4-й байт). Диагностика печатается в Listener при
-- g_orm_debug=true (без него — молча, ошибки в catch не теряются).
fn ORM_loadIconFrames path =
(
	local frames = #()
	if g_orm_debug do format "ModPropsLister: loadIconFrames: '%'\n" path
	local bm = undefined
	try ( bm = openBitMap path ) catch
	(
		if g_orm_debug do format "ModPropsLister:   openBitMap error: %\n" (getCurrentException() as string)
	)
	if bm == undefined then
		( if g_orm_debug do format "ModPropsLister:   openBitMap returned undefined (file missing/unreadable?)\n" )
	else
	(
		local fw = g_orm_iconSize
		local fh = try ( bm.height as integer ) catch ( 0 )
		local frameCount = (try ( bm.width as integer ) catch ( 0 )) / fw
		if g_orm_debug do format "ModPropsLister:   bitmap %x% -> % frame(s) %x%\n" bm.width bm.height frameCount fw fh
		if fw >= 1 and fh >= 1 and frameCount >= 1 then
		(
			try
			(
				local alphaOK = false
				local probe = getPixels bm [0, 0] 1
				try ( alphaOK = (probe[1].a != undefined) ) catch ( alphaOK = false )
				if alphaOK then
					( if g_orm_debug do format "ModPropsLister:   probe[0,0] .a=% .r=% .g=% .b=%\n" probe[1].a probe[1].r probe[1].g probe[1].b )
				else
					( if g_orm_debug do format "ModPropsLister:   WARNING: (color).a not readable -> alpha = 1.0 (fully opaque)\n" )
				local pf = (dotNetClass "System.Drawing.Imaging.PixelFormat").Format32bppArgb
				for k = 0 to frameCount - 1 do
				(
					local db = dotNetObject "System.Drawing.Bitmap" fw fh pf
					for y = 0 to fh - 1 do
					(
						local row = getPixels bm [k * fw, y] fw
						if row.count != fw and g_orm_debug do
							format "ModPropsLister:   row % len % (expected %)\n" y row.count fw
						for x = 1 to row.count do
						(
							local c = row[x]
							local a = if alphaOK then ( try ( c.a ) catch ( 1.0 ) ) else 1.0
							local av = amax 0 (amin 255 ((a * 255.0) as integer))
							db.SetPixel (x - 1) y ((dotNetClass "System.Drawing.Color").FromARGB av (c.r as integer) (c.g as integer) (c.b as integer))
						)
					)
					append frames db
				)
			)
			catch
			(
				for fr in frames do \
					try ( fr.Dispose() ) \
						catch ( ORM_logExcept "disposeFrame" (getCurrentException() as string) )
				frames = #()
				if g_orm_debug do format "ModPropsLister:   pixel copy failed: %\n" (getCurrentException() as string)
			)
		)
		close bm
	)
	if g_orm_debug do format "ModPropsLister:   result: % icon frames\n" frames.count
	frames
)

-- Инициализация dotNet-списка (owner-draw, тёмная тема, загрузка иконок)
fn ORM_initModList =
(
	if g_orm_rollMods == undefined do return false
	local lb = g_orm_rollMods.lst_mods
	try
	(
		lb.BeginUpdate()
		lb.Items.Clear()
		lb.SelectionMode = (dotNetClass "System.Windows.Forms.SelectionMode").One
		lb.DrawMode = (dotNetClass "System.Windows.Forms.DrawMode").OwnerDrawFixed
		lb.IntegralHeight = false
		-- Размер иконок/высоты строк — просто глобал в коде (по умолчанию маленькие 16px)
		if g_orm_iconSize == undefined do g_orm_iconSize = 16
		lb.ItemHeight = g_orm_iconSize + 6
		lb.BackColor = (dotNetClass "System.Drawing.Color").FromARGB 40 40 43
		lb.ForeColor = (dotNetClass "System.Drawing.Color").White
		-- Шрифт задаётся в on rollout_mods open (lst_mods.Font = fontND): эта привязка
		-- к контролу оставляет и plain, и italic шрифт живыми для GDI+ (см. DrawItem).
		lb.EndUpdate()
	)
	catch
	(
		if g_orm_debug do format "ModPropsLister: initModList setup failed: %\n" (getCurrentException() as string)
	)
	ORM_enableDoubleBuffered lb
	g_orm_iconFrames = ORM_loadIconFrames icon_path
	lb.Invalidate()
	true
)

-- Полная замена содержимого списка (сборка строк — ORM_buildListItems)
fn ORM_listSetItems listItems =
(
	if g_orm_rollMods == undefined do return false
	local lb = g_orm_rollMods.lst_mods
	lb.BeginUpdate()
	lb.Items.Clear()
	for s in listItems do lb.Items.Add s
	lb.SelectedIndex = -1
	lb.EndUpdate()
	lb.Invalidate()
	true
)

-- Реакция на смену выделения dotNet-списка (0-based SelectedIndex):
-- idx>=1 → как старый on lst_mods selected; иначе — сброс (кнопки неактивны)
fn ORM_listSelectChanged =
(
	if g_orm_rollMods == undefined do return false
	local idx = g_orm_rollMods.lst_mods.SelectedIndex + 1
	if idx >= 1 then
		ORM_onListSelect idx
	else
	(
		ORM_setToggleUI false
		g_orm_rollMods.btn_toggle.enabled = false
		g_orm_rollMods.btn_delete.enabled = false
		true
	)
)

-- Owner-draw строки: иконка глаза (кадр 9/10/11), текст (курсив = инстанс).
-- fPlain/fItalic — rollout-локальные шрифты (как в рабочей Italic-версии).
fn ORM_drawListItem args fPlain fItalic =
(
	local idx = args.Index
	if idx < 0 do return false
	local lb = g_orm_rollMods.lst_mods
	local rect = args.Bounds
	local g = args.Graphics
	local isSelected = lb.GetSelected idx

	local backBrush = try
		dotNetObject "System.Drawing.SolidBrush" (
			if isSelected then (dotNetClass "System.Drawing.SystemColors").Highlight else lb.BackColor
		)
		catch ( undefined )
	if backBrush != undefined do
	(
		try ( g.FillRectangle backBrush rect ) \
			catch ( ORM_logExcept "fillRect" (getCurrentException() as string) )
		backBrush.Dispose()
	)

	local x = rect.X + 2
	local iconIdx = if idx + 1 <= g_orm_listIcons.count then g_orm_listIcons[idx + 1] else 0
	if classOf iconIdx == Integer and iconIdx >= 1 and iconIdx <= g_orm_iconFrames.count then
	(
		local s = g_orm_iconSize
		if s < 1 do s = 16
		local dst = dotNetObject "System.Drawing.Rectangle" x (rect.Y + ((rect.Height - s) / 2)) s s
		try ( g.DrawImage g_orm_iconFrames[iconIdx] dst )
		catch
		(
			if g_orm_debug do
				format "ModPropsLister: DrawImage idx=% iconIdx=% error=%\n" idx iconIdx (getCurrentException() as string)
		)
		x += s + 5
	)
	else
		if iconIdx >= 1 and g_orm_debug do
			format "ModPropsLister: icon frame missing iconIdx=% frames=%\n" iconIdx g_orm_iconFrames.count

	local isInst = (idx + 1 <= g_orm_listFlags.count) and g_orm_listFlags[idx + 1]
	local textColor = if isSelected then (dotNetClass "System.Drawing.SystemColors").HighlightText else lb.ForeColor
	local textBrush = dotNetObject "System.Drawing.SolidBrush" textColor
	local txt = lb.Items.Item[idx] as string
	local pt = dotNetObject "System.Drawing.PointF" (x as float) (rect.Y as float)
	-- Текст: обычные строки — fPlain (== lst_mods.Font), инстансы — fItalic
	-- (шрифты закреплены за контролом, поэтому живые, без shear).
	local f = fPlain
	if f == undefined do
		try ( f = args.Font ) catch ( ORM_logExcept "argsFont" (getCurrentException() as string) )
	local fIt = fItalic
	if fIt == undefined do fIt = f
	if isInst do f = fIt
	try ( g.DrawString txt f textBrush pt )
	catch ( format "ModPropsLister: draw failed: %\n" (getCurrentException() as string) )
	textBrush.Dispose()
	true
)


-- ======================================================================
-- UI: ROLLOUT "MODIFIERS" (статический)
-- ======================================================================
rollout rollout_mods "Modifiers"
(
	dotNetControl lst_mods "System.Windows.Forms.ListBox" height:130 width:180 align:#left offset:[-4,0]

	-- Шрифты (plain/italic): как в рабочей Italic-версии — rollout-локальные, создаются
	-- в on open и ЗАКРЕПЛЯЮТСЯ за контролом (lst_mods.Font), поэтому живые для GDI+.
	local fontND
	local fontItalicND

	-- Число кадров в ModProps_16i.bmp (см. комментарий у icon_path): rollout-локальная,
	-- глобал-функции читают число кадров из загруженной bitmap (см. ORM_loadIconFrames).
	local locIconCount = 13

	checkbutton btn_toggle "️" images:#(icon_path, undefined, locIconCount, 10, 9, 9, 9, true) align:#right width:24 height:25 tooltip:"Enable/disable modifier" offset:[0,-140]
	button btn_delete "" images:#(icon_path, undefined, locIconCount, 12, 12, 12, 12, true) width:24 height:25 align:#right tooltip:"Remove modifier from the stack" offset:[0,80]

	label lbl_filter "Ignore:" align:#left offset:[-5,4] across:7
	checkbutton chk_geom    "" images:#(icon_path, undefined, locIconCount, 2, 2, 2, 2, true) tooltip:"Geometry"
	checkbutton chk_shape   "" images:#(icon_path, undefined, locIconCount, 3, 3, 3, 3, true) tooltip:"Shapes"
	checkbutton chk_light   "" images:#(icon_path, undefined, locIconCount, 4, 4, 4, 4, true) tooltip:"Light"
	checkbutton chk_camera  "" images:#(icon_path, undefined, locIconCount, 5, 5, 5, 5, true) tooltip:"Camera"
	checkbutton chk_helper  "" images:#(icon_path, undefined, locIconCount, 6, 6, 6, 6, true) tooltip:"Helpers"
	button btn_refresh "" images:#(icon_path, undefined, locIconCount, 13, 13, 13, 13, true) align:#right tooltip:"Re-read the stack: update the list and properties"

	on lst_mods DrawItem sender args do
		ORM_drawListItem args fontND fontItalicND

	on lst_mods SelectedIndexChanged sender args do
		ORM_listSelectChanged()

	on btn_toggle changed st do
	(
		-- Смешанное состояние (часть модов вкл, часть выкл):
		-- спрашиваем пользователя через popupmenu, а не переключаем вслепую (см. архитектура п. 2)
		local modIdx = 0
		if classOf g_orm_selInfo == Array and g_orm_selInfo.count > 0 \
			and g_orm_selInfo[1] == "mod" do modIdx = g_orm_selInfo[2]
		if ORM_isMixedEnabled modIdx then
		(
			if (popUpMenu rmc_toggle) == undefined do
				ORM_setToggleUI (ORM_getLiveEnabled modIdx) mixedState:(ORM_isMixedEnabled modIdx)
		)
		else
			ORM_toggleSelected st
	)

	on btn_delete pressed do
	(
		if classOf g_orm_selInfo != Array or g_orm_selInfo.count == 0 do return false
		if g_orm_selInfo[1] != "mod" do
		(
			messageBox "Base object cannot be deleted." title:APP_TITLE
			return false
		)
		local modDataIdx = g_orm_selInfo[2]
		if modDataIdx < 1 or modDataIdx > g_orm_modClasses.count do return false
		if ORM_onDeleteMod modDataIdx do ORM_rebuildNow()
	)

	on chk_geom    changed st do ORM_onFilterChanged()
	on chk_shape   changed st do ORM_onFilterChanged()
	on chk_light   changed st do ORM_onFilterChanged()
	on chk_camera  changed st do ORM_onFilterChanged()
	on chk_helper  changed st do ORM_onFilterChanged()

	on btn_refresh pressed do
	(
		-- Ручное обновление: считывает реальный стек и пересобирает список + свойства.
		-- ORM_refreshUI (autoSel:false) сохраняет текущий выбранный элемент.
		-- Диагностика восстановления выделения печатается при g_orm_debug.
		if g_orm_refreshing do return false
		g_orm_refreshing = true
		try ( ORM_refreshUI() ) catch
		(
			if g_orm_debug do
				format "ModPropsLister: refresh error: %\n" (getCurrentException() as string)
		)
		g_orm_refreshing = false
	)

	-- Автовысота при сворачивании/разворачивании свитка; сохранение позиции при закрытии
	on rollout_mods rolledUp state do ORM_updateFloaterHeight()

	-- Создание шрифтов в on open — ровно как в рабочей Italic-версии:
	-- fontND создаётся и ПРИСВАИВАЕТСЯ контролу (живой), курсив — от fontND.FontFamily.
	on rollout_mods open do
	(
		local fsClass = dotNetClass "System.Drawing.FontStyle"
		-- Простой шрифт создаём и ПРИСВАИВАЕМ контролу (как в рабочей Italic-версии).
		-- Присвоение в отдельном try: при повторном показе floater контрол может быть
		-- ещё не готов — это НЕ должно прерывать создание курсива.
		fontND = dotNetObject "System.Drawing.Font" "Segoe UI" 9.0 (fsClass.Regular)
		try ( lst_mods.Font = fontND ) catch (
			if g_orm_debug do format "ModPropsLister: lst_mods.Font assign failed: %\n" (getCurrentException() as string)
		)
		-- Курсив строится от ЖИВОГО fontND.FontFamily (строковый "Segoe UI" даёт мёртвый шрифт).
		fontItalicND = dotNetObject "System.Drawing.Font" fontND.FontFamily fontND.Size fsClass.Italic
		if fontItalicND == undefined do fontItalicND = fontND
		if g_orm_debug do
			format "ModPropsLister: fonts ok plain=% italic=%\n" (fontND != undefined) (fontItalicND != undefined)
	)

	on rollout_mods close do
	(
		ORM_saveFloaterState()
		-- Штатное снятие колбэков при закрытии окна (крестиком или скриптом):
		-- иначе «зомби»-колбэки продолжают дёргать мёртвый dotNet-контрол и спамят.
		ORM_unregisterCallbacks()
		g_orm_floater   = undefined
		g_orm_rollMods  = undefined
		g_orm_rollAbout = undefined
	)
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
	try ( g_orm_floater.size = [g_orm_floater.size[1], newH] ) \
		catch ( ORM_logExcept "floaterResize" (getCurrentException() as string) )
	true
)

-- Сохранить позицию/размер floater в INI (паттерн BatchViewsManager: saveFloaterState)
fn ORM_saveFloaterState =
(
	if g_orm_floater == undefined do return false
	local iniPath = getmaxinifile()
	setINISetting iniPath "ModPropsLister" "Position" (g_orm_floater.pos as string)
	-- Состояние фильтра пишем ТОЛЬКО при включённой настройке g_orm_saveFilter
	-- (по умолчанию false — фильтр всегда «ничего не игнорируем» при запуске).
	if g_orm_saveFilter do
		setINISetting iniPath "ModPropsLister" "TypeFilter" (g_orm_typeFilter as string)
	true
)

fn ORM_showUI result =
(
	g_orm_selInfo = #()

	-- Строки списка (символ enabled в начале; см. архитектура п. 1/2)
	local listItems = ORM_buildListItems result

	local flW = 245
	local iniPath = getmaxinifile()
	local posStr  = getINISetting iniPath "ModPropsLister" "Position"
	-- Восстановление только ПОЛОЖЕНИЯ из INI; размер — расчётный (автовысота),
	-- в конфиге не хранится. lockHeight:false — разрешаем автовысоту (см. архитектура п. 7)
	if posStr != "" then
	(
		local p = execute posStr
		try
			g_orm_floater = newRolloutFloater APP_TITLE flW 420 p[1] p[2] lockHeight:false lockWidth:true
		catch
			g_orm_floater = newRolloutFloater APP_TITLE flW 420 lockHeight:false lockWidth:true
	)
	else
		g_orm_floater = newRolloutFloater APP_TITLE flW 420 lockHeight:false lockWidth:true

	-- Сохраняем глобальные псевдонимы статических rollout'ов
	g_orm_rollMods  = rollout_mods
	g_orm_rollAbout = rollout_about

	addRollout rollout_mods g_orm_floater

	-- dotNet-список: owner-draw + иконки глаза из BMP + курсив для инстансов
	ORM_initModList()

	-- Галочки фильтра по типам из глобального состояния (прочитанного из INI)
	ORM_setFilterUI()

	-- Запуск без валидного анализа: показываем текущее состояние, а не блокируем
	if result == undefined do
	(
		local vc = 0
		for o in (selection as array) do if isValidNode o do vc += 1
		if vc == 1 then
			listItems = #("Single Selection")
		else if vc < 1 then
			listItems = #("No selection.")
		else
			listItems = #("No Match")
	)

	ORM_listSetItems listItems
	ORM_setToggleUI false
	rollout_mods.btn_toggle.enabled = false
	rollout_mods.btn_delete.enabled = false

	-- При открытии сразу выделяем первый элемент списка (верхний модификатор стека);
	-- SelectedIndex вызывает SelectedIndexChanged → ORM_listSelectChanged → ORM_onListSelect
	if listItems.count > 0 do
		rollout_mods.lst_mods.SelectedIndex = 0

	addRollout rollout_about g_orm_floater

	-- Автозамёты: обновление при смене выделения / стека (см. архитектура п. 3)
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

	-- Состояние фильтра по типам: при включённой настройке g_orm_saveFilter
	-- восстанавливаем из INI (секция "ModPropsLister"); иначе — всегда «ничего не игнорируем».
	if g_orm_saveFilter then
	(
		local iniPath = getmaxinifile()
		local fstr = getINISetting iniPath "ModPropsLister" "TypeFilter"
		if fstr != "" do
		(
			try
			(
				local f = execute fstr
				if classOf f == Array and f.count == 5 do g_orm_typeFilter = f
			)
			catch
			(
				if g_orm_debug do format "ModPropsLister: run INI TypeFilter failed: %\n" (getCurrentException() as string)
			)
		)
	)
	else
		g_orm_typeFilter = #(false, false, false, false, false)

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
