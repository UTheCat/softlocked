--[[
Utility class for fading from one sound to another.
The fade can be cancelled.

By udev2192
]]--

local RunService = game:GetService("RunService")

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))

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
	local FadeOutQueue = {}
	
	local IsFading = false
	local IsReversing = false
	local FadeRunner
	
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
	Fader.TargetVolume = 1
	
	--[[
	<number>: How long the total fade transition time is.
	]]--
	Fader.TransitionTime = 3
	
	--[[
	<number>: Current fade transition time (from 0-1).
	]]--
	Fader.CurrentTime = 0
	
	--[[
	<Sound>: The current sound instance that is faded in.
	]]--
	Fader.CurrentSound = nil
	
	local function DisconnectLastRunner()
		if FadeRunner ~= nil then
			FadeRunner:Disconnect()
			FadeRunner = nil
		end
	end
	
	--[[
	Stops the current fading transition immediately.
	]]--
	function Fader.Stop()
		DisconnectLastRunner()
		
		IsFading = false
		IsReversing = false
		
		print("stop fade")
	end
	
	--[[
	Starts the fade transition.
	]]--
	local function FadeToNew()
		print("fade")
		
		--local Elapsed = 0
		DisconnectLastRunner()

		FadeRunner = RunService.Heartbeat:Connect(function(Delta)
			local Time
			if IsFading == true then
				Time = Fader.CurrentTime + Delta
			elseif IsReversing == true then
				Time = Fader.CurrentTime - Delta
			end
			
			Time = math.clamp(Time / Fader.TransitionTime, 0, 1)
			local TargetVolume = Fader.TargetVolume

			Fader.CurrentTime = Time
			
			-- Loop through all fading out sounds to fade those out
			-- and fade the new one in.
			local OldSoundVolume = Fader.OldSoundVolume or TargetVolume
			for i, v in pairs(FadeOutQueue) do
				v.Volume = LerpValue(OldSoundVolume, 0, Time)
				print(v.Volume)
			end
			
			local SoundToFadeTo = Fader.CurrentSound
			if SoundToFadeTo ~= nil then
				SoundToFadeTo.Volume = LerpValue(0, TargetVolume, Time)
				print(TargetVolume, ":", SoundToFadeTo.Volume)
			end

			-- Stop and notify once complete
			if Time >= 1 then
				Fader.Stop()

				if SoundToFadeTo ~= nil then
					SoundToFadeTo.Volume = TargetVolume
				end
				Fader.Completed.Fire(FadeOutQueue, SoundToFadeTo)
			elseif Time <= 0 then
				Fader.Stop()
				
				Fader.ReverseCompleted.Fire(FadeOutQueue, SoundToFadeTo)
			else
				return
			end
			
			-- Remove sounds that are fading out from the queue,
			-- then silence them (if the runner got stopped)
			for i, v in pairs(FadeOutQueue) do
				table.remove(FadeOutQueue, i)
				
				v.Volume = 0
			end
		end)
	end
	
	--[[
	Reverses the fade transition if currently being faded.
	]]--
	function Fader.Reverse()
		-- Fade whatever is at the end of the queue back
		-- by removing it from the queue
		-- This is because whatever is at the last index
		-- is the sound most recently trying to fade out
		local Index = #FadeOutQueue
		if Index > 0 then
			-- Set the current sound to whatever
			-- is being reversed back in
			local ReverseSound = table.remove(FadeOutQueue, Index)
			if ReverseSound ~= nil then
				IsReversing = true
			end
			Fader.CurrentSound = ReverseSound
			print(ReverseSound:GetAttribute("Attribution"))
		end
		Index = nil
		
		IsFading = false
	end
	
	--[[
	Fades to the provided sound.
	
	Params:
	Sound <Sound> - The sound instance to fade to.
	]]--
	function Fader.Switch(Sound)
		-- If the sound specified is the one most
		-- recently fading out, and if permitted
		-- to do so, just reverse the fade.
		if Fader.CanReverse == true and Sound ~= nil then
			local FadingOutSound = FadeOutQueue[#FadeOutQueue]
			if Sound == FadingOutSound then
				Fader.Reverse()

				return
			end

			FadingOutSound = nil
		end
		
		-- Schedule the previous sound for fading out
		local CurrentSound = Fader.CurrentSound
		if CurrentSound ~= nil then
			table.insert(FadeOutQueue, CurrentSound)
		end
		CurrentSound = nil
		
		-- Fade in the new sound
		IsReversing = false
		IsFading = true
		
		Fader.CurrentTime = 0
		Fader.CurrentSound = Sound
		FadeToNew()
	end
	
	--[[
	Fires when the fade transition has completed.
	
	Params:
	OldSounds <array> - The sounds that were faded out.
	NewSound - The sound that faded in.
	]]--
	Fader.Completed = Signal.New()
	
	--[[
	Fires when the fade transition has been
	fully cancelled through a reverse fade.
	
	Params:
	OldSounds <array> - The sound that faded back in.
	NewSound - The sound that was cancelled.
	]]--
	Fader.ReverseCompleted = Signal.New()
	
	Fader.OnDisposal = function()
		Fader.Stop()
		
		Fader.Completed.DisconnectAll()
		Fader.ReverseCompleted.DisconnectAll()
	end
	
	return Fader
end

return SoundFader