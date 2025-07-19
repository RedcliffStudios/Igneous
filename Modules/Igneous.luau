--[[
 ___   _______  __    _  _______  _______  __   __  _______    _______  __    _  _______  ___   __    _  _______ 
|   | |       ||  |  | ||       ||       ||  | |  ||       |  |       ||  |  | ||       ||   | |  |  | ||       |
|   | |    ___||   |_| ||    ___||   _   ||  | |  ||  _____|  |    ___||   |_| ||    ___||   | |   |_| ||    ___|
|   | |   | __ |       ||   |___ |  | |  ||  |_|  || |_____   |   |___ |       ||   | __ |   | |       ||   |___ 
|   | |   ||  ||  _    ||    ___||  |_|  ||       ||_____  |  |    ___||  _    ||   ||  ||   | |  _    ||    ___|
|   | |   |_| || | |   ||   |___ |       ||       | _____| |  |   |___ | | |   ||   |_| ||   | | | |   ||   |___ 
|___| |_______||_|  |__||_______||_______||_______||_______|  |_______||_|  |__||_______||___| |_|  |__||_______|     by Redcliff Studios

]]

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local ReplicatedStorage = game.ReplicatedStorage
local Weapons = ReplicatedStorage.Weapons
local Packages = ReplicatedStorage.Packages

local Trove = require(Packages.Trove)
local Spring = require(Packages.Spring)

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Camera = game.Workspace.CurrentCamera

local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude

local IgneousEngine = {}
IgneousEngine.__index = IgneousEngine

local Modpacks = {}

for _, modpack in ReplicatedStorage.IgneousModpacks:GetChildren() do
	Modpacks[modpack.Name] = require(modpack.Main)
end

local function UpdateModpacks(Function: string, Data: {})
	for _, modpack in Modpacks do
		modpack[Function](table.unpack(Data))
	end
end

local function GetWeaponAsset(Name: string, AssetType: string)
	if Name then
		local Folder = Weapons:FindFirstChild(Name)
		if Folder then
			return Folder[AssetType]
		end
	end

	return
end

function IgneousEngine.CreateWeapon(Name: string)
	local self = setmetatable({
		Viewmodel = GetWeaponAsset(Name, "Viewmodel"):Clone(),
		Data = require(GetWeaponAsset(Name, "Data")),
		Module = require(GetWeaponAsset(Name, "Module")),

		AnimCache = {} :: { [string]: AnimationTrack },

		Cleanup = Trove.new(),

		RecoilSpring = Spring.new(vector.zero, 0.25, 25),

		IsActive = false,
		IsFiring = false,
		IsAiming = false,
		CanFire = true,

		AimCF = CFrame.new(),
		AimOffset = CFrame.new(),
	}, IgneousEngine)

	self:Load()

	return self
end

function IgneousEngine:Load()
	self.AimCF = self.Viewmodel.PrimaryPart.CFrame:ToObjectSpace(self.Viewmodel.AimPart.CFrame):Inverse()
	self.Module:Init(self.Viewmodel, self.Data)

	-- Load Animations
	self:Equip()
	for _, animation in self.Viewmodel.Animations:GetChildren() do
		self:PlayAnimation(animation.Name)
	end
	self:StopAllAnimations()
	self:PlayAnimation("Idle")
	self:Unequip()

	-- Add RunService connections

	self.Cleanup:Add(RunService.PreRender:Connect(function(dt)
		if self.IsAiming then
			self.AimOffset = self.AimOffset:Lerp(
				self.Viewmodel.AimPart.CFrame:ToObjectSpace(self.Viewmodel.PrimaryPart.CFrame),
				self.Data.AimSpeed
			)
		else
			self.AimOffset = self.AimOffset:Lerp(CFrame.new(), self.Data.AimSpeed)
		end
		local Position = self.RecoilSpring:Update(dt)
		Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(Position.y), math.rad(Position.x), 0)
		self.Viewmodel:PivotTo(Camera.CFrame * self.AimOffset)
	end))
end

function IgneousEngine:Unequip()
	self.Viewmodel.Parent = Weapons
	self.IsFiring = false
end

function IgneousEngine:Equip()
	self.IsActive = true
	self.Viewmodel.Parent = game.Workspace
end

function IgneousEngine:Fire(Amount)
	self.CanFire = false
	Params.FilterDescendantsInstances = {Character, self.Viewmodel}
	self:PlayAnimation("Fire")
	self.Module:PlayEffect("Fire")

	self.RecoilSpring:Impulse(
		vector.create(
			math.random(-self.Data.Recoil.Horizontal, self.Data.Recoil.Horizontal),
			self.Data.Recoil.Vertical,
			0
		)
	)

	for i = 1, Amount do
		self.Data.Ammo -= 1
		local Origin = Camera.CFrame.Position
		local Direction = vector.normalize((Camera.CFrame.LookVector + self:GenerateSpread())) * self.Data.Range
		local Raycast = game.Workspace:Raycast(Origin, Direction, Params)

		if Raycast then
			local Model = Raycast.Instance:FindFirstAncestorWhichIsA("Model")

			if Model then
				local Humanoid = Model:FindFirstChild("Humanoid")
				if Humanoid then
					if Humanoid.Health > 0 then
						ReplicatedStorage.Events.Weapon.Hit:FireServer(
							Model.Humanoid,
							Raycast.Instance,
							self.Data
						)
					end
				end
			end
		end
		UpdateModpacks("Fire", { { Origin, Direction }, Raycast, self.Data })
	end

	task.wait(self.Data.Cooldown)
	self.CanFire = true
	return
end

function IgneousEngine:SetFiring(Boolean: boolean)
	if not self.IsActive then
		return
	end

	self.IsFiring = Boolean

	self.Cleanup:Add(task.spawn(function()
		if self.IsFiring and self.CanFire and self.Data.Ammo ~= 0 then
			if self.Data.Firemode == "Semi" then
				self:Fire(self.Data.BulletAmount)
			elseif self.Data.Firemode == "Burst" then
				for i = 1, self.Data.BulletAmount do
					self:Fire(1)
				end
			elseif self.Data.Firemode == "Auto" then
				while self.IsFiring and self.Data.Ammo > 0 do
					self:Fire(self.Data.BulletAmount)
				end
			else
				self.Module:Fire()
			end
		end
	end))
end

function IgneousEngine:SetAiming(Boolean: boolean)
	if not self.IsActive then
		return
	end

	self.IsAiming = Boolean
	self.Module:PlayEffect("Aim")
end

function IgneousEngine:Reload()
	if not self.IsActive or self.Data.Ammo == self.Data.MaxAmmo or self.Data.Reserve == 0 then
		return
	end

	self.IsActive = false

	self.Module:PlayEffect("Reload")
	local Animation = self:PlayAnimation("Reload")
	UpdateModpacks("Reload", { self.Data, Animation })

	task.wait(Animation.Length)

	if self.Data then
		local neededAmmo = self.Data.MaxAmmo - self.Data.Ammo
		if self.Data.Reserve >= neededAmmo then
			self.Data.Ammo = self.Data.MaxAmmo
			self.Data.Reserve -= neededAmmo
		else
			self.Data.Ammo += self.Data.Reserve
			self.Data.Reserve = 0
		end
	end
	self.IsActive = true
end

function IgneousEngine:GenerateSpread()
	local theta = math.random() * 2 * math.pi
	local r = math.tan(math.rad(self.Data.MaxSpread * (1 - self.Data.Accuracy))) * math.sqrt(math.random())

	local x = r * math.cos(theta)
	local y = r * math.sin(theta)

	return vector.create(x, y, 0)
end

function IgneousEngine:PlayAnimation(Name: string)
	if not self.AnimCache[Name] then
		self.AnimCache[Name] =
			self.Viewmodel.AnimationController.Animator:LoadAnimation(self.Viewmodel.Animations[Name])
	end

	self.AnimCache[Name]:Play(0)

	return self.AnimCache[Name]
end

function IgneousEngine:StopAllAnimations()
	for _, animation in self.AnimCache do
		animation:Stop()
	end
end

function IgneousEngine:StopAnimation(Name: string)
	self.AnimCache[Name]:Stop()
end

function IgneousEngine:Destroy()
	self.Cleanup:Destroy()
	self:StopAllAnimations()
	self.Viewmodel:Destroy()

	setmetatable(self, nil)
end

return IgneousEngine
