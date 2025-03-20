[Engilsh version](README_EN.md)
# Pankovea_MaxScriptsTools
Pankovea утилиты для работы в 3dsmax с аритектурной визуализацией

# Содержание
[usermacros/](usermacros/)
- [Albedo Tuner](#albedo-tuner) 
- [Camera Animator](#camera-animator)
- [Camera From View](#camera-from-view)
- [Concentric Cycles](#concentric-cycles)
- [Copy-Paste](#copy-paste)
- [Corona Toggles](#corona-toggles)
- [Crop To Atlas](#crop-to-atlas)
- [Distribute](#distribute)
- [Extract Instance](#extract-instance)
- [Instance All](#instance-all)

## Установка
1. Вариант через клонирование репозитория:
    - Зайдите в вашу папку `C:\Users\_USER_\AppData\Local\Autodesk\3dsMax\_MAX-version_\ENU` Замените `_USER_` вашим именем пользователя в операционной системе, `_MAX-version_` версией вашего 3dsmax
    - В строке адреса выполните `git clone https://github.com/Pankovea/Pankovea_MaxScriptsTools.git`
    - Запустите/перезапустите 3dsmax
    - Меню `Cutomize -> Cutomize user interface` -> `вкладка Toolbars -> group Main UI -> Category #PankovScripts` -> Перетащите нужный скрипт на панель 
2. Вариант со скачиванием отдельного скрипта
    - Скачайте нужный скприпт из папки usermacros и поместите его в папку `C:\Users\_USER_\AppData\Local\Autodesk\3dsMax\_MAX_version_\ENU\usermacros` В строке адреса замените _USER_ вашим именем пользователя в операционной системе, _MAX_version_ версией вашего 3dsmax <a name="#individual-icons-install"></a>
    - Если понадобится, то скачайте `usericons` и поместите их в папку `..\ENU\usericons`


## Albedo Tuner
[Версия 2022.02.27](usermacros/%23PankovScripts-Albedo%20Tuner.mcr)

Скрипт для коррекции параметра Albedo в материалах выделенных объектов. Изначально сделан для Corona render, но так же работает и в Vray (может работать не корректно)

Нужно для того чтобы понизить отражаемость материалов. Повышает контрастность изображения с помощью снижения отражённого потока света. Так можно настроить более естественное изобраение в сценах с высоким содержанием белых поверхностей.


## Camera Animator
[Версия 2024.07.06](usermacros/%23PankovScripts-CameraAnimator.mcr)

Скрипт создаёт анимированную камеру из выделенных камер в сцене

* Поддерживает: Standart camera, Vray camera, Corona camera
* Если выделена анимированная камера, то можно запустить скрипт с нажатой клавишей Shift. Это действие произведёт обратную операцию, создаст камеры из кадров анимации


## Camera From View
[Версия 2024.07.06](usermacros/%23PankovScripts-CameraFromView.mcr)

Создаст камеру из перспективного вида в зависимости от используемого рендера Vray или Corona


## Concentric Cycles
[Версия 2024.10.12](usermacros/%23PankovScripts-ConcentricCircles.mcr)

Скрипт создаёт изменяемый объект с концентрическими окружностями с заданными параметрами

Возможности:
* объект создаётся в начале координат или в центре выделенного объёма бордюрной коробки (boundibg box)
* объекту назначаются персонализированные параметры (custom attributes), которые потом используются для изменения объекта
* если выделен один такой объект, то при открытии скрипта загружаются текующие параметры объекта. ри изменении параметров объект будет изменён
* если выделено нескоклько объектов, то параметры будут применены сразу ко всем обхектам (только ConcentricCycles)
* случае неверного задания параметров есть возможность отменить действие стандартным способом.


## Copy-Paste
[Версия 2024.11.19](usermacros/%23PankovScripts-CopyPaste.mcr)

Добавляет кнопки копирования и вставки объектов между различнми проектами/окнами 3dsmax

Можно назначить быстрые клавиши через меню: `Customize -> Hotkey Editor -> найти Copy-Paste action -> Assign hotkey`

В случае с индивидуальной установкой требуется скопировать иконки [1](usericons/pankov_CopyPaste_24i.bmp) и [2](usericons/pankov_CopyPaste_16i.bmp) в папку `usericons` настроек вашего 3dsmax ([см. Установка п.2](#установка))

## Corona Toggles
[Версия 2024.07.05](usermacros/%23PankovScripts-CoronaToggles.mcr)

Выносит на панель быстрые настройки Corona Render
Включает в себя:
* Standart Region Render Toggle
* Standart BlowUp Render Toggle
* Corona Render Selected Toggle. Также отключает/включает настроку `clear Between Renders`
* Corona Distributed Render Toggle
* Corona Denoise on Render Toggle
* Corona Render Mask Only Toggle

В случае с индивидуальной установкой требуется скопировать иконки [1](usericons/PankovScripts_24i.bmp) и [2](usericons/PankovScripts_16i.bmp) в папку `usericons` настроек вашего 3dsmax ([см. Установка п.2](#установка))


## Crop To Atlas
Скрипт используется совместно с бесплатной версией программы [TexturePacker](https://www.codeandweb.com/texturepacker)

С помощью программы можно создать Атлас текстур, уменьшив при этом количество ассетов. Это делается в случае использования декора, который использует множество мелких текстур. Их можно уменьшить и объединить в один файл. После Воспользоваться данным скриптом, который поменят ссылки в материалах на новый файл и сделет корректую обрезку.

* Работает с Bitmap и CoronaBitmap 


## Distribute
[Версия 2025.03.20](usermacros/%23PankovScripts-Distribute.mcr)

Скрипт для рапределения в пространстве

Особенности:
* Работает в режиме объектов и в режиме подобъектов. 
(пока реализовано только выравнивание вершин в EditableSpline, EditaplePoly, и модификатор EditPoly.
В модификаторе EditSpline не работает)

* объекты распределяет равномерно, учитывая размер объекта, сохраняя одинаковое расстояние между объектами.
* Автоматически определяет первый и последний объекты, как наиболее далённые друг от друга в пространстве
* Распределяет группированные объекты (определяет родителькие объекты и оперирует ими)
* для запуска необходимо находиться в нужном режиме выделения.
* В режиме подобъектов группирует выделенные грани и оперирует ими как объектами, учитывая их размер.
  Вершины распределяются каждая в одельности.

## Extract Instance
[версия 2024.07.10](usermacros/%23PankovScripts-ExtractInstance.mcr)

Извлекает объект instance из объекта reference
Просто выделите объект reference и запустите макроскрипт

В случае с индивидуальной установкой требуется скопировать иконки [1](usericons/pankov_instancseAll_24i.bmp) и [2](usericons/pankov_instancseAll_16i.bmp) в папку `usericons` настроек вашего 3dsmax ([см. Установка п.2](#установка))


## Instance All
[версия 2024.10.17](usermacros/%23PankovScripts-InstanceAll.mcr)

Скрипт для замены объектов инстансами и рефернесами

В случае с индивидуальной установкой требуется скопировать иконки [1](usericons/pankov_instancseAll_24i.bmp) и [2](usericons/pankov_instancseAll_16i.bmp) в папку `usericons` настроек вашего 3dsmax ([см. Установка п.2](#установка))

Возможности:
* Замена любого объекта инстансом выбранного объекта
путём создания инстанса и применения исходных трансформаций, слоя, и материала в зависимости от настроек.
То есть, если были выделены часть инстансов, то невыделенная чать заменена не будет.
* При замене большого количества объектов (>100) отображается прогресс бар

1. Группа `Make Instances`
    * Может клонировать инстансом как отжельные обекты, так и сгруппированные объекты
    * Может подогнать размер нового инстанса под размер заменяемых обхектов

2. Группа `Get instance part from refetence object`
Извлекает базовый объект (нижний в теке модификаторов) и заменяет им выделенные объекты.
При этом не создаётся новых объектов и все зависимоти в сцене сохраняются.
    * Так же может заменить весь стек модификаторов
