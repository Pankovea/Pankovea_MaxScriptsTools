/*
#PankovScripts-L10N.ms
Universal lightweight i18n engine for Maxscript tools.
Contains NO translation data. Dictionaries:
  - the English dictionary (only strings missing from the script
    source: runtime messages and dialog titles) is embedded into
    the embedding script and passed to the constructor via enDict:
    (registered automatically at init);
  - every other language dictionary is a separate file
    "<scriptBaseName>.<code>.ms" next to the embedding script, e.g.
    ...usermacros/#PankovScripts-BatchViewsManager.ru.ms

==========================================================================
HOW TO INTEGRATE  (put this at the very top of your script body)
==========================================================================
	local iniFile = "$temp/MapToAtlasRollout.ini"
	local iniSection = getFilenameFile (getThisScriptFilename())
	local myRollout
    
	-- i18n: general wrapper #PankovScripts-L10N.ms (protection against missing file)
	local L10N_VER = 1 -- Expected engine API version
	local L10N
	local thisScriptPath = getThisScriptFilename()
	local scriptBaseName = getFilenamePath thisScriptPath + getFilenameFile thisScriptPath
	local l10n_engine = getFilenamePath thisScriptPath + "#PankovScripts-L10N.ms"
	local l10n_en = Dictionary #(
        "appTitle", "My App Title") #(
		-- Messages
		"msgErrNoSource", "Specify an existing archive or folder!") #(
		"msgInfoSelectObj", "Select objects in the scene.") #(
		"msgCanceled", "Canceled by user.") #(
		-- Message titles
		"titleInfo", "Info") #(
		"titleError", "Error") #(
		"titleResult", "Result") #(
		"titleDone", "Done") #(
		"titleSuccess", "Success")

	-- Fallback (English only) for a missing or broken engine file.
	local L10N_Fallback = struct _L10N_Fallback (
		scriptBaseName,
		enDict = Dictionary #string,
		engineVer = L10N_VER,
		codes = #(),
		fn trMsg key args: = (
			local r = enDict[key]
			if args != unsupplied and args.count > 0 then
				for i = 1 to args.count do r = substituteString r ("{" + ((i - 1) as string) + "}") (args[i] as string)
			r
		),
		fn setLang code = true,
		fn applyRollout roll = true,
		fn applyRollouts arrOfRoll = true,
		fn langLabel code = code,
		fn registerDict code dict = true
	)
	-- Load the engine; on failure fall back to English (version check is inside).
	local L10N_struct = L10N_Fallback
	try (
		if doesFileExist l10n_engine then L10N_struct = fileIn l10n_engine
		L10N = L10N_struct scriptBaseName:scriptBaseName enDict:l10n_en engineVer:L10N_VER
	) catch (
		format ">>> L10N: %\n" (getCurrentException())
		L10N = L10N_Fallback scriptBaseName:scriptBaseName enDict:l10n_en
	)
	-- load ini setting
	L10N.setLang (getINISetting iniFile iniSection "Lang")
	-------------------------------------------------------------------------

	rollout myRollout "My Rollout" width:500 height:710 (
		-- Your control elements are here.
		group "About" (
			dropdownlist drpLang items:#() width:120 align:#center visible:false
			hyperLink hlnkLangEngine "Download language Engine" align:#center offset:[0,-33] \
				address:"https://github.com/Pankovea/Pankovea_MaxScriptsTools/tree/main/usermacros/#PankovScripts-L10N.ms"
			hyperLink hlnkLangRU "Download Russian Translate" align:#center offset:[0,-7] \
				address:("https://github.com/Pankovea/Pankovea_MaxScriptsTools/tree/main/usermacros/" + (getFilenameFile (getThisScriptFilename())) + ".ru.ms")
		)

        -- live language switch WITHOUT recreating the window:
        local arrOfRollouts = #(myRollout, ...)
        on drpLang selected idx do (
            if classof L10N == _L10N_Fallback then return false
            L10N.setLang L10N.codes[idx]
            L10N.applyRollouts arrOfRollouts
            setINISetting iniFile iniSection "Lang" L10N.lang
        )

        -- Interface language: show the choice only if there are other languages.
        on rollout open do (
            if L10N.codes.count > 1 then (
                drpLang.visible = true
                hlnkLangEngine.visible = false
                hlnkLangRU.visible = false
                drpLang.items = for c in L10N.codes collect (L10N.langLabel c)
                local cur = findItem L10N.codes L10N.lang
                if cur > 0 then drpLang.selection = cur
                if L10N.lang != "en" do L10N.applyRollout myRollout
            ) else (
                drpLang.visible = false
                hlnkLangRU.visible = true
                hlnkLangEngine.visible = (classof L10N) == _L10N_Fallback
            )
        )
	)


==========================================================================
TRANSLATION FILE RULES
==========================================================================
* One file per language: "<scriptBase>.<code>.ms" (e.g. ...BatchViewsManager.ru.ms)
  placed in the SAME folder as scriptBaseName (next to the embedding script).
* The file must return a MAXScript Dictionary with STRING keys:
	Dictionary #(
	"appTitle", "Мой инструмент") #(
	"confirmDelete", "Удалить {0}?") #(
	"roll_about.group:About", "О программе")

  Every pair is a SEPARATE #("k", "v") argument (variadic constructor).
  Do NOT nest pairs -- Dictionary #( #("k","v"), ... ) is INVALID and
  fails with 'Type error: First arg for Dictionary ctor invalid'.
* Keys:
    "rolloutName"                  -> rollout title
    "<rollout>.<control>"          -> control caption (button/checkbox/label/...)
    "<rollout>.<control>.tooltip"  -> control tooltip
    "<rollout>.group:<EN caption>" -> group caption (key uses the EN caption)
    "messageID"                    -> dynamic message / dialog title text
* Duplicate keys in one Dictionary are an error -- keep keys unique.
* Text: use \n for line breaks, \" for quotes, keep {0}/{1} placeholders
  identical to the English text.
* Languages are auto-discovered from the files (L10N.codes). "en" is always
  present even if no file exists (its dictionary is registered inline).

==========================================================================
METHOD REFERENCE
==========================================================================
  L10N.codes        #("en", "ru", ...)  all available language codes
  L10N.langLabel c  human-readable language name (English, Русский, ...)
  L10N instance construction:
  L10N_struct scriptBaseName:<base> enDict:<enDict> engineVer:<expected>
                          sets the dictionary base; during _auto_init registers
                          the embedded English dictionary (enDict:, optional),
                          checks the expected API version against the internal
                          _engineVer (reports and throws on mismatch), discovers
                          languages and activates "en".
  L10N.setLang code       activate a language (lazily loads "<base>.<code>.ms";
                          a file is parsed only on its first use and cached
                          afterwards, so dictionaries that are not immediately
                          needed are never loaded)
  L10N.trMsg key args:    translate a message id; fallback: ru -> en -> key
  L10N.applyRollout roll  localize a rollout in place: title, group
                          captions, control captions and tooltips.
                          Two-way: on the first localization the English
                          baseline is captured; switching back to "en"
                          restores it, so English is never lost
  L10N.registerDict code dict   register an in-memory dictionary
  L10N.discoverDicts     scan scriptBaseName + ".*.ms" for language files
  L10N.engineVer         expected API version, passed at construction
                         (engineVer:) and checked against the internal
                         _engineVer during _auto_init (see HOW TO INTEGRATE)
--------------------------------------------------------------------
*/

struct L10N (
    -- Currently active language code, e.g. #("en", "ru").
    lang = "en",
    -- Expected API version, passed by the module at construction (engineVer:).
    -- Compared against the internal _engineVer during _auto_init; on a
    -- mismatch the engine reports it and refuses to start (module falls back).
    engineVer = 1,
    -- Internal: actual engine schema version. Bumped whenever the L10N
    -- public API changes; modules must pass a matching engineVer: at
    -- construction.
    _engineVer = 1,
    -- Full path prefix to the language dictionaries (NO .ms extension)
	scriptBaseName = "",
    -- The English dictionary: passed at construction via enDict:, registered
    -- automatically during _auto_init if non-empty, or lazily loaded from
    -- scriptBaseName + ".en.ms" if present.
    enDict = Dictionary #string,
    -- The dictionary of the currently active language (undefined for "en"
    -- until the embedded EN dictionary is registered).
    dict = undefined,
    -- Registered dictionaries as #(code, dict) pairs.
    registered = #(),
    -- Lazy-loaded file dictionaries as #(code, dict) pairs. A language
    -- dictionary is parsed from disk only on its first use (see loadDict)
    -- and cached here, so each "<scriptBase>.<code>.ms" file is fileIn'd
    -- at most once per Max session. Dictionaries that are not immediately
    -- needed are never loaded at all.
    loaded = #(),
    -- All available language codes (discovered + "en").
    codes = #("en"),
    -- #(code, label) pairs for language dropdowns.
    langLabels = #(#("en", "English")),
    -- Baseline (original English) captions of each localized rollout.
    -- Entry: #(roll, origTitle, #(#(origCaption, origTooltip), ...)) where
    -- the inner array is index-aligned with roll.controls. Captured on the
    -- first localization and restored when switching back to "en".
    origState = #(),

    fn langLabelFor code = (
        -- Internal: pretty label for a language code.
        --   known labels: en -> English, ru -> Русский; anything else -> the code.
        local known = #(#("en", "English"), #("ru", "Русский"))
        local res = code
        for p in known where p[1] == code do res = p[2]
        res
    ),

    fn findOrig roll = (
        -- Internal: baseline entry for a rollout, or undefined.
        for entry in origState where entry[1] == roll do return entry
        undefined
    ),

    fn captureOrig roll = (
        -- Internal: capture the current (English) captions of a rollout.
        -- Called automatically on the first localization; no-op afterwards.
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

    fn restoreOrig roll entry = (
        -- Internal: restore the baseline captions of a rollout (English).
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

    fn discoverDicts = (
        -- Scan scriptBaseName + ".*.ms" and collect language codes from filenames.
        -- Rebuilds L10N.codes and L10N.langLabels (always includes "en").
        codes = #()
        langLabels = #()
        local pattern = scriptBaseName + ".*.ms"
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

    fn registerDict code dict = (
        -- Register an in-memory dictionary for a language code.
        --   code: "en", "ru", ...
        --   dict:  a Dictionary with string keys (see TRANSLATION FILE RULES).
        -- Overwrites a previously registered dictionary with the same code.
        if dict == undefined then return false
        local idx = 0
        for i in 1 to registered.count do if registered[i][1] == code do ( idx = i; exit )
        if idx == 0 then append registered #(code, dict) else registered[idx][2] = dict
        if code == "en" then enDict = dict
        -- An explicit registration supersedes any lazily cached file dictionary.
        for i in loaded.count to 1 by -1 do if loaded[i][1] == code do ( deleteItem loaded i; exit )
        true
    ),

    fn getText d key = (
        -- Internal: value from a dictionary by key; undefined when missing.
        if d == undefined then return undefined
        try ( d[key] ) catch ( undefined )
    ),

    fn loadDict code = (
        -- Internal: return the dictionary for a code, loading it lazily.
        --   registered in-memory dictionaries are returned as-is;
        --   file dictionaries (scriptBaseName + "." + code + ".ms") are fileIn'd
        --     on first use and cached (en -> enDict, the rest -> loaded),
        --     so each file is parsed at most once per Max session and
        --     dictionaries that are not immediately needed are never loaded.
        -- A missing dictionary file returns undefined; errors INSIDE an
        -- existing dictionary file are NOT suppressed and surface to the
        -- caller (Listener), so a broken <script>.<code>.ms is never hidden.
        for p in registered where p[1] == code do return p[2]
        for p in loaded where p[1] == code do return p[2]
        local df = scriptBaseName + "." + code + ".ms"
        if not (doesFileExist df) then return undefined
        local d = fileIn df
        if code == "en" then enDict = d else append loaded #(code, d)
        d
    ),

    fn setLang code = (
        -- Activate a language (lazily loading its dictionary).
        --   code: must be in L10N.codes; unknown codes fall back to "en".
        -- For "en": uses the embedded/registered EN dictionary (or lazily
        -- loads scriptBaseName + ".en.ms" if present). For other codes: fileIn of
        -- scriptBaseName + "." + code + ".ms" (must return a Dictionary) on the
        -- first use; subsequent switches reuse the cached dictionary.
        -- A MISSING dictionary file is silently ignored (falls back to "en").
        if scriptBaseName == "" and registered.count == 0 and loaded.count == 0 then return false
        if code == undefined or code == "" or findItem codes code == 0 then code = "en"
        lang = code
        dict = loadDict code
        true
    ),

    fn trMsg key args: = (
        -- Translate a message id.
        --   key:  string message id ("confirmDelete", "appTitle", ...).
        --   args: optional #(v0, v1, ...) substituted into {0}, {1}, ...
        -- Fallback chain: active dictionary -> English dictionary -> the key itself.
        local txt = getText dict key
        if txt == undefined do txt = getText enDict key
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

    fn applyRollout roll = (
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

    fn applyRollouts arrOfRoll = (
        -- Localize array or rollouts in place.
        for roll in arrOfRoll do applyRollout roll
    ),

    fn langLabel code = (
        -- Human-readable label for a language code (for dropdowns).
        -- L10N.langLabel "ru" -> "Русский"
        for p in langLabels where p[1] == code do return p[2]
        code
    ),

	_auto_init = (
        -- Initialization after creation
		if engineVer != _engineVer do throw ("L10N engine version mismatch: expected " + (engineVer as string) + ", got " + (_engineVer as string))
		discoverDicts()
		if enDict.count > 0 do registerDict "en" enDict
		setLang "en"
	)
)
