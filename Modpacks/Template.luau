-- References to "Motus" can be removed if you don't animate the viewmodel
-- Or if you don't need the autocomplete (Not recommended)
-- Add the weapon type from Types.luau for the autocomplete too


local Modpack = {}

function Modpack.OnEquip(weapon)
	print(weapon.Name, "has been equipped")
end

function Modpack.OnUnequip(weapon)
	print(weapon.Name, "has been unequipped")
end

function Modpack.OnFireStart(weapon)
	print(weapon.Name, "has started firing")
end

function Modpack.OnFireEnd(weapon)
	print(weapon.Name, "has stopped firing")
end

function Modpack.OnFire(weapon, origin: { position: vector, direction: vector }, result: RaycastResult?)
	print(weapon.Name, "has fired at", origin)
	if result then
		print("..." .. "and has hit the part", result.Instance.Name, "at", result.Position)
	end
end

function Modpack.OnAmmoChange(weapon, previous: number, current: number, reason: "reload" | "fired" | "set")
	print(weapon.Name, "has changed from", previous, "bullets to", current, "because a", reason, "happened")
end

return Modpack
