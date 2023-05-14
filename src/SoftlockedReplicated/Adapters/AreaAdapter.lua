-- A utility module for adapting to the game's Areas.
-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local AreaAdapter = {}

-- Original lighting properties to save, and the ones that
-- can be changed in the maps
local LIGHTING_PROPERTIES = {"FogColor", "FogStart", "FogEnd", "ClockTime"}

local CONFIG_FOLDER_NAME = "Config"
local LIGHTING_FOLDER_NAME = "Lighting"
local DEFAULT_TWEEN_INFO = TweenInfo.new()

local OriginalLighting = {}

-- Refreshes the original lighting to the current lighting
local function RefreshOriginalLighting()
	for i, v in pairs(LIGHTING_PROPERTIES) do
		OriginalLighting[v] = Lighting[v]
	end
end

RefreshOriginalLighting()

-- Animates to the lighting specified in the configuration table
-- in argument 1.
-- If argument 1 is nil, the lighting is reset.
function AreaAdapter.ApplyLighting(Config, TweeningInfo)
	TweeningInfo = TweeningInfo or DEFAULT_TWEEN_INFO
	
	if Config ~= nil then
		assert(typeof(Config) == "table", "Argument 1 must be a table.")

		-- Do a check that all the lighting properties can be changed.
		for i, v in pairs(Config) do
			local Property = tostring(i)

			if table.find(LIGHTING_PROPERTIES, i) == nil and Util.IsProperty(Lighting, Property) then
				warn("The " .. Property .. " lighting property cannot be animated.")
				break
			end
		end

		-- Tween.
		Util.Tween(Lighting, TweeningInfo, Config)
	else
		-- Reset.
		Util.Tween(Lighting, TweeningInfo, OriginalLighting)
	end
end

function AreaAdapter.New(Area)
	assert(typeof(Area) == "Instance", "Argument 1 must be an instance.")

	local Obj = Object.New("AreaAdapter")
	local LightingConfig = Area:WaitForChild(LIGHTING_FOLDER_NAME, 5)
	
	local DestroyListeners = {}
	local AppliedLighting -- The applied lighting folder.
	
	Obj.Info = {}
	Obj.InfoChangeEvents = nil
	
	-- TweenInfo used to animate lighting changes.
	Obj.LightingTweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	
	-- Removes an instance from the object table and
	-- disconnects the destroy connection made by the object
	function Obj.RemoveInstanceFromIndex(Index)
		Obj[Index] = nil
		
		local DestroySignal = DestroyListeners[Index]
		if DestroySignal ~= nil then
			DestroySignal:Disconnect()
		end
		DestroySignal = nil
	end
	
	-- Adds an instance to the object table and removes it when
	-- the instance is destroyed.
	function Obj.AddInstanceToIndex(Index, Inst)
		assert(typeof(Index) == "Instance", "Argument 2 must be an instance")
		
		-- Remove to avoid collision
		Obj.RemoveInstanceFromIndex(Index)
		
		-- Add the index
		Obj[Index] = Inst
		
		DestroyListeners[Index] = Inst.AncestryChanged:Connect(function(InstChanged, Parent)
			if InstChanged == Inst and Parent == nil then
				Obj.RemoveInstanceFromIndex(Index)
			end
		end)
	end
	
	local function AddInfoByValue(ValueInst)
		-- Add the current info
		local Name = ValueInst.Name
		local Val = ValueInst.Value
		Obj.Info[Name] = Val

		-- Listen for changes
		Obj.InfoChangeEvents[Name] = ValueInst.Changed:Connect(function(NewValue)
			Obj.Info[Name] = NewValue
			Object.FireCallback(Obj.InfoChanged, Name, NewValue)
		end)

	end

	local function AddInfoByInstance(Inst)
		-- Add the current info
		local Name = Inst.Name
		local Val = Inst

		Obj.Info[Name] = Val
	end

	-- Refreshes area information.
	function Obj.Refresh(Config)
		assert(typeof(Config) == "Instance", "Argument 1 must be an instance.")

		-- Disconnect previous info change events
		-- and clear the table.
		Obj.FinalizeInfo()
		Obj.Info = {}
		Obj.InfoChangeEvents = {}
		
		-- Add info by attribute.
		for i, v in pairs(Config:GetAttributes()) do
			Obj.Info[i] = v
		end

		-- Add info by instance.
		for i, v in pairs(Config:GetChildren()) do
			if typeof(v) == "Instance" then
				if v:IsA("ValueBase") then
					AddInfoByValue(v)
				else
					AddInfoByInstance(v)
				end
			end
		end
	end

	-- Gets the info stored under the provided index.
	function Obj.GetInfo(Index)
		local Info = Obj.Info

		if Info ~= nil then
			return Info[Index]
		end

		Info = nil
	end

	-- Disconnects info changes from being received.
	-- Obj.InfoChangeEvents will be set to nil.
	function Obj.FinalizeInfo()
		local ChangeEvents = Obj.InfoChangeEvents

		if ChangeEvents ~= nil then
			for i, v in pairs(ChangeEvents) do
				if typeof(v) == "RBXScriptConnection" then
					v:Disconnect()
				end
			end
		end

		ChangeEvents = nil
		Obj.InfoChangeEvents = nil
	end
	
	-- Sets if the area's specified lighting will be used.
	-- If argument 1 is false or the lighting folder doesn't exist,
	-- the lighting will be reset.
	function Obj.UseLighting(IsUsing)
		local LightTweenInfo = Obj.LightingTweenInfo
		
		if IsUsing == true and typeof(LightingConfig) == "Instance" then
			-- Apply the lighting instances
			if AppliedLighting ~= nil then
				AppliedLighting:Destroy()
				AppliedLighting = nil
			end
			AppliedLighting = LightingConfig:Clone()
			AppliedLighting.Name = "MapLighting"
			AppliedLighting.Parent = Lighting
			
			-- Animate
			AreaAdapter.ApplyLighting(LightingConfig:GetAttributes(), LightTweenInfo)
		else
			-- Destroy the lighting folder
			if AppliedLighting ~= nil then
				AppliedLighting:Destroy()
				AppliedLighting = nil
			end
			
			-- Animate the reset
			AreaAdapter.ApplyLighting(nil, LightTweenInfo)
		end
	end

	-- Fires when an area's info has been changed.
	-- Params: InfoName, InfoValue
	Obj.InfoChanged = nil

	-- Initialize
	local ConfigFolder = Area:WaitForChild(CONFIG_FOLDER_NAME, 5)
	if typeof(ConfigFolder) == "Instance" then
		Obj.Refresh(ConfigFolder)
	end
	ConfigFolder = nil
	
	Obj.OnDisposal = function()
		Obj.UseLighting(false)
	end

	return Obj
end

return AreaAdapter