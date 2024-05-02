local function IgneousFailed(reason)
	
	warn("Igneous Engine has not been detected.")
	warn(reason)
	
	print("Attempting to find replacement for engine.")
	
	-- Set replacement engine here or is it already configured?
	
	-- THIS IS FOR WHEN IGNEOUS ENGINE HAS TO GO DOWN FOR MAINTENANCE PURPOSES
	
end

local Players = game.Players
local player = Players.LocalPlayer

local RunService = game:GetService("RunService")

local ReplicatedStorage = game.ReplicatedStorage
local CheckIgneousConfig = ReplicatedStorage.Dependencies:FindFirstChild("IgneousConfig")

local Config = nil -- Find BasicConfig

if not CheckIgneousConfig then 
	IgneousFailed([[Couldn't locate config module: "IgneousConfig"]])
else
	Config = require(CheckIgneousConfig)
end

local Storage = ReplicatedStorage.IgneousStorage
local Modules = Storage.Modules
local GeneralInfo = Modules.GeneralInfo
local ViewmodelInfo = Modules.ViewmodelInfo

local Viewmodels = Storage.Viewmodels

-- Check for weapons in userdata

-- DEV -- For now, fists are primary.

local weapon = "Fists" -- Replace with weapon found in data

-- Setup



local weaponInfo = require(ViewmodelInfo[weapon])
Config.BindObjectToCamera(Viewmodels:FindFirstChild("viewmodel_"..weapon), game.Workspace.CurrentCamera)

RunService:BindToRenderStep("UpdatePosition", Enum.RenderPriority.Camera.Value + 1, function()
	Config.updateViewmodelPos()
end)

local viewmodel = game.Workspace.CurrentCamera["viewmodel_"..weapon]

local animList = weaponInfo.AnimList

local IdleAnim
local ShootAnim
local ReloadAnim
local SpecialAnim1

if animList.Idle ~= nil then
	local Anim = Instance.new("Animation")
	Anim.Parent = viewmodel
	Anim.Name = "Idle"
	Anim.AnimationId = animList.Idle
	
	IdleAnim = viewmodel.Animation:LoadAnimation(Anim)
end

if animList.Shoot ~= nil then
	local Anim = Instance.new("Animation")
	Anim.Parent = viewmodel
	Anim.Name = "Shoot"
	Anim.AnimationId = animList.Shoot
	
	ShootAnim = viewmodel.Animation:LoadAnimation(Anim)
end

if animList.Reload ~= nil then
	local Anim = Instance.new("Animation")
	Anim.Parent = viewmodel
	Anim.Name = "Reload"
	Anim.AnimationId = animList.Reload
	
	ReloadAnim = viewmodel.Animation:LoadAnimation(Anim)
end

-- REMEMBER TO ADD SPECIAL ANIMS



-- Main Framework Setup

IdleAnim:Play()