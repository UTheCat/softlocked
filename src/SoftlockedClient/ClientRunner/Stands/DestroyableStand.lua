-- A version of the PlayerStand that has lives.
-- By udev2192

local Players = game:GetService("Players")

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("SoftlockedReplicated")
local UtilModules = RepModules:WaitForChild("Utils")

local Runtime = require(UtilModules:WaitForChild("Runtime"))
local Signal = require(UtilModules:WaitForChild("Signal"))
local TimeWaiter = require(UtilModules:WaitForChild("TimeWaiter"))
local Util = require(UtilModules:WaitForChild("Utility"))

local PlayerStand = require(script.Parent:WaitForChild("PlayerStand"))

RepModules, UtilModules = nil, nil

local DestroyableStand = {}

function DestroyableStand.New(CharAdapter)
	local Stand = PlayerStand.New(CharAdapter)
	local OriginalDiameter = Stand.GetDiameter()
	local AnimWaiter = nil
	local IsCharacterAlive = false
	
	local function DisposeAnimWaiter()
		if AnimWaiter ~= nil then
			AnimWaiter.Dispose()
			AnimWaiter = nil
		end
	end
	
	-- Gets the currently preferred stand size.
	local function GetStandSize()
		return (OriginalDiameter or 1) * ((Stand.Lives or 1) / (Stand.MaxLives or 1))
	end
	
	-- Fades the stand part out, then destroys it.
	local function FadeStandPart(Time)
		local StandPart = Stand.Part

		if StandPart ~= nil then
			if Time > 0 then
				coroutine.wrap(function()
					Util.Tween(StandPart, TweenInfo.new(Time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1})
					Runtime.WaitForDur(Time)
					Stand.DestroyStandPart()
				end)()
			else
				StandPart.Transparency = 1
				Stand.DestroyStandPart()
			end
		end
	end
	
	-- If a life is decremented by 1 when the
	-- character dies.
	Stand.SubtractLifeOnDeath = true
	
	-- The maximum amount of lives in the player stand.
	Stand.MaxLives = 3
	
	-- The amount of "lives" in the player stand
	Stand.SetProperty("Lives", Stand.MaxLives, function(lives)
		-- Fire the signal to indicate change
		local ChangeSignal = Stand.LivesChanged
		if ChangeSignal ~= nil then
			ChangeSignal.Fire(lives)
		end
		ChangeSignal = nil
		
		-- Animate to show the amount of lives left
		-- (Fade the stand if no lives are left)
		local RespawnTime = Players.RespawnTime
		local AnimTime = Stand.DiameterTweenInfo.Time
		local StandPart = Stand.Part
		local FadeTime = RespawnTime - AnimTime - 0.5

		if lives > 0 then
			AnimWaiter = TimeWaiter.New(AnimTime)
			Stand.AnimateDiameter(GetStandSize())
			
			-- Wait to fade
			AnimWaiter.Waited.Connect(function()
				DisposeAnimWaiter()
				FadeStandPart(FadeTime)
			end)
			coroutine.wrap(AnimWaiter.Wait)()
		else
			-- Fade immediately
			FadeStandPart(FadeTime)
		end
	end)
	
	-- Fired when the amount of lives changes.
	-- Params:
	-- Lives (number) - The new amount of lives.
	Stand.LivesChanged = Signal.New()
	
	local function ToggleConnections(IsConnected)
		Stand.ToggleTouchConnection(IsConnected)
		Stand.ToggleMoveRunner(IsConnected)
	end
	
	-- Connect character events
	local function OnCharLoad()
		IsCharacterAlive = true
		
		-- Respawn stand part if it's alive
		if Stand.Lives > 0 then
			DisposeAnimWaiter()

			Stand.RespawnPart()
			Stand.SetDiameter(GetStandSize())
			
			ToggleConnections(true)
		end
	end
	
	local function OnDeath()
		if IsCharacterAlive == true then
			IsCharacterAlive = false
			
			-- Decrement lives if enabled
			if Stand.SubtractLifeOnDeath == true then
				Stand.Lives += -1
			end

			ToggleConnections(false)
		end
	end
	
	OnCharLoad()
	
	CharAdapter.LoadedEvent.Connect(OnCharLoad)
	CharAdapter.DeathEvent.Connect(OnDeath)
	
	Stand.AddDisposalListener(function()
		CharAdapter.LoadedEvent.Disconnect(OnCharLoad)
		CharAdapter.DeathEvent.Disconnect(OnDeath)
		
		DisposeAnimWaiter()
		
		local ChangeSignal = Stand.LivesChanged
		if ChangeSignal ~= nil then
			ChangeSignal.Dispose()
		end
		Stand.LivesChanged = nil
		ChangeSignal = nil
	end)
	
	return Stand
end

return DestroyableStand