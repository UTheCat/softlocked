-- A utility module for grabbing important character objects.
-- By udev2192

local HUMANOID_NAME = "Humanoid"
local ROOT_PART_NAME = "HumanoidRootPart"
local HITBOX_PART_ENABLED = true
local HITBOX_NAME = "Hitbox"

-- The name of the uppermost rig in the character.
local TOP_RIG_NAME = "Head"

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))

local CharacterAdapter = {}
CharacterAdapter.CharacterSize = Vector3.new(4, 5, 1)

-- Welds part1 to part2
local function WeldParts(p1, p2)
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = p1
	Weld.Part1 = p2
	Weld.Parent = p1

	return Weld
end

-- Returns the current dimensions of the provided character model.
-- Dimensions are based off of the character's uppermost part
-- (as of date, this is considered the head).
-- The table returned contains indexes: Size, Position, Orientation.
function CharacterAdapter.GetDimensions(CharModel)
	local UpperPart = CharModel:WaitForChild(TOP_RIG_NAME)

	assert(typeof(UpperPart) == "Instance" and UpperPart:IsA("BasePart"),
		"The top rig named '" .. TOP_RIG_NAME .. "' couldn't be found."
	)

	-- Calculate from the absolute top, then work our way down half the Y size.
	local CharOri, CharSize = CharModel:GetBoundingBox()
	local UpperPos = UpperPart.Position
	local TopPosY = UpperPos.Y + UpperPart.Size.Y/2

	local CharCenter = Vector3.new(UpperPos.X, TopPosY - (CharSize.Y / 2), UpperPos.Z)

	-- Return the table
	return {
		Size = CharSize,
		Position = CharCenter,
		Orientation = CharOri
	}
end

function CharacterAdapter.New(Player)
	assert(typeof(Player) == "Instance" and Player:IsA("Player"), "Argument 1 must be a player.")

	local Obj = Object.New("CharacterAdapter")
	local CurrentForces = {} -- Current body force.

	-- Where the character parts will be.
	-- They're stored here so calling Dispose()
	-- doesn't destroy the character.
	Obj.Parts = {}
	Obj.HumanoidHealthEvent = nil

	local function DisconnectHumanoidDeath()
		local HealthEvent = Obj.HumanoidHealthEvent
		if HealthEvent ~= nil then
			HealthEvent:Disconnect()
		end

		Obj.HumanoidHealthEvent = nil
		HealthEvent = nil
	end

	local function HandleCharAdded(Char)
		if typeof(Char) == "Instance" then
			Object.FireCallback(Obj.OnRespawn, Char)
			Obj.RespawnEvent.Fire(Char)
			DisconnectHumanoidDeath()

			local Parts = {}
			Parts.Character = Char

			-- Load character parts
			local Humanoid = Char:WaitForChild(HUMANOID_NAME, 5)
			local RootPart = Char:WaitForChild(ROOT_PART_NAME, 5)

			if Humanoid ~= nil then
				-- HealthChanged is used for stability reasons
				Obj.HumanoidHealthEvent = Humanoid.HealthChanged:Connect(function(health)
					if health <= 0 then
						Object.FireCallback(Obj.OnDeath)
						Obj.DeathEvent.Fire()
					end
				end)
			end

			Parts.Humanoid = Humanoid
			Parts.RootPart = RootPart

			-- Create hitbox
			if HITBOX_PART_ENABLED == true then
				local Hitbox = Char:FindFirstChild(HITBOX_NAME)

				if Hitbox == nil then
					-- Get the dimensions
					local CharDimensions = CharacterAdapter.GetDimensions(Char)
					
					-- Make the hitbox part
					Hitbox = Instance.new("Part")
					Hitbox.Anchored = true
					Hitbox.CanCollide = false
					Hitbox.Massless = true -- So its weight has no effect
					Hitbox.Transparency = 1
					Hitbox.Size = CharacterAdapter.CharacterSize--CharDimensions.Size
					Hitbox.Position = CharDimensions.Position
					Hitbox.Orientation = CharDimensions.Orientation.LookVector
					Hitbox.Name = HITBOX_NAME

					WeldParts(Hitbox, RootPart)
					Hitbox.Anchored = false
					Hitbox.Parent = Char
				end

				Parts.Hitbox = Hitbox
				Hitbox = nil
			end

			-- Finish
			Obj.Parts = Parts
			Object.FireCallback(Obj.Loaded, Parts)
			Obj.LoadedEvent.Fire(Parts)

			Parts, Humanoid, RootPart = nil, nil, nil
		end
	end

	-- Returns the player associated.
	function Obj.GetPlayer()
		return Player
	end

	-- Returns if the character has a humanoid and that it is alive.
	function Obj.IsAlive()
		local Parts = Obj.Parts
		if Parts ~= nil then
			local Humanoid = Parts.Humanoid 
			if Humanoid ~= nil then
				return Humanoid.Health > 0
			end
		end

		return false
	end

	-- Cancels all currently applied BodyForces.
	function Obj.CancelForces()
		for i, v in pairs(CurrentForces) do
			if typeof(v) == "Instance" then
				v:Destroy()
			end

			CurrentForces[i] = nil
		end
	end

	-- Sets the velocity of the character's RootPart.
	-- Params:
	-- Velocity - The force to apply to the launch.
	-- Duration - How long the force lasts.
	function Obj.ApplyForce(Velocity, Duration)
		assert(typeof(Velocity) == "Vector3", "Argument 1 must be a Vector3.")

		if Obj.Parts ~= nil then
			local RootPart = Obj.Parts.RootPart

			if typeof(RootPart) == "Instance" and RootPart:IsA("BasePart") then
				-- Velocity is now set via AssemblyLinearVelocity
				-- because it is more consistent and respects
				-- gravity
				
				--RootPart:ApplyImpulse(Velocity)
				RootPart.AssemblyLinearVelocity = Velocity

				-- Maintain the force.
				if typeof(Duration) == "number" and Duration > 0 then
					coroutine.wrap(function()
						local Force = Instance.new("BodyForce")
						Force.Force = Velocity
						Force.Parent = RootPart

						CurrentForces[Force] = Force

						-- Wait until time's up or the force was cancelled.
						local Elapsed = 0
						while Force.Parent ~= nil and Elapsed < Duration do
							Elapsed += RunService.Heartbeat:Wait()
						end

						Force:Destroy()
						Force = nil
					end)()
				end
			end
		end
	end

	-- Fires when the character respawns.
	-- Parameters:
	-- Character - The player's character.
	Obj.OnRespawn = nil

	-- Fires when the "important" character objects are loaded.
	-- Parameters:
	-- Parts - The character parts loaded.
	Obj.Loaded = nil

	-- Fires when the character dies.
	Obj.OnDeath = nil

	-- Signal variants of the callbacks.
	Obj.RespawnEvent = Signal.New()
	Obj.LoadedEvent = Signal.New()
	Obj.DeathEvent = Signal.New()

	-- Connect internal events
	HandleCharAdded(Player.Character)
	Player.CharacterAdded:Connect(HandleCharAdded)

	Obj.OnDisposal = function()
		Obj.RespawnEvent.DisconnectAll()
		Obj.LoadedEvent.DisconnectAll()
		Obj.DeathEvent.DisconnectAll()

		Obj.CancelForces()
		CurrentForces = nil
	end

	return Obj
end

return CharacterAdapter