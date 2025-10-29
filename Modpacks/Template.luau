local Motus = require(game.ReplicatedStorage.Packages.Motus) -- Remove this if you do not need to animate the viewmodel

local Modpack = {}

type Weapon = {
	Name: string,
	Viewmodel: Model,

	Animator: Motus.MotusAnimator, -- Remove this if you do not need to animate the viewmodel
}

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

function Modpack.OnFire(weapon: Weapon, origin: { position: vector, direction: vector }, result: RaycastResult?)
	print(weapon.Name, "has fired at", origin)
	if result then
		print("..." .. "and has hit the part", result.Instance.Name, "at", result.Position)
	end
end

function Modpack.OnAmmoChange(weapon: Weapon, previous: number, current: number, reason: "reload" | "fired" | "set")
	print(weapon.Name, "has changed from", previous("bullets to"), current, "because a", reason, "happened")
end

return Modpack
