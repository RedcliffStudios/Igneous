--!strict

--- @class Motus
--- A lightweight animation handler wrapper for Roblox animator objects
--- Provides simple methods for loading, playing, stopping, and managing animations.
--- Handles caching and cleanup automatically.
local Motus = {}
Motus.__index = Motus

--[=[
	@type AnimationInput Animation | string | number
	@within Motus
	Represents an input that can be used to identify an animation.  
	Can be an `Animation` instance, an asset ID string (`"rbxassetid://1234"`) or a numeric asset ID.
]=]
type AnimationInput = Animation & string & number

--[=[
	@class MotusAnimator
	An animator wrapper used to manage animation playback, loading, and cleanup.
]=]
export type MotusAnimator = typeof(setmetatable(
	{} :: {
		_animator: Animator,
		_animCache: { [string]: AnimationTrack },
		Play: (
			self: MotusAnimator,
			animation: AnimationInput,
			priority: Enum.AnimationPriority?,
			speed: number?,
			weight: number?,
			fadeTime: number?
		) -> AnimationTrack,
		Stop: (self: MotusAnimator, animation: AnimationInput, fadeTime: number?) -> (),
	},
	Motus
))

--[=[
	@private
	@prop _animator Animator
	@within MotusAnimator
	The Animator object used for animation
]=]

--[=[
	@private
	@prop _animCache {[string]: AnimationTrack}
	@within MotusAnimator
	The cache that stores loaded AnimationTracks
]=]

local function InputToID(input: AnimationInput): string
	local ID
	if typeof(input) == "number" then
		ID = "rbxassetid://" .. tostring(input)
	elseif typeof(input) == "Instance" then
		ID = input.AnimationId
	else
		ID = input
	end
	return ID
end

local function MakeAnimation(input: AnimationInput)
	local Animation = Instance.new("Animation")
	Animation.AnimationId = InputToID(input)
	return Animation
end

--[=[
	@function new
	@within Motus
	@param model Model -- The model containing an `Animator` instance.
	@return MotusAnimator -- A new `MotusAnimator` bound to the model's Animator.

	Creates a new `MotusAnimator` object and initializes the animation cache.
]=]
function Motus.new(model: Model): MotusAnimator
	local animator = model:FindFirstChildWhichIsA("Animator", true) :: Animator?
	assert(animator, model.Name .. " needs to have an Animator")
	local self = setmetatable({ _animator = animator, Play = Motus.Play, Stop = Motus.Stop, _animCache = {} }, Motus)
	return self
end

--[=[
	@method Preload
	@within MotusAnimator
	@param Input AnimationInput & { AnimationInput } -- The animation(s) to load and cache.

	Preloads and caches one or multiple animations for future playback.
]=]
function Motus.Preload(self: MotusAnimator, Input: AnimationInput & { AnimationInput })
	if type(Input) == "table" then
		for _, input in pairs(Input) do
			self._animCache[InputToID(input)] = self._animator:LoadAnimation(MakeAnimation(input))
		end
	else
		assert(
			typeof(Input) ~= "string" and typeof(Input) ~= "Instance" and typeof(Input) ~= "number",
			"Input is not a valid AnimationInput"
		)
		self._animCache[InputToID(Input)] = self._animator:LoadAnimation(MakeAnimation(Input))
	end
end

--[=[
	@method Play
	@within MotusAnimator
	@param animation AnimationInput -- The animation to play.
	@param priority Enum.AnimationPriority? -- Optional playback priority.
	@param speed number? -- Optional playback speed multiplier.
	@param weight number? -- Optional blending weight.
	@param fadeTime number? -- Optional fade-in duration.
	@return AnimationTrack -- The loaded or cached AnimationTrack.

	Plays an animation on the attached Animator.  
	Automatically loads and caches it if necessary.
]=]
function Motus.Play(
	self: MotusAnimator,
	animation: AnimationInput,
	priority: Enum.AnimationPriority?,
	speed: number?,
	weight: number?,
	fadeTime: number?
): AnimationTrack
	local animType = typeof(animation)
	local Animation = Instance.new("Animation")
	if animType == "string" then
		assert(string.split(animation, "rbxassetid://")[1] == "", "animation must be a valid asset id string")
	elseif animType == "Instance" then
		assert(animation:IsA("Animation"), "animation must be an Animation instance")
	end
	if speed then
		assert(typeof(speed) == "number", "speed must be a number")
	end
	if fadeTime then
		assert(typeof(fadeTime) == "number", "fadeTime must be a number")
	end
	Animation.AnimationId = InputToID(animation)
	local Key = InputToID(animation)
	local Track = self._animCache[Key]
	if not Track then
		Track = self._animator:LoadAnimation(Animation)
		self._animCache[Key] = Track
	end
	Track.Priority = priority or Track.Priority
	Track:Play(fadeTime or 0, weight or 1, speed or 1)
	return Track
end

--[=[
	@method Stop
	@within MotusAnimator
	@param animation AnimationInput -- The animation to stop.
	@param fadeTime number? -- Optional fade-out duration.

	Stops a single animation if it's currently playing.
]=]
function Motus.Stop(self: MotusAnimator, animation: AnimationInput, fadeTime: number?)
	local animType = typeof(animation)
	if animType == "string" then
		assert(string.split(animation, "rbxassetid://")[1] == "", "animation must be a valid asset id string")
	elseif animType == "Instance" then
		assert(animation:IsA("Animation"), "animation must be an Animation instance")
	end
	if fadeTime then
		assert(typeof(fadeTime) == "number", "fadeTime must be a number")
	end
	local Track = self._animCache[InputToID(animation)]
	if Track then
		Track:Stop(fadeTime or 0)
	end
end

--[=[
	@method StopAll
	@within MotusAnimator
	@param fadeTime number? -- Optional fade-out duration.

	Stops all currently cached and playing animations.
]=]
function Motus.StopAll(self: MotusAnimator, fadeTime: number?)
	if fadeTime then
		assert(typeof(fadeTime) == "number", "fadeTime must be a number")
	end
	for _, track in pairs(self._animCache) do
		track:Stop(fadeTime or 0)
	end
end

--[=[
	@method Destroy
	@within MotusAnimator
	Cleans up all cached animations and destroys them.  
	Stops all currently playing tracks and clears internal memory.
]=]
function Motus.Destroy(self: MotusAnimator)
	self:StopAll(0)
	for _, track in pairs(self._animCache) do
		track:Destroy()
	end
	self._animCache = {}
	self = nil :: any
end

return Motus :: { new: (Model) -> MotusAnimator }
