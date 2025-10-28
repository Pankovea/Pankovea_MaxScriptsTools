/* ===================================
Макроскрипт: Renumber Material #X and Map #X
Версия: 2025.09.13
Автор: PankovEA

Назначение:
Переименовывает все материалы и карты в сцене,
чьи имена соответствуют шаблону:
  "Material #<число>" или "Map #<число>"
включая отрицательные и очень большие числа.

После обработки:
  Material #2135464, Material #45646489 ... → Material #1, Material #2, ...
  Карты  Map #145654, Map #2546587, ... → Map #1, Map #2, ...

Особенности:
Для того чтобы макс сбросил счётчик именования новых материалои карт необходимо перезагрузить сцену (save > open)

Как установить:
1. Скопируйте скрипт в "C:\Users\%username%\AppData\Local\Autodesk\3dsMax\20## - 64bit\ENU\usermacros". Используйте ваши данные
2. Перейдите: Customize → Customize User Interface → Toolbars"
   Найдите: категория "#PankovScripts", команда "Renumber Material #X / Map #X names"
3. Перетащите на панель — готово!
===================================

MacroScript: Renumber Material #X and Map #X
Version: 2025.09.13
Author: PankovEA

Purpose:
Renames all materials and maps in the scene whose names match the patterns:
  "Material #<number>" or "Map #<number>"
including negative and very large numbers.

After processing:
  Material #2135464, Material #45646489 ... → Material #1, Material #2, ...
  Maps  Map #145654, Map #2546587, ... → Map #1, Map #2, ...

Notes:
To force 3ds Max to reset its internal name counters for newly created materials and maps,
you need to reload the scene (save > open).

Installation:
1. Copy the script to:
   "C:\Users\%username%\AppData\Local\Autodesk\3dsMax\20## - 64bit\ENU\usermacros"
   (use your actual path and Max version).
2. Open: Customize → Customize User Interface → Toolbars
   Find the category "#PankovScripts" and the command "Renumber Material #X / Map #X names"
3. Drag the command onto a toolbar — done!

===================================
*/

macroScript Pankov_RenumberMaterialMaps
category:"#PankovScripts"
buttontext:"Re#"
tooltip: "Renumber Material #X / Map #X. Shift+ Renumber GroupsX"
icon: #("renum#X", 1)
(
    struct MatchData (obj, number, type)

	local mat_prefixes = #(
		"Material #",
		"Map #"
	)
	
	local obj_prefixes = #(
		"Group",
		"Line",
		"Rectangle",
		"Circle",
		"Arc",
		"Text",
		"Box",
		"Cone",
		"Sphere",
		"GeoSphere",
		"Cylinder",
		"Plane"
	)
	
	local all_prefixes = mat_prefixes + obj_prefixes
	
    fn parseNumberFromName str = (
        if classof str != String do return undefined
		
		for prefix in all_prefixes do (
			if matchPattern str pattern:(prefix+"*") then (
				local startIdx = prefix.count + 1
				if startIdx <= str.count then (
					local numStr = substring str startIdx str.count
					if numStr != "" then try (
						local num = execute numStr
						if classof num == Integer then return num
					) catch ()
				)
				break
			)
		)

        return undefined
    )

    fn collectAllMatchingObjects = (
        local result = #()

        -- Сбор всех материалов
        for cls in material.classes do (
            try (
                local instances = getClassInstances cls --target:sceneMaterials
                for obj in instances do (
                    local num = parseNumberFromName obj.name
                    if num != undefined then (
                        local typ = if (superclassof obj) == Material then "Material" else "Map"
                        append result (MatchData obj:obj number:num type:typ)
                    )
                )
            ) catch ()
        )

        -- Сбор всех карт
        for cls in texturemap.classes do (
            try (
                local instances = getClassInstances cls --target:sceneMaterials
                for obj in instances do (
                    local num = parseNumberFromName obj.name
                    if num != undefined then (
                        local typ = if (superclassof obj) == Material then "Material" else "Map"
                        append result (MatchData obj:obj number:num type:typ)
                    )
                )
            ) catch ()
        )

        -- Удаление дубликатов по ссылке
        return makeUniqueArray result
    )

	fn compareByNumber a b = (
		if a.number < b.number then -1
		else if a.number > b.number then 1
		else 0
	)
	
    fn renameMaterialsAndMapsSequentially matches = (
        local materials = #()
        local maps = #()

        for m in matches do (
            if m.type == "Material" then append materials m
            else if m.type == "Map" then append maps m
        )

        if materials.count > 1 do qsort materials compareByNumber
        if maps.count > 1 do qsort maps compareByNumber
		local materials_renaned = 0
		local maps_renaned = 0
        for i = 1 to materials.count do (
            local item = materials[i]
            local newName = "Material #" + (i as string)
            if item.obj.name != newName then (
                format "% -> %\n" item.obj.name newName
                item.obj.name = newName
				materials_renaned += 1
            )
        )

        for i = 1 to maps.count do (
            local item = maps[i]
            local newName = "Map #" + (i as string)
            if item.obj.name != newName then (
                format "% -> %\n" item.obj.name newName
                item.obj.name = newName
				maps_renaned += 1
            )
        )

        format "Переименовано: % материалов, % карт\n" materials_renaned maps_renaned
    )

    -- === Сбор всех групп с именем Group* ===
    fn collectAllGroupHeads = (
		local result = #()
        local groups = for obj in objects where isgrouphead obj and matchPattern obj.name pattern:"Group*" collect obj
		for obj in groups do (
			local num = parseNumberFromName obj.name
			if num != undefined then (
				append result (MatchData obj:obj number:num type:"Group")
			)
		)
        return result
    )

    fn collectMatchObjects = (
		local result = #()
		for obj in objects do(
			for prefix in all_prefixes do (
				if matchPattern obj.name pattern:(prefix+"*") do (
					local num = parseNumberFromName obj.name
					if num != undefined then (
						append result (MatchData obj:obj number:num type:prefix)
					)
				)
			)
		)
        return result
    )
	
	fn nDig i n = (
		if (i as string).count<n then (
			str = ""
			for m in 1 to (n-(i as string).count) do str+="0"
			str+=i as string
		) else i as string
	)

    -- === Переименование групп в формате Group001, Group002... ===
    fn renameObjectsSequentially mData = (

		group_objs = Dictionary(#string)
		-- рабиваем на группы в словарь
		for md in mData do (
			if group_objs[md.type] == undefined then group_objs[md.type] = #(md)
			else append group_objs[md.type] md
		)
		
		local objs_renamed = Dictionary(#string)
		for k in group_objs.keys do (
			-- сортируем внутри групп
			qsort group_objs[k] compareByNumber
		
			-- переименовывваем
			for i = 1 to group_objs[k].count do (
				local item = group_objs[k][i]
				-- format "объект %\n" item
				local newName = item.type + (nDig i 3)
				if item.obj.name != newName then (
					format "% -> %\n" item.obj.name newName
					item.obj.name = newName
					if objs_renamed[k] == undefined then objs_renamed[k] = 1 else objs_renamed[k] += 1
				)
			)
		)
		if objs_renamed.count > 0 then (
			format "Переименовано: "
			for k in objs_renamed.keys do (
				format "%: %, " k objs_renamed[k]
			)
			format "\n"
		) else (format "Всё осталось по прежнему\n")
    )
	
    on execute do (
		if keyboard.shiftPressed then (
			with undo label:"Renumber Objects" on (
				-- объекты				
				local mData = collectMatchObjects()
				if mData.count == 0 then (
					format "Объекты для переименования не найдены\n"
				)
				else (
					renameObjectsSequentially mData
				)
			)
		) else (
			with undo label:"Renumber Materials/Maps" on (
				local matches = collectAllMatchingObjects()
				if matches.count == 0 then (
					messagebox "Не найдено ни одного материала или карты с именем вида 'Material #X' или 'Map #X'."
				)
				else (
					renameMaterialsAndMapsSequentially matches
				)
			)
		)
    )
)