--[[
Interactive that changes the local player's health

For performance reasons, health is only changed on the client
]]--

local Players = game:GetService("Players")

local Interactives = script.Parent.Parent
local InteractiveUtil = Interactives.Parent:WaitForChild("Util")

local BaseInteractive = require(Interactives:WaitForChild("BaseInteractive"))
local PointHitbox = require(InteractiveUtil:WaitForChild("PointHitbox"))

local HealthChanger = {}
HealthChanger.__index = HealthChanger
HealthChanger.IncrementAttribute = "Increment"
HealthChanger.RepeatDelayAttribute = "RepeatDelay"
--HealthChanger.DetectionRadiusAttribute = "DetectionRadius"

function HealthChanger.ChangeClientHealth(Increment: number)
	local Humanoid: Humanoid = BaseInteractive.GetCharacterHandle().Parts.Humanoid
	if Humanoid then
		Humanoid.Health = math.clamp(Humanoid.Health + Increment, 0, Humanoid.MaxHealth)
	end
end

function HealthChanger.New(Val: StringValue, MapLauncher: {})
	local LocalPlayer = Players.LocalPlayer
	assert(LocalPlayer ~= nil, "No LocalPlayer was found")

	local Changer = BaseInteractive.New()
	--local Hitbox = PointHitbox.New()

	local Connections: {RBXScriptConnection} = {}
	local TouchingParts: {BasePart} = {}
	local PartsFolder: Folder = Val.Parent:WaitForChild("Parts")
	local HealthChanging = false

	-- REMEMBER TO FIX HITBOX LOGIC (it's inaccurate)
	--local function CheckHit(IsEntered)
	--	if IsEntered then
	--		if HealthChanging == false then
	--			HealthChanging = true
	--			local IncrementName = HealthChanger.IncrementAttribute
	--			local RepeatDelayName = HealthChanger.RepeatDelayAttribute

	--			-- Do the first health change
	--			HealthChanger.ChangeClientHealth(Val:GetAttribute(IncrementName) or 0)

	--			-- Repeat if needed
	--			
	--		end
	--	else
	--		HealthChanging = false
	--	end
	--end
	
	local function CanChangeHealth()
		return HealthChanging and #TouchingParts > 0
	end

	local function UpdateHealthChange()
		if HealthChanging == false then
			HealthChanging = true
			HealthChanger.ChangeClientHealth(Val:GetAttribute(HealthChanger.IncrementAttribute) or 0)
			
			while true do
				if #TouchingParts <= 0 then
					HealthChanging = false
					break
				end
				
				if HealthChanging == false then
					break
				end

				local DelayElapsed = 0

				-- Delay must be greater than 0 since we don't wanna crash the client
				while CanChangeHealth() and DelayElapsed <= math.max(Val:GetAttribute(HealthChanger.RepeatDelayAttribute) or 0, 0) do
					DelayElapsed += task.wait()
				end

				if CanChangeHealth() then
					HealthChanger.ChangeClientHealth(Val:GetAttribute(HealthChanger.IncrementAttribute) or 0)
				else
					HealthChanging = false
					break
				end
			end
		end
	end

	local function DisconnectTouch()
		for i, v in pairs(Connections) do
			v:Disconnect()
		end

		Connections = {}
		TouchingParts = {}
	end

	-- Connect the local player's character
	local function OnCharacterLoad(Parts)
		--local HitboxPart = Parts.Hitbox

		--if HitboxPart then
		--	Hitbox.BindedPart = HitboxPart
		--	Hitbox.DetectionRadius = Val:GetAttribute(HealthChanger.DetectionRadiusAttribute) or 0
		--	Hitbox.DetectionPart = Val.Parent:WaitForChild("DetectionCenter")
		--	CheckHit(Hitbox.Scan())
		--	Hitbox.EntryChanged.Connect(CheckHit)
		--	Hitbox.Start()
		--end

		DisconnectTouch()

		local Hitbox: BasePart = Parts.Hitbox

		if Hitbox then
			table.insert(Connections, Hitbox.TouchEnded:Connect(function(OtherPart)
				if OtherPart.Parent == PartsFolder then
					local Index = table.find(TouchingParts, OtherPart)

					if Index then
						table.remove(TouchingParts, Index)
					end
				end
			end))

			table.insert(Connections, Hitbox.Touched:Connect(function(OtherPart)
				if OtherPart.Parent == PartsFolder and table.find(TouchingParts, OtherPart) == nil then
					table.insert(TouchingParts, OtherPart)
					UpdateHealthChange()
				end
			end))
		end
	end

	function Changer.OnStart()
		local CharHandle = BaseInteractive.GetCharacterHandle()

		OnCharacterLoad(CharHandle.Parts)
		CharHandle.LoadedEvent.Connect(OnCharacterLoad)

		--if CharHandle then
		--	local Parts = Val.Parent:WaitForChild("Parts")

		--	if Parts then
		--		--local AppliedParts = {}
		--		--for i, v in pairs(Parts:GetChildren()) do
		--		--	if v:IsA("BasePart") then
		--		--		table.insert(AppliedParts, v)
		--		--	end
		--		--end
		--		--Hitbox.ScannedParts = AppliedParts


		--	end
		--end
	end

	function Changer.OnShutdown()
		--Hitbox.Stop()
		--Hitbox.ScannedParts = {}

		local CharHandle = BaseInteractive.GetCharacterHandle()

		if CharHandle then
			CharHandle.LoadedEvent.Disconnect(OnCharacterLoad)
		end

		DisconnectTouch()
		HealthChanging = false
	end

	--Changer.OnStart.Connect(function()

	--end)

	--Changer.OnShutdown.Connect(function()

	--end)

	return Changer
end

return HealthChanger