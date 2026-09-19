---
sidebar_position: 1
---

# Getting Started with Igneous

## What is Igneous?

Igneous is a small, modpack-driven FPS core for Roblox. The core owns four things:

- a **viewmodel** bound to the camera
- a **runtime stat layer** every value can be changed through
- named **resource pools** for ammo, reserve, mana, charges or heat
- **`Cast`**, which emits projectiles

Everything else is a modpack, including the ones Igneous ships with. Firing, reloading and aiming aren't privileged features of the engine; they're three modules in `Modpacks/` that register themselves onto weapons like any modpack you write.

That's what makes Igneous work for more than shooters. A bow, a spellcaster or a melee weapon doesn't have to fight an engine built around magazines and hitscan. It swaps out the parts it needs and keeps the rest.

Here are some quick links to get started:

- [**API**](/api/Igneous)
- [Installation guide](/docs/Installation)
- [Weapon Mods & Recipes](/docs/Runtime)
- [Templates](/docs/Templates)

## A minimal weapon

```lua
local Igneous = require(game.ReplicatedStorage.Packages.Igneous)

local Weapon = Igneous.new("AK47", ViewmodelTemplate, DataModule)

Weapon:Equip()
Weapon:SetFiring(true)   -- from the Firing modpack
Weapon:SetFiring(false)
Weapon:Reload()          -- from the Reloading modpack
Weapon:SetAiming(true)   -- from the Aiming modpack

Weapon:Destroy()         -- weapons hold a render connection; always destroy them
```

`SetFiring`, `Reload` and `SetAiming` are **extensions**, methods the standard modpacks add to every weapon with `Igneous.RegisterExtension`. Drop those modpacks and the methods disappear; write your own and yours appear alongside the core's.

## The four dispatch styles

How a hook behaves depends on how it's dispatched, not how it's written:

| Style | Who runs | Used for |
| --- | --- | --- |
| **Notify** (`Igneous.Trigger`) | every enabled modpack | `OnEquip`, `OnFire`, `OnProjectileFire` |
| **Veto** (`Igneous.Gate`) | every modpack until one returns `false` | `OnBeforeFire`, `OnBeforeReload` |
| **Accumulate** (`Igneous.Sum`) | every modpack, vectors summed | `OnCameraUpdate` |
| **Provide** (`Igneous.Provide`) | **only the highest-priority implementer** | `ResolveProjectile`, `GetSpread` |

The first three observe. The fourth replaces: a modpack implementing `ResolveProjectile` takes over how shots resolve, which is how you get travelling projectiles, melee arcs or hitbox queries without touching the core.

Your own modpacks can dispatch their own hook names through the same four functions. That's exactly how the standard modpacks talk to each other: Reloading blocks firing by vetoing Firing's `OnBeforeFire`, not by reaching into it.

## What the core actually reads

Just `Range`, `Projectiles`, `Lock`, `Offset` and `Resources`. Every other field in a Data module, whether that is `Cooldown`, `Firemode`, `Reload`, `Recoil` or your own `Damage` table, is read by whichever modpack cares about it, and all of it is mutable at runtime.
