/* @Pankovea Scripts - 2025.10.20
ExtractInstanceFromReference: Скрипт извлекает инстансную часть объекта.

Воздаёт новый объект и заменяет ссылку на геометрию на инстансную часть.
Можно применять несколько раз подряд чтобы извлечь более глубокие части.

----------------------------------------------------------------

ExtractInstanceFromReference: This script extracts the instanced part of an object.

Creates a new object and replaces the geometry reference with the instanced part.
Can be applied multiple times in succession to extract deeper parts.

*/


macroScript Pankov_ExtractInstanceFromReference
category:"#PankovScripts"
buttontext:"ExtractInstanceFromReference"
tooltip:"Extract instance from reference"
icon:#("pankov_instancseAll",2)
(
	fn isEqualListObjects a b = (
		-- Used to compare the list of the reference nodes for the modifier
		if a.count != b.count then return false
		for i in 1 to a.count do if a[i] != b[i] then return false
		return true
	)
	
	on isenabled return (
		if selection.count != 1 or selection[1].modifiers.count == 0 do return false
		local base_refs = refs.dependentNodes selection[1].baseobject
		if base_refs.count > 1 do (
			for modif in selection[1].modifiers do (
				if not isEqualListObjects base_refs (refs.dependentNodes modif) do (
					return true
				)
			)
		)
		false
	)
	
	on execute do (
		obj = selection[1]
		modifiedObjSub = obj[4]  -- SubAnim:Modified_Object
		i = 1; subObjects = #() -- list of modifiers or Modified_Object
		while modifiedObjSub[i] != undefined do (append subObjects modifiedObjSub[i]; i+=1)
        modObjSubAnim = subObjects[subObjects.count]  -- SubAnim для #Modified_Object
		if modObjSubAnim.name == "Modified Object" do
			derivedObj = modObjSubAnim.value  -- ReferenceTarget:DerivedObject
		
		undo "Extract instance" on (
			-- Создаем tempNode того же типа, что и obj
			tempNode = copy obj
			if derivedObj != undefined and superclassOf derivedObj == GenDerivedObjectClass then (
				-- Находим индекс референса для .object в tempNode
				/*
				refIndex = 0
				for i = 1 to refs.getNumRefs tempNode do (
					if refs.getReference tempNode i == tempNode[4].object do (
						refIndex = i
						exit
					)
				)
				*/
				-- искать не нужно
				-- refIndex ввсегда 2
				local refIndex = 2
				
				-- Если индекс найден,
				--if refIndex > 0 do (
					-- заменяем на derivedObj
					refs.replaceReference tempNode refIndex derivedObj
					select tempNode
				--)
			) else (
				-- clear modifiers
				while tempNode.modifiers.count > 0 do deletemodifier tempNode 1
				-- replace base object
				tempNode.baseobject = obj.baseobject
				select tempNode
			)
		)
	)
)
