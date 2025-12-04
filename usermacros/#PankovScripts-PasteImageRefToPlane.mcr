/* @Pankovea Scripts - 2025.12.04
Paste Image Reference To Plane
Позволяет быстро Вставить изображение из буфера обмена как референс-плоскость
Копируете изображение (скриншот, план, текстуру) → запускаете скрипт → в сцене появляется плоскость с этим изображением в качестве материала.

Без Shift: плоскость в XZ (горизонтально, как план)
С зажатым Shift: плоскость в XY (вертикально, как стена), нижний край на Z = 0
* 1 пиксель = 1 миллиметр — масштаб автоматически подстраивается под ваши единицы сцены
* Отображается полное разрешение картинки. Не съедаются пиксели
* При повторном запуске обновляется существующая плоскость
Идеально для архитектурных планов, технических чертежей и быстрых референсов — без сохранения файлов вручную!

-------------------------------------------------
Paste Clipboard Image as Reference Plane
Copy any image → run the script → it appears in your scene as a textured plane.

Without Shift: plane in XZ (horizontal, like a floor plan)
With Shift pressed: plane in XY (vertical, like a wall), bottom edge at Z = 0
* 1 pixel = 1 millimeter — scale automatically adapts to your scene units
* Full image resolution is displayed. Pixels are not lost
* Re-running updates the existing plane — no duplicates
Perfect for floor plans, elevations, screenshots, and technical references — no manual file saving needed!

*/

macroScript Pankov_PasteImageRefToPlane
category:"#PankovScripts"
buttontext:"PasteRef"
tooltip:"Paste Image Reference from buffer to plane (Shift+ Vertical)"
(
-- Загружаем сборки
dotNet.loadAssembly "PresentationCore"
dotNet.loadAssembly "System.Drawing"

-- Автоматическое определение масштаба: 1 px = 1 мм в реальном мире
local mmPerUnit = case units.SystemType of (
    #inches:      25.4
    #feet:        304.8      -- 12 * 25.4
    #miles:       1609344.0  -- 5280 * 12 * 25.4	
	#millimeters: 1.0 
	#centimeters: 10.0
	#meters:      1000.0
	#kilometers:  1e6
    default:      1.0
)

local scaleFactor = 1.0 / mmPerUnit
local origWidth
local origHeight
local refPlane = undefined

fn getNitrousRes current_res = (
	-- Возвращает 
	local target_res
	for n in 6 to 13 do ( -- 2^n = 64 .. 8192
		target_res = 2^n
		if target_res > current_res do return target_res
	)
	return target_res
)

-- Функция для сохранения изображения из буфера обмена в файл с обработкой (padding to power-of-2 square)
-- Обработка: длинная сторона -> ближайшая степень 2 вверх; короткая -> pad полями (transparent) до новой длинной
fn saveClipboardImageToFile filePath = (
    local clipboard = dotNetClass "System.Windows.Clipboard"
    if clipboard.ContainsImage() then (
        local wpfBitmap = clipboard.GetImage()
        if wpfBitmap != undefined then (
            try (
                -- Конвертировать WPF Bitmap в GDI для обработки
                local encoder = dotNetObject "System.Windows.Media.Imaging.PngBitmapEncoder"
                local frame = (dotNetClass "System.Windows.Media.Imaging.BitmapFrame").Create wpfBitmap
                encoder.Frames.Add frame

                local memStream = dotNetObject "System.IO.MemoryStream"
                encoder.Save memStream

                memStream.Position = 0
                local origGdiBitmap = dotNetObject "System.Drawing.Bitmap" memStream
				
				origWidth = origGdiBitmap.Width
				origHeight = origGdiBitmap.Height				
				
				if VRayBitmap != undefined then (	
					-- VRayBitmap отображает качетсвенно сразу как есть
					origGdiBitmap.Save filePath (dotNetClass "System.Drawing.Imaging.ImageFormat").Png
				) else (
					-- для bitmapTexture необходимо изображение сделать кратным 2^n
					-- чтобы избежать некорретного масштабирования во вьюпорте
					
					-- Фикс для high-DPI: нормализовать DPI оригинала к 96 (стандарт, игнорирует screen scaling)
					origGdiBitmap.SetResolution 96 96
					
					-- Определить длинную сторону
					local longSide = amax origWidth origHeight
				
					-- Новая длинная сторона: ближайшая степень 2 >= longSide
					local newSide = getNitrousRes longSide
					
					-- Создать новый квадратный bitmap с transparent padding
					local newGdiBitmap = dotNetObject "System.Drawing.Bitmap" newSide newSide (dotNetClass "System.Drawing.Imaging.PixelFormat").Format32bppArgb  -- ARGB для совместимости, но alpha ignored для чёрного
					newGdiBitmap.SetResolution 96 96  -- Также нормализовать разрешение нового
					
					-- Graphics для рисования
					local graphics = (dotNetClass "System.Drawing.Graphics").FromImage newGdiBitmap
					graphics.Clear (dotNetClass "System.Drawing.Color").Black  -- Чёрный фон
					
					-- Рассчитать offset для центрирования оригинала
					local offsetX = (newSide - origWidth) / 2
					local offsetY = (newSide - origHeight) / 2

					-- Рисуем в центр
					graphics.DrawImage origGdiBitmap offsetX offsetY
					
					-- Сохранить новый bitmap
					newGdiBitmap.Save filePath (dotNetClass "System.Drawing.Imaging.ImageFormat").Png
					
					-- Очистка
					graphics.Dispose()
					newGdiBitmap.Dispose()
				)
				
                -- Dispose ресурсов
                origGdiBitmap.Dispose()
                memStream.Close()
                
                true
            ) catch (
                format "Ошибка сохранения: %\n" (getCurrentException())
                false
            )
        ) else ( false )
    ) else ( false )
)

fn getImageSize filePath = (
    try (
        local img = dotNetObject "System.Drawing.Bitmap" filePath
        local size = [img.Width as float, img.Height as float]
        img.Dispose()
        size
    ) catch ( [1.0, 1.0] )
)

fn deleteOldClipboardRefFiles = (
    local tempDir = getDir #temp
    local maskStr = tempDir + "\\clipboard_ref*.png"
    local filesToDelete = getFiles maskStr
    
    local deletedCount = 0
    for f in filesToDelete do (
        if deleteFile f then (
            deletedCount += 1
        ) else (
            format "Ошибка удаления: %\n" f
        )
    )
    return deletedCount > 0  -- true если что-то удалено
)

fn getXformModif obj = (
	-- Ищет моификатор Xform в объекте с именем "Xform to wall"
	-- если не находит, то возвращает undefined
	local xf
	for m in refPlane.modifiers where m.name == "Xform to wall" do (
		xf = m
		exit
	)
	return xf
)

rollout sizeDialog "Размеры"
(
    local myPlane = undefined
    local myRatio = 1.0
    local updating = false
    
    spinner spnX "X:" range:[0.001,1e6,1.0] type:#float scale:1.0 width:80 height:16 align:#left across:2 offset:[0,0]
	checkbutton chkLock "🔗" checked:true offset:[-8,8]
    spinner spnY "Y:" range:[0.001,1e6,1.0] type:#float scale:1.0 width:80 height:16 align:#left across:2 offset:[0,-8] 
    button btnOK "✅" offset:[26,-26]
    
    on sizeDialog open do (
        if refPlane != undefined then (
            myPlane = refPlane
            myRatio = if myPlane.width > 0 then myPlane.length / myPlane.width else 1.0
            spnX.value = myPlane.width
            spnY.value = myPlane.length
        ) else DestroyDialog sizeDialog
    )
    
    on spnX changed val do (
        if not updating and myPlane != undefined do (
            updating = true
            myPlane.width = val
            if chkLock.checked then (
                local newY = val * myRatio
                spnY.value = newY
                myPlane.length = newY
            )
			-- Обновляем трансформацию если вертикальная
			local xf = getXformModif myPlane
			if xf != undefined do (
				xf.gizmo.pos.z = myPlane.length / 2.0
			)
            --redrawViews()
            updating = false
        )
    )
    
    on spnY changed val do (
        if not updating and myPlane != undefined do (
            updating = true
            myPlane.length = val
            if chkLock.checked then (
                local newX = val / myRatio
                spnX.value = newX
                myPlane.width = newX
            )
			-- Обновляем трансформацию если вертикальная
			local xf = getXformModif myPlane
			if xf != undefined do (
				xf.gizmo.pos.z = myPlane.length / 2.0
			)
            --redrawViews()
            updating = false
        )
    )
    
    on chkLock changed state do (
        chkLock.caption = if state then "🔗" else "⛓️‍💥"
    )
    
    on btnOK pressed do destroyDialog sizeDialog
)

fn updateReferencePlane = (
	-- определимся с методом отрисовки
	-- для лучшего отображения лучше использовать VrayBitmap
	bitmapMethod = case of (
		(VRayBitmap != undefined): #VRay
		default: #default
	)
	
	local tempImagePath
	if bitmapMethod == #VRay then (
		-- генерируем новое имя файла для того чтобы не использовать кэш с прошлого изображения
		deleteOldClipboardRefFiles()
		
		dt = getLocalTime()
		dt_str = ""; for i in 1 to 7 do (
			if i == 4 then dt_str += "_"
			else dt_str += dt[i] as string -- format YMDhms
		)
		tempImagePath = (getDir #temp) + "\\clipboard_ref_" + dt_str + ".png"
	) else (
		-- bitmapTexture не кэширует текстуры можно просто перезаписывать текущий файл
		tempImagePath = (getDir #temp) + "\\clipboard_ref.png"
	)

    if saveClipboardImageToFile tempImagePath then (
        local w = origWidth * scaleFactor   -- ширина (X)
        local l = origHeight * scaleFactor  -- высота изображения → длина плоскости (Y)
		
		local longSide = amax origWidth origHeight
		
		local nitrousRes = getNitrousRes longSide
		if longSide >= 2048 and NitrousGraphicsManager.IsEnabled() do ( -- настраиваем отображение
			NitrousGraphicsManager.SetTextureSizeLimit nitrousRes true
		)
		
        refPlane = getNodeByName "ClipboardRefPlane"
        if refPlane == undefined then (
            -- Создаём плоскость
            refPlane = plane name:"ClipboardRefPlane" width:w length:l widthsegs:1 lengthsegs:1
            local mat = standard name:"RefMat"
            refPlane.material = mat
        ) else (
            -- Обновляем размеры
            refPlane.width = w
            refPlane.length = l
        )

		local xf = getXformModif myPlane
        if keyboard.ShiftPressed then (
			if (classof xf) != xform then (
				xf = xform name:"Xform to wall"
				addmodifier refPlane xf
			)
			xf.gizmo.transform = matrix3 [1,0,0] [0,0,1] [0,-1,0] [0, 0, refPlane.length / 2.0]
		) else (
			if (classof xf) == xform then
				deletemodifier refPlane xf
        )

        -- Назначаем текстуру
        local map
		local uv = refPlane.modifiers[refPlane.modifiers.count]
		case bitmapMethod of ( -- для лучшего отображения лучше использовать Corona или Vray bitmap
			#VRay: (
				map = VRayBitmap name:"ClipboardTex" filename:tempImagePath viewport_useFullResolution:true
				if (classof uv) == UVWMap then
					deletemodifier refPlane refPlane.modifiers.count
			)
			default: (
				map = bitmapTexture name:"ClipboardTex" fileName:tempImagePath
				if (classof uv) != UVWMap then (
					uv = UVWMap()
					addmodifier refPlane uv before:refPlane.modifiers.count
				)
				uv.width = nitrousRes
				uv.length = nitrousRes
				/*
				-- почему-то вызывает ошибку Unknown property: "gizmo" in Uvwmap:UVW Map
				-- коррекция на нечётность размера изображения и значит выравнивание по центру смещено
				local uoffset = if (origWidth / 2) != (origWidth / 2.0) then scaleFactor else 0
				local voffset = if (origHeight / 2) != (origHeight / 2.0) then scaleFactor else 0
				refPlane.modifiers[1].gizmo.position = [uoffset, voffset, 0]
				*/
			)
		)
        refPlane.material.diffuseMap = map
		refPlane.material.showInViewport = true
        --redrawViews()
		
		local oldsel = selection as array
		select refPlane
		refPlane.scale = [3,3,3]
		actionMan.executeAction 0 "310"  -- Tools: Zoom Extents Selected
		select oldsel
		refPlane.scale = [1,1,1]
		
		-- Показываем модальное окно для редактирования размеров
        createDialog sizeDialog modal:true
    ) else (
        messagebox "❌ Нет изображения в буфере."
    )
)

on execute do (
	updateReferencePlane()
)
)