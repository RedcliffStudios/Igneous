<h1 align="center"><img src="Assets/logo/full.png" alt="Igneous Engine logo"/></h1>

<div align="center">
 <h1>Igneous Engine</h1>
 <p>Easy FPS framework for use in Redcliff Studios games that supports modpacks for further customization</p>
</div>

## ⚠️ WARNING ⚠️

This documentation is very very unfinished. Most of the documentation needs new functions/methods and more details.

# Setting up Igneous Engine

## Prerequisites

> Igneous Engine requires 2 packages:
>
> - [`Spring = "sleitnick/spring@1.0.0"`](https://sleitnick.github.io/RbxUtil/api/Spring/)
> - [`Trove = "sleitnick/trove@1.5.1"`](https://sleitnick.github.io/RbxUtil/api/Trove/)

## Adding the main module

> Insert the [main module](Source/Igneous.luau) somewhere the client can access for example in `ReplicatedStorage`
 Require it inside the script you will use to control your weapons
>
> ```lua
> local Igneous = require(game.ReplicatedStorage.Igneous)
>```

## Adding Modpacks

> Inside `ReplicatedStorage` ensure you have a folder named `IgneousModpacks`
 That folder will store all of your modpacks.
 To add a modpack, just insert the folder into `IgneousModpacks`
 All modpacks will automatically be managed by the main module once it has been required

## Optional: Essential Modpacks

TODO: BulletHoles and Damage modpacks

# Using Igneous Engine

## Functions

TODO: CreateWeapon, Equip, Dequip, SetFiring, SetAim, Reload

# Weapons

## Folder Structure

> Weapons must contain 3 things inside its folder:
>
> - A viewmodel
> - A data module
> - A function module
>
> Here is an example of the structure of a weapon:
>
> ```text
>ReplicatedStorage
>└── Weapons
>    └── Glock17
>        ├── Viewmodel
>        ├── Data
>        └── Module
>```
>
> Examples of the modules:
>
> - [Data](Source/Templates/Weapon/Data.luau)
> - [Function](Source/Templates/Weapon/Module.luau)

## Viewmodel Structure

> Viewmodels must contain a primary part and an Animation Controller with an Animator inside (soon Igneous Engine will support humanoid viewmodels)
> The primary part is what binds to the camera, and should have welds/joints to all parts of the viewmodel.
> Heres an example of the structure of a viewmodel:
>
>```text
>Viewmodel
>├── HumanoidRootPart (Primary Part)
>└── AnimationController
>    └── Animator

# Creating modpacks

## Structure

> Modpacks always need a `Main.luau` module script inside. This module is what Igneous Engine sends data to and should handle the modpack.
> Here is an example of the structure of a modpack:
>
> ```text
>ReplicatedStorage
>└── IgneousModpacks
>    └── Modpack
>        ├── Main.luau
>        ├── Server.server.luau
>        ├── Resources
>        └── Events
> ```
>
> Folders and scripts like `Resources`, `Events`, and `Server.server.luau` are optional, only add scripts and items that are needed by the modpack to function properly.

## Methods

> Every modpack requires 2 functions to work properly, even if they are empty, which are:
>
> ```lua
>
> local Modpack = {}
>
>function Modpack.Fire(Coordinate: { Origin: vector, Direction: vector }, Raycast: RaycastResult, Data: {}) end
>
>function Modpack.Reload(Data: {}, Animation: AnimationTrack) end
>
>return Modpack
>
>```
>
>`function Modpack.Fire()` is activated every time the weapon is fired, and it sends the Coordinate, Raycast Result and Weapon Data as parameters for use in the modpack.
>
>`function Modpack.Reload()` is activated every time the weapon is reloaded, and it sends the Weapon Data, and Reload Animation Track as parameters for use in the modpack.