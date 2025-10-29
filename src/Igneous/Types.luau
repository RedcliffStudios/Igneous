local Motus = require(game.ReplicatedStorage.Packages.Motus)

export type Weapon = {
	Name: string,
	Viewmodel: Model,

	Animator: Motus.MotusAnimator,
}

export type DataModule = { any } & { [any]: any }

export type Firemode = "Semi" | "Auto" | "Burst"

export type AmmoData = {
	Amount: number,
	Max: number,
	Reserve: number,
}

export type Hooks = "OnEquip" | "OnUnequip" | "OnFireStart" | "OnFireEnd" | "OnFire" | "OnAmmoChange"

export type Modpack = {
	OnEquip: ((weapon: Weapon) -> ())?,
	OnUnequip: ((weapon: Weapon) -> ())?,
	OnFireStart: ((weapon: Weapon) -> ())?,
	OnFireEnd: ((weapon: Weapon) -> ())?,
	OnFire: ((weapon: Weapon, origin: { position: Vector3, direction: Vector3 }, result: RaycastResult?) -> ())?,
	OnAmmoChange: ((weapon: Weapon, previous: number, current: number, reason: "reload" | "fired" | "set") -> ())?,
}

return {}
