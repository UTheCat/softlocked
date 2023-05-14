-- Provides an object that is used to play background music.

-- This is the successor of the old MusicPlayer. This includes support
-- for a set music url and the usage of music zones.

-- Thanks to Jukereise for the concept of the music zones
-- (Meaning music zones are in the form of models)

-- This version revampes the coding from the last version of the BGM player
-- because it got way too messy

-- By udev2192

local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local Adapters = RepModules:WaitForChild("Adapters")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Hitbox = require(Adapters:WaitForChild("Hitbox"))
local InstCollector = require(Adapters:WaitForChild("InstanceCollector"))

local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))
local TimeWaiter = require(UtilRepModules:WaitForChild("TimeWaiter"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local SoundFader = require(script.Parent:WaitForChild("SoundFader"))

local MusicPlayer = {}

-- The default BGM url.
MusicPlayer.DefaultURL = ""

-- The search keyword of a music zone.
MusicPlayer.MUSIC_ZONE_KEYWORD = "^_MusicZone"

-- The name of the sound instance in a music zone.
MusicPlayer.SOUND_NAME = "Sound"

-- The name of the parts folder instance in a music zone.
MusicPlayer.PARTS_FOLDER_NAME = "Parts"

-- The name of the "attribution" sound attribute to use when citing sounds.
MusicPlayer.ATTRIBUTION_INDEX = "Attribution"

MusicPlayer.START_TIME_ATTRIBUTE = "StartTime"
MusicPlayer.TARGET_VOLUME_ATTRIBUTE = "TargetVolume"

-- Where to look for music zones.
MusicPlayer.MusicZoneLocation = workspace:WaitForChild("Areas")

-- Music modes that are used to determine the behavior
-- that triggers music playback.
MusicPlayer.MusicMode = {
	-- Play by using a set sound URL
	ByURL = 0,

	-- Play by using sound URLs from music zones.
	ByMusicZone = 1
}

-- Gets the sound information by asset id.
local function GetInfoById(Id)
	local Success, Result = pcall(function()
		return MarketplaceService:GetProductInfo(Id)
	end)

	if Success == true then
		return Result
	else
		return ""
	end
end

local function IsPart(Part)
	return Util.IsInstance(Part) and Part:IsA("BasePart")
end

local function IsSoundLoaded(Sound)
	return Sound.IsLoaded == true and Sound.TimeLength > 0
end

local function IsSoundURL(URL)
	return URL ~= nil and typeof(URL) == "string" and URL ~= ""
end

local function FadeSound(Sound, Vol, Dur)
	assert(typeof(Sound) == "Instance" and Sound:IsA("Sound"), "Argument 1 must be a sound instance.")

	return Util.Tween(Sound, TweenInfo.new(Dur, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Volume = Vol})
end

local function IsMusicZone(Inst)
	return Util.IsInstance(Inst) and (string.match(Inst.Name, MusicPlayer.MUSIC_ZONE_KEYWORD) ~= nil)
end

local HitStatus = Hitbox.HitStatus
Hitbox = nil

-- Constructs a new sound fader object that fades
-- from the old sound to the new sound over the
-- provided duration.
--function MusicPlayer.CreateFader(OldSound, NewSound, FadeTime)
--	local Fader = TimeWaiter.New()

--	local OldTween = nil
--	local NewTween = nil

--	-- Reverses the fade direction to go back to the old sound.
--	function Fader.Cancel()

--	end

--	-- Starts the fading
--	function Fader.Start()

--	end

--	-- Fades out both sounds.
--	function Fader.FadeOut()

--	end
--end

--[[
Gets a sound instance's attribution.

Params:
Sound <Sound> - The sound instance to retrieve
				the attribution from.
]]--
function MusicPlayer.GetAttributionBySound(Sound)
	assert(Sound ~= nil, "Argument 1 is missing.")
	
	-- See if there's an "Attribution" attribute on
	-- the sound instance
	local AttributionAttr = Sound:GetAttribute(MusicPlayer.ATTRIBUTION_INDEX)
	if AttributionAttr ~= nil then
		return tostring(AttributionAttr)
	end

	-- If all else fails, find the id in the URL string, if needed
	-- Conversion to a number is needed because
	-- MarketplaceService:GetProductInfo()
	-- only accepts asset IDs.
	local Url = Sound.SoundId
	if typeof(Url) == "string" then
		Url = string.split(Url, "://")[2]
		if Url ~= nil then
			Url = tonumber(Url)
			return GetInfoById(Url)
		end
	end
	
	return nil
end

function MusicPlayer.New()
	local Obj = Object.New("ClientMusicPlayer")
	local AssetInfo = {} -- Asset info override table
	local CurrentMusicZones = {}

	local SoundVolumes = {} -- Sound instance volumes
	local TimePositions = {} -- Sound instance time positions

	local ZoneParts = {} -- Music zone BaseParts
	local CurrentHitbox
	local CurrentMusicZone

	local FadingInSound
	local FadingOutSound

	local FinishedFading = true
	
	-- If the current fader is fading to a new BGM
	local IsFadingIn = false
	
	-- If the current fader will do a reverse animation.
	-- If the next Obj.SoundInstance will be the FadingOutSound,
	-- this will be set to true so that the cancel animation
	-- can be played.
	local IsReverseFading = false

	local CurrentFader = SoundFader.New() -- The current sound fader
	local ZoneCollector
	
	-- The volume of the previous sound
	local PreviousVolume

	Obj.SoundInstance = nil
	Obj.IsLoaded = false

	-- By default, the name of the sound asset
	-- that was just loaded.
	Obj.AssetInfo = ""

	-- The length of the music transition in seconds.
	Obj.FadeTime = 1

	-- If the audio plays the new URL as soon as it's changed
	Obj.Autoplay = true
	
	-- If the fading allows for an animation that
	-- reverses the sound change when the old sound
	-- is trying to be played while it's being
	-- faded out.
	Obj.AllowReversing = true

	-- The most recent method of music playback.
	Obj.LastMusicMode = MusicPlayer.MusicMode.ByURL
	
	-- The currently playing sound URL

	-- Waits for the currently fading sounds to stop fading.
	-- Returns if the fade completed.
	local function WaitForSoundFade(SoundToFadeIn, FadeTime)
		FadingInSound = SoundToFadeIn

		local Elapsed = 0

		while FadingInSound == SoundToFadeIn do
			Elapsed += RunService.Heartbeat:Wait()

			if Elapsed > FadeTime then
				FadingInSound = nil
				return true
			end
		end

		FadingInSound = nil

		return false
	end

	local function UpdateInfoInternally(Sound)
		local Info = AssetInfo[Sound.SoundId]
		
		if Info == nil then
			-- Request the info through other methods
			-- if not overriden
			Info = MusicPlayer.GetAttributionBySound(Sound)
		end
		Info = Info or ""
		
		Obj.AssetInfo = Info
		Object.FireCallback(Obj.AssetInfoChanged, Info)
		return Info
	end

	-- Fade completion listener.
	--local function OnFadeComplete()
	--	if CurrentFader ~= nil then
	--		CurrentFader.Dispose()
	--		print("Disposing current fader from completion")
	--	end
	--end

	-- Toggles the fader completion listener that
	-- disposes the fader itself.
	local function ToggleFaderWaitListener(IsListening)
		if CurrentFader ~= nil then
			local WaitSignal = CurrentFader.Waited

			if IsListening == true then
				WaitSignal.Connect(OnFadeComplete)
			else
				WaitSignal.Disconnect(OnFadeComplete)
			end
		end
	end

	-- Toggles the music fading.
	local function ToggleFader(IsFading, FadeTime, OldSound, NewSound)
		if IsFading == true then
			IsFadingIn = true

			CurrentFader = SoundFader.New(FadeTime)
			CurrentFader.OldSound = OldSound
			CurrentFader.NewSound = NewSound

			ToggleFaderWaitListener(true)
			CurrentFader.StartAnimation()
		else
			IsFadingIn = false

			if CurrentFader ~= nil then
				ToggleFaderWaitListener(true)
				CurrentFader.CancelAnimation()
			end
		end
	end

	-- Fades out the old sound instance
	local function FadeOutSound(DestroyOldSound, SoundToFadeIn)
		local OldSound = Obj.SoundInstance
		local FadeTime = Obj.FadeTime or 1

		if OldSound ~= nil then
			coroutine.wrap(function()
				local IsTweenCompleted = false
				if FadeTime > 0 then
					local Tween = FadeSound(OldSound, 0, FadeTime)

					local Elapsed = 0
					while SoundToFadeIn == FadingInSound do
						Elapsed += RunService.Heartbeat:Wait()

						if Elapsed > FadeTime then
							IsTweenCompleted = true
							break
						end
					end

					Tween:Destroy()
				end

				if DestroyOldSound == true then
					OldSound:Destroy()
				else
					if IsTweenCompleted == true then
						print("pause sound")
						OldSound:Pause()
					end
				end
				OldSound = nil
			end)()
		end
	end

	-- Disposes the current sound fader.
	local function DisposeSoundFader()
		if CurrentFader ~= nil then
			CurrentFader.Dispose()
		end
		CurrentFader = nil
	end
	
	-- Listener for sound fade completion.
	-- Pause old bgm playback only on fade completion to ensure
	-- that reversing it mid-way is possible
	local function OnFadeComplete(OldSounds)
		for i, OldSound in pairs(OldSounds) do
			OldSound:Pause()

			--OldSound.TimePosition = TimePositions[OldSound] or 0
			--OldSound.Volume = SoundVolumes[OldSound] or 0

			--print("Stopped at volume", OldSound.Volume)

			TimePositions[OldSound] = nil
			SoundVolumes[OldSound] = nil
		end
	end
	
	CurrentFader.ReverseCompleted.Connect(OnFadeComplete)
	CurrentFader.Completed.Connect(OnFadeComplete)

	-- Fades to a new sound instance.
	-- If no sound instances are provided, the music fades out.
	-- This function returns the old sound instance for convenience
	function Obj.FadeToSound(NewSound, DestroyOldSound)
		local OldSound = Obj.SoundInstance
		
		-- If the new sound is the fading-out sound, set IsReverseFading
		-- to true so the cancel animation can be played (if enabled).
		-- Otherwise, proceed to switching
		if Obj.AllowReversing == true and FadingOutSound ~= nil and NewSound == FadingOutSound then
			print("reverse fade")
			FadingInSound = nil
			FadingOutSound = nil
			IsReverseFading = true
		else
			-- Destroys the old sound if told
			local function DestroyOld()
				if OldSound ~= nil and DestroyOldSound == true then
					OldSound:Destroy()
				end
			end

			-- Resets the old sound properties
			local function ResetOld()
				if OldSound ~= nil then
					OldSound:Pause()

					OldSound.TimePosition = TimePositions[OldSound] or 0
					OldSound.Volume = SoundVolumes[OldSound] or 0
					
					print(OldSound.Volume)

					TimePositions[OldSound] = nil
					SoundVolumes[OldSound] = nil
				end
			end

			if NewSound ~= nil then
				-- Update the sound instance if the new sound doesn't match
				-- the one currently playing
				local URL = NewSound.SoundId
				if URL ~= Obj.CurrentSoundId then
					Obj.CurrentSoundId = URL

					-- Update sound instance
					Obj.SoundInstance = NewSound

					-- Update song citation
					coroutine.wrap(UpdateInfoInternally)(NewSound)

					-- Initialize music transition
					local FadeTime = Obj.FadeTime or 1
					
					local TargetVolume = tonumber(NewSound:GetAttribute(MusicPlayer.TARGET_VOLUME_ATTRIBUTE) or 1) or 1
											* (Obj.MasterVolume or 1)
					local StartTime = tonumber(NewSound:GetAttribute(MusicPlayer.START_TIME_ATTRIBUTE) or 0) or 0

					if FadeTime > 0 then
						
						
						--DisposeSoundFader()

						-- Store the sound's information
						-- (only if the sound info doesn't exist currently)
						
						
						-- Fade to the new sound
						CurrentFader.TransitionTime = FadeTime
						CurrentFader.OldSoundVolume = PreviousVolume or TargetVolume
						CurrentFader.TargetVolume = TargetVolume
						
						PreviousVolume = TargetVolume
						
						NewSound.Volume = 0
						--NewSound.TimePosition = StartTime
						NewSound:Resume()
						CurrentFader.Switch(NewSound)

						---- Fade to the new sound instance
						----CurrentFader = SoundFader.New(FadeTime)
						----print(OldSound and OldSound.SoundId, NewSound and NewSound.SoundId)
						----CurrentFader.OldSound = OldSound
						----CurrentFader.NewSound = NewSound
						
						---- Turn off auto-pause/play because it interferes witht the
						---- reverse logic (implement later lol)
						----CurrentFader.AutoPause = false
						----CurrentFader.AutoPlay = false
						
						--CurrentFader.TargetVolume = TargetVolume * (Obj.MasterVolume or 1)
						
						--IsReverseFading = false
						--CurrentFader.StartAnimation()

						--print("Target volume:", TargetVolume)

						---- Wait for fading to be completed or interrupted
						--local IsCompleted = false
						--local Elapsed = 0

						---- Set fade debounce values
						--FadingOutSound = OldSound
						--FadingInSound = NewSound

						---- Wait until the fade completes or a reverse fade
						---- is requested to cancel the animation
						--while IsReverseFading == false and OldSound == FadingOutSound and NewSound == FadingInSound do
						--	Elapsed += RunService.Heartbeat:Wait()

						--	if Elapsed > FadeTime then
						--		IsCompleted = true
						--		break
						--	end
						--end
						
						---- If reversing is disabled, automatically
						---- mark completion so that it gets paused
						---- and/or destroyed no matter what.
						--if Obj.AllowReversing == true then
						--	IsCompleted = true
						--end

						---- Reset the old sound instance and forget the desired volume
						---- and starting time position if fading completed, otherwise,
						---- reverse the fading so it goes back to the old sound
						--if OldSound ~= nil then
						--	if IsCompleted == true then
						--		-- Reset the old sound
						--		ResetOld()
						--		DestroyOld()

						--		FadingOutSound, FadingInSound = nil, nil
						--		print("fade completed")
						--	elseif IsReverseFading == true then
						--		IsReverseFading = false -- Mark false because the cancel animation is starting
						--		CurrentFader.OldVolume = SoundVolumes[OldSound] or 0.5
						--		CurrentFader.CancelAnimation()
						--	end
						--end
					else
						-- Immediately switch
						if OldSound ~= nil then
							OldSound:Pause()
							--TimePositions[OldSound] = nil
						end

						--TimePositions[NewSound] = NewSound.TimePosition
						NewSound.Volume = TargetVolume
						NewSound.TimePosition = StartTime
						NewSound:Resume()
						Obj.SoundInstance = NewSound

						ResetOld()
						DestroyOld()
					end
				end
			else
				print("no sound")
				if OldSound ~= nil then
					Obj.SoundInstance = nil
					Obj.CurrentSoundId = ""

					ResetOld()
					DestroyOld()
				end
			end
		end

		return OldSound
	end

	-- Fades to a new sound by URL
	-- If URL is nil, the sound will fade out and stop
	function Obj.FadeToURL(URL, DestroyOldSound)
		Obj.LastMusicMode = MusicPlayer.MusicMode.ByURL
		
		local NewSound = nil
		if URL ~= nil and URL ~= "" then
			NewSound = Instance.new("Sound")
			NewSound.SoundId = Util.FormatAssetId(URL)
			NewSound.Volume = Obj.URLVolume or 1
			NewSound.Looped = true
			NewSound.TimePosition = 0
			NewSound.Parent = script

			-- Wait for the new sound to load
			if NewSound.IsLoaded == false then
				NewSound.Loaded:Wait()
			end
		end
		
		-- Set to destroy the old sound automatically if the
		-- last music mode was by URL
		local DestroysLastSound = false
		if DestroyOldSound == false then
			if Obj.LastMusicMode == MusicPlayer.MusicMode.ByURL then
				DestroysLastSound = true
			end
		end

		-- If there's a new sound and it loaded, play it
		local OldSound = nil
		if NewSound ~= nil and IsSoundLoaded(NewSound) == true then
			OldSound = Obj.FadeToSound(NewSound, DestroysLastSound)
		end
	end

	--local function Obj.FadeToURL(URL, IsDestroyingOld)
	--	local OldSound = Obj.SoundInstance

	--	if Obj.FadeTime > 0 then
	--		FinishedFading = false

	--		if IsSoundURL(URL) == true then
	--			local NewSound = Instance.new("Sound")
	--			Obj.SoundInstance = NewSound
	--			NewSound.SoundId = URL
	--			NewSound.Volume = 0
	--			NewSound.Looped = true
	--			NewSound.Parent = script

	--			-- Fade out the old sound
	--			--FadeOutSound(IsDestroyingOld)

	--			-- Fade in the new sound once it loads
	--			coroutine.wrap(function()
	--				if NewSound.IsLoaded == false then
	--					NewSound.Loaded:Wait()
	--				end

	--				if IsSoundLoaded(NewSound) then
	--					-- Update asset information
	--					coroutine.wrap(UpdateInfoInternally)(URL)

	--					-- Fade in
	--					local FadeTime = Obj.FadeTime or 1
	--					ToggleFader(true, FadeTime, OldSound, NewSound)


	--					NewSound:Play()
	--					local Tween = FadeSound(NewSound, Obj.Volume, FadeTime)

	--					local CompletedFade = WaitForSoundFade(NewSound, FadeTime)
	--					Tween:Destroy()
	--					Tween = nil

	--					if CompletedFade == true then
	--						FinishedFading = true

	--						print("fade completion true")
	--					else
	--						print("fade completion false")

	--						-- Fade out the sound if the fade didn't complete.
	--						ToggleFader(false)

	--						--FadeSound(NewSound, 0, FadeTime)

	--						--NewSound:Pause()
	--						if IsDestroyingOld == true then
	--							NewSound:Destroy()
	--						end
	--					end
	--				else
	--					NewSound:Destroy()
	--					warn("Failed to load sound: " .. URL)
	--				end

	--				NewSound = nil
	--			end)()
	--		else
	--			Obj.SoundInstance = nil
	--			FadeOutSound(IsDestroyingOld)
	--		end

	--		FinishedFading = true

	--		--if FinishedFading == true then

	--		--end
	--	else
	--		-- Immediately switch
	--		if IsSoundURL(URL) == true then
	--			local Sound = Obj.SoundInstance
	--			if Sound == nil then
	--				Sound = Instance.new("Sound")
	--			end
	--			Sound.SoundId = URL
	--			Sound.Looped = true
	--			Sound.Volume = Obj.Volume
	--			Sound.Parent = script
	--			Sound:Play()

	--			Obj.SoundInstance = Sound
	--		else
	--			local Sound = Obj.SoundInstance
	--			if Sound ~= nil then
	--				Sound:Destroy()
	--				Sound = nil
	--			end
	--			Obj.SoundInstance = nil
	--		end
	--	end
	--end
	
	-- Fades to the primary sound or sound URL.
	local function FadeToPrimarySound()
		local Sound = Obj.MainSound

		if Sound ~= nil then
			Obj.FadeToSound(Sound)
		else
			Obj.FadeToURL(Obj.SoundURL)
		end

		Sound = nil
	end

	-- Fades to a song by music zone.
	local function FadeToMusicZone(Zone)
		if Zone ~= nil then
			-- Find the sound object in the music zone model
			-- then use it
			local Sound = Zone:FindFirstChild(MusicPlayer.SOUND_NAME)

			if Sound ~= nil then
				Obj.LastMusicMode = MusicPlayer.MusicMode.ByMusicZone
				Obj.FadeToSound(Sound)
			end
		else
			coroutine.wrap(FadeToPrimarySound)()
		end
	end

	--local function FadeToMusicZone(Zone)
	--	--if FinishedFading == true then
	--	FinishedFading = false

	--	FadingInSound = nil

	--	print("a")
	--	if Zone ~= nil then
	--		local OldSound = Obj.SoundInstance
	--		local FadeTime = Obj.FadeTime or 1

	--		local FadeInTween = nil

	--		-- Get the sound instance that is fading in.
	--		local SoundToFadeIn = Zone:FindFirstChild(MusicPlayer.SOUND_NAME or "Sound")

	--		print("b", Zone, SoundToFadeIn)
	--		if SoundToFadeIn ~= nil then
	--			print("c")
	--			Obj.SoundInstance = SoundToFadeIn
	--			FadingInSound = SoundToFadeIn

	--			local SoundPos = SoundToFadeIn.TimePosition
	--			local TargetTimePos = TimePositions[SoundToFadeIn] or SoundPos
	--			TimePositions[SoundToFadeIn] = TargetTimePos

	--			-- Get the starting properties of the sound				
	--			local SoundVolume = SoundToFadeIn.Volume
	--			local TargetVolume = SoundVolumes[SoundToFadeIn] or SoundVolume
	--			SoundVolumes[SoundToFadeIn] = TargetVolume

	--			local StartingVolume = 0
	--			local StartingTimePos = 0
	--			if FinishedFading == true then
	--				StartingVolume = TargetVolume
	--				StartingTimePos = TargetTimePos
	--			else
	--				print("finish fading false", SoundVolume)
	--				StartingVolume = SoundVolume
	--				StartingTimePos = SoundPos
	--			end
	--			FinishedFading = false

	--			SoundToFadeIn.Volume = StartingVolume
	--			SoundToFadeIn.TimePosition = StartingTimePos

	--			-- Fade the new sound in
	--			if SoundToFadeIn.IsPlaying == false then
	--				SoundToFadeIn:Resume()
	--			end
	--			ToggleFader(true, FadeTime, OldSound, SoundToFadeIn)
	--			local IsCompleted = WaitForSoundFade(SoundToFadeIn, FadeTime)
	--			if IsCompleted == false then
	--				-- Fade back
	--				ToggleFader(false)
	--			end

	--			--FadeInTween = FadeSound(FadingInSound, TargetVolume, FadeTime)
	--		end

	--		local function DestroyFadeIn()
	--			if FadeInTween ~= nil then
	--				FadeInTween:Destroy()
	--				FadeInTween = nil
	--			end
	--		end

	--		if OldSound ~= nil then
	--			if true then
	--				print("reached old sound logic, returning")
	--				return
	--			end

	--			-- Fade out the old sound
	--			-- (Fade it back in if its zone is re-entered)
	--			local Elapsed = 0
	--			--local FadeOutTween = FadeSound(OldSound, 0, FadeTime)

	--			local CompletedFade = WaitForSoundFade(SoundToFadeIn, FadeTime)

	--			-- Stop tweening
	--			DestroyFadeIn()

	--			if FadeOutTween ~= nil then
	--				FadeOutTween:Destroy()
	--				FadeOutTween = nil
	--			end

	--			-- If the music transition completed, reset the old sound instance
	--			if CompletedFade == true then
	--				Obj.SoundInstance = SoundToFadeIn

	--				local TimePos = TimePositions[OldSound]
	--				local SoundVolume = SoundVolumes[OldSound]

	--				OldSound:Stop()

	--				if TimePos ~= nil then
	--					OldSound.TimePosition = TimePos
	--				end

	--				if SoundVolume ~= nil then
	--					OldSound.Volume = SoundVolume
	--				end

	--				FadingInSound = nil

	--				print("completed sound fade")

	--				-- Reset debounce values
	--				CurrentMusicZone = nil
	--				FinishedFading = true
	--			else
	--				-- Fade back
	--				Obj.SoundInstance = OldSound
	--				FinishedFading = false
	--				ToggleFader(false)
	--				--FadeToMusicZone(Zone)
	--			end
	--		else
	--			task.wait(FadeTime)
	--			DestroyFadeIn()
	--			FinishedFading = true
	--		end
	--	else
	--		FadingInSound = nil
	--		FinishedFading = true
	--		Obj.FadeToURL(Util.FormatAssetId(Obj.MainURL))
	--		FinishedFading = false
	--	end
	--	--end
	--end
	
	-- Removes a music zone from its storage array.
	-- Returns true if the zone was successfully unlisted.
	local function UnlistMusicZone(ZoneModel)
		-- Remove music zone
		local Index = table.find(CurrentMusicZones, ZoneModel)
		if Index ~= nil then
			table.remove(CurrentMusicZones, Index)
			return true
		end
		
		return false
	end

	-- Hitbox change listener.
	local function OnHitChange(Part, HitResult)
		if IsPart(Part) == true then
			HitResult = HitResult.Status

			-- Take the next action by hit result
			-- (Music zones are by part parent)
			local ZoneModel = Part.Parent.Parent
			local IsChanging = false

			if HitResult == HitStatus.CompletelyInside then
				-- Add music zone
				if IsMusicZone(ZoneModel) == true then
					IsChanging = true
					
					-- Unlist before relisting, to prevent certain problems
					-- with code sync
					UnlistMusicZone(ZoneModel)
					table.insert(CurrentMusicZones, ZoneModel)
				end
			elseif HitResult == HitStatus.NotTouching then
				IsChanging = UnlistMusicZone(ZoneModel)
			end

			-- Fade to the music zone at the end of the list
			if CurrentMusicZones ~= nil then
				if IsChanging == true then
					local NextZoneModel = CurrentMusicZones[#CurrentMusicZones]

					--CurrentMusicZone = NextZoneModel
					print("fading to", NextZoneModel)
					FadeToMusicZone(NextZoneModel)

					-- Set as the current music zone for debouncing
					--if NextZoneModel ~= CurrentMusicZone then
					CurrentMusicZone = NextZoneModel
					--end
				end
			else
				CurrentMusicZone = nil
				FadeOutSound()
			end
		end
	end

	-- Sets if the specified model music zone has
	-- its parts binded to the hitbox
	local function SetZoneConnected(Zone, IsConnected)
		local Hitbox = CurrentHitbox

		if Hitbox ~= nil then
			if IsConnected == true then
				if IsMusicZone(Zone) == true then
					SetZoneConnected(Zone, false)

					-- Reconnect the parts to the hitbox.
					local Parts = Zone:WaitForChild(MusicPlayer.PARTS_FOLDER_NAME or "Parts")
					if Parts ~= nil then
						Parts = Parts:GetChildren()

						ZoneParts[Zone] = Parts
						for i, v in pairs(Parts) do
							if IsPart(v) == true then
								Hitbox.ConnectPart(v)
							end
						end
					end
				end
			else
				local Parts = ZoneParts[Zone]

				if Parts ~= nil then
					for i, v in pairs(Parts) do
						Hitbox.DisconnectPart(v)
					end
				end
			end
		end
	end

	-- Sets if the music zone instance collector is being used
	local function SetInstancesCollected(IsCollecting)
		if IsCollecting == true then
			SetInstancesCollected(false)

			local ZoneLocation = MusicPlayer.MusicZoneLocation
			if ZoneLocation ~= nil then
				ZoneCollector = InstCollector.New(MusicPlayer.MUSIC_ZONE_KEYWORD)

				-- Reconnect events.
				ZoneCollector.InstanceRemoved = function(Inst)
					SetZoneConnected(Inst, false)
				end

				ZoneCollector.InstanceFound = function(Inst)
					SetZoneConnected(Inst, true)
				end

				-- Start the collection.
				ZoneCollector.AdaptInstance(ZoneLocation)
			end
		else
			if ZoneCollector ~= nil then
				ZoneCollector.Dispose()
				ZoneCollector = nil
			end
		end
	end

	-- Checks if a sound is currently fading.
	function Obj.IsFading()
		return FinishedFading == false
	end

	-- Stores a URL's asset information. That information
	-- is then used by Obj.GetSoundInfo().
	function Obj.SetAssetInfo(URL, Info)
		AssetInfo[URL] = Info
	end


	-- Binds a Hitbox to be used by the MusicZone handler.
	function Obj.BindHitbox(Hitbox)
		if Hitbox ~= nil then
			CurrentHitbox = Hitbox

			Hitbox.HitStatusChanged.Connect(OnHitChange)
		else
			if CurrentHitbox ~= nil then
				CurrentHitbox.HitStatusChanged.Disconnect(OnHitChange)
				CurrentHitbox = nil
			end
		end
	end

	-- Gets the sound info of the currently loaded sound.
	-- This yields the current thread.
	function Obj.GetSoundInfo()
		local Sound = Obj.SoundInstance
		if Sound ~= nil then
			return UpdateInfoInternally(Sound.SoundId)
		else
			return ""
		end
	end

	-- Re(-starts) the BGM playback.
	function Obj.Play()
		FadeToPrimarySound()
	end

	-- Fades out the BGM playback
	function Obj.Stop()
		Obj.FadeToSound(nil)
	end

	-- The volume used when the music is played by URL.
	Obj.SetProperty("URLVolume", 1, function(vol)
		local Sound = Obj.SoundInstance
		if Sound ~= nil then
			Sound.Volume = vol
		end
		Sound = nil
	end)
	
	-- The master volume of the BGM player.
	-- This multiplies the currently playing sound's
	-- volume so:
	-- (0 = muted, 1 = full volume)
	Obj.SetProperty("MasterVolume", 1, function(Vol)
		local Sound = Obj.SoundInstance
		
		if Sound ~= nil then
			local OriginalVolume = SoundVolumes[Sound]
			if OriginalVolume ~= nil then
				
				-- Disconnection of sound completion is needed to
				-- interrupt tweens.
				if CurrentFader ~= nil then
					CurrentFader.DisconnectCompletion()
				end
				
				Sound.Volume = OriginalVolume * Vol
			end
		end
	end)
	
	-- The primary sound instance to play the background music.
	-- Also used if the hitbox isn't in any music zone.
	Obj.SetProperty("MainSound", MusicPlayer.DefaultURL, function(Sound)
		if Obj.Autoplay == true then
			coroutine.wrap(Obj.FadeToSound)(Sound)
		end
	end)

	-- The sound URL used to play the background music.
	-- Used as a backup if MainSound isn't provided.
	-- Also used if the hitbox isn't in any music zone.
	Obj.SetProperty("MainURL", MusicPlayer.DefaultURL, function(URL)
		if Obj.Autoplay == true then
			coroutine.wrap(Obj.FadeToURL)(Util.FormatAssetId(URL), true)
		end
		--coroutine.wrap(UpdateInfoInternally)(URL)
	end)

	-- If the music zones will be in use
	Obj.SetProperty("UsesMusicZones", false, function(UsingMusicZones)
		local MusicMode = MusicPlayer.MusicMode

		if UsingMusicZones == false then
			-- Disconnect the music zone collector
			SetInstancesCollected(false)

			-- Disconnect music zones
			for i, v in pairs(ZoneParts) do
				SetZoneConnected(i, false)
			end

			-- Fade back to the main url
			coroutine.wrap(Obj.FadeToURL)(Obj.MainURL)
		elseif UsingMusicZones == true then
			-- Connect the music zone collector
			SetInstancesCollected(true)
		end
	end)

	-- Fires when the asset info loaded into the BGM object changes.
	Obj.AssetInfoChanged = nil

	-- Pause sound instance on disposal
	Obj.OnDisposal = function()
		Obj.FadeToSound(nil)
		task.wait(Obj.FadeTime or 1)
		SoundFader.Dispose()
	end

	return Obj
end

return MusicPlayer