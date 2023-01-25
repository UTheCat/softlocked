--[[
buttons from the iconic jtoh kit with a few additions
]]--

local Interactives = script.Parent.Parent
local MapHandles = Interactives.Parent

local BaseInteractive = require(Interactives:WaitForChild("BaseInteractive"))
local TweenGroup = require(MapHandles.Parent:WaitForChild("Utils"):WaitForChild("TweenGroup"))

local LocalPlayer = game:GetService("Players").LocalPlayer

local DefaultPressSound = script:WaitForChild("PressSound")

local Button = {}

function Button.CanPartToggle(Trigger: BasePart, OtherPart: BasePart)
	return (OtherPart:GetAttribute("HitsButtonId") == Trigger:GetAttribute("ButtonId")
		or (OtherPart.Name == "Hitbox" and OtherPart.Parent == LocalPlayer.Character))
end

function Button.New(Val: StringValue, MapLauncher: {})
	local Interact = BaseInteractive.New()
	local Tweens = TweenGroup.New()
	local ButtonModel = Val.Parent

	local TouchConnections = {}

	-- whatever stored in the property archive
	-- is affected by the button
	-- and also contains original properties
	local PropertyArchive = {}

	local ActivatorArchive = {}
	local ActivatorCFrames = {}

	Interact.IsActivated = false
	Interact.DefaultTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Interact.CurrentTimer = nil
	Interact.Color = Val:GetAttribute("Color")
	
	function Interact.Deactivate()
		if Interact.IsActivated then
			Tweens.KillAll()
			local DefaultTweenInfo = Interact.DefaultTweenInfo
			
			local CurrentTimer = Interact.CurrentTimer
			if CurrentTimer then
				Interact.CurrentTimer = nil
				CurrentTimer.Dispose()
			end

			for i, v in pairs(PropertyArchive) do
				local Properties = {}
				local IsChanging = false

				local OffCollision = i:GetAttribute("OffCollision")
				if OffCollision ~= nil then
					i.CanCollide = OffCollision
				end

				local OffTransparency = i:GetAttribute("OffTransparency")
				if OffTransparency then
					IsChanging = true
					Properties.Transparency = OffTransparency
				end

				local OriginalCFrame = v.CFrame

				if OriginalCFrame then
					IsChanging = true
					Properties.CFrame = OriginalCFrame
				end

				if IsChanging then
					Tweens.Play(i, DefaultTweenInfo, Properties)
				end
			end

			for i, v in pairs(ActivatorArchive) do
				local OriginalCFrame = ActivatorCFrames[i]
				if OriginalCFrame then
					Tweens.Play(i, DefaultTweenInfo, {CFrame = OriginalCFrame})
				end

				local Material = v.Material
				if Material then
					i.Material = Material
				end
			end
			
			ActivatorArchive = {}

			Interact.IsActivated = false
		end
	end

	function Interact.Activate(Activator: BasePart?, Duration: number?)
		local DefaultTweenInfo = Interact.DefaultTweenInfo
		
		if Interact.IsActivated == false then
			Interact.IsActivated = true

			Tweens.KillAll()

			-- go through affected parts
			for i, v in pairs(PropertyArchive) do
				local Properties = {}
				local IsChanging = false

				local OnCollision = i:GetAttribute("OnCollision")
				if OnCollision ~= nil then
					i.CanCollide = OnCollision
				end

				local OnTransparency = i:GetAttribute("OnTransparency")

				if OnTransparency then
					IsChanging = true
					Properties.Transparency = OnTransparency
				end

				local OriginalCFrame: CFrame = v.CFrame

				if OriginalCFrame then
					local Moved = false

					local Move: Vector3? = i:GetAttribute("ButtonMove")
					local Rotate: Vector3? = i:GetAttribute("ButtonRotate")

					if Move then
						Moved = true
						IsChanging = true
						OriginalCFrame = OriginalCFrame:ToWorldSpace(CFrame.new(Move))
					end

					if Rotate then
						Moved = true
						IsChanging = true
						OriginalCFrame = OriginalCFrame:ToWorldSpace(CFrame.fromOrientation(
							math.rad(Rotate.X), math.rad(Rotate.Y), math.rad(Rotate.Z)
							)
						)
					end

					if Moved then
						Properties.CFrame = OriginalCFrame
					end
				end

				if IsChanging then
					Tweens.Play(i, DefaultTweenInfo, Properties)
				end
			end
		end
		
		-- let them know they pressed the button
		if ActivatorArchive[Activator] == nil then
			local ActivatorMove = Activator:GetAttribute("ActivatorMove")
			if ActivatorMove then
				Tweens.Play(Activator, DefaultTweenInfo, {
					CFrame = ActivatorCFrames[Activator]:ToWorldSpace(CFrame.new(ActivatorMove))
				})
			end
			
			local Properties = {}

			if Activator:GetAttribute("UseNeon") then
				Properties.Material = Activator.Material
				Activator.Material = Enum.Material.Neon
			end

			ActivatorArchive[Activator] = Properties

			local PressSound: Sound = Activator:FindFirstChild("PressSound") or DefaultPressSound

			if PressSound then
				PressSound:Play()
			end

			if Duration and Duration > 0 then
				local CurrentTimer = Interact.CurrentTimer

				if CurrentTimer then
					CurrentTimer.TimeLeft += Duration
				else
					local NewTimer = MapLauncher.GetLoader().GetController("ButtonTimer").Attach(
						Interact, nil, Duration
					)

					NewTimer.OnFinish = Interact.Deactivate

					Interact.CurrentTimer = NewTimer
					NewTimer.Start()
				end
			end
		end
	end

	function Interact.OnInitialize()
		for i, v in pairs(ButtonModel:WaitForChild("AffectedParts"):GetChildren()) do
			if v:IsA("BasePart") then
				local Properties = {}
				local StoreProperties = false

				local OffTransparency = v:GetAttribute("OffTransparency")

				if OffTransparency or v:GetAttribute("OnTransparency") then
					StoreProperties = true
					Properties.Transparency = v.Transparency
				end

				if OffTransparency then
					v.Transparency = OffTransparency
				end

				if v:GetAttribute("ButtonMove") or v:GetAttribute("ButtonRotate") then
					StoreProperties = true
					Properties.CFrame = v.CFrame
				end

				local OffCollision = v:GetAttribute("OffCollision")
				if OffCollision or v:GetAttribute("OnCollision") then
					StoreProperties = true
					Properties.CanCollide = v.CanCollide
				end

				if OffCollision ~= nil then
					v.CanCollide = OffCollision
				end

				if StoreProperties then
					PropertyArchive[v] = Properties
				end
			end
		end
	end

	function Interact.OnStart()
		for i, v in pairs(ButtonModel:WaitForChild("Deactivators"):GetChildren()) do
			if v:IsA("BasePart") then
				local IsTouched = false

				table.insert(TouchConnections, v.Touched:Connect(function(OtherPart)
					if IsTouched == false and Button.CanPartToggle(v, OtherPart) then
						IsTouched = true
						Interact.Deactivate()
						IsTouched = false
					end
				end))
			end
		end

		for i, v in pairs(ButtonModel:WaitForChild("Activators"):GetChildren()) do
			if v:IsA("BasePart") then
				ActivatorCFrames[v] = v.CFrame

				local IsTouched = false

				table.insert(TouchConnections, v.Touched:Connect(function(OtherPart)
					if IsTouched == false and Button.CanPartToggle(v, OtherPart) then
						IsTouched = true
						Interact.Activate(v, v:GetAttribute("AddedDuration"))
						IsTouched = false
					end
				end))
			end
		end
	end

	function Interact.OnShutdown()
		Interact.Deactivate()

		for i, v in pairs(TouchConnections) do
			v:Disconnect()
		end
		TouchConnections = {}

		for i, v in pairs(ActivatorCFrames) do
			i.CFrame = v
		end
		ActivatorCFrames = {}
	end

	function Interact.OnDisposal()
		Tweens.Dispose()

		for i, v in pairs(PropertyArchive) do
			for i2, v2 in pairs(v) do
				i[i2] = v2
			end
		end

		PropertyArchive = {}
	end

	return Interact
end

return Button