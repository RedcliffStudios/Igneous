--[[
 ___   _______  __    _  _______  _______  __   __  _______    _______  __    _  _______  ___   __    _  _______ 
|   | |       ||  |  | ||       ||       ||  | |  ||       |  |       ||  |  | ||       ||   | |  |  | ||       |
|   | |    ___||   |_| ||    ___||   _   ||  | |  ||  _____|  |    ___||   |_| ||    ___||   | |   |_| ||    ___|
|   | |   | __ |       ||   |___ |  | |  ||  |_|  || |_____   |   |___ |       ||   | __ |   | |       ||   |___ 
|   | |   ||  ||  _    ||    ___||  |_|  ||       ||_____  |  |    ___||  _    ||   ||  ||   | |  _    ||    ___|
|   | |   |_| || | |   ||   |___ |       ||       | _____| |  |   |___ | | |   ||   |_| ||   | | | |   ||   |___ 
|___| |_______||_|  |__||_______||_______||_______||_______|  |_______||_|  |__||_______||___| |_|  |__||_______|     by notkaif

]]

local module = {

	igneous = true;

	-- Project Info

	ProjectSeries = "IgneousMain";
	ProjectName = "IgneousTest";
	ProjectVersion = "Alpha v1.1";

	-- Config

	ConfigVersion = 1.0;
	IgneousVersion = "ModernIgneous vAlpha";
	DevMode = {
		437494048; -- notkaif
	};

}

local ReplicatedStorage = game.ReplicatedStorage
local Storage = ReplicatedStorage.IgneousStorage
local Modules = Storage.Modules
local GeneralInfo = Modules.GeneralInfo
local ViewmodelInfo = Modules.ViewmodelInfo

-- FrameworkMain functions

function module.BindObjectToCamera(Object, Camera)

	-- Remove any previous viewmodels
	for i, v in pairs(Camera:GetChildren()) do
		if string.sub(v.Name, 1, 11) == "viewmodel_" then
			v:Destroy()
		end
	end

	local Viewmodel = Object:Clone()
	Viewmodel.Parent = Camera

	function module.updateViewmodelPos()
		Viewmodel:SetPrimaryPartCFrame(Camera.CFrame) -- Add on recoil should probably move to main framework script.
	end

end

return module