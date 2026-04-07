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
- [Paste Image Reference To Plane](#paste-image-reference-to-plane)


[scripts/](scripts/)
- [Simplify Spline by Remove Selected Vertices](#simplify-spline-by-remove-selected-vertices)

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
This script works with the free TexturePacker tool (https://www.codeandweb.com/texturepacker).

Use TexturePacker to create a texture atlas and reduce asset count for many small decoration textures. Then run this script to update material bitmap references to the atlas and adjust cropping accordingly.

* Works with Bitmap and CoronaBitmap.

[back (contents)](#contents)

## Distribute
[Version 2025.12.07](usermacros/%23PankovScripts-Distribute.mcr)

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