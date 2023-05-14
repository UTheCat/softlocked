-- Provides an object that is used to play background music.

-- This is the legacy background music player and therefore, is deprecated.

-- By udev2192

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local BGM = {}

-- The default BGM url.
BGM.DefaultURL = ""

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

function BGM.New()
	local Obj = Object.New("ClientBGM")
	Obj.SoundInstance = nil
	Obj.IsLoaded = false
	
	-- By default, the name of the sound asset
	-- that was just loaded.
	Obj.AssetInfo = ""
	
	-- The length of the music transition in seconds.
	Obj.FadeTime = 1
	
	-- Sets if the audio plays the new URL as soon as it's changed
	Obj.Autoplay = true
	
	-- Fades to a new sound by URL
	-- If URL is nil, the sound will fade out and stop
	local function FadeToURL(URL)
		local OldSound = Obj.SoundInstance
		
		if Obj.FadeTime > 0 then	
			-- Fade over the duration
			local FadeTime = Obj.FadeTime or 1
			if OldSound ~= nil then
				coroutine.wrap(function()
					local Tween = FadeSound(OldSound, 0, FadeTime)
					if Util.IsTweenPlaying(Tween) then
						Tween.Completed:Wait()
					end
					OldSound:Destroy()
					OldSound = nil
				end)()
			end
			
			if IsSoundURL(URL) == true then
				local NewSound = Instance.new("Sound")
				Obj.SoundInstance = NewSound
				NewSound.SoundId = URL
				NewSound.Volume = 0
				NewSound.Looped = true
				NewSound.Parent = script

				-- Fade in the new sound once it loads
				coroutine.wrap(function()
					if NewSound.IsLoaded == false then
						NewSound.Loaded:Wait()
					end
					if IsSoundLoaded(NewSound) then
						NewSound:Play()
						FadeSound(NewSound, Obj.Volume, FadeTime)
					else
						NewSound:Destroy()
						warn("Failed to load sound: " .. URL)
					end

					NewSound = nil
				end)()
			else
				Obj.SoundInstance = nil
			end
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
	
	local function UpdateInfoInternally(URL)
		-- Find the id in the URL string, if needed
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
	
	-- Gets the sound info of the currently loaded sound.
	-- This yields the current thread.
	function Obj.UpdateSoundInfo()
		local Sound = Obj.SoundInstance
		if Sound ~= nil then
			UpdateInfoInternally(Sound.SoundId)
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
	
	Obj.SetProperty("Volume", 0.5, function(vol)
		local Sound = Obj.SoundInstance
		if Sound ~= nil then
			Sound.Volume = vol
		end
		Sound = nil
	end)
	
	Obj.SetProperty("SoundURL", BGM.DefaultURL, function(URL)
		if Obj.Autoplay == true then
			FadeToURL(Util.FormatAssetId(URL))
		end
		coroutine.wrap(UpdateInfoInternally)(URL)
	end)
	
	-- Fires when the asset info loaded into the BGM object changes.
	Obj.AssetInfoChanged = nil
	
	return Obj
end

return BGM