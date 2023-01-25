-- This module provides an object that gives players the ability to swim
-- in liquids (from BaseParts).

-- Thanks to ForbiddenJ for swimming movement logic.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local Adapters = RepModules:WaitForChild("Adapters")
local UtilRepModules = RepModules:WaitForChild("Utils")

local LiquidModules = script.Parent

local CharAdapter = require(Adapters:WaitForChild("CharacterAdapter"))
local Object = require(UtilRepModules:WaitForChild("Object"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local LiquidAdapter = require(LiquidModules:WaitForChild("LiquidAdapter"))
local SwimmerInput = require(LiquidModules:WaitForChild("SwimmerInput"))

local Camera = workspace.CurrentCamera

local Swimmer = {}
Swimmer.HumanoidCollectionId = "SwimmerHumanoids" -- For internal use

local function PlaySound(URL)
	local Sound = Instance.new("Sound")
	Sound.SoundId = Util.FormatAssetId(URL)
	Sound.Volume = 1
	Sound.Parent = script

	if Sound.IsLoaded == false then
		Sound.Loaded:Wait()
	end

	Sound:Play()
	Debris:AddItem(Sound, Sound.TimeLength)
	Sound = nil
end

-- Toggles the SoundGroup used in the 

-- Gets the weight of the specified part.
local function GetPartWeight(BasePart)
	if Util.IsBasePart(BasePart) then
		-- Get a BasePart's weight, the weight of its connected parts
		local AccumulatedWeight = 0
		for i, v in pairs(BasePart:GetConnectedParts()) do
			if v:IsA("BasePart") then
				AccumulatedWeight = AccumulatedWeight + v:GetMass()
			end
		end
		-- Calculate the weight by going through the table and return the weight relative to the gravity
		return AccumulatedWeight * workspace.Gravity
	end
end

function Swimmer.New(Player)
	assert(typeof(Player) == "Instance" and Player:IsA("Player"), "Argument 1 must be a player instance.")

	local Obj = Object.New("Swimmer")
	local ObjCharAdapter = CharAdapter.New(Player)
	local ObjInput = SwimmerInput.New()

	local Liquids = {} -- Liquid adapters
	local ActiveLiquids = {} -- Liquid adapters the rig is in.
	local Connections = {} -- Liquid body part connections
	
	local FloatTweens = {}

	local CharObjects = ObjCharAdapter.Parts
	local Forces = {}
	local ForceEnabled = false -- Swimmin force debounce.
	local FloatingForces = {} -- Forces used to make the character float.
	local RootPartWeight = 0
	local OldRig = nil -- For adapter refresh
	local Rig = nil
	local IsInLiquid = false -- Internal identifier for sound playback
	local WaitingForFloat = false
	local VerticalDirection = nil
	local CanPlaySounds = false

	-- Physics tweaking stuff
	Obj.PhysicsConfig = {
		MaxSwimTorqueY = 2000, -- The maximum amount of force (negative or positive) that can be applied in the Y-axis to turn the player's character while they are swimming
		SwimRotationalDamping = 50, -- The higher this number gets, the more intertia that is ignored when turning
		SwimRotationalPower = 500 -- The amount of power to use to turn the character while they are swimming
	}

	-- Air change rates by liquid state.
	-- Numbers are in change per second.
	Obj.AirChanges = {
		-- Decreases should be negative numbers

		["water"] = -8,
		["acid"] = -30,
		["lava"] = -10000
	}

	-- How long (in seconds) the player has to wait before
	-- breathing in when out of a liquid.
	Obj.BreatheInDelay = 2

	-- Air gained per second when not in a liquid.
	Obj.AirRecoveryRate = 12

	-- Current air cap.
	Obj.MaxAir = 100

	-- Sounds by liquid state
	Obj.LiquidSounds = {
		-- Format: ["state"] = "id"
		["default"] = "rbxasset://sounds/impact_water.mp3",
		["lava"] = "rbxasset://sounds/Rocket shot.wav"--"rbxassetid://5094928129"--"rbxasset://sounds/Launching rocket.wav"
	}

	Obj.SplashOutSound = "rbxasset://sounds/impact_water.mp3"
	Obj.SoundsEnabled = true

	-- The current liquid body the player is in.
	Obj.CurrentBody = nil

	-- The velocity of the character when it is floating.
	Obj.FloatVelocity = Vector3.new(0, 1, 0)

	Obj.FloatTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	Obj.FloatStopVelocity = Vector3.new(0, 0, 0)

	-- The liquid body identifier string.
	Obj.BodyId = "_Liquid"

	-- If the player can lose air.
	Obj.CanLoseAir = true

	Obj.CanLoseAirWhileDead = false
	Obj.CanSwimWhileDead = false
	Obj.SoundsEnabledWhileDead = false
	Obj.MaxForceMultiplier = 3.1
	
	-- Time after character loading to wait before letting a sound be played.
	Obj.SoundSpawnCooldown = 0.1

	-- Multiplier for the humanoid's jump power when
	-- they launch out of a liquid.
	Obj.JumpBoostFactor = 1

	local function RefreshCharValues()
		local RootPart = CharObjects.RootPart
		if RootPart ~= nil then
			RootPartWeight = GetPartWeight(RootPart) * (Obj.MaxForceMultiplier or 1)
		end
		
		CanPlaySounds = false

		local Char = CharObjects.Character
		if Char ~= nil then
			Rig = Char:WaitForChild(Obj.InteractingRig)

			if Rig ~= nil then
				IsInLiquid = false
				
				-- Set liquid adapter rigs
				for i, v in pairs(Liquids) do
					if OldRig ~= nil then
						v.SetInteractingPart(OldRig, false)
					end

					v.SetInteractingPart(Rig, true)
				end
			end

			OldRig = Rig
			
			-- Go through sound cooldown
			coroutine.wrap(function()
				local SoundCooldown = Obj.SoundSpawnCooldown or 0

				if SoundCooldown > 0 then
					CanPlaySounds = false
					local Elapsed = 0
					
					while Elapsed < SoundCooldown do
						Elapsed += RunService.Heartbeat:Wait()
					end
					
					CanPlaySounds = true
				else
					CanPlaySounds = true
				end
			end)()
		end
	end

	local function HandleAirSupply(Air)
		if Air <= 0 then
			-- Kill the player when they run out of air
			local Humanoid = CharObjects.Humanoid
			if Humanoid ~= nil then
				Humanoid.Health = 0
			end
		end

		-- Fire the callback.
		Object.FireCallback(Obj.AirChanged, Air)
	end

	-- Internally toggles air recovery.
	local function ToggleAirRecovery(Enabled)
		if Enabled == true then
			-- Disconnect the old recovery runner.
			ToggleAirRecovery(false)

			-- Inhale.
			Obj.InhaleRun = RunService.Heartbeat:Connect(function(Delta)
				-- Check if the player is out of a liquid and has less than or equal to max air
				if Obj.CurrentBody == nil and Obj.Air <= Obj.MaxAir then
					-- Recover
					Obj.Air = math.min(Obj.Air + (Obj.AirRecoveryRate * Delta), Obj.MaxAir)
				else
					ToggleAirRecovery(false)
				end
			end)
		else
			local InhaleRun = Obj.InhaleRun

			if InhaleRun ~= nil then
				InhaleRun:Disconnect()
			end

			Obj.InhaleRun = nil
			InhaleRun = nil
		end
	end

	local function CanSwim()
		local Humanoid = CharObjects.Humanoid
		local IsAlive = true
		if Humanoid ~= nil then
			IsAlive = Humanoid.Health > 0
		end

		return Obj.CanSwimWhileDead == true or (Obj.CanSwimWhileDead == false and IsAlive)
	end

	-- Toggles the swimming force.
	local function ToggleForce(Enabled)
		if Enabled == true and CanSwim() == true then
			local PhysicsConfig = Obj.PhysicsConfig
			local RootPart = CharObjects.RootPart
			local Humanoid = CharObjects.Humanoid

			if PhysicsConfig ~= nil and RootPart ~= nil and Humanoid ~= nil then
				-- Moves the character.
				local Force = Util.CreateInstance("BodyVelocity", {
					Velocity = Vector3.new(0,0,0),
					P = RootPartWeight, -- Power
					MaxForce = Vector3.new(RootPartWeight, RootPartWeight, RootPartWeight) * 3.1,
					Parent = RootPart
				})

				-- Rotates the character.
				local Gyro = Util.CreateInstance("BodyGyro", {
					MaxTorque = Vector3.new(math.huge, PhysicsConfig.MaxSwimTorqueY, math.huge),
					D = PhysicsConfig.SwimRotationalDamping,
					P = PhysicsConfig.SwimRotationalPower,
					CFrame = RootPart.CFrame, -- Important because this is where the torque will be applied
					Parent = RootPart
				})

				Forces.Force = Force
				Forces.Gyro = Gyro

				-- Set Humanoid PlatformStand, so default
				-- humanoid control doesn't apply
				Humanoid.PlatformStand = true
			end

			PhysicsConfig, RootPart, Humanoid = nil, nil, nil
		else
			for i, v in pairs(Forces) do
				if typeof(v) == "Instance" then
					v:Destroy()
				end
			end

			-- Allow for default control again
			local Humanoid = CharObjects.Humanoid
			if Humanoid ~= nil then
				Humanoid.PlatformStand = false

				-- Launch the humanoid upwards if it was swimming up.
				if VerticalDirection == "up" then
					local RootPart = CharObjects.RootPart
					if RootPart ~= nil then
						local RootVelocity = RootPart.Velocity
						local UpVelocity = Humanoid.JumpPower * (Obj.JumpBoostFactor or 1)

						-- Jump the humanoid for consistency.
						Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

						-- Apply the velocity
						RootPart:ApplyImpulse(Vector3.new(RootVelocity.X, UpVelocity, RootVelocity.Z))

						RootVelocity, UpVelocity  = nil, nil
					end
					RootPart = nil
				end
			end
			Humanoid = nil
		end
	end

	local function ToggleSwimRunner(Enabled)
		if Enabled == true then
			-- Disconnect the old swim runner if it exists.
			ToggleSwimRunner(false)

			-- Runs swimmer humanoid movement
			Obj.SwimRunner = RunService.Heartbeat:Connect(function(Delta)
				local Body = Obj.CurrentBody
				if Body ~= nil then

					if CanSwim() == true then
						local Humanoid = CharObjects.Humanoid
						local IsAlive = true
						if Humanoid ~= nil then
							IsAlive = Humanoid.Health > 0
						end

						if Obj.CanLoseAir == true then
							-- Do death check before draining air.
							if Humanoid == nil or Obj.CanLoseAirWhileDead == true or (Obj.CanLoseAirWhileDead == false and IsAlive) then
								-- Drain air.
								Obj.Air = math.max(0, Obj.Air + ((Obj.AirChanges[Body.State] or 0) * Delta))
							end
						end

						-- Move the humanoid
						local Force = Forces.Force
						local Gyro = Forces.Gyro

						if Forces ~= nil and Gyro ~= nil then
							if Humanoid ~= nil then
								local MoveDir = Humanoid.MoveDirection -- The movement direction of the humanoid
								local HumanoidSpeed = Humanoid.WalkSpeed -- The movement speed of the humanoid

								local YVelocity = nil -- The Vector3 that hoists the swim direction of the player on the Y-axis
								if VerticalDirection == "up" then
									YVelocity = MoveDir + Vector3.new(0, 1, 0) -- Swim up
								elseif VerticalDirection == "down" then
									YVelocity = MoveDir + Vector3.new(0, -1, 0) -- Swim down
								else
									YVelocity = MoveDir + Vector3.new(0, 0, 0)
								end
								Force.Velocity = YVelocity * HumanoidSpeed

								if MoveDir.Magnitude > 0.1 then -- Detect if the character is applying force in any direction other than just up or down by detecting if there is magnitude in the move direction (the up and down direction won't affect this number)
									Gyro.CFrame = CFrame.new(Vector3.new(0,0,0), MoveDir) -- Apply a directional force away from the center
								end
								MoveDir, HumanoidSpeed, YVelocity = nil, nil, nil
							end

							Humanoid = nil
						end
					else
						ToggleSwimRunner(false)
						ToggleForce(false)
					end
				end
			end)
		else
			local SwimRunner = Obj.SwimRunner

			if SwimRunner ~= nil then
				SwimRunner:Disconnect()
			end

			Obj.SwimRunner = nil
			SwimRunner = nil
		end
	end

	-- This moves the humanoid while they're swimming
	local function MoveSwimmer(Direction)
		VerticalDirection = Direction
	end

	-- Sets the current body the rig is swimming in.
	-- This can only have one value for this object.
	local function SetCurrentBody(Body)
		Obj.CurrentBody = Body

		if Body ~= nil then
			if ForceEnabled == false then
				ForceEnabled = true
				if CanSwim() then
					ToggleForce(true)
					ToggleSwimRunner(true)
					ObjInput.IsSinkingInput = true
				else
					Obj.ToggleFloating(true)
				end
			end
		else
			if ForceEnabled == true then
				ForceEnabled = false

				ToggleSwimRunner(false)
				ToggleForce(false)
				Obj.ToggleFloating(false)
				ObjInput.IsSinkingInput = false

				-- Yielding in roblox sucks sometimes,
				-- so coroutines are needed.
				coroutine.wrap(function()
					-- Wait for air recovery
					local Elapsed = 0
					local RecoverDelay = Obj.BreatheInDelay
					if RecoverDelay ~= nil then
						while Obj.CurrentBody == nil and Elapsed < RecoverDelay do
							Elapsed += RunService.Heartbeat:Wait()
						end
					end
					Elapsed, RecoverDelay = nil, nil

					-- Breathe in
					if Obj.CurrentBody == nil then
						ToggleAirRecovery(true)
					end
				end)()
			end
		end
	end

	-- Makes the player swim in the liquid body,
	-- if IsSwimming is true, false for getting
	-- out of the body.
	-- The body parameter should be a BasePart.
	local function SwimInBody(Body, IsSwimming)
		local Humanoid = CharObjects.Humanoid

		if Humanoid ~= nil then
			local NextBody = nil
			if Body ~= nil then
				if IsSwimming == true then
					Obj.CurrentBody = Body

					-- Add to the table
					table.insert(ActiveLiquids, Body)
					--print("Swimming in:", Body.State)

					NextBody = Body
					Body = nil
				else
					-- Remove from the table
					local TablePos = table.find(ActiveLiquids, Body)
					if TablePos ~= nil then
						table.remove(ActiveLiquids, TablePos)
					end
					TablePos = nil

					-- Swim in the last body in the table.
					-- If there are none, it means the
					-- player isn't in any liquids.
					NextBody = ActiveLiquids[#ActiveLiquids]
				end
			end

			-- Swim in the next body.
			Obj.CurrentBody = NextBody
			SetCurrentBody(NextBody)

			-- Fire the callback
			Object.FireCallback(Obj.RigEntryChanged, NextBody, IsSwimming)

			-- Play a sound to indicate liquid entry change.
			if CanPlaySounds == true then
				if Obj.SoundsEnabled == true then
					-- Check if the sounds can be played when dead.
					local SoundsWhenDead = Obj.SoundsEnabledWhileDead
					if SoundsWhenDead == true or (SoundsWhenDead == false and Humanoid ~= nil and Humanoid.Health > 0) then
						-- Play the corresponding sound.
						if NextBody == nil then
							if IsInLiquid == true then
								IsInLiquid = false
								coroutine.wrap(PlaySound)(Obj.SplashOutSound)
							end
						elseif IsInLiquid == false then
							IsInLiquid = true
							coroutine.wrap(PlaySound)(Obj.LiquidSounds[NextBody.State] or Obj.LiquidSounds["default"])
						end
					end
				end
			end
		end
	end

	local function IsLiquidBody(Part)
		return Util.IsBasePart(Part) and string.match(Part.Name, Obj.BodyId)
	end

	-- Toggles if the specified liquid can be interacted with
	-- by this object.
	local function ToggleLiquidRegistry(Body, IsRegistered)
		if Util.IsBasePart(Body) then

			if IsRegistered == true then
				-- Register if not already registered
				if Liquids[Body] == nil then
					local Adapter = LiquidAdapter.New(Body)		
					Liquids[Body] = Adapter
					Adapter.SetInteractingPart(Rig, true)
					--print("a")
					Adapter.EntryStatusChanged = function(Part, Entered)
						--print("b")
						if Util.IsInstance(Part) then
							--print("c")
							SwimInBody(Adapter, Entered)
						end
					end
				end
			else
				-- De-register
				local Adapter = Liquids[Body]
				if Adapter ~= nil then
					Adapter.Dispose()
				end

				Liquids[Body] = nil
				Adapter = nil
			end
		end
	end

	local function HandleLiquidBasePart(Descendant, IsAdded)
		-- Check for the identifier
		if Util.IsBasePart(Descendant) and string.match(Descendant.Name, Obj.BodyId) then
			-- Toggle registration
			ToggleLiquidRegistry(Descendant, IsAdded)
		end
	end

	-- Makes the character float. For realism, this should
	-- be called if the player is in water.
	-- Paramters:
	-- IsFloating (boolean) - If the character will float.
	function Obj.ToggleFloating(IsFloating)
		local Char = CharObjects.Character

		if IsFloating == true then
			-- Toggle off any existing floating forces
			Obj.ToggleFloating(false)

			if Char ~= nil then
				-- Start floating
				local FloatVelocity = Obj.FloatVelocity
				if FloatVelocity ~= nil then
					local Parts = Char:GetChildren()
					local Info = Obj.FloatTweenInfo or TweenInfo.new()
					local Properties = {AssemblyLinearVelocity = FloatVelocity}

					-- Tween to the float force
					for i, v in pairs(Parts) do
						if Util.IsBasePart(v) then
							table.insert(FloatTweens, Util.Tween(v, Info, Properties))
						end
					end
					Properties = nil

					-- Wait for tween finish
					WaitingForFloat = true
					local Elapsed = 0
					local Time = Info.Time or 0
					while WaitingForFloat == true and Elapsed < Time do
						Elapsed += RunService.Heartbeat:Wait()
					end
					Info = nil

					-- If floating hasn't been toggled off yet, maintain the force
					if WaitingForFloat == true then
						for i, v in pairs(Parts) do
							if Util.IsBasePart(v) then
								if WaitingForFloat == true then
									FloatingForces[v] = Util.CreateInstance("BodyVelocity", {
										Velocity = FloatVelocity,
										Name = "FloatVelocity",
										Parent = v
									})
								else
									break
								end
							end
						end
					end
					
					for i, v in pairs(FloatTweens) do
						v:Pause()
						v:Destroy()
					end
					FloatTweens = {}

					WaitingForFloat = false
					FloatVelocity = nil
				end
			end
		else
			-- Stop floating
			WaitingForFloat = false
			
			-- Destroy float forces
			for i, v in pairs(FloatingForces) do
				if Util.IsInstance(v) == true then
					v:Destroy()
				end
			end
		end
	end

	-- Regenerates the player's air and stops when
	-- the air reaches the maximum or if a liquid
	-- is entered again.
	function Obj.Inhale()
		ToggleAirRecovery(true)
	end

	-- Sets if the object will look for bodies in the workspace.
	function Obj.SetWorkspaceUse(IsUsing)
		if IsUsing == true then
			Obj.WorkspaceDescendantAdded = workspace.DescendantAdded:Connect(function(desc)
				HandleLiquidBasePart(desc, true)
			end)

			Obj.WorkspaceDescendantRemoved = workspace.DescendantRemoving:Connect(function(desc)
				HandleLiquidBasePart(desc, false)
			end)

			for i, v in pairs(workspace:GetDescendants()) do
				HandleLiquidBasePart(v, true)
			end
		else
			local DescAdd = Obj.WorkspaceDescendantAdded
			local DescRemove = Obj.WorkspaceDescendantRemoved

			if DescAdd ~= nil then
				DescAdd:Disconnect()
			end

			if DescRemove ~= nil then
				DescRemove:Disconnect()
			end

			DescAdd, DescRemove = nil, nil
		end
	end

	-- How much air the player has.
	Obj.SetProperty("Air", 100, HandleAirSupply)

	-- Fires when a rig enters or exits a liquid.
	-- Parameters:
	-- IsEntering - True if the rig entered the liquid, false if otherwise.
	-- Liquid - The adapter entered.
	Obj.RigEntryChanged = nil

	-- Fires when the amount of air changes.
	-- Parameters:
	-- Air: number - Amount of oxygen left.
	Obj.AirChanged = nil

	-- How much air the player has.
	Obj.SetProperty("Air", Obj.MaxAir, HandleAirSupply)

	-- The name of the rig that interacts with the liquids.
	Obj.SetProperty("InteractingRig", "Head", RefreshCharValues)

	-- Connect internal events.
	Obj.OnDisposal = function()
		-- Destroy/forget stuff.
		Obj.SetWorkspaceUse(false)
		Obj.ToggleFloating(false)
		ToggleForce(false)
		Forces = nil

		-- Dispose all adapters
		for i, v in pairs(Liquids) do
			ToggleLiquidRegistry(i, false)
		end

		-- Stop listening to input.
		ObjInput.Dispose()

		-- De-register all liquid bodies.
		for i, v in pairs(Liquids) do
			ToggleLiquidRegistry(i, false)
		end
	end

	ObjCharAdapter.Loaded = function(Parts)
		Obj.Air = Obj.MaxAir
		CharObjects = Parts
		RefreshCharValues()
	end

	-- Swimming input handler
	ObjInput.DirectionChanged = function(Direction)
		MoveSwimmer(Direction)
		--print("Direction changed:", Direction)
	end

	-- Float if the player drowned.
	ObjCharAdapter.OnDeath = function()
		ObjInput.IsSinkingInput = false
		MoveSwimmer(nil)
		if Obj.CurrentBody ~= nil then
			Obj.ToggleFloating(true)
		end
	end

	RefreshCharValues()
	ObjInput.ToggleSwimmingInput(true)

	return Obj
end

return Swimmer