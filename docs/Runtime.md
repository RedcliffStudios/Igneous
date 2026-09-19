---
sidebar_position: 3
---

# Weapon Mods & Recipes

Every weapon carries two layers:

- **Data**: what its Data module returned. Authored, never mutated, always readable with `GetData()`.
- **Runtime**: a deep copy of that entire table, made at creation and rewritten freely afterwards.

Everything reads the runtime layer. That's what makes attachments, perks and weapon mods possible: change the runtime layer and the next shot uses the new numbers, with the authored Data still intact underneath.

## Changing stats

```lua
Weapon:SetRuntime({
	Accuracy = 0.95,
	Firemode = "Auto",
	Cooldown = 0.07,
	Range = 450,
	Damage = { Torso = 40, Head = 95 },
})
```

Because the runtime layer starts as a copy of the *whole* Data table, there's no allowlist. The core's `Range`, a modpack's `Cooldown`, and your own `Damage` are all equally writable. Keys the weapon never defined can be added too.

Reading comes in two shapes:

```lua
local Everything = Weapon:GetRuntime()          -- deep copy, safe to mutate, costs a copy
local Cooldown = Weapon:GetStat("Cooldown", 0)  -- one value, no copy, with a default
```

`GetStat` is what modpacks should use on hot paths. The default argument is what makes stats optional, so a melee weapon that never defines `Cooldown` still works because Firing asks for `weapon:GetStat("Cooldown", 0)`.

A Lua table cannot hold a nil value, so `SetRuntime({ Lock = nil })` is an empty table and does nothing. Pass `Igneous.None` to clear a key:

```lua
Weapon:SetRuntime({ Lock = Igneous.None })
```

## An attachment, end to end

```lua
local Suppressor = {
	Accuracy = 0.05, -- Additive modifiers over the base weapon
	Range = -40,
}

local function ApplyAttachment(weapon, attachment)
	local Base = weapon:GetData() -- The authored values, unaffected by other mods
	local Changes = {}

	for Key, Delta in attachment do
		Changes[Key] = Base[Key] + Delta
	end

	weapon:SetRuntime(Changes)
end
```

Computing against `GetData()` rather than `GetRuntime()` makes attachments removable and non-cumulative, so reapplying one twice doesn't stack.

## Resources

Ammo isn't special. A weapon has named pools, each a current value and a ceiling:

```lua
Weapon:HasResource("Ammo")                            --> true
Weapon:GetResource("Ammo")                            --> { Amount = 20, Max = 30 }
Weapon:SetResource("Mana", 40, "spell")
Weapon:AddResource("Heat", 12, "shot")
Weapon:TransferResource("Reserve", "Ammo", 30, "reload")
```

Every change raises `OnResourceChange(weapon, name, previous, current, reason)`. Reloading is just a transfer from `Reserve` into `Ammo`; so is spending mana to refill charges.

`GetResource` hands back an empty pool for anything the weapon does not define, so use `HasResource` when the difference between "no ammo pool" and "out of ammo" matters. Firing does exactly that, which is why a melee weapon with only a Stamina pool can still swing.

The Firing modpack adds the familiar shorthand over the `Ammo` and `Reserve` pools:

```lua
Weapon:GetAmmo()      --> { Amount = 20, Max = 30, Reserve = 90 }
Weapon:SetAmmo(30)
Weapon:AddReserve(60)
```

and re-raises ammo changes as `OnAmmoChange(weapon, previous, current, reason)` for the common case.

## Recipes

### Spread bloom

Accuracy is a runtime value, so bloom is a modpack that tightens and loosens it.

```lua
local BLOOM_PER_SHOT = 0.06
local RECOVERY_PER_SECOND = 0.35

function Modpack.OnEquip(weapon)
	weapon:GetState("Bloom").Base = weapon:GetStat("Accuracy", 1)
end

function Modpack.OnFire(weapon)
	weapon:SetRuntime({ Accuracy = math.max(weapon:GetStat("Accuracy", 1) - BLOOM_PER_SHOT, 0) })
end

function Modpack.OnCameraUpdate(weapon, deltaTime)
	local Base = weapon:GetState("Bloom").Base
	local Current = weapon:GetStat("Accuracy", 1)

	if Base and Current < Base then
		weapon:SetRuntime({ Accuracy = math.min(Current + RECOVERY_PER_SECOND * deltaTime, Base) })
	end

	return nil
end
```

For a *deterministic* pattern rather than a widening random cone, implement `GetSpread` instead, which receives the projectile index and count.

### Travelling projectiles

The core never raycasts. Claim `ResolveProjectile` and you decide what a shot means:

```lua
function Modpack.ResolveProjectile(weapon, origin, context)
	local Arrow = ArrowTemplate:Clone()
	Arrow.CFrame = CFrame.lookAt(origin.position, origin.position + origin.direction)
	Arrow.AssemblyLinearVelocity = vector.normalize(origin.direction) * weapon:GetStat("ProjectileSpeed", 200)
	Arrow.Parent = workspace

	Arrow.Touched:Once(function(hit)
		ApplyDamage(weapon, hit)
		Arrow:Destroy()
	end)

	return nil -- Nothing has been hit *yet*; OnProjectileFire still fires with nil
end
```

A charge firemode can scale the speed by putting the charge in the context table, which arrives here as `context.Charge`.

### Melee

A melee weapon is a firemode, a resolver and no reload:

```lua
function Modpack.ResolveProjectile(weapon, origin, context)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = weapon:GetIgnored()

	return workspace:Spherecast(origin.position, weapon:GetStat("ArcRadius", 3), origin.direction, Params)
end

function Modpack.OnBeforeFire(weapon)
	return weapon:GetResource("Stamina").Amount >= weapon:GetStat("SwingCost", 15)
end

function Modpack.OnFire(weapon)
	weapon:AddResource("Stamina", -weapon:GetStat("SwingCost", 15), "swing")
end
```

A weapon with no `Ammo` pool fires without spending anything, so the Stamina pool above is all it needs.

### Penetration and wallbangs

`OnProjectileFire` gives you the spread-adjusted, range-scaled direction the shot was cast along, and `weapon:GetIgnored()` gives you the live exclusion list, already covering the character and viewmodel and kept correct across respawns.

```lua
local MAX_PENETRATIONS = 2

function Modpack.OnProjectileFire(weapon, origin, result)
	if not result then
		return
	end

	local Ignored = table.clone(weapon:GetIgnored())
	local Position = result.Position

	for _ = 1, MAX_PENETRATIONS do
		table.insert(Ignored, result.Instance)

		local Continued = RaycastParams.new()
		Continued.FilterType = Enum.RaycastFilterType.Exclude
		Continued.FilterDescendantsInstances = Ignored

		result = workspace:Raycast(Position, origin.direction, Continued)
		if not result then
			break
		end

		Position = result.Position
	end
end
```

### Server authority

Igneous runs on the client, so nothing it does is authoritative. Damage and ammo validation belong behind a remote, fired from `OnProjectileFire`:

```lua
function Modpack.OnProjectileFire(weapon, origin, result)
	if result and result.Instance.Parent:FindFirstChildOfClass("Humanoid") then
		DamageRemote:FireServer(weapon.Name, result.Instance, origin.position, origin.direction)
	end
end
```

The server should treat every argument as a claim, not a fact: re-check which weapon the player has equipped, the distance between `origin.position` and the hit, and the fire rate against the last shot it accepted. Sending the damage number from the client is what makes a game exploitable.

### Dry fire

Igneous stays quiet when the trigger is pulled on an empty magazine. Read the resource yourself:

```lua
function Modpack.OnFireStart(weapon)
	if weapon:GetResource("Ammo").Amount <= 0 then
		PlayDryFire(weapon)
	end
end
```

### Ammo counters

```lua
function Modpack.OnEquip(weapon)
	local Ammo = weapon:GetAmmo()
	UpdateCounter(Ammo.Amount, Ammo.Reserve)
end

function Modpack.OnAmmoChange(weapon, previous, current)
	UpdateCounter(current, weapon:GetAmmo().Reserve)
end
```

## Cleaning up

A weapon holds a render connection, a cloned viewmodel and a Motus animator. Call `Weapon:Destroy()` when you're finished. Dropping the reference isn't enough, and a leaked weapon keeps contributing to the camera every frame.

`Destroy` unequips the weapon, fires `OnDestroy` so modpacks can release anything keyed to it, drops the `GetState` tables, and destroys the viewmodel and animator. It's safe to call twice.
