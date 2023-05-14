-- A utility object that fades from an old sound to a new sound
-- over a provided duration. Inherits from TimeWaiter.

-- By udev2192

local TweenService = game:GetService("TweenService")

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local TimeWaiter = require(UtilRepModules:WaitForChild("TimeWaiter"))

RepModules, UtilRepModules = nil, nil

local SoundFader = {}

function SoundFader.New(Duration)
	local Fader = TimeWaiter.New(Duration)
	
	local OldTween = nil
	local NewTween = nil
	
	-- Original sound volumes before the next animation
	-- Stored in the object's table in case these
	-- need to be modified externally.
	Fader.OldVolume = 0
	Fader.NewVolume = 0
	
	-- The sound to fade from.
	Fader.OldSound = nil
	
	-- The sound to fade to.
	Fader.NewSound = nil
	
	-- If the old sound is paused after animation when
	-- Start() is called.
	-- This also determines if the new sound is paused
	-- when the reverse animation is completed.
	Fader.AutoPause = true
	
	-- If the new sound is played automatically
	-- when Start() is called.
	Fader.AutoPlay = true
	
	-- Fade easing style.
	Fader.EaseStyle = Enum.EasingStyle.Linear
	
	-- Fade easing direction.
	Fader.EaseDirection = Enum.EasingDirection.Out
	
	-- The target volume of the animations.
	Fader.TargetVolume = 1
	
	-- Utility function for getting the sounds to fade.
	-- Returns the OldSound first and then the NewSound
	local function GetSounds()
		return Fader.OldSound, Fader.NewSound
	end
	
	-- Cancels the current tweens.
	local function StopTweens()
		if OldTween ~= nil then
			OldTween:Destroy()
		end
		OldTween = nil
		
		if NewTween ~= nil then
			NewTween:Destroy()
		end
		NewTween = nil
	end
	
	-- Fade-out-all completion listener.
	local function FadedOutAll()
		Fader.Waited.Disconnect(FadedOutAll)

		StopTweens()

		-- Pause all the sounds if told to do so
		if Fader.AutoPause == true then
			local OldSound, NewSound = GetSounds()
			if OldSound ~= nil and NewSound ~= nil then
				OldSound:Pause()
				NewSound:Pause()
			end
			OldSound, NewSound = nil, nil
		end
	end
	
	-- Reverse animation completion listener.
	local function OnAnimationReverse()
		Fader.Waited.Disconnect(OnAnimationReverse)
		
		StopTweens()
		
		-- Pause the new sound if told to do so
		if Fader.AutoPause == true then
			local NewSound = Fader.NewSound
			if NewSound ~= nil then
				NewSound:Pause()
			end
			NewSound = nil
		end
	end
	
	-- Animation completion listener.
	-- This is where auto pause/play is handled.
	local function OnWaitComplete()
		Fader.Waited.Disconnect(OnWaitComplete)
		
		StopTweens()
		
		-- Do automated pausing
		if Fader.AutoPause == true then
			local OldSound = Fader.OldSound
			if OldSound ~= nil then
				OldSound:Pause()
			end
			OldSound = nil
		end
	end
	
	-- Constructs a new TweenInfo from the properties in the fader.
	function Fader.GetTweenInfo()
		return TweenInfo.new(Fader.Duration, Fader.EaseStyle, Fader.EaseDirection)
	end
	
	-- Cancels the objects used to mark completion.
	-- This stops all animation.
	function Fader.DisconnectCompletion()
		Fader.Cancel()
		
		local WaitedSignal = Fader.Waited
		if WaitedSignal ~= nil then
			WaitedSignal.Disconnect(FadedOutAll)
			WaitedSignal.Disconnect(OnAnimationReverse)
			WaitedSignal.Disconnect(OnWaitComplete)
		end
		
		WaitedSignal = nil
		StopTweens()
	end
	
	-- Cancels fade completion by reversing the direction
	-- of the fade. This makes it fade back to the
	-- old sound.
	function Fader.CancelAnimation()
		-- Disconnect completion stuff
		Fader.DisconnectCompletion()
		
		-- Do reverse animation
		local OldSound, NewSound = GetSounds()
		
		local Info = Fader.GetTweenInfo()
		if OldSound ~= nil then
			OldTween = TweenService:Create(OldSound, Info, {Volume = Fader.OldVolume})
			OldTween:Play()
		end
		
		if NewSound ~= nil then
			NewTween = TweenService:Create(NewSound, Info, {Volume = 0})
			NewTween:Play()
		end
		
		Fader.Waited.Connect(OnAnimationReverse)
		
		Fader.Wait()
	end
	
	-- Starts the fade from the old sound to the new sound.
	-- Argument 1 is a number that overrides the destination volume
	-- of the NewSound.
	function Fader.StartAnimation()
		Fader.DisconnectCompletion()
		
		-- Store volumes, then do animation
		local TargetVolume = Fader.TargetVolume
		local OldSound, NewSound = GetSounds()

		local Info = Fader.GetTweenInfo()
		if OldSound ~= nil then
			print("fade old sound")
			Fader.OldVolume = OldSound.Volume
			OldTween = TweenService:Create(OldSound, Info, {Volume = 0})
			OldTween:Play()
		end

		if NewSound ~= nil then
			print("fade new sound")
			
			local NewVolume = TargetVolume or NewSound.Volume
			Fader.NewVolume = NewVolume
			
			-- Start from 0% volume, then resume (to not affect TimePosition)
			NewSound.Volume = 0
			if Fader.AutoPlay == true then
				NewSound:Resume()
			end
			
			NewTween = TweenService:Create(NewSound, Info, {Volume = NewVolume})
			NewTween:Play()
		end
		
		-- Completion is marked when the .Waited signal fires.
		Fader.Waited.Connect(OnWaitComplete)
		
		Fader.Wait()
	end
	
	-- Fades out all sounds stored in the object table.
	function Fader.FadeOutAll()
		Fader.DisconnectCompletion()
		
		local OldSound, NewSound = GetSounds()
		
		if OldSound ~= nil and NewSound ~= nil then
			-- Store volumes and fade out all sounds
			Fader.OldVolume = OldSound.Volume
			Fader.NewVolume = NewSound.Volume
			
			local Info = Fader.GetTweenInfo()
			local VolumeTable = {Volume = 0}
			
			OldTween = TweenService:Create(OldSound, Info, VolumeTable)
			NewTween = TweenService:Create(NewSound, Info, VolumeTable)
			
			Fader.Waited.Connect(FadedOutAll)
			
			Fader.Wait()
		end
	end
	
	Fader.AddDisposalListener(function()
		Fader.DisconnectCompletion()
	end)
	
	return Fader
end

return SoundFader