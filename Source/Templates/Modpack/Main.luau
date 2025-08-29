local Modpack = {}

function Modpack.Fire(Coordinate: { Origin: vector, Direction: vector }, Raycast: RaycastResult, Data: {}) end

function Modpack.Reload(Data: {}, Animation: AnimationTrack) end

function Modpack.Equip(Weapon) end

function Modpack.Unequip(Weapon) end

-- The Weapon parameter being passed to these listeners is the entire weapon object. So you have access to the entire weapon from those listeners.

return Modpack
