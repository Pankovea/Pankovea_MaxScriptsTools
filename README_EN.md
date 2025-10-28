[на Русском](README.md)
# Pankovea_MaxScriptsTools
Pankovea utilities for working in 3ds Max with architectural visualization

# Contents
[usermacros/](usermacros/)
- [Albedo Tuner](#albedo-tuner) 
- [Camera Animator](#camera-animator)
- [Camera From View](#camera-from-view)
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


[scripts/](scripts/)
- [Simplify Spline by Remove Selected Vertices](#simplify-spline-by-remove-selected-vertices)

## Installation
1. Option: clone the repository:
    - Open your folder `C:\Users\_USER_\AppData\Local\Autodesk\3dsMax\_MAX-version_\ENU` — replace `_USER_` with your OS username and `_MAX-version_` with your 3ds Max version.
    - In the address bar run: `git clone https://github.com/Pankovea/Pankovea_MaxScriptsTools.git`
    - Start/restart 3ds Max.
    - Go to: Customize -> Customize User Interface -> Toolbars -> group Main UI -> Category `#PankovScripts` -> drag the desired script to a toolbar.
2. Option: download a single script
    - Download the desired script from the usermacros folder and place it into:
      `C:\Users\_USER_\AppData\Local\Autodesk\3dsMax\_MAX_version_\ENU\usermacros` (replace `_USER_` and `_MAX_version_` appropriately).
    - If needed, download `usericons` and put them into the `..\ENU\usericons` folder.

## Simplify Spline by Remove Selected Vertices

[Version 2025.08.03 - alpha](/scripts/Simplify-Spline-by-Remove-Selected-Vertices.ms)

A script to simplify splines. Requires the base object to be Editable Spline or Line. It will not work as a modifier.

* If vertices are selected, it removes groups of consecutive selected vertices while attempting to preserve the shape.
* If splines are selected, the script automatically determines which vertices can be removed and removes them (this mode is experimental).

Requires [Matrix.ms](/scripts/Matrix.ms) in the same scripts folder. Documentation for [Matrix](/docs/Matrix.ms.md).

Select vertices to remove in the spline (not inside a modifier) and run run_simplifySpline(). Planning macro integration later.

Does not process end vertices. You cannot remove the first or last vertex in a closed spline.
There are also issues if vertices are corner points — in this implementation they must all have handles.

[back (contents)](#contents)

## Albedo Tuner
[Version 2022.02.27](usermacros/%23PankovScripts-Albedo%20Tuner.mcr)

A script to adjust the Albedo parameter for materials on selected objects. Initially designed for Corona renderer, but it can also work with V-Ray (may be inaccurate).

Purpose: reduce material reflectance to increase image contrast by lowering reflected light contribution. Useful for achieving more natural looks in scenes with many white surfaces.

[back (contents)](#contents)

## Camera Animator
[Version 2024.07.06](usermacros/%23PankovScripts-CameraAnimator.mcr)

Creates an animated camera from selected cameras in the scene.

* Supports: Standard camera, V-Ray camera, Corona camera
* If an animated camera is selected, run the script with Shift pressed to perform the inverse operation: create cameras from animation frames.

[back (contents)](#contents)

## Camera From View
[Version 2024.07.06](usermacros/%23PankovScripts-CameraFromView.mcr)

Creates a camera from the current perspective view depending on the active renderer (V-Ray or Corona).

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
This script works with the free TexturePacker tool (https://www.codeandweb.com/texturepacker).

Use TexturePacker to create a texture atlas and reduce asset count for many small decoration textures. Then run this script to update material bitmap references to the atlas and adjust cropping accordingly.

* Works with Bitmap and CoronaBitmap.

[back (contents)](#contents)

## Distribute
[Version 2025.09.04](usermacros/%23PankovScripts-Distribute.mcr)

A script for spatial distribution.

Features:
* Works in Object mode and sub-object modes.
  Implemented alignment for sub-objects in EditableSpline, EditablePoly, and the EditPoly modifier.
  (EditSpline modifier is not technically accessible and will not work.)
* Distributes objects evenly taking object size into account so spacing between objects is uniform
  (pivot offset and bounding accuracy need improvement; currently size is determined by bounding box).
* Automatically determines first and last objects by largest distance between them.
* Works inside EditPoly even when the modifier is instanced on multiple objects (#FIXME: currently unstable in Max2025).
* Distributes grouped objects.
* Requires being in the appropriate selection mode to run.

[back (contents)](#contents)

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
[Version 2024.07.10](usermacros/%23PankovScripts-ExtractInstance.mcr)

Extracts the instance object from a reference object.
Select a reference object and run the macro.

For single-script installation, copy icons [1](usericons/pankov_instancseAll_24i.bmp) and [2](usericons/pankov_instancseAll_16i.bmp) to your 3ds Max `usericons` folder (see Installation step 2).

[back (contents)](#contents)

## Instance All
[Version 2024.10.17](usermacros/%23PankovScripts-InstanceAll.mcr)

Script to replace objects with instances and reference parts.

For single-script installation, copy icons [1](usericons/pankov_instancseAll_24i.bmp) and [2](usericons/pankov_instancseAll_16i.bmp) to your 3ds Max `usericons` folder (see Installation step 2).

Features:
* Replace any object with an instance of a selected source object by creating an instance and applying original transforms, layer, and material depending on settings.
  If only some instances are selected, unselected instances will not be replaced.
* Shows a progress bar when processing a large number of objects (>100).

1. "Make Instances" group:
    * Can clone by instance both individual objects and grouped objects.
    * Can fit the new instance to the size of the objects being replaced.

2. "Get instance part from reference object" group:
Extracts the base object (the bottom of the modifier stack) and replaces selected objects with it.
No new objects are created and all scene dependencies are preserved.
    * Can also replace the entire modifier stack.

[back (contents)](#contents)

## Reset ModContextTM
[Version 2025.03.20](usermacros/%23PankovScripts-ResetModContextTM.mcr)

Resets the modifier transformation context matrix as if the modifier was just applied to one or multiple objects.

Notes:

Each modifier has a transform context. For example, when a modifier is applied to a single object the transform context is zero, but if the modifier is applied to multiple objects the transform pivot is placed at the center of mass. This makes the modifier behave consistently in world space while each object retains its own context. After moving objects, the context remains tied to local coordinates. This script recenters the context in world coordinates.

Features:
* Works with the selected modifier in the modifier stack.
* Hold Shift to reset ModContextBBox per object individually.
* Press Esc to reset the Gizmo.
* Note: changing the transform pivot may not preserve the object's original position.
Warning:
* Undo does not work.

### Copy ModContextTM
Located in the same file.

Copies and pastes the transform matrix for a modifier, preserving its global placement relative to the source object.

This is an alternate method to match modifier contexts by adjusting only one and not changing others (unlike the previous script).

[back (contents)](#contents)

## Align Pivot PCA
[Version 2025.09.30](usermacros/%23PankovScripts-AlignPivotPCA.mcr)

Aligns the local axes along the long and short dimensions of the object's geometry.

This script analyzes the selected object's geometry, computes the covariance matrix of its vertices,
and extracts principal components (Principal Component Analysis - PCA) to determine the object's natural orientation.

The first and second principal axes define the plane used for an angular search to find the orientation
with the minimal-area bounding rectangle. The Z axis is automatically adjusted to point upward (+Z world).
The object's pivot is moved to the centroid and rotated to the found coordinate system while the geometry remains stationary.

The script handles initially offset pivots correctly by precisely recalculating objectOffset parameters.

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