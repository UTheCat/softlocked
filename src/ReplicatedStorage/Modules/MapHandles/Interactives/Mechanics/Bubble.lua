--[[
celeste is such a good game and i haven't even played it

By udev2192
]]--

local TweenService = game:GetService("TweenService")
--local RunService = game:GetService("RunService")

local Interactives = script.Parent.Parent
local Util = Interactives.Parent:WaitForChild("Util")

local BaseInteractive = require(Interactives:WaitForChild("BaseInteractive"))
local Bezier = require(Util:WaitForChild("Bezier"))
local PropertyLock = require(Util:WaitForChild("PropertyLock"))

local Bubble = {}

function Bubble.New(Val: StringValue, MapLauncher: {})
	local Interact = BaseInteractive.New()
	local PropertiesModule = Val:FindFirstChild("BubbleProperties")
	
	local PointParts: {BasePart} = {}
	
	-- {Bubble part, number value, tween instance, property lock}
	local RidingParts: {[BasePart]: {}} = {}
	
	local Course
	local TouchConnection: RBXScriptConnection
	
	Interact.PopEffect = script:WaitForChild("PopEffect")
	Interact.MoveEffect = script:WaitForChild("MoveEffect")
	
	Interact.PopSound = script:WaitForChild("PopSound")
	Interact.MoveSound = script:WaitForChild("MoveSound")
	Interact.BlowSound = script:WaitForChild("BlowSound")
	
	Interact.BlowTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	--[[
	Pops a bubble that's carrying the specified part
	
	Params:
	Part <BasePart> - The part
	]]--
	function Interact.Pop(Part: BasePart, UseEffects: boolean)
		local Ride = RidingParts[Part]
		
		if Ride then
			RidingParts[Part] = nil
			
			if Ride[2] then
				Ride[2]:Destroy()
			end
			
			local Tween = Ride[3]
			if Tween then
				Tween:Pause()
				Tween:Destroy()
				Tween = nil
			end
			
			local AnchorLock = Ride[4]
			if AnchorLock then
				AnchorLock.ReleaseAll()
				AnchorLock = nil
			end
			
			if UseEffects then
				local BubblePart: BasePart = Ride[1]
				
				local PopEffect: ParticleEmitter = Interact.PopEffect
				if PopEffect then
					local Sound = Val:FindFirstChild("PopSound") or Interact.PopSound
					if Sound then
						Sound:Play()
					end
					
					local MoveEffect = BubblePart:FindFirstChild("MoveEffect")
					if MoveEffect then
						MoveEffect:Destroy()
					end
					
					BubblePart.Transparency = 1
					local Effect = PopEffect:Clone()
					Effect.Parent = BubblePart
					
					Effect:Emit(Effect:GetAttribute("NumParticles"))
					task.wait(Effect.Lifetime.Max)
					Effect:Destroy()
				end
				
				BubblePart:Destroy()
			else
				Ride[1]:Destroy()
			end
		end
	end
	
	--[[
	Blows a bubble for the specified part, then carries it
	along the course
	
	Params:
	Part <BasePart> - The part
	]]--
	function Interact.Carry(Part: BasePart)
		if Course and RidingParts[Part] == nil then
			local FirstPoint = PointParts[1]
			assert(FirstPoint, "Cannot spawn bubble because the first part/point in its intended path is missing")
			
			local OriginalRideTable = {}
			RidingParts[Part] = OriginalRideTable
			
			if Val:GetAttribute("StopsVelocity") then
				Part.AssemblyLinearVelocity = Vector3.zero
			end
			
			local AnchorLock = PropertyLock.New(Part)
			AnchorLock.Set("Anchored", true)
			OriginalRideTable[4] = AnchorLock
			--if RidingParts[Part] == nil then
			--	Interact.Pop(Part)
			--end

			local Properties = require(PropertiesModule)

			local BubblePart = Instance.new("Part")
			BubblePart.Material = Enum.Material.Ice
			BubblePart.Color = Color3.fromRGB(85, 170, 255)
			BubblePart.Name = "Bubble"
			BubblePart.Position = FirstPoint.Position
			BubblePart.Orientation = FirstPoint.Orientation
			BubblePart.Shape = Enum.PartType.Ball
			
			local PartProperties = Properties.PartProperties
			if PartProperties then
				for i, v in pairs(PartProperties) do
					BubblePart[i] = v
				end
			end
			PartProperties = nil
			
			BubblePart.Anchored = true
			BubblePart.CanCollide = false
			BubblePart.CanTouch = false
			BubblePart.CanQuery = false
			BubblePart.Size = Vector3.zero
			BubblePart.Transparency = 0.5
			BubblePart.Parent = Part.Parent

			-- Blow the bubble
			local BlowTweenInfo: TweenInfo = Properties.BlowTweenInfo or Interact.BlowTweenInfo
			
			local CharMoveTween: Tween = TweenService:Create(Part, BlowTweenInfo, {CFrame = FirstPoint.CFrame})
			
			local CurrentTween: Tween = TweenService:Create(
				BubblePart,
				BlowTweenInfo,
				{Size = Properties.Size or Vector3.new(9, 9, 9)}
			)
			CurrentTween.Completed:Connect(function()
				CurrentTween:Destroy()
				
				local RideTable = RidingParts[Part]
				if RideTable then
					-- Move the bubble to its destination along the course
					local TimeVal: NumberValue = Instance.new("NumberValue")
					TimeVal.Value = 0
					TimeVal.Changed:Connect(function(NewTime)
						-- Wait for the task scheduler to do its stuff
						-- so the transition is smooth
						task.wait()
						
						-- Update the position
						BubblePart.Position = Course.SmoothLerp(NewTime)
						Part.CFrame = BubblePart.CFrame

						if NewTime >= 1 then
							-- Done
							CurrentTween:Destroy()
							Interact.Pop(Part, true)
						end
					end)
					

					local MoveSound = Interact.MoveSound
					if MoveSound then
						MoveSound = MoveSound:Clone()
						MoveSound.Parent = BubblePart
					end
					
					local MoveEffect = Interact.MoveEffect
					if MoveEffect then
						MoveEffect = MoveEffect:Clone()
						MoveEffect.Parent = BubblePart
					end
					
					CurrentTween = TweenService:Create(TimeVal, Properties.CarryTweenInfo, {Value = 1})
					RideTable[2] = TimeVal
					RideTable[3] = CurrentTween
					CurrentTween:Play()
				end
			end)
			
			local BlowSound = Interact.BlowSound
			if BlowSound then
				BlowSound:Play()
			end
			
			--RidingParts[Part] = {BubblePart, nil, CharMoveTween}
			OriginalRideTable[1] = BubblePart
			OriginalRideTable[3] = CharMoveTween
			CurrentTween:Play()
			CharMoveTween:Play()
		end
	end
	
	function Interact.OnInitialize()
		-- Find bezier points
		local PointsFolder: Folder = Val.Parent:WaitForChild("Points")
		local Points: {Vector3} = {}
		
		for i, v in pairs(PointsFolder:GetChildren()) do
			if v:IsA("BasePart") then
				local Number = tonumber(v.Name)
				
				if Number then
					--table.insert(Points, Number, v.CFrame.Position)
					Points[Number] = v.CFrame.Position
					--table.insert(PointParts, Number, v)
					PointParts[Number] = v
				end
			end
		end
		
		local NumPoints = #Points
		if NumPoints < 2 then
			error("Cannot calculate bubble course because there are less than 2 parts to use as points.")
		end
		
		-- Calculate segments
		local AutoNumSegments: boolean = Val:GetAttribute("AutoNumSegments")
		local NumSegments: number
		
		if AutoNumSegments then
			if Points == 2 then
				NumSegments = 2
			else
				NumSegments = math.max((Points[2] - Points[1]).Magnitude, 2)
			end
		else
			NumSegments = Val:GetAttribute("NumSegments")
		end
		
		Course = Bezier.New(Val:GetAttribute("Degree"), NumSegments, Points)
	end
	
	function Interact.OnStart()
		if TouchConnection == nil then
			TouchConnection = Val.Parent:WaitForChild("Hitbox").Touched:Connect(function(OtherPart)
				if
					OtherPart:GetAttribute("CanBubbleCarry") 
					or OtherPart == BaseInteractive.GetCharacterHandle().Parts.RootPart
				then
					Interact.Carry(OtherPart)
				end
			end)
		end
	end
	
	function Interact.OnShutdown()
		if TouchConnection then
			TouchConnection:Disconnect()
			TouchConnection = nil
		end
		
		for i, v in pairs(RidingParts) do
			Interact.Pop(i, false)
		end
	end
	
	function Interact.OnDisposal()
		Interact.OnShutdown()
	end
	
	return Interact
end

return Bubble