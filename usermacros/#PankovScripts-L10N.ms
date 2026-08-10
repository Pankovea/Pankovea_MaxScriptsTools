-- #PankovScripts-L10N.ms
-- Universal lightweight i18n engine for #PankovScripts-* tools.
-- Contains NO translation data. Dictionaries:
--   - the English dictionary (only strings missing from the script
--     source: runtime messages and dialog titles) is embedded into
--     the embedding script and registered via L10N.registerDict "en" <dict>;
--   - every other language dictionary is a separate file
--     "<scriptBase>.<code>.ms" next to the embedding script, e.g.
--     ...usermacros/#PankovScripts-BatchViewsManager.ru.ms
--
-- ==========================================================================
-- HOW TO INTEGRATE  (put this at the very top of your script body)
-- ==========================================================================
--     global L10N
--     -- L10N is a global shared across tools and Max sessions, so it can be
--     -- stale (an older engine without the current API). Reload it when the
--     -- engine version is missing or too old:
--     local l10n_stale = (L10N == undefined)
--     if not l10n_stale do (
--         try ( if L10N.engineVer < 2 then l10n_stale = true ) catch ( l10n_stale = true )
--     )
--     if l10n_stale do (
--         L10N = fileIn ((getFilenamePath (getThisScriptFilename())) + "#PankovScripts-L10N.ms")
--         L10N.dictBase = (getFilenamePath (getThisScriptFilename())) + "#PankovScripts-<YourScriptBase>"
--         L10N.discoverDicts()
--         -- English dictionary: ONLY runtime strings missing from the source
--         -- (dynamic messages, dialog titles). It is embedded INLINE here:
--         L10N.registerDict "en" ( Dictionary #(
--             "appTitle", "My Tool",
--             "confirmDelete", "Delete {0}?"
--         ) )
--     )
--
--     -- activate the saved language BEFORE building the UI
--     -- (e.g. L10N.setLang <code-read-from-ini>; default is "en"):
--     L10N.setLang "ru"
--
--     -- after addRollout <roll>, localize it. Switching back to "en"
--     -- restores the original (English) captions automatically:
--     L10N.applyRollout roll
--
--     -- translate runtime messages; {0}/{1} are placeholders:
--     messageBox (L10N.trMsg "confirmDelete" args:#(objName))
--
--     -- language dropdown in the UI:
--     for code in L10N.codes do append drp_lang.items (L10N.langLabel code)
--
--     -- live language switch WITHOUT recreating the window:
--     --   on drp_lang selected idx do (
--     --       local code = L10N.codes[idx]
--     --       if code == L10N.lang do return false
--     --       setINISetting (getmaxinifile()) "Sec" "Lang" code
--     --       L10N.setLang code
--     --       for r in #(rollA, rollB) do L10N.applyRollout r
--     --   )
--     -- NOTE: rollout handlers only see functions/variables that existed
--     -- BEFORE the rollout definition. Do NOT call showUI()/recreate the
--     -- window from a handler if that function is defined after the rollout.
--
-- ==========================================================================
-- TRANSLATION FILE RULES
-- ==========================================================================
-- * One file per language: "<scriptBase>.<code>.ms" (e.g. ...BatchViewsManager.ru.ms)
--   placed in the SAME folder as dictBase (next to the embedding script).
-- * The file must return a MAXScript Dictionary with STRING keys:
--
--     Dictionary #(
--         "appTitle", "Мой инструмент"
--     ) #(
--         "confirmDelete", "Удалить {0}?"
--     ) #(
--         "roll_about.group:About", "О программе"
--     )
--
--   Every pair is a SEPARATE #( "k", "v" ) argument (variadic constructor).
--   Do NOT nest pairs -- Dictionary #( #("k","v"), ... ) is INVALID and
--   fails with 'Type error: First arg for Dictionary ctor invalid'.
-- * Keys:
--     "rollout name"                 -> rollout title
--     "<rollout>.<control>"          -> control caption (button/checkbox/label/...)
--     "<rollout>.<control>.tooltip"  -> control tooltip
--     "<rollout>.group:<EN caption>" -> group caption (key uses the EN caption)
--     "message id"                   -> dynamic message / dialog title text
-- * Duplicate keys in one Dictionary are an error -- keep keys unique.
-- * Text: use \n for line breaks, \" for quotes, keep {0}/{1} placeholders
--   identical to the English text.
-- * Languages are auto-discovered from the files (L10N.codes). "en" is always
--   present even if no file exists (its dictionary is registered inline).
--
-- ==========================================================================
-- METHOD REFERENCE
-- ==========================================================================
--   L10N.codes        #("en", "ru", ...)  all available language codes
--   L10N.langLabel c  human-readable language name (English, Русский, ...)
--   L10N.setLang code       activate a language (loads "<base>.<code>.ms")
--   L10N.trMsg key args:    translate a message id; fallback: ru -> en -> key
--   L10N.applyRollout roll  localize a rollout in place: title, group
--                           captions, control captions and tooltips.
--                           Two-way: on the first localization the English
--                           baseline is captured; switching back to "en"
--                           restores it, so English is never lost
--   L10N.registerDict code arr   register an in-memory dictionary
--   L10N.discoverDicts     scan dictBase + ".*.ms" for language files
--   L10N.engineVer         engine schema version (embedding scripts use it
--                          to detect and reload a stale global L10N)
-- ------------------------------------------------------------------

struct L10N (
    -- Currently active language code, e.g. #("en", "ru").
    lang = "en",
    -- Engine schema version. Embedding scripts compare it to decide whether
    -- a stale global L10N (from an older engine in the same Max session)
    -- must be reloaded, because L10N is a global shared across tools.
    engineVer = 2,
    -- Full path prefix to the language dictionaries, e.g.
    -- "...usermacros/#PankovScripts-BatchViewsManager" (NO .ms extension).
    dictBase = "",
    -- The in-memory English dictionary (registered via registerDict, or
    -- lazily loaded from dictBase + ".en.ms" if it exists).
    dict_en = undefined,
    -- The dictionary of the currently active language (undefined for "en"
    -- until the embedded EN dictionary is registered).
    dict = undefined,
    -- Registered dictionaries as #(code, dict) pairs.
    registered = #(),
    -- All available language codes (discovered + "en").
    codes = #("en"),
    -- #(code, label) pairs for language dropdowns.
    langLabels = #(#("en", "English")),
    -- Baseline (original English) captions of each localized rollout.
    -- Entry: #(roll, origTitle, #(#(origCaption, origTooltip), ...)) where
    -- the inner array is index-aligned with roll.controls. Captured on the
    -- first localization and restored when switching back to "en".
    origState = #(),

    -- Internal: pretty label for a language code.
    --   known labels: en -> English, ru -> Русский; anything else -> the code.
    fn langLabelFor code = (
        local known = #(#("en", "English"), #("ru", "Русский"))
        local res = code
        for p in known where p[1] == code do res = p[2]
        res
    ),

    -- Internal: baseline entry for a rollout, or undefined.
    fn findOrig roll = (
        for entry in origState where entry[1] == roll do return entry
        undefined
    ),

    -- Internal: capture the current (English) captions of a rollout.
    -- Called automatically on the first localization; no-op afterwards.
    fn captureOrig roll = (
        local entry = findOrig roll
        if entry != undefined then return entry
        local caps = #()
        for c in roll.controls do (
            local cap = undefined
            local tip = undefined
            try ( cap = c.caption ) catch ()
            try ( tip = c.tooltip ) catch ()
            append caps #(cap, tip)
        )
        local title = undefined
        try ( title = roll.title ) catch ()
        entry = #(roll, title, caps)
        append origState entry
        entry
    ),

    -- Internal: restore the baseline captions of a rollout (English).
    fn restoreOrig roll entry = (
        if entry == undefined then return false
        try ( roll.title = entry[2] ) catch ()
        local caps = entry[3]
        for i in 1 to roll.controls.count do (
            if i > caps.count do exit
            try ( roll.controls[i].caption = caps[i][1] ) catch ()
            try ( roll.controls[i].tooltip = caps[i][2] ) catch ()
        )
        true
    ),

    -- Scan dictBase + ".*.ms" and collect language codes from filenames.
    -- Rebuilds L10N.codes and L10N.langLabels (always includes "en").
    fn discoverDicts = (
        codes = #()
        langLabels = #()
        local pattern = dictBase + ".*.ms"
        for f in (getFiles pattern) do (
            local base = getFilenameFile f
            local dot = 0
            for i in base.count to 1 by -1 do (
                if base[i] == "." do ( dot = i; exit )
            )
            local code = undefined
            if dot > 0 and dot < base.count then code = substring base (dot + 1) (base.count - dot)
            if code != undefined and code != "" and findItem codes code == 0 then (
                append codes code
                append langLabels #(code, langLabelFor code)
            )
        )
        if findItem codes "en" == 0 then (
            append codes "en"
            append langLabels #("en", "English")
        )
        sort codes
        local tmp = #()
        for c in codes do for p in langLabels where p[1] == c do append tmp p
        langLabels = tmp
        true
    ),

    -- Register an in-memory dictionary for a language code.
    --   code: "en", "ru", ...
    --   arr:  a Dictionary with string keys (see TRANSLATION FILE RULES).
    -- Overwrites a previously registered dictionary with the same code.
    fn registerDict code arr = (
        if arr == undefined then return false
        local idx = 0
        for i in 1 to registered.count do if registered[i][1] == code do ( idx = i; exit )
        if idx == 0 then append registered #(code, arr) else registered[idx][2] = arr
        if code == "en" then dict_en = arr
        true
    ),

    -- Internal: value from a dictionary by key; undefined when missing.
    fn getText d key = (
        if d == undefined then return undefined
        try ( d[key] ) catch ( undefined )
    ),

    -- Activate a language and load its dictionary.
    --   code: must be in L10N.codes; unknown codes fall back to "en".
    -- For "en": uses the embedded/registered EN dictionary (or loads
    -- dictBase + ".en.ms" if present). For other codes: fileIn of
    -- dictBase + "." + code + ".ms" (must return a Dictionary).
    fn setLang code = (
        if dictBase == "" and registered.count == 0 then return false
        if code == undefined or code == "" or findItem codes code == 0 then code = "en"
        lang = code
        local reg = undefined
        for p in registered where p[1] == code do ( reg = p[2]; exit )
        if reg != undefined then (
            dict = reg
        ) else (
            if code == "en" then (
                if dict_en == undefined do (
                    try ( dict_en = fileIn (dictBase + ".en.ms") ) catch ( dict_en = undefined )
                )
                dict = dict_en
            ) else (
                try ( dict = fileIn (dictBase + "." + code + ".ms") ) catch ( dict = undefined )
            )
        )
        true
    ),

    -- Translate a message id.
    --   key:  string message id ("confirmDelete", "appTitle", ...).
    --   args: optional #(v0, v1, ...) substituted into {0}, {1}, ...
    -- Fallback chain: active dictionary -> English dictionary -> the key itself.
    fn trMsg key args: = (
        local txt = getText dict key
        if txt == undefined do txt = getText dict_en key
        if txt == undefined do txt = key
        if args == unsupplied then args = #()
        else if (classOf args) == String then args = #(args)
        if args.count > 0 then (
            for i in 1 to args.count do (
                txt = substituteString txt ("{" + ((i - 1) as string) + "}") (args[i] as string)
            )
        )
        txt
    ),

    -- Localize a rollout in place. Works in BOTH directions:
    --   lang != "en": first captures the current (English) captions as the
    --                   baseline, then applies the active dictionary.
    --   lang == "en": restores the baseline captured earlier, so the
    --                   English text is never lost. No-op if the rollout
    --                   was never localized.
    --   roll: a rollout instance/definition.
    -- Updates: rollout title, GroupStartControl captions, control captions
    -- and tooltips. Keys: "<roll>" for the title, "<roll>.group:<EN caption>"
    -- for groups, "<roll>.<control>" / "<roll>.<control>.tooltip" for controls.
    -- Missing keys are skipped silently; property writes are wrapped in try.
    fn applyRollout roll = (
        if roll == undefined then return false
        if lang == "en" then (
            restoreOrig roll (findOrig roll)
            return true
        )
        captureOrig roll
        local t = getText dict roll.name
        if t != undefined do ( try ( roll.title = t ) catch () )
        for c in roll.controls do (
            local cls = (classOf c) as string
            if cls == "GroupEndControl" then continue
            if cls == "GroupStartControl" then (
                local gt = getText dict (roll.name + ".group:" + c.caption)
                if gt != undefined do ( try ( c.caption = gt ) catch () )
                continue
            )
            local cap = getText dict (roll.name + "." + c.name)
            if cap != undefined do ( try ( c.caption = cap ) catch () )
            local tip = getText dict (roll.name + "." + c.name + ".tooltip")
            if tip != undefined do ( try ( c.tooltip = tip ) catch () )
        )
        true
    ),

    -- Human-readable label for a language code (for dropdowns).
    --   L10N.langLabel "ru" -> "Русский"
    fn langLabel code = (
        for p in langLabels where p[1] == code do return p[2]
        code
    )
)

L10N()
