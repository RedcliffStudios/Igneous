local Module = {
	Data = nil,
	Viewmodel = nil,
}

function Module:Init(Viewmodel, Data)
	Module.Viewmodel = Viewmodel
	Module.Data = Data
end

function Module:Fire() end

function Module:PlayEffect(Effect: string, AimInfo: boolean)
	if Effect == "Fire" then
	elseif Effect == "Reload" then
	elseif Effect == "Aim" then
		if AimInfo then
		else
		end
	end
end

return Module
