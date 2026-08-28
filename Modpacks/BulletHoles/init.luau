local Motus = require(game.ReplicatedStorage.RS_GLOBAL.Packages.Motus)

local Modpack = {}

type Weapon = {
	Name: string,
	Viewmodel: Model,

	Animator: Motus.MotusAnimator,
}

function Modpack.OnEquip(weapon: Weapon) end

function Modpack.OnUnequip(weapon: Weapon) end

function Modpack.OnFire(weapon: Weapon, origin: { position: vector, direction: vector }, result: RaycastResult?) end

function Modpack.OnAmmoChange(weapon: Weapon, previous: number, current: number, reason: "reload" | "fired" | "set") end

return Modpack
