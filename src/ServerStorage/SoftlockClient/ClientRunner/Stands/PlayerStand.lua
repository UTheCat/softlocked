-- Gives the player a cylindrical stand over a cuttable part/softlock zone.
-- By udev2192

local RunService = game:GetService("RunService")

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local UtilModules = RepModules:WaitForChild("Utils")

local Object = require(UtilModules:WaitForChild("Object"))
local Runtime = require(UtilModules:WaitForChild("Runtime"))
local Util = require(UtilModules:WaitForChild("Utility"))

RepModules, UtilModules = nil, nil

-- Keyword for a softlock zone.
local GBJ_KEYWORD = "^_SoftlockZone"

-- Default stand part diameter.
local DEFAULT_STAND_DIAMETER = 5

-- Default stand part height.
local DEFAULT_STAND_HEIGHT = 1

-- Stand BasePart defaults.
local STAND_PART_PROPERTIES = {
	Anchored = true,
	CanCollide = true,
	Size = Vector3.new(DEFAULT_STAND_HEIGHT, DEFAULT_STAND_DIAMETER, DEFAULT_STAND_DIAMETER),
	Shape = Enum.PartType.Cylinder,
	Orientation = Vector3.new(0, 0, 90),
	Color = Color3.fromRGB(85, 85, 255),
	Material = Enum.Material.Neon,
	Transparency = 0.7,
	Reflectance = 0.75
}

-- Stand BasePart folder name.
local STAND_FOLDER_NAME = "PlayerStandBaseParts"

-- Stand BasePart folder.
local StandPartFolder = workspace:FindFirstChild(STAND_FOLDER_NAME) or Instance.new("Folder")
StandPartFolder.Name = STAND_FOLDER_NAME
StandPartFolder.Parent = workspace

local PlayerStand = {}

local function IsPart(Obj)
	return typeof(Obj) == "Instance" and Obj:IsA("BasePart")
end

-- Returns if the part is considered a "GBJ zone".
local function IsGBJPart(Part)
	return IsPart(Part) and string.match(Part.Name, GBJ_KEYWORD)
end

-- Creates and returns the default stand BasePart.
local function CreateStandPart()
	local Part = Instance.new("Part")
	
	for i, v in pairs(STAND_PART_PROPERTIES) do
		Part[i] = v
	end
	
	return Part
end

function PlayerStand.GetDefaultDiameter()
	return DEFAULT_STAND_DIAMETER
end

function PlayerStand.New(CharAdapter)
	assert(typeof(CharAdapter) == "table", "Argument 1 must be a CharacterAdapter.")
	
	local Stand = Object.New("PlayerStand")
	local Hitbox = nil
	local TouchConnection = nil
	local MoveRunner = nil
	local IsTouchingGBJ = false
	
	-- Currently stored stand part diameter.
	local CurrentDiameter = DEFAULT_STAND_DIAMETER
	
	-- The current GBJ part that the stand is connected to.
	local CurrentGBJPart = nil
	
	-- The BasePart that the stand uses.
	Stand.Part = nil
	
	-- The tweening info used by AnimateDiameter()
	Stand.DiameterTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	
	-- Destroys the stand part.
	function Stand.DestroyStandPart()
		local StandPart = Stand.Part
		if StandPart ~= nil then
			StandPart:Destroy()
		end
		StandPart = nil
		Stand.Part = nil
	end
	
	-- Respawns the stand part.
	function Stand.RespawnPart()
		Stand.DestroyStandPart()
		
		local StandPartInit = CreateStandPart()
		Stand.Part = StandPartInit
		StandPartInit.Parent = StandPartFolder
		StandPartInit = nil
	end
	
	-- Sets diameter of the stand.
	function Stand.SetDiameter(Diameter)
		CurrentDiameter = Diameter
		
		local StandPart = Stand.Part

		if IsPart(StandPart) == true then
			StandPart.Size = Vector3.new(DEFAULT_STAND_HEIGHT, Diameter, Diameter)
		end
	end
	
	-- Gets the current diameter of the stand.
	function Stand.GetDiameter()
		return CurrentDiameter
	end
	
	-- Animates to the destination diameter of the stand part.
	function Stand.AnimateDiameter(Diameter)
		CurrentDiameter = Diameter
		
		local StandPart = Stand.Part
		
		if IsPart(StandPart) == true then
			local AnimInfo = Stand.DiameterTweenInfo or TweenInfo.new()
			
			-- Animate
			return Util.Tween(StandPart, AnimInfo, {Size = Vector3.new(DEFAULT_STAND_HEIGHT, Diameter, Diameter)})
		end
	end
	
	-- Moves the part to be under the hitbox.
	function Stand.MoveStand()
		local StandPart = Stand.Part
		
		if StandPart ~= nil and Hitbox ~= nil and CurrentGBJPart ~= nil then
			local GBJSizeHalved = CurrentGBJPart.Size / 2
			local GBJPos = CurrentGBJPart.Position
			
			local GBJBegin = GBJPos - GBJSizeHalved
			local GBJEnd = GBJPos + GBJSizeHalved
			
			local HitboxPos = Hitbox.Position
			
			local function ClampDim(Dimension)
				return math.clamp(HitboxPos[Dimension], GBJBegin[Dimension], GBJEnd[Dimension])
			end
			
			StandPart.Position = Vector3.new(ClampDim("X"), GBJPos.Y + GBJSizeHalved.Y, ClampDim("Z"))
		end
	end
	
	-- Toggles the movement runner for the player stand.
	function Stand.ToggleMoveRunner(IsRunning)
		if IsRunning == true then
			Stand.ToggleMoveRunner(false)
			
			local StandPart = Stand.Part
			if IsPart(StandPart) then
				-- Reconnect movement
				MoveRunner = RunService.Heartbeat:Connect(Stand.MoveStand)
			else
				warn("Cannot turn on move runner because no stand part has been set.")
			end
		else
			if MoveRunner ~= nil then
				MoveRunner:Disconnect()
				MoveRunner = nil
			end
		end
	end
	
	-- Toggles the .Touched connection for finding GBJ parts.
	function Stand.ToggleTouchConnection(IsConnected)
		if IsConnected == true and Hitbox ~= nil then
			Stand.ToggleTouchConnection(false)
			
			-- Reconnect GBJ zone touch.
			TouchConnection = Hitbox.Touched:Connect(function(OtherPart)
				if IsGBJPart(OtherPart) then
					-- Move the stand to the GBJ part.
					CurrentGBJPart = OtherPart
				end
			end)
		else
			if TouchConnection ~= nil then
				TouchConnection:Disconnect()
				TouchConnection = nil
			end
		end
	end
	
	-- Character load handler.
	local function OnCharLoad(Parts)
		Hitbox = Parts.Hitbox
	end
	
	OnCharLoad(CharAdapter.Parts)
	
	-- Connect events.
	CharAdapter.LoadedEvent.Connect(OnCharLoad)
	
	Stand.OnDisposal = function()
		Stand.ToggleTouchConnection(false)
		Stand.ToggleMoveRunner(false)
		CharAdapter.LoadedEvent.Disconnect(OnCharLoad)
		Stand.DestroyStandPart()
		
		Hitbox = nil
	end
	
	return Stand
end

return PlayerStand