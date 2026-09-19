---
sidebar_position: 2
---

# Modpack Structure

Modpacks are where nearly everything in Igneous lives. The core gives you a weapon bound to the camera with stats, resources and `Cast`; firing, reloading, aiming, recoil and effects are all modpacks on top of it, including the ones Igneous ships with.

Place modpack modules in `ReplicatedStorage.Modpacks` and they're registered automatically. Each hook is optional; only implement the ones you need.

Note: although Igneous modpacks are meant to be extremely portable, we do not recommend putting your server scripts inside a modpack. Put those in ServerScriptService.

## How modpacks are wired up

- **Registration.** Every ModuleScript inside `ReplicatedStorage.Modpacks` is registered one frame after Igneous first loads, and anything added to the folder later is picked up automatically. Modpacks elsewhere can be added with `Igneous.RegisterModpack(module)`.
- **Scope.** By default a modpack runs for every weapon. A weapon whose Data lists `Modpacks = { "Firing", "Recoil" }` only sees the modpacks it names, matched against each modpack's `Name` field (or its ModuleScript name).
- **Order.** Modpacks are dispatched highest `Priority` first, defaulting to 0, ties broken by registration order. Priority decides who wins a provider hook and who gets to veto first.
- **Failure.** A hook that errors is caught and warned about. One broken modpack can't take down the frame or leave a weapon stuck mid-shot.
- **Per-weapon state.** Hooks are plain functions shared by every weapon, so anything belonging to one weapon goes in `weapon:GetState("YourModpackName")`. That table is created on first use and dropped when the weapon is destroyed.

## The four dispatch styles

```lua
Igneous.Trigger(weapon, "OnSomething", ...)          -- notify: everyone runs
local allowed = Igneous.Gate(weapon, "OnBefore", …)  -- veto: stops at first false
local total = Igneous.Sum(weapon, "OnCamera", dt)    -- accumulate: vectors summed
local ok, value = Igneous.Provide(weapon, "Hook", …) -- provide: highest priority only
```

Your own modpacks can dispatch their own hook names through these, which is how the standard modpacks cooperate without depending on each other. Reloading blocks firing like this:

```lua
function Modpack.OnBeforeFire(weapon)
	return not GetReloadState(weapon).IsFireLocked
end
```

Firing calls `Igneous.Gate(weapon, "OnBeforeFire")` and never learns that reloading exists.

## Provider hooks

`ResolveProjectile` and `GetSpread` are **provider** hooks: only the highest-priority modpack implementing one runs, and it owns the answer outright. There is no abstaining, since implementing one is claiming it.

The Firing modpack claims `ResolveProjectile` to supply the default hitscan, and deliberately sits at `Priority = -100` so **any resolver you write outranks it just by existing**. A weapon listing `{ "Firing", "MeleeArc" }` fires with Firing's trigger machinery but resolves with MeleeArc's arc, with no priority juggling on your part. Two custom resolvers on one weapon is the case to avoid, so pick one.

Replacing hitscan with a spherecast melee arc is the whole of a melee weapon:

```lua
function Modpack.ResolveProjectile(weapon, origin, context)
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = weapon:GetIgnored()
	return workspace:Spherecast(origin.position, weapon:GetStat("ArcRadius", 3), origin.direction, Params)
end
```

Controlling the pattern of a shotgun is the whole of `GetSpread`. The index and count let you build deterministic patterns rather than random ones:

```lua
function Modpack.GetSpread(weapon, index, count)
	local Angle = (index / count) * math.pi * 2
	local Radius = math.rad(weapon:GetStat("RingSpread", 2))
	local Offset = workspace.CurrentCamera.CFrame:VectorToWorldSpace(
		Vector3.new(math.cos(Angle) * Radius, math.sin(Angle) * Radius, 0)
	)
	return vector.create(Offset.X, Offset.Y, Offset.Z)
end
```

Without a `GetSpread` provider the core falls back to a uniform random cone. Without a `ResolveProjectile` provider **nothing resolves at all**. The core does no casting of its own, so a weapon that has neither the Firing modpack nor a resolver of its own still emits geometry and still raises `OnProjectileFire`, but always with a nil result. It warns once when that happens.

## Extensions

Modpacks add methods to every weapon with `Igneous.RegisterExtension`. This is why `weapon:SetFiring(true)` works even though firing isn't in the core:

```lua
Igneous.RegisterExtension("Inspect", function(weapon)
	weapon.Animator:Play("Inspect")
end)

Weapon:Inspect()
```

The handler takes the weapon as its first argument, so it's called as a method. Registering a name that already exists is refused with a warning, so a modpack can't silently clobber the core or another modpack.

For autocomplete, extend the type yourself:

```lua
type MyWeapon = Types.StandardWeapon & { Inspect: (self: Types.Weapon) -> () }
```

## Firemodes

The Firing modpack keeps a firemode registry. Semi, Burst and Auto are registered there and have no special status, so yours sit alongside them:

```lua
local Firing = require(game.ReplicatedStorage.Modpacks.Firing)

Firing.RegisterFiremode("Charge", function(weapon, trigger)
	local Held = 0
	while trigger:IsHeld() and Held < weapon:GetStat("MaxCharge", 1.5) do
		Held += trigger:Wait()
	end

	trigger:Fire(nil, { Charge = Held })
end)
```

A handler gets the weapon and a [Trigger](/api/Igneous): `IsHeld()` reports whether the player is still holding, `Wait()` yields and returns elapsed time, and `Fire()` spends a round and casts, returning `false` when the shot couldn't happen. **Always stop on a false return.** That is what keeps a firemode from spinning when the weapon is empty, reloading or vetoed.

The context table passed to `Fire` reaches `OnBeforeFire`, `OnFire`, the spread provider, the resolver and `OnProjectileFire`, so a charge level or a pellet seed can travel with the shot.

## Template

A template modpack can be found [here](https://github.com/RedcliffStudios/Igneous/blob/master/Modpacks/Template.luau). It lists every hook grouped by who dispatches it, since only the core's group fires unconditionally. The rest depend on having those modpacks loaded.

Requiring Igneous's `Types` module gives you autocomplete on the weapon passed to each hook. It contains only type definitions, so it costs nothing at runtime:

```lua
local Types = require(game.ReplicatedStorage.Packages.Igneous.Types)

type Weapon = Types.Weapon
```

## Bundled modpacks

| Modpack | What it adds |
| --- | --- |
| **Firing** | `SetFiring`, `IsFiring`, the ammo helpers, the firemode registry, Semi/Burst/Auto, and the default hitscan resolver |
| **Reloading** | `Reload`, `CancelReload`, `IsReloading`, the three reload shapes |
| **Aiming** | `SetAiming`, `IsAiming` and the aim hooks |
| **Recoil** | Spring-driven camera kick from `Recoil` data |
| **BulletHoles** | Decals stamped on hit surfaces |

Firing, Reloading and Aiming are ordinary modpacks. Delete them, replace them, or ignore them for a weapon by leaving them out of its `Modpacks` list.
