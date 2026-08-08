---
sidebar_position: 3
---

# Data Module Structure

A data module must be passed into `Igneous.new()` to give Igneous data about the weapon.

Here's how the data module must be structured:

```lua
return function()
	return {
		-- REQUIRED
		CanFire = true,

		Accuracy = 0.8,
		Range = 300,
		MaxSpread = 3,

		Ammo = 20,
		MaxAmmo = 20,
		Reserve = 100,

		Firemode = "Semi", -- "Semi" | "Auto" | "Burst"
		Cooldown = 0.1,
		Projectiles = 1,

		-- Pick ONE of the three Reload examples below and delete the other two 

		-- Simple example — waits Duration, then fills to Max in one transfer
		Reload = {
			Type = "Simple",
			Duration = 1.5,
			Cancellable = true,
		},

		-- Staged example (for multi-stage reloads such as mag out, mag in, bolt pull)
		Reload = {
			Type = "Staged",
			Stages = {
				{ Name = "MagOut", Duration = 0.4, Cancellable = true, CanFireAfter = false },
				{ Name = "MagIn", Duration = 0.6, Cancellable = true, AmmoTransfer = 30, CanFireAfter = false },
				{ Name = "BoltPull", Duration = 0.3, Cancellable = false, CanFireAfter = true },
			},
		},

		-- Progressive example (for shotguns, or other single-load weapons)
		Reload = {
			Type = "Progressive",
			Duration = 0.5,
			AmountPerCycle = 1,
			Cancellable = true,
		},

		AimSpeed = 0.7,
		CanReloadWhileAiming = false,
		CanAim = true,

		-- OPTIONAL, hardcoded support
		Lock = { X = true, Y = false, Z = false },
		Offset = vector.create(0, 0, 0),

		-- OPTIONAL EXAMPLES, not hardcoded
		DisplayName = "Name",
		Damage = { Torso = 50, Head = 80, Limbs = 20, Armor = 30 },
		Recoil = {
			Vertical = 2.1,
			Horizontal = 0.6,
		},
	}
end
```
