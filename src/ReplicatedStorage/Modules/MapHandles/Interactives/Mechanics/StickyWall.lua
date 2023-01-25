--[[
Flood Escape 2 by Crazyblox Games
]]--

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Interactives = script.Parent.Parent
local BaseInteractive = require(Interactives:WaitForChild("BaseInteractive"))
local PropertyLock = require(Interactives.Parent:WaitForChild("Util"):WaitForChild("PropertyLock"))

local DefaultSounds = script:WaitForChild("DefaultSounds")

local StickyWall = {}
StickyWall.__index = StickyWall

StickyWall.BouncePowerAttribute = "BouncePower"
StickyWall.JumpHeightAttribute = "JumpHeight"
StickyWall.IsEnabledAttribute = "IsEnabled"
StickyWall.StickDurationAttribute = "StickDuration"
StickyWall.GrabCooldownAttribute = "GrabCooldown"
StickyWall.LaunchDurationAttribute = "LaunchDuration"
StickyWall.GrabSoundName = "Grab"
StickyWall.ReleaseSoundName = "Release"

StickyWall.AttachedKey = "IsCharacterOnStickyWall"
StickyWall.RaycastCheckOffset = Vector3.new(2.5, 0, 0)

function StickyWall.New(StringVal: StringValue, MapLauncher: {})
	local StickPart = StringVal.Parent
	assert(StickPart and StickPart:IsA("BasePart"), "StickyWall interactive value must have a BasePart as its parent.")

	local Interact = BaseInteractive.New()
	local CharacterValues = BaseInteractive.GetCharacterHandle()

	local IsOnCooldown = false

	local TouchEvent
	local EnableChangeSignal
	local JumpSignal
	local StickDurationSignal
	local AnchorLock
	--local Weld

	local function CanInteract()
		return StringVal:GetAttribute(StickyWall.IsEnabledAttribute) == true
	end

	function Interact.PlaySound(Name)
		local Sound = StringVal:FindFirstChild(Name) or DefaultSounds:FindFirstChild(Name)

		if Sound then
			Sound:Play()
		end
	end

	function Interact.Release(BoostVelocity)
		if JumpSignal then
			JumpSignal:Disconnect()
			JumpSignal = nil
		end
		CharacterValues.DeathEvent.Disconnect(Interact.Release)

		if StickDurationSignal then
			StickDurationSignal:Disconnect()
			StickDurationSignal = nil
		end

		--if Weld then
		--	Weld:Destroy()
		--	Weld = nil
		--end
		if AnchorLock then
			AnchorLock.ReleaseAll()
			AnchorLock = nil
		end

		if BoostVelocity then
			CharacterValues.ApplyForce(BoostVelocity, StringVal:GetAttribute(StickyWall.LaunchDurationAttribute))
		end

		if IsOnCooldown then
			local Elapsed = 0
			while IsOnCooldown and Elapsed < (StringVal:GetAttribute(StickyWall.GrabCooldownAttribute) or 0) do
				Elapsed += task.wait()
			end
		end

		IsOnCooldown = false
	end

	local function ToggleTouch(IsEnabled)
		if IsEnabled then
			if TouchEvent == nil then
				TouchEvent = StickPart.Touched:Connect(function(OtherPart)
					local RootPart: BasePart = CharacterValues.Parts.RootPart

					if RootPart and OtherPart == RootPart then
						CharacterValues.DeathEvent.Connect(Interact.Release)
						
						local StickDuration = StringVal:GetAttribute(StickyWall.StickDurationAttribute)

						if StickDuration and StickDuration ~= 0 then
							if IsOnCooldown == false then
								IsOnCooldown = true

								-- Get launch direction
								local RaycastInfo = RaycastParams.new()
								RaycastInfo.FilterType = Enum.RaycastFilterType.Whitelist
								RaycastInfo.FilterDescendantsInstances = {StickPart}
								RaycastInfo.IgnoreWater = true

								local HitCFrame = RootPart.CFrame
								local RaycastResult: RaycastResult = BaseInteractive.RaycastWithOffset(
									HitCFrame,
									HitCFrame.LookVector.Unit * Vector3.new(2.5, 0, 2.5),
									RaycastInfo,
									nil--StickyWall.RaycastCheckOffset
								)

								if RaycastResult then

									--if RootPart then
									-- Stick to the StickyWall since the hit was successful
									local Pos = HitCFrame.Position

									-- This bit gives the orientation needed to make the character
									-- face the opposite direction of the wall
									local Normal = RaycastResult.Normal
									local ObjectSpace: CFrame = StickPart.CFrame:ToObjectSpace(CFrame.lookAt(Pos, Pos + Normal))
									if AnchorLock == nil then
										AnchorLock = PropertyLock.New(RootPart)
										AnchorLock.Set("Anchored", true)
									end
									
									-- For welding the anchored character to the wall
									local function UpdateCFrame()
										RootPart.CFrame = StickPart.CFrame:ToWorldSpace(ObjectSpace)
									end

									--print(Normal.X * 180 .. " degrees")
									--print(Normal * Vector3.new(180, 180, 180))
									--local Rotation = HitCFrame.LookVector * Normal
									--RootPart.CFrame = --CFrame.new(Pos.X, Pos.Y, Pos.Z) * CFrame.Angles(0, math.rad(Normal.Y * 180), 0)
									
									UpdateCFrame()
									Interact.PlaySound(StickyWall.GrabSoundName)

									--Weld = Instance.new("BodyVelocity")
									--Weld.Velocity = Vector3.zero
									--Weld.MaxForce = Vector3.zero
									--Weld.P = math.huge
									--Weld.Parent = RootPart

									-- Wait for the stick duration to expire, or
									-- for the player to jump
									if JumpSignal == nil then
										local Checking = false

										JumpSignal = UserInputService.JumpRequest:Connect(function()
											if Checking == false then
												Checking = true

												-- Calculate launch velocity boosted off the collided part face and release
												local BouncePower = StringVal:GetAttribute(StickyWall.BouncePowerAttribute)
												local JumpHeight = StringVal:GetAttribute(StickyWall.JumpHeightAttribute)

												if BouncePower and JumpHeight then
													Checking = false

													Interact.PlaySound(StickyWall.ReleaseSoundName)

													Interact.Release(Vector3.new(Normal.X * BouncePower, JumpHeight, Normal.Z * BouncePower))
												else
													Checking = false
												end
											end
										end)
									end

									if StickDurationSignal == nil and StickDuration > 0 then
										local Elapsed = 0

										StickDurationSignal = RunService.Heartbeat:Connect(function(Delta)
											Elapsed += Delta
											UpdateCFrame()

											if Elapsed > StickDuration then
												Interact.Release(Vector3.zero)
											end
										end)
									else
										StickDurationSignal = RunService.Heartbeat:Connect(UpdateCFrame)
									end
									--end
								else
									IsOnCooldown = false
								end
							end
						end
					end
				end)
			end
		else
			if TouchEvent then
				TouchEvent:Disconnect()
				TouchEvent = nil
			end
		end
	end
	
	function Interact.OnStart()
		if CanInteract() then
			ToggleTouch(true)
		end

		-- Connect IsEnabled attribute change
		if EnableChangeSignal == nil then
			EnableChangeSignal = StringVal.AttributeChanged:Connect(function(AttributeName)
				if AttributeName == StickyWall.IsEnabledAttribute then
					local Enabled = CanInteract()
					ToggleTouch(Enabled)

					if not Enabled then
						Interact.Release()
					end
				end
			end)
		end
	end
	
	function Interact.OnShutdown()
		if EnableChangeSignal then
			EnableChangeSignal:Disconnect()
			EnableChangeSignal = nil
		end

		ToggleTouch(false)
		IsOnCooldown = false
		Interact.Release()
	end

	--Interact.OnStart.Connect(function()
		
	--end)

	--Interact.OnShutdown.Connect(function()
		
	--end)

	return Interact
end

return StickyWall