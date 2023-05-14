--[[
Utility class for fading from one sound to another.
The fade can be cancelled.

By udev2192
]]--

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))
local Util = require(UtilRepModules:WaitForChild("Utility"))
local TweenGroup = require(UtilRepModules:WaitForChild("TweenGroup"))

local SoundFader = {}
SoundFader.__index = SoundFader
SoundFader.ClassName = script.Name

local function AssertNumber(Obj, ArgNum)
	assert(typeof(Obj) == "number", "Argument", ArgNum, "must be a number")
end

local function LerpValue(a, b, t)
	return a + (b - a) * t
end

--[[
Lerps the volume between two sounds to a destination volume.

Params:
FadeParams <table> - A table of fading parameters which include:
	OldSound <Sound> - The sound instance to fade from.
	NewSound <Sound> - The sound instance to fade to.
	OldSoundVolume <number> - The volume to fade the old sound away from.
	NewSoundVolume <number> - The volume to fade the new sound to.
	Time <number> - The percentage of the fade (from 0-1).
]]--
function SoundFader.Lerp(FadeParams)
	local Time = math.clamp(FadeParams.Time, 0, 1)
	local OldSound = FadeParams.OldSound
	local NewSound = FadeParams.NewSound
	
	if OldSound ~= nil then
		OldSound.Volume = LerpValue(FadeParams.OldSoundVolume, 0, Time)
	end
	if NewSound ~= nil then
		NewSound.Volume = LerpValue(0, FadeParams.NewSoundVolume, Time)
	end
end

function SoundFader.New()
	local Fader = Object.New(SoundFader.ClassName)
	
	--[[
	Store fading in a queue in case another sound is
	queued for transition while a fade is in progress.
	
	If the fade is requested to be reversed, the sound
	that fades back in will be at the end of the list.
	]]--
	--local FadeOutQueue = {}
	--local OldSoundTweens = {}
	
	-- make sure to fix the music fade out bug with this
	local FadeOutTweens = TweenGroup.New()
	
	--local IsFading = false
	--local IsReversing = false
	--local FadeRunner
	local NewSoundTween
	
	--[[
	<boolean>: Whether or not the fade transition
			   can be cancelled.
	]]--
	Fader.CanReverse = true
	
	--[[
	<number>: A number of reference to the original volume of the sound
			  that is fading out.
	]]--
	Fader.OldSoundVolume = 1
	
	--[[
	<number>: The target volume to fade to.
	]]--
	--Fader.TargetVolume = 1
	
	--[[
	<number>: How long the total fade transition time is.
	]]--
	Fader.SetProperty("TransitionTime", 1, function(Time)
		Fader.TweeningInfo = TweenInfo.new(Time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	end)
	
	--[[
	<number>: Current fade transition time (from 0-1).
	]]--
	--Fader.CurrentTime = 0
	
	--[[
	<Sound>: The current sound instance that is faded in.
	]]--
	Fader.CurrentSound = nil
	
	--Fader.TweeningInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	
	--local function DisconnectLastRunner()
	--	if FadeRunner ~= nil then
	--		FadeRunner:Disconnect()
	--		FadeRunner = nil
	--	end
	--end
	
	--local function StopOldSoundTweens()
	--	for i, v in pairs(OldSoundTweens) do
	--		v:Pause()
	--		v:Destroy()
	--	end
	--	OldSoundTweens = {}
	--end
	
	local function StopNewSoundTween()
		if NewSoundTween ~= nil then
			NewSoundTween:Pause()
			NewSoundTween:Destroy()
			NewSoundTween = nil
		end
	end
	
	--[[
	Stops the current fading transition immediately.
	]]--
	function Fader.Stop()
		StopNewSoundTween()
		FadeOutTweens.KillAll()
	end
	
	--[[
	Starts the fade transition.
	]]--
	--local function FadeToNew(NewSound, IsReverse)	
	--	--local OldSound = Fader.CurrentSound
	--	local CurrentlyFading = NewSound
	--	Fader.CurrentSound = NewSound
	--	Fader.SoundChanged.Fire(NewSound)

	--	local AnimInfo = Fader.TweeningInfo
		
	--	-- Fade in all the old sounds, then fade in the new one
	--	StopOldSoundTweens()
	--	for i, v in pairs(FadeOutQueue) do
	--		table.insert(OldSoundTweens, Util.Tween(v, AnimInfo, {Volume = 0}))
	--	end
		
	--	StopNewSoundTween()
	--	if NewSound then
	--		NewSoundTween = Util.Tween(NewSound, AnimInfo, {Volume = Fader.TargetVolume})
	--	end	
		
	--	-- Wait until the tweening is done or until interrupted
	--	local Elapsed = 0
	--	local FadeTime = AnimInfo.Time
		
	--	local IsInterrupted
	--	while true do
	--		Elapsed += RunService.Heartbeat:Wait()
			
	--		if CurrentlyFading ~= Fader.CurrentSound then
	--			IsInterrupted = true
	--			StopOldSoundTweens()
				
	--			if NewSoundTween then
	--				NewSoundTween:Destroy()
	--				NewSoundTween = nil
	--			end
				
	--			--print("interrupted")
				
	--			break
	--		elseif Elapsed > FadeTime then
	--			IsInterrupted = false
				
	--			break
	--		end
	--	end
		
	--	-- Fire the interrupted event if the tweening was interrupted.
	--	-- Otherwise, fire the corresponding completed event.
	--	if IsInterrupted == true then
	--		Fader.Interrupted.Fire(FadeOutQueue, NewSound)
	--	else
	--		if IsReverse == true then
	--			Fader.ReverseCompleted.Fire(FadeOutQueue, NewSound)
	--		else
	--			Fader.Completed.Fire(FadeOutQueue, NewSound)
	--		end
			
	--		-- Since it's now safe to do so, clear the fade out queue.
	--		StopOldSoundTweens()
	--		FadeOutQueue = {}
	--	end
	--end
	
	--[[
	Reverses the fade transition if currently being faded.
	]]--
	--function Fader.Reverse()
	--	-- Fade whatever is at the end of the queue back
	--	-- by removing it from the queue
	--	-- This is because whatever is at the last index
	--	-- is the sound most recently trying to fade out
	--	local Index = #FadeOutQueue
	--	if Index > 0 then
	--		-- Set the current sound to whatever
	--		-- is being reversed back in
	--		local ReverseSound = table.remove(FadeOutQueue, Index)
	--		if ReverseSound ~= nil then
	--			IsReversing = true
				
	--			-- Add the sound that was trying to fade in originally
	--			-- to the fade out queue, then reverse fade
	--			local CurrentSound = Fader.CurrentSound
	--			if CurrentSound ~= nil then
	--				table.insert(FadeOutQueue, CurrentSound)
	--			end
	--			CurrentSound = nil
				
	--			FadeToNew(ReverseSound, true)
	--		end
	--	end
	--	Index = nil
		
	--	IsFading = false
	--end
	
	--[[
	Fades to the provided sound.
	
	Params:
	Sound <Sound> - The sound instance to fade to.
	]]--
	function Fader.Switch(Sound: Sound?, TargetVolume: number)
		-- If the sound specified is the one most
		-- recently fading out, and if permitted
		-- to do so, just reverse the fade.
		--if Fader.CanReverse == true and Sound ~= nil then
		--	local FadingOutSound = FadeOutQueue[#FadeOutQueue]
		--	if Sound == FadingOutSound then
		--		Fader.Reverse()

		--		return
		--	end

		--	FadingOutSound = nil
		--end
		
		-- Schedule the previous sound for fading out
		--local CurrentSound = Fader.CurrentSound
		--if CurrentSound ~= nil then
		--	table.insert(FadeOutQueue, CurrentSound)
		--end
		--CurrentSound = nil
		
		-- Fade in the new sound
		--IsReversing = false
		--IsFading = true
		
		-- If the new sound is being faded out,
		-- stop that tween
		if Sound then
			FadeOutTweens.Kill(Sound)
		end
		
		--Fader.CurrentTime = 0
		--FadeToNew(Sound, false)
		
		StopNewSoundTween()
		local TweeningInfo = Fader.TweeningInfo
		
		-- Fade out the old
		local OldSound = Fader.CurrentSound
		if OldSound then
			FadeOutTweens.Play(OldSound, TweeningInfo, {Volume = 0}, OldSound, function()
				Fader.SoundFadedOut.Fire(OldSound)
			end)
		end
		
		-- Fade in the new
		Fader.CurrentSound = Sound
		Fader.SoundChanged.Fire(Sound)
		
		if Sound then
			NewSoundTween = TweenService:Create(Sound, TweeningInfo, {Volume = TargetVolume})
			NewSoundTween:Play()
		end
	end
	
	--[[
	Fires when the fade transition has been interrupted.
	
	Params:
	OldSounds <array> - The sounds that tried to fade out.
	NewSound - The sound that tried to fade in.
	]]--
	--Fader.Interrupted = Signal.New()
	
	--[[
	Fires when a sound has been faded out
	
	Params:
	OldSounds <Sound> - The sound that was faded out.
	]]--
	Fader.SoundFadedOut = Signal.New()
	
	--[[
	Fires when the fade transition has completed.
	
	Params:
	OldSounds <array> - The sounds that were faded out.
	NewSound - The sound that faded in.
	]]--
	--Fader.Completed = Signal.New()
	
	--[[
	Fires when the fade transition has been
	fully cancelled through a reverse fade.
	
	Params:
	OldSounds <array> - The sound that faded back in.
	NewSound - The sound that was cancelled.
	]]--
	--Fader.ReverseCompleted = Signal.New()
	
	--[[
	Fires when the primary sound instance has changed.
	
	Params:
	NewSound <Sound> - The new primary sound instance
	]]--
	Fader.SoundChanged = Signal.New()
	
	Fader.OnDisposal = function()
		Fader.Stop()
		
		--Fader.Interrupted.DisconnectAll()
		--Fader.Completed.DisconnectAll()
		--Fader.ReverseCompleted.DisconnectAll()
		Fader.SoundFadedOut.DisconnectAll()
		Fader.SoundChanged.DisconnectAll()
	end
	
	return Fader
end

return SoundFader