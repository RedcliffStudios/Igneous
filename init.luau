--!strict

local Player = game.Players.LocalPlayer

local Trove = require(script.Parent.Trove)
local Spring = require(script.Parent.Spring)
local Motus = require(script.Parent.Motus)

local ModpackManager = require(script.ModpackManager)
local Types = require(script.Types)

type Weapon = IgneousWeapon & {
	_Cleanup: Trove.Trove,
	_IsFiring: boolean,
	_IsEquipped: boolean,
	_CanFire: boolean,
	_Ammo: Types.AmmoData,
	_Data: Types.DataModule,
	_Recoil: Spring.Spring<vector>,

	_Init: (self: Weapon) -> (),
	_GenerateSpread: (self: Weapon) -> vector,
}

local Modpacks = game.ReplicatedStorage:FindFirstChild("Modpacks")

local RunService = game:GetService("RunService")

local RaycastParams = RaycastParams.new()
RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

local Camera = game.Workspace.CurrentCamera

local function DeepClone(original: Types.DataModule)
	local clone = table.clone(original)

	for key, value in original do
		if type(value) == "table" then
			clone[key] = DeepClone(value)
		end
	end

	return clone
end

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
	@function new
	@within Igneous
	@param name string
	@param viewmodel Model -- Refer to the templates page to see an example viewmodel
	@return IgneousWeapon

	Creates a new weapon
]=]

function Igneous.new(name: string, viewmodel: Model): IgneousWeapon
	local DataModule = viewmodel:FindFirstChild("Data")
	assert(DataModule, "Weapon: " .. name .. " doesn't have a data module inside it's viewmodel")
	local Data = require(viewmodel:FindFirstChild("Data")) :: Types.DataModule

	local self = setmetatable({
		Name = name,
		Viewmodel = viewmodel:Clone(),

		Animator = Motus.new(viewmodel),
		_Cleanup = Trove.new(),
		_Recoil = Spring.new(vector.zero, 0.25, 25),

		_Ammo = {
			Amount = Data.Ammo,
			Max = Data.MaxAmmo,
			Reserve = Data.Reserve,
		},

		_Data = DeepClone(Data),

		_IsFiring = false,
		_IsEquipped = false,
		_CanFire = Data.CanFire,
	}, Igneous) :: IgneousWeapon

	self._Init(self :: Weapon)
	DataModule:Destroy()

	return self
end

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
	@private
	@method _Init
	@within IgneousWeapon

	Sets up and initializes the weapon by binding it to the camera and setting the RaycastParams
]=]

--[=[
	@method Equip
	@within IgneousWeapon
	
	Equips the weapon, making it visible and triggering the OnEquip hook for all registered modpacks.
	The viewmodel is parented to Workspace and becomes active.
]=]

function Igneous._Init(self: Weapon)
	self._Cleanup:Add(RunService.PreRender:Connect(function(dt)
		local Position = self._Recoil:Update(dt)
		Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(Position.y), math.rad(Position.x), 0)
		self.Viewmodel:PivotTo(Camera.CFrame)
	end))

	RaycastParams.FilterDescendantsInstances = { Player.Character :: Instance, self.Viewmodel }
end

function Igneous.Equip(self: Weapon)
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

function Igneous.Unequip(self: Weapon)
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

function Igneous._GenerateSpread(self: Weapon)
	local theta = math.random() * 2 * math.pi
	local r = math.tan(math.rad(self._Data.MaxSpread * (1 - self._Data.Accuracy))) * math.sqrt(math.random())

	local x = r * math.cos(theta)
	local y = r * math.sin(theta)

	return vector.create(x, y, 0)
end

--[=[
	@private
	@method _Fire
	@within IgneousWeapon

	Fires a raycast, and triggers the OnFire hook. It waits the duration of the weapon cooldown.
]=]

function Igneous._Fire(self: Weapon, Amount: number)
	if not (self._Ammo.Amount > 0) then
		return
	end

	self._CanFire = false

	self._Recoil:Impulse(
		vector.create(
			math.random(-self._Data.Recoil.Horizontal, self._Data.Recoil.Horizontal),
			self._Data.Recoil.Vertical,
			0
		)
	)

	self._Ammo.Amount -= 1

	for _ = 1, Amount do
		local LookVector = Camera.CFrame.LookVector
		local Origin = Camera.CFrame.Position
		local Direction = vector.normalize(
			(vector.create(LookVector.X, LookVector.Y, LookVector.Z) + self:_GenerateSpread())
		) * self._Data.Range
		local RaycastResult = game.Workspace:Raycast(Origin, Direction, RaycastParams)
		ModpackManager:TriggerHook("OnFire", { position = Origin, direction = Direction }, RaycastResult)
	end

	task.wait(self._Data.Cooldown)
	self._CanFire = true
	return
end

--[=[
	@method SetFiring
	@within IgneousWeapon
	@param firing boolean -- Whether the weapon should start or stop firing
	
	Controls the weapon's firing state. When set to true, begins firing based on the weapon's firemode (Semi, Burst, or Auto).
	When set to false, stops firing. Triggers OnFireStart and OnFireEnd hooks accordingly.
	Only works when the weapon is equipped and has ammunition.
]=]

function Igneous.SetFiring(self: Weapon, boolean: boolean)
	if not self._IsEquipped or self._IsFiring == boolean then
		return
	end

	self._IsFiring = boolean

	if self._IsFiring then
		ModpackManager:TriggerHook("OnFireStart", self)
	else
		ModpackManager:TriggerHook("OnFireEnd", self)
	end

	self._Cleanup:Add(task.spawn(function()
		if self._CanFire and self._IsFiring and self._Ammo.Amount > 0 then
			local Firemode = self._Data.Firemode :: Types.Firemode

			if Firemode == "Semi" then
				self:_Fire(self._Data.Projectiles :: number)
			elseif Firemode == "Burst" then
				for _ = 1, self._Data.Projectiles :: number do
					self:_Fire(1)
				end
			elseif Firemode == "Auto" then
				while self._IsFiring and self._Ammo.Amount > 0 do
					self:_Fire(self._Data.Projectiles :: number)
				end
			end
		end
	end))
end

--[=[
	@class IgneousWeapon

	Represents a weapon instance created by `Igneous.new()`. Contains methods for equipping, unequipping, and controlling weapon firing.
	Weapons automatically handle recoil, spread, ammo management, and trigger modpack hooks at appropriate lifecycle points.
]=]

export type IgneousWeapon = typeof(setmetatable(
	{} :: {
		Name: string,
		Viewmodel: Model,

		Animator: Motus.MotusAnimator,

		Equip: (self: Weapon) -> (),
		Unequip: (self: Weapon) -> (),
		SetFiring: (self: Weapon, bool: boolean) -> (),
	},
	Igneous
))

return Igneous
