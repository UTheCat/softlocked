--[[
The utility module for client interactives. These are just mechanics that can be used in levels or community builds
(some may know these as ClientObjects) and are intended to be bound to instances

This also contains the base interactive class (which is a bunch of signals for implementation)

By udev2192
]]--

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("SoftlockedReplicated")

local Interactives = script.Parent
local MapHandles = Interactives.Parent
local Mechanics = Interactives:WaitForChild("Mechanics")

local Adapters = RepModules:WaitForChild("Adapters")
local UtilRepModules = RepModules:WaitForChild("Utils")

local CharAdapter = require(Adapters:WaitForChild("CharacterAdapter"))

local IntroText = require(MapHandles:WaitForChild("Gui"):WaitForChild("IntroText"))

local Signal = require(UtilRepModules:WaitForChild("Signal"))
local Utils = require(UtilRepModules:WaitForChild("Utility"))
local Object = require(UtilRepModules:WaitForChild("Object"))
local TweenGroup = require(UtilRepModules:WaitForChild("TweenGroup"))

local Interactives = script.Parent
local abs = math.abs

local LocalPlayer

export type InteractiveObject = {
	OnInitialize: () -> ()?,
	OnStart: () -> ()?,
	OnShutdown: () -> ()?
} & Object.ObjectPool

local BaseInteractive = {}
BaseInteractive.__index = BaseInteractive
BaseInteractive.ClassName = script.Name

BaseInteractive.GlobalId = Interactives.Name .. "/Globals"

-- A few attribution names
BaseInteractive.PhysicsRadiusAttribute = "PhysicsRadius"

--[[
<string> - The name given to a module which specifies that
		   it defines the behavior of the interactive
]]--
BaseInteractive.DefinitionName = "CustomDefinition"

BaseInteractive.ValueClassName = "StringValue"
BaseInteractive.ScreenGuiName = "InteractiveGui"

BaseInteractive.DefaultCharacterSize = Vector3.new(0, 5, 0)

--[[
<table> - Collision group names for BaseParts
]]--
BaseInteractive.CollisionGroups = {
	Default = PhysicsService:GetCollisionGroupName(0),
	Players = "PlayerCollisionGroup",
	Interactives = "InteractiveCollisionGroup",
}

--[[
<table> - Collision groups used for filtering, such that
		  its BaseParts can only collide with a particular
		  collision group
]]--
BaseInteractive.CollisionFilters = {
	DefaultOnly = "DefaultOnly",
	PlayersOnly = "PlayersOnly",
	InteractivesOnly = "InteractivesOnly"
}

-- Type definitions

-- Global setup
if _G[BaseInteractive.GlobalId] == nil then
	_G[BaseInteractive.GlobalId] = {}
end

if _G[BaseInteractive.GlobalId].Reserved == nil then
	_G[BaseInteractive.GlobalId].Reserved = {}
end

if _G[BaseInteractive.GlobalId].Definitions == nil then
	_G[BaseInteractive.GlobalId].Definitions = {}
end

-- The storage table is for use by interactives
if _G[BaseInteractive.GlobalId].InteractStorage == nil then
	_G[BaseInteractive.GlobalId].InteractStorage = {}
end

-- Table reference (micro-optimization)
local Globals = _G[BaseInteractive.GlobalId]
local Definitions = Globals.Definitions -- For external interactive code definitions
local InteractStorage = Globals.InteractStorage -- For external interactive values
local Reserved = Globals.Reserved

-- Server global setup
if RunService:IsServer() then
	
end

-- Client global setup
if RunService:IsClient() then
	LocalPlayer = Players.LocalPlayer
	
	if Reserved.CharacterHandle == nil then
		Reserved.CharacterHandle = CharAdapter.New(LocalPlayer)
	end
	
	if Reserved.InteractiveGui == nil then
		local Gui = Instance.new("ScreenGui")
		Reserved.InteractiveGui = Gui
		
		Gui.Name = BaseInteractive.ScreenGuiName
		Gui.ResetOnSpawn = false
		Gui.IgnoreGuiInset = true
		Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	
	if Reserved.InteractiveWorkspace == nil then
		local InteractWorkspace = Instance.new("Folder")
		Reserved.InteractiveWorkspace = InteractWorkspace
		
		InteractWorkspace.Name = BaseInteractive.ClassName .. "WSCache"
		InteractWorkspace.Parent = workspace
	end
end

function BaseInteractive.AssertClient()
	assert(RunService:IsClient(), "This action can only be performed from the client.")
end

function BaseInteractive.AssertServer()
	assert(RunService:IsServer(), "This action can only be performed from the server")
end

--[[
Destroys collision groups other than the default one
]]--
function BaseInteractive.DeleteCollisionGroups()
	BaseInteractive.AssertServer()

	local Groups = BaseInteractive.CollisionGroups
	local Default = Groups.Default

	for i, v in pairs(PhysicsService:GetCollisionGroups()) do
		if v ~= Default then
			PhysicsService:RemoveCollisionGroup(v)
		end
	end
	
	Reserved.CollisionGroupsCreated = nil
end

--[[
Creates collision groups listed in the CollisionGroups table
other than the default one
]]--
function BaseInteractive.CreateCollisionGroups()
	BaseInteractive.AssertServer()
	
	if Reserved.CollisionGroupsCreated == nil then
		Reserved.CollisionGroupsCreated = true
		
		local Groups = BaseInteractive.CollisionGroups
		local Filters = BaseInteractive.CollisionFilters

		local Default = Groups.Default

		for i, v in pairs(Groups) do
			if v ~= Default then
				PhysicsService:CreateCollisionGroup(v)
			end
		end

		for i, v in pairs(Filters) do
			if v ~= Default then
				PhysicsService:CreateCollisionGroup(v)
			end
		end
	end
end


--[[
Resets collision group behavior
]]--
function BaseInteractive.RefreshCollisionGroups()
	BaseInteractive.AssertServer()
	
	local Groups = BaseInteractive.CollisionGroups
	local Filters = BaseInteractive.CollisionFilters
	
	local Default = Groups.Default
	local Players = Groups.Players
	local Interactives = Groups.Interactives
	
	local DefaultOnly = Filters.DefaultOnly
	local PlayersOnly = Filters.PlayersOnly
	local InteractivesOnly = Filters.InteractivesOnly
	
	-- Whether or not players can collide with each other
	PhysicsService:CollisionGroupSetCollidable(Players, Players, false)
	
	-- Every other group
	PhysicsService:CollisionGroupSetCollidable(Default, Players, true)
	
	PhysicsService:CollisionGroupSetCollidable(DefaultOnly, Default, true)
	PhysicsService:CollisionGroupSetCollidable(DefaultOnly, Players, false)
	PhysicsService:CollisionGroupSetCollidable(DefaultOnly, Interactives, false)
	
	PhysicsService:CollisionGroupSetCollidable(PlayersOnly, Default, false)
	PhysicsService:CollisionGroupSetCollidable(PlayersOnly, Players, true)
	PhysicsService:CollisionGroupSetCollidable(PlayersOnly, Interactives, false)
	
	PhysicsService:CollisionGroupSetCollidable(InteractivesOnly, Default, false)
	PhysicsService:CollisionGroupSetCollidable(InteractivesOnly, Players, false)
	PhysicsService:CollisionGroupSetCollidable(InteractivesOnly, Interactives, true)
end

--[[
Clears all custom interactive definitions from the global

Params:
Name <string> - The name of the definition to be removed
]]--
function BaseInteractive.ClearDefinitions()
	Definitions = {}
end

--[[
Removes a custom interactive definition

Params:
Name <string> - The name of the definition to be removed
]]--
function BaseInteractive.RemoveDefinition(Name: string)
	assert(typeof(Name) == "string", "Argument 1 must be a string.")

	Definitions[Name] = nil
end

--[[
Adds a custom interactive definition

Params:
Name <string> - The name of the definition to be removed
Table <table> - The interactive's definition as a Lua table
]]--
function BaseInteractive.AddDefinition(Name: string, Table: table)
	assert(typeof(Name) == "string", "Argument 1 must be a string.")
	assert(typeof(Table) == "table", "Argument 2 must be a table.")

	Definitions[Name] = Table
end

--[[
Looks for interactive's class definition by name.
Order goes as follows:
1) Custom definitions (listed in the global)
2) Listed definitions in the module's parent

Params:
Name <string> - The interactive class/code to look for

Returns:
<table> - If the interactive is listed, it returns its class definition.
		  Otherwise, it returns nil.
]]--
function BaseInteractive.GetByName(Name: string) : {}?
	local ScriptName = script.Name
	assert(Name ~= ScriptName, "Interactive class name cannot be '" .. ScriptName .. "'")
	ScriptName = nil
	
	local Global = Definitions[Name]
	
	if typeof(Global) == "table" then
		return Global
	end
	
	Global = Mechanics:FindFirstChild(Name)
	
	if Global and Global:IsA("ModuleScript") then
		-- Save and return the new global
		Global = require(Global)
		BaseInteractive.AddDefinition(Name, Global)
		
		return Global
	end
	
	return nil
end

--[[
Looks for interactive's class definition by instance.
Order goes as follows:
1) The "_Definition" module in the instance
2) Whatever is returned by GetByName()

Params:
StringVal <StringValue> - The instance to search an interactive definition for

Returns:
<table> - If the interactive is listed, it returns its class definition.
		  Otherwise, it returns nil.
]]--
function BaseInteractive.GetByInstance(StringVal: StringValue) : {}?
	assert(
		typeof(StringVal) == "Instance" and StringVal.ClassName == BaseInteractive.ValueClassName,
		"Instance passed as the 1st argument must be a " .. BaseInteractive.ValueClassName
	)
	
	local CustomDef = StringVal:FindFirstChild(BaseInteractive.DefinitionName)
	if CustomDef and CustomDef:IsA("ModuleScript") then
		return CustomDef
	end
	
	return BaseInteractive.GetByName(StringVal.Value)
end

--[[
Returns the ScreenGui intended for use by Interactives and Maps

Returns:
<ScreenGui> - The ScreenGui
]]--
function BaseInteractive.GetScreenGui(): ScreenGui
	return Reserved.InteractiveGui
end

--[[
Returns the Workspace folder used to hold interactives

Returns:
<ScreenGui> - The ScreenGui
]]--
function BaseInteractive.GetWorkspace(): Folder
	return Reserved.InteractiveWorkspace
end

--[[
Returns the CharacterAdapter for the local player.
This will error if not called from the client.

Returns:
<CharacterAdapter> - The LocalPlayer's CharacterAdapter.
]]--
function BaseInteractive.GetCharacterHandle()
	BaseInteractive.AssertClient()
	
	return Reserved.CharacterHandle
end

--[[
Returns:
<table> - The table used to hold the table of general utility functions
]]--
function BaseInteractive.GetGeneralUtils()
	return Utils
end

--[[
Returns:
<BasePart> - The BasePart created as the hitbox for the character
]]--
function BaseInteractive.GetHitbox()
	BaseInteractive.AssertClient()

	return BaseInteractive.GetCharacterHandle().Parts.Hitbox
end

--[[
Returns:
<table> - The table containing the signal class that provides an alternative to
		  the BindableEvent
]]--
function BaseInteractive.GetSignalClass()
	return Signal
end

--[[
Returns:
<table> - The table containing the base class used for all object-oriented stuff
]]--
function BaseInteractive.GetObjectClass()
	return Object
end

--[[
Returns:
<table> - The table containing the tweening group class
]]--
function BaseInteractive.GetTweenGroupClass()
	return TweenGroup
end

--[[
Returns:
<Folder> - The folder instance containing Utility classes/modules
]]--
function BaseInteractive.GetUtilPackage()
	return UtilRepModules
end

--[[
Returns:
<Signal> - A synchronized event listener
]]--
function BaseInteractive.CreateSyncedSignal()
	local Signal = Signal.New()
	Signal.Sync = true

	return Signal
end

--[[
Returns the value associated with a storage key for interactives.

Params:
Name <string> - The key to use when looking for the corresponding value

Returns:
<any> - The value (or nil if it doesn't exist)
]]--
function BaseInteractive.GetGlobal(Name: string) : any
	return InteractStorage[Name]
end

--[[
Stores a global value for use by interactives.

Params:
Name <string> - The key to store
Value <any> - The value to store
]]--
function BaseInteractive.SetGlobal(Name: string, Value: any)
	InteractStorage[Name] = Value
end

--[[
Just like StoreGlobal() but only sets the value
if it hasn't already been set.

Params:
Name <string> - The key to store
Value <any> - The value to store
]]--
function BaseInteractive.InitializeGlobal(Name: string, Value: any)
	if BaseInteractive.GetGlobal(Name) == nil then
		BaseInteractive.SetGlobal(Name, Value)
	end
end

--[[
Returns the distance of two vectors

Params:
Vect1 <Vector3> - The first vector
Vect2 <Vector3> - The second vector

Returns:
<number> - The distance
]]--
function BaseInteractive.GetDistance(Vect1: Vector3, Vect2: Vector3) : number
	return (Vect2 - Vect1).Magnitude
end

--[[
Returns the hypotenuse of two lengths

Params:
a <number> - The first length (usually the base of a triangle)
b <number> - The second length (usually the height of a triangle)

Returns:
<number> - The hypotenuse
]]--
function BaseInteractive.Hypotenuse(a: number, b: number) : number
	return math.sqrt(a^2 + b^2)
end

--[[
Determines whether or not the object is a table
with the CFrame and Size properties

Returns:
<boolean> - If the above is true
]]--
function BaseInteractive.Is3dObject(Obj: {})
	if typeof(Obj) == "table" or typeof(Obj) == "Instance" then
		if typeof(Obj.CFrame) == "CFrame" and typeof(Obj.Size) == "Vector3" then
			return true
		end
	end

	return false
end

--[[
Determines if a point converted to object space is within the bounds of the
corresponding part

Params:
LocalPoint <Vector3> - The point converted to object space
ObjectSize <Vector3> - The object's size
Offset <Vector3> - How much to offset the size 
ShapeType <ShapeType> - The part's shape
]]--
function BaseInteractive.IsInLocalBounds(LocalPoint: Vector3, ObjectSize: Vector3, Offset: Vector3, ShapeType: EnumItem)
	-- Offset compared size, smaller means more constrained
	ObjectSize = (ObjectSize + Offset) * 0.5

	-- Get local point and object size components
	-- Use absolute value for the LocalPoint so that
	-- negative numbers won't affect the bound results.
	local LocalX = abs(LocalPoint.X + Offset.X)
	local LocalY = abs(LocalPoint.Y + Offset.Y)
	local LocalZ = abs(LocalPoint.Z + Offset.Z)

	local SizeX = ObjectSize.X
	local SizeY = ObjectSize.Y
	local SizeZ = ObjectSize.Z

	local ValidTypes = Enum.PartType

	-- Use the corresponding formula to determine in-bounds status
	-- (Use less than or equal to for comparision accuracy)
	if ShapeType == ValidTypes.Block then
		-- Return the bounding status of the "box-shaped" 3d objects
		return LocalX <= SizeX and LocalY <= SizeY and LocalZ <= SizeZ
	elseif ShapeType == ValidTypes.Cylinder then
		-- In a Roblox cylinder, the non-circular coordinate is the X
		-- coordinate. Take that into account when finding the hypotenuse
		-- Use the object space Y-position to compare hypotenuse bounding status
		return LocalX <= SizeX and BaseInteractive.Hypotenuse(LocalY, LocalZ) <= SizeZ + (Offset.Z)
	elseif ShapeType == ValidTypes.Ball then
		-- Use the hypotenuse function for faster performance
		-- (Use x and z coordinates for that)
		-- If the hypotenuse is less than or equal to the Y size,
		-- mark it as "in bounds" and return true
		-- If that passes, then do the same, but this time, 
		-- compare the hypotenuse of y and z to x,
		-- then the hypotenuse of x and y to z

		--local XDist = abs(SizeY - LocalY)
		--local YDist = abs(SizeY - LocalY)
		--local ZDist = abs(SizeZ - LocalZ)

		-- The Y coordinate of ObjectSize / 2 will indicate radius
		--local Hypo = Hypotenuse(XDist, ZDist)
		-- Use local point coordinates, since that will determine offset
		-- from the center due to it being object space
		return BaseInteractive.Hypotenuse(LocalX, LocalZ) <= SizeY
		--and Hypotenuse(YDist, ZDist) <= SizeX
		--and Hypotenuse(XDist, YDist) <= SizeZ
	end
end

--function BaseInteractive.IsInLocalBounds(LocalPoint: Vector3, ObjectSize: Vector3, Offset: Vector3, ShapeType: EnumItem)
--	-- Offset compared size, smaller means more constrained
--	ObjectSize = (ObjectSize * 0.5)

--	-- Get local point and object size components
--	-- Use absolute value for the LocalPoint so that
--	-- negative numbers won't affect the bound results.
--	local LocalX = abs(LocalPoint.X)
--	local LocalY = abs(LocalPoint.Y)
--	local LocalZ = abs(LocalPoint.Z)
	
--	local HitSizeX = ObjectSize.X - LocalX
--	local HitSizeY = ObjectSize.Y - LocalY
--	local HitSizeZ = ObjectSize.Z - LocalZ

--	--local SizeX = ObjectSize.X
--	--local SizeY = ObjectSize.Y
--	--local SizeZ = ObjectSize.Z

--	local ShapeTypes = Enum.PartType

--	-- Use the corresponding formula to determine in-bounds status
--	-- (Use less than or equal to for comparision accuracy)
--	if ShapeType == ShapeTypes.Block then
--		-- Return the bounding status of the "box-shaped" 3d objects
--		--return LocalX <= SizeX and LocalY <= SizeY and LocalZ <= SizeZ
--		return HitSizeX >= Offset.X and HitSizeY >= Offset.Y and HitSizeZ >= Offset.Z
--	elseif ShapeType == ShapeTypes.Cylinder then
--		-- In a Roblox cylinder, the non-circular coordinate is the X
--		-- coordinate. Take that into account when finding the hypotenuse
--		-- Use the object space Y-position to compare hypotenuse bounding status
--		--return LocalX <= SizeX and BaseInteractive.Hypotenuse(LocalY, LocalZ) <= SizeZ + (Offset.Z)
--		return HitSizeX >= Offset.Z and BaseInteractive.Hypotenuse(LocalY, LocalZ) <= ObjectSize.Z + (Offset.Z)
--	elseif ShapeType == ShapeTypes.Ball then
--		warn("Use BaseInteractive.GetDistance() for spheres")
--	end

--	return false
--end

--[[
Returns if the point is inside a certain part

Params:
Point <Vector3> - The point to use when determining if it's inside
Part <table> - Any table that has the CFrame and Size properties
Offset <Vector3?> - Offsets the detection size (bigger = less filtered)
]]--
function BaseInteractive.IsPointInside(Point: Vector3, Part: {}, Offset: Vector3?)
	assert(typeof(Point) == "Vector3", "Argument 1 must be a Vector3")
	assert(BaseInteractive.Is3dObject(Part), "Argument 2 must be a table with CFrame and Size properties")

	local ShapeType = Part.Shape
	if ShapeType then
		if ShapeType == Enum.PartType.Ball then
			return BaseInteractive.GetDistance(Point, Part.CFrame.Position) <= Part.Size.Y
		else
			local PartCFrame = Part.CFrame
			return BaseInteractive.IsInLocalBounds(PartCFrame:PointToObjectSpace(Point), Part.Size, Offset or Vector3.zero, Part.Shape)
		end
	end

	return false
end

--[[
Performs a raycast operation up to 3 times, returning nil if these conditions haven't been met in order:
- center check
- check with negative offset
- check with positive offset

Params:
HitCFrame <CFrame> - The starting CFrame of the raycast
Direction <Vector3> - The directional vector of the raycast
RaycastParams <RaycastParams> - The RaycastParams to use
Offset <Vector3?> - The offset to use

Returns:
<RaycastResult?> - The results of the raycast (or nil if a BasePart couldn't be hit)
]]--
function BaseInteractive.RaycastWithOffset(HitCFrame: CFrame, Direction: Vector3, RaycastInfo: RaycastParams, Offset: Vector3?)
	local Result = workspace:Raycast(HitCFrame.Position, Direction, RaycastInfo)

	if Result then
		return Result
	elseif Offset and Offset ~= Vector3.zero then
		Result = workspace:Raycast(HitCFrame:PointToWorldSpace(-Offset), Direction, RaycastInfo)

		if Result then
			return Result
		else
			Result = workspace:Raycast(HitCFrame:PointToWorldSpace(Offset), Direction, RaycastInfo)

			if Result then
				return Result
			end
		end
	end

	return nil
end

--[[
Hides and destroys the intro text made by DisplayIntroText()
]]--
function BaseInteractive.RemoveIntroText()
	local OriginalText = Reserved.IntroText
	if OriginalText ~= nil then
		OriginalText.SetVisible(false)
		OriginalText.Dispose()
		Reserved.IntroText = nil
	end
end

--[[
Displays text at the top of the screen that's intended to tell the user where they are
]]--
function BaseInteractive.DisplayIntroText(Text: string, Color: Color3, Duration: number?)
	BaseInteractive.RemoveIntroText()
	
	-- Temporarily display some intro text
	local NewText = IntroText.New(Text)
	Reserved.IntroText = NewText
	NewText.Color = Color
	NewText.Gui.Parent = BaseInteractive.GetScreenGui()
	
	NewText.SetVisible(true)
	NewText.VisibleChanged.Sync = true
	
	task.delay(Duration or 4, BaseInteractive.RemoveIntroText)
end

--[[
Constructs a new base interactive object (this is meant to be used by other constructors)
]]--
function BaseInteractive.New(): InteractiveObject
	local Interact = Object.New(BaseInteractive.ClassName)
	
	--[[
	(synced, this fires on the current thread)
	Fires when initialzation is requested
	]]--
	Interact.OnInitialize = nil--BaseInteractive.CreateSyncedSignal()
	
	--[[
	(synced, this fires on the current thread)
	Fires when starting is requested
	]]--
	Interact.OnStart = nil--BaseInteractive.CreateSyncedSignal()
	
	--[[
	(synced, this fires on the current thread)
	Fires when the "shutdown" of the interactive is requested
	]]--
	Interact.OnShutdown = nil--BaseInteractive.CreateSyncedSignal()
	
	Interact.OnDisposal = function()
		local OnShutdown = Interact.OnShutdown
		if OnShutdown then
			OnShutdown()
		end
		
		--Interact.OnShutdown.Fire()
		--Interact.OnShutdown.Dispose()
		
		--Interact.OnInitialize.Dispose()
		--Interact.OnStart.Dispose()
	end
	
	return Interact
end

return BaseInteractive