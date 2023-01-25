--[[
Class that handles a set of spinners and syncs them every frame

By udev2192
]]--

local BaseInteractive = require(script.Parent.Parent:WaitForChild("BaseInteractive"))

local SpinnerSet = {}

--[[
<string> - Attribute name that defines how long a full rotation takes
		   for each part
]]--
SpinnerSet.RotationTimeAttribute = "RotationTime"

SpinnerSet.ClockwiseAttribute = "IsClockwise"

--SpinnerSet.PhysicsInstanceName = "SpinnerModuleConstraint"
--SpinnerSet.PhysicsAttachmentName = "SpinnerModuleAttachment"
SpinnerSet.AngularVelocityTorque = Vector3.new(50000, 50000, 50000)
SpinnerSet.AttachmentAngle = Vector3.new(0, 0, 90)
SpinnerSet.AttachPartSize = Vector3.new(1, 1, 1)

function SpinnerSet.New(Model)
	local Interactive = BaseInteractive.New()
	local Parts = Model:WaitForChild("Parts")

	local FoundParts = {}
	local TimeElapsed = 0
	local IsRunning = false

	local function ResetParts()
		for i, v in pairs(FoundParts) do
			i.CFrame = v.OriginalCFrame
			i.Anchored = v.WasAnchored

			for i2, v2 in pairs(v.PhysicsObjects) do
				v2:Destroy()
			end
			v.PhysicsObjects = {}
		end

		FoundParts = {}
	end

	local function DoSpinnerLoop()
		local LastFrameTime = task.wait()

		while true do
			if IsRunning then
				local RootPart = BaseInteractive.GetCharacterHandle().Parts.RootPart

				if RootPart then

					-- Note that the index is the part here
					for i, v in pairs(FoundParts) do
						if IsRunning then
							local RotationTime = i:GetAttribute(SpinnerSet.RotationTimeAttribute)

							if RotationTime > 0 then
								local IsClockwise = i:GetAttribute(SpinnerSet.ClockwiseAttribute)
								local PhysicsRadius = i:GetAttribute(BaseInteractive.PhysicsRadiusAttribute)

								-- Calculate the offset percent
								local Time = v.Time
								local NewTime
								if IsClockwise then
									NewTime = Time + LastFrameTime
								else
									NewTime = Time - LastFrameTime
								end

								-- Make sure the time doesn't go overboard
								-- Modulus already does absolute value or whatever
								if NewTime > RotationTime then
									NewTime = NewTime % RotationTime
								end
								v.Time = NewTime

								-- For eliminating physics lag (fix the constraints later)
								if PhysicsRadius == -1 or BaseInteractive.GetDistance(RootPart.CFrame.Position, i.CFrame.Position) <= PhysicsRadius then
									if #v.PhysicsObjects <= 0 then
										--	local Att0 = Instance.new("Attachment")
										--	Att0.Position = Vector3.new(0, 0.5, 0)
										--	Att0.Orientation = Vector3.new(0, 0, -90)

										--	--local Att1 = Instance.new("Attachment")
										--	--Att1.Position = Vector3.new(0, 1, 0)

										--	local Velocity = Vector3.new(0, math.rad((1 / RotationTime) * 360), 0)
										--	if not IsClockwise then
										--		Velocity *= -1
										--	end

										--	local Torque = Instance.new("Torque")
										--	Torque.Attachment0 = Att0
										--	Torque.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
										--	Torque.Torque = Velocity

										--	--local Constraint = Instance.new("HingeConstraint")
										--	--Constraint.LimitsEnabled = false
										--	--Constraint.ActuatorType = Enum.ActuatorType.Motor

										--	-- Basically angle per second in radians
										--	--Constraint.AngularVelocity = math.rad((1 / RotationTime) * 360)
										--	--Constraint.Attachment0 = Att0
										--	--Constraint.Attachment1 = Att1

										--	--Att0.Parent = i
										--	--Att1.Parent = i
										--	--Constraint.Parent = i

										--	table.insert(v.PhysicsObjects, Att0)
										--	--table.insert(v.PhysicsObjects, Att1)
										--	--table.insert(v.PhysicsObjects, Constraint)
										--	table.insert(v.PhysicsObjects, Torque)

										--	Att0.Parent = i
										--	Torque.Parent = i

										--	-- THANK YOU URCHIN
										--	--local AngularVelocity = Instance.new("BodyAngularVelocity")

										--	--table.insert(v.PhysicsObjects, AngularVelocity)

										--	--local Velocity = Vector3.new(0, math.rad((1 / RotationTime) * 360), 0)
										--	--if not IsClockwise then
										--	--	Velocity *= -1
										--	--end

										--	--AngularVelocity.AngularVelocity = Velocity
										--	--AngularVelocity.MaxTorque = SpinnerSet.AngularVelocityTorque

										--	--AngularVelocity.Parent = i


										-- Unstable, but it's the best we've got for now
										local Velocity = math.rad((1 / RotationTime) * 360)--Vector3.new(0, math.rad((1 / RotationTime) * 360), 0)
										if not IsClockwise then
											Velocity *= -1
										end

										local AttachPart = Instance.new("Part")
										AttachPart.Anchored = true
										AttachPart.CanCollide = false
										AttachPart.CanTouch = false
										AttachPart.CFrame = i.CFrame
										AttachPart.Transparency = 1
										AttachPart.Size = SpinnerSet.AttachPartSize

										local Att0 = Instance.new("Attachment")
										Att0.Position = Vector3.zero
										Att0.Orientation = SpinnerSet.AttachmentAngle
										Att0.Name = "Attachment0"

										local Att1 = Att0:Clone()
										Att1.Name = "Attachment1"
										
										local Hinge = Instance.new("HingeConstraint")
										Hinge.ActuatorType = Enum.ActuatorType.None
										Hinge.LimitsEnabled = false
										Hinge.AngularVelocity = Velocity
										Hinge.Attachment0 = Att0
										Hinge.Attachment1 = Att1
										Hinge.MotorMaxAcceleration = math.huge
										Hinge.MotorMaxTorque = math.huge

										Att0.Parent = AttachPart
										Att1.Parent = i
										Hinge.Parent = AttachPart
										AttachPart.Parent = Model
										
										i.AssemblyAngularVelocity = Vector3.new(0, Velocity, 0)

										local PhysicsObjTable = v.PhysicsObjects
										table.insert(PhysicsObjTable, AttachPart)
										table.insert(PhysicsObjTable, Att0)
										table.insert(PhysicsObjTable, Att1)
										table.insert(PhysicsObjTable, Hinge)
									end

									--i.AssemblyLinearVelocity = Vector3.zero
									--i.AssemblyAngularVelocity = Velocity

									-- This check is here for micro-optimization
									if i.Anchored then
										i.Anchored = false
									end
								else
									if not i.Anchored then
										i.Anchored = true
										v.ContinueCFrame = i.CFrame
									end

									if #v.PhysicsObjects > 0 then
										for i2, v2 in pairs(v.PhysicsObjects) do
											v2:Destroy()
										end
										v.PhysicsObjects = {}
									end	
									
									-- Set the CFrame
									if IsRunning then
										i.CFrame = v.ContinueCFrame * CFrame.fromOrientation(
											0,
											math.rad((NewTime / RotationTime) * 360),
											0
										)
									end	
								end
							end
						else
							break
						end
					end
				end

				if IsRunning then
					LastFrameTime = task.wait()
					TimeElapsed += LastFrameTime
				else
					break
				end
			else
				break
			end
		end

		ResetParts()
	end

	Interactive.OnShutdown.Connect(function()
		IsRunning = false
		TimeElapsed = 0
	end)

	Interactive.OnStart.Connect(function()
		TimeElapsed = 0

		for i, v in pairs(Parts:GetChildren()) do
			if v:IsA("BasePart") then
				v.Anchored = true

				local Cframe = v.CFrame
				FoundParts[v] = {
					OriginalCFrame = Cframe,
					ContinueCFrame = Cframe,
					Time = 0,
					PhysicsObjects = {},
					WasAnchored = v.Anchored
				}
			end
		end

		if IsRunning == false then
			IsRunning = true
			task.spawn(DoSpinnerLoop)
		end
	end)

	return Interactive
end

return SpinnerSet