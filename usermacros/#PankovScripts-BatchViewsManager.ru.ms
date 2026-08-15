-- #PankovScripts-BatchViewsManager.ru.ms
-- Russian dictionary: MAXScript Dictionary with string keys, flat pairs:
--   "rollout name"                 -> rollout title
--   "<rollout>.<control>"          -> control caption
--   "<rollout>.<control>.tooltip"  -> tooltip
--   "<rollout>.group:<EN caption>" -> group caption
--   message id                     -> dynamic message text
--

Dictionary #(
    "deleteGroupQuery", "Удалить \"{0}\"?") #(
    "delGroupAll", "Группу + виды") #(
    "delGroupOnly", "Только группу") #(
    "delGroupCancel", "Отмена") #(
    "delViewOk", "Удалить") #(
    "delViewCancel", "Отмена") #(
    "roll_Cams", "Камеры") #(
    "roll_Cams.btn_refresh", "🔄️ Обновить") #(
    "roll_Cams.btn_refresh.tooltip", "Обновить список камер сцены") #(
    "roll_Cams.chk_only_visible", "Только видимые") #(
    "roll_Cams.chk_only_visible.tooltip", "Показывать только видимые камеры.\nВыкл — показать все камеры сцены.") #(
    "roll_Cams.btn_cams_info", "?") #(
    "roll_Cams.btn_cams_info.tooltip", "Один клик — просмотр параметров камеры и разрешения в UI (сцена не меняется).\nДвойной клик — активировать камеру и загрузить её разрешение в сцену.") #(
    "roll_Cams.btn_pick_pathrev_cam", "<<") #(
    "roll_Cams.btn_pick_pathrev_cam.tooltip", "Предыдущая камера") #(
    "roll_Cams.btn_s", "Выделить") #(
    "roll_Cams.btn_s.tooltip", "Выделить активную камеру") #(
    "roll_Cams.btn_next_cam", ">>") #(
    "roll_Cams.btn_next_cam.tooltip", "Следующая камера") #(
    "roll_Cams.group:Parameters", "Параметры") #(
    "roll_Cams.lbl_fl", "Фокусное расстояние") #(
    "roll_Cams.spn_fl", "мм") #(
    "roll_Cams.chk_fov", "Использовать FOV") #(
    "roll_Cams.spn_fov", "FOV") #(
    "roll_Cams.chk_dof", "Включить DOF") #(
    "roll_Cams.spn_f", "f-") #(
    "roll_Cams.chk_tilt", "Перспектива: авто-наклон вертикали") #(
    "roll_Cams.lbl_ex", "Экспозиция:") #(
    "roll_Cams.drp_ev", "Выдержка") #(
    "roll_Cams.spn_ev", "EV") #(
    "roll_Cams.spn_sh", "Выдержка") #(
    "roll_Cams.spn_iso", "ISO") #(
    "roll_Cams.group:Rename", "Переименовать") #(
    "roll_Cams.txt_rename_cam.tooltip", "Переименовать камеру и обновить имена batch views") #(
    "roll_Cams.lbl_rename_warn", "⚠ Имя уже используется") #(
    "roll_Cams.btn_create_view", "➕ Создать Batch View") #(
    "roll_Cams.btn_create_view.tooltip", "Создать batch view для активной камеры\nи перейти на вкладку Batch Views") #(
    "roll_Cams.btn_for_all_cams", "Для всех камер") #(
    "roll_Cams.btn_for_all_cams.tooltip", "Создать batch views для всех камер,\nу которых ещё нет вида") #(
    "roll_batch", "Batch Views") #(
    "roll_batch.btn_open_batch", "Batch Views") #(
    "roll_batch.btn_refresh", "🔄️ Обновить") #(
    "roll_batch.btn_refresh.tooltip", "Обновить список видов") #(
    "roll_batch.btn_views_info", "?") #(
    "roll_batch.btn_views_info.tooltip", "Список Batch Views.\n\n— Один клик — просмотр параметров вида в UI (сцена не меняется).\n— Повторный клик по выбранному пункту — применить вид к сцене: камера + разрешение + состояние сцены.\n— Двойной клик по виду — вкл/выкл (вид) / свернуть-развернуть группу.\n— Ctrl/Shift — мультивыбор.\n— Кнопки слева: обновить список, добавить, дублировать, удалить, вверх/вниз, вкл/выкл.") #(
    "roll_batch.btn_togleEnabled.tooltip", "Вкл/выкл") #(
    "roll_batch.btn_togleEnabledAll.tooltip", "Вкл/выкл все") #(
    "roll_batch.btn_up.tooltip", "Вверх (вид/группа)") #(
    "roll_batch.btn_add_sep.tooltip", "Добавить группу\nГруппы можно переименовать в поле «Имя вида»") #(
    "roll_batch.btn_down.tooltip", "Вниз (вид/группа)") #(
    "roll_batch.btn_dup.tooltip", "Дублировать вид") #(
	"roll_batch.btn_prev_view.tooltip", "Активировать предыдущий вид") #(
	"roll_batch.btn_select_cam", "Выделить") #(
	"roll_batch.btn_select_cam.tooltip", "Выделить камеру текущего вида") #(
	"roll_batch.btn_next_view.tooltip", "Активировать следующий вид") #(
    "roll_batch.btn_net_render", "🕸️ Net") #(
    "roll_batch.btn_render", "🫖 Рендер") #(
    "roll_batch.txt_view_name", "Имя вида") #(
    "roll_batch.btn_open_in_explorer", "Открыть") #(
    "roll_batch.btn_open_in_explorer.tooltip", "Открыть папку в проводнике") #(
    "roll_batch.txt_view_path", "Путь вывода") #(
    "roll_batch.txt_view_file", "Имя файла") #(
    "roll_batch.btn_pick_path", "...") #(
    "roll_batch.btn_pick_path.tooltip", "Использовать диалог сохранения файла") #(
    "roll_batch.drdwn_cam", "Камера") #(
    "roll_batch.btn_use_active_cam", "🎥") #(
    "roll_batch.btn_use_active_cam.tooltip", "Использовать активную камеру") #(
    "roll_batch.drdwn_state", "Состояние сцены") #(
    "roll_batch.drdwn_render_preset", "Пресет рендера") #(
    "roll_batch.group:Resolution", "Разрешение") #(
    "roll_batch.chk_override_preset", "Переопределить пресет") #(
    "roll_batch.chk_override_preset.tooltip", "Вкл — вид использует СВОЁ разрешение и кадры.\nВыкл — вид использует выбранный Render Preset.") #(
    "roll_batch.chk_edit_base", "Базовый размер") #(
    "roll_batch.chk_edit_base.tooltip", "Выкл — редактируется ТЕКУЩИЙ (масштабированный) размер.\nВкл — редактируется БАЗОВЫЙ (100%) размер.\nДоступно только когда глобальный масштаб ≠ 100%.") #(
    "roll_batch.txt_out_w", "Ширина") #(
    "roll_batch.txt_out_ratio", "Пропорции") #(
    "roll_batch.txt_out_h", "Высота") #(
    "roll_batch.chk_ratio", "🔗") #(
    "roll_batch.btn_swap", "↕") #(
    "roll_batch.btn_swap.tooltip", "Поменять местами ширину и высоту\nи инвертировать пропорции") #(
    "roll_batch.chk_snap", "Кратно 16(8) пикс") #(
    "roll_batch.chk_snap.tooltip", "Снап разрешения к стандартным значениям.\n1. Стандартный список разрешений (большой допуск по МП, пропорции сохраняются).\n2. Кратные сетке (W:32, H:16) + стандартные пропорции.\nВыкл — значения используются как есть.") #(
    "roll_batch.chk_preserve_mp", "Сохранять МегаПикс") #(
    "roll_batch.chk_preserve_mp.tooltip", "При изменении пропорций сохранять суммарные мегапиксели,\nпересчитывая обе стороны.\nСнап к ближайшему стандартному разрешению.") #(
    "roll_batch.chk_sync_views", "Синхронизация по камере") #(
    "roll_batch.chk_sync_views.tooltip", "Вкл — обновить все batch views этой камеры.\n'Base size' ВКЛ — синхронизирует БАЗОВЫЙ размер.\n'Base size' ВЫКЛ — синхронизирует ТЕКУЩИЙ (масштабированный) размер.") #(
    "roll_batch.spn_start_frame", "Старт") #(
    "roll_batch.spn_end_frame", "Конец") #(
    "roll_batch.btn_copy_res", "Копировать разрешение на все виды") #(
    "roll_batch.btn_copy_res.tooltip", "Копирует разрешение текщего вида во все batch views.\n\n'Preserve MegaPix' ВЫКЛ — копируется WxH как есть,\nменяется местами для портретных/альбомных видов.\n'Preserve MegaPix' ВКЛ — сохраняются суммарные\мегапиксели, обе стороны пересчитываются\nпод пропорции каждого вида.") #(
    "roll_batch.btn_copy_res_mp", "Перенести МегаПикс на все виды") #(
    "roll_global", "Batch Views глобально") #(
    "roll_global.group:Sizes", "Размеры") #(
    "roll_global.btn_apply_res", "Применить") #(
    "roll_global.btn_apply_res.tooltip", "Задать текущее масштабированное разрешение как новую базу\nдля ВСЕХ batch views и сбросить масштаб на 100%") #(
    "roll_global.group:Output paths", "Пути вывода") #(
    "roll_global.btn_set_folder", "Задать папку вывода для всех видов") #(
    "roll_global.chk_update_re", "Обновить и пути Render Elements") #(
    "roll_global.chk_update_re.tooltip", "При смене папки вывода\nтакже обновить все пути вывода Render Elements") #(
    "roll_global.btn_update_re", "Обновить пути Render Elements") #(
    "roll_global.btn_update_re.tooltip", "Обновить пути вывода Render Elements\nпо основной папке вывода рендера") #(
    "roll_lang", "Язык / инфо") #(
    "roll_lang.group:Language", "Язык") #(
    "roll_lang.drp_lang.tooltip", "Переключить язык интерфейса") #(
    "roll_lang.group:About", "О программе") #(
    "roll_states", "Состояния сцены") #(
    "roll_states.btn_states_info", "?") #(
    "roll_states.btn_states_info.tooltip", "Состояния сцены. Один клик — выбрать.\nДвойной клик — применить.") #(
    "roll_states.txt_states_new", "Имя состояния") #(
    "roll_states.txt_states_new.tooltip", "Enter — переименовать выбранное состояние.\nНовое — когда состояние не выбрано.") #(
    "roll_states.btn_states_new", "➕ Создать") #(
    "roll_states.btn_states_new.tooltip", "Создать состояние из выбранного,\nдобавив порядковый номер.\nНовое состояние выбирается для редактирования.") #(
    "roll_states.btn_states_update", "Обновить") #(
    "roll_states.btn_states_update.tooltip", "Перезаписать выбранное состояние\nтекущей сценой") #(
    "roll_states.group:Parts to capture", "Сохраняемые части") #(
    "roll_states.btn_parts_info", "?") #(
    "roll_states.btn_parts_info.tooltip", "Сохраняемые части. Ctrl+click — переключить.\nОдин клик по состоянию выше загружает его части.") #(
    "roll_states.btn_parts_none", "Очистить") #(
    "appTitle", "Менеджер Batch Views") #(
    "titleCameras", "Камеры") #(
    "titleError", "Ошибка") #(
    "titleCameraBase", "База камеры") #(
    "titleBatchViews", "Batch Views") #(
    "titleApplyState", "Применить состояние сцены") #(
    "titleManageStates", "Управление состояниями сцены") #(
    "titleNewState", "Новое состояние сцены") #(
    "titleUpdateState", "Обновить состояние сцены") #(
    "titleRenameState", "Переименовать состояние сцены") #(
    "titleDeleteState", "Удалить состояние сцены") #(
    "camerasInfo", "Один клик — просмотр параметров камеры и разрешения в UI (сцена не меняется).\nДвойной клик — активировать камеру и загрузить её разрешение в сцену.") #(
    "selectCameraFirst", "Сначала выберите камеру") #(
    "createdBatchViews", "Создано batch views: {0}") #(
    "viewExists", "Такой вид уже существует.\nИзмените имя и попробуйте снова.") #(
    "dirNotExist", "Каталог не существует") #(
    "applyAsBase", "Применить {0}x{1} как базовое для этого вида?") #(
    "batchViewsInfoMsg", "Список Batch Views.\n\n— Один клик — просмотр параметров вида в UI (сцена не меняется).\n— Повторный клик по выбранному пункту — применить вид к сцене: камера + разрешение + состояние сцены.\n— Двойной клик по виду — вкл/выкл (вид) / свернуть-развернуть группу.\n— Ctrl/Shift — мультивыбор: вкл/выкл и вверх/вниз действуют на все выбранные\n  и на все виды внутри выбранных групп.\n— Кнопки слева: обновить список, добавить, дублировать, удалить, вверх/вниз,\n  вкл/выкл (выбранное) и вкл/выкл всё.") #(
    "deleteView", "Удалить вид(ы)?") #(
    "selectStateToApply", "Выберите состояние сцены для применения.") #(
    "cantRestoreState", "Не удалось восстановить состояние сцены:\n{0}") #(
    "statesInfo", "Менеджер состояний сцены.\n\nПрименить — восстановить выбранное состояние сцены.\nОбновить — перезаписать выбранное состояние текущей сценой.\nНовое — создать состояние из выбранного,\nдобавив порядковый номер.\nУдалить — удалить выбранное состояние.\n\nПоле «Имя состояния»: одиночный клик по состоянию\nзагружает его имя — отредактируйте и нажмите Enter\nдля переименования.\n\n«Сохраняемые части» — выберите части (свет/камера/\nобъект/слой/материал/окружение...)\nс помощью Ctrl+клик при создании или перезаписи\nсостояния. Одиночный клик по состоянию загружает его части.") #(
    "enterNewStateName", "Введите имя нового состояния.") #(
    "stateExists", "Состояние с таким именем уже существует.") #(
    "selectPartToCapture", "Выберите хотя бы одну часть для сохранения.") #(
    "cantCreateState", "Не удалось создать состояние сцены (ошибка захвата).") #(
    "cantCreateStateEx", "Не удалось создать состояние сцены:\n{0}") #(
    "selectStateToOverwrite", "Выберите состояние сцены для перезаписи.") #(
    "overwriteState", "Перезаписать \"{0}\" текущей сценой?") #(
    "cantUpdateState", "Не удалось обновить состояние сцены (ошибка захвата).") #(
    "cantUpdateStateEx", "Не удалось обновить состояние сцены:\n{0}") #(
    "enterNewName", "Введите новое имя.") #(
    "cantRenameState", "Не удалось переименовать состояние сцены:\n{0}") #(
    "selectStateToDelete", "Выберите состояние сцены для удаления.") #(
    "copyResConfirm", "Скопировать разрешение текущего вида во ВСЕ виды?\nОтменить это действие нельзя.\n\nСледующие виды изменят свои ПРОПОРЦИИ:\n{0}") #(
    "setFolderConfirm", "Задать папку вывода для ВСЕХ видов?\nОтменить это действие нельзя.\n\nТекущие папки вывода:\n{0}") #(
    "deleteStateQuery", "Удалить состояние сцены \"{0}\"?") #(
    "cantDeleteState", "Не удалось удалить состояние сцены:\n{0}") #(
    "deleteEmptyGroup", "Удалить пустую группу \"{0}\"?") #(
    "groupWord", "Группа") #(
    "scaleText", "Масштаб: {0}%") #(
    "selectOutputFolder", "Выберите папку вывода") #(
    "selectReFolder", "Выберите папку для Render Elements") #(
    "version", "Версия"
)
