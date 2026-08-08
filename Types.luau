local Motus = require(script.Parent.Parent.Motus)

--[=[
	@type Firemode "Semi" | "Auto" | "Burst"
	@within Igneous
	Represents the three hardcoded weapon firemodes
]=]

export type Firemode = "Semi" | "Auto" | "Burst"

export type Weapon = {
	Name: string,
	Viewmodel: Model,

	Animator: Motus.MotusAnimator,
}

--[=[
	@type LockAxes { X: boolean, Y: boolean, Z: boolean }
	@within Igneous
	Which axes of the viewmodel's rotation should stay frozen relative to the camera.
]=]

export type LockAxes = {
	X: boolean,
	Y: boolean,
	Z: boolean,
}

--[=[
	@type RecoilData { Vertical: number, Horizontal: number }
	@within Igneous
	The magnitude of vertical and horizontal recoil applied per shot.
]=]

export type RecoilData = {
	Vertical: number,
	Horizontal: number,
}

--[=[
	@type RuntimeState { Lock: LockAxes?, Offset: vector?, IsAiming: boolean, Accuracy: number, MaxSpread: number, Range: number, Cooldown: number, Recoil: RecoilData }
	@within Igneous
	Mutable per-weapon state that modpacks can read and change at runtime via
	SetLock, SetOffset, SetAiming, and UpdateData, seeded from the weapon's Data on creation.
]=]

export type RuntimeState = {
	Lock: LockAxes?,
	Offset: vector?,
	IsAiming: boolean,
	Accuracy: number,
	MaxSpread: number,
	Range: number,
	Cooldown: number,
	Recoil: RecoilData,
}

--[=[
	@type StagedReloadStage { Name: string, Duration: number, Cancellable: boolean, AmmoTransfer: number?, CanFireAfter: boolean }
	@within Igneous
	A single stage in a Staged reload. AmmoTransfer moves that many rounds from
	Reserve to Amount when the stage completes; omit it for stages with no ammo
	movement (e.g. racking a bolt). CanFireAfter controls whether the weapon may
	fire once this stage completes, or must wait for a later stage.
]=]

export type StagedReloadStage = {
	Name: string,
	Duration: number,
	Cancellable: boolean,
	AmmoTransfer: number?,
	CanFireAfter: boolean,
}

--[=[
	@type SimpleReloadData { Type: "Simple", Duration: number, Cancellable: boolean }
	@within Igneous
	A single wait-then-fill reload with no intermediate stages.
]=]

export type SimpleReloadData = {
	Type: "Simple",
	Duration: number,
	Cancellable: boolean,
}

--[=[
	@type StagedReloadData { Type: "Staged", Stages: {StagedReloadStage} }
	@within Igneous
	A reload made up of ordered stages, each independently cancellable and
	able to gate firing and ammo transfer.
]=]

export type StagedReloadData = {
	Type: "Staged",
	Stages: { StagedReloadStage },
}

--[=[
	@type ProgressiveReloadData { Type: "Progressive", Duration: number, AmountPerCycle: number, Cancellable: boolean }
	@within Igneous
	A reload that repeats a single cycle, adding AmountPerCycle rounds each
	time, until full or out of reserve. Used for pellet-fed or single-load weapons.
]=]

export type ProgressiveReloadData = {
	Type: "Progressive",
	Duration: number,
	AmountPerCycle: number,
	Cancellable: boolean,
}

--[=[
	@type ReloadData SimpleReloadData | StagedReloadData | ProgressiveReloadData
	@within Igneous
	A weapon's reload configuration, set via Data.Reload.
]=]

export type ReloadData = SimpleReloadData | StagedReloadData | ProgressiveReloadData

--[=[
	@type AmmoData { Amount: number, Max: number, Reserve: number }
	@within Igneous
	A weapon's current ammo state.
]=]

export type AmmoData = {
	Amount: number,
	Max: number,
	Reserve: number,
}

export type DataModule = { any } & { [any]: any }

--[=[
	@type Hooks "OnEquip" | "OnUnequip" | "OnFireStart" | "OnFireEnd" | "OnFire" | "OnProjectileFire" | "OnAmmoChange" | "OnAimStart" | "OnAimEnd" | "OnCameraUpdate"
	@within Igneous
	Notify hooks: dispatched to every modpack that implements them, return values discarded.
]=]

export type Hooks =
	"OnEquip"
	| "OnUnequip"
	| "OnFireStart"
	| "OnFireEnd"
	| "OnFire"
	| "OnProjectileFire"
	| "OnAmmoChange"
	| "OnAimStart"
	| "OnAimEnd"
	| "OnCameraUpdate"

--[=[
	@type GateHooks "OnBeforeFire" | "OnBeforeAim" | "OnBeforeReload"
	@within Igneous
	Veto hooks: any modpack returning false blocks the action.
]=]

export type GateHooks = "OnBeforeFire" | "OnBeforeAim" | "OnBeforeReload"

--[=[
	@type SumHooks "OnCameraUpdate"
	@within Igneous
	Accumulate hooks: every modpack's returned vector is summed.
]=]

export type SumHooks = "OnCameraUpdate"

--[=[
	@class Modpack
	
	Modpacks extend weapon functionality through lifecycle hooks without having to modify the main module.
	Place modpack modules in `game.ReplicatedStorage.Modpacks` and they'll be automatically registered on initialization.
	Each hook is optional - only implement the ones your modpack needs.
]=]

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
	@function OnFireEnd
	@within Modpack
	@param weapon IgneousWeapon
	
	Called when the player stops firing (mouse down/trigger released).
]=]

--[=[
	@function OnFire
	@within Modpack
	@param weapon IgneousWeapon
	
	Called once per trigger-pull fire event, before any projectiles are cast.
	Intended for camera-effect modpacks (recoil impulse, etc.) reacting once per shot event
	rather than once per projectile.
]=]

--[=[
	@function OnProjectileFire
	@within Modpack
	@param weapon IgneousWeapon
	@param origin {position: Vector3, direction: Vector3} -- The origin of the projectile
	@param result RaycastResult? -- Hit result if the raycast struck something, nil otherwise
	
	Called once per projectile cast. Fires multiple times per OnFire for multi-projectile weapons.
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

--[=[
	@function OnAimStart
	@within Modpack
	@param weapon IgneousWeapon
	
	Called when the weapon enters its aiming state via SetAiming.
]=]

--[=[
	@function OnAimEnd
	@within Modpack
	@param weapon IgneousWeapon
	
	Called when the weapon leaves its aiming state via SetAiming.
]=]

--[=[
	@function OnCameraUpdate
	@within Modpack
	@param weapon IgneousWeapon
	@param dt number -- Delta time since the last frame
	@return vector? -- A rotational offset (x, y in degrees, z unused) to add to this frame's total

	Called every PreRender frame. Every modpack's returned offset is summed and applied
	once to the viewmodel/camera. Use this for recoil, sway, breathing shake, ADS lean, etc.
]=]

--[=[
	@function OnBeforeFire
	@within Modpack
	@param weapon IgneousWeapon
	@return boolean? -- Return false to prevent the weapon from firing

	Called before a fire attempt. Any modpack returning false cancels the fire.
]=]

--[=[
	@function OnBeforeAim
	@within Modpack
	@param weapon IgneousWeapon
	@param isAiming boolean -- The aiming state being requested
	@return boolean? -- Return false to prevent the aim state change

	Called before SetAiming changes the weapon's aiming state. Any modpack returning false cancels the change.
]=]

--[=[
	@function OnBeforeReload
	@within Modpack
	@param weapon IgneousWeapon
	@return boolean? -- Return false to prevent the reload from starting

	Called before a reload attempt. Any modpack returning false cancels the reload.
]=]

--[=[
	@function OnReloadStageStart
	@within Modpack
	@param weapon IgneousWeapon
	@param stage StagedReloadStage

	Called when a reload stage begins. Simple and Progressive reloads synthesize
	a single ad-hoc stage so this fires consistently across all three reload types.
]=]

--[=[
	@function OnReloadStageEnd
	@within Modpack
	@param weapon IgneousWeapon
	@param stage StagedReloadStage

	Called when a reload stage completes without being cancelled.
]=]

--[=[
	@function OnReloadCancel
	@within Modpack
	@param weapon IgneousWeapon
	@param stage StagedReloadStage -- The stage that was interrupted

	Called when a reload is cancelled mid-stage.
]=]

export type Modpack = {
	OnEquip: ((weapon: Weapon) -> ())?,
	OnUnequip: ((weapon: Weapon) -> ())?,
	OnFireStart: ((weapon: Weapon) -> ())?,
	OnFireEnd: ((weapon: Weapon) -> ())?,
	OnFire: ((weapon: Weapon) -> ())?,
	OnProjectileFire: ((
		weapon: Weapon,
		origin: { position: Vector3, direction: Vector3 },
		result: RaycastResult?
	) -> ())?,
	OnAmmoChange: ((weapon: Weapon, previous: number, current: number, reason: "reload" | "fired" | "set") -> ())?,
	OnAimStart: ((weapon: Weapon) -> ())?,
	OnAimEnd: ((weapon: Weapon) -> ())?,
	OnCameraUpdate: ((weapon: Weapon, dt: number) -> vector?)?,

	OnBeforeFire: ((weapon: Weapon) -> boolean?)?,
	OnBeforeAim: ((weapon: Weapon, isAiming: boolean) -> boolean?)?,
	OnBeforeReload: ((weapon: Weapon) -> boolean?)?,
	OnReloadStageStart: ((weapon: Weapon, stage: StagedReloadStage) -> ())?,
	OnReloadStageEnd: ((weapon: Weapon, stage: StagedReloadStage) -> ())?,
	OnReloadCancel: ((weapon: Weapon, stage: StagedReloadStage) -> ())?,
}

return {}