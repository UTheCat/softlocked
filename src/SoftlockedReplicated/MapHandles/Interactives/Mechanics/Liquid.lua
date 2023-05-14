--[[
Liquids as an interactive (finally)

By udev2192
]]--

local RunService = game:GetService("RunService")

local Camera = workspace.CurrentCamera
local LocalPlayer = game:GetService("Players").LocalPlayer

local Interactives = script.Parent.Parent
local Util = Interactives.Parent:WaitForChild("Util")

local BaseInteractive = require(Interactives:WaitForChild("BaseInteractive"))
local PropertyLock = require(Util:WaitForChild("PropertyLock"))
local Signal = BaseInteractive.GetSignalClass()

local Liquid = {}

function Liquid.New(Val: StringValue, MapLauncher: {})
	local Obj = BaseInteractive.New()
	local LiquidParts = {}
	local ActiveDisplays = {}
	
	local DisplayPart: Part
	local SpawnConnection: RBXScriptConnection
	local Runner: RBXScriptConnection
	local Head: BasePart
	local Loader
	
	Obj.InteractiveValue = Val
	Obj.IsHeadSubmerged = false
	Obj.IsCameraSubmerged = false
	
	function Obj.ClearDisplays()
		for i, v in pairs(ActiveDisplays) do
			v:Destroy()
		end

		ActiveDisplays = {}
	end
	
	--[[
	Returns:
	<number> - The priority of the liquid
	]]--
	function Obj.GetPriority()
		return Val:GetAttribute("Priority") or 0
	end
	
	--[[
	Returns:
	<Color3?> - The liquid's desired color, or nil if it isn't found
	]]--
	function Obj.GetColor()
		local Color = Val:GetAttribute("Color")
		if Color then
			return Color
		end
		
		local FirstPart = LiquidParts[1]
		if FirstPart then
			return FirstPart.Color
		end
		
		return nil
	end

	function Obj.RemoveDisplay(Liquid: BasePart)
		local Display = ActiveDisplays[Liquid]
		if Display then
			ActiveDisplays[Liquid] = nil
			Display.Part:Destroy()
			Display.Lock.ReleaseAll()
		end
	end

	function Obj.AddDisplay(Liquid: BasePart)
		if ActiveDisplays[Liquid] == nil and Liquid:IsA("Part") and Liquid.Shape == Enum.PartType.Block then
			local LiquidSize = Liquid.Size
			local TopSize = LiquidSize.Y / 2
			local Display = Liquid:Clone()
			Display.Size = Vector3.new(LiquidSize.X, 0.005, LiquidSize.Z)
			Display.Anchored = true
			Display.CanCollide = false
			Display.CanQuery = false
			Display.CanTouch = false
			Display.CFrame = Liquid.CFrame + Vector3.new(0, TopSize, 0)

			local Lock = PropertyLock.New(Liquid)
			Lock.Set("Transparency", 1)

			ActiveDisplays[Liquid] = {
				Part = Display,
				Lock = Lock
			}
			
			Display.Parent = Liquid
		end
	end
	
	local function OnSpawn(Char: Model)
		if Char then
			Head = Char:WaitForChild("Head")
		end
	end

	function Obj.OnStart()
		for i, v in pairs(Val.Parent:WaitForChild("Parts"):GetChildren()) do
			if v:IsA("BasePart") then
				table.insert(LiquidParts, v)
			end
		end
		
		Loader = MapLauncher.GetLoader()
		Loader.GetController("Swimmer").Add(Obj)
		
		OnSpawn(LocalPlayer.Character)
		SpawnConnection = LocalPlayer.CharacterAdded:Connect(OnSpawn)
		Runner = RunService.Heartbeat:Connect(function()
			-- determine submersion status
			local IsHeadInside = false
			local IsCamInside = false
			for i, v in pairs(LiquidParts) do
				if IsHeadInside == false then
					if BaseInteractive.IsPointInside(Head.Position, v) then
						IsHeadInside = true
					end
				end
				
				if BaseInteractive.IsPointInside(Camera.CFrame.Position, v) then
					IsCamInside = true
					Obj.AddDisplay(v)
				else
					Obj.RemoveDisplay(v)
				end
			end
			if IsHeadInside ~= Obj.IsHeadSubmerged then
				Obj.IsHeadSubmerged = IsHeadInside
				Obj.HeadEntryChanged.Fire(IsHeadInside)
			end
			if IsCamInside ~= Obj.IsCameraSubmerged then
				Obj.IsCameraSubmerged = IsCamInside
				Obj.CameraEntryChanged.Fire(IsCamInside)
			end
			
			-- update liquid displays
			for i, v in pairs(ActiveDisplays) do
				local Display: Part = v.Part
				Display.CFrame = i.CFrame + Vector3.new(0, i.Size.Y / 2, 0)

				-- check that they haven't changed yet, because changing them
				-- causes a tiny bit of lag each
				if Display.Color ~= i.Color then
					Display.Color = i.Color
				end
				if Display.Material ~= i.Material then
					Display.Material = i.Material
				end
			end
		end)
	end

	function Obj.OnShutdown()
		if SpawnConnection then
			SpawnConnection:Disconnect()
			SpawnConnection = nil
		end
		
		if Runner then
			Runner:Disconnect()
			Runner = nil
		end
		
		if Loader then
			Loader.GetController("Swimmer").Remove(Obj)
			Loader = nil
		end
	end
	
	--[[
	Fires when the liquid's submersion status changes
	]]--
	Obj.HeadEntryChanged = Signal.New()
	
	--[[
	Fires when the camera's submersion status changes
	]]--
	Obj.CameraEntryChanged = Signal.New()

	return Obj
end

return Liquid