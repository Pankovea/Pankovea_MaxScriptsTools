#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; БЛОК АВТОЗАГРУЗКИ (выполняется один раз при первом запуске)
; ============================================================
if !A_IsCompiled
{
    startupDir := A_Startup . "\"
    scriptPath := A_ScriptFullPath
    shortcutPath := startupDir . "SaveClipboardImageToActiveFolder.lnk"

    if !FileExist(shortcutPath)
    {
        answer := MsgBox(
            "Скрипт для быстрой вставки картинки из буфера обмена`n" .
            "в текущую папку по сочетанию Win + V`n`n" .
            "Добавить скрипт в автозагрузку, чтобы он запускался`n" .
            "при старте Windows?`n`n" .
            "Да – добавить и запустить`nНет – не добавлять и запустить`nОтмена – не запускать скрипт",
            "Автозагрузка", "YesNoCancel Icon?"
        )
        if answer = "Yes"
        {
            try {
                shell := ComObject("WScript.Shell")
                shortcut := shell.CreateShortcut(shortcutPath)
                shortcut.TargetPath := A_AhkPath
                shortcut.Arguments := '"' . scriptPath . '"'
                shortcut.WorkingDirectory := A_ScriptDir
                shortcut.Save()
                MsgBox("Скрипт добавлен в автозагрузку.`n`n" .
                       "Для удаления из автозагрузки нажмите Ctrl+Win+Delete`n(при работающем скрипте).`n`n" .
                       "Или просто удалить ярлык из:`n" .
                       startupDir, "Готово", "Iconi")
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

; ------------------------------------------------------------
; Горячая клавиша для удаления скрипта из автозагрузки и выхода
; Ctrl + Win + Delete
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
    startupLink := A_Startup . "\SaveClipboardToActiveFolder.lnk"
    if FileExist(startupLink)
    {
        try {
            FileDelete startupLink
            Tooltip "Ярлык автозагрузки удалён."
            SetTimer () => Tooltip(), 2000
        } catch {
            MsgBox "Не удалось удалить ярлык. Проверьте права доступа.", "Ошибка", 48
            return
        }
    }
    else
    {
        Tooltip "Ярлык автозагрузки не найден."
        SetTimer () => Tooltip(), 2000
    }
    
    ; Завершаем работу скрипта
    Sleep 500
    ExitApp
}

; Горячая клавиша: Win + V
#v::
{
    TargetFolder := ""

    ; 1. Пробуем найти путь через Shell.Application (работает и для Проводника, и для многих диалогов)
    TargetFolder := GetPathFromShell()

    ; 2. Если не нашли, пробуем эвристику по контролам (резервный вариант)
    if (TargetFolder = "") {
        TargetFolder := GetPathFromDialogControls()
    }

    if (TargetFolder = "") {
        Tooltip "Не удалось определить папку."
        SetTimer () => Tooltip(), 3000
        return
    }

    ; 3. Проверяем буфер обмена
    if !DllCall("IsClipboardFormatAvailable", "UInt", 2) {
        Tooltip "В буфере нет изображения!"
        SetTimer () => Tooltip(), 2000
        return
    }

    ; 4. Генерируем имя файла
    FileName := "Image_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . ".png"
    FullPath := TargetFolder . "\" . FileName

    ; 5. Сохраняем через PowerShell
    try {
        SafePath := StrReplace(FullPath, "'", "''")
        
        PsCmd := "Add-Type -AssemblyName System.Windows.Forms; "
        PsCmd .= "$img = [System.Windows.Forms.Clipboard]::GetImage(); "
        PsCmd .= "if ($img) { "
        PsCmd .= "$img.Save('" . SafePath . "', [System.Drawing.Imaging.ImageFormat]::Png); "
        PsCmd .= "$img.Dispose(); "
        PsCmd .= "}"

        RunWait('powershell -NoProfile -WindowStyle Hidden -Command "' . PsCmd . '"',, "Hide")
        
        Sleep 400
        
        ; Обновляем вид
        SendInput "{F5}"
        
        Tooltip "Сохранено: " . FileName
        SetTimer () => Tooltip(), 2000
        
    } catch as err {
        MsgBox "Ошибка: " . err.Message
    }
}

; --- Функция 1: Поиск пути через Shell.Application (Наиболее надежно) ---
GetPathFromShell() {
    try {
        shell := ComObject("Shell.Application")
        for window in shell.Windows {
            ; Проверяем, активно ли это окно сейчас
            ; WinExist возвращает HWND, сравниваем с HWND окна Shell
            if (WinActive("ahk_id " . window.HWND)) {
                try {
                    ; Пытаемся получить путь
                    path := window.Document.Folder.Self.Path
                    if (path != "") {
                        return path
                    }
                }
            }
        }
    }
    return ""
}

; --- Функция 2: Резервный поиск по контролам ---
GetPathFromDialogControls() {
    ; Получаем список всех контролов активного окна
    ; WinGetControls возвращает массив строк ClassNN
    Controls := WinGetControls("A")
    
    for ctrlClassNN in Controls {
        ; ctrlClassNN - это строка, например "ToolbarWindow323" или "Edit1"
        
        ; Нас интересуют Edit (поля ввода) и иногда ComboBox
        if (ctrlClassNN ~= "i)^Edit") {
            try {
                Text := ControlGetText(ctrlClassNN, "A")
                ; Проверяем, похож ли текст на абсолютный путь (начинается с буквы диска и :\ )
                if (Text ~= "^[a-zA-Z]:\\") {
                    return Text
                }
            }
        }
        
        ; ToolbarWindow обычно содержит адресную строку, но getText от нее часто пустой.
        ; Однако в некоторых старых приложениях там может быть текст.
        if (ctrlClassNN ~= "i)^ToolbarWindow") {
             ; Попробуем, но шанс мал
             try {
                 Text := ControlGetText(ctrlClassNN, "A")
                 if (Text ~= "^[a-zA-Z]:\\") {
                     return Text
                 }
             }
        }
    }
    return ""
}