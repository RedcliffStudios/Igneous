<h1 align="center"><img src="Assets/logo/igneous.png" alt="Igneous Engine logo"/></h1>

<div align="center">
 <h1>Igneous Engine</h1>
 <p>Easy FPS framework for use in Redcliff Studios games that supports modpacks for further customization</p>
</div>

# Setting up Igneous Engine

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

## Methods and functions

TODO: CreateWeapon, Equip, Dequip, SetFiring, SetAim, Reload

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

## Functions

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