[на Русском](README.md)
# Pankovea_MaxScriptsTools
Pankovea utilities for working in 3dsmax with architectural visualization

# Content
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
- [Reset ModContextTM](#Reset-ModContextTM)

[scripts/](scripts/)
- [Simplify-Spline-by-Remove-Selected-Vertices](#simplify-spline-by-remove-selected-vertices)
## Installation
1. Option via repository cloning:
    - Go to your folder `C:\Users\_USER_\AppData\Local\Autodesk\3dsMax\_MAX-version_\ENU ` Replace `_USER_` with your operating system username, `_MAX-version_` with your 3dsmax version
    - In the address bar, run `git clone https://github.com/Pankovea/Pankovea_MaxScriptsTools.git `
    - Start/restart 3dsmax
    - Menu `Cutomize -> Cutomize user interface` -> `Toolbars tab -> group Main UI -> Category #PankovScripts` -> Drag the desired script to the panel 
2. The option of downloading a separate script
    - Download the required script from the usermacros folder and place it in the folder `C:\Users\_USER_\AppData\Local\Autodesk\3dsMax\_MAX_version_\ENU\usermacros ` In the address bar, replace _USER with your operating system username, _MAX_version_ with your 3dsmax version <a name="#individual-icons-install"></a>
    - If necessary, download `usericons` and put them in the folder `..\ENU\usericons`

## Simplify Spline by Remove Selected Vertices
[Version 2025.04.01 - alpha](/scripts/Simplify-Spline-by-Remove-Selected-Vertices.ms)

Script to simplify splines. The base EditableSpline or Line object is required. The modifier won't work.

* If vertices are selected, it deletes a group of consecutive vertices and strives to restore the shape.
* If splines are selected, it determines which vertices can be deleted and deletes them. (This mode is experimental)

To work, you need [Matrix.ms ](/scripts/Matrix.ms) in the script folder. [Matrix docs](/docs/Matrix.ms_EN.md)

You need to select the vertices to be deleted in the spline (not in the modifier) and run run_simplifySpline().
I'm still trying to figure out how to format the macro script.

Does not process extreme vertices. You will not be able to delete the first and last in a closed spline.
There are also problems if the vertices are angular. They should all have guides in this implementation.

## Albedo Tuner
[Version 2022.02.27](usermacros/%23PankovScripts-Albedo%20Tuner.mcr)

A script for correcting the Albedo parameter in the materials of selected objects. Originally made for Corona render, but it also works in Vray (it may not work correctly)

It is necessary in order to reduce the reflectivity of materials. Increases the contrast of the image by reducing the reflected light flux. This way you can set up a more natural image in scenes with a high content of white surfaces.


## Camera Animator
[Version 2024.07.06](usermacros/%23PankovScripts-CameraAnimator.mcr)

The script creates an animated camera from the selected cameras in the scene

* Supports: Standart camera, Vray camera, Corona camera
* If an animated camera is highlighted, you can run the script with the Shift key pressed. This action will perform the reverse operation, create cameras from animation frames


## Camera From View
[Version 2024.07.06](usermacros/%23PankovScripts-CameraFromView.mcr)

It will create a camera from a perspective view, depending on the Vray or Corona render used


## Concentric Cycles
[Version 2024.10.12](usermacros/%23PankovScripts-ConcentricCircles.mcr)

The script creates a modifiable object with concentric circles with the specified parameters

Features:
* the object is created at the origin or in the center of the selected volume of the border box (boundibg box)
* the object is assigned personalized parameters (custom attributes), which are then used to change the object
* if one such object is selected, the corresponding object parameters are loaded when the script is opened. if you change the parameters, the object will be changed
* if only a few objects are selected, the parameters will be applied to all objects at once (only ConcentricCycles)
* if the parameters are set incorrectly, it is possible to cancel the action in the standard way.


## Copy-Paste
[Version 2025.03.20](usermacros/%23PankovScripts-CopyPaste.mcr)
### Working with objects

Adds buttons for copying and pasting objects between different 3dsmax projects/windows
You can assign keyboard shortcuts via the menu: `Customize -> Hotkey Editor -> find Copy-Paste action -> Assign hotkey'.
For example, I have Alt+C and Alt+V.

In the case of an individual installation, you need to copy the icons [1](usericons/pankov_CopyPaste_24i.bmp) and [2](usericons/pankov_CopyPaste_16i.bmp) to the `usericons` folder of your 3dsmax settings ([see Installation of item 2](#installation))
### Working with modifiers
A macro script for assigning keyboard shortcuts. It has no icons.
Instead of selecting with the mouse -> right-> select copy modifier in the menu, then do the same for pasting.
You can use the keyboard shortcuts: `Customize -> Hotkey Editor -> find Copy-Paste Modifier action -> Assign hotkey'.
For example, I have Ctrl+Shift+C and Ctrl+Shift+V, which is very convenient. (but you will have to remove the quick button from Chamfer Mode on EditSpline and EditPoly)

Useful features:
* You can insert a modifier on several selected objects at once. It will be inserted by the instance.
* The EditPoly and EditSpline modifiers are inserted without local data.
  In other words, the instance remains connected to change a group of objects, but the other object does not break.

## Corona Toggles
[Version 2024.07.05](usermacros/%23PankovScripts-CoronaToggles.mcr)

Displays the quick settings of Corona Render on the panel
Includes:
* Standart Region Render Toggle
* Standart BlowUp Render Toggle
* Corona Render Selected Toggle. Also disables/enables the `clear Between Renders` setting
* Corona Distributed Render Toggle
* Corona Denoise on Render Toggle
* Corona Render Mask Only Toggle

In the case of an individual installation, you need to copy the icons [1](usericons/PankovScripts_24i.bmp) and [2](usericons/PankovScripts_16i.bmp) to the `usericons` folder of your 3dsmax settings ([see Installation of item 2](#installation))


## Crop To Atlas
The script is used in conjunction with the free version of the [TexturePacker](https://www.codeandweb.com/texturepacker) program

Using the program, you can create an Atlas of textures, while reducing the number of assets. This is done in the case of using a decor that uses many small textures. They can be reduced and combined into a single file. After that, use this script, which will change the links in the materials to a new file and make the correct cropping.

* Works with Bitmap and CoronaBitmap 


## Distribute
[Version 2025.09.04](usermacros/%23PankovScripts-Distribute.mcr)

The script for the distribution in space

Features:
* Works in Object mode and in subobject mode. 
Has been implemented in all subobjects EditableSpline, EditablePoly, and the EditPoly modifier.
The EditSpline modifier does not work)

* distributes objects evenly, taking into account the size of the object in such a way that the distance between them is the same
(you need to refine the pivot offset from the center and the accuracy of sizing. Now the size is determined by the Bounding box)
* Automatically detects the first and last objects by the largest distance between them.
* works if the modifier is imposed by the instance on several objects (#FIXME is not working correctly in max2025 yet)
* * Distributes grouped objects

* To start, you must be in the desired selection mode.

## Link material
[Version 2025.03.20](usermacros/%23PankovScripts-LinkMaterial.mcr)

The idea is taken from Blender.
With a quick click, you can quickly take material from a nearby object. 
Assign keyboard shortcuts in: `Customize -> Hotkey Editor`
* `Link material` -> Assign hotkey **Ctrl+L**
* `Select by material` -> Assign hotkey` **Ctrl+Shift+L**

The principle is this:
* Link material: First, you need to select all the objects to assign the matrix, and at the end, select the object from which you want to take a sample of the material and press the keyboard shortcut.
* Select by material: Select an object and press a keyboard shortcut. I will highlight all objects in the field of view that have the same material.(s)

## Extract Instance
[version 2024.07.10](usermacros/%23PankovScripts-ExtractInstance.mcr)

Retrieves the instance object from the reference object
Just select the reference object and run the macro script.

In the case of an individual installation, you need to copy the icons [1](usericons/pankov_instancseAll_24i.bmp) and [2](usericons/pankov_instancseAll_16i.bmp) to the `usericons` folder of your 3dsmax settings ([see Installation of item 2](#installation))


## Instance All
[version 2024.10.17](usermacros/%23PankovScripts-InstanceAll.mcr)

The script for replacing objects with instances and references

In the case of an individual installation, you need to copy the icons [1](usericons/pankov_instancseAll_24i.bmp) and [2](usericons/pankov_instancseAll_16i.bmp) to the `usericons` folder of your 3dsmax settings ([see Installation of item 2](#installation))

Features:
* Replacing any object with an instance of the selected object
by creating an instance and applying the original transformations, layer, and material, depending on the settings.
That is, if some instances were allocated, then the unallocated part will not be replaced.
* When replacing a large number of objects (>100), the progress bar is displayed

1. The `Make Instances` group
* Can clone both parallel objects and grouped objects with an instance
* Can adjust the size of the new instance to the size of the objects being replaced

2. The `Get instance part from reference object` group
Retrieves the base object (the lower one in the modifier stack) and replaces the selected objects with it.
At the same time, no new objects are created and all dependencies in the scene are saved.
* It can also replace the entire stack of modifiers.

## Reset ModContextTM
[version 2025.03.20](usermacros/%23PankovScripts-ResetModContextTM.mcr)

Resets the transformation matrix in the context of the modifier to the state as if the modifier had just been applied to objects or a single object.

Reference:

Each modifier has a so-called transformation context. For example, if we applied a modifier to one object, then the transformation context will be zero, but if the modifier is applied to several objects at once, then the transformation point is placed in the center of the objects' masses. So the modifier will act the same way on objects in the virtual space, but each object will have its own context. And if we shift the objects, we will see that the context is tied to local coordinates. This script is for such cases. After the objects are shifted, place the context again at one point in world coordinates. 

Features:
* Works with a dedicated modifier in the modifier stack
* when Shift is pressed, resets ModContextBBox for each object individually
* when Esc is pressed, Gizmo resets
* when changing the transformation point, it is not possible to keep the object in its original position
.:
* undo does not work

### Macro script Pankov_Copy_ModContextTM
Copies and inserts the transformation matrix for the modifier, preserving its global position as in the original object.

This is a good way to combine the context of modifiers by adjusting only one of them and not changing all the others (unlike the previous script).