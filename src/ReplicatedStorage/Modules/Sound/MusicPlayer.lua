--[[
Provides an object that is used to play background music.

This is the successor of the old MusicPlayer. This includes support
for a set music url and the usage of music zones.
The code is also much more clean than the last.

Thanks to Jukereise for the concept of the music zones
(Meaning music zones are in the form of models)

This version revamps the coding from the last version of the BGM player
because it got way too messy

By udev2192
]]--

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local Adapters = RepModules:WaitForChild("Adapters")
local UtilRepModules = RepModules:WaitForChild("Utils")

local BaseInteractive = require(
	RepModules
	:WaitForChild("MapHandles")
	:WaitForChild("Interactives")
	:WaitForChild("BaseInteractive")
)

local Hitbox = require(Adapters:WaitForChild("Hitbox"))
local InstCollector = require(Adapters:WaitForChild("InstanceCollector"))

local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))
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
MusicPlayer.PRIORITY_ATTRIBUTE = "Priority"

MusicPlayer.URL_SOUND_COLLECTION = "MusicPlayer_SoundsPlayedByUrlCollection"

MusicPlayer.LoadingAttribution = "[Loading]"

-- Where to look for music zones.
MusicPlayer.MusicZoneLocation = workspace --:WaitForChild("Areas")

-- Music modes that are used to determine the behavior
-- that triggers music playback.
MusicPlayer.MusicMode = {
	-- Play by using a set sound URL
	ByURL = 0,

	-- Play by using a sound instance
	BySound = 1,

	-- Play by using sound URLs from music zones.
	ByMusicZone = 2
}

MusicPlayer.DefaultMasterVolume = 1

-- Gets the sound information by asset id.
local function GetInfoById(Id)
	local Success, Result = pcall(function()
		return MarketplaceService:GetProductInfo(Id)
	end)

	if Success == true then
		return Result.Name
	else
		return ""
	end
end

local function IsPart(Part)
	return Util.IsInstance(Part) and Part:IsA("BasePart")
end

function MusicPlayer.IsSoundLoaded(Sound)
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

local function GetSoundAttributionProperty(Sound)
	return Sound:GetAttribute(MusicPlayer.ATTRIBUTION_INDEX)
end

local HitStatus = Hitbox.HitStatus
Hitbox = nil

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
	local AttributionAttr = GetSoundAttributionProperty(Sound)
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

function MusicPlayer.GetTargetVolume(Sound: Sound): number
	return tonumber(Sound:GetAttribute(MusicPlayer.TARGET_VOLUME_ATTRIBUTE) or 1)
	--return ((
	--	tonumber(Sound:GetAttribute(MusicPlayer.TARGET_VOLUME_ATTRIBUTE) or 1) or 1)
	--		or SoundVolumes[Sound])
end

function MusicPlayer.New()
	-- Subclass the sound fader for the sake of memory usage
	local Obj = SoundFader.New()

	local AssetInfo = {} -- Asset info override table
	local CurrentMusicZones = {}

	local SoundVolumes = {} -- Sound instance volumes
	local TimePositions = {} -- Sound instance time positions

	local ZoneParts = {} -- Music zone BaseParts

	local CurrentHitbox
	local CurrentMusicZone
	local ZoneCollector
	local ZoneEntryRunner

	-- The volume of the previous sound
	local PreviousVolume

	-- By default, the name of the sound asset
	-- that was just loaded.
	Obj.AssetInfo = ""

	-- If the audio plays the new URL as soon as it's changed
	Obj.Autoplay = true

	--[[
	<boolean> - If attributions are saved when they're loaded.
	]]--
	Obj.SaveAttributions = true

	--[[
	<BasePart> - The part to detect music zone entry with
	]]--
	Obj.MusicZoneHitbox = nil

	-- The most recent method of music playback.
	Obj.LastMusicMode = MusicPlayer.MusicMode.ByURL
	
	local SoundGroup: SoundGroup = Util.CreateInstance("SoundGroup", {
		Volume = Obj.DefaultMasterVolume,
		Name = "MusicGroup",
	})

	local function ChangeAttribution(Info)
		Obj.AssetInfo = Info
		Obj.AttributionChanged.Fire(Info)
	end

	local function UpdateInfoInternally(Sound)
		local Info
		local SoundId
		
		if Sound then
			SoundId = Sound.SoundId
			
			if SoundId then
				Info = AssetInfo[SoundId]

				if Info == nil then
					-- Indicate that the info is being requested
					-- Only do this if not overriden because the
					-- info may not be available instantly
					if GetSoundAttributionProperty(Sound) == nil then
						ChangeAttribution(MusicPlayer.LoadingAttribution)
					end

					-- Request the info through other methods
					-- if not overriden
					Info = MusicPlayer.GetAttributionBySound(Sound)

					-- Save the attribution if permitted
					if Obj.SaveAttributions == true and Info ~= nil and Info ~= "" then
						Obj.SetAssetInfo(SoundId, Info)
					end
				end
			end
		end
		
		Info = Info or ""

		-- Indicate changes
		if SoundId == nil or SoundId == Obj.CurrentSoundId then
			ChangeAttribution(Info)
		end

		return Info
	end

	local function ResetSound(Sound)
		Sound:Pause()

		Sound.TimePosition = TimePositions[Sound] or 0
		Sound.Volume = SoundVolumes[Sound] or 0

		TimePositions[Sound] = nil
		SoundVolumes[Sound] = nil

		-- If the sound was played using FadeToURL, it will most likely
		-- need to be garbage collected
		local UrlTag = MusicPlayer.URL_SOUND_COLLECTION
		if CollectionService:HasTag(Sound, UrlTag) then
			CollectionService:RemoveTag(Sound, UrlTag)
			Sound:Destroy()
		end
	end

	--[[
	Listener for sound fade completion.
	
	Pause old bgm playback only on fade completion to ensure
	that reversing it mid-way is possible
	
	If a song is faded out, the sound properties are reset here
	]]--
	--local function ResetOldSounds(OldSounds)
	--	for i, Sound in pairs(OldSounds) do
	--		if Sound ~= Obj.CurrentSound then
	--			ResetSound(Sound)
	--		end
	--	end
	--end

	--Obj.ReverseCompleted.Connect(ResetOldSounds)
	--Obj.Completed.Connect(ResetOldSounds)
	local FadeOutConnection: Signal.SignalConnection = Obj.SoundFadedOut.Connect(ResetSound)

	-- Fades to a new sound instance.
	-- If no sound instances are provided, the music fades out.
	-- This function returns the old sound instance for convenience
	function Obj.FadeToSound(NewSound, DestroyOldSound)
		local OldSound = Obj.CurrentSound

		if NewSound ~= OldSound then
			-- Update the sound instance if the new sound doesn't match
			-- the one currently playing
			local URL = NewSound and NewSound.SoundId
			if URL and URL ~= Obj.CurrentSoundId then
				Obj.CurrentSoundId = URL

				-- Update song citation
				coroutine.wrap(UpdateInfoInternally)(NewSound)

				-- Initialize music transition
				local FadeTime = Obj.TransitionTime or 1

				-- Get initial sound info
				local TargetVolume = MusicPlayer.GetTargetVolume(NewSound)
				local StartTime = 
					tonumber(NewSound:GetAttribute(MusicPlayer.START_TIME_ATTRIBUTE) or 0)
					or TimePositions[NewSound]
					or 0

				--local IsPaused = SoundVolumes[NewSound] == nil

				-- Store initial sound info for later use
				--SoundVolumes[NewSound] = TargetVolume
				--TimePositions[NewSound] = StartTime

				-- Fade to the new sound
				PreviousVolume = TargetVolume

				if NewSound.IsPlaying == false then
					NewSound.Volume = 0
					NewSound.TimePosition = StartTime
					NewSound.SoundGroup = SoundGroup
					NewSound:Resume()
				end

				-- Obj.CurrentSound is set here
				--Obj.TargetVolume = TargetVolume
				Obj.Switch(NewSound, TargetVolume)

				-- Destroy the old sound(s) if needed
				if OldSound and DestroyOldSound then
					task.spawn(function()
						if FadeTime > 0 then
							task.wait(FadeTime)
						end

						OldSound:Destroy()
					end)
				end
			else
				Obj.Switch(nil)
				Obj.CurrentSoundId = ""
			end
		end

		return OldSound
	end

	-- Fades to a new sound by URL
	-- If URL is nil, the sound will fade out and stop
	function Obj.FadeToURL(URL, DestroyOldSound)
		local CurrentSound = Obj.CurrentSound

		if CurrentSound then
			if URL ~= CurrentSound.SoundId then
				Obj.LastMusicMode = MusicPlayer.MusicMode.ByURL

				local NewSound
				if URL ~= nil and URL ~= "" then
					local TargetVolume = (Obj.URLVolume or 1)

					NewSound = Instance.new("Sound")
					NewSound.SoundId = Util.FormatAssetId(URL)
					NewSound.Volume = TargetVolume 
					NewSound.Looped = true
					NewSound.TimePosition = 0

					NewSound:SetAttribute(MusicPlayer.TARGET_VOLUME_ATTRIBUTE, TargetVolume)
					NewSound:SetAttribute(MusicPlayer.START_TIME_ATTRIBUTE, 0)

					CollectionService:AddTag(NewSound, MusicPlayer.URL_SOUND_COLLECTION)
					NewSound.Parent = script

					-- Wait for the new sound to load
					-- (don't because it sounds weird)
					--if NewSound.IsLoaded == false then
					--	NewSound.Loaded:Wait()
					--end
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
				if NewSound then
					Obj.FadeToSound(NewSound, DestroysLastSound)
				end
			end
		end
	end

	-- Fades to the primary sound or sound URL.
	local function FadeToPrimarySound()
		local Sound = Obj.MainSound

		if Sound ~= nil then
			Obj.LastMusicMode = MusicPlayer.MusicMode.BySound
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

	--[[
	Rescans music zone entry
	]]--
	function Obj.RescanMusicZones()
		local MusicZoneHitbox = Obj.MusicZoneHitbox
		local PriorityAttribute = MusicPlayer.PRIORITY_ATTRIBUTE

		if MusicZoneHitbox then
			local CurrentHitPos: Vector3 = MusicZoneHitbox.Position
			MusicZoneHitbox = nil
			
			-- Sounds of the entered music zones
			local EnteredSounds = {}
			
			-- The highest priority among the entered zones
			local HighestPriority: number = 0
			
			local SelectedSound

			-- Get the entered music zones
			-- We shouldn't have to check for any duplicates
			-- cause of the break statement in the loop
			for i, v in pairs(CurrentMusicZones) do
				local Sound = v:FindFirstChildOfClass("Sound")
				
				if Sound then
					local Parts = v:FindFirstChild("Parts")

					if Parts then
						for i2, v2 in pairs(Parts:GetChildren()) do
							if v2:IsA("BasePart") then
								if BaseInteractive.IsPointInside(CurrentHitPos, v2) then
									table.insert(EnteredSounds, Sound)
									break
								end
							end
						end
					end
				end
			end
			
			if #EnteredSounds > 0 then
				-- Use the sound with the highest priority
				for i, v in pairs(EnteredSounds) do
					local Priority = v:GetAttribute(PriorityAttribute) or 0

					if Priority >= HighestPriority then
						HighestPriority = Priority
						SelectedSound = v
					end
				end
				
				-- Play the sound
				Obj.FadeToSound(SelectedSound)
			else
				FadeToPrimarySound()
			end
		end
	end

	local function ListMusicZone(ZoneModel)
		if table.find(CurrentMusicZones, ZoneModel) == nil then
			table.insert(CurrentMusicZones, ZoneModel)
		end
	end

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
	--local function OnHitChange(Part, HitResult)
	--	if IsPart(Part) == true then
	--		HitResult = HitResult.Status

	--		-- Take the next action by hit result
	--		-- (Music zones are by part parent)
	--		local ZoneModel = Part.Parent.Parent
	--		local IsChanging = false

	--		if HitResult == HitStatus.CompletelyInside then
	--			-- Add music zone
	--			if IsMusicZone(ZoneModel) == true then
	--				IsChanging = true

	--				-- Unlist before relisting, to prevent certain problems
	--				-- with code sync
	--				UnlistMusicZone(ZoneModel)
	--				table.insert(CurrentMusicZones, ZoneModel)
	--			end
	--		elseif HitResult == HitStatus.NotTouching then
	--			IsChanging = UnlistMusicZone(ZoneModel)
	--		end

	--		-- Fade to the music zone at the end of the list
	--		if CurrentMusicZones ~= nil then
	--			if IsChanging == true then
	--				local NextZoneModel = CurrentMusicZones[#CurrentMusicZones]

	--				FadeToMusicZone(NextZoneModel)

	--				-- Set as the current music zone for debouncing
	--				CurrentMusicZone = NextZoneModel
	--			end
	--		else
	--			CurrentMusicZone = nil
	--			Obj.FadeToSound(nil)
	--		end
	--	end
	--end

	-- Sets if the specified model music zone has
	-- its parts binded to the hitbox
	--local function SetZoneConnected(Zone, IsConnected)
	--	local Hitbox = CurrentHitbox

	--	if Hitbox ~= nil then
	--		if IsConnected == true then
	--			if IsMusicZone(Zone) == true then
	--				SetZoneConnected(Zone, false)

	--				-- Reconnect the parts to the hitbox.
	--				local Parts = Zone:WaitForChild(MusicPlayer.PARTS_FOLDER_NAME or "Parts")
	--				if Parts ~= nil then
	--					Parts = Parts:GetChildren()

	--					ZoneParts[Zone] = Parts
	--					for i, v in pairs(Parts) do
	--						if IsPart(v) == true then
	--							Hitbox.ConnectPart(v)
	--						end
	--					end
	--				end
	--			end
	--		else
	--			local Parts = ZoneParts[Zone]

	--			if Parts ~= nil then
	--				for i, v in pairs(Parts) do
	--					Hitbox.DisconnectPart(v)
	--				end
	--			end
	--		end
	--	end
	--end

	-- Sets if the music zone instance collector is being used
	local function SetInstancesCollected(IsCollecting)
		if IsCollecting == true then
			SetInstancesCollected(false)

			local ZoneLocation = MusicPlayer.MusicZoneLocation
			if ZoneLocation ~= nil then
				ZoneCollector = InstCollector.New(MusicPlayer.MUSIC_ZONE_KEYWORD)

				-- Reconnect events.
				ZoneCollector.InstanceRemoved = function(Inst)
					--SetZoneConnected(Inst, false)
					UnlistMusicZone(Inst)
				end

				ZoneCollector.InstanceFound = function(Inst)
					--SetZoneConnected(Inst, true)
					ListMusicZone(Inst)
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

	-- Stores a URL's asset information. That information
	-- is then used by Obj.GetSoundInfo().
	function Obj.SetAssetInfo(URL, Info)
		AssetInfo[URL] = Info
	end


	-- Binds a Hitbox to be used by the MusicZone handler.
	--function Obj.BindHitbox(Hitbox)
	--	if Hitbox ~= nil then
	--		CurrentHitbox = Hitbox

	--		Hitbox.HitStatusChanged.Connect(OnHitChange)
	--	else
	--		if CurrentHitbox ~= nil then
	--			CurrentHitbox.HitStatusChanged.Disconnect(OnHitChange)
	--			CurrentHitbox = nil
	--		end
	--	end
	--end

	-- Gets the sound info of the currently loaded sound.
	-- This yields the current thread.
	function Obj.GetSoundInfo()
		local Sound = Obj.CurrentSound
		if Sound ~= nil then
			return UpdateInfoInternally(Sound)
		else
			return ""
		end
	end

	-- Re(-starts) the main BGM playback.
	function Obj.Restart()
		FadeToPrimarySound()
	end

	-- Fades out the main BGM playback
	function Obj.StopMain()
		Obj.FadeToSound(nil)
	end

	-- The volume used when the music is played by URL.
	Obj.SetProperty("URLVolume", 1, function(vol)
		local Sound = Obj.CurrentSound
		if Sound ~= nil then
			Sound.Volume = vol
		end
		Sound = nil
	end)

	-- The master volume of the BGM player.
	-- This multiplies the currently playing sound's
	-- volume so:
	-- (0 = muted, 1 = full volume)
	-- make this use a sound group later for stability reasons
	-- (right now, there's the music mute bug which make transitions a bit weird)
	Obj.SetProperty("MasterVolume", MusicPlayer.DefaultMasterVolume, function(Vol)
		SoundGroup.Volume = Vol
	end)
	
	--[[
	<SoundGroup> - A reference to the current music sound group
	]]--
	Obj.SoundGroup = SoundGroup

	-- The primary sound instance to play the background music.
	-- Also used if the hitbox isn't in any music zone.
	Obj.SetProperty("MainSound", nil, function(Sound)
		if Obj.Autoplay == true then
			Obj.LastMusicMode = MusicPlayer.MusicMode.BySound
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
	end)
	
	--[[
	<boolean> - Whether or not music zones will have their sounds played,
				regardless of whether or not they're found
	]]--
	Obj.SetProperty("PlayMusicZones", false, function(PlayingMusicZones)
		if PlayingMusicZones then
			-- Start applying the music zones
			if ZoneEntryRunner == nil then
				ZoneEntryRunner = RunService.Heartbeat:Connect(Obj.RescanMusicZones)
			end
		else
			-- Disconnect entry runner
			if ZoneEntryRunner then
				ZoneEntryRunner:Disconnect()
				ZoneEntryRunner = nil
			end
			
			-- Fade back to the main sound
			task.spawn(FadeToPrimarySound)
		end
	end)

	--[[
	<boolean> - Whether or not music zones will be searched for
	]]--
	Obj.SetProperty("FindMusicZones", false, function(FindingMusicZones)
		--local MusicMode = MusicPlayer.MusicMode

		if FindingMusicZones == false then
			-- Disconnect the music zone collector
			SetInstancesCollected(false)

			-- Disconnect music zones
			--for i, v in pairs(ZoneParts) do
			--	SetZoneConnected(i, false)
			--end
			CurrentMusicZones = {}
			--coroutine.wrap(Obj.FadeToURL)(Obj.MainURL)
		elseif FindingMusicZones == true then
			-- Connect the music zone collector
			SetInstancesCollected(true)
		end
	end)

	--[[
	Fires when the sound info loaded into the BGM object changes.
	
	Params:
	Attribution <string> - The asset info/attribution.
	]]--
	Obj.AttributionChanged = Signal.New()

	-- Pause sound instance on disposal
	Obj.AddDisposalListener(function()
		Obj.AttributionChanged.DisconnectAll()
		--Obj.ReverseCompleted.Disconnect(ResetOldSounds)
		--Obj.Completed.Disconnect(ResetOldSounds)
		FadeOutConnection.Disconnect()
		FadeOutConnection = nil
		--Obj.BindHitbox(nil)

		Obj.UsesMusicZones = false
		Obj.MainURL = ""

		local CurrentSound = Obj.CurrentSound
		if CurrentSound ~= nil then
			ResetSound(CurrentSound)
		end
		CurrentSound = nil
	end)
	
	SoundGroup.Parent = script

	return Obj
end

return MusicPlayer