-- Does the internal handling for the movement mechanics.
-- By udev2192

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local Adapters = RepModules:WaitForChild("Adapters")
local UtilRepModules = RepModules:WaitForChild("Utils")

local CharAdapter = require(Adapters:WaitForChild("CharacterAdapter"))
local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))

local ClientPackage = script.Parent.Parent
--local Sound = ClientPackage:WaitForChild("Sound")

--local SoundPlayer = require(Sound:WaitForChild("SoundPlayer"))

local Player = game:GetService("Players").LocalPlayer

local BaseMover = {}
BaseMover.__index = BaseMover

BaseMover.DefaultSoundId = "rbxassetid://9114890978"--"rbxassetid://624706518"

local ZERO_VECTOR3 = Vector3.new(0, 0, 0)
--local GLOBALS_ENABLED = true

--if GLOBALS_ENABLED == true and RunService:IsClient() then
--	-- For static fields.
--	-- This is so multiple require()s of this module
--	-- will return tables with the same
--	-- memory address.
--	BaseMover.__index = BaseMover

--	-- Global character adapter for convienence.
--	BaseMover.CharAdapter = CharAdapter.New(Player)
--end

-- Slightly buggy, ik :/
local function PlaySound(URL, Volume)
	if URL ~= nil and URL ~= "" then
		coroutine.wrap(function()
			local Sound = Instance.new("Sound")
			Sound.SoundId = URL
			Sound.Looped = false
			Sound.Volume = Volume or 0
			Sound.Parent = script
			Sound:Play()
			Sound.Ended:Wait()
			Sound:Destroy()
			Sound = nil
		end)()
	end
end

-- For utility purposes.
function BaseMover.AssertPart(Part, ArgNumber)
	assert(typeof(Part) == "Instance" and Part:IsA("BasePart"), "Argument " .. ArgNumber .. " must be a BasePart.")
end

function BaseMover.New(CharAdapter)
	assert(typeof(CharAdapter) == "table", "Argument 1 must be a CharacterAdapter.")

	local Obj = Object.New("BaseMover")
	local ObjParts = CharAdapter.Parts
	local IsOnCooldown = false
	local IsPreparingLaunch = false
	
	local InteractingRig = nil
	local TouchConnection = nil -- Interacting rig .Touched connection
	local DestroyConnection = nil

	-- Does the cooldown.
	local function DoCooldown()
		local Time = 0
		
		if Obj.DoesForceCooldown == true then
			Time = Obj.ForceDuration
		else
			Time = Obj.CooldownTime
		end
		
		if typeof(Time) == "number" and Time > 0 then
			IsOnCooldown = true

			local Elapsed = 0
			while Obj.CooldownTime ~= nil and Elapsed < Time do
				Elapsed += RunService.Heartbeat:Wait()
			end

			IsOnCooldown = false
		end
	end

	-- Connects to the specified rig's touch.
	local function UseRig(RigName)
		if RigName ~= nil then
			UseRig(nil)

			-- Reconnect touch
			InteractingRig = ObjParts.Hitbox or ObjParts.Character:WaitForChild(RigName)

			if typeof(InteractingRig) == "Instance" and InteractingRig:IsA("BasePart") then
				TouchConnection = InteractingRig.Touched:Connect(function(OtherPart)
					local PartToTouch = Obj.Part
					if PartToTouch == OtherPart then
						--print("Touch")
						Obj.Launch()
					end

					PartToTouch = nil
				end)
			else
				error("Cannot connect rig because", tostring(InteractingRig), "isn't a BasePart.")
			end
		else
			if TouchConnection ~= nil then
				TouchConnection:Disconnect()
			end
			TouchConnection = nil
		end
	end

	-- Character load handler.
	local function OnCharLoad(Parts)
		ObjParts = Parts

		UseRig(Obj.RigName)
	end

	-- The debounce in seconds before the next trigger
	-- of the mover by the character.
	Obj.CooldownTime = 0

	-- Force of the next launch.
	Obj.NextForce = ZERO_VECTOR3

	-- How long, in seconds, to maintain the force of the next launch.
	Obj.ForceDuration = 0

	-- If the CharAdapter's current forces will be cancelled before
	-- applying this mover's force.
	Obj.UseForceOverride = true

	-- The BasePart, that when touched, triggers the force.
	Obj.Part = nil

	-- The sound ID played when the mover is activated.
	Obj.SoundId = BaseMover.DefaultSoundId

	-- The name of the rig that interacts with the humanoid.
	-- Applies if the hitbox isn't found in CharAdapter.
	Obj.RigName = "Hitbox"
	
	-- If the character is given a jump boost when the force is applied.
	Obj.UseJumpBoost = false
	
	-- Multiplies the up force if th next force goes up.
	-- This is mainly for countering workspace.Gravity
	Obj.UpForceMultiplier = 1
	
	-- If the mover uses force duration for cooldown time.
	Obj.DoesForceCooldown = true
	
	-- If the launching is enabled.
	Obj.Enabled = true
	
	-- The volume of the sound played for the mover.
	Obj.SoundVolume = 1
	
	-- Applies the force.
	function Obj.Launch()
		if IsPreparingLaunch == false then
			IsPreparingLaunch = true
			
			if Obj.Enabled == true and IsOnCooldown == false then
				coroutine.wrap(DoCooldown)()

				if Obj.UseForceOverride == true then
					CharAdapter.CancelForces()
				end

				-- Prepare launch force
				if Obj.UseJumpBoost == true then
					local Humanoid = ObjParts.Humanoid
					if typeof(Humanoid) == "Instance" and Humanoid:IsA("Humanoid") then
						Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end

				local NextForce = Obj.NextForce

				-- Apply up force multiplier, if going up
				local YForceMultiplier = 1
				if NextForce.Y > 0 then
					YForceMultiplier = Obj.UpForceMultiplier
				end
				NextForce = NextForce * Vector3.new(1, YForceMultiplier, 1)

				-- Launch
				CharAdapter.ApplyForce(NextForce, Obj.ForceDuration)
				Obj.OnLaunch.Fire(NextForce)
				NextForce = nil

				-- Play the sound.
				coroutine.wrap(PlaySound)(Obj.SoundId, Obj.SoundVolume)
				--print("Playing sound", Obj.SoundId)
			end
			
			IsPreparingLaunch = false
		end
	end

	-- Sets if the Dispose() is called when the Part is parented to nil.
	function Obj.SetAutoDispose(IsAuto)
		if IsAuto == true then
			Obj.SetAutoDispose(false)
		else
			if DestroyConnection ~= nil then
				DestroyConnection:Disconnect()
			end
			DestroyConnection = nil
		end
	end
	
	-- Initialize
	if ObjParts.Character ~= nil then
		UseRig(Obj.RigName)
	end
	CharAdapter.LoadedEvent.Connect(OnCharLoad)

	-- Fired when the mover is triggered.
	-- Params:
	-- Velocity - The velocity of the launch.
	Obj.OnLaunch = Signal.New()

	Obj.OnDisposal = function()
		Obj.OnLaunch.DisconnectAll()

		CharAdapter.LoadedEvent.Disconnect(OnCharLoad)
		UseRig(nil)
		InteractingRig = nil

		ObjParts = nil
	end

	return Obj
end

return BaseMover