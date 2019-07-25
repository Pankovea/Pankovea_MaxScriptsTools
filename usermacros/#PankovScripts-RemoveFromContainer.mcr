-- Remove selected from multiple Containers with groups 
-- version 1.0
-- date 25.07.2019
-- PankovEA © 3ddd.ru
-- https://3ddd.ru/users/PankovEA


fn GetLevlGroup GHead levl:0 =  -- assign group levels -- recousive function
(	if GHead.parent == undefined then (return levl)
	else (return GetLevlGroup GHead.parent levl:(levl+1))
)

macroScript RemoveFromContainers
category:"#PankovScripts"
tooltip:"Remove selected from multiple Containers with groups"
buttontext:"Remove From Containers"
icon:#("Containers", 3)
(
on isenabled return (
	local cnts = 0
	if selection.count > 0 then
	(	local n = selection.count
		while (n > 0) and (cnts==0) do
		(	if Containers.IsContainerNode selection[n].parent != undefined then cnts+=1
			n = n-1	)
	)
	(selection.count > 0) AND (cnts>0)
)

on execute do
(
local workobjects = for obj in selection collect obj

-- Containers
local cnts = for obj in workobjects where (Containers.IsContainerNode obj.parent != undefined) collect Containers.IsContainerNode obj.parent
makeuniquearray cnts

if cnts.count>0 then ( -- work or no

-- collectiong groups
local grps = for obj in workobjects where isgrouphead obj collect #(obj)
local g

for g in grps do
(	append g (dummy name:g[1].name boxsize:g[1].boxsize rotation:g[1].rotation scale:g[1].scale pos:g[1].pos)
						-- 2-new group
	append g #()	-- 3-grouped objects
	for n=1 to g[1].children.count do append g[3] g[1].children[n]
	append g 0 	-- 4-default level of nested group
)

-- assign group levels
for g in grps do g[4] = GetLevlGroup g[1]

-- replacing new group dummys in array
for g in grps do
	for n=1 to g[3].count where (isgrouphead g[3][n]) do			-- find inclouding groups 			n = index in target array
		for i = 1 to grps.count where (grps[i][1] == g[3][n]) do	-- find this group in base array	i = base index
		(	insertItem grps[i][2] g[3] n
			deleteItem g[3] (n+1)	)

-- sorting by levels
fn cmprFN g1 g2 =
(	case of (
(g1[4] < g2[4]): 1
(g1[4] > g2[4]): -1
default: 0  )
)
qsort grps cmprFN

-- ungrouping
local n= grps.count
while n > 0 do ( ungroup grps[n][1] ; n = n-1 )
-- clear deleted nodes
workobjects = for obj in workobjects where (isValidNode obj) collect obj

-- Remove Node From Content
for cntnr in cnts do for obj in workobjects do cntnr.RemoveNodeFromContent obj true

-- grouping
for g in grps do
( setGroupHead g[2] true
attachNodesToGroup g[3] g[2] )

select cnts -- selecting containers, witch is in work process

) -- end if 
) -- end onExicute
) -- end macroscript