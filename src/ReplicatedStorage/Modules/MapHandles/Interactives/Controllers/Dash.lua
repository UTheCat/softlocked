--[[
MADELINE CELESTE MADELINE CELESTE MADELINE CELESTE MADELINE CELESTE MADELINE CELESTE MADELINE CELESTE MADELINE CELESTE

make dash zones later because being able to dash at all times is
a bit broken in a jtoh fangame
]]--

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--local Object = require(script.Parent.Parent:WaitForChild("BaseInteractive")).GetObjectClass()

local Dash = {}

function Dash.New(Player: Player)
	local ObjDash = {}
	
	local JumpConnection: RBXScriptConnection
	local RespawnConnection: RBXScriptConnection
	local StateChangeConnection: RBXScriptConnection
	local RootPart: BasePart
	local Humanoid: Humanoid
	
	local IsFreefalling = false
	
	ObjDash.TotalDashes = 0
	ObjDash.DashesLeft = 0
	ObjDash.DashCooldown = 0.2
	ObjDash.FreefallCheckDelay = 0.2
	ObjDash.IsRecharging = false
	ObjDash.DashSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed * 2
	ObjDash.DashJumpPower = game:GetService("StarterPlayer").CharacterJumpPower * 1.5
	ObjDash.DashSound = script:WaitForChild("DashActivate")
	
	local function DisconnectStateChange()
		if StateChangeConnection then
			StateChangeConnection:Disconnect()
			StateChangeConnection = nil
		end
	end
	
	local function OnRespawn(Character: Model)
		if Character then
			ObjDash.DashesLeft = 0
			DisconnectStateChange()
			
			RootPart = Character:WaitForChild("HumanoidRootPart")
			Humanoid = Character:WaitForChild("Humanoid")
			
			ObjDash.DashesLeft = ObjDash.TotalDashes
			
			if StateChangeConnection == nil then
				StateChangeConnection = Humanoid.StateChanged:Connect(function(OldState, NewState)
					if NewState == Enum.HumanoidStateType.Landed then
						IsFreefalling = false
						ObjDash.DashesLeft = ObjDash.TotalDashes
					elseif NewState == Enum.HumanoidStateType.Freefall then
						task.wait(ObjDash.FreefallCheckDelay)
						IsFreefalling = true
					end
				end)
			end
		end
	end
	
	function ObjDash.CanDash()
		return ObjDash.DashesLeft > 0 and Humanoid and Humanoid.Health > 0 and IsFreefalling
	end
	
	function ObjDash.RechargeDashes()
		if ObjDash.IsRecharging == false then
			ObjDash.IsRecharging = true
			
			local CooldownElapsed = 0

			while true do
				if CooldownElapsed >= ObjDash.DashCooldown then
					CooldownElapsed = 0
					ObjDash.DashesLeft += 1
				end

				if ObjDash.IsRecharging == false or ObjDash.DashesLeft >= ObjDash.TotalDashes then
					break
				end

				CooldownElapsed += task.wait()
			end
		end
	end
	
	function ObjDash.Disable()
		if RespawnConnection then
			RespawnConnection:Disconnect()
			RespawnConnection = nil
		end
		
		if JumpConnection then
			JumpConnection:Disconnect()
			JumpConnection = nil
		end
		
		DisconnectStateChange()
	end
	
	function ObjDash.Enable()
		OnRespawn(Player.Character)
		
		if RespawnConnection == nil then
			RespawnConnection = Player.CharacterAdded:Connect(OnRespawn)
		end
		
		if JumpConnection == nil then
			local IsDashing = false
			
			JumpConnection = UserInputService.JumpRequest:Connect(function()
				if IsDashing == false and RootPart and ObjDash.CanDash() then
					IsDashing = true
					
					ObjDash.DashesLeft -= 1
					
					-- wait until just before the physics update
					-- for a more consistent boost
					RunService.Stepped:Wait()
					
					local Sound = ObjDash.DashSound
					if Sound then
						Sound:Play()
					end
					
					-- dash
					local MoveDir = Humanoid.MoveDirection
					local Speed = ObjDash.DashSpeed
					Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					RootPart.AssemblyLinearVelocity = Vector3.new(MoveDir.X * Speed, ObjDash.DashJumpPower, MoveDir.Z * Speed)
					
					-- recharge
					task.spawn(ObjDash.RechargeDashes)
					
					IsDashing = false
				end
			end)
		end
	end
	
	return ObjDash
end

return Dash