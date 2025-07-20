local Root = script.Parent
local Events = Root.Events

local Modpack = {}

-- Initialize Logic

function Modpack.Fire(_Coordinate: { Origin: vector, Direction: vector }, Raycast: RaycastResult, Data: {})
	if Raycast then
		local Model = Raycast.Instance:FindFirstAncestorWhichIsA("Model")

		if Model then
			local Humanoid = Model:FindFirstChild("Humanoid")
			if Humanoid then
				if Humanoid.Health > 0 then
					Events.Hit:FireServer(Model.Humanoid, Raycast.Instance, Data)
				end
			end
		end
	end
end

function Modpack.Reload(_Data: {}, _Animation: AnimationTrack) end

return Modpack
