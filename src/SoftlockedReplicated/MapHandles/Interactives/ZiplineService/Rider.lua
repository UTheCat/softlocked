--[[
The class that gives the ability for a player
to ride the zipline.

By udev2192
]]--

local RunService = game:GetService("RunService")

local Interactives = script.Parent.Parent
local Object = require(Interactives:WaitForChild("BaseInteractive")).GetObjectClass()
local Zipline = require(Interactives:WaitForChild("Zipline"))

local ZERO_VECTOR3 = Vector3.new(0, 0, 0)

local Rider = {}


-- Attribute names
local RIDER_DISPLAYED_ATTRIBUTE = "DisplaysRider"
local RIDE_SPEED_ATTRIBUTE = "RideSpeed"

Rider.WORKSPACE_CACHE_NAME = "ZiplineRiderWScache"

local function IsInstance(name, inst)
	return typeof(inst) == "Instance" and inst:IsA(name)
end

local function IsPart(Part)
	return IsInstance("BasePart", Part)
end

local function HasTouchEvent(Part)
	return IsInstance("BasePart", Part) or IsInstance("Humanoid", Part)
end

-- Welds part1 to part2
local function WeldParts(p1, p2)
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = p1
	Weld.Part1 = p2
	Weld.Parent = Rider.WorkspaceCache
	
	return Weld
end

local function GetCFrameOri(Ori)
	assert(typeof(Ori) == "Vector3", "Argument 1 must be a Vector3.")
	return CFrame.fromOrientation(math.rad(Ori.X), math.rad(Ori.Y), math.rad(Ori.Z))
end

--local function GetModelHeight(Model)
--	assert(typeof(Model) == "Instance" and Model:IsA("Model"), "Argument 1 must be a model.")
--	return Model:GetExtentsSize().Y
--end

-- Toggles if the rider cache folder exists in the DataModel.
function Rider.ToggleRiderCache(Enabled)
	local WSCache = Rider.WorkspaceCache
	
	if Enabled == true then
		WSCache = WSCache or workspace:FindFirstChild(Rider.WORKSPACE_CACHE_NAME) or Instance.new("Folder")
		
		Rider.WorkspaceCache = WSCache
		WSCache.Name = Rider.WORKSPACE_CACHE_NAME
		WSCache.Parent = workspace
	else
		if WSCache ~= nil then
			WSCache:Destroy()
		end
		
		Rider.WorkspaceCache = nil
		WSCache = nil
	end
end

Rider.ToggleRiderCache(true)

function Rider.New()
	local Obj = Object.New("ZiplineRider")
	local NumConnections = 0
	local IsTouching = false
	
	Obj.CanZipline = true
	Obj.IsOnZipline = false
	Obj.Speed = 16 -- In studs per second
	Obj.TouchConnections = {}
	Obj.LastVelocity = ZERO_VECTOR3
	
	-- If zipline configuration affects ride speed.
	Obj.ZiplineAffectsSpeed = true
	
	-- The default part that rides the zipline.
	Obj.RidingRig = nil
	
	-- Display properties of the handle part
	Obj.HandleDisplaySettings = {
		Transparency = 0,
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(0, 0, 0),
		Size = Vector3.new(4, 1, 1)
	}
	
	-- BodyGyro mover config
	-- Thanks to ForbiddenJ for helping me
	-- tweak these!
	-- 1 power makes for precise replication
	-- because the physics engine would've
	-- picked up the CFrame change along
	-- with high dampening values to get
	-- rid of bouncing
	Obj.GyroDampening = 2500
	Obj.GyroPower = 1
	
	Obj.PartMassMultiplier = 2000
	
	-- Returns if the rider can keep riding the zipline.
	function Obj.CanAdvanceOnZipline()
		return Obj ~= nil and Obj.CanZipline == true and Obj.IsOnZipline == true
	end
	
	-- Sends the provided part riding down the provided zipline.
	function Obj.UseZipline(Part, Zip)
		assert(IsPart(Part), "Argument 1 must be a BasePart.")
		assert(Zip ~= nil, "Argument 2 must be a Zipline.")
		
		if Obj.CanZipline == true and Obj.IsOnZipline == false then
			
			Obj.IsOnZipline = true
			local Time = 0
			local TotalDist = Zip.TotalDistance
			if TotalDist > 0 then
				-- Begin the zipline welding.
				local Moving = Instance.new("Part")
				
				local HandleDisplay = Obj.HandleDisplaySettings or {}
				for i, v in pairs(HandleDisplay) do
					Moving[i] = v
				end
				
				Moving.CanCollide = false
				Moving.Anchored = true
				
				--local Mass = Part.Mass
				
				-- Use a BodyGyro and BodyPosition for replication.
				-- Force properties don't matter since the
				-- CFrame property will be taken in by the physics engine
				local BodyGyro = Instance.new("BodyGyro")
				local BodyPosition = Instance.new("BodyPosition")
				--BodyGyro.MaxTorque = Vector3.new(Mass, Mass, Mass) * Obj.PartMassMultiplier
				--BodyGyro.D = Obj.GyroDampening
				--BodyGyro.P = Obj.GyroPower
				
				-- Change ride speed to zipline settings when permitted.
				if Obj.ZiplineAffectsSpeed == true then
					Obj.Speed = Zip.GetModelSetting(RIDE_SPEED_ATTRIBUTE)
				end
				
				-- Longer ziplines should have DistDelta
				-- be a shorter number.
				local DistDelta = Obj.Speed / TotalDist

				local function nextFrame()
					local Pos, cf = Zip.LerpTo(Time)
					cf = cf.Direction
					
					local RiderCf = cf - Vector3.new(0, (Zip.DisplayThickness + (Part.Size.Y/2)), 0)
					if Pos ~= nil and Obj ~= nil then
						Moving.CFrame = cf
						Obj.LastVelocity = cf.LookVector * Obj.Speed
						Part.CFrame = RiderCf
						
						-- Replicate
						BodyGyro.CFrame = RiderCf
						BodyPosition.Position = RiderCf.Position
						
						--Moving.AssemblyLinearVelocity = cf.LookVector -- So movement replicates
					end
					return Pos, cf, RiderCf
				end
				
				-- Weld the parts
				local FirstPos, FirstCf, RiderCf = nextFrame()
				
				Part.CFrame = RiderCf --CFrame.new(FirstPos.X, FirstPos.Y, FirstPos.Z) * GetCFrameOri(FirstCf.YVector)
				--local Weld = WeldParts(Part, Moving)
				if Zip.GetModelSetting(RIDER_DISPLAYED_ATTRIBUTE) == true then
					Moving.Parent = Rider.WorkspaceCache
				else
					Moving.Parent = nil
				end
				
				BodyGyro.CFrame = RiderCf
				BodyPosition.Position = RiderCf.Position
				
				BodyGyro.Parent = Part
				BodyPosition.Parent = Part
				
				FirstPos, FirstCf = nil, nil

				Object.FireCallback(Obj.OnGrab, Zip)

				-- Ride the zipline.
				-- A while loop is used instead of RunService.Heartbeat
				-- to lower the impact of framerate.
				while Obj.CanAdvanceOnZipline() and Time <= 1 do
					local TimeDelta = RunService.Heartbeat:Wait()
					Time += DistDelta * TimeDelta
					--print(Time)
					nextFrame()
				end

				nextFrame = nil

				-- Let go of the part.
				BodyGyro:Destroy()
				BodyGyro = nil
				
				BodyPosition:Destroy()
				BodyPosition = nil
				
				--Weld:Destroy()
				--Weld = nil

				Moving:Destroy()
				Moving = nil
			end
			
			if Obj ~= nil then
				Obj.IsOnZipline = false

				Object.FireCallback(Obj.OnRelease, Zip)
			end
		end
	end
	
	-- Releases the rider from the zipline
	function Obj.Release()
		Obj.IsOnZipline = false
	end

	-- Handles a part touch internally.
	function Obj.HandleTouch(ControlPart, OtherPart)
		if Obj.CanZipline == true and Obj.IsOnZipline == false then
			local Zipline = Zipline.GetZipline(OtherPart)
			
			if Zipline ~= nil then
				Obj.UseZipline(Obj.RidingRig or ControlPart, Zipline)
			end
		end
	end

	-- Adds the touch connection to the part specified.
	function Obj.AddTouchConnection(Part)
		assert(IsPart(Part), "Argument 1 must be a BasePart")
		NumConnections += 1
		
		local Connection = Part.Touched:Connect(function(OtherPart)
			if IsTouching == false then
				IsTouching = true
				Obj.HandleTouch(Part, OtherPart)
				IsTouching = false
			end
		end)
		Obj.TouchConnections[Part] = Connection
	end
	
	-- Disconnects all parts from triggering this rider
	function Obj.DisconnectAll()
		for i, v in pairs(Obj.TouchConnections) do
			if typeof(v) == "RBXScriptConnection" then
				v:Disconnect()
				v = nil
			end
		end
	end
	
	-- Fired when a zipline is grabbed.
	Obj.OnGrab = nil
	
	-- Fired when the rider lets go of a zipline.
	Obj.OnRelease = nil
	
	Obj.OnDisposal = function()
		Obj.Release()
		Obj.DisconnectAll()
	end
	
	return Obj
end

return Rider