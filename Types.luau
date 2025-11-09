local Motus = require(script.Parent.Parent.Motus)

--[=[
	@type Firemode "Semi" | "Auto" | "Burst"
	@within Igneous
	Represents the three hardcoded weapon firemodes
]=]

export type Firemode = "Semi" | "Auto" | "Burst"

--[=[
	@class Modpack
	
	Modpacks extend weapon functionality through lifecycle hooks without having to modify the main module
	Place modpack modules in `game.ReplicatedStorage.Modpacks` and they'll be automatically registered on initialization
	Each hook is optional - only implement the ones your modpack needs
]=]

export type Modpack = {
	OnEquip: ((weapon: Weapon) -> ())?,
	OnUnequip: ((weapon: Weapon) -> ())?,
	OnFireStart: ((weapon: Weapon) -> ())?,
	OnFireEnd: ((weapon: Weapon) -> ())?,
	OnFire: ((weapon: Weapon, origin: { position: Vector3, direction: Vector3 }, result: RaycastResult?) -> ())?,
	OnAmmoChange: ((weapon: Weapon, previous: number, current: number, reason: "reload" | "fired" | "set") -> ())?,
}

--[=[
	@function OnEquip
	@within Modpack
	@param weapon IgneousWeapon
	
	Called when a weapon is equipped by the player.
]=]

--[=[
	@function OnUnequip
	@within Modpack
	@param weapon IgneousWeapon
	
	Called when a weapon is unequipped by the player.
]=]

--[=[
	@function OnFireStart
	@within Modpack
	@param weapon IgneousWeapon
	
	Called when the player starts firing (mouse down/trigger pressed).
]=]

--[=[
	@function OnFire
	@within Modpack
	@param weapon IgneousWeapon
	@param origin {position: Vector3, direction: Vector3} -- The origin of the projectile
	@param result RaycastResult? -- Hit result if the raycast struck something, nil otherwise
	
	Called each time a projectile is fired.
]=]

--[=[
	@function OnFireEnd
	@within Modpack
	@param weapon IgneousWeapon
	
	Called when the player stops firing (mouse down/trigger released).
]=]

--[=[
	@function OnAmmoChange
	@within Modpack
	@param weapon IgneousWeapon
	@param previous number -- The previous ammo count
	@param current number -- The new ammo count
	@param reason "reload" | "fired" | "set" -- Why the ammo changed
	
	Called whenever the weapon's ammo count changes.
]=]

export type Weapon = {
	Name: string,
	Viewmodel: Model,

	Animator: Motus.MotusAnimator,
}

export type Hooks = "OnEquip" | "OnUnequip" | "OnFireStart" | "OnFireEnd" | "OnFire" | "OnAmmoChange"

export type AmmoData = {
	Amount: number,
	Max: number,
	Reserve: number,
}

export type DataModule = { any } & { [any]: any }

return {}
