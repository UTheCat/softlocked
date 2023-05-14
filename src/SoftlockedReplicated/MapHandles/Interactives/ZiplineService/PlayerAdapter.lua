--[[
The Rider module adapter/wrapper for players.

By default, the player gets off a zipline
when they jump or when they die.

By udev2192
]]--

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ZiplineService = script.Parent
local Object = require(ZiplineService.Parent:WaitForChild("BaseInteractive")).GetObjectClass()
local Rider = require(ZiplineService:WaitForChild("Rider"))

local PlayerAdapter = {}

-- For manual tuning (default numbers are for R6)
local LAUNCH_VELOCITY_MULTIPLIER = 1
local JUMP_VELOCITY_MULTIPLIER = 1

-- Sets if the ziplines can only be triggered
-- by one rig.
local USING_ONE_RIG = false

-- Attribute names
local JUMP_DISMOUNT_ATTRIBUTE = "CanJumpToDismount"
local GRAB_SOUND_ATTRIBUTE = "GrabSound"
local RIDE_SOUND_ATTRIBUTE = "RideSound"
local RELEASE_SOUND_ATTRIBUTE = "ReleaseSound"
local VOLUME_ATTRIBUTE = "Volume"

-- Humanoid states where a player would let go of the zipline.
PlayerAdapter.RELEASE_STATES = {Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.Jumping}

-- The name of the rig of the character that can triggger the zipline.
PlayerAdapter.RIG_NAME = "Head"

--PlayerAdapter.GRAB_SOUND = "rbxassetid://12222054"
--PlayerAdapter.RIDE_SOUND = "rbxassetid://12222076" -- Loop
--PlayerAdapter.RELEASE_SOUND = "rbxassetid://11900833"

local function WaitForDur(s)
	if typeof(s) == "number" and s > 0 then
		local Elapsed = 0
		
		while Elapsed < s do
			Elapsed += RunService.Heartbeat:Wait()
		end
	end
end

local function PlaySound(URL, Volume)
	if URL ~= nil and URL ~= "" then
		coroutine.wrap(function()
			local Sound = Instance.new("Sound")
			Sound.SoundId = URL
			Sound.Looped = false
			Sound.Volume = Volume or 0.5
			Sound.Parent = script
			Sound:Play()
			Sound.Ended:Wait()
			Sound:Destroy()
			Sound = nil
		end)()
	end
end

local function IsPart(Part)
	return typeof(Part) == "Instance" and Part:IsA("Part")
end

local function GetWeightOfPart(Part)
	assert(IsPart(Part), "Argument 1 must be a BasePart.")
	
	local Weight = Part:GetMass()
	for i, v in pairs(Part:GetConnectedParts()) do
		if IsPart(v) then
			Weight += v:GetMass()
		end
	end
	
	return Weight
end

-- Rider workspace cache toggler.
function PlayerAdapter.ToggleRiderCache(Enabled)
	Rider.ToggleRiderCache(Enabled)
end

function PlayerAdapter.New(Player)
	assert(typeof(Player) == "Instance" and Player:IsA("Player"), "Argument 1 must be a player instance.")
	assert(RunService:IsClient(), "PlayerAdapter is currently only supported on the client.")

	local Obj = Object.New("ZiplinePlayerAdapter")
	local StateChangedEvent = nil
	local JumpRequestEvent = nil
	
	Obj.Character = nil
	Obj.Humanoid = nil
	Obj.RespawnEvent = nil
	Obj.Rider = Rider.New()
	Obj.RideLoop = nil
	Obj.Rig = nil
	Obj.RigTouchEvent = nil
	Obj.RootPart = nil
	Obj.UseMomentum = true -- If momentum is applied on zipline release
	
	-- How long to wait before accepting the next zipline
	-- jump request.
	Obj.NextJumpDelay = 0.005
	
	-- This number multiplies the humanoid's WalkSpeed,
	-- which is used for the zipline rider speed.
	-- This might be needed so the player doesn't
	-- feel as if riding the zipline is too slow.
	-- No longer used as of customization update.
	--Obj.HumanoidSpeedMultiplier = 1.5

	local PlayerLeavingEvent = nil

	local function DisconnectHumanoidChange()
		if StateChangedEvent ~= nil then
			StateChangedEvent:Disconnect()
			StateChangedEvent = nil
		end
	end
	
	local function DisconnectJumpRequest()
		if JumpRequestEvent ~= nil then
			JumpRequestEvent:Disconnect()
			JumpRequestEvent = nil
		end
	end
	
	-- This function handles releases before the player
	-- reaches the end of a zipline.
	local function HandleEarlyRelease()
		DisconnectJumpRequest()
		DisconnectHumanoidChange()

		-- Release
		Obj.DoInternalRelease()
	end
	
	local function ToggleRideLoop(IsPlaying, Url)
		local PrevLoop = Obj.RideLoop
		
		if IsPlaying == true then
			if Url ~= nil and Url ~= "" then
				ToggleRideLoop(false) -- In case the loop is still playing

				local Loop = Instance.new("Sound")
				Obj.RideLoop = Loop
				
				Loop.SoundId = Url
				Loop.Looped = true
				Loop.Parent = script
				Loop:Play()

				Loop = nil
			end
		elseif PrevLoop ~= nil then
			PrevLoop:Destroy()
		end
		
		PrevLoop = nil
	end

	function Obj.DoInternalRelease()
		if Obj.Rider ~= nil then
			Obj.Rider.Release()
		end
	end
	
	-- Sets the velocity of the HumanoidRootPart (for internal use)
	function Obj.SetVelocity(velocity)
		if Obj.UseMomentum == true then
			local RootPart = Obj.RootPart
			if RootPart ~= nil then
				velocity = velocity * LAUNCH_VELOCITY_MULTIPLIER
				RootPart.AssemblyLinearVelocity = velocity
				RootPart:ApplyImpulse(velocity)
			end
		end
	end

	function Obj.HandleHumanoidChange(State)
		-- Release from a zipline if there is a release state match
		if table.find(PlayerAdapter.RELEASE_STATES, State) then
			Obj.DoInternalRelease()
		end

		if State == Enum.HumanoidStateType.Dead then
			if Obj.RigTouchEvent ~= nil then
				Obj.RigTouchEvent:Disconnect()
				Obj.RigTouchEvent = nil
			end

			if Obj.Rider ~= nil then
				Obj.Rider.DisconnectAll()
			end

			DisconnectHumanoidChange()
			DisconnectJumpRequest()
		end
	end
	
	-- Connects "important" rider events
	function Obj.ReconnectEvents()
		-- Disconnect previously connected events, just in case.
		DisconnectJumpRequest()
		DisconnectHumanoidChange()

		-- Reconnect.
		local ObjRider = Obj.Rider
		local Humanoid = Obj.Humanoid

		if ObjRider ~= nil and Humanoid ~= nil then
			local NextLaunchVelocty = nil
			
			-- Debounce values.
			local IsGrabbing = false
			local IsReleasing = false
			local JumpRequested = false
			
			-- Event connections.
			ObjRider.OnGrab = function(Zip)
				if IsGrabbing == false and IsReleasing == false and JumpRequested == false then
					IsGrabbing = true
					
					NextLaunchVelocty = nil -- Just in case
					--StateChangedEvent = Obj.Humanoid.StateChanged:Connect(Obj.HandleHumanoidChange)

					-- Connect to releasing when the player dies.
					StateChangedEvent = Obj.Humanoid.HealthChanged:Connect(function(health)
						if health <= 0 then
							ObjRider.DisconnectAll() -- So the player can't grab a zipline while being dead.
							HandleEarlyRelease()
						end
					end)

					-- Makes players have the ability to jump to dismount.
					-- This applies if the zipline allows for it.
					-- Needed for now cause PlatformStand sucks.
					if Zip.GetModelSetting(JUMP_DISMOUNT_ATTRIBUTE) == true then
						JumpRequestEvent = UserInputService.JumpRequest:Connect(function()
							if JumpRequested == false then
								JumpRequested = true
								
								--print("Jump to release requested")
								HandleEarlyRelease()

								if Humanoid ~= nil and ObjRider ~= nil then
									local lv = ObjRider.LastVelocity
									NextLaunchVelocty = Vector3.new(lv.X, Humanoid.JumpPower * JUMP_VELOCITY_MULTIPLIER, lv.Z)
									Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								end
								
								-- Counter "multi-grabbing" by waiting.
								WaitForDur(Obj.NextJumpDelay or 0)
								
								JumpRequested = false
							end
						end)
					end
					
					IsGrabbing = false
					
					local Vol = Zip.GetModelSetting(VOLUME_ATTRIBUTE)
					PlaySound(Zip.GetModelSetting(GRAB_SOUND_ATTRIBUTE), Vol)
					ToggleRideLoop(true, Zip.GetModelSetting(RIDE_SOUND_ATTRIBUTE), Vol)
				end
			end

			Obj.Rider.OnRelease = function(Zip)
				if IsReleasing == false then
					IsReleasing = true
					
					--print("release detected")
					DisconnectHumanoidChange()
					DisconnectJumpRequest()
					--Obj.Humanoid.PlatformStand = false

					if NextLaunchVelocty == nil then
						local LastVelocity = Obj.Rider.LastVelocity
						--print(LastVelocity)
						Obj.SetVelocity(LastVelocity)
					else
						--print("Next launch velocity", NextLaunchVelocty)
						Obj.SetVelocity(NextLaunchVelocty)
					end

					NextLaunchVelocty = nil

					PlaySound(Zip.GetModelSetting(RELEASE_SOUND_ATTRIBUTE), Zip.GetModelSetting(VOLUME_ATTRIBUTE))
					ToggleRideLoop(false)
					
					IsReleasing = false
				end
			end
		end
	end

	-- Does the internal respawn handling.
	-- This is where the zipline ability stuff happens.
	function Obj.HandleRespawn(char)
		if typeof(char) == "Instance" then
			-- Clear the connected parts remaining
			local ObjRider = Obj.Rider
			if ObjRider ~= nil then
				ObjRider.DisconnectAll()

				-- Connect humanoid state change events
				local Humanoid = char:WaitForChild("Humanoid", 5)
				assert(typeof(Humanoid) == "Instance" and Humanoid:IsA("Humanoid"), "The character's humanoid is missing.")
				Obj.Humanoid = Humanoid
				Obj.RootPart = char:WaitForChild("HumanoidRootPart")
				ObjRider.Speed = Humanoid.WalkSpeed * (Obj.HumanoidSpeedMultiplier or 1)

				-- Reconnect the interacting rig
				Obj.Character = char
				Obj.Rig = char:WaitForChild(PlayerAdapter.RIG_NAME)
				Obj.ReconnectEvents()
				ObjRider.RidingRig = Obj.Rig
				if USING_ONE_RIG == true then
					ObjRider.AddTouchConnection(Obj.Rig)
				else
					for i, v in pairs(Obj.Character:GetChildren()) do
						if v:IsA("BasePart") then
							ObjRider.AddTouchConnection(v)
						end
					end
				end
			end
		end
	end

	-- Set the specified rig to be able to interact with ziplines
	Obj.SetProperty("InteractingRig", nil, function(rig)
		if typeof(rig) == "Instance" and rig:IsA("BasePart") and Obj.Rider ~= nil then
			Obj.Rider.DisconnectAll()
			Obj.Rider.AddTouchConnection(rig)
		end
	end)

	-- Initialize
	Obj.HandleRespawn(Player.Character)

	Obj.RespawnEvent = Player.CharacterAdded:Connect(Obj.HandleRespawn)

	PlayerLeavingEvent = Players.PlayerRemoving:Connect(function(plr)
		if plr == Player then
			PlayerLeavingEvent:Disconnect()
			PlayerLeavingEvent = nil
			
			DisconnectHumanoidChange()
			DisconnectJumpRequest()

			Obj.Rider.Dispose()
			Obj.Dispose()
		end
	end)
	
	Obj.OnDisposal = function()
		-- Release and get rid of the rider on disposal.
		HandleEarlyRelease()
		
		local ObjRider = Obj.Rider
		
		if ObjRider ~= nil then
			ObjRider.Dispose()
		end
		
		ObjRider = nil
	end

	return Obj
end

return PlayerAdapter