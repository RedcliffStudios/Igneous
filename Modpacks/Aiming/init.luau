--!strict

-- The aim-down-sights flag and its hooks. Owns the state and the events only; what aiming
-- looks like is left to whatever modpack reacts to it.
--
-- IsAiming lives in the weapon's runtime state rather than in this modpack, so anything
-- can read it with weapon:GetStat("IsAiming", false).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Igneous = require(ReplicatedStorage.Packages.Igneous)
local Types = require(ReplicatedStorage.Packages.Igneous.Types)

type Weapon = Types.Weapon

local Modpack = {}

Modpack.Name = "Aiming"
Modpack.Priority = 80

Igneous.RegisterExtension("SetAiming", function(weapon: Weapon, isAiming: boolean): ()
	if weapon:GetStat("IsAiming", false) == isAiming then
		return
	end

	if isAiming and weapon:GetStat("CanAim", true) == false then
		return
	end

	if not Igneous.Gate(weapon, "OnBeforeAim", isAiming) then
		return
	end

	weapon:SetRuntime({ IsAiming = isAiming })

	Igneous.Trigger(weapon, if isAiming then "OnAimStart" else "OnAimEnd")
end)

Igneous.RegisterExtension("IsAiming", function(weapon: Weapon): boolean
	return weapon:GetStat("IsAiming", false)
end)

function Modpack.OnUnequip(weapon: Weapon)
	if not weapon:GetStat("IsAiming", false) then
		return
	end

	weapon:SetRuntime({ IsAiming = false })
	Igneous.Trigger(weapon, "OnAimEnd")
end

return Modpack
