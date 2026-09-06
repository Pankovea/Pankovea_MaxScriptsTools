/* #PankovScripts - InstancedEditMod

Добавляет модификатор Edit Spline / Edit Poly ИНСТАНСОМ на все выделенные объекты.

Использование:
    Customize -> Customize User Interface -> Toolbars -> #PankovScripts
    кнопка "Instanced Edit Mod" (либо запуск из Macro Scripts).

Правило выбора модификатора:
    - если ВСЕ выделенные опорные объекты - сплайны (superclassof baseObject == Shape),
      на ВСЕ объекты добавляется Edit Spline;
    - если среди выделенных есть хоть один меш/геометрия (GeometryClass),
      на ВСЕ объекты добавляется Edit Poly.
    Хелперы, свет, камеры и прочее в обработке не участвуют (правило не портят).

Позиция в стеке:
    - верхний модификатор стека имеет индекс 1, низ - obj.modifiers.count;
    - Edit Spline вставляется в ОБЛАСТЬ СПЛАЙНА: от базового объекта вверх
      проходим модификаторы, пока они в белом списке "не конвертирующих"
      (multiAdd_splineSafeMods: xform, bend, taper, twist, FFD, и т.д.);
      при первом конвертирующем (Extrude и т.п.) Edit Spline становится
      СРАЗУ ПОД ним снизу;
    - Edit Poly добавляется ВСЕГДА В САМЫЙ ВЕРХ (before:0), чтобы не ломать
      нижележащие конвертирующие модификаторы (Extrude и т.п.), которые
      не работают на Poly;
    - чтобы избежать "Modifier is not appropriate", модификаторы от 1 (верх)
      до места вставки временно ОТКЛЮЧАЮТСЯ (состояние запоминается),
      добавляется наш модификатор, затем всё включается в обратном порядке.

Инстанс:
    - один общий модификатор на группу объектов: правка одного меняет все;
    - в имя модификатора приписывается " multi (N)", где N - число объектов,
      разделяющих этот инстанс (включая и тех, что вне текущего выделения);
    - при повторном запуске существующий инстанс ПЕРЕИСПОЛЬЗУЕТСЯ
      (новые объекты получают ссылку на него, без копирования внутренних
      действий), а число в имени увеличивается.
      Предполагается ОДНА группа инстанса на класс в выделении.

Режим выделения инстансов:
    - включается, если в Modify-панели открыт наш multi-модификатор
      (".. multi (N)"), ЛИБО все выделенные объекты разделяют один общий
      инстанс нашего модификатора;
    - при запуске скрипт НИЧЕГО не добавляет, а выделяет все объекты,
      разделяющие этот инстанс;
    - если такие объекты лежат в закрытой группе, группа ОТКРЫВАЕТСЯ,
      чтобы можно было выделить только их (setGroupOpen);
    - если ВСЕ объекты-инстансы находятся в одной группе и в этой группе
      больше нет объектов без нашего модификатора, группа НЕ открывается
      (выделяется целиком).

Режим Collapse To (Shift):
    при зажатой клавише Shift проходит по всем выделенным объектам,
    находит наш multi-модификатор (первый сверху в стеке) и выполняет
    Collapse To (maxOps.CollapseNodeTo): модификатор и всё ниже него
    сворачиваются в базовый объект (Editable_Spline / Editable_Poly),
    модификаторы ВЫШЕ остаются на месте;
    после этого повторный запуск без Shift добавит новый свежий
    multi-модификатор поверх оставшихся.

Отмена: прогон обёрнут в undo ("Instanced Edit Mod") или ("Instanced Edit Mod Collapse").

Panel: в конце прогона Modify-панель обновляется
    (modPanel.setCurrentObject того же объекта с ui:true), чтобы новый
    модификатор появился в окне стека.

*/

macroScript InstancedEditMod
	category:"#PankovScripts"
	ButtonText:"Instanced Edit Mod"
	tooltip:"Instance Edit_Spline or Edit_Poly modifier\nReuses and assigns it to objects without it.\nIf our modifier is open in the stack —\nall its instances are selected.\n\nShift: Collapse To our modifier into the base object"
	icon:#("FileLinkActionItems", 7)
	autoUndoEnabled:false
(

local VERSION = "1.0.0 (2026.08.30)"

-- == Настройки и реестр =====================================================

-- Запись реестра модификаторов. Определена на локальном уровне макроса.
--   name         - имя в стеке (без суффикса " multi (N)");
--   modifierClass - класс добавляемого модификатора (Edit_Spline, Edit_Poly...);
--   baseClass    - класс базового объекта (Shape, GeometryClass...), по которому
--                  объект считается кандидатом на этот модификатор, и который
--                  определяет позицию вставки в стеке (см. multiAdd_insertIndex).
struct multiAdd_spec (
	name,	modifierClass,	baseClass
)

-- Реестр модификаторов (локальный массив struct-записей).
-- Новые модификаторы добавляются строкой, при необходимости -
-- с собственным правилом в multiAdd_pickSpec.
local multiAdd_specs = #(
	multiAdd_spec "Edit Spline" Edit_Spline Shape,
	multiAdd_spec "Edit Poly"   Edit_Poly   GeometryClass
)

-- == Функции =================================================================

-- Класс базового объекта (Shape / GeometryClass и т.п.).
-- Используется для фильтрации кандидатов и правила выбора в multiAdd_pickSpec.
fn multiAdd_baseClass obj = superclassof obj.baseObject

-- Проверка кандидата: подходит ли объект хотя бы под одну запись реестра
-- (сравниваем с baseClass записи).
fn multiAdd_isCandidate obj =
(
	for spec in multiAdd_specs do
		if multiAdd_baseClass obj == spec.baseClass then return true
	false
)

-- Выбор спецификатора по правилу "все сплайны -> модификатор для Shape,
-- есть геометрия -> модификатор для GeometryClass".
fn multiAdd_pickSpec candidates =
(
	local allShapes = true
	for obj in candidates do
		if multiAdd_baseClass obj != Shape do ( allShapes = false; exit )

	local targetClass = if allShapes then Shape else GeometryClass
	for spec in multiAdd_specs do
		if spec.baseClass == targetClass then return spec
	undefined
)

-- Модификаторы, которые НЕ конвертируют сплайн в геометрию (остаются сплайном).
-- Расширяется строками. Edit Spline вставляется ТОЛЬКО в область сплайна,
-- т.е. ниже первого модификатора, которого нет в этом списке (он конвертирует).
local multiAdd_splineSafeMods = #(
	XForm, Bend, Taper, Twist, Conform, Flex, Melt, Noise, Mirror, Squeeze, Stretch,
	SplineSelect, Edit_Spline, Spline_Chamfer, SplineMirror,
	DeleteSplineModifier, SplineOverlap, Spline_IK_Control, SplineRelax,
	Normalize_Spl, Normalize_Spline2
)

-- Сохраняет ли модификатор m сплайн (не конвертирует в геометрию)?
fn multiAdd_isSplineSafe m =
(
	-- FFD-семейство (FFD 2x2x2, FFD 3x3x3, FFD 4x4x4 и т.д.): класс наследуется
	-- от FFDBox / совпадает по baseobject-хинту; проверяем по имени класса.
	if matchpattern (classof m as string) pattern:"FFD*" then return true
	for spec in multiAdd_splineSafeMods do
		if classof m == spec then return true -- or m.enabled == false (если решим исключить из рассмотрения выключенные)
	false
)

-- Позиция вставки Edit Spline (базовый класс Shape):
-- идём от базового объекта (низ стека, индекс count) к верху, пока модификаторы
-- в белом списке (сплайн-сохраняющие). Первый модификатор, конвертирующий сплайн
-- в геометрию (Extrude и т.п.), и есть граница: вставляем СРАЗУ ПОД ним снизу
-- (before:i). Если весь стек сплайн-безопасный - ставим в самый верх (before:0).
fn multiAdd_splineInsertIndex obj =
(
	local n = obj.modifiers.count
	if n == 0 then return 0
	-- первый конвертер от низа
	for i = n to 1 by -1 do
		if not (multiAdd_isSplineSafe obj.modifiers[i]) then return i
	-- конвертеров нет - вся область сплайна, ставим в самый верх
	0
)

-- Позиция вставки модификатора по классу базового объекта:
--   Shape         -> Edit Spline в области сплайна (по белому списку);
--   GeometryClass -> Edit Poly ВСЕГДА в самый верх (before:0), чтобы не ломать
--                    нижележащие конвертирующие модификаторы (Extrude и т.п.),
--                    которые не работают на Poly.
fn multiAdd_insertIndex obj spec =
(
	if spec.baseClass == Shape then multiAdd_splineInsertIndex obj
	else 0
)

-- Поиск на объекте уже добавленного скриптом инстанса (по классу и имени ".. multi (")
fn multiAdd_findExisting obj spec =
(
	for m in obj.modifiers do
		if classof m == spec.modifierClass and matchpattern m.name pattern:(spec.name + " multi (*") then
			return m
	undefined
)

-- Вспомогательный обработчик макроса
fn multiAdd_isEnabled = selection.count > 0

-- Принудительное обновление Modify-панели, чтобы изменения (новый модификатор,
-- его имя и позиция в стеке) появились в интерфейсе. Повторно открываем тот же
-- объект/модификатор, который был активен в стеке (см. документацию:
-- modPanel.setCurrentObject с ui:true переключает панель в режим Modify).
-- setCurrentObject сужает выделение до одного объекта, поэтому в конце
-- восстановливаем исходное выделение savedSel.
fn multiAdd_refreshPanel savedSel =
(
	if savedSel.count == 0 then return undefined
	local curObj = modPanel.getCurrentObject()
	local target = savedSel[1]
	max modify mode
	if curObj != undefined then
	(
		try modPanel.setCurrentObject curObj node:target ui:true
		catch modPanel.setCurrentObject target ui:true
	)
	else modPanel.setCurrentObject target ui:true
	select savedSel
	OK
)

-- Текущий модификатор в стеке Modify-панели, если это наш multi-инстанс
fn multiAdd_panelModifier =
(
	local cur = modPanel.getCurrentObject()
	if cur == undefined then return undefined
	for spec in multiAdd_specs do
		if (classof cur == spec.modifierClass) and (matchpattern cur.name pattern:(spec.name + " multi (*")) then
			return cur
	undefined
)

-- Голова группы, в которую входит объект (или undefined, если объект вне групп)
fn multiAdd_groupHead obj =
(
	if not (isValidNode obj) then return undefined
	if isGroupHead obj then return obj
	if isGroupMember obj and isValidNode obj.parent and isGroupHead obj.parent then
		return obj.parent
	undefined
)

-- Наши multi-модификаторы на объекте (все подходящие реестру multiAdd_specs)
fn multiAdd_ourModifiers obj =
(
	local res = #()
	for m in obj.modifiers do
		for spec in multiAdd_specs do
			if classof m == spec.modifierClass and matchpattern m.name pattern:(spec.name + " multi (*") then
				append res m
	res
)

-- Общий инстанс нашего модификатора, разделяемый ВСЕМИ выделенными объектами.
-- Возвращает модификатор или undefined, если такого общего инстанса нет.
fn multiAdd_commonInstanceModifier =
(
	local shared = undefined
	if selection.count == 0 then return undefined
	for obj in selection where isValidNode obj do
	(
		local mods = multiAdd_ourModifiers obj
		if mods.count == 0 then return undefined
		local m = mods[1]
		for k = 2 to mods.count do
			if mods[k] != m then return undefined
		if shared == undefined then shared = m
		else if m != shared then return undefined
	)
	shared
)

-- Вся ли группа (голова) состоит только из целей.
-- В закрытой группе выбирать можно лишь целиком, поэтому голову считать
-- «чистой» можно только если среди её членов нет объектов без нашего модификатора.
fn multiAdd_groupIsClean head targets =
(
	for c in head.children do
		if findItem targets c == 0 then return false
	true
)

-- Режим «выделить инстансы»: найти все объекты-инстансы модификатора m и выделить их.
-- Группы: закрытую группу с «чужими» объектами (без нашего модификатора) открываем
-- (узнать «открыта ли» позволяет isOpenGroupHead, открыть - setGroupOpen), чтобы
-- выделить только наши объекты. Если же ВСЕ наши объекты в одной группе и в ней
-- больше нет объектов без нашего модификатора - группу не открываем (выделяем целиком).
fn multiAdd_selectInstances m =
(
	local targets = for obj in (refs.dependentnodes m) where isValidNode obj collect obj
	if targets.count == 0 then
	(
		format "Instanced Edit Mod: у '%' нет инстансов-объектов.\n" m.name
		return 0
	)

	-- уникальные головы групп, в которые входят цели
	local heads = #()
	for t in targets do
	(
		local h = multiAdd_groupHead t
		if h != undefined and findItem heads h == 0 then append heads h
	)

	-- особый случай: все цели в ОДНОЙ группе, и в группе больше нет объектов
	-- без нашего модификатора -> группу НЕ открываем, выделяем целиком
	if heads.count == 1 and (multiAdd_groupIsClean heads[1] targets) then
	(
		select targets
		format "Instanced Edit Mod: выделено % инстансов (группа '%' не открывалась).\n" targets.count heads[1].name
		return targets.count
	)

	-- общий случай: открываем закрытые группы с «чужими» объектами и собираем выделение
	local selectable = #()
	for h in heads do
	(
		if multiAdd_groupIsClean h targets then
		(
			-- группа целиком наша: выделяем её голову (всю группу)
			append selectable h
			continue
		)
		if not (isOpenGroupHead h) then
			( setGroupOpen h true; format "Instanced Edit Mod: группа '%' открыта.\n" h.name )
		for t in targets do
			if multiAdd_groupHead t == h then append selectable t
	)

	-- цели вне групп
	for t in targets do
		if multiAdd_groupHead t == undefined then append selectable t

	select selectable
	format "Instanced Edit Mod: выделено % инстансов '%'.\n" targets.count m.name
	targets.count
)

-- Режим «Collapse To»: пройтись по всем выделенным объектам, найти наш multi-модификатор
-- (первый сверху) и сделать Collapse To (maxOps.CollapseNodeTo): модификатор и всё
-- ниже него сворачиваются в базовый объект (Editable_Spline / Editable_Poly),
-- модификаторы ВЫШЕ остаются. Вызывается при зажатой клавише Shift.
fn multiAdd_collapseSelected =
(
	if selection.count == 0 then return undefined
	local count = 0
	for obj in selection where isValidNode obj do
	(
		-- ищем наш multi-модификатор (первый сверху)
		local foundIdx = undefined
		for i = 1 to obj.modifiers.count do
		(
			for spec in multiAdd_specs do
				if classof obj.modifiers[i] == spec.modifierClass and matchpattern obj.modifiers[i].name pattern:(spec.name + " multi (*") then
				( foundIdx = i; exit )
			if foundIdx != undefined then exit
		)
		if foundIdx != undefined then
		(
			maxOps.CollapseNodeTo obj foundIdx true
			count += 1
		)
	)
	format "Instanced Edit Mod (Collapse): % из % объектов обработано.\n" count selection.count
	count
)

-- Основная логика
fn multiAdd_run =
(
	if selection.count == 0 then return undefined

	-- Shift: режим Collapse To
	if keyboard.shiftPressed then
	(
		undo "Instanced Edit Mod Collapse" on ( multiAdd_collapseSelected() )
		return OK
	)

	-- запоминаем выделение, чтобы восстановить его в конце (см. multiAdd_refreshPanel)
	local savedSel = selection as array

	-- режим «выделить инстансы»: в стеке Modify-панели активен наш multi-модификатор,
	-- либо ВСЕ выделенные объекты разделяют один общий наш multi-инстанс
	local panelMod = multiAdd_panelModifier()
	if panelMod == undefined then panelMod = multiAdd_commonInstanceModifier()
	if panelMod != undefined then
	(
		multiAdd_selectInstances panelMod
		return OK
	)

	-- кандидаты: только сплайны и геометрия
	local cands = #()
	for obj in selection where isValidNode obj do
		if multiAdd_isCandidate obj then append cands obj
	if cands.count == 0 then return undefined

	local spec = multiAdd_pickSpec cands
	if spec == undefined then return undefined

	undo "Instanced Edit Mod" on
	(
		-- разделяем кандидатов: уже с инстансом и свежие
		local existing = undefined
		local freshObjs = #()
		for obj in cands do
		(
			local m = multiAdd_findExisting obj spec
			if m == undefined then append freshObjs obj
			else if existing == undefined do existing = m
		)

		-- переиспользуем существующий инстанс или создаём новый
		local ctor = spec.modifierClass
		local m
		if existing != undefined then m = existing else m = ctor()

-- объекты "без" получают инстанс на корректную позицию:
			-- Edit Spline - после последнего Edit Spline у сплайна,
			-- Edit Poly - всегда в самый верх (before:0)
			local added = 0
			for obj in freshObjs do
			(
				local placeIdx = multiAdd_insertIndex obj spec

				-- временно отключаем модификаторы от 1 (верх) до placeIdx,
				-- чтобы избежать "Modifier is not appropriate" у того, что ниже
				local saved = #()
				for i = 1 to placeIdx do
				(
					local mm = obj.modifiers[i]
					append saved #(i, mm.enabled)
					mm.enabled = off
				)

				-- добавляем наш модификатор
				local ok = false
				try ( addModifier obj m before:placeIdx; ok = true )
				catch ( format "Instanced Edit Mod: не удалось повесить '%' на '%'.\n" spec.name obj.name )

			-- возвращаем состояние отключённых модификаторов в обратном порядке
			for s = saved.count to 1 by -1 do
				try ( obj.modifiers[saved[s][1]].enabled = saved[s][2] ) catch ()

			if ok then added += 1
		)

		-- число в имени = все, кто реально разделяет инстанс
		local cnt = 0
		try ( cnt = (refs.dependentnodes m).count ) catch ( cnt = cands.count )
		m.name = spec.name + " multi (" + (cnt as string) + ")"

		format "Instanced Edit Mod: '%' добавлен на % из % объектов (инстанс на %).\n" m.name added cands.count cnt
	)
	multiAdd_refreshPanel savedSel
	OK
)
	
on isEnabled do multiAdd_isEnabled()
on execute do multiAdd_run()
)