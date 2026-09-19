--!strict

-- Camera recoil, driven by a critically damped spring. Each shot impulses the spring, and
-- every frame its movement since the last frame is handed back as a camera delta. The
-- spring settles at zero, so the kick recovers and the camera ends up where it started.
-- Raise the spring's Target instead for recoil that only partly recovers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spring = require(ReplicatedStorage.Packages.Spring)
local Types = require(ReplicatedStorage.Packages.Igneous.Types)

type Weapon = Types.Weapon

type RecoilState = {
	Spring: Spring.Spring<vector>,
	Previous: vector,
}

local STATE_KEY = "Recoil"
local DEFAULT_SMOOTH_TIME = 0.18

-- The spring is impulsed with a velocity, but Recoil.Vertical/Horizontal are authored as
-- the peak kick in degrees. A critically damped spring impulsed with v0 peaks at
-- v0 * SmoothTime / (2e), so scaling by 2e / SmoothTime makes the peak land exactly on the
-- authored number.
local PEAK_TO_IMPULSE = 2 * math.exp(1)

local Modpack = {}

Modpack.Name = "Recoil"
Modpack.Priority = 0

local function GetRecoilState(weapon: Weapon): RecoilState
	local State = weapon:GetState(STATE_KEY) :: any

	if not State.Spring then
		State.Spring = Spring.new(vector.zero, DEFAULT_SMOOTH_TIME)
		State.Previous = vector.zero
	end

	return State
end

function Modpack.OnEquip(weapon: Weapon)
	local State = GetRecoilState(weapon)

	State.Spring:Reset(vector.zero)
	State.Previous = vector.zero
end

function Modpack.OnFire(weapon: Weapon)
	local Recoil = weapon:GetStat("Recoil") :: Types.RecoilData?
	if not Recoil then
		return
	end

	local State = GetRecoilState(weapon)

	-- Re-read the tuning every shot so attachments and perks that rewrite Recoil through
	-- SetRuntime take effect immediately.
	local SmoothTime = Recoil.SmoothTime or DEFAULT_SMOOTH_TIME
	State.Spring.SmoothTime = SmoothTime
	State.Spring.MaxSpeed = Recoil.MaxSpeed or math.huge

	local Scale = PEAK_TO_IMPULSE / SmoothTime
	State.Spring:Impulse(
		vector.create((math.random() * 2 - 1) * Recoil.Horizontal * Scale, Recoil.Vertical * Scale, 0)
	)
end

function Modpack.OnCameraUpdate(weapon: Weapon, deltaTime: number): vector?
	local State = GetRecoilState(weapon)
	local Current = State.Spring:Update(deltaTime)
	local Delta = Current - State.Previous

	State.Previous = Current

	return Delta
end

return Modpack
