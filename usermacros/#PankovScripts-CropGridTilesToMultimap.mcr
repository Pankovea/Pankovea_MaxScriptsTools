/* @Pankovea Scripts - 2025.04.22

Этот скрипт предназначен для создания Corona MultiMap (CMM) из одного
изображения путем обрезки сетки плиток.
Инструмент позволяет пользователю указать количество столбцов и строк
для макета сетки, а затем генерирует серию CoronaBitmap с настроеной обрезкой,
которые объединяются в одну Corona MultiMap.

--

This script is designed to create a Corona MultiMap from one image
by cropping tile grids. The tool allows the user to specify
the number of columns and rows for the grid layout,
then generates a series of cropped CoronaBitmap
that are combined into one Corona MultiMap.
*/

macroscript Pankovea_CropGridTilesToCoronaMultiMap
    category:"#PankovScripts"
    tooltip:"CoronaMultiMap from single image by cropping grid tiles"
    buttonText:"GridTile to CMM"
(

struct CMM_Settings (
    cols = 3,
	rows = 4,
    ini = cfgMgr.getIniFile(),
	sec = "Pankovea_CMM",

    fn load = (
        if getIniSetting ini sec "cols" != "" do (
            cols = (getIniSetting ini sec "cols") as integer
            rows = (getIniSetting ini sec "rows") as integer
            local p = getIniSetting ini sec "window_pos"
            if p != "" do (
				try window_pos = (execute p) catch ()
            )
        )
    ),

    fn save = (
        setIniSetting ini sec "cols" (cols as string)
        setIniSetting ini sec "rows" (rows as string)
    )
)

local cfg = CMM_Settings()
cfg.load()

fn createCoronaMultiMapFromImage sourceImagePath cols:3 rows:4 = (
    if not doesFileExist sourceImagePath do return messagebox "Файл не найден!"
    try CoronaMultiMap() catch (
		return messagebox "Corona не загружена или не установлена!"
	)

	local cmm = CoronaMultiMap()
    cmm.name = "MultiMap_Crop_" + cols as string + "x" + rows as string
    cmm.items = cols * rows
	cmm.randomizeMeshElement = true

    local cropW = 1.0 / cols
    local cropH = 1.0 / rows

    for r = 1 to rows do (
        for c = 1 to cols do (
            local idx = (r - 1) * cols + c
            
            local cb = CoronaBitmap()
            cb.name = "Tile_" + idx as string
            cb.filename = sourceImagePath
            
            -- Включаем обрезку и задаём границы тайла
            cb.clippingOn = true
            cb.clippingU = (c - 1) * cropW
            cb.clippingV = 1.0 - (r * cropH) -- V=0 внизу, поэтому считаем от верха
            cb.clippingWidth = cropW
            cb.clippingHeight = cropH

            cmm.texmaps[idx] = cb
        )
    )
    return cmm
)

-- 1. Сразу открываем проводник для выбора файла
	local srcFile = getOpenFileName caption:"Выберите исходное изображение" \
		types:"Изображения (*.jpg;*.png;*.tga;*.exr;*.tif)|*.jpg;*.png;*.tga;*.exr;*.tif|Все файлы (*.*)|*.*|"
		
	if srcFile == undefined then return false -- Нажали Отмена в проводнике
	
-- 2. Модальное окно с настройкой сетки
	rollout rTileSettings "Настройка сетки" width:220 (
		label lbl1 "Num of Tiles"
		spinner spnX "X:" type:#integer range:[1,64,3] across:2
		label lbl2 ""
		spinner spnY "Y:" type:#integer range:[1,64,4] across:2
		button btnOK "✅" width:50 height:42 offset:[0,-26]
		
		on rTileSettings open do (
			spnX.value = cfg.cols
			spnY.value = cfg.rows
		)
		
		on btnOK pressed do (
			-- 3. Генерация и установка в Material Editor
			local cmm = createCoronaMultiMapFromImage srcFile cols:spnX.value rows:spnY.value
			if cmm != undefined then (
				meditMaterials[activeMeditSlot] = cmm
				destroyDialog rTileSettings
				messagebox ("Готово! CoronaMultiMap создан в слоте #" + activeMeditSlot as string) title:"Успех"
			) else (
				destroyDialog rTileSettings
			)
		)
			
        on rTileSettings keyUp code do (
			if code == #esc do destroyDialog rTileSettings
		)
		
		on rTileSettings close do (
			cfg.cols = spnX.value
			cfg.rows = spnY.value
			cfg.save()
		)
	)
	local pos = mouse.screenPos
	pos[1] -= 150
	pos[2] -= 72
	createDialog rTileSettings modal:true pos:pos
)