--!strict

-- Stamps a bullet hole decal onto whatever a projectile hits. Holes are kept in a
-- fixed-size ring so sustained fire cannot flood the workspace with parts, and holes on
-- unanchored parts are welded so they travel with whatever they hit.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Packages.Igneous.Types)

type Weapon = Types.Weapon

local HOLE_LIFETIME = 8
local MAX_HOLES = 64
local SURFACE_OFFSET = 0.005
local HEAT_FADE = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local HoleTemplate = script:WaitForChild("Resources"):WaitForChild("Hole") :: BasePart

local Container = Instance.new("Folder")
Container.Name = "IgneousBulletHoles"
Container.Parent = Workspace

local ActiveHoles: { BasePart } = {}

local Modpack = {}

Modpack.Name = "BulletHoles"
Modpack.Priority = 0

function Modpack.OnProjectileFire(weapon: Weapon, origin: Types.ProjectileOrigin, result: RaycastResult?)
	if not result then
		return
	end

	local Hole = HoleTemplate:Clone()
	local Heat = Hole:FindFirstChild("Heat") :: Decal
	local Mark = Hole:FindFirstChild("Decal") :: Decal

	-- Rotating the mark stops repeated hits from stamping an obviously identical decal.
	Mark.Rotation = math.random(0, 360)
	Hole.CFrame = CFrame.lookAt(result.Position + result.Normal * SURFACE_OFFSET, result.Position + result.Normal)
	Hole.Parent = Container

	TweenService:Create(Heat, HEAT_FADE, { Transparency = 1 }):Play()

	local HitPart = result.Instance
	if HitPart and HitPart:IsA("BasePart") and not HitPart.Anchored then
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Hole
		Weld.Part1 = HitPart
		Weld.Parent = Hole
	end

	table.insert(ActiveHoles, Hole)

	Hole.Destroying:Once(function()
		local Index = table.find(ActiveHoles, Hole)
		if Index then
			table.remove(ActiveHoles, Index)
		end
	end)

	if #ActiveHoles > MAX_HOLES then
		ActiveHoles[1]:Destroy()
	end

	Debris:AddItem(Hole, HOLE_LIFETIME)
end

return Modpack
