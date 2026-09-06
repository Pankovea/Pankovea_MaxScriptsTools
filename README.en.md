[на Русском](README.md)
# Pankovea_MaxScriptsTools
Pankovea utilities for working in 3ds Max with architectural visualization

# Contents
[usermacros/](usermacros/)
- [Albedo Tuner](#albedo-tuner) 
- [Camera Animator](#camera-animator)
- [Camera From View](#camera-from-view)
- [Batch Views Manager](#batch-views-manager)
- [Concentric Cycles](#concentric-cycles)
- [Copy-Paste](#copy-paste)
- [Corona Toggles](#corona-toggles)
- [Crop To Atlas](#crop-to-atlas)
- [Distribute](#distribute)
- [Link Material](#link-material)
- [Extract Instance](#extract-instance)
- [Instance All](#instance-all)
- [Reset ModContextTM](#reset-modcontexttm)
- [Align Pivot PCA](#align-pivot-pca)
- [Renumber Material #X and Map #X](#renumber-material-x-and-map-x)
- [Paste Image Reference To Plane](#paste-image-reference-to-plane)
- [Rebuild Extruded Mesh to Spline](#rebuild-extruded-mesh-to-spline)
- [ModPropsLister](#modpropslister)
- [InstancedEditMod](#instancededitmod)
- [ResetPivotOffset](#resetpivotoffset)


[scripts/](scripts/)
- [Simplify Spline](#simplify-spline)
- [Save Clipboard Image To Active Folder](#save-clipboard-image-to-active-folder)

## Installation
### Copying files
1. Option via downloading the archive option
    - Download [the entire repository](https://github.com/Pankovea/Pankovea_MaxScriptsTools/archive/refs/heads/main.zip)
    - Unzip to `%LOCALAPPDATA%/Autodesk/3dsMax/20XX - 64bit/ENU/`
2. Option via downloading a separate script
    - Download the required script from the usermacros folder and place it in the folder `%LOCALAPPDATA%/Autodesk/3dsMax/20XX - 64bit/ENU/usermacros` (Replace `20XX - 64bit` with your version of 3dsmax) <a name="#individual-icons-install"></a>
    - If necessary, download the `usericons` and place them in the `./usericons` folder
3. Option via cloning the repository (You must have [Git](https://git-scm.com/install/windows) installed):
    - Go to your folder `%LOCALAPPDATA%/Autodesk/3dsMax/20XX - 64bit/ENU/` (Replace `20XX - 64bit` with your version of 3dsmax)
    - In the address bar, run
    ```
    git init
    git remote add origin https://github.com/Pankovea/Pankovea_MaxScriptsTools.git
    git checkout -b main origin/main
    ```
### Setting up the user interface
- Start/restart 3dsmax
- Menu `Cutomize` -> `Cutomize user interface` -> `Toolbar tab`
- If necessary, create a new toolbar `New...` -> `Pankov_scripts`
- On the left, select `group Main UI` -> `Category #PankovScripts` -> Drag the desired script to the panel

## Simplify Spline

[Version 2026.09.06 - alpha](/scripts/#Simplify-Spline.ms)

A script for simplifying splines. The base object must be EditableSpline or Line. The EditSpline modifier will not work.

If you select:
* vertices, it removes a group of consecutive vertices and tries to preserve the shape.
* segments, it automatically selects points for deletion within a group of adjacent segments, leaving its end points.
* splines, it determines which vertices can be deleted.
It also works at the object level, but only with the basic EditableSpline.

You need to select objects or subobjects and run:
1. run_rebuildArcs() -- Searches for circular arcs and rebuilds them. Usually for processing CAD source files.
2. run_simplifySpline() -- Works with arbitrary curvature.
(Sequential runs are possible)

[back (contents)](#contents)

## Rebuild Extruded Mesh to Spline
[Version 2026.09.05 - alpha](usermacros/%23PankovScripts-Rebuild-Mesh-to-Extruded-Spline.mcr)

Restores imported meshes that were originally splines with extrusion to their original state:
- automatically detects the extrusion axis from the POLYGON EDGES (Editable Poly)
- builds a spline from the cap contour (or the wall facade): openings (windows/doors)
  stay as holes
- optimizes the spline shape using [Simplify Spline](#simplify-spline) (optional — Ctrl turns optimization off)
- adds extrusion of the same height
- preserves the Material IDs of the top/bottom caps and the extrusion surface
  (plain Extrude with default IDs, otherwise a MaterialID modifier / Shell+UVWMap)

How to use:
1. Select one or more meshes.
2. Run the macro Rebuild Extruded Mesh to Spline.
3. Done: a spline with extrusion will appear instead of each mesh.

Keyboard modifiers:
* regular run — the axis is detected automatically (from polygon edges);
  on ambiguity — world +Z (slab)
* Shift — fallback hint for walls/tilted objects: the local axis of least extent
* Alt — extrusion direction: maximum base surface, in the negative direction
  (without Alt — minimum base surface, in the positive direction)
* Ctrl — turn off auto-simplification of the spline
* Shift + Alt + Ctrl — any combination works

The original object is deleted automatically.
Global settings are at the top of the file (REMS_*, e.g. REMS_preserveMatIDs).

[back (contents)](#contents)

## ModPropsLister
[Version 2026.09.06](usermacros/%23PankovScripts-ModPropsLister.mcr)

Dynamic multi-editor for parameters of selected NON-INSTANCE objects.
Compares and edits shared properties of the base object and common modifiers
(top instance of each class in the stack).

* Modifiers list with an eye icon: enabled / disabled / mixed state
  (mixed opens the Enable/Disable popup menu)
* The properties rollout is generated on the fly; differing values are shown
  inactive, with a "Make common" button and a context menu
  Maximum / Average / Median / Minimum / Most common
* Base: MIXED — different base classes: only properties that match by name and type
  are shown. This way you can edit common properties across different object types.
* Group mode via right-click on a value: Incremental (delta) and Scale (multiplier)
* Smart spinner step: 1% of the parameter magnitude, lower bound from the rollout
  average; Alt — fine power step; one Undo step for a whole spinner drag
* Object type filters: Geometry/Shapes/Light/Camera/Helpers

[back (contents)](#contents)

## InstancedEditMod
[Version 1.0.0 (2026.08.30)](usermacros/%23PankovScripts-InstancedEditMod.mcr)

Adds the Edit Spline / Edit Poly modifier as an INSTANCE onto all selected objects at once.
This way you can edit multiple objects at the same time. You can group them for convenience,
but you can also quickly find and select the instance objects by running the macro while
the modifier is selected.

* If all base objects are splines, Edit Spline is added; if any geometry is present —
  Edit Poly (helpers/lights/cameras don't take part in the decision)
* Edit Spline is inserted into the spline area (right below the first "converting"
  modifier, e.g. Extrude); Edit Poly always goes to the very top of the stack
* Re-running REUSES the existing instance (adds objects that are missing it);
  the modifier name gets the " multi (N)" suffix
* If our multi-modifier is open in the stack (or the objects share a common instance),
  the run selects all objects that have it (groups are opened if necessary)
* Shift — Collapse To: our modifier and everything below it collapse into the base object

[back (contents)](#contents)

## ResetPivotOffset
[Version 2026.09.06](usermacros/%23PankovScripts-ResetPivotOffset.mcr)

Works like Reset Xform but KEEPS the rotation: clears the pivot offset and scale
(objectOffset) while preserving the axis orientation.

* Regular run: the existing "Reset Pivot XForm" modifier is fitted to the current
  pivot offset (or a new one is added), then the offset is cleared
* Shift: the pivot offset is baked into the object transform, the offset is cleared
  without a modifier

Useful after `Hierarchy → Affect Pivot Only` → `Reset Pivot only` when you need to
clear the pivot position/scale without losing its rotation.

[back (contents)](#contents)

## Albedo Tuner
[Version 2022.02.27](usermacros/%23PankovScripts-Albedo%20Tuner.mcr)

A script to adjust the Albedo parameter for materials on selected objects. Initially designed for Corona renderer, but it can also work with V-Ray (may be inaccurate).

Purpose: reduce material reflectance to increase image contrast by lowering reflected light contribution. Useful for achieving more natural looks in scenes with many white surfaces.

[back (contents)](#contents)

## Camera Animator
[Version 2026.08.28](usermacros/%23PankovScripts-CameraAnimator.mcr)

Creates an animated camera from selected cameras in the scene.

* Supports: Standard camera, V-Ray camera, Corona camera
* If an animated camera is selected, run the script with Shift pressed to perform the inverse operation: create cameras from animation frames.

[back (contents)](#contents)

## Camera From View
[Version 2024.07.06](usermacros/%23PankovScripts-CameraFromView.mcr)

Creates a camera from the current perspective view depending on the active renderer (V-Ray or Corona).

[back (contents)](#contents)

## Batch Views Manager
[Version 2026.09.05](usermacros/%23PankovScripts-BatchViewsManager.mcr)

A utility to manage 3ds Max batch rendering (Batch Render).

Batch Views:
* Reorder views in the list, group views, move groups
* Quick view load into the scene by a single click in the list (camera, resolution, scene state)
* Double click toggles views on/off and collapses/expands a group
* Aspect ratio presets (3:2, 4:3, 16:9, ...) aware of frame orientation
* **Preserve MegaPix** mode — change the aspect ratio while keeping the pixel count
* Scale: global resolution multiplier for preview/final of all views.
  - Base resolution is stored in the view name (`CamA (1920x1080)`); the global scale applies as a single multiplier to all views
  - **Apply** bakes the current scaled size as the new base and resets the scale to 100%
* Batch change of output sizes and paths (including Render Elements paths)

Cameras:
* Camera list. Double click shows the camera in the viewport; single click edits it in the script UI
* Lens and shooting parameters configuration
* Camera rename that updates view names when a view contains the camera name
* Supports Corona, V-Ray, Physical cameras

Scene States:
* A replacement for the standard Scene States dialog. Everything in one window — create, rename, update and delete scene states.
* Fast and convenient: fewer mouse clicks than the standard interface.
* Choose which parts to capture (camera, lights, materials, layers, environment, etc.), apply a state with a double click, list sorted by name.

[back (contents)](#contents)

## Concentric Cycles
[Version 2024.10.12](usermacros/%23PankovScripts-ConcentricCircles.mcr)

Creates a parametric object with concentric circles and configurable parameters.

Features:
* The object is created at the origin or at the center of the selected bounding box.
* The object has custom attributes used to tweak parameters.
* If one such object is selected, opening the script loads its current parameters; changing them updates the object.
* If multiple objects are selected, parameters are applied to all selected ConcentricCycles objects.
* You can undo parameter changes via standard Undo if parameters are set incorrectly.

[back (contents)](#contents)

## Copy-Paste
[Version 2025.03.20](usermacros/%23PankovScripts-CopyPaste.mcr)

### Object copy/paste
Adds copy and paste buttons to transfer objects between different 3ds Max projects/windows. You can assign hotkeys in: Customize -> Hotkey Editor -> find Copy-Paste action -> Assign hotkey. Example: Alt+C and Alt+V.

For single-script installation, copy icons [1](usericons/pankov_CopyPaste_24i.bmp) and [2](usericons/pankov_CopyPaste_16i.bmp) into your 3ds Max `usericons` folder (see Installation step 2).

### Modifier copy/paste
A macro for assigning hotkeys to copy/paste modifiers. It has no icons.
Instead of right-clicking and choosing copy/paste from the modifier menu, use hotkeys: Customize -> Hotkey Editor -> find Copy-Paste Modifier action -> Assign hotkey. Example: Ctrl+Shift+C and Ctrl+Shift+V — very convenient (you may need to remove a hotkey from Chamfer Mode on EditSpline/EditPoly).

Useful notes:
* You can paste a modifier onto multiple selected objects — it will be inserted as an instance.
* EditPoly and EditSpline modifiers are pasted without local data. This preserves instance links across objects without breaking others.

### Select Modifier Instances
For the currently selected modifier, finds its instances and selects all objects that contain it.
Enabled when the modifier has instances.


[back (contents)](#contents)

## Corona Toggles
[Version 2024.07.05](usermacros/%23PankovScripts-CoronaToggles.mcr)

Exposes quick Corona render toggles on a toolbar:
* Standard Region Render Toggle
* Standard BlowUp Render Toggle
* Corona Render Selected Toggle (also toggles "Clear Between Renders")
* Corona Distributed Render Toggle
* Corona Denoise on Render Toggle
* Corona Render Mask Only Toggle

For single-script installation, copy icons [1](usericons/PankovScripts_24i.bmp) and [2](usericons/PankovScripts_16i.bmp) into your 3ds Max `usericons` folder (see Installation step 2).

[back (contents)](#contents)

## Crop To Atlas
Create a texture atlas (this is when multiple textures are located in a single file)

Using the program, you can create a texture atlas while reducing the number of assets. This is done when using a decoration that uses many small textures. They can be reduced and combined into a single file.
This script:
- will collect textures from the selected objects
- will reduce them if necessary
- will place the content compactly in one or more atlases using the MaxRects algorithm (rotation is possible)
- will change material references to the new texture atlas
- will perform correct cropping and reverse rotation (takes into account the previous cropping coordinates)

- Works with Bitmap, CoronaBitmap, VrayBitmap

[back (contents)](#contents)

## Distribute
[Version 2026.08.28](usermacros/%23PankovScripts-Distribute.mcr)

A script for spatial distribution.

Features:
* Works in Object mode and sub-object modes.
  Implemented alignment for sub-objects in EditableSpline, EditablePoly, EditableMesh and the EditPoly modifier.
  (The EditSpline and EditMesh modifiers are not available in Maxscript and does not work)
* Distributes objects evenly taking object size into account so spacing between objects is uniform
  (pivot offset and bounding accuracy need improvement; currently size is determined by bounding box).
* Automatically determines first and last objects by largest distance between them.
* Works inside EditPoly even when the modifier is instanced on multiple objects.
* Distributes grouped objects.
* Requires being in the appropriate selection mode to run.

[back (contents)](#contents)
## Extract Missing Maps
[Version 2026.08.16](usermacros/%23PankovScripts-ExtractMissingMaps.mcr)

This is an analogue of Relink Bitmaps, but with a specific purpose.
It can also find lost textures in the specified folder. But at the same time, it scans archives (zip, 7z, rar).
And if there are files from the list of lost ones in the archive, it extracts them to the specified folder and reassigns the path in the maps.

- You can search for all textures in the project (not just lost ones)
- You can search for textures only in selected objects
- You can modify the list by removing elements
- It can be used as an Asset Collector

**Need installed [7-zip](https://www.7-zip.org/)**

[назад (содержание)](#содержание)
## Link Material
[Version 2025.09.04](usermacros/%23PankovScripts-LinkMaterial.mcr)

Idea borrowed from Blender.
A quick button to take a material from a neighboring object.
Assign hotkeys in: Customize -> Hotkey Editor
* Link material -> Assign hotkey (e.g. Ctrl+L)
* Select by material -> Assign hotkey (e.g. Ctrl+Shift+L)

Workflow:
* Link material: Select all target objects first, then select the source object last and press the hotkey.
* Select by material: Select any object and press the hotkey to select all visible objects that share the same material(s).

## Extract Instance
[Version 2026.08.28](usermacros/%23PankovScripts-ExtractInstance.mcr)

Extracts the instance object from a reference object.
Select a reference object and run the macro.

For single-script installation, copy icons [1](usericons/pankov_instancseAll_24i.bmp) and [2](usericons/pankov_instancseAll_16i.bmp) to your 3ds Max `usericons` folder (see Installation step 2).

[back (contents)](#contents)

## Instance All
[Version 2026.08.28](usermacros/%23PankovScripts-InstanceAll.mcr)

Script to replace objects with instances and reference parts.

For single-script installation, copy icons [1](usericons/pankov_instancseAll_24i.bmp) and [2](usericons/pankov_instancseAll_16i.bmp) to your 3ds Max `usericons` folder (see Installation step 2).

Features:
* Replace any object with an instance of the selected object by creating an instance
  and applying original transforms, layer, and material according to the settings.
  Note: if only some instances were selected, unselected instance objects will not be replaced.

* Replace a reference part of an object with the ability to choose the source reference level.

* When replacing a large number of objects (>100), a progress bar is shown.

Details:

1. Make Instances group
* Can create instances of both individual objects and grouped objects.
* Can fit the new instance size to match the size of the objects being replaced.

2. Replace Reference Target group
Extracts a reference object from the chosen main object and replaces the specified reference level
in the selected objects. This section works only in object mode (when the source object is geometry,
not a group).

Behavior depending on selection:
* If a single destination object is selected, the script will prompt to choose the insertion level.
* If multiple destination objects are selected, you can choose:
  - Top layer (Top) — replace the whole object. In this case, unselected instance objects will not be affected.
  - Instance part (Instance part) — the lower reference level including modifiers up to the first "break".
    This may match the base level. In this case all objects referencing this part will be changed.
  - Base object (Base object) — replace only the base object (the first entry on which the modifier stack is built).
    In this case unselected instance objects will not be affected.

## Reset ModContextTM
[version 2025.10.28](usermacros/%23PankovScripts-ResetModContextTM.mcr)

This package contains several macroscripts for manipulating a modifier's transform context matrix.

Overview:

Every modifier has a transform context. For example, when a modifier is applied to a single object the transform context is zero; but when a modifier is applied to multiple objects the transform pivot is placed at the objects' center of mass. This makes the modifier behave consistently in world space while each object retains its own context. If objects are moved, the context stays tied to local coordinates. This script is intended for such cases — after moving objects it recenters the modifier context to a single point in world coordinates.

### Main macro: Reset ModContextTM
Resets the modifier's transform context matrix to the state as if the modifier had just been applied to the object(s).

Features:
* Works with the selected modifier in the modifier stack
* Hold Shift to reset ModContextBBox per object individually
* Press Esc to reset the Gizmo
* Changing the transform pivot may not preserve the object's original position

Warning:
* Undo does not work

### ResetModContextBBox
Same as above, but resets the modifier's context BBox

### Copy ModContextTM
Copies and pastes the transform matrix for a modifier, preserving its global placement as in the source object.

This is an alternative method to align modifier contexts by adjusting only one of them and not changing the others (unlike the previous script).

### TransformModContextTM
Allows transforming a modifier's context matrix using an auxiliary Dummy object that serves as a Gizmo.
For example, you can use a single dependent instance of a UVWMap modifier on many objects and tweak its orientation via the context.

[back (contents)](#contents)

## Align Pivot PCA
[Version 2025.12.03](usermacros/%23PankovScripts-AlignPivotPCA.mcr)

Aligns local axes along the longer and shorter dimensions of the object’s geometry.

This script analyzes the geometry of the selected object, computes the covariance matrix of its vertices,
and performs Principal Component Analysis (PCA) to determine the object's natural orientation.

When invoked with Shift+, the script searches for a rotation that minimizes the bounding box size,
while keeping the Z-axis fixed.
Typically, square-shaped objects require axis realignment, whereas circular objects should retain their original orientation —
use Shift+ accordingly.

If the object's Z-axis flips downward, its orientation is automatically adjusted
to stay as close as possible to the world +Z direction.

The object's pivot is then moved to its centroid and rotated to align with the computed coordinate system,
while the geometry itself remains fixed in the scene.

The script handles initially offset pivots correctly by precisely recalculating objectOffset parameters.
All calculations are performed in global space.

[back (contents)](#contents)

## Renumber Material #X and Map #X
[Version 2025.09.13](usermacros/%23PankovScripts-Renumber_Material%23X_Maps%23X.mcr)

Renames all materials and maps in the scene whose names match the patterns:
  "Material #<number>" or "Map #<number>"
including negative and very large numbers.

After processing:
  Material #2135464, Material #45646489 ... → Material #1, Material #2, ...
  Maps  Map #145654, Map #2546587, ... → Map #1, Map #2, ...

Notes:
To force 3ds Max to reset internal naming counters for newly created materials and maps,
reload the scene (save > open).

Installation:
1. Copy the script to:
   "C:\Users\%username%\AppData\Local\Autodesk\3dsMax\20## - 64bit\ENU\usermacros" (adjust path for your setup)
2. Go to: Customize → Customize User Interface → Toolbars
   Find category "#PankovScripts" and the command "Renumber Material #X / Map #X names"
3. Drag the command onto a toolbar — done!

The icons for the buttons are located here: [1](usericons/renum#X_24i.bmp) and [2](usericons/usericons/renum#X_16i.bmp). Copy them to the `usericons` folder in your 3dsmax settings ([see Installation step 2](#installation)).

[back (contents)](#contents)
## Paste Image Reference To Plane
[Version 2025.12.04](usermacros/%23PankovScripts-PasteImageRefToPlane.mcr)

Paste Clipboard Image as Reference Plane
Copy any image → run the script → it appears in your scene as a textured plane.

Without Shift: plane in XZ (horizontal, like a floor plan)
With Shift pressed: plane in XY (vertical, like a wall), bottom edge at Z = 0
* 1 pixel = 1 millimeter — scale automatically adapts to your scene units
* Full image resolution is displayed. Pixels are not lost
* Re-running updates the existing plane — no duplicates
Perfect for floor plans, elevations, screenshots, and technical references — no manual file saving needed!

[back (contents)](#contents)

## Save Clipboard Image To Active Folder
[version 2026.05.27](scripts/SaveClipboardImageToActiveFolder.ahk)

A script for AutoHotkey v2 that saves an image
from the clipboard as a PNG file with a single hotkey.
The image is saved to the folder that
is currently open in Windows Explorer or in the standard
"Open File" dialog box of any program.

Need an installed one https://www.autohotkey.com/
[Direct download link](https://www.autohotkey.com/download/ahk-v2.exe ) (3 MB)

Download or save the script file [SaveClipboardImageToActiveFolder.ahk](scripts/SaveClipboardImageToActiveFolder.ahk)
to any convenient location on your computer.

Run the script by double-clicking. After launching, the AutoHotkey icon will appear in the notification area
(system tray), signaling the script's operation.

Hotkey: `Win + V`

Usage examples:
- Screenshot of the screen (PrtSc key)
- Copy the image from the browser
  - Copy the selected part in the graphic editor
Then switch to the Explorer window or open the `open file` dialog in any program.
Press `Win + V` to save the PNG file to the active folder. You can open it right there — It's convenient!

[Detailed description](scripts/SaveClipboardImageToActiveFolder_readme.md)

[back (content)](#content)
