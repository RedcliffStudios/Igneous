local Root = script.Parent
local Resources = Root.Resources

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Info = TweenInfo.new(2)

local Modpack = {}

-- Initialize Logic

function Modpack.Fire(Coordinate: { Origin: vector, Direction: vector }, Raycast: RaycastResult, Data: {})
	if Raycast then
		local Hole = Resources.Hole:Clone()
		Hole.CFrame = CFrame.new(Raycast.Position, Raycast.Position + Raycast.Normal)

		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Hole
		Weld.Part1 = Raycast.Instance

		Weld.Parent = Raycast.Instance
		Hole.Parent = Raycast.Instance

		TweenService:Create(Hole.Heat, Info, { Transparency = 1 }):Play()
		Debris:AddItem(Hole, 20)
	end
end

function Modpack.Reload(Data: {}, Animation: AnimationTrack) end

return Modpack
