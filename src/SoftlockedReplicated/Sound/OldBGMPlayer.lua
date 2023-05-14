-- Provides an object that is used to play background music.

-- This is the successor of the old MusicPlayer. This includes support
-- for a set music url and the usage of music zones.

-- Thanks to Jukereise for the concept of the music zones
-- (Meaning music zones are in the form of models)

-- THIS VERSION IS SUPER BUGGY AND SHOULD NOT BE USED
-- Use the revamped version instead

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
local function GetInfoByURL(Id)
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

function MusicPlayer.New()
	local Obj = Object.New("ClientMusicPlayer")
	local AssetInfo = {} -- Asset info override table
	local CurrentMusicZones = {}
	local SoundVolumes = {} -- Music zone sound volumes
	local TimePositions = {} -- Music zone starting time positions
	local ZoneParts = {} -- Music zone BaseParts
	local CurrentHitbox = nil
	local CurrentMusicZone = nil
	local FadingInSound = nil
	local FinishedFading = true
	
	local IsFadingIn = false -- If the current fader is fading to a new BGM
	
	local CurrentFader = nil -- The current sound fader
	local ZoneCollector = nil

	Obj.SoundInstance = nil
	Obj.IsLoaded = false

	-- By default, the name of the sound asset
	-- that was just loaded.
	Obj.AssetInfo = ""

	-- The length of the music transition in seconds.
	Obj.FadeTime = 1

	-- If the audio plays the new URL as soon as it's changed
	Obj.Autoplay = true

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

	local function UpdateInfoInternally(URL)
		local SetInfo = AssetInfo[URL]
		if SetInfo ~= nil then
			-- Return the set asset information
			-- since it's been defined already
			Obj.AssetInfo = SetInfo
			return SetInfo
		else
			SetInfo = nil

			-- Find the id in the URL string, if needed
			-- Conversion to a number is needed because
			-- MarketplaceService:GetProductInfo()
			-- only accepts asset IDs.
			if typeof(URL) == "string" then
				URL = string.split(URL, "://")[2]
				if URL ~= nil then
					URL = tonumber(URL)
				end
			end

			-- Request the info
			if typeof(URL) == "number" then
				local Info = GetInfoByURL(URL or 0)
				Obj.AssetInfo = Info
				Object.FireCallback(Obj.AssetInfoChanged, Info)
				return Info
			end
		end
	end
	
	-- Fade completion listener.
	local function OnFadeComplete()
		if CurrentFader ~= nil then
			CurrentFader.Dispose()
			print("Disposing current fader from completion")
		end
	end
	
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

	-- Fades to a new sound by URL
	-- If URL is nil, the sound will fade out and stop
	local function FadeToURL(URL, IsDestroyingOld)
		local OldSound = Obj.SoundInstance

		if Obj.FadeTime > 0 then
			FinishedFading = false

			if IsSoundURL(URL) == true then
				local NewSound = Instance.new("Sound")
				Obj.SoundInstance = NewSound
				NewSound.SoundId = URL
				NewSound.Volume = 0
				NewSound.Looped = true
				NewSound.Parent = script
				
				-- Fade out the old sound
				--FadeOutSound(IsDestroyingOld)

				-- Fade in the new sound once it loads
				coroutine.wrap(function()
					if NewSound.IsLoaded == false then
						NewSound.Loaded:Wait()
					end

					if IsSoundLoaded(NewSound) then
						-- Update asset information
						coroutine.wrap(UpdateInfoInternally)(URL)

						-- Fade in
						local FadeTime = Obj.FadeTime or 1
						ToggleFader(true, FadeTime, OldSound, NewSound)
						

						NewSound:Play()
						local Tween = FadeSound(NewSound, Obj.Volume, FadeTime)

						local CompletedFade = WaitForSoundFade(NewSound, FadeTime)
						Tween:Destroy()
						Tween = nil

						if CompletedFade == true then
							FinishedFading = true
							
							print("fade completion true")
						else
							print("fade completion false")

							-- Fade out the sound if the fade didn't complete.
							ToggleFader(false)
							
							--FadeSound(NewSound, 0, FadeTime)

							--NewSound:Pause()
							if IsDestroyingOld == true then
								NewSound:Destroy()
							end
						end
					else
						NewSound:Destroy()
						warn("Failed to load sound: " .. URL)
					end

					NewSound = nil
				end)()
			else
				Obj.SoundInstance = nil
				FadeOutSound(IsDestroyingOld)
			end

			FinishedFading = true

			--if FinishedFading == true then

			--end
		else
			-- Immediately switch
			if IsSoundURL(URL) == true then
				local Sound = Obj.SoundInstance
				if Sound == nil then
					Sound = Instance.new("Sound")
				end
				Sound.SoundId = URL
				Sound.Looped = true
				Sound.Volume = Obj.Volume
				Sound.Parent = script
				Sound:Play()

				Obj.SoundInstance = Sound
			else
				local Sound = Obj.SoundInstance
				if Sound ~= nil then
					Sound:Destroy()
					Sound = nil
				end
				Obj.SoundInstance = nil
			end
		end
	end

	-- Fades to a song by music zone.
	local function FadeToMusicZone(Zone)
		--if FinishedFading == true then
		FinishedFading = false

		FadingInSound = nil

		print("a")
		if Zone ~= nil then
			local OldSound = Obj.SoundInstance
			local FadeTime = Obj.FadeTime or 1

			local FadeInTween = nil

			-- Get the sound instance that is fading in.
			local SoundToFadeIn = Zone:FindFirstChild(MusicPlayer.SOUND_NAME or "Sound")

			print("b", Zone, SoundToFadeIn)
			if SoundToFadeIn ~= nil then
				print("c")
				Obj.SoundInstance = SoundToFadeIn
				FadingInSound = SoundToFadeIn
				
				local SoundPos = SoundToFadeIn.TimePosition
				local TargetTimePos = TimePositions[SoundToFadeIn] or SoundPos
				TimePositions[SoundToFadeIn] = TargetTimePos
				
				-- Get the starting properties of the sound				
				local SoundVolume = SoundToFadeIn.Volume
				local TargetVolume = SoundVolumes[SoundToFadeIn] or SoundVolume
				SoundVolumes[SoundToFadeIn] = TargetVolume

				local StartingVolume = 0
				local StartingTimePos = 0
				if FinishedFading == true then
					StartingVolume = TargetVolume
					StartingTimePos = TargetTimePos
				else
					print("finish fading false", SoundVolume)
					StartingVolume = SoundVolume
					StartingTimePos = SoundPos
				end
				FinishedFading = false

				SoundToFadeIn.Volume = StartingVolume
				SoundToFadeIn.TimePosition = StartingTimePos
				
				-- Fade the new sound in
				if SoundToFadeIn.IsPlaying == false then
					SoundToFadeIn:Resume()
				end
				ToggleFader(true, FadeTime, OldSound, SoundToFadeIn)
				local IsCompleted = WaitForSoundFade(SoundToFadeIn, FadeTime)
				if IsCompleted == false then
					-- Fade back
					ToggleFader(false)
				end
				
				--FadeInTween = FadeSound(FadingInSound, TargetVolume, FadeTime)
			end

			local function DestroyFadeIn()
				if FadeInTween ~= nil then
					FadeInTween:Destroy()
					FadeInTween = nil
				end
			end

			if OldSound ~= nil then
				if true then
					print("reached old sound logic, returning")
					return
				end
				
				-- Fade out the old sound
				-- (Fade it back in if its zone is re-entered)
				local Elapsed = 0
				--local FadeOutTween = FadeSound(OldSound, 0, FadeTime)

				local CompletedFade = WaitForSoundFade(SoundToFadeIn, FadeTime)

				-- Stop tweening
				DestroyFadeIn()

				if FadeOutTween ~= nil then
					FadeOutTween:Destroy()
					FadeOutTween = nil
				end

				-- If the music transition completed, reset the old sound instance
				if CompletedFade == true then
					Obj.SoundInstance = SoundToFadeIn

					local TimePos = TimePositions[OldSound]
					local SoundVolume = SoundVolumes[OldSound]

					OldSound:Stop()

					if TimePos ~= nil then
						OldSound.TimePosition = TimePos
					end

					if SoundVolume ~= nil then
						OldSound.Volume = SoundVolume
					end
					
					FadingInSound = nil
					
					print("completed sound fade")

					-- Reset debounce values
					CurrentMusicZone = nil
					FinishedFading = true
				else
					-- Fade back
					Obj.SoundInstance = OldSound
					FinishedFading = false
					ToggleFader(false)
					--FadeToMusicZone(Zone)
				end
			else
				task.wait(FadeTime)
				DestroyFadeIn()
				FinishedFading = true
			end
		else
			FadingInSound = nil
			FinishedFading = true
			FadeToURL(Util.FormatAssetId(Obj.MainURL))
			FinishedFading = false
		end
		--end
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
					table.insert(CurrentMusicZones, ZoneModel)
				end
			elseif HitResult == HitStatus.NotTouching then
				-- Remove music zone
				local Index = table.find(CurrentMusicZones, ZoneModel)
				if Index ~= nil then
					IsChanging = true
					table.remove(CurrentMusicZones, Index)
				end
			end

			-- Fade to the music zone at the end of the list
			if CurrentMusicZones ~= nil then
				if IsChanging == true then
					local NextZoneModel = CurrentMusicZones[#CurrentMusicZones]

					CurrentMusicZone = NextZoneModel
					print("fading to", NextZoneModel)
					FadeToMusicZone(NextZoneModel)

					-- Set as the current music zone for debouncing
					if NextZoneModel ~= CurrentMusicZone then
						CurrentMusicZone = NextZoneModel
					end
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
		FadeToURL(Obj.SoundURL)
	end

	-- Fades out the BGM playback
	function Obj.Stop()
		FadeToURL(nil)
	end

	Obj.SetProperty("Volume", 1, function(vol)
		local Sound = Obj.SoundInstance
		if Sound ~= nil then
			Sound.Volume = vol
		end
		Sound = nil
	end)

	-- The sound URL used to play the background music.
	-- Also used if the hitbox isn't in any music zone.
	Obj.SetProperty("MainURL", MusicPlayer.DefaultURL, function(URL)
		if Obj.Autoplay == true then
			FadeToURL(Util.FormatAssetId(URL), true)
		end
		--coroutine.wrap(UpdateInfoInternally)(URL)
	end)

	-- The music mode used.
	Obj.SetProperty("MusicMode", MusicPlayer.MusicMode.ByURL, function(Mode)
		local MusicMode = MusicPlayer.MusicMode

		if Mode == MusicMode.ByURL then
			-- Disconnect the music zone collector
			SetInstancesCollected(false)

			-- Disconnect music zones
			for i, v in pairs(ZoneParts) do
				SetZoneConnected(i, false)
			end

			-- Fade back to the main url
			FadeToURL(Obj.MainURL)
		elseif Mode == MusicMode.ByMusicZone then
			-- Connect the music zone collector
			SetInstancesCollected(true)
		end
	end)

	-- Fires when the asset info loaded into the BGM object changes.
	Obj.AssetInfoChanged = nil
	
	-- Pause sound instance on disposal
	Obj.Disposal = function()
		Obj.SoundInstance:Pause()
	end

	return Obj
end

return MusicPlayer