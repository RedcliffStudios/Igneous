---
sidebar_position: 2
---

# Modpack Structure

Igneous uses modpacks to extend the functionality of your weapons.
Some examples may be a modpack that damages humanoids when a weapon is shot, or something purely visual like muzzle flashes, bullet holes, etc.

You can also store store assets inside of your modpack, for example instances, extra modules, etc.

Note: Although Igneous modpacks are supposed to be extremely portable, we do not recommend putting your server scripts inside your Modpack. Put your server scripts in ServerScriptService.

A template modpack can be found [here](https://github.com/RedcliffStudios/Igneous/blob/master/Modpacks/Template.luau), or you can see one here:

```lua
-- References to "Motus" can be removed if you don't animate the viewmodel
-- Or if you don't need the autocomplete (Not recommended)

local Motus = require(game.ReplicatedStorage.Packages.Motus)

local Modpack = {}

type Weapon = {
	Name: string,
	Viewmodel: Model,

	Animator: Motus.MotusAnimator,
}

function Modpack.OnEquip(weapon: Weapon)
	print(weapon.Name, "has been equipped")
end

function Modpack.OnUnequip(weapon: Weapon)
	print(weapon.Name, "has been unequipped")
end

function Modpack.OnFireStart(weapon: Weapon)
	print(weapon.Name, "has started firing")
end

function Modpack.OnFireEnd(weapon: Weapon)
	print(weapon.Name, "has stopped firing")
end

function Modpack.OnFire(weapon: Weapon, origin: { position: vector, direction: vector }, result: RaycastResult?)
	print(weapon.Name, "has fired at", origin)
	if result then
		print("..." .. "and has hit the part", result.Instance.Name, "at", result.Position)
	end
end

function Modpack.OnAmmoChange(weapon: Weapon, previous: number, current: number, reason: "reload" | "fired" | "set")
	print(weapon.Name, "has changed from", previous("bullets to"), current, "because a", reason, "happened")
end

return Modpack
```
