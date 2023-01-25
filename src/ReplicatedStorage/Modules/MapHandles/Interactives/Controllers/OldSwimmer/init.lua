--[[
This revamp handles liquid submersion and display

By udev2192
]]--

local RunService = game:GetService("RunService")

local Interactives = script.Parent.Parent

local BaseInteractive = require(Interactives:WaitForChild("BaseInteractive"))
local PropertyLock = require(Interactives.Parent:WaitForChild("Util"):WaitForChild("PropertyLock"))
local Object = BaseInteractive.GetObjectClass()
local Signal = BaseInteractive.GetSignalClass()
local SwimmerInput = require(script:WaitForChild("SwimmerInput"))

local Camera = workspace.CurrentCamera

local Swimmer = {}

function Swimmer.New(Loader: {}, Player: Player)
	local Swim = Object.New("Swimmer")
	local Input = SwimmerInput.New()
	
	local IsAlive = false
	
	local ActiveLiquids: {BasePart} = {}
	local ActiveDisplays: {[BasePart]: BasePart} = {}
	local Head: BasePart
	local Runner: RBXScriptConnection
	local DeathEvent: RBXScriptConnection
	local Character: Model
	local LightingFx: ColorCorrectionEffect
	local LastDirection: string
	
	Swim.CurrentLiquid = nil
	Swim.CurrentCamLiquid = nil
	
	--[[
	<number> - How fast the player swims
	]]--
	Swim.Speed = game:GetService("StarterPlayer").CharacterWalkSpeed
	
	local function OnSpawn(Char: Model)
		if Char then
			Character = Char
			IsAlive = true
			Head = Char:WaitForChild("Head")
			
			local Humanoid = Char:WaitForChild("Humanoid")
			if DeathEvent == nil then
				DeathEvent = Humanoid.HealthChanged:Connect(function(Health)
					if Health <= 0 then
						DeathEvent:Disconnect()
						Input.ToggleSwimmerInput(false)
						IsAlive = false
					end
				end)
			end
		end
	end
	
	OnSpawn(Player.Character)
	local PlayerSpawnConnection = Player.CharacterAdded:Connect(OnSpawn)
	
	function Swim.ClearDisplays()
		for i, v in pairs(ActiveDisplays) do
			v:Destroy()
		end
		
		ActiveDisplays = {}
	end
	
	function Swim.RemoveDisplay(Liquid: BasePart)
		local Display = ActiveDisplays[Liquid]
		if Display then
			ActiveDisplays[Liquid] = nil
			Display.Part:Destroy()
			Display.Lock.ReleaseAll()
		end
	end
	
	function Swim.AddDisplay(Liquid: BasePart)
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

			ActiveDisplays[Liquid] = Display
			Display.Parent = Liquid
		end
	end
	
	function Swim.StopLoop()
		if Runner then
			Runner:Disconnect()
			Runner = nil
		end
	end

	function Swim.RunLoop()
		Runner = RunService.Heartbeat:Connect(function()
			local PRIORITY = "Priority"
			local SelectedLiquid: BasePart
			local SelectedCamLiquid: BasePart
			
			local HeadPos: Vector3 = Head.Position
			local CamPos: Vector3 = Camera.CFrame.Position
			local HighestPriority = 0
			
			for i, v in pairs(ActiveLiquids) do
				local IsHigherPriority = (v:GetAttribute(PRIORITY) or 0) > SelectedLiquid:GetAttribute(PRIORITY)
				
				if BaseInteractive.IsPointInside(HeadPos, v) and IsHigherPriority then
					-- Higher liquid priority means it gets selected
					-- over one that intersects
					SelectedLiquid = v
				end
				
				if BaseInteractive.IsPointInside(CamPos, v) then
					Swim.AddDisplay(v)
					
					if IsHigherPriority then
						SelectedCamLiquid = v
					end
				else
					Swim.RemoveDisplay(v)
				end
			end
			
			if SelectedLiquid ~= Swim.CurrentLiquid then
				Swim.CurrentLiquid = SelectedLiquid
			end
			
			if SelectedCamLiquid ~= Swim.CurrentCamLiquid then
				Swim.CurrentCamLiquid = SelectedCamLiquid
				
				-- if the camera is submerged in a liquid
				-- make it look like so
				if SelectedCamLiquid then
					if LightingFx == nil then
						LightingFx = Instance.new("ColorCorrectionEffect")
						LightingFx.Brightness = 0
						LightingFx.TintColor = SelectedCamLiquid.Color
						LightingFx.Parent = Camera
					else
						LightingFx.TintColor = SelectedCamLiquid.Color
					end
				elseif LightingFx then
					LightingFx:Destroy()
					LightingFx = nil
				end
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
	
	function Swim.Clear()
		Swim.StopLoop()
		ActiveLiquids = {}
	end
	
	function Swim.Remove(Liquid: BasePart)
		local Index = table.find(ActiveLiquids, Liquid)
		
		if Index then
			table.remove(ActiveLiquids, Index)
		end
		
		if Liquid == Swim.CurrentLiquid then
			Swim.CurrentLiquid = nil
		end
		
		if Liquid == Swim.CurrentCamLiquid then
			Swim.CurrentCamLiquid = nil
		end
	end
	
	function Swim.Add(Liquid: BasePart)
		table.insert(ActiveLiquids, Liquid)
	end
	
	function Input.DirectionChanged(Direction: string)
		LastDirection = Direction
	end
	
	function Swim.OnDisposal()
		PlayerSpawnConnection:Disconnect()
		PlayerSpawnConnection = nil
		
		if DeathEvent then
			DeathEvent:Disconnect()
			DeathEvent = nil
		end
		
		Swim.StopLoop()
		Input.Dispose()
	end
	
	return Swim
end

return Swimmer