/* @Pankovea Scripts - Mass Import Grid v0.1 - 2026.09.25

Mass Import Grid: массовый импорт объектов с раскладкой в сетку по XY

Как работает:
1. Сразу после запуска открывается стандартный диалог выбора файлов
   (мультивыбор, по умолчанию - все поддерживаемые форматы). Своего окна у
   макроса нет: выбрали файлы - сразу импорт. Файлы можно задать и без диалога,
   списком или папкой - см. Pankovea_MassImportGrid.run в конце файла.
2. Каждый файл импортируется в сцену, новые объекты объединяются в группу.
3. Размер группы измеряется по мировому bounding box.
4. Группы раскладываются в сетку по плоскости XY: колонки = ceil(sqrt(N)),
   у каждого столбца своя ширина, у каждого ряда своя высота - по максимуму
   габаритов внутри них. Отступ задаётся в процентах от размера:
   ячейка = габарит * (1 + %/100). Ось Z не изменяется.
5. Вся операция - один шаг Undo.

Форматы: 3ds Max (*.max - merge), FBX, OBJ, Collada (dae), DWG, DXF.
Имя группы берётся из имени файла (можно отключить).
Настройки по умолчанию - локальные переменные migGapPct, migCols, migAnchor,
migCenterGrid, migNameFromFile, migSortFiles, migZoomExtents в начале файла.
Ничего никуда не записывается, ini не используется. Последняя папка - в
глобальной переменной PankovMIG_LastDir (живёт до перезапуска 3ds Max).

--

Mass Import Grid: mass import with XY grid layout.
No rollout: the standard multi-select file dialog opens and the import starts
right away. Each file is imported, grouped, measured by its world bounding box
and placed into an auto-sized grid on the XY plane. Column widths and row
heights are variable (max of the boxes inside them). Z is left untouched.
*/

macroScript Pankovea_MassImportGrid
	category:"#PankovScripts"
	buttonText:"MassImport"
	tooltip:"Массовый импорт .max/.fbx/.obj/.dae/.dwg/.dxf: группа, замер, раскладка в сетку по XY"
	icon:#("AutoGrid", 2)
(
	local FILE_EXTS = #("max", "fbx", "obj", "dae", "dwg", "dxf")
	-- ВНИМАНИЕ: строка фильтра .NET не должна заканчиваться висящим "|",
	-- иначе OpenFileDialog бросает "Filter string you provided is not valid".
	-- Первым идёт "все поддерживаемые", это значение по умолчанию: в .NET
	-- выбирается первая строка фильтра. Шаблоны перечисляются через ";".
	local FILE_ALL = "*.max;*.fbx;*.obj;*.dae;*.dwg;*.dxf"
	local FILE_TYPES = "Все поддерживаемые файлы|" + FILE_ALL + \
		"|3ds Max (*.max)|*.max|FBX (*.fbx)|*.fbx|OBJ (*.obj)|*.obj" + \
		"|Collada (*.dae)|*.dae|DWG (*.dwg)|*.dwg|DXF (*.dxf)|*.dxf" + \
		"|Все файлы (*.*)|*.*"

	-- Последняя ошибка: fn logErr определён ниже и должен видеть эту переменную,
	-- поэтому она объявлена до всех функций макроса
	local migLastError = ""

	-------------------------------------------------------------------------
	-- Настройки по умолчанию. Правятся здесь, в файле.
	-- Никакого ini: значения живут только в этой сессии.
	-------------------------------------------------------------------------

	local migGapPct = 10.0		-- свободное место вокруг объекта, % от его габарита
	local migCols = 0			-- 0 = авто (ceil(sqrt(N))), иначе фиксированное число
	local migAnchor = 1			-- 1 = центр габарита, 2 = левый нижний угол
	local migCenterGrid = true	-- центрировать сетку в начале координат
	local migNameFromFile = true	-- переименовывать группы по имени файла
	local migSortFiles = true		-- сортировать файлы по имени
	local migZoomExtents = true	-- показать импортированное во вьюпорте (Zoom Extents)

	-- Последняя папка - в глобальной переменной, переживает перезагрузку
	-- файла в пределах сессии, но не записывается на диск.
	--
	-- ВАЖНО, почему объявление именно такое:
	-- 1. Объявлять БЕЗ значения - "global X", а не "global X = ...".
	--    По справке <decl> ::= <var_name> [=<expr>] - значение необязательно.
	--    Если написать "global X = ...", присваивание поднимается на этап
	--    компиляции: переменная создаётся как undefined и в рантайме таковым
	--    и остаётся. Отсюда "Unable to convert: undefined to type: FileName"
	--    в initialDir.
	-- 2. global без значения НЕ затирает уже существующее значение,
	--    поэтому повторный fileIn сохраняет выбранную папку.
	-- 3. Значение по умолчанию проставляется, только если переменная ещё
	--    пустая. Это же чинит состояние, если макрос уже грузился
	--    с неправильным объявлением.
	global PankovMIG_LastDir
	if PankovMIG_LastDir == undefined do PankovMIG_LastDir = ""


	struct MIG_Item (
		node,				-- головной узел набора (группа или одиночный узел)
		roots = #(),		-- узлы, которые двигаем (верхний уровень набора)
		bb = box3(),		-- мировой габарит набора
		srcFile = ""
	)

	-------------------------------------------------------------------------
	-- Работа с файлами
	-------------------------------------------------------------------------

	fn isSupportedFile f = (findItem FILE_EXTS (toLower (getFilenameType f)) > 0)

	-- Компаратор для qsort: fn нельзя передать как выражение, только именем
	fn cmpNameCI a b = ((toLower (filenameFromPath a)) < (toLower (filenameFromPath b)))

	-- getSavePath возвращает путь с завершающим обратным слэшем, поэтому маска
	-- собирается без удвоения разделителя - иначе getFiles не находит файлы
	fn collectFromDir dir =
	(
		local res = #()
		local d = (dir as string)
		if d != "" do (
			local lastCh = substring d d.count 1
			local mask = if lastCh == "\\" then (d + "*.*") else (d + "\\*.*")
			for f in (getFiles mask) where (isSupportedFile f) and (doesFileExist f) do append res f
		)
		qsort res cmpNameCI
		res
	)

	-- Журнал ошибок: сообщение идёт и в Listener, и в интерфейс
	fn logErr msg =
	(
		migLastError = msg
		format "[MassImport] ОШИБКА: %\n" msg
	)

	-- Мультивыбор файлов. Нативного мультивыбора в MaxScript нет
	-- (getOpenFileName берёт ровно один файл), поэтому используется .NET.
	-- Возвращает #(files, failed), чтобы отличить "пользователь отменил"
	-- от ".NET-диалог не открылся" - иначе откат выглядит как будто
	-- мультивыбора нет.
	fn dotNetPickFiles initialDir =
	(
		local res = #()
		local failed = false
		local dlg = undefined
		local dlgResult = undefined
		local names = undefined
		local cnt = 0
		-- initialDir обязан быть строкой: undefined сюда попадать не может,
		-- иначе .NET бросит "Unable to convert: undefined to type: FileName"
		if initialDir == undefined do initialDir = ""
		try (
			try (dotNet.loadAssembly "System.Windows.Forms") catch ()
			dlg = dotNetObject "System.Windows.Forms.OpenFileDialog"
			dlg.Title = "Массовый импорт - выберите файлы"
			dlg.Multiselect = true
			dlg.CheckFileExists = true
			dlg.RestoreDirectory = true
			try (dlg.Filter = FILE_TYPES) catch (logErr ("Filter: " + (getCurrentException())))
			if initialDir != "" and doesDirectoryExist initialDir do dlg.InitialDirectory = initialDir
			dlgResult = dlg.ShowDialog()
			if (dlgResult.ToString()) == "OK" do (
				names = dlg.FileNames
				-- MaxScript отдаёт FileNames уже как обычный массив #(...),
				-- поэтому .count и [i]; .Length/GetValue - только если
				-- вернётся настоящий .NET-массив (на всякий случай оставлен try)
				cnt = 0
				try (cnt = names.count) catch (cnt = names.Length as integer)
				for i = 1 to cnt do append res (names[i] as string)
			)
		) catch (
			failed = true
			logErr ("NET OpenFileDialog: " + (getCurrentException()))
		)
		#(res, failed)
	)

	-- Основная точка выбора файлов: .NET мультивыбор, откат - выбор папки.
	-- Стартовая папка берётся из глобальной переменной, туда же пишется новая.
	fn pickFiles =
	(
		-- нормализация: getSavePath со строкой initialDir не принимает
		-- ничего, кроме строки, поэтому undefined исключаем заранее
		local lastDir = if PankovMIG_LastDir == undefined then "" else PankovMIG_LastDir
		local picked = dotNetPickFiles lastDir
		if picked[2] then (
			messageBox (".NET-диалог не открылся, мультивыбор недоступен.\n\nПричина (в Listener):\n" + migLastError + \
				"\n\nВыберите папку - будут взяты все файлы .max/.fbx/.obj/.dae/.dwg/.dxf из неё.") title:"Mass Import"
			local dir = getSavePath caption:"Выберите папку с файлами" initialDir:lastDir
			if dir != undefined then (
				if doesDirectoryExist dir do PankovMIG_LastDir = dir
				picked[1] = collectFromDir dir
				if picked[1].count == 0 do (
					logErr ("в папке нет поддерживаемых файлов: " + dir)
					messageBox ("Не найдено поддерживаемых файлов в папке:\n" + dir + "\n(.max, .fbx, .obj, .dae, .dwg, .dxf)") title:"Mass Import"
				)
			)
		)
		picked[1]
	)

	-------------------------------------------------------------------------
	-- Габариты
	-------------------------------------------------------------------------

	-- nodeGetBoundingBox требует матрицу, а для узлов без геометрии бросает ошибку,
	-- поэтому габарит собирается вручную по всему поддереву узла.
	-- Вырожденные боксы (голова группы, точки) в габарит не берутся.
	-- Список боксов вместо box3()-аккумулятора: пустой box3 имеет бессмысленные
	-- min/max, отличить его от настоящего бокса нельзя.
	fn collectBBoxes node acc =
	(
		local b = undefined
		try (b = nodeGetBoundingBox node (matrix3 1) asBox3:true) catch ()
		if b != undefined and (b.max.x > b.min.x or b.max.y > b.min.y or b.max.z > b.min.z) do append acc b
		for c in node.children do collectBBoxes c acc
		acc
	)

	-- Возвращает box3 набора или undefined, если геометрии нет
	fn rootsBBox roots =
	(
		local list = #()
		local acc = undefined
		for r in roots do collectBBoxes r list
		if list.count > 0 then (
			acc = list[1]
			-- объединение вручную: expandToInclude в 2026 существует только как
			-- глобальная функция expandToInclude <box3> <box3>, а метода
			-- <box3>.expandToInclude нет ("Unknown property")
			for i = 2 to list.count do (
				local b = list[i]
				acc.min = [amin acc.min.x b.min.x, amin acc.min.y b.min.y, amin acc.min.z b.min.z]
				acc.max = [amax acc.max.x b.max.x, amax acc.max.y b.max.y, amax acc.max.z b.max.z]
			)
		)
		acc
	)

	-------------------------------------------------------------------------
	-- Импорт одного файла
	-------------------------------------------------------------------------

	fn importAsItem f nameFromFile =
	(
		local beforeCount = objects.count
		local newNodes = #()
		local merged = #()
		local head = undefined
		local roots = #()
		local top = #()
		local bb = box3()
		local impErr = undefined
		local baseName = filenameFromPath f
		local extStr = getFilenameType baseName		-- ".FBX" с точкой

		if extStr != "" and baseName.count > extStr.count do
			baseName = substring baseName 1 (baseName.count - extStr.count)

		try (
			if (toLower (getFilenameType f)) == "max" then (
				mergeMAXFile f #autoRenameDups #noRedraw quiet:true \
					missingExtFilesAction:#logmsg missingXRefsAction:#logmsg missingDLLsAction:#logmsg \
					mergedNodes:&merged includeFullGroup:true
				if merged.count > 0 do newNodes = merged
			) else (
				importFile f #noPrompt
			)
		) catch (
			impErr = getCurrentException()
		)

		-- для .max берём mergedNodes, для остальных импортов - новые узлы
		-- добавляются в конец коллекции objects, т.е. это индексы > beforeCount.
		-- (битовый массив с узлом-индексом недопустим: "array index must be positive number")
		if newNodes.count == 0 and objects.count > beforeCount do (
			for i = (beforeCount + 1) to objects.count do append newNodes objects[i]
		)

		if newNodes.count == 0 do (
			if impErr != undefined do (
				format "[MassImport] % - импорт не удался: %\n" (filenameFromPath f) impErr
			)
			return undefined
		)

		-- верхний уровень набора: головы вложенных групп двигают своих участников
		roots = for nd in newNodes where (not (isGroupMember nd)) collect nd
		if roots.count == 0 do roots = newNodes

		if roots.count > 1 do (
			try (
				head = group roots select:false
				if not (isValidNode head) do head = undefined
			) catch ()
		)
		top = if head != undefined then #(head) else roots

		if nameFromFile and top.count == 1 do (
			try (top[1].name = baseName) catch ()
		)

		bb = rootsBBox top
		if bb == undefined do bb = box3 top[1].pos top[1].pos

		MIG_Item node:top[1] roots:top bb:bb srcFile:f
	)

	-------------------------------------------------------------------------
	-- Раскладка в сетку
	-------------------------------------------------------------------------

	-- Раскладка по сетке XY с ПЕРЕМЕННОЙ ячейкой: у каждого столбца своя
	-- ширина, у каждого ряда своя высота - максимум по габаритам внутри них.
	-- Так крупный ассет не растягивает всю партию.
	-- Возвращает #(cols, rows, totalW, totalH).
	fn layoutItems items gapPct colsOverride anchorMode centerGrid =
	(
		local total = items.count
		if total == 0 do return #(0, 0, 0.0, 0.0)

		local cols = if colsOverride > 0 then (amin colsOverride total) else (ceil (sqrt (total as float)))
		if cols < 1 do cols = 1
		local rows = ceil (total as float / cols)

		-- отступ в процентах от размера: ячейка = габарит * (1 + %/100)
		local k = 1.0 + ((gapPct as float) / 100.0)

		local colW = for j = 1 to cols collect 0.0
		local rowH = for r = 1 to rows collect 0.0
		for i = 1 to total do (
			local c = (mod (i - 1) cols) as integer
			local r = (((i - 1) - c) / cols) + 1
			local sz = items[i].bb.max - items[i].bb.min
			colW[c + 1] = amax colW[c + 1] (sz.x as float)
			rowH[r] = amax rowH[r] (sz.y as float)
		)
		for j = 1 to cols do colW[j] = colW[j] * k
		for r = 1 to rows do rowH[r] = rowH[r] * k

		-- накопленные отступы: левый край столбца и верхний край ряда
		local colX0 = #()
		local rowY0 = #()
		local acc = 0.0
		for j = 1 to cols do (
			colX0[j] = acc
			acc += colW[j]
		)
		local totalW = acc
		acc = 0.0
		for r = 1 to rows do (
			rowY0[r] = acc
			acc += rowH[r]
		)
		local totalH = acc

		-- начало сетки: по центру в начале координат или от нуля
		local x0 = if centerGrid then (-totalW / 2.0) else 0.0
		local y0 = if centerGrid then (totalH / 2.0) else 0.0

		for i = 1 to total do (
			local it = items[i]
			local c = (mod (i - 1) cols) as integer
			local r = (((i - 1) - c) / cols) + 1
			local left = x0 + colX0[c + 1]
			local top = y0 - rowY0[r]
			-- привязка 1 = центр габарита в центр ячейки, 2 = угол в угол ячейки
			local targetX = if anchorMode == 1 then (left + colW[c + 1] * 0.5) else left
			local targetY = if anchorMode == 1 then (top - rowH[r] * 0.5) else (top - rowH[r])
			-- it.bb всегда валидный: без геометрии там позиция узла
			local anchorPt = case anchorMode of (
				1: [(it.bb.min.x + it.bb.max.x) * 0.5, (it.bb.min.y + it.bb.max.y) * 0.5, 0]
				default: [it.bb.min.x, it.bb.min.y, 0]
			)
			local delta = [targetX - anchorPt.x, targetY - anchorPt.y, 0]
			if delta != [0,0,0] do (
				for nd in it.roots do nd.pos += delta
			)
		)

		#(cols, rows, totalW, totalH)
	)

	-------------------------------------------------------------------------
	-- Основная процедура
	-------------------------------------------------------------------------

	-- Возвращает #(items, errors, cancelled, fatalError, gridInfo)
	fn runMassImport files gapPct colsOverride anchorMode centerGrid nameFromFile =
	(
		local total = files.count
		local items = #()
		local errors = #()
		local cancelled = false
		local fatal = undefined
		local grid = #(0, 0, 0.0, 0.0)

		if total == 0 do return #(items, errors, cancelled, fatal, grid)

		with redraw off
		(
			undo label:"Mass Import Grid" on
			(
				progressStart "Mass Import Grid" allowCancel:true
				try (
					-- цикл while, а не for+exit: exit реализуется через скрытый
					-- try/catch и может быть перехвачен внешним catch
					local i = 1
					while i <= total and not cancelled do (
						local f = files[i]
						local pct = (((i - 1) as float) / (total as float)) * 100.0
						local stepName = "[" + (i as string) + "/" + (total as string) + "] " + (filenameFromPath f)
						if not (progressUpdate pct stepName:stepName) then
							cancelled = true
						else (
							local it = undefined
							local errMsg = undefined
							try (
								it = importAsItem f nameFromFile
							) catch (
								errMsg = getCurrentException()
							)
							if it != undefined then
								append items it
							else
								append errors #(f, (if errMsg == undefined then "объекты не созданы" else errMsg))
						)
						i += 1
					)
				) catch (
					fatal = getCurrentException()
				)
				progressEnd()

				-- при отмене раскладываем всё, что уже успело импортироваться
				if items.count > 0 do (
					grid = layoutItems items gapPct colsOverride anchorMode centerGrid
					deselect objects
					select (for it in items collect it.node)
				)
			)
		)
		completeRedraw()
		#(items, errors, cancelled, fatal, grid)
	)

	-------------------------------------------------------------------------
	-- Запуск без окна
	-------------------------------------------------------------------------

	-- Нормализует то, что пришло в run: массив файлов, один файл или папку.
	-- Поддерживаемые расширения отсеиваются, дубликаты убираются.
	fn gatherFiles arg =
	(
		local out = #()
		if arg == undefined then
			return out

		local raw = #()
		if isKindOf arg String then
			raw = #(arg)
		else if isKindOf arg Array then
			raw = arg
		else if isKindOf arg Name then
			raw = #(arg as string)

		for f in raw do (
			local s = f as string
			if doesDirectoryExist s then (
				-- папка: берём всё поддерживаемое из неё
				for g in (collectFromDir s) where ((findItem out g) == 0) do append out g
			)
			else if doesFileExist s then (
				if isSupportedFile s and (findItem out s) == 0 do append out s
			)
			else
				logErr ("не найден файл или папка: " + s)
		)
		out
	)

	-- Точка входа. Без аргументов открывает диалог выбора файлов,
	-- с аргументом импортирует сразу - файлом, папкой или массивом:
	--   macros.run "Pankovea_MassImportGrid" "run #(\"c:\\a.fbx\", \"c:\\b.max\")"
	--   macros.run "Pankovea_MassImportGrid" "run @\"c:\\папка\""
	-- Настройки - локальные переменные выше. Возвращает true, если импорт
	-- прошёл без критичной ошибки.
	fn run arg =
	(
		local files = if arg == undefined then (pickFiles()) else (gatherFiles arg)
		if files.count == 0 do return false

		-- запоминаем папку первого файла для следующего запуска
		local d = getFilenamePath files[1]
		if d != "" do PankovMIG_LastDir = d

		-- предсказуемый порядок раскладки: по имени файла, без учёта регистра
		if migSortFiles do qsort files cmpNameCI

		local res = runMassImport files migGapPct migCols migAnchor \
			migCenterGrid migNameFromFile
		local items = res[1]
		local errors = res[2]
		local grid = res[5]

		if res[4] != undefined then (
			logErr ("Импорт прерван: " + res[4])
			return false
		)

		format "[MassImport] Импортировано: %, ошибок: %, сетка: %x%, размер: % x %\n" \
			items.count errors.count grid[1] grid[2] grid[3] grid[4]

		-- Показать результат. max zoomext sel all - зум по выделенному,
		-- а импортированные узлы как раз выделены в конце runMassImport.
		-- Вызываем только если есть что показать, иначе зум отплющит пустую сцену.
		if migZoomExtents and items.count > 0 do (
			try (
				max zoomext sel all
				redrawViews()
			) catch (
				logErr ("Zoom Extents: " + (getCurrentException()))
			)
		)

		if errors.count > 0 do (
			local msg = "Не удалось импортировать файлы:\n"
			local shown = 0
			for e in errors while shown < 10 do (
				msg += ((filenameFromPath e[1]) + " - " + e[2] + "\n")
				shown += 1
			)
			if errors.count > shown do msg += ("... ещё " + ((errors.count - shown) as string) + "\n")
			messageBox msg title:"Mass Import"
		)

		true
	)

	on execute do run undefined
)
