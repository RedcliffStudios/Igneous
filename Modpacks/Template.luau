-- References to "Motus" can be removed if you don't animate the viewmodel
-- Or if you don't need the autocomplete, where you can also remove the other types (Not recommended)

local Motus = require(game.ReplicatedStorage.Packages.Motus)

type Weapon = {
	Name: string,
	Viewmodel: Model,

	Animator: Motus.MotusAnimator,
}

type StagedReloadStage = {
	Name: string,
	Duration: number,
	Cancellable: boolean,
	AmmoTransfer: number?,
	CanFireAfter: boolean,
}

local Modpack = {}

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

function Modpack.OnFire(weapon: Weapon)
	print(weapon.Name, "has fired")
end

function Modpack.OnProjectileFire(
	weapon: Weapon,
	origin: { position: Vector3, direction: Vector3 },
	result: RaycastResult?
)
	print(weapon.Name, "has cast a projectile from", origin.position)
	if result then
		print("..." .. "and has hit the part", result.Instance.Name, "at", result.Position)
	end
end

function Modpack.OnAmmoChange(weapon: Weapon, previous: number, current: number, reason: "reload" | "fired" | "set")
	print(weapon.Name, "has changed from", previous, "bullets to", current, "because a", reason, "happened")
end

function Modpack.OnAimStart(weapon: Weapon)
	print(weapon.Name, "has started aiming")
end

function Modpack.OnAimEnd(weapon: Weapon)
	print(weapon.Name, "has stopped aiming")
end

function Modpack.OnCameraUpdate(weapon: Weapon, dt: number): vector?
	return nil
end

function Modpack.OnBeforeFire(weapon: Weapon): boolean?
	return true
end

function Modpack.OnBeforeAim(weapon: Weapon, isAiming: boolean): boolean?
	return true
end

function Modpack.OnBeforeReload(weapon: Weapon): boolean?
	return true
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

return Modpack