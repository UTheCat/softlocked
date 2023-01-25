-- Utility module for playing a sound by its id.

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local SoundPlayer = {}
SoundPlayer.GlobalId = "SoundPlayerModuleGlobals"

SoundPlayer.__index = SoundPlayer

-- Returns a formatted asset ID relative to the one specified
local function FormatAssetId(AssetId)
	-- Format and return the correct asset id according to the type of the asset ID
	if typeof(AssetId) == "string" then
		return AssetId
	elseif typeof(AssetId) == "number" then
		return "rbxassetid://" .. AssetId
	else
		-- Since the asset id couldn't be formatted, return a blank string
		return ""
	end
end

local SoundGroupInit = nil
local function Initialize()
	if _G[SoundPlayer.GlobalId] == nil then
		_G[SoundPlayer.GlobalId] = {}
		if _G[SoundPlayer.GlobalId].IsInitialized == nil then
			_G[SoundPlayer.GlobalId].IsInitialized = true

			SoundGroupInit = Instance.new("SoundGroup")
			SoundGroupInit.Volume = 1
			SoundGroupInit.Name = SoundPlayer.GlobalId
			SoundGroupInit.Parent = SoundService
		else
			SoundGroupInit = SoundService:WaitForChild(SoundPlayer.GlobalId)
		end
	end
end

Initialize()

-- The SoundGroup for the module.
SoundPlayer.SoundGroup = SoundGroupInit

SoundGroupInit = nil

-- Returns if the provided sound instance has 
-- properly loaded.
function SoundPlayer.IsSoundLoaded(Sound)
	assert(typeof(Sound) == "Instance" and Sound:IsA("Sound"), "Argument 1 must be a Sound instance.")
	
	return Sound.IsLoaded == true and Sound.TimeLength > 0
end

-- Plays a sound once under the sound group.
function SoundPlayer.PlaySound(Id)
	local Group = SoundPlayer.SoundGroup
	
	if Group ~= nil then
		local Sound = Instance.new("Sound")
		Sound.SoundId = FormatAssetId(Id)
		Sound.Volume = 1
		Sound.SoundGroup = Group
		Sound.Parent = Group
		
		if SoundPlayer.IsSoundLoaded(Sound) then
			Sound.Loaded:Wait()
		end
		
		Sound:Play()
		Debris:AddItem(Sound, Sound.TimeLength)
		
		return Sound
	end
	
	Group = nil
end

return SoundPlayer