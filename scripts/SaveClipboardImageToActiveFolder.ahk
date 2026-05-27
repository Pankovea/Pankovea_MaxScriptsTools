#Requires AutoHotkey v2.0
#SingleInstance Force

; ------------------- НАСТРОЙКИ --------------------

; Имя файла. Найдите строку:
; FileName := "Image_" . FormatTime(A_Now, "yyyyMMdd_HHmmss")
; Можно комбинировать через точку следующее:
;  - В кавычках любой текст
;  - Формат даты подробнее тут https://www.autohotkey.com/docs/v2/lib/FormatTime.htm
;  - A_ComputerName - ммя компьютера
;  - A_UserName - имя пользователя системы

; Выберите формат для сохранения изображения
global OutputFileExt := "png"   ; впишите любое перечисленного ниже
global validFormats := Map(
    "png", "Png",
    "jpg", "Jpeg",
    "jpeg", "Jpeg",
    "gif", "Gif",
    "bmp", "Bmp",
    "tif", "Tiff",
    "tiff", "Tiff"
)

; Имя ярлыка автозагрузки
global startupLinkPath := A_Startup . "\SaveClipboardImageToActiveFolder.lnk"

; Горячая клавиша: Win + V
; Сочетание клавиш: замените #v:: на нужную
;    Символы: # = Win, ^ = Ctrl, ! = Alt, + = Shift
;    Примеры: ^!s:: (Ctrl+Alt+S), #+v:: (Win+Shift+V)
;    Двойное двоеточие :: обязательно оставить.
#v::

; ------------------------------------------------------------
{
    TargetFolder := ""

    ; 1. Пробуем найти путь
    winProcess := WinGetProcessName("A")
    if (winProcess = "explorer.exe")
        TargetFolder := GetActiveFolderPath()
    else
        TargetFolder := GetPathFromDialogControls()


    if (TargetFolder = "") {
        Tooltip "Не удалось определить папку."
        SetTimer () => Tooltip(), -3000
        return
    }

    ; 3. Проверяем буфер обмена
    if !DllCall("IsClipboardFormatAvailable", "UInt", 2) {
        Tooltip "В буфере нет изображения!"
        SetTimer () => Tooltip(), -2000
        return
    }

    ; 4. Генерируем имя файла
    ext := StrLower(OutputFileExt)
    if !validFormats.has(ext)
        ext := "png"
    FileName := "Image_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . "." . ext
    FullPath := TargetFolder . "\" . FileName

    ; 5. Сохраняем через PowerShell
    SafePath := StrReplace(FullPath, "'", "''")
    PsCmd := "Add-Type -AssemblyName System.Windows.Forms; "
    PsCmd .= "$img = [System.Windows.Forms.Clipboard]::GetImage(); "
    PsCmd .= "if ($img) { "
    PsCmd .= "$img.Save('" . SafePath . "', [System.Drawing.Imaging.ImageFormat]::" . validFormats[ext] . "); "        
    PsCmd .= "$img.Dispose(); "
    PsCmd .= "}"

    try {
        RunWait('powershell -NoProfile -WindowStyle Hidden -Command "' . PsCmd . '"',, "Hide")

        Sleep 400

        ; Обновляем вид
        SendInput "{F5}"

        Tooltip "Сохранено: " . FileName
        SetTimer () => Tooltip(), -2000

    } catch as err {
        MsgBox "Ошибка: " . err.Message
    }
}

; --- Функция 1: Поиск пути через Explorer ---
GetActiveExplorerTab(hwnd := WinExist("A")) {
    activeTab := 0
    try activeTab := ControlGetHwnd("ShellTabWindowClass1", hwnd) ; Windows 11
    catch
        try activeTab := ControlGetHwnd("TabWindowClass1", hwnd)   ; Internet Explorer

    for w in ComObject("Shell.Application").Windows {
        if w.hwnd != hwnd
            continue
        if activeTab {
            static IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"
            shellBrowser := ComObjQuery(w, IID_IShellBrowser, IID_IShellBrowser)
            ComCall(3, shellBrowser, "uint*", &thisTab := 0)
            if thisTab != activeTab
                continue
        }
        return w
    }
    return 0
}

; Функция для получения пути из активной вкладки
GetActiveFolderPath() {
    tab := GetActiveExplorerTab()
    if tab
        return tab.Document.Folder.Self.Path
    else
        return ""
}

; --- Функция 2: Поиск в окне открытия файла ---
GetPathFromDialogControls() {
    text := ControlGetText("ToolbarWindow323", "A")
    text := Trim(text)
    ; Проверяем, похож ли текст на абсолютный путь (начинается с буквы диска и :\ )
    if RegExMatch(text, "([a-zA-Z]:\\.+)", &match)
        return RTrim(RegExReplace(match[1], "[\x00-\x1F\x7F]"), "\")

    ; Резервный вариант. Пытаемся найти что-то похожее на путь
    ; Получаем список всех контролов активного окна
    ; WinGetControls возвращает массив строк ClassNN
    ; ctrlClassNN - это строка, например "ToolbarWindow323" или "Edit1"

    Controls := WinGetControls("A")
    for ctrlClassNN in Controls {
        try {
            text := ControlGetText(ctrlClassNN, "A")
            text := Trim(text)
            if RegExMatch(text, "([a-zA-Z]:\\.+)", &match)
                return RTrim(RegExReplace(match[1], "[\x00-\x1F\x7F]"), "\")
        }
    }

    return ""
}

; ------------------------------------------------------------
; Горячая клавиша Ctrl + Win + Delete
; для удаления скрипта из автозагрузки и выхода
; ------------------------------------------------------------
^#Delete::
{
    ; Запрашиваем подтверждение
    answer := MsgBox(
        "Вы действительно хотите удалить SaveClipboardImageToActiveFolder`n" .
        "из автозагрузки и завершить его работу?",
        "Удаление из автозагрузки",
        "OKCancel Icon?"
    )
    
    if answer = "Cancel"
        return
    
    ; Удаляем ярлык из автозагрузки
    UninstallAndStop()
}


; ------------------------------------------------------------
; УСТАНОВКА И УДАЛЕНИЕ
; ------------------------------------------------------------

; Определяем, запущен ли скрипт из автозагрузки (по аргументу)
isAutoStartup := false
for arg in A_Args {
    if arg = "/fromStartup" {
        isAutoStartup := true
        break
    }
}

; Функция: удалить ярлык из автозагрузки
; Возвращает: false если ярлыка не было или ошибка
UninstallAndStop() {
    if FileExist(startupLinkPath) {
        try {
            FileDelete startupLinkPath
            Tooltip "Ярлык автозагрузки удалён."
            SetTimer () => Tooltip(), -2000

            ; Завершаем работу скрипта
            Sleep 500
            ExitApp
        } catch {
            MsgBox "Не удалось удалить ярлык. Проверьте права доступа.", "Ошибка", 16
            return false
        }
    }
    Tooltip "Ярлык автозагрузки не найден."
    SetTimer () => Tooltip(), -2000
}


; ------------------------------------------------------------
; УСТАНОВКА (УДАЛЕНИЕ) в АВТОЗАГРУЗКУ
; При ручном запуске
; ------------------------------------------------------------
if !isAutoStartup
{
    startupDir := A_Startup . "\"
    scriptPath := A_ScriptFullPath

    if FileExist(startupLinkPath) {
        answer := MsgBox(
            "Скрипт уже добавлен в автозагрузку.`n`nУдалить его оттуда?",
            "Автозагрузка", 4 + 32
        )
        if answer = "Yes"
            UninstallAndStop()

    } else if !A_IsCompiled {
        answer := MsgBox(
            "Скрипт для быстрой вставки картинки из буфера обмена`n" .
            "в текущую папку по сочетанию Win + V`n`n" .
            "Добавить скрипт в автозагрузку, чтобы он`n" .
            "запускался при старте Windows?`n" .
            "(Удалнеие повторным запуском скрипта)`n`n" .
            "Да – добавить и запустить`nНет – не добавлять и запустить`nОтмена – не запускать скрипт",
            "Автозагрузка", "YesNoCancel Icon?"
        )
        if answer = "Yes"
        {
            try {
                shell := ComObject("WScript.Shell")
                shortcut := shell.CreateShortcut(startupLinkPath)
                shortcut.TargetPath := A_AhkPath
                shortcut.Arguments := '"' . scriptPath . '" /fromStartup'
                shortcut.WorkingDirectory := A_ScriptDir
                shortcut.Save()
                MsgBox("Скрипт добавлен в автозагрузку:`n" . startupDir .
                       "`n`nДля удаления из автозагрузки и завершения приложения`n" .
                       "нажмите Ctrl+Win+Delete`n(при работающем скрипте).`n`n" .
                       "Или просто запустите скрипт повторно.", "Готово", "Iconi")
            } catch {
                MsgBox("Не удалось создать ярлык. Проверьте права на запись в папку автозагрузки.`n" .
                startupDir, "Ошибка", "Iconx")
            }
        }
        else if answer = "Cancel"
        {
            ; Пользователь отказался от запуска – завершаем скрипт
            ExitApp
        }
        ; Если answer = "No" – ничего не делаем, просто продолжаем работу скрипта
    }
}
