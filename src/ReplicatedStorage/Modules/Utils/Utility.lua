--[[
Utility.lua by udev2192

Contains some utility functions that are intended for widespread use

3/3/2021 - As of today, the set of utilities have been updated to support the new attributes system, superseding ValueBases.

Last Updated: 4 Mar 2021
]]--

-- Services:
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Module:
local Util = {} -- Store utilities in a table (there will be multiple uses for this)
local ActiveTweens = {} -- Tweens that are currently playing

-- To ensure that values in the module table are static
Util.__index = Util

Util.DefaultTweenName = "Tween"

-- Initialize a global attribute sets table (for attribute sets)
if typeof(_G.AttributeSets) ~= "table" then
	_G.AttributeSets = {}
end

-- Initialize a global property defaults table
if typeof(_G.PropertyDefaults) ~= "table" then
	_G.PropertyDefaults = {}
end

-- Getting "no value" which is different from "nil" (also known as "void")
function Util.GetVoid()
	local BlankTable = {}
	return BlankTable[0]
end

-- Linear interpolation
function Util.Lerp(a, b, t)
	return a + (b - a) * t
end

-- RunService based wait
function Util.WaitFor(Duration) -- Accurate wait function, returns the difference between actual wait and desired wait
	if typeof(Duration) == "number" then
		local ActualWait = 0

		-- Wait until time's up
		while ActualWait < Duration do
			ActualWait = ActualWait + RunService.Heartbeat:Wait()
		end

		-- Return the difference between the actual wait and the desired wait
		return ActualWait - Duration
	end
end

-- String formatting
function Util.FormatAssetId(AssetId) -- Returns a correctly formatted asset ID relative to the one specified
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

function Util.SeparateCharacters(String) -- Separates each character in the string with a space and returns the newly formatted string
	if typeof(String) == "string" then
		local StringLength = string.len(String)
		local CombinedString = "" -- Holds the formatted string

		-- Split each character
		for i, v in ipairs(string.split(String,"")) do
			if i < StringLength then -- So a space isn't added at the very end of the string
				CombinedString = CombinedString .. v .. " " -- Add the space
			else
				CombinedString = CombinedString .. v
			end
		end

		-- Garbage collection
		String, StringLength = nil, nil

		-- Return the newly formatted string
		return CombinedString
	else
		error("Cannot separate the characters of a non-string value.")
		return nil
	end
end

-- Conditionals
function Util.IsConnection(Object) -- Returns if the specified object is a event connection
	return typeof(Object) == "RBXScriptConnection"
end

function Util.IsInstance(Object) -- Returns if the specified object is an instance
	return typeof(Object) == "Instance"
end

function Util.IsBasePart(Object)
	return Util.IsInstance(Object) and Object:IsA("BasePart")
end

function Util.IsGUI(Object) -- Returns if the specified object is an GUI object
	return Util.IsInstance(Object) and Object:IsA("GuiObject")
end

function Util.IsTween(Object) -- Returns if the specified object is a TweenBase
	return Util.IsInstance(Object) and Object:IsA("TweenBase")
end

function Util.IsTweenPlaying(Tween) -- Returns if the specified tween is playing
	return Util.IsTween(Tween) and Tween.PlaybackState == Enum.PlaybackState.Playing
end

function Util.IsProperty(Object, PropertyName) -- Returns if the property exists for the specified Instance
	if typeof(Object) == "Instance" then
		-- Use pcall as a hacky solution
		local Success, Property = pcall(function()
			return Object[PropertyName] -- Index the property (for the most part, should not return an instance)
		end)

		-- The success of the protected call indicates that it's a valid property
		return Success
	end
end

-- Table manipulation
function Util.ShiftArray(Array, Integer) -- Returns the array specified with all its elements shifted by the integer
	if typeof(Array) == "table" then
		local NumType = typeof(Integer)

		if NumType == "number" then
			if Integer ~= 0 then
				if Integer % 1 == 0 then -- Detect if it's an integer

					local ShiftedTable = {} -- The resulting table
					-- Loop through the array to shift its contents
					for i, v in ipairs(Array) do
						-- Move to the shifted position (for a different table so no problems occur with overwrite)
						ShiftedTable[i + Integer] = v
					end

					return ShiftedTable -- Return the array with the shifted elements
				else
					error("Integer specified must be an integer")
				end
			else
				error("Shift increment cannot be 0")
			end
		else
			error("Number to shift by expected a number but got " .. NumType)
		end

		NumType = nil
	else
		error("The Array argument must be an array for it to work.")
	end
end

-- Attribute manipulation
function Util.WriteAttributeSet(SetName, Attributes) -- Registers an attribute set
	if typeof(SetName) == "string" and typeof(Attributes) == "table" then
		_G.AttributeSets[SetName] = Attributes
	else
		error("Cannot create attribute set due to invalid arguments. SetName must be a string and Attributes must be a key-value table.")
	end
end

function Util.DeleteAttributeSet(SetName)
	if typeof(SetName) == "string" then
		_G.AttributeSets[SetName] = nil -- Unregister the attribute set
	else
		error("Attribute set name to delete must be a string.")
	end
end

function Util.GetAttributeSet(SetName) -- If it has been registered, gets the attribute set from _G.AttributeSets as a table
	if typeof(SetName) == "string" then
		local Set = _G.AttributeSets[SetName]
		if typeof(Set) == "table" then
			return Set -- Return if found
		else
			error(SetName .. " isn't a registered attribute set. Use Util.WriteAttributeSet to do so.")
			return nil
		end
	else
		error("Cannot get attribute set because SetName provided isn't a string.")
		return nil
	end
end

function Util.ApplyAttribute(Object, Name, Value) -- Serves as a wrapper for adding a new attribute
	if typeof(Object) == "Instance" then
		local Success, Result = pcall(function() -- Just in case
			Object:SetAttribute(Name, Value)
		end)
		if Success ~= true then
			error("Failed to set attribute because of error: " .. tostring(Result))
		end
	else
		error("Cannot apply an attribute to a non-Instance.")
	end
end

function Util.ApplyAttributesFromTable(Object, Table) -- Applies the attributes from the specified table
	if typeof(Object) == "Instance" then
		if typeof(Table) == "table" then
			for i, v in pairs(Table) do
				Util.ApplyAttribute(Object, i, v) -- Apply the attribute
			end
		else
			error("Attributes table must be a table.")
		end
	else
		error("Cannot apply attributes to a non-Instance.")
	end
end

function Util.ApplyAttributeSet(Object, Name) -- Applies the attributes from a set registered by this module
	if typeof(Object) == "Instance" then
		if typeof(Name) == "string" then
			-- Find the attribute set from the global table
			local Set = _G.AttributeSets[Name]

			if typeof(Set) == "table" then
				-- Apply attributes if existant
				Util.ApplyAttributesFromTable(Object, Set)
			else
				error(Name .. " isn't a registered attribute set. Use Util.WriteAttributeSet to do so.")
			end

			Set = nil
		else
			error("Attribute set name must be a string.")
		end
	else
		error("Cannot apply attributes to a non-Instance.")
	end
end

function Util.ExtractValueBases(Object) -- Returns a table of key/name-value pairs of an object's value-base children
	if typeof(Object) == "Instance" then
		local Table = {}
		for i, v in pairs(Object:GetChildren()) do
			if typeof(v) == "Instance" and v:IsA("ValueBase") then
				Table[v.Name] = v.Value
			end
		end
		return Table
	else
		return nil
	end
end

-- Instance manipulation
function Util.ApplyProperties(Object, PropertiesTable) -- Applies properties to an object without it erroring (even if the property is invalid)
	if typeof(Object) == "Instance" then
		local PropertyType = typeof(PropertiesTable)

		if PropertyType == "table" then
			-- Set the properties according to the table
			for i, v in pairs(PropertiesTable) do
				if Util.IsProperty(Object, i) == true then
					Object[i] = v
				else
					error(tostring(i) .. " is an invalid property of " .. tostring(Object.ClassName))
				end
			end
		else
			error("ApplyProperties() expected a table but got " .. PropertyType)
			PropertyType = nil
		end
	end
end

function Util.SetPropertyDefaults(InstanceName, Properties) -- Sets the property defaults of the instance name provided to the properties table provided.
	-- These defaults will be applied in Util.CreateInstance()
	-- Specify the second argument with nil (or leave it blank) to remove the property defaults
	
	if typeof(InstanceName) == "string" then
		-- Correct the properties table format
		if Properties ~= nil and typeof(Properties) ~= "table" then
			Properties = {}
		end
		
		-- Register (or delete) the property defaults
		_G.PropertyDefaults[InstanceName] = Properties
	end
end

function Util.ApplyDefaultProperties(Object) -- Applies the property defaults specified with Util.SetPropertyDefaults to the provided instance
	if Util.IsInstance(Object) == true then
		-- Reference the defaults for the instance class type
		local Defaults = _G.PropertyDefaults[Object.ClassName]
		
		-- Apply the defaults
		Util.ApplyProperties(Object, Defaults)
		
		-- Garbage collect
		Defaults = nil
	end
end

function Util.CreateInstance(Type: string, PropertiesTable: {string: any}?) -- Creates an instance the Roact way (warns if the instance doesn't exist). Returns the instance created. Thanks to ChipioIndustries for making Roact
	if typeof(Type) == "string" then
		-- Make the object with the properties
		local Success, Result = pcall(function()
			local Object = Instance.new(Type)
			
			-- Format the properties table correctly
			if typeof(PropertiesTable) ~= "table" then
				PropertiesTable = {}
			end
			
			-- Apply missing properties with the defaults provided with Util.SetPropertyDefaults()
			local Defaults = _G.PropertyDefaults[Type]
			if typeof(Defaults) == "table" then
				for i, v in pairs(Defaults) do
					if PropertiesTable[i] == nil then -- Check if the property hasn't been specified before applying
						PropertiesTable[i] = v -- Apply the default property setting
					end
				end
			end
			Defaults = nil
			
			-- Apply the properties
			Util.ApplyProperties(Object, PropertiesTable)
			
			return Object
		end)

		-- Return the newly created object if the creation was successful
		if Success == true then
			Success = nil
			return Result
		else
			error("Couldn't create instance because of error: " .. tostring(Result))
			Success, Result = nil, nil
			return nil
		end
	end
end

-- Tweening
function Util.PlayTween(Tween, Duration) -- Plays the specified tween, then destroys it
	if Util.IsTween(Tween) then		
		-- Play the tween
		Tween:Play()
		if typeof(Duration) == "number" and Duration > 0 then
			Util.WaitFor(Duration) -- In case of tween collision issues
		else
			Tween.Completed:Wait()
		end
		
		-- Destroy the tween
		Tween:Destroy()
		Tween, Duration = nil, nil
	end
end

--[[
Pauses and destroys any of an object's tweens that has a matching name

Name <string?> - The name of tweens to cancel (leave blank for all tweens)
]]--
function Util.DestroyTweens(Object: Instance, Name: string?)
	assert(typeof(Object) == "Instance", "Argument 1 must be an instance")
	assert(Name == nil or typeof(Name) == "string", "Argument 2 must be a string or nil")
	
	for i, v in pairs(Object) do
		if Name == nil or v.Name == Name then
			v:Pause()
			v:Destroy()
		end
	end
end

-- Plays a tween for the object provided and ensures there are no tween collisions. Returns the tween created.
-- Credit to ForbiddenJ for figuring out that tweens can be named and accessed via GetChildren()
function Util.Tween(Object: Instance, TweenStyle: TweenInfo, Properties: {string: any}, Name: string?)
	-- Set to the default tween style if one isn't provided
	if typeof(TweenStyle) ~= "TweenInfo" then
		TweenStyle = TweenInfo.new()
	end
	
	if Util.IsInstance(Object) and typeof(Properties) == "table" then
		-- Pause the colliding tween if it exists
		--Util.DestroyTweens(Object, Name)
		if Util.IsTween(ActiveTweens[Object]) == true then
			ActiveTweens[Object]:Pause()
			ActiveTweens[Object]:Destroy()
		end
		
		-- Construct the tween
		local Tween = TweenService:Create(Object, TweenStyle, Properties)
		Tween.Name = Name or Util.DefaultTweenName
		
		-- Play the tween if the tweening time is greater than 0, otherwise, insta-change the properties
		if TweenStyle.Time > 0 then
			-- Collision-proof the tween			
			ActiveTweens[Object] = Tween
			
			-- Play the tween
			task.spawn(function() -- Don't yield the thread while the tween plays
				Util.PlayTween(Tween, TweenStyle.Time) -- Will yield until it's finished
				ActiveTweens[Object] = nil -- Garbage collect
			end)
		else
			task.spawn(Util.ApplyProperties, Properties) -- Insta-change
		end
		
		-- Make the tween accessible elsewhere
		return Tween
	else
		error("Cannot tween because of missing arguments (Object or Properties).")
	end
end

-- Geometry
-- Converts the angle so that if it exceeds 180 degrees, the remainder will still be accounted for
function Util.ConvertAngle(Angle)
	if Angle < 180 then
		return Angle
	elseif Angle < 360 then
		return -(Angle - 180)
	else
		local Remainder = Angle%180
		return Util.ConvertAngle(Remainder) -- We go through the function again in case the remainder is 180 or greater
	end
end

-- Returns the angle of CFrame2 relative to where CFrame1 is facing. Credits to sircfenner for the solution, devforum post: https://devforum.roblox.com/t/how-to-check-if-an-object-is-within-an-angle-of-the-front-of-a-player-s-characters/214046/3
-- probably doesn't work
function Util.GetRelativeAngle(CFrame1, CFrame2)
	if typeof(CFrame1) == "CFrame" and typeof(CFrame2) == "CFrame" then
		local Face = CFrame2.LookVector -- The face to project the angle from
		local Difference = CFrame1.Position - CFrame2.Position
		local Vector = Difference.Unit -- The unit vector is important here, this determines the angle projected because it serves as a second point of reference
		local RelativeAngle = math.deg(math.acos(Face:Dot(Vector)))
		Face, Vector = nil, nil -- Garbage collect
		return RelativeAngle / Difference.Magnitude ^ 0.5
	else
		return nil
	end
end

-- Converts the WorldOri vector into the object space relative to the axis vector
-- probably doesn't work
function Util.GetObjectSpaceRotation(Axis, WorldOri)
	if typeof(Axis) == "Vector3" and typeof(WorldOri) == "Vector3" then
		-- Do translation
		local X = WorldOri.X - Axis.X
		local Y = WorldOri.Y - Axis.Y
		local Z = WorldOri.Z - Axis.Z

		-- Convert the components into a proper angle
		X = Util.ConvertAngle(X)
		Y = Util.ConvertAngle(Y)
		Z = Util.ConvertAngle(Z)

		return Vector3.new(X, Y, Z) -- Return the Vector in object space
	else
		error("Both arguments must be Vector3s.")
		return nil
	end
end

-- probably doesn't work
function Util.GetWorldSpaceRotation(Axis, Orientation) -- Returns the orientation of the 2nd argument relative to the axis vector in world space
	if typeof(Axis) == "Vector3" and typeof(Orientation) == "Vector3" then
		print(Axis)
		print(Orientation)

		-- Do translation
		local X = Axis.X + Orientation.X
		local Y = Axis.Y + Orientation.Y
		local Z = Axis.Z + Orientation.Z

		-- Convert the components into a proper angle
		X = Util.ConvertAngle(X)
		Y = Util.ConvertAngle(Y)
		Z = Util.ConvertAngle(Z)

		return Vector3.new(X,Y,Z) -- Return the Vector in world space
	else
		error("Both arguments must be Vector3s.")
		return nil
	end
end

function Util.IsInBasePart(BasePart1, BasePart2, IncludeBasePart1Size) -- Determines if BasePart1 is inside BasePart2
	-- BasePart1 should be the BasePart where it is seeing if it's inside or not (such as the head)
	-- If IncludeBasePart1Size is true, the entire volume of the BasePart is counted, instead of determining it from the center
	if (Util.IsBasePart(BasePart1) or typeof(BasePart1) == "Instance" and BasePart1:IsA("Camera"))and Util.IsBasePart(BasePart2) then
		local LocalPoint = BasePart2.CFrame:PointToObjectSpace(BasePart1.CFrame.Position)
		if IncludeBasePart1Size == true then
			LocalPoint = LocalPoint - BasePart1.Size
		end
		if math.abs(LocalPoint.X) < BasePart2.Size.X/2 and math.abs(LocalPoint.Y) < BasePart2.Size.Y/2 and math.abs(LocalPoint.Z) < BasePart2.Size.Z/2 then
			return true
		else
			return false
		end
	end
	return nil
end

-- Client only:
if RunService:IsClient() then
	local GuiService = game:GetService("GuiService")
	local UserInputService = game:GetService("UserInputService")

	function Util.GetPlatform() -- Returns the type of device the player is on
		if GuiService:IsTenFootInterface() then
			return "Console"
		elseif UserInputService.TouchEnabled then
			return "Mobile"
		elseif UserInputService.VREnabled then
			return "VR"
		elseif UserInputService.KeyboardEnabled then
			return "PC"
		else
			-- Probably will never get to here but we'll leave this just in case
			warn("Unknown platform, certain things may break")
			return "Unknown"
		end
	end
end

return Util