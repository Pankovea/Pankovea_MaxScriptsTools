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
  Rollout "Properties" — свиток контролов выбранного элемента. Строится один раз
      на КЛАСС модификатора (rolloutCreator) и живёт во floater: при переключении
      модов разворачивается/сворачивается (open/close), при смене выборки объектов
      переиспользуется из кэша — без пересоздания и без моргания списка (архитектура п. 4).
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

2. LOOKUP — СЛОВАРЬ. g_orm_propLookup — Dictionary lookupKey -> запись
   ORM_PropEntry (lookupKey, modIdx, propName, prefix); поиск через
   ORM_lookupFind = g_orm_propLookup[lookupKey]. g_orm_rlCache — то же:
   Dictionary clsKey -> ORM_RlEntry (см. п. 4).
   Хеш-доступ arr["key"]=... к глобальному #() в MAXScript НЕ работает
   ("array index must be positive number") — не менять на hash.
   ИНДЕКС 0 И ЗА ПРЕДЕЛЫ: g_orm_listItems[0] бросает "array index must be
   positive number, got: 0", лишний индекс даёт undefined (в части версий 0 ->
   OK). Поэтому ВСЕ чтения g_orm_selInfo / g_orm_listItems[..] guard'ятся
   classOf == Array И idx >= 1 ДО индексации — иначе runtime error.

3. codeStr БЕЗ @...@. Вложенные @ ломают парсинг ("Call needs function or
   class"). Имена/значения подставляются конкатенацией строк.

4. КЭШ СВИТКОВ СВОЙСТВ. Свиток свойств строится ОДИН раз на класс (clsKey — имя
   класса мода, для базы — "base:<Класс>" / "base:mixed:<Super>", т.к. набор свойств
   базы зависит от класса) и ЖИВЁТ во floater: при переключении модов открытый
   сворачивается, новый разворачивается (open/close) — без removeRollout/
   addRollout/destroyDialog, поэтому список модов не перелэйаутается и не моргает.
   Кэш — g_orm_rlCache: Dictionary clsKey -> ORM_RlEntry (struct-запись, поля именами).
   destroyDialog
   РАЗРУШАЕТ определение (rollout-значение), поэтому применяется ТОЛЬКО при закрытии
   окна (ORM_closeDialog). При смене ВЫБОРКИ объектов свитки убираются из floater'а
   removeRollout (без destroyDialog — определения переиспользуются), кэш сохраняется.
ВСТРОЕННЫЕ СВИТКИ: для класса может быть задан РУЧНОЙ макет строк вместо автоанализа
    getPropNames (глобал g_orm_builtinDefs; тестовый Extrude): порядок, НАСТОЯЩИЕ ГРУППЫ
    (group-блоки rollout'а — рамка вокруг контролов, формат #(":group", "Заголовок",
    #(дети...)), дети — те же строки) и radiobuttons (state маппится на значение свойства
    через ORM_radioApply). Значения ВСЕГДА берутся из props анализа — макет определяет
    только раскладку; для синка/проверки доступности группы разворачиваются
    (ORM_rlFlattenLayout). radiobuttons Unify-кнопки НЕ имеют: в ORM_rlUsable для строк-радио
    проверяется только наличие контрола (иначе — ресббинговый цикл drop→rebuild).
   Префиксы контролов СТАБИЛЬНЫ ("c<uid>_") — не зависят от modDataIdx, поэтому codeStr
   одного свитка работает для любого мода того же класса; g_orm_propLookup пересобирается
   с актуальным modIdx при каждом открытии (ORM_rlSyncValues). Заголовок свитка
   (Base: MIXED, "N lower duplicates") зависит от выборки и переустанавливается
   в ORM_rlOpenForSel (rl.title). Исключение из «не пересобирать»: кнопка Unify (_mk)
   создаётся только для различавшегося при ПОСТРОЕНИИ свойства (см. ORM_addPropControls);
   если в новой выборке различается свойство, созданное «одинаковым», свиток класса
   пересобирается на месте (ORM_rlUsable → ORM_rlDrop) — редкий случай, допустимый
   ценой небольшого релэйаута.

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
   выключенный мод мог молча пропасть из списка. Глаз в строке списка:
   9 — открытый, 10 — закрытый, 11 — смешанный (BMP-иконка в ImageColumn).
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
local VERSION = "1.0.2 (2026-09-09)"

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

-- Lookup контролов: Dictionary lookupKey -> ORM_PropEntry (lookupKey, modIdx, propName, prefix)
global g_orm_propLookup     = Dictionary #string
-- Выбранный элемент: #(type, modDataIdx) ; тип "base" | "mod" (пустой = нет выбора)
global g_orm_selInfo        = #()
-- Соответствие строк DataGridView -> #("base"|"mod", modDataIdx)
global g_orm_listItems      = #()
-- dotNet списка: состояние глаза и флаги инстанса по индексам строк (см. ORM_buildListItems/ORM_listSetItems)
global g_orm_listIcons      = #()
global g_orm_listFlags      = #()
-- Кадры ModProps_16i.bmp (загружаются в ORM_initModList); g_orm_eyeFrames — 3 глаза для ImageColumn
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
-- Приостановка callback-refresh'ей на время многошаговой операции (конвертация
-- в инстанс): промежуточные postModifier* пересобирали бы UI многократно и теряли
-- текущее выделение сетки. Финальный пересбор делает сам обработчик операции.
global g_orm_suspendRefresh = false
-- Форс-рестор выделения после такой операции: #(wasSel, wasLabel). Потребляется
-- ОДИН раз следующим ORM_refreshUI с autoSel:false (см. btn_inst / ORM_refreshUI).
global g_orm_forceRestore   = #()
-- Групповой режим спиннера (см. «Сделать общим»): lookupKey ->
--   #( #(obj, baseVal, modIdx, realName), ... , mode ) где mode = #incr | #scale.
--   #incr:  контрол стартует с 0, изменение ПРИБАВЛЯЕТ дельту к запомненной базе
--           (0 = «прибавить ноль», ничего не меняем).
--   #scale: контрол стартует со 100 (%), изменение УМНОЖАЕТ базы на значение/100
--           (100 = «умножить на 1»).
--   И в том, и в другом случае показанное число — фактор (дельту/процент),
--   НЕ абсолютное значение свойства.
global g_orm_incrMap        = #()


-- Максимальная высота floater: не более 3/4 высоты рабочего стола (в логических
-- единицах, с учётом DPI). Вычисляется при каждой загрузке макроса. Глобал, а не
-- local, чтобы был доступен и из динамически генерируемых свитков (rolloutCreator),
-- и из ORM_updateFloaterHeight.
global g_orm_maxFloaterH = \
	((sysInfo.DesktopSize)[2] * 3.0 / 4.0) / (((dotNetClass "System.Drawing.Graphics").fromHwnd 0).dpiX / 100)
global g_orm_rlProps        = undefined  -- активный (развёрнутый) rollout свойств
-- Структуры-записи (вместо позиционных кортежей #(...) с доступом по индексу).
struct ORM_RlEntry (
	clsKey,         -- ключ набора свойств (см. g_orm_rlCache ниже)
	rl,             -- значение rollout'а свитка (кэш-запись)
	prefix,         -- стабильный префикс контролов "c<uid>_"
	lookupTemplate, -- #(ORM_PropTemplate) БЕЗ modIdx (подставляется при открытии)
	uid,            -- монотонный номер (имя rollout'а "g_orm_rlProps_<uid>")
	layout          -- строки встроенного макета (rows) или undefined (см. g_orm_builtinDefs)
)

struct ORM_PropTemplate (
	lookupKey,      -- стабильный ключ контрола ("c<uid>_<prop>")
	propName,       -- имя свойства Max (строка)
	prefix          -- префикс контрола (для повторной сборки lookup)
)

struct ORM_PropEntry (
	lookupKey,      -- стабильный ключ контрола ("c<uid>_<prop>")
	modIdx,         -- ЖИВОЙ индекс мода (0 = база) при текущем открытии свитка
	propName,       -- имя свойства Max (строка)
	prefix          -- префикс контрола
)

struct ORM_BuiltinLayout (
	rows            -- строки встроенного макета свитка (см. g_orm_builtinDefs)
)

-- Кэш свитков свойств по классу модификатора (см. архитектура п. 4):
-- Dictionary clsKey -> ORM_RlEntry, где
--   clsKey         — ключ набора свойств: "base:<Класс>" / "base:mixed:<Super>" /
--                    имя класса мода (Bend, Edit_Poly, ...)
--   rl             — значение rollout'а (переживает removeRollout, НЕ destroyDialog)
--   prefix         — стабильный префикс контролов ("c"+uid+"_"), не зависит от modDataIdx
--   lookupTemplate — #(ORM_PropTemplate) БЕЗ modIdx (подставляется при открытии)
--   uid            — монотонный номер (имя rollout'а "g_orm_rlProps_<uid>")
--   layout         — строки ВСТРОЕННОГО (ручного) свитка класса или undefined:
--                    #( #(accessorKey, kind, label), #(key, #radio, label, labels, mappings),
--                       #(":group", "Заголовок", #(дети...)) ... ) — см. g_orm_builtinDefs
-- Свитки ЖИВУТ во floater при переключении модов (open/close); при смене выборки
-- объектов все removeRollout (без destroyDialog) — определения из кэша переиспользуются.
global g_orm_rlCache        = Dictionary #string
global g_orm_rlUid          = 0
-- Встроенные (ручные) свитки свойств для классов: структурированный макет вместо
-- автоанализа getPropNames. Dictionary имяКласса -> ORM_BuiltinLayout #rows.
-- Пока — тестовый свиток Extrude. Формат строк rows:
--   #(accessorKey, ptype, "Подпись")            — обычное свойство (ptype: #float/#integer/
--                                                 #boolean/#color/#point3)
--   #(accessorKey, #radio, "Подпись", labels,   — radiobuttons; labels — #("A","B",...),
--                                                 mappings — #(значение->индекс) (напр. #(1,2))
--                                                 для capType 1=Morph 2=Grid, #(0,1,2) для output)
--   #(":group", "Заголовок", #(дети...))        — настоящая группа (group-блок rollout'а:
--                                                 рамка вокруг контролов); дети — те же строки,
--                                                 значения и колбэки, но внутри блока
--   #(":group", "Заголовок")                    — старый формат: label-разделитель
global g_orm_builtinDefs = Dictionary #string
g_orm_builtinDefs["Extrude"] = ORM_BuiltinLayout rows:#(
	#("amount",  #float,    "Amount"),
	#("segs",    #integer,  "Segments"),
	#(":group",  "Capping", #(
		#("capStart", #boolean, "Cap Start"),
		#("capEnd",   #boolean, "Cap End"),
		#("capType",  #radio,   "Cap Type",    #("Morph", "Grid"),            #(0, 1))
	)),
	#(":group",  "Output", #(
		#("output",   #radio,   "Output Type", #("Patch", "Mesh", "NURBS"),   #(0, 1, 2))
	)),
	#("mapcoords",       #boolean, "Generate Mapping Coordinates"),
	#("realWorldMapSize",#boolean, "Real-World Map Size"),
	#("matIDs",  #boolean, "Generate Material ID"),
	#("useShapeIDs", #boolean, "Use Shape IDs"),
	#("smooth",  #boolean, "Smooth")
)
-- Какой rollout сейчас развёрнут (значение rollout'а, не clsKey)
global g_orm_rlOpen         = undefined
-- Глобальные псевдонимы статических rollout'ов (паттерн доступа из global-функций)
global g_orm_rollMods       = undefined
global g_orm_rollAbout      = undefined


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
global ORM_instancifyModifier
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
global ORM_onInstancifyMod
global ORM_rebuildPropsRollout
global ORM_addPropControls
global ORM_rlFindByClass
global ORM_rlBuild
global ORM_rlSyncValues
global ORM_rlOpenForSel
global ORM_rlRemoveAll
global ORM_rlAddIfMissing
global ORM_builtinLayoutFor
global ORM_rlFindProp
global ORM_rlAddLayoutRow
global ORM_radioApply
global ORM_rlFlattenLayout
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
-- Функции grid-списка вызываются из dotNet-событий (SelectionChanged, CellMouseClick)
-- и из глобальных ORM_*-функций, т.е. из скоупа, ОТДЕЛЬНОГО от макроса. В .mcr обычный
-- fn локален макроскоупу — без этого предобъявления global dotNet-событие увидело бы
-- имя как Global:undefined.
global ORM_enableDoubleBuffered
global ORM_loadIconFrames
global ORM_initModList
global ORM_listSetItems
global ORM_listSelectChanged
global ORM_selectRow
global ORM_refreshList
global ORM_refreshEyeRow
global ORM_eyeBitmapFor
global ORM_eyeIdxForStates
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

-- Номер кадра глаза по состояниям enabled: 9 — все вкл, 10 — все выкл, 11 — смешанное.
-- Общая логика для ORM_buildListItems и точечного обновления строки (ORM_refreshEyeRow).
fn ORM_eyeIdxForStates sts =
(
	local eyeIdx = 9
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
	eyeIdx
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
		local eyeIdx = ORM_eyeIdxForStates (ORM_getEnabledStates mi2)
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
	local gd = g_orm_rollMods.lst_mods
	local selIdx0 = -1
	try ( selIdx0 = gd.CurrentRow.Index ) \
		catch ( ORM_logExcept "refreshListSel" (getCurrentException() as string) )
	ORM_listSetItems (ORM_buildListItems g_orm_result)
	if selIdx0 >= 0 and selIdx0 < gd.Rows.Count do
		ORM_selectRow selIdx0
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

-- Конвертирует выбранный модификатор в ОБЩИЙ ИНСТАНС на всех объектах.
-- Образец — «первый попавшийся» мод данного класса (верхний экземпляр на первом
-- подходящем объекте). На каждом остальном объекте СВОЙ мод заменяется инстансом
-- образца, причём место вставки ОБЯЗАНО совпасть: вставляем инстанс before:{ourIdx}
-- (счёт от вершины стека, как индексируется obj.modifiers), затем удаляем СВОЙ мод
-- (после вставки он сдвинут вниз на 1) — инстанс оказывается ровно на его месте.
-- Итог: у всех объектов один и тот же экземпляр модификатора (курсив в списке).
fn ORM_instancifyModifier modClass =
(
	if g_orm_debug do format "ModPropsLister[inst]: ORM_instancifyModifier modClass=%\n" (modClass as string)
	if not (ORM_validTargets()) do ( if g_orm_debug do format "ModPropsLister[inst]: no valid targets\n"; ORM_refreshUI quiet:true; return false )
	-- «Первый попавшийся»: образец — верхний мод класса на первом из объектов,
	-- у которых этот класс вообще есть (идём по г_uniq в порядке списка).
	local refObj = undefined
	local refMod = undefined
	for obj in g_orm_uniqueObjs do
	(
		if not (isValidNode obj) do continue
		for m in obj.modifiers do
			if classOf m == modClass do ( refObj = obj; refMod = m; exit )
		if refMod != undefined do exit
	)
	if g_orm_debug do format "ModPropsLister[inst]: refObj=% refMod=%\n" (refObj as string) (refMod as string)
	if refMod == undefined do return false

	-- Конвертация идёт на ЖИВОМ стеке, и каждый deleteModifier/addModifier стреляет
	-- postModifierDeleted|Added → ORM_cbRefresh. Промежуточные пересборы UI не нужны
	-- (и ломали бы текущее выделение сетки), поэтому приостанавливаем callbacks на всю
	-- операцию; финальный пересбор делает обработчик кнопки (ORM_rebuildNow).
	g_orm_suspendRefresh = true
	local applied = false
	try
	(
	undo "ModPropsLister Convert To Instance" on
	(
		with redraw off
		(
			for obj in g_orm_uniqueObjs do
			(
				if obj == refObj do continue
				if not (isValidNode obj) do continue
				if g_orm_debug do format "ModPropsLister[inst]:   obj=% mods=%\n" (obj as string) obj.modifiers.count
				-- Своя копия мода данного класса на этом объекте (верхняя) и её индекс
				local ourMod = undefined
				local ourIdx = 0
				for i = 1 to obj.modifiers.count do
					if classOf obj.modifiers[i] == modClass do ( ourMod = obj.modifiers[i]; ourIdx = i; exit )
				if g_orm_debug do format "ModPropsLister[inst]:   ourMod=% ourIdx=%\n" (ourMod as string) ourIdx
				if ourMod == undefined or ourMod == refMod do continue
				if g_orm_debug do
					format "ModPropsLister[inst]:   valid(ref)=% valid(instance)=% index=% mods.count=% base=%\n" \
						(validModifier obj refMod) (validModifier obj (classOf refMod)) ourIdx obj.modifiers.count \
						(classOf obj.baseObject)
				try
				(
					-- Порядок КРИТИЧЕН: Extrude (shape-only) нельзя навесить поверх уже
					-- заметоченного меша — «Modifier is not appropriate». Поэтому:
					--  1) запоминаем состояние ВСЕХ вышестоящих модов (наша позиция = ourIdx),
					--  2) отключаем их — тип под позицией вставки возвращается к базовому,
					--  3) удаляем СВОЙ мод (индексы вышестоящих при этом не меняются),
					--  4) вставляем инстанс образца НА ТО ЖЕ МЕСТО (before:{ourIdx}),
					--  5) возвращаем состояние вышестоящих как было.
					-- addModifier с уже применённым модом = инстанс (общие данные).
					local upperStates = #()
					for i = 1 to ourIdx - 1 do
						try ( append upperStates #(i, obj.modifiers[i].enabled) ) \
							catch ( append upperStates #(i, true) )
					for i = 1 to ourIdx - 1 do
						try ( obj.modifiers[i].enabled = false ) \
							catch ()
					deleteModifier obj ourMod
					addModifier obj refMod before:ourIdx
					applied = true
					for d in upperStates do
						try ( obj.modifiers[d[1]].enabled = d[2] ) \
							catch ()
				)
				catch ( ORM_logExcept ("instancify " + (modClass as string)) (getCurrentException() as string) )
				if g_orm_debug do format "ModPropsLister[inst]:   done applied=%\n" applied
			)
		)
	)
	-- Список (курсив инстанса) и Modify-панель обновляем, если что-то применили.
	-- Панель переоткрываем на ОБЩЕМ инстансе образца (старые копии удалены, поэтому
	-- владельца и объект задаём явно: setCurrentObject по удалённому моду не найдёт стек).
		if applied do ORM_refreshModPanel show:refMod owner:refObj
	)
	catch
	(
		ORM_logExcept "instancifyOuter" (getCurrentException() as string)
	)
	g_orm_suspendRefresh = false
	if g_orm_debug do format "ModPropsLister[inst]: ORM_instancifyModifier returns %\n" applied
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
-- show:/owner: — принудительно показать конкретный мод на конкретном узле
-- (например, общий инстанс после конвертации, когда старые копии уже удалены).
fn ORM_refreshModPanel show:undefined owner:undefined =
(
	if not (ORM_validTargets()) do ( if g_orm_debug do format "ModPropsLister[panel]: skip, no valid targets\n"; return false )
	-- Панель Modify считается открытой, если командная панель в режиме #modify.
	-- getCurrentObject() после удаления мода скриптом может вернуть undefined,
	-- поэтому ориентируемся на режим, а не на текущий объект.
	local taskMode = getCommandPanelTaskMode()
	if taskMode != #modify do
		( if g_orm_debug do format "ModPropsLister[panel]: skip, taskMode=% not #modify\n" (taskMode as string); return false )
	local savedSel = selection as array
	if savedSel.count == 0 do ( if g_orm_debug do format "ModPropsLister[panel]: skip, empty selection\n"; return false )
	-- Узел, которому принадлежит показываемый панелью объект. Узлы направленных
	-- инстансов общие, но на всякий случай ищем владельца: иначе не рискуем
	-- перещёлкивать панель на чужой стек.
	local curObj = show
	local panelOwner = owner
	if curObj == undefined do curObj = modPanel.getCurrentObject()
	if panelOwner == undefined do
	(
		if isKindOf curObj Node do panelOwner = curObj
		for obj in g_orm_uniqueObjs do
		(
			if panelOwner != undefined do exit
			if curObj == obj.baseObject do ( panelOwner = obj; exit )
			for m in obj.modifiers do
				if m == curObj do ( panelOwner = obj; exit )
		)
	)
	if panelOwner == undefined do ( if g_orm_debug do format "ModPropsLister[panel]: skip, no owner for %\n" (curObj as string); return false )
	if g_orm_debug do format "ModPropsLister[panel]: setCurrentObject % on %\n" (curObj as string) (panelOwner as string)
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
	g_orm_propLookup[propNameStr]
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
	local modIdx    = lookup.modIdx
	local realName  = lookup.propName
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
	undo "ModPropsLister Color" on ( ORM_applyProperty lookup.modIdx lookup.propName val )
	true
)

fn ORM_propPoint3Changed propNameStr component val =
(
	local lookup = ORM_lookupFind propNameStr
	if lookup == undefined do return false
	local modIdx   = lookup.modIdx
	local realName = lookup.propName

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

-- Конвертировать выбранный модификатор в инстанс (обёртка кнопки)
fn ORM_onInstancifyMod idx =
(
	if g_orm_debug do format "ModPropsLister[inst]: ORM_onInstancifyMod idx=% modClasses.count=%\n" idx g_orm_modClasses.count
	if idx < 1 or idx > g_orm_modClasses.count do return false
	ORM_instancifyModifier g_orm_modClasses[idx]
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
	local modIdx   = lookup.modIdx
	local realName = lookup.propName
	local prefix   = lookup.prefix

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
	local modIdx   = lookup.modIdx
	local realName = lookup.propName
	local prefix   = lookup.prefix

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
	local modIdx   = lookup.modIdx
	local realName = lookup.propName
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
	-- guard ДО индексации: сетка может прислать idx=0 (сброс при смене rows),
	-- а g_orm_listItems[0] бросает "array index must be positive number" (см. архитектура п. 2)
	if classOf idx != Integer or idx < 1 do return false
	local info = g_orm_listItems[idx]
	if classOf info != Array do return false
	g_orm_selInfo = info
	ORM_rebuildPropsRollout()
	-- Кнопки Inst и Delete активны ТОЛЬКО для модификатора, для baseobject — неактивны
	-- (см. архитектура п. 2): базу нельзя ни удалить, ни конвертировать в инстанс.
	-- Состояние enabled для мода меняется галочкой в колонке сетки, кнопки тут нет.
	if info[1] == "mod" and info[2] <= g_orm_result.modDataList.count then
	(
		g_orm_rollMods.btn_delete.enabled = true
		g_orm_rollMods.btn_inst.enabled   = true
	)
	else
	(
		g_orm_rollMods.btn_delete.enabled = false
		g_orm_rollMods.btn_inst.enabled   = false
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
	-- Колбэка на смену enabled в Max нет, но пересобирать весь список не нужно:
	-- меняется только картинка глаза тогглнутой строки (обновляем одну ячейку —
	-- никакого моргания/пересборки остальных строк).
	local idx0 = -1
	try ( idx0 = g_orm_rollMods.lst_mods.CurrentRow.Index ) \
		catch ( ORM_logExcept "toggleRow" (getCurrentException() as string) )
	if idx0 < 0 or idx0 >= g_orm_listItems.count then ( ORM_refreshList(); return true )
	local fixed = false
	-- Текущий выделенный мод == тот, что переключаем (внешняя синхронизация); если вдруг
	-- CurrentRow отстаёт от g_orm_selInfo — ищем по modDataIdx и обновляем его строку.
	if g_orm_listItems[idx0 + 1] == g_orm_selInfo then
		fixed = ORM_refreshEyeRow idx0 g_orm_listItems[idx0 + 1]
	else
	(
		for i = 1 to g_orm_listItems.count do
		(
			local it = g_orm_listItems[i]
			if classOf it == Array and it.count >= 2 and it[1] == "mod" and it[2] == modDataIdx do
			(
				fixed = ORM_refreshEyeRow (i - 1) it
				exit
			)
		)
	)
	if not fixed do ORM_refreshList()
	true
)

-- Очистка интерфейса: старые данные не показываем, когда выделение снято (см. архитектура п. 8)
fn ORM_clearUI msg:"No selection." =
(
	local changed = false
	if g_orm_rollMods != undefined do
	(
		local gd = g_orm_rollMods.lst_mods
		local oldCnt = gd.Rows.Count
		local oldText = ""
		if oldCnt == 1 do try ( oldText = gd.Rows.Item[0].Cells.Item[1].Value as string ) \
			catch ( ORM_logExcept "listItemRead" (getCurrentException() as string) )
		if oldCnt != 1 or oldText != msg do
		(
			ORM_listSetItems #(msg)
			changed = true
		)
		-- Сброс выделения: SelectionChanged неиндексирует пустой список,
		-- просто отключает кнопки удаления/инстанса.
		gd.ClearSelection()
		gd.CurrentCell = undefined
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

	-- Убираем свитки свойств из floater'а (кэш сохраняется, см. архитектура п. 4)
	ORM_rlRemoveAll()
	changed = true
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
	local prevIdx0 = -1
	try ( prevIdx0 = g_orm_rollMods.lst_mods.CurrentRow.Index ) \
		catch ( ORM_logExcept "refreshPrevRow" (getCurrentException() as string) )
	local wasSel = undefined
	local wasLabel = ""
	-- Форс-рестор из операции с приостановкой callbacks (конвертация в инстанс):
	-- стек после неё изменился, поэтому берём сохранённый label/тип, а не grid-захват.
	-- Потребляется ОДИН раз (autoSel:false), дальше работает обычный механизм.
	local forceRestore = (not autoSel and g_orm_forceRestore.count == 2 and classOf g_orm_forceRestore[1] == Array)
	if forceRestore do
	(
		wasSel = deepcopy g_orm_forceRestore[1]
		wasLabel = try ( g_orm_forceRestore[2] as string ) catch ( "" )
		g_orm_forceRestore = #()
	)
	-- Строка, которую мы выбираем в этом refresh (для повторного подтверждения подсветки
	-- ПОСЛЕ релэйаута автовысоты floater'а — релэйаут может погасить видимое выделение
	-- dotNet-сетки; повторный select идемпотентен (guarded по g_orm_lastSelKey) и
	-- только восстанавливает подсветку, свойства не пересобирает).
	local targetSelRow = -1
	if not forceRestore do
	(
		if prevIdx0 >= 0 and prevIdx0 < g_orm_listItems.count do
			wasSel = deepcopy g_orm_listItems[prevIdx0 + 1]
		if prevIdx0 >= 0 and prevIdx0 < g_orm_rollMods.lst_mods.Rows.Count do
			wasLabel = try ( g_orm_rollMods.lst_mods.Rows.Item[prevIdx0].Cells.Item[1].Value as string ) catch ( "" )
	)
	if g_orm_debug do
		format "ModPropsLister[refresh]: STEP 1 capture — prevIdx0=% Rows=% wasLabel='%' wasSel=% wasSelCnt=% g_orm_selInfo=%\n" \
			prevIdx0 g_orm_rollMods.lst_mods.Rows.Count wasLabel wasSel \
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
	g_orm_rollMods.btn_delete.enabled = false
	g_orm_rollMods.btn_inst.enabled = false
	if g_orm_debug do
		format "ModPropsLister[refresh]: STEP 2 rebuilt — g_orm_listItems.count=% listItems.count=% (Rows now %)\n" \
			g_orm_listItems.count listItems.count g_orm_rollMods.lst_mods.Rows.Count

	-- Убираем свитки свойств из floater'а (кэш сохраняется, см. архитектура п. 4)
	ORM_rlRemoveAll()
	g_orm_lastSelKey = ""

	-- При изменении выделения сразу выделяем первый элемент списка:
	-- это верхний модификатор стека, его свойства открываются сразу (см. архитектура п. 2).
	-- Выбор строки вызывает SelectionChanged → ORM_listSelectChanged → ORM_onListSelect.
	if autoSel then
	(
		if g_orm_listItems.count > 0 do
		(
			targetSelRow = 0
			ORM_selectRow 0
		)
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
				-- Выбор строки вызывает SelectionChanged → ORM_listSelectChanged →
				-- ORM_onListSelect → ORM_rebuildPropsRollout (свойства выбранного модификатора).
				targetSelRow = i - 1
				ORM_selectRow (i - 1)
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
		format "ModPropsLister[refresh]: STEP 4 final — CurrentRow=% Rows.Count=%\n" \
			(try ( g_orm_rollMods.lst_mods.CurrentRow.Index ) catch ( -1 )) g_orm_rollMods.lst_mods.Rows.Count

	-- Повторное подтверждение выделения ПОСЛЕ релэйаута автовысоты: если relayout
	-- погасил подсветку net-сетки, ещё раз выставляем ту же строку. Идемпотентно:
	-- свойство уже открыто (g_orm_lastSelKey совпадает) — SelectionChanged→onListSelect
	-- сделает ранний return и ничего не перестроит (см. архитектура п. 4).
	if targetSelRow >= 0 and targetSelRow < g_orm_rollMods.lst_mods.Rows.Count do
		ORM_selectRow targetSelRow

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
	-- Приостановка на время многошаговой операции (конвертация в инстанс): финальный
	-- пересбор делает сам обработчик, а промежуточные postModifier* только портят
	-- выделение сетки (см. g_orm_suspendRefresh).
	if g_orm_suspendRefresh do return false
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
	-- Закрытие окна — единственное место, где кэш свитков свойств РАЗРУШАЕТСЯ
	-- (destroyDialog). В любом другом переходе определения переиспользуются
	-- (см. архитектура п. 4).
	for k in g_orm_rlCache.keys do
		try ( destroyDialog g_orm_rlCache[k].rl ) \
			catch ( ORM_logExcept "destroyPropsClose" (getCurrentException() as string) )
	g_orm_rlCache = Dictionary #string
	g_orm_rlUid = 0
	g_orm_rlOpen = undefined
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
fn ORM_addPropControls rc modIdx prefix propInfo &height labelOverride:undefined =
(
	local pNameStr = propInfo.name as string
	local ctrlName = prefix + pNameStr
	local lookupKey = prefix + pNameStr
	g_orm_propLookup[lookupKey] = ORM_PropEntry lookupKey:lookupKey modIdx:modIdx propName:pNameStr prefix:prefix

	-- Подпись контрола: для встроенных свитков (g_orm_builtinDefs) — человеческое имя
	-- из макета, иначе — имя свойства Max. Спиннеры/цвет — с двоеточием, checkbox — без.
	local labelStr = (if labelOverride != undefined then (labelOverride as string) else pNameStr) + ":"
	local labelChk = if labelOverride != undefined then (labelOverride as string) else pNameStr

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

		rc.addControl #spinner ctrlName labelStr paramStr:(
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
		rc.addControl #checkbox ctrlName labelChk paramStr:(
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
		rc.addControl #colorpicker ctrlName labelStr paramStr:(
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

-- Средняя ВЕЛИЧИНА числовых параметров свитка (см. глобал g_orm_avgMag): только
-- ненулевые значения, точка3 считается по компонентам; всё нулевое → 1.0, чтобы шаг
-- спиннеров не схлопывался в 0.01 на пустых (нулевых) контролах. Пересчитывается при
-- каждом ОТКРЫТИИ свитка (значения выборки меняются), не только при построении.
fn ORM_calcAvgMag props =
(
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
	true
)

-- Поиск PropInfo в массиве props по ИМЕНИ свойства (имя как строка; для строк макета
-- встроенного свитка — его accessorKey, совпадающий с именем свойства Max).
fn ORM_rlFindProp props key =
(
	for p in props do
		if (p.name as string) == (key as string) do return p
	undefined
)

-- Макет встроенного свитка для класса (строки g_orm_builtinDefs) или undefined,
-- если для класса ручной свиток не задан (см. архитектура п. 4 / g_orm_builtinDefs).
fn ORM_builtinLayoutFor clsKey =
(
	local b = g_orm_builtinDefs[clsKey]
	if b == undefined do return undefined
	b.rows
)

-- Применение выбора radiobuttons встроенного свитка: state (1-based) маппится на ЗНАЧЕНИЕ
-- свойства (vals) и уходит в общий ORM_propChanged (тот же путь, что спиннер/checkbox).
fn ORM_radioApply lookupKey vals st =
(
	if g_orm_uiSuppress do return false
	if st < 1 or st > vals.count do return false
	local v = vals[st]
	if v == undefined do return false
	ORM_propChanged lookupKey v
	true
)

-- Разворачивает строки макета встроенного свитка: группы (контейнеры #(":group", "..",
-- #(дети))) отдают своих детей — для синхронизации и проверки доступности важен только
-- набор ЛИСТЬЕВЫХ строк (группа — чистый визуальный блок, своего контрола в ней нет).
fn ORM_rlFlattenLayout rows =
(
	local out = #()
	for row in rows do
	(
		if (row[1] as string)[1] == ":" and row.count > 2 then
		(
			local kids = ORM_rlFlattenLayout row[3]
			for k in kids do append out k
		)
		else
			append out row
	)
	out
)

-- Генерирует в rolloutCreator контролы ОДНОЙ строки встроенного свитка (g_orm_builtinDefs).
-- Строк может быть: группа #(":group", "Заголовок", #(дети...)) — НАСТОЯЩИЙ group-блок
-- rollout'а (рамка вокруг контролов; children вставляются внутрь между "(" и ")"), или
-- radiobutton, или обычное свойство (#(":group", "Заголовок") без детей — старый
-- label-разделитель).
--   gi — счётчик заголовков групп (имя label-контрола должно быть уникальным)
fn ORM_rlAddLayoutRow rc modIdx prefix row &height propList &gi =
(
	local key = row[1]
	if (key as string)[1] == ":" and row.count > 2 do -- ГРУППА: group "Заголовок" (дети)
	(
		rc.addText ("group \"" + (row[2] as string) + "\" (") filter:false
		height += 22
		for child in row[3] do
			ORM_rlAddLayoutRow rc modIdx prefix child &height propList &gi
		rc.addText (")") filter:false
		height += 20
		return true
	)
	if (key as string)[1] == ":" do -- заголовок группы: label-разделитель
	(
		gi += 1
		rc.addControl #label ("grp_" + (gi as string)) (row[2] as string) paramStr:"align:#left"
		height += 18
		return true
	)
	local p = ORM_rlFindProp propList key
	if p == undefined do return false

	if row[2] == #radio then
	(
		local ctrlName = prefix + (key as string)
		local lookupKey = ctrlName
		g_orm_propLookup[lookupKey] = ORM_PropEntry lookupKey:lookupKey modIdx:modIdx propName:(key as string) prefix:prefix
		local labels = row[4]
		local vals   = row[5]
		local defIdx = if p.value != undefined then (findItem vals (p.value as integer)) else 0
		if defIdx < 1 do defIdx = 1
		local disStr = if not p.allSame then " enabled:false" else ""
		local cols = 2
		local rows = ((labels.count + cols - 1) / cols)
		-- caption: поддерживается у radiobuttons; при сбое создания контрола (например,
		-- нестандартный параметр в этой версии Max) — откатываемся к радиокнопкам без
		-- подписи-колонтитула, чтобы не уронить построение всего свитка.
		local ok = true
		try
		(
			rc.addControl #radiobuttons ctrlName "" paramStr:(
				"caption:\"" + (row[3] as string) + "\" " \
				+ "labels:" + (labels as string) + " default:" + defIdx as string \
				+ " columns:" + cols as string + " align:#left height:" + (rows * 22) as string + disStr
			)
			ok = true
		)
		catch ( ok = false )
		if not ok do
		(
			try
				rc.addControl #radiobuttons ctrlName "" paramStr:(
					"labels:" + (labels as string) + " default:" + defIdx as string \
					+ " columns:" + cols as string + " align:#left height:" + (rows * 22) as string + disStr
				)
			catch
			(
				ORM_logExcept "rlRadioCtrl" (getCurrentException() as string)
				return false
			)
		)
		height += rows * 22 + 6
		local valsExpr = ""
		for v in vals do valsExpr += v as string + ","
		valsExpr = substring valsExpr 1 (valsExpr.count-1)
		rc.addHandler ctrlName #changed paramStr:"st" \
			codeStr:("if not g_orm_uiSuppress and ORM_radioApply \"" + lookupKey + "\" #(" + valsExpr + ") st do ()")
		return true
	)

	-- Прочие типы — переиспользуем генератор обычных контролов (спиннер/checkbox/цвет/point3)
	local info = ORM_PropInfo name:p.name value:p.value allSame:p.allSame ptype:row[2]
	ORM_addPropControls rc modIdx prefix info &height labelOverride:(row[3] as string)
	true
)

-- Поиск кэш-записи свитка свойств по классу: словарь, клас-ключ (см. архитектура п. 4)
fn ORM_rlFindByClass clsKey =
(
	g_orm_rlCache[clsKey]
)

-- СТРОИТ СВИТОК СВОЙСТВ для класса (один раз на класс, затем кэшируется, см. архитектура п. 4).
--   clsKey    — имя класса мода (Bend, Edit_Poly, ...) или "base"
--   bakeTitle — заголовок, запекаемый при построении (стабильный: имя класса). Живой
--               заголовок (Base: MIXED, "N lower duplicates") зависит от выборки и
--               переустанавливается при каждом открытии (ORM_rlOpenForSel) — в кэше его нет.
--   props     — #(ORM_PropInfo) этого класса (из выборки, где класс встретился первым)
--   modIdx    — modIdx первой выборки; в lookupTemplate НЕ попадает — при открытии
--               свитка g_orm_propLookup пересобирается АКТУАЛЬНЫМ modIdx.
-- Возврат — кэш-запись ORM_RlEntry (структура, поля именами):
--   rl             — значение rollout'а (переживает removeRollout, НЕ destroyDialog)
--   prefix         — СТАБИЛЬНЫЙ префикс контролов "c<uid>_" (НЕ зависит от modDataIdx —
--                    поэтому codeStr этого свитка работает для любого мода того же класса)
--   lookupTemplate — #(ORM_PropTemplate) БЕЗ modIdx (см. архитектура п. 4)
--   layout         — строки встроенного макета или undefined (см. g_orm_builtinDefs)
fn ORM_rlBuild clsKey bakeTitle props modIdx =
(
	local uid = g_orm_rlUid + 1
	g_orm_rlUid = uid
	local rolloutName = "g_orm_rlProps_" + (uid as string)
	local prefix = "c" + (uid as string) + "_"
	-- Для класса может быть задан ВСТРОЕННЫЙ (ручной) макет свитка — строки
	-- g_orm_builtinDefs (тестовый Extrude, см. глобал выше). Макет определяет ПОРЯДОК,
	-- группы (блоки-рамки) и radiobuttons; значения всегда берутся из props анализа.
	local layout = ORM_builtinLayoutFor clsKey

	-- Защита от ДУБЛЕЙ ИМЁН: getPropNames у некоторых объектов возвращает одно имя
	-- несколько раз — иначе rolloutCreator падает «control already defined». Оставляем
	-- первый случай каждого имени (сохраняя порядок), остальные дубли отбрасываем.
	local seenNames = #()
	local uniqProps = #()
	for p in props do
	(
		local pn = p.name as string
		if (findItem seenNames pn) == 0 do
		(
			append seenNames pn
			append uniqProps p
		)
	)
	props = uniqProps

	ORM_calcAvgMag props
	g_orm_propLookup = Dictionary #string

	local rc = rolloutCreator rolloutName bakeTitle
	rc.begin()
	-- Пересчёт автовысоты floater при разворачивании/сворачивании свитка.
	-- ORM_updateFloaterHeight и g_orm_maxFloaterH глобальны, поэтому видны
	-- из сгенерированного (safeExecute) rollout'а. (см. архитектура п.7)
	rc.addText ("on " + rolloutName + " rolledUp state do ORM_updateFloaterHeight()") filter:false

	local h = 10
	if layout != undefined then
	(
		local gi = 0
		for row in layout do
			ORM_rlAddLayoutRow rc modIdx prefix row &h props &gi
	)
	else if props.count == 0 then
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

	local rl = rc.end()

	-- lookupTemplate: без modIdx (подставляется живой modIdx при открытии, см. архитектура п. 4)
	local lookupTemplate = for k in g_orm_propLookup.keys collect
		ORM_PropTemplate lookupKey:(g_orm_propLookup[k].lookupKey) \
			propName:(g_orm_propLookup[k].propName) prefix:(g_orm_propLookup[k].prefix)

	ORM_RlEntry clsKey:clsKey rl:rl prefix:prefix lookupTemplate:lookupTemplate uid:uid layout:layout
)

-- Возвращает кэш-запись для класса, построив её при отсутствии, и КЛАДЁТ свиток во
-- floater так, чтобы About оставался ПОСЛЕДНИМ (см. архитектура п. 4). Повторный
-- вызов для уже добавленного свитка ничего не переносит — переключение модов идёт
-- open/close (без removeRollout/addRollout, без моргания списка модов).
fn ORM_rlAddIfMissing clsKey bakeTitle props modIdx =
(
	local entry = ORM_rlFindByClass clsKey
	if entry == undefined do
	(
		entry = ORM_rlBuild clsKey bakeTitle props modIdx
		if entry == undefined do return undefined
		g_orm_rlCache[clsKey] = entry
	)
	local rl = entry.rl
	-- Во floater кладём ОДИН раз: findItem учитывает уже добавленные свитки
	if g_orm_floater != undefined and (findItem g_orm_floater.rollouts rl) == 0 do
	(
		local hasAbout = (findItem g_orm_floater.rollouts g_orm_rollAbout) != 0
		if hasAbout do removeRollout g_orm_rollAbout g_orm_floater
		addRollout rl g_orm_floater
		if hasAbout do addRollout g_orm_rollAbout g_orm_floater
	)
	entry
)

-- Пересинхронизация контролов кэшированного свитка под текущую выборку (см. архитектура п. 4):
-- пересборка g_orm_propLookup с ЖИВЫМ modIdx (codeStr ходит в lookup по стабильному
-- ключу), значения из props, enabled=allSame (различие показывает Unify), диапазоны
-- спиннеров под величину значения. Программные установки — под g_orm_uiSuppress,
-- чтобы не стрельнули changed (см. архитектура п. 3).
fn ORM_rlSyncValues entry props modIdx =
(
	local rl       = entry.rl
	local prefix   = entry.prefix
	local template = entry.lookupTemplate
	local layout   = entry.layout
	g_orm_propLookup = Dictionary #string
	for t in template do
		g_orm_propLookup[t.lookupKey] = ORM_PropEntry lookupKey:t.lookupKey modIdx:modIdx \
			propName:t.propName prefix:t.prefix
	ORM_calcAvgMag props

	-- Синхронизируем «строки» свитка: для встроенного макета — его строки (группы,
	-- radiobuttons и т.п.), иначе — свойства анализа (обычный автоанализ).
	local rows = if layout != undefined then ORM_rlFlattenLayout layout else for p in props collect #(p.name, p.ptype)
	g_orm_uiSuppress = true
	for row in rows do
	(
		local key = row[1]
		if (key as string)[1] == ":" do continue -- заголовок группы: значений нет
		local kind = row[2]
		local p = ORM_rlFindProp props key
		local ctrlName = prefix + (key as string)
		if kind == #radio then
		(
			local c = ORM_ctrlByName rl ctrlName
			if c == undefined do continue
			local differing = (p != undefined and not p.allSame)
			c.enabled = not differing
			if p != undefined and p.value != undefined do
			(
				local vals = row[5]
				local idx = findItem vals (p.value as integer)
				if idx < 1 do idx = 1
				try ( c.state = idx ) \
					catch ( ORM_logExcept "rlSyncRadio" (getCurrentException() as string) )
			)
			continue
		)
		-- Строка макета, у которой нет свойства в текущем анализе — контрол не трогаем.
		if p == undefined do continue
		local differing = not p.allSame
		-- point3 НЕ имеет главного контрола: компоненты называются "<имя>_x/y/z"
		-- (см. ORM_addPropControls) — синхронизируем их отдельно.
		if p.ptype == #point3 then
		(
			local mk = ORM_ctrlByName rl (ctrlName + "_mk")
			if mk != undefined do mk.visible = differing
			if p.value != undefined do
			(
				local v = p.value
				for ci in #("x", "y", "z") do
				(
					local cc = ORM_ctrlByName rl (ctrlName + "_" + ci)
					if cc != undefined do
					(
						cc.enabled = not differing
						local nv = case ci of ( "x": v.x; "y": v.y; "z": v.z )
						if cc.value != nv do
							try ( cc.value = nv ) \
								catch ( ORM_logExcept "rlSyncP3" (getCurrentException() as string) )
					)
				)
			)
			continue
		)
		local c = ORM_ctrlByName rl ctrlName
		if c == undefined do continue
		c.enabled = not differing
		local mk = ORM_ctrlByName rl (ctrlName + "_mk")
		if mk != undefined do mk.visible = differing
		local ptype = if layout != undefined then kind else p.ptype
		case ptype of
		(
			#boolean:
			(
				if p.value != undefined do
					try ( c.checked = p.value ) \
						catch ( ORM_logExcept "rlSyncChk" (getCurrentException() as string) )
			)
			#integer:
			(
				if p.value != undefined do
				(
					local v = p.value as integer
					try ( if c.value != v do c.value = v ) \
						catch ( ORM_logExcept "rlSyncInt" (getCurrentException() as string) )
				)
			)
			#float:
			(
				if p.value != undefined do
				(
					local v = p.value as float
					try ( if c.value != v do c.value = v ) \
						catch ( ORM_logExcept "rlSyncFlt" (getCurrentException() as string) )
				)
			)
			#color:
			(
				if p.value != undefined do
					try ( c.color = p.value ) \
						catch ( ORM_logExcept "rlSyncCol" (getCurrentException() as string) )
			)
		)
	)
	g_orm_uiSuppress = false
	true
)

-- Открывает свиток свойств выбранного элемента: сворачивает прежний развёрнутый,
-- разворачивает нужный и пересинхронизирует значения под текущую выборку.
fn ORM_rlOpenForSel entry sectionTitle props modIdx =
(
	local rl = entry.rl
	ORM_rlSyncValues entry props modIdx

	if g_orm_rlOpen != undefined and g_orm_rlOpen != rl do
		g_orm_rlOpen.open = false
	rl.open = true
	g_orm_rlOpen = rl
	g_orm_rlProps = rl

	-- Живой заголовок зависит от выборки (Base: <Класс> / Base: MIXED (...), у модов —
	-- счётчик lower duplicates); в кэше заголовок «заморожен» на первое построение
	-- класса — перезаписываем при каждом открытии.
	try ( rl.title = sectionTitle ) catch ( ORM_logExcept "rlTitle" (getCurrentException() as string) )

	-- Сворачиваем About при выборе элемента (см. архитектура п. 2)
	if g_orm_rollAbout != undefined do g_orm_rollAbout.open = false

	-- Автовысота под новый набор открытых свитков
	ORM_updateFloaterHeight()
	true
)

-- Убирает ВСЕ свитки свойств из floater'а (смена выборки объектов). Кэш ПРИ ЭТОМ
-- СОХРАНЯЕТСЯ — определения переиспользуются при следующем выборе (см. архитектура п. 4).
fn ORM_rlRemoveAll =
(
	if g_orm_floater != undefined then
		for k in g_orm_rlCache.keys do
		(
			local rl = g_orm_rlCache[k].rl
			try ( removeRollout rl g_orm_floater ) \
				catch ( ORM_logExcept "removeRollout" (getCurrentException() as string) )
			rl.open = false
		)
	g_orm_rlOpen = undefined
	g_orm_rlProps = undefined
	g_orm_propLookup = Dictionary #string
	true
)

-- Доступен ли кэш-свиток класса для текущего набора свойств: у каждого свойства
-- должен быть его КОНТРОЛ, а у РАЗЛИЧАЮЩЕГОСЯ — ещё и кнопка «Сделать общим» (_mk).
-- Заметка: _mk создаётся только когда на момент построения свойство различалось
-- (см. ORM_addPropControls). Если позже то же свойство различается в новой выборке,
-- а _mk в свитке нет — Unify недоступен, свиток нужно пересобрать (ORM_rlDrop).
fn ORM_rlUsable entry props =
(
	local rl = entry.rl
	local prefix = entry.prefix
	local layout = entry.layout
	if layout != undefined then
	(
		-- Встроенный свиток: проверяем ТОЛЬКО строки макета, у которых есть свойство в
		-- анализе (строки без свойства не созданы). radiobuttons Unify НЕ имеют (см.
		-- ORM_rlAddLayoutRow) — для них проверяем только наличие контрола.
		-- Группы разворачиваем (ORM_rlFlattenLayout) — важен набор листьевых строк.
		for row in (ORM_rlFlattenLayout layout) do
		(
			local key = row[1]
			if (key as string)[1] == ":" do continue
			local p = ORM_rlFindProp props key
			if p == undefined do continue
			local ctrlName = prefix + (key as string)
			if row[2] == #radio then
			(
				if ORM_ctrlByName rl ctrlName == undefined do return false
				continue
			)
			local hasCtrl = if row[2] == #point3 then
				(ORM_ctrlByName rl (ctrlName + "_x") != undefined)
			else
				(ORM_ctrlByName rl ctrlName != undefined)
			if not hasCtrl do return false
			if not p.allSame and ORM_ctrlByName rl (ctrlName + "_mk") == undefined do return false
		)
		true
	)
	else
	(
		for p in props do
		(
			local ctrlName = prefix + (p.name as string)
			local hasCtrl = if p.ptype == #point3 then
				(ORM_ctrlByName rl (ctrlName + "_x") != undefined)
			else
				(ORM_ctrlByName rl ctrlName != undefined)
			if not hasCtrl do return false
			if not p.allSame and ORM_ctrlByName rl (ctrlName + "_mk") == undefined do return false
		)
		true
	)
)

-- Разрушает кэш-запись класса ПОЛНОСТЬЮ (removeRollout + destroyDialog + удаление из
-- кэша). Используется только когда кэш-свиток не покрывает текущее состояние класса
-- (см. ORM_rlUsable) — после этого ORM_rlAddIfMissing построит свиток заново.
fn ORM_rlDrop clsKey =
(
	local entry = ORM_rlFindByClass clsKey
	if entry == undefined do return false
	local rl = entry.rl
	if g_orm_floater != undefined do
		try ( removeRollout rl g_orm_floater ) \
			catch ( ORM_logExcept "rlDropRm" (getCurrentException() as string) )
	try ( destroyDialog rl ) \
		catch ( ORM_logExcept "rlDropDst" (getCurrentException() as string) )
	try ( g_orm_rlCache.remove clsKey ) \
		catch ( ORM_logExcept "rlDropRmKey" (getCurrentException() as string) )
	if g_orm_rlOpen == rl do
	(
		g_orm_rlOpen = undefined
		g_orm_rlProps = undefined
	)
	true
)

-- Открывает свиток свойств выбранного элемента (кэш по классу, см. архитектура п. 4):
-- свиток строится один раз на класс и при переключении модов разворачивается/
-- сворачивается без removeRollout/addRollout/destroyDialog — список модов не
-- перелэйаутается и не моргает.
fn ORM_rebuildPropsRollout =
(
	-- guard по типу: g_orm_selInfo может оказаться НЕ массивом (OK), см. архитектура п. 2
	if classOf g_orm_selInfo != Array or g_orm_selInfo.count == 0 do return false
	ORM_gestureCommit()
	g_orm_incrMap = #()

	-- Только переоткрывать, если выбранная запись реально поменялась (см. архитектура п. 4)
	local curKey = (g_orm_selInfo[1] as string) + "_" + (g_orm_selInfo[2] as string)
	if curKey == g_orm_lastSelKey and g_orm_rlProps != undefined do
		return true

	if g_orm_result == undefined do return false

	local isBaseObj = (g_orm_selInfo[1] == "base")
	local modDataIdx = g_orm_selInfo[2]

	local clsKey = ""
	local bakeTitle = ""
	local sectionTitle = ""
	local props = #()
	local modIdx = 0

	if isBaseObj then
	(
		if g_orm_result.baseObjData == undefined do return false
		local bd = g_orm_result.baseObjData
		-- Ключ базы УНИКАЛЕН по классу: у разных баз (Box, Sphere, ...) РАЗНЫЙ набор
		-- свойств, "base" сам по себе смешал бы их. Для MIXED — по общему суперклассу.
		clsKey = if bd.isMixed then
			"base:mixed:" + (if bd.commonSuper != undefined then bd.commonSuper else "*")
		else
			("base:" + (bd.objClass as string))
		bakeTitle = "Base"
		sectionTitle = if bd.isMixed then
			"Base: MIXED" + (if bd.commonSuper != undefined then " (" + bd.commonSuper + ")" else "")
		else
			("Base: " + (bd.objClass as string))
		props = bd.props
		modIdx = 0
	)
	else
	(
		if modDataIdx < 1 or modDataIdx > g_orm_result.modDataList.count do return false
		local md = g_orm_result.modDataList[modDataIdx]
		clsKey = md.modClass as string
		bakeTitle = md.displayName
		sectionTitle = md.displayName
		if md.lowerCount > 0 do
			sectionTitle += "  (" + md.lowerCount as string + " lower duplicates)"
		props = md.props
		modIdx = modDataIdx
	)

	-- База и «редакторы геометрии» (Edit Mesh/Spline/Poly) без поддерживаемых свойств
	-- показывают свиток-заглушку. Прочие моды без свойств — свиток НЕ показываем:
	-- сворачиваем прежний (он остаётся в кэше, см. архитектура п. 4), чтобы в floater
	-- не висели свойства НЕвыбранного мода.
	if props.count == 0 and not isBaseObj and not (ORM_isEditableGeomMod modDataIdx) do
	(
		if g_orm_rlOpen != undefined do g_orm_rlOpen.open = false
		g_orm_rlOpen = undefined
		g_orm_rlProps = undefined
		g_orm_propLookup = Dictionary #string
		g_orm_lastSelKey = curKey
		ORM_updateFloaterHeight()
		return false
	)

	local entry = ORM_rlAddIfMissing clsKey bakeTitle props modIdx
	if entry == undefined do return false

	-- Кэш-свиток построен с ДРУГОЙ картой различий (свойство различается, а _mk в
	-- свитке нет — см. ORM_rlUsable): пересобираем класс на месте. Это редкий случай
	-- (первая выборка класса была полностью «одинаковой»), обычное переключение модов
	-- остаётся open/close без пересборки (см. архитектура п. 4).
	if not (ORM_rlUsable entry props) do
	(
		ORM_rlDrop clsKey
		entry = ORM_rlAddIfMissing clsKey bakeTitle props modIdx
		if entry == undefined do return false
	)

	ORM_rlOpenForSel entry sectionTitle props modIdx

	-- Запоминаем, для какого выбора открыт свиток, чтобы не дублировать (см. архитектура п. 4)
	g_orm_lastSelKey = curKey

	true
)


-- ======================================================================
-- DOTNET LIST (DataGridView): BMP-глаз (кликабельный) + имя
-- ======================================================================

global g_orm_iconFrames = #()   -- кадры ModProps_16i.bmp (1..locIconCount), резаные по g_orm_iconSize px
global g_orm_eyeFrames  = #()   -- #(open, closed, mixed) — shared Bitmap для ImageColumn (кадры 9/10/11)
global g_orm_eyeBlank   = undefined  -- прозрачная заглушка глаза (base строка, нет иконок)
global g_orm_listIcons   = #()   -- параллельно g_orm_listItems: состояние глаза (9 вкл / 10 выкл / 11 mixed; base = 0)
global g_orm_listFlags   = #()   -- параллельно g_orm_listItems: true = инстанс (курсив)
global g_orm_debug       = false -- включить для логирования всех catch в Listener
-- ПРИМЕЧАНИЕ: шрифты (plain/italic) хранит сам rollout rollout_mods как локальные переменные
-- (fontND на DefaultCellStyle, fontItalicND — на ячейки-инстансы в ORM_listSetItems).

-- Программный выбор строки сетки (0-based). SelectionChanged вызовется автоматически
-- и отработает ORM_onListSelect. idx0 вне диапазона — сбрасываем выделение.
fn ORM_selectRow idx0 =
(
	if g_orm_rollMods == undefined do return false
	local gd = g_orm_rollMods.lst_mods
	try
	(
		gd.ClearSelection()
		if idx0 >= 0 and idx0 < gd.Rows.Count do
		(
			-- Сначала CurrentCell, ПОТОМ Selected: если в момент программного выделения
			-- сработает SelectionChanged, CurrentRow уже будет валидным (иначе при
			-- пустом CurrentCell grid.CurrentRow — null и handler проглатывает выбор).
			gd.CurrentCell = gd.Rows.Item[idx0].Cells.Item[1]
			gd.Rows.Item[idx0].Selected = true
		)
	)
	catch
	(
		if g_orm_debug do format "ModPropsLister: selectRow % failed: %\n" idx0 (getCurrentException() as string)
	)
	true
)

-- Двойная буферизация DataGridView (свойство защищённое, доступ через рефлексию)
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

-- Инициализация dotNet-сетки (DataGridView): 2 колонки (иконка глаза / имя),
-- тёмная тема, курсив для инстансов. BMP-фреймы загружаются из ModProps_16i.bmp.
fn ORM_initModList =
(
	if g_orm_rollMods == undefined do return false
	local gd = g_orm_rollMods.lst_mods
	try
	(
		-- Размер иконок/высоты строк — просто глобал в коде (по умолчанию маленькие 16px)
		if g_orm_iconSize == undefined do g_orm_iconSize = 16
		local C  = dotNetClass "System.Drawing.Color"
		local DGVSel = dotNetClass "System.Windows.Forms.DataGridViewSelectionMode"
		local BST = dotNetClass "System.Windows.Forms.BorderStyle"
		local CB  = dotNetClass "System.Windows.Forms.DataGridViewCellBorderStyle"
		local SM  = dotNetClass "System.Windows.Forms.DataGridViewColumnSortMode"

		gd.AllowUserToAddRows = false
		gd.AllowUserToDeleteRows = false
		gd.AllowUserToResizeRows = false
		gd.AllowUserToResizeColumns = false
		gd.ReadOnly = true
		gd.MultiSelect = true
		gd.SelectionMode = DGVSel.FullRowSelect
		gd.ColumnHeadersVisible = false
		gd.RowHeadersVisible = false
		gd.BorderStyle = BST.None
		gd.BackgroundColor = C.FromARGB 68 68 68
		gd.GridColor = C.FromARGB 68 68 68
		gd.RowTemplate.Height = g_orm_iconSize + 6
		try ( gd.CellBorderStyle = CB.None ) catch ( ORM_logExcept "gridBorder" (getCurrentException() as string) )
		try ( gd.EnableHeadersVisualStyles = false ) catch ( ORM_logExcept "gridHeaders" (getCurrentException() as string) )
		-- Шрифт задаётся в on rollout_mods open (lst_mods.DefaultCellStyle.Font = fontND):
		-- эта привязка оставляет plain/italic шрифты живыми для GDI+ (см. ORM_listSetItems).
		gd.DefaultCellStyle.BackColor = C.FromARGB 68 68 68
		gd.DefaultCellStyle.ForeColor = C.White
		gd.DefaultCellStyle.SelectionBackColor = (dotNetClass "System.Drawing.SystemColors").Highlight
		gd.DefaultCellStyle.SelectionForeColor = (dotNetClass "System.Drawing.SystemColors").HighlightText

		-- Колонки: 0 — иконка глаза (ImageColumn, кадры 9/10/11 из BMP),
		-- 1 — имя мода (курсив для инстансов), всех свободная ширина.
		gd.Columns.Clear()
		local colIcon = dotNetObject "System.Windows.Forms.DataGridViewColumn"
		colIcon.Name = "Eye"
		colIcon.Width = g_orm_iconSize + 4
		colIcon.ReadOnly = true
		try ( colIcon.SortMode = SM.NotSortable ) catch ( ORM_logExcept "eyeSort" (getCurrentException() as string) )
		local icoCell = dotNetObject "System.Windows.Forms.DataGridViewImageCell"
		-- ImageLayout = Zoom (3): масштабирует иконку на ячейку с сохранением пропорций.
		-- Enum DataGridViewImageCellLayout: NotSet=0, Normal=1, Stretch=2, Zoom=3.
		try ( icoCell.ImageLayout = (dotNetClass "System.Windows.Forms.DataGridViewImageCellLayout").Zoom ) \
			catch ( try ( icoCell.ImageLayout = 3 ) catch ( ORM_logExcept "eyeLayout" (getCurrentException() as string) ) )
		colIcon.CellTemplate = icoCell
		local colName = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
		colName.Name = "Name"
		colName.ReadOnly = true
		colName.AutoSizeMode = (dotNetClass "System.Windows.Forms.DataGridViewAutoSizeColumnMode").Fill
		gd.Columns.Add colIcon
		gd.Columns.Add colName
	)
	catch
	(
		if g_orm_debug do format "ModPropsLister: initModList setup failed: %\n" (getCurrentException() as string)
	)
	ORM_enableDoubleBuffered gd
	-- Загружаем кадры BMP и извлекаем 3 состояния глаза для ImageColumn
	g_orm_iconFrames = ORM_loadIconFrames icon_path
	if g_orm_iconFrames.count >= 11 then
		g_orm_eyeFrames = #( g_orm_iconFrames[9], g_orm_iconFrames[10], g_orm_iconFrames[11] )
	else
	(
		g_orm_eyeFrames = #()
		if g_orm_debug do format "ModPropsLister: initModList: iconFrames only % (need 11), eye icons disabled\n" g_orm_iconFrames.count
	)
	-- Прозрачная заглушка глаза: 1x1 с нулевой альфой — в ячейку baseobject ничего не рисует,
	-- при этом не превращает ячейку в «битую картинку» (DataGridViewImageCell с null value рисует
	-- крестик ошибки, поэтому используем явный transparent Bitmap).
	try
	(
		g_orm_eyeBlank = dotNetObject "System.Drawing.Bitmap" 1 1 (dotNetClass "System.Drawing.Imaging.PixelFormat").Format32bppArgb
		g_orm_eyeBlank.SetPixel 0 0 ((dotNetClass "System.Drawing.Color").FromARGB 0 0 0 0)
	)
	catch
	(
		g_orm_eyeBlank = undefined
		if g_orm_debug do format "ModPropsLister: initModList: eyeBlank create failed: %\n" (getCurrentException() as string)
	)
	gd.Invalidate()
	true
)

-- Bitmap глаза для строки по состоянию eyeIdx (9/10/11); base и «нет иконок» — прозрачная заглушка.
-- Единая точка: используется в ORM_listSetItems (полная пересборка) и ORM_refreshEyeRow (точечная).
fn ORM_eyeBitmapFor eyeIdx =
(
	if g_orm_eyeFrames.count >= 3 then
		case eyeIdx of
		(
			9:  return g_orm_eyeFrames[1]
			10: return g_orm_eyeFrames[2]
			11: return g_orm_eyeFrames[3]
		)
	if g_orm_eyeBlank != undefined then g_orm_eyeBlank
	else undefined
)

-- Точечное обновление глаза ОДНОЙ строки (без пересборки всего списка — нет моргания).
-- idx0 — 0-based индекс строки; элемент должен быть #("mod", mi).
-- После ORM_toggleModifier меняется только картинка глаза, текст/курсив не трогаем.
fn ORM_refreshEyeRow idx0 info =
(
	if g_orm_rollMods == undefined or g_orm_eyeFrames.count < 3 do return false
	local gd = g_orm_rollMods.lst_mods
	if idx0 < 0 or idx0 >= gd.Rows.Count do return false
	if classOf info != Array or info.count < 2 or info[1] != "mod" do return false
	local modIdx = info[2]
	if modIdx < 1 or modIdx > g_orm_result.modDataList.count do return false
	local eyeIdx = ORM_eyeIdxForStates (ORM_getEnabledStates modIdx)
	g_orm_listIcons[idx0 + 1] = eyeIdx
	gd.Rows.Item[idx0].Cells.Item[0].Value = ORM_eyeBitmapFor eyeIdx
	true
)

-- Полная замена содержимого списка (сборка строк — ORM_buildListItems).
-- В ячейки колонки 0 кладутся BMP-иконки из g_orm_eyeFrames (open/closed/mixed),
-- в колонку 1 — текст модификатора с курсивом для инстансов.
fn ORM_listSetItems listItems =
(
	if g_orm_rollMods == undefined do return false
	local gd = g_orm_rollMods.lst_mods
	gd.SuspendLayout()
	gd.Rows.Clear()
	-- BMP-иконки глаза: open (9), closed (10), mixed (11) — через shared-функцию;
	-- baseobject (eyeIdx 0/иной) и отсутствие иконок → прозрачная заглушка (пустой фон).
	local hasEyes = (g_orm_eyeFrames.count >= 3)
	for i = 1 to listItems.count do
	(
		local r = gd.Rows.Add()
		local eyeIdx = if i <= g_orm_listIcons.count then g_orm_listIcons[i] else 0
		local iconCell = gd.Rows.Item[r].Cells.Item[0]
		iconCell.Value = if hasEyes then ORM_eyeBitmapFor eyeIdx else undefined
		gd.Rows.Item[r].Cells.Item[1].Value = listItems[i]
		-- Курсив для инстансов
		if i <= g_orm_listFlags.count and g_orm_listFlags[i] do
			gd.Rows.Item[r].Cells.Item[1].Style.Font = g_orm_rollMods.fontItalicND
	)
	-- Снимаем выделение, чтобы SelectionChanged не сработал на перезаполнении
	gd.ClearSelection()
	gd.CurrentCell = undefined
	gd.ResumeLayout()
	gd.Invalidate()
	true
)

-- Реакция на смену выделения dotNet-сетки (0-based CurrentRow.Index):
-- idx>=1 → как старый on lst_mods selected; иначе — сброс (кнопки неактивны)
fn ORM_listSelectChanged =
(
	if g_orm_rollMods == undefined do return false
	local gd = g_orm_rollMods.lst_mods
	local idx = -1
	try ( idx = gd.CurrentRow.Index + 1 ) \
		catch ( ORM_logExcept "currentRow" (getCurrentException() as string) )
	if idx >= 1 then
		ORM_onListSelect idx
	else
	(
		g_orm_rollMods.btn_delete.enabled = false
		g_orm_rollMods.btn_inst.enabled = false
		true
	)
)


-- ======================================================================
-- UI: ROLLOUT "MODIFIERS" (статический)
-- ======================================================================
rollout rollout_mods "Modifiers"
(
	dotNetControl lst_mods "System.Windows.Forms.DataGridView" height:130 width:180 align:#left offset:[-4,0]

	-- Шрифты (plain/italic): rollout-локальные, создаются в on open. Плоский шрифт
	-- закрепляется за контролом (DefaultCellStyle.Font) и жив для GDI+; курсив
	-- применяется к ячейкам строк-инстансов (см. ORM_listSetItems).
	local fontND
	local fontItalicND

	-- Число кадров в ModProps_16i.bmp (см. комментарий у icon_path): rollout-локальная,
	-- глобал-функции читают число кадров из загруженной bitmap (см. ORM_loadIconFrames).
	local locIconCount = 13

	button btn_inst "" images:#(icon_path, undefined, locIconCount, 7, 7, 7, 7, true) \
		width:24 height:25 align:#right offset:[0,0] \
		tooltip:"Convert selected modifier to instance.\nAll objects will share one instance of the first found modifier."
	button btn_delete "" images:#(icon_path, undefined, locIconCount, 12, 12, 12, 12, true) \
		width:24 height:25 align:#right tooltip:"Remove modifier from the stack" offset:[0,50]

	label lbl_filter "Ignore:" align:#left offset:[-5,4] across:7
	checkbutton chk_geom    "" images:#(icon_path, undefined, locIconCount, 2, 2, 2, 2, true) tooltip:"Geometry"
	checkbutton chk_shape   "" images:#(icon_path, undefined, locIconCount, 3, 3, 3, 3, true) tooltip:"Shapes"
	checkbutton chk_light   "" images:#(icon_path, undefined, locIconCount, 4, 4, 4, 4, true) tooltip:"Light"
	checkbutton chk_camera  "" images:#(icon_path, undefined, locIconCount, 5, 5, 5, 5, true) tooltip:"Camera"
	checkbutton chk_helper  "" images:#(icon_path, undefined, locIconCount, 6, 6, 6, 6, true) tooltip:"Helpers"
	button btn_refresh "" images:#(icon_path, undefined, locIconCount, 13, 13, 13, 13, true) \
	align:#right tooltip:"Re-read the stack: update the list and properties"

	on lst_mods SelectionChanged sender args do
		ORM_listSelectChanged()

	-- Клик по иконке глаза (колонка 0) тоггает enabled как кнопка On/Off.
	-- Клик по тексту (колонка 1) — только выбор строки (SelectionChanged выше).
	on lst_mods CellMouseClick sender args do
	(
		if args.ColumnIndex != 0 or args.RowIndex < 0 do return false
		local rowIdx = args.RowIndex + 1
		if rowIdx > g_orm_listItems.count do return false
		local info = g_orm_listItems[rowIdx]
		if classOf info != Array or info.count < 2 or info[1] != "mod" do return false
		local modIdx = info[2]
		if modIdx < 1 or modIdx > g_orm_result.modDataList.count do return false
		-- Смешанное состояние (часть модов вкл, часть выкл):
		-- спрашиваем пользователя через popupmenu, а не переключаем вслепую (см. архитектура п. 2).
		-- Пункты меню (Enable/Disable) сами зовут ORM_toggleSelected.
		if ORM_isMixedEnabled modIdx then
			popUpMenu rmc_toggle
		else
			ORM_toggleSelected (not (ORM_getLiveEnabled modIdx))
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
		-- Запоминаем позицию строки в списке, чтобы после удаления выделение
		-- осталось на активном модификаторе под тем же индексом (следующем в стеке).
		local prevIdx0 = -1
		try ( prevIdx0 = rollout_mods.lst_mods.CurrentRow.Index ) \
			catch ( ORM_logExcept "delPrevRow" (getCurrentException() as string) )
		if ORM_onDeleteMod modDataIdx do
		(
			ORM_rebuildNow()
			local cnt = rollout_mods.lst_mods.Rows.Count
			if cnt > 0 and prevIdx0 >= 0 do
				ORM_selectRow (amin prevIdx0 (cnt - 1))
		)
	)

	on btn_inst pressed do
	(
		if g_orm_debug do format "ModPropsLister[inst]: pressed, g_orm_selInfo=%\n" (g_orm_selInfo as string)
		if classOf g_orm_selInfo != Array or g_orm_selInfo.count == 0 do
		(
			if g_orm_debug do format "ModPropsLister[inst]: selInfo invalid, bail\n"
			return false
		)
		if g_orm_selInfo[1] != "mod" do
		(
			if g_orm_debug do format "ModPropsLister[inst]: selInfo[1]='%' not 'mod', bail\n" (g_orm_selInfo[1] as string)
			messageBox "Base object cannot be converted to an instance." title:APP_TITLE
			return false
		)
		local modDataIdx = g_orm_selInfo[2]
		if g_orm_debug do format "ModPropsLister[inst]: modDataIdx=% modClasses.count=%\n" modDataIdx g_orm_modClasses.count
		if modDataIdx < 1 or modDataIdx > g_orm_modClasses.count do
		(
			if g_orm_debug do format "ModPropsLister[inst]: modDataIdx out of range, bail\n"
			return false
		)
		-- Запоминаем текущий выбранный элемент ДО конвертации: после неё стек меняется,
		-- и обычный grid-захват в ORM_refreshUI может не восстановить ту же строку.
		-- Callbacks на время конвертации приостановлены (g_orm_suspendRefresh), поэтому
		-- форс-рестор (g_orm_forceRestore) применится в финальном ORM_rebuildNow.
		local prevIdx0 = -1
		try ( prevIdx0 = rollout_mods.lst_mods.CurrentRow.Index ) \
			catch ( ORM_logExcept "instPrevRow" (getCurrentException() as string) )
		if prevIdx0 >= 0 and prevIdx0 < g_orm_listItems.count then
			g_orm_forceRestore = #(
				deepcopy g_orm_listItems[prevIdx0 + 1],
				try ( rollout_mods.lst_mods.Rows.Item[prevIdx0].Cells.Item[1].Value as string ) catch ( "" )
			)
		else
			g_orm_forceRestore = #()
		local applied = ORM_onInstancifyMod modDataIdx
		if not applied do g_orm_forceRestore = #()
		if applied do ORM_rebuildNow()
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
		try ( lst_mods.DefaultCellStyle.Font = fontND ) catch (
			if g_orm_debug do format "ModPropsLister: lst_mods.DefaultCellStyle.Font assign failed: %\n" (getCurrentException() as string)
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
	-- Ограничение: не выше 3/4 высоты рабочего стола (глобал считается на старте)
	local maxH = g_orm_maxFloaterH
	if newH > maxH do newH = maxH
	if newH < 200 do newH = 200
	-- Guard: если высота не изменилась — не трогаем size (лишний ресайз floater'а
	-- при переключении модификаторов давал заметное моргание всего интерфейса).
	-- newH float, size[2] integer — округляем до целого для сравнения.
	if (newH as integer) == g_orm_floater.size[2] do return true
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

	-- dotNet-сетка: BMP-глаз (кликабельный) + имя, курсив для инстансов
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
	rollout_mods.btn_delete.enabled = false
	rollout_mods.btn_inst.enabled = false

	-- При открытии сразу выделяем первый элемент списка (верхний модификатор стека);
	-- выбор строки вызывает SelectionChanged → ORM_listSelectChanged → ORM_onListSelect
	if listItems.count > 0 do
		ORM_selectRow 0

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
