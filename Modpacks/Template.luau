--!strict

-- Every hook is optional. Delete the ones your modpack doesn't need.
--
-- Hooks are grouped below by who dispatches them. Only the core group fires
-- unconditionally; the rest need their modpack loaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Igneous = require(ReplicatedStorage.Packages.Igneous)
local Types = require(ReplicatedStorage.Packages.Igneous.Types)

type Weapon = Types.Weapon
type StagedReloadStage = Types.StagedReloadStage

local Modpack = {}

-- The name weapons opt into this modpack by, via their Data module's `Modpacks` list.
-- Defaults to the ModuleScript's name when omitted.
Modpack.Name = "Template"

-- Dispatch order across modpacks, highest first. Defaults to 0. Decides who wins a
-- provider hook and who gets to veto first.
Modpack.Priority = 0

-- Core hooks

function Modpack.OnEquip(weapon: Weapon)
	print(weapon.Name, "has been equipped")
end

function Modpack.OnUnequip(weapon: Weapon)
	print(weapon.Name, "has been unequipped")
end

function Modpack.OnDestroy(weapon: Weapon)
	print(weapon.Name, "has been destroyed")
end

function Modpack.OnProjectileFire(
	weapon: Weapon,
	origin: Types.ProjectileOrigin,
	result: RaycastResult?,
	context: Types.CastContext?
)
	print(weapon.Name, "has cast a projectile from", origin.position)

	if result then
		print("...and has hit the part", result.Instance.Name, "at", result.Position)
	end
end

function Modpack.OnResourceChange(weapon: Weapon, name: string, previous: number, current: number, reason: string?)
	print(weapon.Name, "changed", name, "from", previous, "to", current, "because of a", reason)
end

-- Accumulate hook. Return a per-frame rotation delta in degrees (x = yaw, y = pitch,
-- z = roll), not an absolute angle. Igneous sums every modpack's delta and applies it
-- to the camera once.
function Modpack.OnCameraUpdate(weapon: Weapon, deltaTime: number): vector?
	return nil
end

-- Provider hooks
-- Only the highest-priority modpack implementing these runs, and it owns the answer.
-- Implementing one is claiming it, so delete these unless you mean to take them over.

-- function Modpack.ResolveProjectile(
-- 	weapon: Weapon,
-- 	origin: Types.ProjectileOrigin,
-- 	context: Types.CastContext?
-- ): RaycastResult?
-- 	local Params = RaycastParams.new()
-- 	Params.FilterType = Enum.RaycastFilterType.Exclude
-- 	Params.FilterDescendantsInstances = weapon:GetIgnored()
-- 	return workspace:Raycast(origin.position, origin.direction, Params)
-- end

-- function Modpack.GetSpread(weapon: Weapon, index: number, count: number, context: Types.CastContext?): vector
-- 	return vector.zero
-- end

-- Firing modpack hooks

function Modpack.OnFireStart(weapon: Weapon)
	print(weapon.Name, "has started firing")
end

function Modpack.OnFireEnd(weapon: Weapon)
	print(weapon.Name, "has stopped firing")
end

function Modpack.OnFire(weapon: Weapon, context: Types.CastContext?)
	print(weapon.Name, "has fired")
end

function Modpack.OnAmmoChange(weapon: Weapon, previous: number, current: number, reason: string?)
	print(weapon.Name, "has changed from", previous, "bullets to", current, "because a", reason, "happened")
end

function Modpack.OnBeforeFire(weapon: Weapon, context: Types.CastContext?): boolean?
	return true
end

-- Reloading modpack hooks

function Modpack.OnBeforeReload(weapon: Weapon): boolean?
	return true
end

function Modpack.OnReloadStart(weapon: Weapon)
	print(weapon.Name, "has started reloading")
end

function Modpack.OnReloadEnd(weapon: Weapon)
	print(weapon.Name, "has finished reloading")
end

function Modpack.OnReloadStageStart(weapon: Weapon, stage: StagedReloadStage)
	print(weapon.Name, "has started the", stage.Name, "reload stage")
end

function Modpack.OnReloadStageEnd(weapon: Weapon, stage: StagedReloadStage)
	print(weapon.Name, "has finished the", stage.Name, "reload stage")
end

function Modpack.OnReloadCancel(weapon: Weapon, stage: StagedReloadStage)
	print(weapon.Name, "cancelled the", stage.Name, "reload stage")
end

-- Aiming modpack hooks

function Modpack.OnBeforeAim(weapon: Weapon, isAiming: boolean): boolean?
	return true
end

function Modpack.OnAimStart(weapon: Weapon)
	print(weapon.Name, "has started aiming")
end

function Modpack.OnAimEnd(weapon: Weapon)
	print(weapon.Name, "has stopped aiming")
end

-- Extensions
-- Modpacks can add methods to every weapon, which is how the standard modpacks provide
-- SetFiring, Reload and SetAiming without those living in the core.

Igneous.RegisterExtension("Inspect", function(weapon: Weapon)
	print(weapon.Name, "is being inspected")
end)

return Modpack
