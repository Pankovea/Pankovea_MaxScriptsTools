-- Pankovaea Scripts 
-- CropToAtlas v2.0
-- 10.08.2026
-- Упаковывает текстуры выбранных объектов в атлас(ы) и применяет UV-кропы.
-- Внешние инструменты/XML не нужны: компоновка, генерация изображений атласа и кроп выполняются здесь.
-- Для обработки изображений используется System.Drawing (GDI+).
-- Автовыбор формата в зависимости от наличия прозрачности
-- Автовыбор базового имени по имени группы

- added Russian docstrings to all functions

macroScript CropToAtlas category:"#PankovScripts" buttontext:"CropToAtlas" tooltip:"CropToAtlas - pack textures to atlas and apply crops" icon:#("Patches", 1)
(
	global MapToAtlasRollout

	try(destroyDialog MapToAtlasRollout) catch()

	dotNet.loadAssembly "System.Drawing"

	rollout MapToAtlasRollout "Crop To Atlas" width:350
		(
		-- Структуры данных
		--   sprInfo      — исходная текстура: имя, путь, размер
		--   placedSprite — размещённый спрайт: рамка (fx,fy,fw,fh), контент (w,h), признак поворота
		--   atlasEntry   — лист/атлас: размер, спрайты, свободные узлы, занятый прямоугольник (mx,my)
		--   freeNode     — свободный прямоугольник в листе
		--   packRef      — ссылка "текстура -> регион в атласе" для применения кропа
		struct sprInfo ( name="", file="", w=0, h=0 )
		struct placedSprite ( tex=undefined, fx=0, fy=0, fw=0, fh=0, w=0, h=0, rot=false )
		struct atlasEntry ( idx=0, name="", file="", w=0, h=0, sprites=#(), freeNodes=#(), mx=0, my=0 )
		struct freeNode ( x=0, y=0, w=0, h=0 )
		struct packRef ( file="", atlasFile="", atlasW=0, atlasH=0, x=0, y=0, w=0, h=0, rot=false )

		----------------------------------------------------------------------------------
		--( UI
		label lblSep "" height:4
		editText edtOutDir "Output" text:"" labelOnTop:true width:323 across:2 align:#left
		button btnBrowseDir "Browse..." align:#right width:64 offset:[0,-5]

		label lblSep1 "" height:4
		editText edtNameBase "Base name:" text:"" width:200 align:#left across:2
		checkbox chkAutoName "From group name" checked:true align:#right
		
		group ""
		(
			label blank1 "" across:3
			spinner spnMaxSize "Max atlas size:" range:[256,16384,4096] fieldWidth:50 type:#integer scale:1 align:#right
			checkbox chkRotate "Allow 90° rot" checked:true align:#right
			
			label blank2 "" across:3
			spinner spnMaxTex "Max texture size:" range:[16,16384,512] fieldWidth:50 type:#integer scale:1 align:#right across:2
			label blank3 ""
			
			label blank4 "" across:3
			spinner spnPad "Padding:" range:[0,16,2] type:#integer fieldWidth:50 scale:1 align:#right across:2 \
				tooltip:"Padding fills with the edge pixel of each sprite"
			label blank5 ""
			
			radioButtons rbFormat "Format:" labels:#(".JPG", ".PNG", ".Auto") default:3 columns:1 align:#left offset:[0,-70]
			spinner spnQuality "" range:[50,100,100] type:#integer scale:1 fieldWidth:30 align:#left
			label lbl1 "JPG quality" align:#left offset:[50,-20]
		)

		button btnMapList "Maps info" width:150 across:2 align:#left
		button btnMap "Crop Selected To Atlas" width:150 across:2 align:#right
		label lblSep2 "" height:4
		--) Конец UI
		----------------------------------------------------------------------------------


		----------------------------------------------------------------------------------
		--( Служебные функции

		-- Сохраняет все настройки элементов управления в INI
		-- Вход: thisRol — rollout; thisINI — путь к ini-файлу.
		fn SaveControlSettings thisRol thisINI =
		(
			for c in thisRol.controls do
			(
				if c.name == "edtOutDir" then continue
				case classof c of
				(
					SpinnerControl : setINISetting thisINI thisRol.name c.name (c.value as string)
					EditTextControl : setINISetting thisINI thisRol.name c.name c.text
					CheckboxControl : setINISetting thisINI thisRol.name c.name (c.checked as string)
					ComboBoxControl : setINISetting thisINI thisRol.name c.name (c.selection as string)
					RadioButtonsControl : setINISetting thisINI thisRol.name c.name (c.state as string)
					ColorPickerControl : setINISetting thisINI thisRol.name c.name (c.color as string)
				)
			)
		)

		-- Загружает настройки элементов управления из INI и применяет их
		-- Вход: thisRol — rollout; thisINI — путь к ini-файлу.
		fn LoadControlSettings thisRol thisINI =
		(
			if doesFileExist thisINI do
			(
				for c in thisRol.controls do
				(
					if c.name == "edtOutDir" then continue
					local cName

					try(cName = c.Name)catch(cName = "")
					if cName == undefined then cName = ""
					local controlValue = getINISetting thisINI thisRol.name cName

					if controlValue != "" do
					(
						case classof c of
						(
							SpinnerControl : c.value = controlValue as number
							EditTextControl : c.text = controlValue
							CheckboxControl : c.checked = controlValue as BooleanClass
							ComboBoxControl : c.selection = controlValue as number
							RadioButtonsControl : c.state = controlValue as integer
							ColorPickerControl : c.color = execute (controlValue)
						)
					)
				)
			)
		)

		-- Открывает диалог выбора папки и записывает результат в editBox.
		-- Вход: editBox — editText контрол; captionText — заголовок диалога;
		-- initDir — начальная директория (по умолчанию maxFilePath).
		fn BrowseForFolder editBox captionText initDir:maxFilePath =
		(
			dir = getSavePath caption:("Please locate this folder: " + captionText) initialDir:initDir
			if dir != undefined do
			(
				editBox.text = dir
			)
		)

		-- Показывает модальное окно с текстом и кнопками Copy / Ok.
		-- Вход: m — текст; title — заголовок; width — ширина текстового поля.
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

		-- Собирает все bitmap-текстуры объектов (bitmapTexture, CoronaBitmap, VrayBitmap).
		-- Вход: theObjects — массив нод. Выход: массив уникальных текстурных карт.
		fn GetBitmapTextures theObjects =
		(
			texMaps = #()
			for obj in theObjects do
			(
				join texMaps (getClassInstances bitmapTexture target:obj asTrackViewPick:off)
				try( join texMaps (getClassInstances CoronaBitmap target:obj asTrackViewPick:off) )catch()
				try( join texMaps (getClassInstances VrayBitmap target:obj asTrackViewPick:off) )catch()
			)
			makeUniqueArray texMaps
		)

		-- Возвращает корень группы объекта (самый верхний предок) или undefined,
		-- если объект не в группе. Вход: obj — нода.
		fn getGroupRoot obj =
		(
			local o = obj
			local hasParent = false
			while o.parent != undefined do
			(
				o = o.parent
				hasParent = true
			)
			if hasParent then o else undefined
		)

		-- Вычисляет базовое имя атласа: имя корня группы выделения (при одной группе
		-- берётся она; при нескольких — с наибольшим числом детей). Если групп нет —
		-- имя текущего файла сцены или "atlas".
		-- Вход: selObjects — массив выделенных нод. Выход: строка.
		fn getAutoBaseName selObjects =
		(
			local roots = #()
			for obj in selObjects do
			(
				local r = getGroupRoot obj
				if r != undefined and (findItem roots r) == 0 do append roots r
			)
			local root = undefined
			if roots.count == 1 then root = roots[1]
			else if roots.count > 1 then
			(
				local best = roots[1]
				local bestN = best.children.count
				for i=2 to roots.count do
				(
					local n = roots[i].children.count
					if n > bestN do ( best = roots[i]; bestN = n )
				)
				root = best
			)
			if root != undefined then root.name
			else
			(
				local fname = getFilenameFile maxfilename
				if fname == "" then "atlas" else fname
			)
		)

		-- Обновляет поле имени по имени группы текущего выделения (если авто-имя включено).
		fn UpdateNamePreview =
		(
			if chkAutoName.checked do
			(
				edtNameBase.text = getAutoBaseName (getCurrentSelection())
			)
		)

		-- Возвращает папку вывода: "<путь сцены>\maps\", если она существует,
		-- иначе "<путь сцены>\", иначе "" (сцена не сохранена).
		fn getOutputDir =
		(
			local mf = maxfilepath
			if mf == "" then ""
			else
			(
				local mapsDir = mf + "maps"
				if doesDirectoryExist mapsDir then (mapsDir + "\\") else mf
			)
		)

		-- Возвращает расширение файла атласа по состоянию переключателя формата.
		-- Вход: autoFmt — расширение, запомненное при авто-определении (".jpg" / ".png").
		fn getOutputExt autoFmt =
		(
			if rbFormat.state == 1 then ".jpg"
			else if rbFormat.state == 2 then ".png"
			else autoFmt
		)

		-- Создаёт System.Drawing.Rectangle из целочисленных координат.
		fn mkRect x y w h =
		(
			dotNetObject "System.Drawing.Rectangle" (x as integer) (y as integer) (w as integer) (h as integer)
		)

		-- Вход: file — путь к изображению.
		-- Выход: #(w, h, hasAlpha) или undefined, если файл не читается.
		-- hasAlpha — true, если у изображения есть альфа-канал (PixelFormat Argb).
		fn getTextureInfo file =
		(
			try
			(
				local img = dotNetObject "System.Drawing.Bitmap" file
				local w = img.Width
				local h = img.Height
				local hasA = (findString (img.PixelFormat.ToString()) "Argb") != undefined
				img.Dispose()
				#(w, h, hasA)
			)
			catch
			(
				try
				(
					local b = openBitmap file
					local s = [b.width, b.height]
					local hasA = b.hasAlpha
					close b
					#(s[1], s[2], hasA)
				)
				catch ( undefined )
			)
		)

		-- Приводит путь к абсолютному и проверяет существование файла.
		-- Выход: полный существующий путь или undefined.
		fn resolveTexFile f =
		(
			local full = try( pathConfig.convertPathToAbsolute f ) catch( f )
			if doesFileExist full then full else ( if doesFileExist f then f else undefined )
		)

		-- Округляет число до n знаков после запятой (по умолчанию до целого).
		fn round val n:0 = (
			local mult = 10.0 ^ n
			(floor ((val * mult) + 0.5)) / mult
		)
		
		--) Конец Служебных функций
		----------------------------------------------------------------------------------


		----------------------------------------------------------------------------------
		--( Генерация изображений атласа

		-- Дублирует `pad` пикселей краевых пикселей вокруг спрайта (в масштабе цели).
		-- Контент уменьшается ровно до w x h в целочисленной позиции, поэтому паддинг — точное
		-- количество пикселей с каждой стороны, и кроп (x,y,w,h) совпадает попиксельно. Границы —
		-- растянутые на поля 1px краевые полоски исходника; после компоновки со всех сторон
		-- срезается `drop` пикселей кольца артефактов билинейной фильтрации GDI+.
		fn drawWithBleed g img x y w h pad =
		(
			local unit = (dotNetClass "System.Drawing.GraphicsUnit").Pixel
			if pad <= 0 do
			(
				g.DrawImage img (mkRect x y w h) (mkRect 0 0 img.Width img.Height) unit
				return true
			)

			local drop = 6
			local padX = pad + drop
			local padY = pad + drop

			local tmpW = w + 2*padX
			local tmpH = h + 2*padY
			local tmp = dotNetObject "System.Drawing.Bitmap" tmpW tmpH (dotNetClass "System.Drawing.Imaging.PixelFormat").Format32bppArgb
			local tg = (dotNetClass "System.Drawing.Graphics").FromImage tmp
			tg.CompositingMode = (dotNetClass "System.Drawing.Drawing2D.CompositingMode").SourceCopy
			tg.InterpolationMode = (dotNetClass "System.Drawing.Drawing2D.InterpolationMode").HighQualityBilinear
			tg.PixelOffsetMode = (dotNetClass "System.Drawing.Drawing2D.PixelOffsetMode").Half
			tg.Clear (dotNetClass "System.Drawing.Color").Black

			-- контент уменьшается ровно до w x h в позиции (padX, padY)
			tg.DrawImage img (mkRect padX padY w h) (mkRect 0 0 img.Width img.Height) unit

			-- границы: 1px краевые полоски исходника, растянутые на поля, рисуются тем же фильтром
			-- HighQualityBilinear, что и контент, — паддинг выглядит как продолжение края, а не как
			-- алясинг-шум на тонких высококонтрастных узорах.
			-- Исходные прямоугольники вложены на 1px внутрь от края, чтобы фильтр никогда не выбирал
			-- пиксели за краем (GDI+ смешал бы с прозрачным чёрным -> полупрозрачная кромка).
			-- Каждая полоска перекрывает край контента на 1px, затирая краевой пиксель, которому
			-- билинейная фильтрация GDI+ задала alpha<255.
			tg.DrawImage img (mkRect 0 padY (padX+1) h) (mkRect 0 0 1 img.Height) unit
			tg.DrawImage img (mkRect (padX+w-1) padY (padX+1) h) (mkRect (img.Width-2) 0 1 img.Height) unit
			tg.DrawImage img (mkRect padX 0 w (padY+1)) (mkRect 0 0 img.Width 1) unit
			tg.DrawImage img (mkRect padX (padY+h-1) w (padY+1)) (mkRect 0 (img.Height-2) img.Width 1) unit
			tg.DrawImage img (mkRect 0 0 (padX+1) (padY+1)) (mkRect 0 0 1 1) unit
			tg.DrawImage img (mkRect (padX+w-1) 0 (padX+1) (padY+1)) (mkRect (img.Width-2) 0 1 1) unit
			tg.DrawImage img (mkRect 0 (padY+h-1) (padX+1) (padY+1)) (mkRect 0 (img.Height-2) 1 1) unit
			tg.DrawImage img (mkRect (padX+w-1) (padY+h-1) (padX+1) (padY+1)) (mkRect (img.Width-2) (img.Height-2) 1 1) unit
			tg.Dispose()

			-- переносим контент+паддинг в атлас точно в (x-pad, y-pad), срезая `drop` со всех сторон
			g.DrawImage tmp (mkRect (x-pad) (y-pad) (w+2*pad) (h+2*pad)) (mkRect drop drop (w+2*pad) (h+2*pad)) unit
			tmp.Dispose()
			true
		)

		-- Сохраняет Bitmap в файл. Для ".png" — PNG (сохраняет альфу), иначе JPEG
		-- с качеством spnQuality. Выход: true при успехе.
		fn saveAtlasImage imgObj filePath ext =
		(
			if ext == ".png" then
			(
				imgObj.Save filePath (dotNetClass "System.Drawing.Imaging.ImageFormat").Png
				return true
			)
			try
			(
				local codecs = (dotNetClass "System.Drawing.Imaging.ImageCodecInfo").GetImageEncoders()
				local enc = undefined
				for c in codecs do
				(
					if c.MimeType == "image/jpeg" do ( enc = c; exit )
				)
				if enc == undefined do
				(
					imgObj.Save filePath (dotNetClass "System.Drawing.Imaging.ImageFormat").Jpeg
					return true
				)
				local prm = dotNetObject "System.Drawing.Imaging.EncoderParameters" 1
				local prmArr = prm.Param
				prmArr.SetValue (dotNetObject "System.Drawing.Imaging.EncoderParameter" (dotNetClass "System.Drawing.Imaging.Encoder").Quality (dotNetObject "System.Int64" spnQuality.value)) 0
				imgObj.Save filePath enc prm
				true
			)
			catch
			(
				try ( imgObj.Save filePath (dotNetClass "System.Drawing.Imaging.ImageFormat").Jpeg; true ) catch ( false )
			)
		)

		-- Собирает один атлас из листа a (структура atlasEntry): рисует все спрайты
		-- с паддингом через drawWithBleed (с поворотом, если rot) и сохраняет файл a.file.
		-- Выход: true при успехе.
		fn buildAtlas a =
		(
			try
			(
				local pad = spnPad.value
				local atlasBmp = dotNetObject "System.Drawing.Bitmap" a.w a.h (dotNetClass "System.Drawing.Imaging.PixelFormat").Format32bppArgb
				local g = (dotNetClass "System.Drawing.Graphics").FromImage atlasBmp
				g.InterpolationMode = (dotNetClass "System.Drawing.Drawing2D.InterpolationMode").NearestNeighbor
				g.PixelOffsetMode = (dotNetClass "System.Drawing.Drawing2D.PixelOffsetMode").HighQuality
				g.CompositingMode = (dotNetClass "System.Drawing.Drawing2D.CompositingMode").SourceCopy
				g.Clear (dotNetClass "System.Drawing.Color").Black

				for s in a.sprites do
				(
					local src = try( dotNetObject "System.Drawing.Bitmap" s.tex.file ) catch( undefined )
					if src == undefined do continue
					local img = src
					if s.rot then
					(
						img = dotNetObject "System.Drawing.Bitmap" src
						-- поворот на 90 против часовой стрелки; компенсация в кропе: W_angle +90 (в обратную сторону)
						img.RotateFlip (dotNetClass "System.Drawing.RotateFlipType").Rotate270FlipNone
					)
					drawWithBleed g img (s.fx+pad) (s.fy+pad) s.w s.h pad
					if img != src do img.Dispose()
					src.Dispose()
				)
				g.Dispose()
				local saveOK = saveAtlasImage atlasBmp a.file (getFilenameType a.file)
				atlasBmp.Dispose()
				saveOK
			)
			catch
			(
				false
			)
		)

		--) Конец Генерации изображений атласа
		----------------------------------------------------------------------------------


		----------------------------------------------------------------------------------
		--( Алгоритм компоновки MAXRECTS

		-- Компаратор для сортировки спрайтов по убыванию: сначала большая сторона,
		-- затем площадь. Вход: a, b — sprInfo.
		fn cmpBig a b =
		(
			local aa = amax a.w a.h
			local bb = amax b.w b.h
			if aa != bb then aa > bb else (a.w * a.h) > (b.w * b.h)
		)

		-- Компаратор фреймов по убыванию площади контента.
		-- Вход: a, b — фреймы #(sprInfo, dw, dh, fw, fh).
		fn compareFrames a b =
		(
			(a[1].w * a[1].h) > (b[1].w * b[1].h)
		)

		-- Упаковка по методу MaxRects. Свободные прямоугольники — максимальные свободные области.
		-- После каждой установки РАЗРЕЗАЕТСЯ каждый свободный прямоугольник, которого касается новый
		-- спрайт, поэтому перекрытия невозможны.
		-- Оценка установки = (новая максимальная сторона, новая площадь, остаток короткой стороны).
		-- Сначала минимизируется максимальная сторона -> наименьший ограничивающий квадрат; при
		-- равенстве — меньшая площадь.
		-- Оценка установки прямоугольника w×h в свободном узле n листа sh.
		-- Выход: #(макс. сторона, площадь, остаток короткой стороны) или undefined,
		-- если размер не влезает в узел.
		fn scorePlacement n w h sh =
		(
			if w <= n.w and h <= n.h then
			(
				local nmx = amax sh.mx (n.x + w)
				local nmy = amax sh.my (n.y + h)
				#( (amax nmx nmy), (nmx * nmy), (amin (n.w-w) (n.h-h)) )
			)
			else undefined
		)

		-- Сравнивает две оценки установки. Вход: cur — текущая, new — новая.
		-- Выход: true, если new лучше (или cur == undefined).
		fn betterScore cur new =
		(
			if cur == undefined then return true
			if new[1] != cur[1] then return new[1] < cur[1]
			if new[2] != cur[2] then return new[2] < cur[2]
			new[3] < cur[3]
		)

		-- Ищет лучший свободный узел листа sh (структура atlasEntry) для фрейма fw×fh.
		-- allowRot — разрешать поворот на 90° (учитывается в scorePlacement).
		-- Выход: #(node или undefined, rot).
		fn findBestNode sh fw fh allowRot =
		(
			local bestScore = undefined
			local bestNode = undefined
			local bestRot = false
			for n in sh.freeNodes do
			(
				local s1 = scorePlacement n fw fh sh
				if s1 != undefined do
				(
					if (betterScore bestScore s1) do
					(
						bestScore = s1; bestNode = n; bestRot = false
					)
				)
				if allowRot and fh != fw then
				(
					local s2 = scorePlacement n fh fw sh
					if s2 != undefined do
					(
						if (betterScore bestScore s2) do
						(
							bestScore = s2; bestNode = n; bestRot = true
						)
					)
				)
			)
			#(bestNode, bestRot)
		)

		-- Разрезает свободный узел f (структура freeNode) занятым прямоугольником
		-- (x,y,w,h), добавляя оставшиеся куски в массив newRects.
		-- Выход: true, если прямоугольники пересекаются.
		fn splitFreeNode f x y w h newRects =
		(
			if (x + w) <= f.x or x >= (f.x + f.w) then return false
			if (y + h) <= f.y or y >= (f.y + f.h) then return false
			if (x + w) < (f.x + f.w) do
				append newRects (freeNode x:(x+w) y:f.y w:((f.x+f.w)-(x+w)) h:f.h)
			if (y + h) < (f.y + f.h) do
				append newRects (freeNode x:f.x y:(y+h) w:f.w h:((f.y+f.h)-(y+h)))
			true
		)

		-- Убирает из списка пустые, дублирующиеся и вложенные (покрытые другими) узлы.
		-- Вход: массив freeNode. Выход: массив freeNode.
		fn pruneNodes nodes =
		(
			local alive = for n in nodes where n.w > 0 and n.h > 0 collect n
			local result = #()
			for i=1 to alive.count do
			(
				local n = alive[i]
				local contained = false
				for j=1 to alive.count where j != i do
				(
					local m = alive[j]
					if n.x >= m.x and n.y >= m.y and (n.x+n.w) <= (m.x+m.w) and (n.y+n.h) <= (m.y+m.h) do
					(
						contained = true
						exit
					)
				)
				if not contained do append result n
			)
			local uniq = #()
			for n in result do
			(
				local dup = false
				for u in uniq do
					if u.x == n.x and u.y == n.y and u.w == n.w and u.h == n.h do ( dup = true; exit )
				if not dup do append uniq n
			)
			uniq
		)

		-- Размещает спрайт it в узле n листа s: фиксирует placedSprite, обновляет mx/my
		-- и режет свободные узлы.
		-- Вход: s — atlasEntry; it — sprInfo; n — freeNode; rot — повёрнут ли спрайт;
		-- dw,dh — размер контента; fw,fh — размер ячейки. Выход: обновлённый s.
		fn placeInSheet s it n rot dw dh fw fh =
		(
			local pfw = if rot then fh else fw
			local pfh = if rot then fw else fh
			local sw = if rot then dh else dw
			local sh = if rot then dw else dh
			append s.sprites (placedSprite tex:it fx:n.x fy:n.y fw:pfw fh:pfh w:sw h:sh rot:rot)
			s.mx = amax s.mx (n.x + pfw)
			s.my = amax s.my (n.y + pfh)

			local newRects = #()
			local remaining = #()
			for f in s.freeNodes do
			(
				if not (splitFreeNode f n.x n.y pfw pfh newRects) do append remaining f
			)
			join remaining newRects
			s.freeNodes = pruneNodes remaining
			s
		)

		-- Упаковывает список фреймов #(sprInfo,dw,dh,fw,fh) в лист S x S.
		-- Возвращает лист или undefined, если не все фреймы поместились.
		fn packFrames frames S pad allowRot =
		(
			local sh = atlasEntry idx:1 sprites:#() freeNodes:#(freeNode x:0 y:0 w:S h:S) mx:0 my:0
			for fr in frames do
			(
				local res = findBestNode sh fr[4] fr[5] allowRot
				if res[1] != undefined then
					sh = placeInSheet sh fr[1] res[1] res[2] fr[2] fr[3] fr[4] fr[5]
				else return undefined
			)
			sh
		)

		-- Перепаковывает элементы листа в наименьший квадрат, в который ещё помещаются все.
		-- Перепаковывает спрайты листа в наименьший квадрат, в который ещё помещаются
		-- все (бинарный поиск по размеру стороны). Выход: atlasEntry.
		fn repackSheet sh pad allowRot =
		(
			local frames = #()
			for s in sh.sprites do
			(
				local dw = if s.rot then s.h else s.w
				local dh = if s.rot then s.w else s.h
				append frames #(s.tex, dw, dh, dw+2*pad, dh+2*pad)
			)
			if frames.count <= 1 then return sh
			qsort frames compareFrames

			local lo = 0
			for fr in frames do lo = amax lo (amax fr[4] fr[5])
			local hi = amax sh.mx sh.my
			if hi < lo do hi = lo
			local bestSheet = packFrames frames hi pad allowRot
			while lo < hi do
			(
				local mid = ((lo + hi) / 2) as integer
				local attempt = packFrames frames mid pad allowRot
				if attempt != undefined then
				(
					bestSheet = attempt
					hi = mid
				)
				else
					lo = mid + 1
			)
			if bestSheet == undefined then sh else bestSheet
		)

		-- Главная упаковка: уменьшает текстуры до ячейки uiMax (длинная сторона),
		-- режет их на листы maxSize и минимизирует каждый лист.
		-- Вход: items — массив sprInfo; maxSize — макс. сторона листа;
		-- uiMax — макс. сторона ячейки; pad — паддинг; allowRot — разрешить поворот;
		-- skipped — массив, куда попадут имена не поместившихся текстур.
		-- Выход: массив atlasEntry.
		fn packTextures items maxSize uiMax pad allowRot skipped =
		(
			local sheets = #()
			if items.count == 0 do return sheets

			-- предварительный расчёт фреймов (уменьшение применяется один раз)
			-- Контент масштабируется равномерно так, чтобы длинная сторона влезла в maxTex = uiMax - 2*pad;
			-- паддинг затем добавляется обратно ТОЧНЫМ числом пикселей, поэтому длинная сторона ячейки ровно uiMax.
			-- round() (вместо старого усечения `as integer`) сохраняет точность — усечение обрезало 512 до 511
			-- и оставляло 1px чёрный шов между ячейками.
			local frames = #()
			local maxTex = uiMax - 2*pad
			if maxTex < 1 do maxTex = 1
			for it in items do
			(
				local dw = it.w
				local dh = it.h
				local longSide = amax dw dh
				if longSide > maxTex do
				(
					local k = maxTex / (longSide as float)
					dw = (round (dw * k)) as integer
					dh = (round (dh * k)) as integer
					if dw < 1 do dw = 1
					if dh < 1 do dh = 1
				)
				local fw = dw + 2*pad
				local fh = dh + 2*pad
				if fw > maxSize or fh > maxSize do
				(
					append skipped (it.name + " (" + (it.w as string) + "x" + (it.h as string) + ")")
					continue
				)
				append frames #(it, dw, dh, fw, fh)
			)
			if frames.count == 0 do return sheets

			qsort frames compareFrames

			-- этап 1: разбиение на листы жадной упаковкой при maxSize
			local curIdx = 0
			for fr in frames do
			(
				if curIdx == 0 do
				(
					curIdx = 1
					append sheets (atlasEntry idx:1 sprites:#() freeNodes:#(freeNode x:0 y:0 w:maxSize h:maxSize) mx:0 my:0)
				)
				local res = findBestNode sheets[curIdx] fr[4] fr[5] allowRot
				if res[1] != undefined then
					sheets[curIdx] = placeInSheet sheets[curIdx] fr[1] res[1] res[2] fr[2] fr[3] fr[4] fr[5]
				else
				(
					curIdx += 1
					append sheets (atlasEntry idx:curIdx sprites:#() freeNodes:#(freeNode x:0 y:0 w:maxSize h:maxSize) mx:0 my:0)
					local res2 = findBestNode sheets[curIdx] fr[4] fr[5] allowRot
					if res2[1] != undefined then
						sheets[curIdx] = placeInSheet sheets[curIdx] fr[1] res2[1] res2[2] fr[2] fr[3] fr[4] fr[5]
					else
					(
						deleteItem sheets sheets.count
						curIdx -= 1
						append skipped (fr[1].name + " (" + (fr[1].w as string) + "x" + (fr[1].h as string) + ")")
					)
				)
			)

			-- этап 2: минимизация ограничивающего квадрата каждого листа
			for i=1 to sheets.count do
			(
				if sheets[i].sprites.count > 0 do
					sheets[i] = repackSheet sheets[i] pad allowRot
			)

			for i=1 to sheets.count do
			(
				local a = sheets[i]
				a.w = a.mx
				a.h = a.my
				sheets[i] = a
			)

			sheets
		)

		--) Конец Алгоритма компоновки MAXRECTS
		----------------------------------------------------------------------------------


		----------------------------------------------------------------------------------
		--( Применение UV-кропов

		-- Ближайшая степень двойки (64..8192) не меньше current_res.
		fn getNitrousRes current_res =
		(
			local target_res
			for n in 6 to 13 do
			(
				target_res = (pow 2 n) as integer
				if target_res > current_res do return target_res
			)
			return target_res
		)

		-- Применяет кроп к bitmapTexture: переключает файл на атлас и выставляет
		-- clipu/clipv/clipw/cliph. Если уже был кроп — наследует его UV-поправки.
		-- Вход: tex — карта; pr — packRef (регион в атласе). Если pr.rot — W_angle +90.
		fn ApplyBitmapCrop tex pr =
		(
			local sheetWidth = pr.atlasW as float
			local sheetHeight = pr.atlasH as float
			local x = pr.x as float
			local y = pr.y as float
			local w = pr.w as float
			local h = pr.h as float
			local uOffset, vOffset, wOffset, hOffset
			if tex.apply == off then
			(
				uOffset = ((x+.5)/sheetWidth)
				vOffset = ((y+.5)/sheetHeight)
				wOffset = ((w-1)/sheetWidth)
				hOffset = ((h-1)/sheetHeight)
			)
			else
			(
				uOffset = (x/sheetWidth) + (tex.clipu * (w/sheetWidth))
				vOffset = (y/sheetHeight) + (tex.clipv * (h/sheetHeight))
				wOffset = (w/sheetWidth) * tex.clipw
				hOffset = (h/sheetHeight) * tex.cliph
			)
			tex.filename = pr.atlasFile
			tex.apply = on
			tex.clipu = uOffset
			tex.clipv = vOffset
			tex.clipw = wOffset
			tex.cliph = hOffset
			if pr.rot then tex.coords.W_angle = tex.coords.W_angle + 90
			tex.filtering = 1
		)

		-- Аналог ApplyBitmapCrop для CoronaBitmap: поля clippingU/clippingV/
		-- clippingWidth/clippingHeight, при pr.rot — wAngle +90.
		fn ApplyCoronaBitmapCrop tex pr =
		(
			local sheetWidth = pr.atlasW as float
			local sheetHeight = pr.atlasH as float
			local x = pr.x as float
			local y = pr.y as float
			local w = pr.w as float
			local h = pr.h as float
			local uOffset, vOffset, wOffset, hOffset
			if tex.clippingOn == off then
			(
				uOffset = ((x+.5)/sheetWidth)
				vOffset = ((y+.5)/sheetHeight)
				wOffset = ((w-1)/sheetWidth)
				hOffset = ((h-1)/sheetHeight)
			)
			else
			(
				uOffset = (x/sheetWidth) + (tex.clippingU * (w/sheetWidth))
				vOffset = (y/sheetHeight) + (tex.clippingV * (h/sheetHeight))
				wOffset = (w/sheetWidth) * tex.clippingWidth
				hOffset = (h/sheetHeight) * tex.clippingHeight
			)
			tex.filename = pr.atlasFile
			tex.clippingOn = on
			tex.clippingU = uOffset
			tex.clippingV = vOffset
			tex.clippingWidth = wOffset
			tex.clippingHeight = hOffset
			if pr.rot then tex.wAngle = tex.wAngle + 90
		)

		-- Аналог ApplyBitmapCrop для VrayBitmap: поля cropplace_u/cropplace_v/
		-- cropplace_width/cropplace_height, mode=1, при pr.rot — W_angle +90.
		fn ApplyVrayBitmapCrop tex pr =
		(
			local sheetWidth = pr.atlasW as float
			local sheetHeight = pr.atlasH as float
			local x = pr.x as float
			local y = pr.y as float
			local w = pr.w as float
			local h = pr.h as float
			local uOffset, vOffset, wOffset, hOffset
			if tex.cropplace_on == off then
			(
				uOffset = ((x+.5)/sheetWidth)
				vOffset = ((y+.5)/sheetHeight)
				wOffset = ((w-1)/sheetWidth)
				hOffset = ((h-1)/sheetHeight)
			)
			else
			(
				uOffset = (x/sheetWidth) + (tex.cropplace_u * (w/sheetWidth))
				vOffset = (y/sheetHeight) + (tex.cropplace_v * (h/sheetHeight))
				wOffset = (w/sheetWidth) * tex.cropplace_width
				hOffset = (h/sheetHeight) * tex.cropplace_height
			)
			tex.filename = pr.atlasFile
			tex.cropplace_on = on
			tex.cropplace_mode = 1
			tex.cropplace_u = uOffset
			tex.cropplace_v = vOffset
			tex.cropplace_width = wOffset
			tex.cropplace_height = hOffset
			if pr.rot do try( tex.coords.W_angle = tex.coords.W_angle + 90 )catch()
		)

		-- Основной цикл: собирает текстуры выделения, упаковывает их в атласы,
		-- строит файлы атласов, применяет UV-кропы и показывает отчёт.
		-- Выход: true при успехе.
		fn RunCrop =
		(
			local outDir = edtOutDir.text
			if outDir == "" or not (doesDirectoryExist outDir) then
			(
				messageBox "Select an existing output folder first." title:"Crop To Atlas"
				return false
			)
			local selObjects = getCurrentSelection()
			if selObjects.count == 0 then
			(
				messageBox "Select objects with textures first." title:"Crop To Atlas"
				return false
			)

			local baseName
			if chkAutoName.checked then baseName = getAutoBaseName selObjects
			else
			(
				baseName = edtNameBase.text
				if baseName == "" do baseName = getAutoBaseName selObjects
			)
			local atlasPrefix = baseName + "_atlas"

			local items = #()
			local seenFiles = #()
			local autoFmt = ".jpg"
			for obj in selObjects do
			(
				for tex in (GetBitmapTextures obj) do
				(
					if tex.filename != undefined and tex.filename != "" do
					(
						local full = resolveTexFile tex.filename
						if full != undefined do
						(
							if not (matchPattern (filenameFromPath full) pattern:(atlasPrefix + "*")) do
							(
								local key = toLower full
								if (findItem seenFiles key) == 0 do
								(
									local info = getTextureInfo full
									if info != undefined then
									(
										append items (sprInfo name:(filenameFromPath full) file:full w:info[1] h:info[2])
										append seenFiles key
										if autoFmt == ".jpg" and info[3] do autoFmt = ".png"
									)
									else ()
								)
							)
						)
					)
				)
			)

			if items.count == 0 then
			(
				messageBox "No textures found on selected objects." title:"Crop To Atlas"
				return false
			)

			local skipped = #()
			local fullAtlases = packTextures items spnMaxSize.value spnMaxTex.value spnPad.value chkRotate.checked skipped
			if fullAtlases.count == 0 then
			(
				messageBox "Nothing to pack." title:"Crop To Atlas"
				return false
			)

			-- пропускаем атласы с одним спрайтом: нет смысла делать атлас из одной текстуры
			local singleCount = 0
			local atlases = #()
			for a in fullAtlases do
			(
				if a.sprites.count >= 2 then append atlases a
				else singleCount += 1
			)
			if atlases.count == 0 then
			(
				messageBox "Less than 2 unique textures - no atlas needed." title:"Crop To Atlas"
				return false
			)

			local ext = getOutputExt autoFmt
			local onlyOne = atlases.count == 1
			for i=1 to atlases.count do
			(
				local a = atlases[i]
				local suffix = if onlyOne then "" else (i as string)
				a.name = baseName + "_atlas" + suffix
				a.file = outDir + "\\" + a.name + ext
				atlases[i] = a
			)

			local builtRefs = #()
			local failCount = 0
			for a in atlases do
			(
				if buildAtlas a then
				(
					for s in a.sprites do
					(
						append builtRefs (packRef file:s.tex.file atlasFile:a.file atlasW:a.w atlasH:a.h x:(s.fx+spnPad.value) y:(s.fy+spnPad.value) w:s.w h:s.h rot:s.rot)
					)
				)
				else failCount += 1
			)

			if builtRefs.count == 0 then
			(
				messageBox "Failed to build atlas images." title:"Crop To Atlas"
				return false
			)

			local appliedCount = 0
			local processedTexes = #()
			for obj in selObjects do with redraw off
			(
				for tex in (GetBitmapTextures obj) do
				(
					if tex.filename != undefined and tex.filename != "" do
					(
						if (findItem processedTexes tex) == 0 do
						(
							local full = resolveTexFile tex.filename
							if full != undefined do
							(
								local pr = undefined
								for r in builtRefs where (toLower r.file) == (toLower full) do ( pr = r; exit )
								if pr != undefined then
								(
									local cName = (classof tex) as string
									case cName of
									(
										"Bitmaptexture": ( ApplyBitmapCrop tex pr; appliedCount += 1 )
										"CoronaBitmap": ( ApplyCoronaBitmapCrop tex pr; appliedCount += 1 )
										"VrayBitmap": ( ApplyVrayBitmapCrop tex pr; appliedCount += 1 )
									)
								)
							)
							append processedTexes tex
						)
					)
				)
			)
			redrawViews()

			local maxSide = 0
			for r in builtRefs do ( maxSide = amax maxSide r.atlasW r.atlasH )
			if maxSide >= 2048 do
			(
				try ( NitrousGraphicsManager.SetTextureSizeLimit (getNitrousRes maxSide) true ) catch()
			)

			select selObjects

			local info = "Atlas files:\n"
			for a in atlases do
			(
				info += "  " + (filenameFromPath a.file) + "  " + (a.w as string) + "x" + (a.h as string) + "  (" + (a.sprites.count as string) + " sprites)\n"
			)
			info += "\nTextures mapped: " + (appliedCount as string)
			if failCount > 0 do info += "\nFailed atlases: " + (failCount as string)
			if singleCount > 0 do info += "\nSkipped single-sprite atlases: " + (singleCount as string)
			if skipped.count > 0 do
			(
				info += "\n\nSkipped (bigger than atlas):\n"
				for s in skipped do info += "  " + s + "\n"
			)
			showInfo info title:"Crop To Atlas - result"
			true
		)

		--) Конец Применения UV-кропов
		----------------------------------------------------------------------------------


		----------------------------------------------------------------------------------
		--( Обработчики событий

		on MapToAtlasRollout open do
		(
			clearlistener()

			LoadControlSettings MapToAtlasRollout "$temp/MapToAtlasRollout.ini"

			local d = getOutputDir()
			if d != "" do edtOutDir.text = d

			edtNameBase.enabled = not chkAutoName.checked
			spnQuality.enabled = (rbFormat.state != 2)
			UpdateNamePreview()

			RollPos = getIniSetting (getMaxINIFile()) "MapToAtlasSettings" "WindowPos"
			if RollPos != "" and RollPos != undefined do
			(
				if not keyboard.escPressed do SetDialogPos MapToAtlasRollout (execute RollPos)
			)
		)

		on MapToAtlasRollout close do
		(
			SaveControlSettings MapToAtlasRollout "$temp/MapToAtlasRollout.ini"

			RollPos = GetDialogPos MapToAtlasRollout
			setIniSetting (getMaxINIFile()) "MapToAtlasSettings" "WindowPos" (RollPos as string)
		)

		on btnBrowseDir pressed do
		(
			local initDir = if edtOutDir.text != "" then edtOutDir.text else maxfilepath
			BrowseForFolder edtOutDir "AtlasOutputDir" initDir:initDir
		)

		on chkAutoName changed state do
		(
			edtNameBase.enabled = not state
			UpdateNamePreview()
		)

		on rbFormat changed state do
		(
			spnQuality.enabled = (state != 2)
		)

		on btnMapList pressed do
		(
			local textinfo = ""
			objMaps = GetBitmapTextures selection
			listed = sort(for i in objMaps collect (if i.filename != undefined then filenamefrompath i.filename else ""))
			listed = makeuniquearray listed
			for map in listed do textinfo = textinfo + map + "\n"

			showInfo textinfo
		)

		on btnMap pressed do with undo "Crop To Atlas" on
		(
			max create mode
			RunCrop()
		)

		--) Конец Обработчиков событий
		----------------------------------------------------------------------------------
	)

	createDialog MapToAtlasRollout
)
