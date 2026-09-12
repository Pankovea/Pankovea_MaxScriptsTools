-- #PankovScripts-ExtractMissingFromArchive.ru.ms
-- Русский словарь для макроса ExtractMapsFromArchive.
-- Формат: каждый ключ-значение — отдельный #( "k", "v" ) аргумент конструктора Dictionary.
-- Возвращает Dictionary (обязательное последнее выражение файла).

Dictionary #(
	"extractRollout", "Извлечение потерянных ассетов из архивов") #(
	"extractRollout.group:Options", "Параметры") #(
	"extractRollout.group:Missing assets", "Искомые ассеты") #(
	"extractRollout.group:About", "О программе") #(
	"extractRollout.lblSource", "Архив или папка для поиска:") #(
	"extractRollout.btnBrowseFile", "Файл") #(
	"extractRollout.btnBrowseFolder", "Папка") #(
	"extractRollout.lblDest", "Папка для извлечения:") #(
	"extractRollout.chkRecursive", "Искать в подпапках") #(
	"extractRollout.chkOnlyMissing", "Только потерянные файлы") #(
	"extractRollout.chkOnlyMissing.tooltip", "Включено: только потерянные файлы. Выключено: все ассеты сцены.") #(
	"extractRollout.chkRelink", "Переназначить найденные файлы в сцене") #(
	"extractRollout.chkRelinkInPlace", "Переназначать на месте") #(
	"extractRollout.chkRelinkInPlace.tooltip", "Включено: найденные файлы не копируются в папку назначения, а переназначаются на месте (архивы всегда извлекаются).") #(
	"extractRollout.chkKeepPath", "Размещать в исходное имя папки/архива") #(
	"extractRollout.chkKeepPath.tooltip", "Включено: сохраняется имя папки/архива, где лежала текстура (только родитель, не весь путь).\nВыключено: всё в корень папки назначения.") #(
	"extractRollout.btnRescan", "Обновить список") #(
	"extractRollout.btnTakeSelected", "Взять из выделенного") #(
	"extractRollout.btnSelScene", "Выделить в сцене") #(
	"extractRollout.btnLoadMat", "Загрузить в матэдитор") #(
	"extractRollout.btnExclude", "Исключить из поиска") #(
	"extractRollout.btnRun", "НАЙТИ → ИЗВЛЕЧЬ → ПЕРЕНАЗНАЧИТЬ") #(
	"msgBtnRunNo7z", "НАЙТИ → ПЕРЕНАЗНАЧИТЬ") #(
	"extractRollout.btnCancel", "Отмена") #(
	"extractRollout.lblLog", "Лог:") #(
	"msgErrNoSource", "Укажите существующий архив или папку!") #(
	"msgErrNoDest", "Укажите папку назначения!") #(
	"msgErrEmptyList", "Список потерянных файлов пуст.") #(
	"msgErrEmptyListAll", "Список ассетов пуст.") #(
	"msgWarnNo7zip", "7-Zip не найден. Ожидается в: {0}\nАрхивы будут пропущены.\nСкачать: {1}") #(
	"extractRollout.btnDeleteSelected", "Удалить выделенные объекты с текстурой") #(
	"extractRollout.btnDeleteSelected.tooltip", "Удалить выделенные объекты и их текстуры из сцены и с диска. Отмена (Undo) восстанавливает объекты (файлы с диска не восстанавливаются).") #(
	"msgDelConfirmHeader", "Удалить {0} объектов и их текстуры?") #(
	"msgDelItems", "Удалить") #(
	"msgDelObjCount", "Объектов удалено: {0}") #(
	"msgDelMatCleared", "Очищено неиспользуемых слотов мультиматериала: {0} (в {1} материалах)") #(
	"msgDelUndoName", "Удалить выделенные объекты с их текстурами") #(
	"msgDelDone", "Удалено: {0} объектов, {1} текстур с диска.") #(
	"msgInfoSelectObj", "Выделите объекты в сцене.") #(
	"msgInfoNoMatMissing", "В материалах выделенных объектов потерянных файлов не найдено.") #(
	"msgInfoNoMatAll", "В материалах выделенных объектов ассетов не найдено.") #(
	"msgInfoSelectFiles", "Сначала выделите файлы в списке.") #(
	"msgSelObjects", "Выделено объектов: {0}") #(
	"msgNoObjects", "Объекты с этими файлами не найдены.") #(
	"msgLoadedMat", "Загружено: {0}\nСлот 1 — карта\nСлот 2 — материал") #(
	"msgNoMats", "Материалы с этими файлами не найдены.") #(
	"msgResultNone", "Ничего не найдено.") #(
	"msgResultSuccess", "Переназначено из папки: {0}\nИзвлечено из архивов: {1}\nПереназначено в сцене: {2}\nОсталось потерянных: {3}\n\nСохраните сцену!") #(
	"msgResultNoRelink", "Извлечено: {0}\n(переназначение не выполнялось)") #(
	"msgCanceled", "Отменено пользователем.") #(
	"stSearchMissing", "Поиск потерянных файлов...") #(
	"stSearchAll", "Поиск ассетов...") #(
	"stMissing", "Потерянных: {0}") #(
	"stAssets", "Ассетов: {0}") #(
	"stScanFolders", "Сканирование папок...") #(
	"stScanFolder", "Сканирование папки: {0}") #(
	"stRelinkFolder", "Переназначение из папки...") #(
	"stCheck", "Проверка: {0} ({1}/{2})") #(
	"stExtract", "Извлечение: {0} ({1} файлов)") #(
	"stRelinkArchives", "Переназначение из архивов...") #(
	"stCanceled", "Отменено") #(
	"stPreparing", "Подготовка...") #(
	"stReady", "Готов!") #(
	"stTaken", "Взято из выделенного: {0}") #(
	"stExcluded", "Исключено файлов: {0}") #(
	"lblCountFormat", "Потерянных файлов: {0}") #(
	"lblCountAll", "Все файлы: {0}") #(
	"logFound",          "Потерянных ассетов найдено: {0}") #(
	"logAllFound",       "Ассетов найдено: {0}") #(
	"logTakenFound",     "Взято из выделенного: найдено потерянных ассетов {0}") #(
	"logTakenFoundAll",  "Взято из выделенного: найдено ассетов {0}") #(
	"logFolderFiles",    "Файлов в папке: {0}") #(
	"logArchivesFound",  "Найдено архивов: {0}") #(
	"logInArchive",      "В архиве {0} найдено файлов: {1}") #(
	"logMissingFiles",   "Потерянных файлов: {0}") #(
	"logAssets",         "Ассетов: {0}") #(
	"logLeftMissing",    "Осталось потерянных после переназначения: {0}") #(
	"logLeftMissingAll", "Не переназначено после операции: {0}") #(
	"logStatsHeader",    "=== СТАТИСТИКА ===") #(
	"logStatTotal",      "Потерянных всего\t: {0}") #(
	"logStatTotalAll",   "Ассетов всего\t: {0}") #(
	"logStatFolder",     "Переназначено из папки\t: {0}") #(
	"logStatArchives",   "Извлечено из архивов\t: {0}") #(
	"logStatScene",      "Переназначено в сцене\t: {0}") #(
	"logStatNotFound",   "Не найдено\t: {0}") #(
	"logFoldersHeader",  "Папки, где найдены файлы:") #(
	"logArchivesHeader", "Архивы, где найдены файлы:") #(
	"logItem",           "  - {0} ({1} файлов)") #(
	"titleInfo",    "Информация") #(
	"titleError",   "Ошибка") #(
	"titleResult",  "Результат") #(
	"titleDone",    "Готово") #(
	"titleSuccess", "Успех"
)
