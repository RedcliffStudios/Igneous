--!strict

local Player = game.Players.LocalPlayer

local ReplicatedStorage = game.ReplicatedStorage :: ReplicatedStorage

local Trove = require(script.Parent.Trove)
local Motus = require(script.Parent.Motus)

local ModpackManager = require(script.ModpackManager)
local Types = require(script.Types)

type Weapon = IgneousWeapon & {
	_Cleanup: Trove.Trove,
	_RaycastParams: RaycastParams,
	_Data: Types.DataModule,
	_Runtime: Types.RuntimeState,
	_LockedAngles: Vector3,

	_IsEquipped: boolean,

	_Ammo: Types.AmmoData,

	_IsFiring: boolean,
	_CanFire: boolean,
	_FireThread: thread?,

	_ReloadState: "InProgress"?,
	_ReloadStageIndex: number?,
	_ReloadFireLocked: boolean,
	_ReloadThread: thread?,

	_Init: (self: Weapon) -> (),
	_GenerateSpread: (self: Weapon) -> vector,
	_UpdateLockedAngles: (self: Weapon) -> (),
	_SetLock: (self: Weapon, lock: Types.LockAxes?) -> (),

	_TransferAmmo: (self: Weapon, amount: number) -> (),
	_RunReload: (self: Weapon) -> (),
	_RunSimpleReload: (self: Weapon, reload: Types.SimpleReloadData) -> (),
	_RunStagedReload: (self: Weapon, reload: Types.StagedReloadData) -> (),
	_RunProgressiveReload: (self: Weapon, reload: Types.ProgressiveReloadData) -> (),

	_Fire: (self: Weapon, amount: number) -> (),
}

local Modpacks = ReplicatedStorage:FindFirstChild("Modpacks", true)

local RunService = game:GetService("RunService")

local Camera = game.Workspace.CurrentCamera

local RUNTIME_KEYS = {
	Accuracy = true,
	MaxSpread = true,
	Range = true,
	Cooldown = true,
	Recoil = true,
	Offset = true,
}

if Modpacks then
	for _, modpack in ipairs(Modpacks:GetChildren()) do
		ModpackManager:RegisterModpack(modpack :: ModuleScript)
	end
end

--- @class Igneous
--- Lightweight, modular FPS framework for Roblox providing core weapon mechanics with a hook-based modpack system

local Igneous = {}
Igneous.__index = Igneous

--[=[
	@prop Name string
	@within IgneousWeapon
	The name of the weapon
]=]

--[=[
	@prop Viewmodel Model
	@within IgneousWeapon
	The cloned viewmodel instance for this weapon
]=]

--[=[
	@prop Animator MotusAnimator
	@within IgneousWeapon
	The Motus animator for controlling weapon animations. See [the specific documentation](https://redcliffstudios.github.io/Motus/api/MotusAnimator) for usage.
]=]

--[=[
	@function new
	@within Igneous
	@param name string
	@param viewmodel Model -- Refer to the templates page to see an example viewmodel
	@param data ModuleScript -- The weapon's Data module, see the templates page for its schema
	@return IgneousWeapon

	Creates a new weapon
]=]

function Igneous.new(name: string, viewmodel: Model, data: ModuleScript): IgneousWeapon
	local Data = require(data)() :: Types.DataModule

	local self = setmetatable({
		Name = name,
		Viewmodel = viewmodel:Clone(),

		Animator = Motus.new(viewmodel),
		_Cleanup = Trove.new(),
		_RaycastParams = RaycastParams.new(),
		_Data = Data,
		_Runtime = {
			IsAiming = false,
			Lock = Data.Lock,
			Offset = Data.Offset,
			Accuracy = Data.Accuracy,
			MaxSpread = Data.MaxSpread,
			Range = Data.Range,
			Cooldown = Data.Cooldown,
			Recoil = Data.Recoil,
		},
		_LockedAngles = Vector3.new(0, 0, 0),

		_IsEquipped = false,

		_Ammo = {
			Amount = Data.Ammo,
			Max = Data.MaxAmmo,
			Reserve = Data.Reserve,
		},

		_IsFiring = false,
		_CanFire = Data.CanFire,
		_FireThread = nil,

		_ReloadState = nil,
		_ReloadStageIndex = nil,
		_ReloadFireLocked = false,
		_ReloadThread = nil,
	}, Igneous)

	self:_Init()

	return self
end

--[=[
	@private
	@method _Init
	@within IgneousWeapon

	Sets up and initializes the weapon by binding it to the camera and setting the RaycastParams
]=]

function Igneous._Init(self: Weapon): ()
	self._Cleanup:Add(function()
		if self._FireThread then
			task.cancel(self._FireThread)
		end
		if self._ReloadThread then
			task.cancel(self._ReloadThread)
		end
	end)

	self._Cleanup:Add(RunService.PreRender:Connect(function(dt)
		local Contribution = ModpackManager:SumHook("OnCameraUpdate", self, dt)
		Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(Contribution.y), math.rad(Contribution.x), 0)

		local FinalCFrame = Camera.CFrame
		if self._Runtime.Lock then
			local X, Y, Z = Camera.CFrame:ToOrientation()
			local Lock = self._Runtime.Lock
			FinalCFrame = CFrame.new(FinalCFrame.Position)
				* CFrame.fromOrientation(
					Lock.X and self._LockedAngles.X or X,
					Lock.Y and self._LockedAngles.Y or Y,
					Lock.Z and self._LockedAngles.Z or Z
				)
		end

		if self._Runtime.Offset then
			FinalCFrame = FinalCFrame * CFrame.new(self._Runtime.Offset)
		end

		self.Viewmodel:PivotTo(FinalCFrame)
	end))

	self._RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self._RaycastParams.FilterDescendantsInstances = { Player.Character :: Instance, self.Viewmodel }
end

--[=[
	@method Equip
	@within IgneousWeapon
	
	Equips the weapon, making it visible and triggering the OnEquip hook for all registered modpacks.
	The viewmodel is parented to Workspace and becomes active.
]=]

function Igneous.Equip(self: Weapon): ()
	self:_UpdateLockedAngles()

	ModpackManager:TriggerHook("OnEquip", self)
	self._IsEquipped = true
	self.Viewmodel.Parent = game.Workspace
end

--[=[
	@method Unequip
	@within IgneousWeapon
	
	Unequips the weapon, hiding it and triggering the OnUnequip hook for all registered modpacks.
	The viewmodel is parented back to ReplicatedStorage and becomes inactive.
]=]

function Igneous.Unequip(self: Weapon): ()
	ModpackManager:TriggerHook("OnUnequip", self)
	self._IsEquipped = false
	self.Viewmodel.Parent = ReplicatedStorage
end

--[=[
	@private
	@method _GenerateSpread
	@within IgneousWeapon
	@return vector

	Generates a random spread based on the weapon's accuracy
]=]

function Igneous._GenerateSpread(self: Weapon): vector
	local Theta = math.random() * 2 * math.pi
	local Radius = math.tan(math.rad(self._Runtime.MaxSpread * (1 - self._Runtime.Accuracy))) * math.sqrt(math.random())

	return vector.create(Radius * math.cos(Theta), Radius * math.sin(Theta), 0)
end

--[=[
	@private
	@method _UpdateLockedAngles
	@within IgneousWeapon

	Recomputes the weapon's locked rotation angles from the camera's current orientation,
	based on which axes _Runtime.Lock has enabled. No-ops if the weapon isn't locked on any axis.
]=]

function Igneous._UpdateLockedAngles(self: Weapon): ()
	local Lock = self._Runtime.Lock
	if not Lock then
		return
	end

	local X, Y, Z = Camera.CFrame:ToOrientation()
	self._LockedAngles = Vector3.new(Lock.X and X or 0, Lock.Y and Y or 0, Lock.Z and Z or 0)
end

--[=[
	@private
	@method _TransferAmmo
	@within IgneousWeapon
	@param amount number -- How many rounds to move from Reserve into Amount

	Moves up to `amount` rounds from Reserve into Amount, clamped to whatever's actually
	available and to the weapon's Max. Triggers OnAmmoChange if any rounds were transferred.
]=]

function Igneous._TransferAmmo(self: Weapon, amount: number): ()
	local Transferred = math.min(amount, self._Ammo.Reserve, self._Ammo.Max - self._Ammo.Amount)
	if Transferred <= 0 then
		return
	end

	local Previous = self._Ammo.Amount
	self._Ammo.Amount += Transferred
	self._Ammo.Reserve -= Transferred
	ModpackManager:TriggerHook("OnAmmoChange", self, Previous, self._Ammo.Amount, "reload")
end

--[=[
	@private
	@method _RunSimpleReload
	@within IgneousWeapon
	@param reload SimpleReloadData

	Runs a Simple reload: waits the full duration, then fills ammo to Max in one transfer.
]=]

function Igneous._RunSimpleReload(self: Weapon, reload: Types.SimpleReloadData): ()
	local Stage: Types.StagedReloadStage =
		{ Name = "Reload", Duration = reload.Duration, Cancellable = reload.Cancellable, CanFireAfter = true }
	self._ReloadFireLocked = true

	ModpackManager:TriggerHook("OnReloadStageStart", self, Stage)
	task.wait(reload.Duration)
	ModpackManager:TriggerHook("OnReloadStageEnd", self, Stage)

	self:_TransferAmmo(self._Ammo.Max - self._Ammo.Amount)
	self._ReloadFireLocked = false
end

--[=[
	@private
	@method _RunStagedReload
	@within IgneousWeapon
	@param reload StagedReloadData

	Runs a Staged reload, walking each stage in order starting from _ReloadStageIndex
	(so a resumed reload continues from wherever it was cancelled). Transfers ammo and
	unlocks firing according to each stage's AmmoTransfer and CanFireAfter.
]=]

function Igneous._RunStagedReload(self: Weapon, reload: Types.StagedReloadData): ()
	self._ReloadStageIndex = self._ReloadStageIndex or 1

	while self._ReloadStageIndex <= #reload.Stages do
		local Stage = reload.Stages[self._ReloadStageIndex]
		self._ReloadFireLocked = true

		ModpackManager:TriggerHook("OnReloadStageStart", self, Stage)
		task.wait(Stage.Duration)
		ModpackManager:TriggerHook("OnReloadStageEnd", self, Stage)

		if Stage.AmmoTransfer then
			self:_TransferAmmo(Stage.AmmoTransfer)
		end

		self._ReloadFireLocked = not Stage.CanFireAfter
		self._ReloadStageIndex += 1
	end
end

--[=[
	@private
	@method _RunProgressiveReload
	@within IgneousWeapon
	@param reload ProgressiveReloadData

	Runs a Progressive reload, repeating a single cycle and transferring AmountPerCycle
	rounds each time until the weapon is full or reserve runs out. Firing is unlocked
	between cycles.
]=]

function Igneous._RunProgressiveReload(self: Weapon, reload: Types.ProgressiveReloadData): ()
	local Stage: Types.StagedReloadStage =
		{ Name = "Cycle", Duration = reload.Duration, Cancellable = reload.Cancellable, CanFireAfter = true }

	while self._Ammo.Amount < self._Ammo.Max and self._Ammo.Reserve > 0 do
		self._ReloadFireLocked = true

		ModpackManager:TriggerHook("OnReloadStageStart", self, Stage)
		task.wait(reload.Duration)
		ModpackManager:TriggerHook("OnReloadStageEnd", self, Stage)

		self:_TransferAmmo(reload.AmountPerCycle)
		self._ReloadFireLocked = false
	end
end

--[=[
	@private
	@method _RunReload
	@within IgneousWeapon

	Dispatches to the correct reload runner based on _Data.Reload.Type, then clears
	all reload state once the runner finishes.
]=]

function Igneous._RunReload(self: Weapon): ()
	local Reload = self._Data.Reload :: Types.ReloadData

	if Reload.Type == "Simple" then
		self:_RunSimpleReload(Reload)
	elseif Reload.Type == "Staged" then
		self:_RunStagedReload(Reload)
	elseif Reload.Type == "Progressive" then
		self:_RunProgressiveReload(Reload)
	end

	self._ReloadState = nil
	self._ReloadStageIndex = nil
	self._ReloadFireLocked = false
	self._ReloadThread = nil
end

--[=[
	@private
	@method _Fire
	@within IgneousWeapon
	@param amount number -- How many projectiles to cast this call

	Fires a raycast per projectile, and triggers the OnFire and OnProjectileFire hooks.
	Waits the duration of the weapon cooldown before returning.
]=]

function Igneous._Fire(self: Weapon, amount: number): ()
	if self._Ammo.Amount <= 0 or self._ReloadFireLocked then
		return
	end

	if not ModpackManager:CheckGate("OnBeforeFire", self) then
		return
	end

	self._CanFire = false
	self._Ammo.Amount -= 1

	ModpackManager:TriggerHook("OnFire", self)

	for _ = 1, amount do
		local LookVector = Camera.CFrame.LookVector
		local Origin = Camera.CFrame.Position
		local Direction = vector.normalize(
			(vector.create(LookVector.X, LookVector.Y, LookVector.Z) + self:_GenerateSpread())
		) * self._Runtime.Range
		local RaycastResult = game.Workspace:Raycast(Origin, Direction, self._RaycastParams)
		ModpackManager:TriggerHook(
			"OnProjectileFire",
			self,
			{ position = Origin, direction = Direction },
			RaycastResult
		)
	end

	task.wait(self._Runtime.Cooldown)
	self._CanFire = true
end

--[=[
	@private
	@method _SetLock
	@within IgneousWeapon
	@param lock LockAxes? -- Which axes to freeze relative to the camera, or nil to unlock

	Freezes the viewmodel's rotation on the given axes, capturing the current camera
	orientation as the locked angle. Pass nil to let the viewmodel rotate freely again.
	Called internally by SetRuntime — use `weapon:SetRuntime({ Lock = ... })` instead of calling this directly.
]=]

function Igneous._SetLock(self: Weapon, lock: Types.LockAxes?): ()
	self._Runtime.Lock = lock
	self:_UpdateLockedAngles()
end

--[=[
	@method Reload
	@within IgneousWeapon

	Begins (or resumes) the weapon's reload sequence. No-ops if already reloading, unequipped,
	full on ammo, out of reserve, aiming while CanReloadWhileAiming is false, or blocked by a
	modpack's OnBeforeReload. If a previous Staged reload was cancelled mid-stage, resumes
	from that stage.
]=]

function Igneous.Reload(self: Weapon): ()
	if not self._IsEquipped or self._ReloadState == "InProgress" then
		return
	end

	if self._Ammo.Amount >= self._Ammo.Max or self._Ammo.Reserve <= 0 then
		return
	end

	if self._Runtime.IsAiming and not self._Data.CanReloadWhileAiming then
		return
	end

	if not ModpackManager:CheckGate("OnBeforeReload", self) then
		return
	end

	self._ReloadState = "InProgress"

	self._ReloadThread = task.spawn(function()
		self:_RunReload()
	end)
end

--[=[
	@method CancelReload
	@within IgneousWeapon

	Interrupts an in-progress reload, if the current stage allows it. For a Staged reload,
	the stage index is preserved, so calling Reload again resumes (restarts) from the
	interrupted stage rather than starting over from the beginning.
]=]

function Igneous.CancelReload(self: Weapon): ()
	if self._ReloadState ~= "InProgress" then
		return
	end

	local Reload = self._Data.Reload :: Types.ReloadData
	local Stage: Types.StagedReloadStage

	if Reload.Type == "Simple" then
		if not Reload.Cancellable then
			return
		end
		Stage = { Name = "Reload", Duration = Reload.Duration, Cancellable = true, CanFireAfter = true }
	elseif Reload.Type == "Progressive" then
		if not Reload.Cancellable then
			return
		end
		Stage = { Name = "Cycle", Duration = Reload.Duration, Cancellable = true, CanFireAfter = true }
	else
		local CurrentStage = Reload.Stages[self._ReloadStageIndex :: number]
		if not CurrentStage.Cancellable then
			return
		end
		Stage = CurrentStage
	end

	if self._ReloadThread then
		task.cancel(self._ReloadThread)
		self._ReloadThread = nil
	end

	self._ReloadState = nil
	self._ReloadFireLocked = false
	ModpackManager:TriggerHook("OnReloadCancel", self, Stage)
end

--[=[
	@method SetRuntime
	@within IgneousWeapon
	@param changes { [string]: any } -- Partial fields to overwrite

	Overwrites weapon stats. Accuracy, MaxSpread, Range, Cooldown, Recoil, Offset,
	and Lock are runtime-mutable and are written to _Runtime
]=]

function Igneous.SetRuntime(self: Weapon, changes: { [string]: any }): ()
	local NewData: Types.DataModule?

	for Key, Value in changes do
		if Key == "Lock" then
			self:_SetLock(Value :: Types.LockAxes?)
		elseif RUNTIME_KEYS[Key] then
			(self._Runtime :: any)[Key] = Value
		elseif Key == "MaxAmmo" then
			self._Ammo.Max = Value :: number
		elseif Key == "Reserve" then
			self._Ammo.Reserve = Value :: number
		else
			NewData = NewData or table.clone(self._Data)
		end
	end

	if NewData then
		self._Data = NewData
	end
end

--[=[
	@method GetRuntime
	@within IgneousWeapon
	@return RuntimeState

	Returns a shallow copy of the weapon's current runtime state (Lock, Offset,
	IsAiming, Accuracy, MaxSpread, Range, Cooldown, Recoil). A copy, not the live
	table, so mutating the result can't bypass SetRuntime/SetAiming and their side effects.
]=]

function Igneous.GetRuntime(self: Weapon): Types.RuntimeState
	return table.clone(self._Runtime)
end

--[=[
	@method SetAiming
	@within IgneousWeapon
	@param isAiming boolean

	Toggles the weapon's aiming state and triggers OnAimStart/OnAimEnd for registered modpacks.
	Does not itself change any camera behavior — modpacks read Weapon._Runtime.IsAiming to react.
]=]

function Igneous.SetAiming(self: Weapon, isAiming: boolean): ()
	if self._Runtime.IsAiming == isAiming then
		return
	end

	if not ModpackManager:CheckGate("OnBeforeAim", self, isAiming) then
		return
	end

	self._Runtime.IsAiming = isAiming

	if isAiming then
		ModpackManager:TriggerHook("OnAimStart", self)
	else
		ModpackManager:TriggerHook("OnAimEnd", self)
	end
end

--[=[
	@method SetFiring
	@within IgneousWeapon
	@param shouldFire boolean -- Whether the weapon should start or stop firing
	
	Controls the weapon's firing state. When set to true, begins firing based on the weapon's firemode (Semi, Burst, or Auto).
	When set to false, stops firing (Auto only — Semi/Burst always complete their sequence). Triggers OnFireStart
	and OnFireEnd hooks accordingly. Only works when the weapon is equipped, not blocked by a reload, and has ammunition.
]=]

function Igneous.SetFiring(self: Weapon, shouldFire: boolean): ()
	if not self._IsEquipped or self._IsFiring == shouldFire or self._ReloadFireLocked then
		return
	end

	self._IsFiring = shouldFire

	if self._IsFiring then
		ModpackManager:TriggerHook("OnFireStart", self)

		if not self._FireThread then
			self._FireThread = task.spawn(function()
				if self._CanFire and self._Ammo.Amount > 0 then
					local Firemode = self._Data.Firemode :: Types.Firemode
					local Projectiles = self._Data.Projectiles :: number

					if Firemode == "Semi" then
						self:_Fire(Projectiles)
					elseif Firemode == "Burst" then
						for _ = 1, Projectiles do
							self:_Fire(1)
						end
					elseif Firemode == "Auto" then
						while self._IsFiring and self._Ammo.Amount > 0 do
							self:_Fire(self._Data.Projectiles :: number)
						end
					end
				end

				self._FireThread = nil
			end)
		end
	else
		ModpackManager:TriggerHook("OnFireEnd", self)

		if self._Data.Firemode == "Auto" and self._FireThread then
			task.cancel(self._FireThread)
			self._FireThread = nil
		end
	end
end

--[=[
	@class IgneousWeapon

	Represents a weapon instance created by `Igneous.new()`. Contains methods for equipping, unequipping, and controlling weapon firing.
	Weapons automatically handle spread, ammo management, and trigger modpack hooks at appropriate lifecycle points.
]=]

export type IgneousWeapon = typeof(setmetatable(
	{} :: {
		Name: string,
		Viewmodel: Model,

		Animator: Motus.MotusAnimator,

		Equip: (self: Weapon) -> (),
		Unequip: (self: Weapon) -> (),
		Reload: (self: Weapon) -> (),
		CancelReload: (self: Weapon) -> (),
		SetFiring: (self: Weapon, shouldFire: boolean) -> (),
		SetRuntime: (self: Weapon, changes: { [string]: any }) -> (),
		GetRuntime: (self: Weapon) -> Types.RuntimeState,
		SetAiming: (self: Weapon, isAiming: boolean) -> (),
	},
	Igneous
))

return Igneous
