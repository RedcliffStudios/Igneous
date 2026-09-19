--!strict

-- Simple, Staged and Progressive reload sequences. A reload moves rounds from the Reserve
-- pool into the Ammo pool, blocking fire through OnBeforeFire while a stage requires it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Igneous = require(ReplicatedStorage.Packages.Igneous)
local Types = require(ReplicatedStorage.Packages.Igneous.Types)

type Weapon = Types.Weapon

type ReloadState = {
	IsActive: boolean,
	StageIndex: number,
	IsFireLocked: boolean,
	Thread: thread?,
}

local STATE_KEY = "Reloading"
local AMMO = "Ammo"
local RESERVE = "Reserve"

local Modpack = {}

Modpack.Name = "Reloading"
Modpack.Priority = 90

local function GetReloadState(weapon: Weapon): ReloadState
	local State = weapon:GetState(STATE_KEY) :: any

	if State.StageIndex == nil then
		State.IsActive = false
		State.StageIndex = 1
		State.IsFireLocked = false
		State.Thread = nil
	end

	return State
end

local function IsThreadAlive(thread: thread?): boolean
	return thread ~= nil and coroutine.status(thread :: thread) ~= "dead"
end

--[=[
	The stage a reload is currently sitting in. Simple and Progressive reloads have no real
	stages, so they synthesize one from their own duration and cancellability, which is what
	keeps the reload hooks consistent across all three types.
]=]
local function GetCurrentStage(weapon: Weapon): Types.StagedReloadStage?
	local Reload = weapon:GetStat("Reload") :: Types.ReloadData?
	if not Reload then
		return nil
	end

	if Reload.Type == "Simple" then
		return { Name = "Reload", Duration = Reload.Duration, Cancellable = Reload.Cancellable, CanFireAfter = true }
	elseif Reload.Type == "Progressive" then
		return { Name = "Cycle", Duration = Reload.Duration, Cancellable = Reload.Cancellable, CanFireAfter = true }
	end

	return Reload.Stages[GetReloadState(weapon).StageIndex]
end

--[=[
	Kills the reload thread and clears reload state, leaving the stage index alone so a
	Staged reload can resume from the interrupted stage. Does not itself check whether the
	stage is cancellable. That is the caller's decision.
]=]
local function AbortReload(weapon: Weapon, stage: Types.StagedReloadStage?): ()
	local State = GetReloadState(weapon)
	local Thread = State.Thread
	State.Thread = nil

	if IsThreadAlive(Thread) then
		task.cancel(Thread :: thread)
	end

	State.IsActive = false
	State.IsFireLocked = false

	if stage then
		Igneous.Trigger(weapon, "OnReloadCancel", stage)
	end
end

local function RunSimple(weapon: Weapon, reload: Types.SimpleReloadData): ()
	local State = GetReloadState(weapon)
	local Stage = GetCurrentStage(weapon) :: Types.StagedReloadStage
	State.IsFireLocked = true

	Igneous.Trigger(weapon, "OnReloadStageStart", Stage)
	task.wait(reload.Duration)
	Igneous.Trigger(weapon, "OnReloadStageEnd", Stage)

	local Ammo = weapon:GetResource(AMMO)
	weapon:TransferResource(RESERVE, AMMO, Ammo.Max - Ammo.Amount, "reload")
	State.IsFireLocked = false
end

local function RunStaged(weapon: Weapon, reload: Types.StagedReloadData): ()
	local State = GetReloadState(weapon)

	while State.StageIndex <= #reload.Stages do
		local Stage = reload.Stages[State.StageIndex]
		State.IsFireLocked = true

		Igneous.Trigger(weapon, "OnReloadStageStart", Stage)
		task.wait(Stage.Duration)
		Igneous.Trigger(weapon, "OnReloadStageEnd", Stage)

		if Stage.AmmoTransfer then
			weapon:TransferResource(RESERVE, AMMO, Stage.AmmoTransfer, "reload")
		end

		State.IsFireLocked = not Stage.CanFireAfter
		State.StageIndex += 1
	end
end

local function RunProgressive(weapon: Weapon, reload: Types.ProgressiveReloadData): ()
	local State = GetReloadState(weapon)
	local Stage = GetCurrentStage(weapon) :: Types.StagedReloadStage

	while true do
		local Ammo = weapon:GetResource(AMMO)
		if Ammo.Amount >= Ammo.Max or weapon:GetResource(RESERVE).Amount <= 0 then
			break
		end

		State.IsFireLocked = true

		Igneous.Trigger(weapon, "OnReloadStageStart", Stage)
		task.wait(reload.Duration)
		Igneous.Trigger(weapon, "OnReloadStageEnd", Stage)

		weapon:TransferResource(RESERVE, AMMO, reload.AmountPerCycle, "reload")
		State.IsFireLocked = false
	end
end

local function RunReload(weapon: Weapon): ()
	local State = GetReloadState(weapon)
	local Reload = weapon:GetStat("Reload") :: Types.ReloadData

	if Reload.Type == "Simple" then
		RunSimple(weapon, Reload)
	elseif Reload.Type == "Staged" then
		RunStaged(weapon, Reload)
	elseif Reload.Type == "Progressive" then
		RunProgressive(weapon, Reload)
	end

	State.IsActive = false
	State.StageIndex = 1
	State.IsFireLocked = false
	State.Thread = nil

	Igneous.Trigger(weapon, "OnReloadEnd")
end

Igneous.RegisterExtension("Reload", function(weapon: Weapon): ()
	local State = GetReloadState(weapon)

	if not weapon:IsEquipped() or State.IsActive then
		return
	end

	if not weapon:GetStat("Reload") then
		return
	end

	local Ammo = weapon:GetResource(AMMO)
	if Ammo.Amount >= Ammo.Max or weapon:GetResource(RESERVE).Amount <= 0 then
		return
	end

	if weapon:GetStat("IsAiming", false) and not weapon:GetStat("CanReloadWhileAiming", true) then
		return
	end

	if not Igneous.Gate(weapon, "OnBeforeReload") then
		return
	end

	State.IsActive = true
	Igneous.Trigger(weapon, "OnReloadStart")

	State.Thread = task.spawn(function()
		RunReload(weapon)
	end)
end)

Igneous.RegisterExtension("CancelReload", function(weapon: Weapon): ()
	if not GetReloadState(weapon).IsActive then
		return
	end

	local Stage = GetCurrentStage(weapon)
	if not Stage or not Stage.Cancellable then
		return
	end

	AbortReload(weapon, Stage)
end)

Igneous.RegisterExtension("IsReloading", function(weapon: Weapon): boolean
	return GetReloadState(weapon).IsActive
end)

--[=[
	Blocks the Firing modpack while a stage says the weapon can't shoot. Firing never has
	to know reloading exists.
]=]
function Modpack.OnBeforeFire(weapon: Weapon): boolean?
	return not GetReloadState(weapon).IsFireLocked
end

function Modpack.OnUnequip(weapon: Weapon)
	if not GetReloadState(weapon).IsActive then
		return
	end

	-- Forced, ignoring Cancellable: the weapon is gone. The stage index survives, so
	-- re-equipping and reloading resumes where it left off.
	AbortReload(weapon, GetCurrentStage(weapon))
end

return Modpack
