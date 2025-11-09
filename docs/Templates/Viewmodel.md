---
sidebar_position: 1
---

# Viewmodel Structure

An Igneous Viewmodel must contain 3 items to function properly:

1. A Primary Part
   - The viewmodel must be a Model instance
   - The primary part is where the viewmodel will bind to the camera
2. An Animator
   - Igneous animates your viewmodels using [Motus](https://redcliffstudios.github.io/Motus)
3. A data module
   - The data module stores the base/template data for the weapon, for example the ammo data, firemode, etc

Here is an example of a data module:

```lua
-- Viewmodel/Data.luau
return {

	-- REQUIRED

	CanFire = true,

	Accuracy = 0.8,
	Range = 300,
	MaxSpread = 3,

	Ammo = 20,
	MaxAmmo = 20,
	Reserve = 100,

	Firemode = "Semi",
	Cooldown = 0.1,
	Projectiles = 1,

	Recoil = {
		Vertical = 2.1,
		Horizontal = 0.6
	},

	AimSpeed = 0.7,
	CanReloadWhileAiming = false,
	CanAim = true,

	-- OPTIONAL (You can add any sort of data that might fit your needs)

	DisplayName = "Name",

	Damage = {
		Torso = 50,
		Head = 80,
		Limbs = 20,
		Armor = 30
	},
}
```

Note: Reloading, ammo manipulation and aiming are features that are not currently implemented. It will be added in the future.
