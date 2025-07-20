local Root = script.Parent

Root.Events.Hit.OnServerEvent:Connect(function(player, humanoid, instance, data)
	if instance.Name == "Head" then
		humanoid:TakeDamage(data.Damage.Head)
	elseif instance.Name == "UpperTorso" or instance.Name == "LowerTorso" or instance.Name == "HumanoidRootPart" then
		humanoid:TakeDamage(data.Damage.Torso)
	elseif instance.Name == "Handle" then
		if instance.Parent:IsA("Accessory") then
			if
				instance.Parent.AccessoryType == Enum.AccessoryType.Hair
				or instance.Parent.AccessoryType == Enum.AccessoryType.Hat
			then
				humanoid:TakeDamage(data.Damage.Head)
			else
				humanoid:TakeDamage(data.Damage.Armor)
			end
		end
	else
		humanoid:TakeDamage(data.Damage.Limbs)
	end
end)
