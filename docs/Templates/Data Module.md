---
sidebar_position: 3
---

# Data Module Structure

A data module must be passed into `Igneous.new()`. It returns a *function* that returns the table, so every weapon built from it gets its own copy.

The whole table is deep-copied into the weapon's [runtime state](/docs/Runtime), so **every field below is mutable at runtime**, including fields the core has never heard of.

## What reads what

The core only interprets five keys. Everything else belongs to a modpack, and is only meaningful if you have that modpack loaded.

| Key | Read by |
| --- | --- |
| `Range`, `Projectiles`, `Lock`, `Offset`, `Resources` | the core |
| `Firemode`, `Cooldown`, `CanFire`, `BurstCount`, `BurstCooldown` | Firing |
| `Reload`, `CanReloadWhileAiming` | Reloading |
| `CanAim`, `AimSpeed` | Aiming |
| `Accuracy`, `MaxSpread` | the core's default spread, or your `GetSpread` provider |
| `Recoil` | Recoil |
| anything else | you |

## A standard gun

```lua
return function()
	return {
		-- CORE
		Range = 300, -- Stud length of each cast
		Projectiles = 1, -- Rays per shot; raise it for shotguns

		Resources = {
			Ammo = { Amount = 20, Max = 20 },
			Reserve = { Amount = 100, Max = math.huge },
		},

		Lock = { X = true, Y = false, Z = false }, -- Optional: freeze viewmodel rotation
		Offset = vector.create(0, 0, 0), -- Optional: position offset from the camera

		-- FIRING MODPACK
		CanFire = true,
		Firemode = "Semi", -- Any registered firemode: Semi, Burst, Auto, or your own
		Cooldown = 0.1,
		BurstCount = 3, -- Burst only, defaults to 3
		BurstCooldown = 0.3, -- Burst only, defaults to Cooldown

		-- SPREAD
		Accuracy = 0.8, -- 0 = full MaxSpread, 1 = pinpoint
		MaxSpread = 3, -- Cone half-angle in degrees at Accuracy = 0

		-- AIMING MODPACK
		CanAim = true,
		AimSpeed = 0.7,
		CanReloadWhileAiming = false,

		-- RELOADING MODPACK -- pick ONE of the three shapes
		Reload = {
			Type = "Simple",
			Duration = 1.5,
			Cancellable = true,
		},

		-- Staged (mag out, mag in, bolt pull)
		Reload = {
			Type = "Staged",
			Stages = {
				{ Name = "MagOut", Duration = 0.4, Cancellable = true, CanFireAfter = false },
				{ Name = "MagIn", Duration = 0.6, Cancellable = true, AmmoTransfer = 30, CanFireAfter = false },
				{ Name = "BoltPull", Duration = 0.3, Cancellable = false, CanFireAfter = true },
			},
		},

		-- Progressive (shotguns and other single-load weapons)
		Reload = {
			Type = "Progressive",
			Duration = 0.5,
			AmountPerCycle = 1,
			Cancellable = true,
		},

		-- RECOIL MODPACK
		-- Vertical and Horizontal are the peak kick in degrees.
		Recoil = { Vertical = 2.1, Horizontal = 0.6, SmoothTime = 0.18 },

		-- MODPACKS -- optional
		-- Omit it and every registered modpack runs for this weapon. Provide it and only
		-- the modpacks named here do.
		Modpacks = { "Firing", "Reloading", "Aiming", "Recoil", "BulletHoles" },

		-- YOURS -- not interpreted by anything, read with GetData/GetStat
		DisplayName = "Name",
		Damage = { Torso = 50, Head = 80, Limbs = 20 },
	}
end
```

### The ammo shorthand

Weapons written before resources existed still work. If you give `Ammo`, `MaxAmmo` and `Reserve` instead of a `Resources` table, the core builds the two pools from them:

```lua
Ammo = 20,
MaxAmmo = 20,
Reserve = 100,
```

is exactly equivalent to the `Resources` block above. Use whichever reads better; `Resources` is the one that scales to a weapon with more than one pool.

## A weapon that isn't a gun

Nothing above is required. A melee weapon defines almost none of it, with no reload, no ammo and no spread, and relies on a modpack providing `ResolveProjectile` to resolve a swing as a short arc instead of a ray:

```lua
return function()
	return {
		Range = 8,
		Projectiles = 1,

		Firemode = "Semi",
		Cooldown = 0.45,

		Resources = {
			Stamina = { Amount = 100, Max = 100 },
		},

		Modpacks = { "Firing", "MeleeArc" },

		SwingCost = 15,
		Damage = { Torso = 65 },
	}
end
```

A bow adds a charge firemode and an arrow pool:

```lua
return function()
	return {
		Range = 500,
		Projectiles = 1,

		Firemode = "Charge", -- Registered with Firing.RegisterFiremode
		Cooldown = 0.2,
		MaxCharge = 1.5,

		Resources = {
			Ammo = { Amount = 1, Max = 1 },
			Reserve = { Amount = 24, Max = 24 },
		},

		Reload = { Type = "Progressive", Duration = 0.6, AmountPerCycle = 1, Cancellable = true },
		Modpacks = { "Firing", "Reloading", "ArrowProjectile" },
	}
end
```

Both are covered in [Weapon Mods & Recipes](/docs/Runtime).

## Notes

- **`Projectiles` vs `BurstCount`.** `Projectiles` is how many rays one shot casts, so a burst shotgun is `Firemode = "Burst"`, `BurstCount = 3`, `Projectiles = 8`.
- **`CanFire` is a switch, not a cooldown.** Setting it false disables the weapon until something sets it back; the fire rate is `Cooldown`, and it can't be bypassed by releasing and re-pulling the trigger.
- **Listing `Modpacks` is opt-in, not opt-out.** A weapon that names `{ "BulletHoles" }` and forgets `"Firing"` has no `SetFiring` behaviour, because the modpack that provides it was excluded.
