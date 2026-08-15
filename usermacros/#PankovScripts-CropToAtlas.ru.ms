-- ##PankovScripts-CropToAtlas.ru.ms
-- Russian dictionary: MAXScript Dictionary with string keys, flat pairs:
--   "rollout name"                 -> rollout title
--   "<rollout>.<control>"          -> control caption
--   "<rollout>.<control>.tooltip"  -> tooltip
--   "<rollout>.group:<EN caption>" -> group caption
--   message id                     -> dynamic message text
--

Dictionary #(
	"MapToAtlasRollout", "Создание атласа текстур") #(
	"MapToAtlasRollout.edtOutDir", "Сохранить в:") #(
	"MapToAtlasRollout.btnBrowseDir", "Выбрать...") #(
    "MapToAtlasRollout.edtNameBase", "Базовое имя:") #(
    "MapToAtlasRollout.chkAutoName", "Из названия группы") #(
    "MapToAtlasRollout.spnMaxSize", "Макс. размер атласа:") #(
    "MapToAtlasRollout.chkRotate", "Поворот 90°") #(
    "MapToAtlasRollout.spnMaxTex", "Макс. размер текстуры:") #(
    "MapToAtlasRollout.spnPad", "Отсутп:") #(
    "MapToAtlasRollout.spnPad.tooltip", "Отступ вокруг каждой текстуры, заполняется цветом края текстуры") #(
    "MapToAtlasRollout.rbFormat", "Формат:") #(
    "MapToAtlasRollout.lbl1", "JPG качество") #(
    "MapToAtlasRollout.btnMapList", "Инфо о картах") #(
    "MapToAtlasRollout.btnMapList.tooltip", "Какие карты содержатся в выделенных обхектах") #(
    "MapToAtlasRollout.btnMap", "Сформировать атлас") #(
    "MapToAtlasRollout.btnMap.tooltip", "Сформировать атлас из текстур на выделенных объектах") #(

    "AtlasMapsInfo.btnCopy", "Копировать") #(
    "AtlasMapsInfo.btnOK", "Ok") #(
    "AtlasMapsInfo.group:About", "О программе:") #(
	-- Messages
	"locateFolder", "Укажите выходную папку: {0}") #(
	"selOutputFolder", "Для начала укажите выходную папку") #(
    "selObjects", "Для начала выберите объекты, содержащие материалы с текстурой.") #(
    "noTexturesFound", "На выделеных объекта не найдено текстур") #(
    "nothingToPack", "Нечего паковать") #(
    "ltTwoTextures", "Менне 2 уникальных текстур - атлас не нужен") #(
    "failedBuildAtlas", "Не удачное формарование атласа")
