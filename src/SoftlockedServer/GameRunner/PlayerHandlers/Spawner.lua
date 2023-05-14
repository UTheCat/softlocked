-- Takes care of player spawning.
-- By udev2192

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local RepModules = RepStorage:WaitForChild("Modules")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Runtime = require(UtilRepModules:WaitForChild("Runtime"))
local Object = require(UtilRepModules:WaitForChild("Object"))

--local DEFAULT_PHYSICS_GROUP = PhysicsService:GetCollisionGroupName(0)
local HEALTH_SCRIPT_NAME = "Health"

local Spawner = {}
local CollisionGroups = require(
	RepModules:WaitForChild("MapHandles")
	:WaitForChild("Interactives")
	:WaitForChild("BaseInteractive")
).CollisionGroups

Spawner.DefaultRespawnTime = Players.RespawnTime

-- If player-to-player collisions are enabled by default
Spawner.PlayersCollideByDefault = false

Spawner.PlayerCollisionGroup = CollisionGroups.Players

-- How long to wait in seconds before moving the character
-- to the spawn.
-- This is needed because moving immediately after spawn
-- almost always fails.
Spawner.SpawnMoveDelay = 0.01

Players.CharacterAutoLoads = false -- So that this module takes care of spawning
--PhysicsService:CreateCollisionGroup(Spawner.PlayerCollisionGroup)
--PhysicsService:CollisionGroupSetCollidable(Spawner.PlayerCollisionGroup, Spawner.PlayerCollisionGroup, false)

local function IsPlayer(Player)
	return typeof(Player == "Instance") and Player:IsA("Player")
end

local function TogglePartPlayerCollision(Part, Collides)
	if Collides == true then
		PhysicsService:SetPartCollisionGroup(Part, CollisionGroups.Default)
	else
		PhysicsService:SetPartCollisionGroup(Part, Spawner.PlayerCollisionGroup)
	end
end

function Spawner.New(Player)
	assert(IsPlayer(Player), "The player object must be a player instance.")
	
	local Obj = Object.New("PlayerSpawner")
	--local IsAwaitingSpawn = false -- Set to true when the player dies
	
	local Connections = {}
	
	Obj.Character = nil
	Obj.CharacterHeight = 5
	Obj.Humanoid = nil
	Obj.Player = Player
	Obj.RespawnTime = Spawner.DefaultRespawnTime
	
	-- The BasePart in which the player will spawn at next.
	Obj.Spawn = nil
	
	--[[
	<boolean> - If set to false, any server script parented to the player's
	character named "Health" is destroyed.
	]]--
	Obj.KeepHealthScript = false
	
	local function CanSpawnPlayer()
		return Player.Parent == Players
	end
	
	local function WaitForRespawnTime()
		local RespawnTime = Obj.RespawnTime
		local Elapsed = 0
		while Obj.AutoRespawns == true and Elapsed < RespawnTime and CanSpawnPlayer() do
			Elapsed += RunService.Heartbeat:Wait()
		end
	end
	
	local function CheckDescendant(d)
		if typeof(d) == "Instance" then
			if d:IsA("BasePart") then
				TogglePartPlayerCollision(d, Obj.CanCharCollide)
			elseif Obj.KeepHealthScript == false and d:IsA("Script") and d.Name == HEALTH_SCRIPT_NAME then
				d:Destroy()
			end
		end
	end
	
	-- Sets if character descendants are listened to when they're added.
	local function TogglePhysicGroupListener(Connected)
		local Char = Obj.Character
		if Connected == true then
			Connections.DescendantAddedEvent = Char.DescendantAdded:Connect(CheckDescendant)
		else
			local AddedEvent = Connections.DescendantAddedEvent
			if AddedEvent ~= nil then
				AddedEvent:Disconnect()
			end
			AddedEvent = nil
		end
	end
	
	-- Function that is called on respawn to
	-- set player-to-player collision.
	local function SetCharCollidable(Collides)
		local Char = Obj.Character
		if Char ~= nil then
			local CharParts = Char:GetDescendants()
			if #CharParts > 0 then
				if Collides == true then
					if Connections.DescendantAddedEvent ~= nil then
						TogglePhysicGroupListener(false)
					end
				else
					if Connections.DescendantAddedEvent == nil then
						TogglePhysicGroupListener(true)
					end
				end
			end
			
			for i, v in pairs(CharParts) do
				CheckDescendant(v)
				--if v:IsA("BasePart") then
				--	TogglePartPlayerCollision(v, Collides)
				--end
			end
			
			CharParts = nil
		end
	end
	
	-- Spawns and returns the player's character.
	local function SpawnChar()
		Player:LoadCharacter()
		local Char = Player.Character
		Obj.Character = Char
		SetCharCollidable(Obj.CanCharCollide)
		return Char
	end
	
	-- Internally spawns at a given location.
	local function SpawnAt(Cf)
		local Char = SpawnChar()
		if Char ~= nil and typeof(Char) == "Instance" then
			local Humanoid = Char:WaitForChild("Humanoid", 5)

			if typeof(Humanoid) == "Instance" then
				Obj.Character = Char
				Obj.Humanoid = Humanoid
				coroutine.wrap(function()
					Runtime.WaitForDur(Spawner.SpawnMoveDelay)
					Obj.SetCFrame(Cf)
				end)()
			else
				Char:Destroy()
			end

			Humanoid = nil
		end

		Char = nil
	end
	
	-- Spawns the character on top of Obj.Spawn.
	local function SpawnAtSelected()
		local Selected = Obj.Spawn
		if Selected ~= nil then
			SpawnAt(Selected.CFrame + Vector3.new(0, Selected.Size.Y/2 + Obj.CharacterHeight/2, 0))
		end
	end
	
	local function HandleDeath()
		if Obj.AutoRespawns == true then
			--IsAwaitingSpawn = true
			WaitForRespawnTime()
			
			if CanSpawnPlayer() then
				SpawnAtSelected()
			end
		end
	end
	
	local function SetHumanoidHealthConnected(Connected)
		if Connected == true then
			-- Disconnect, in case this was previously connected.
			SetHumanoidHealthConnected(false)
			
			-- Connect again.
			local Humanoid = Obj.Humanoid
			if Humanoid ~= nil then
				Connections.HumanoidHealthEvent = Humanoid.HealthChanged:Connect(function(health)
					if health <= 0 then
						-- Take care of the humanoid's death.
						SetHumanoidHealthConnected(false)
						HandleDeath()
						if Obj.AutoRespawns == true then
							SetHumanoidHealthConnected(true)
						end
					end
				end)
			end
		else
			local HealthEvent = Connections.HumanoidHealthEvent
			if HealthEvent ~= nil then
				HealthEvent:Disconnect()
			end
			Connections.HumanoidHealthEvent = nil
			HealthEvent = nil
		end
	end
	
	-- Sets the character's CFrame.
	function Obj.SetCFrame(Cf)
		local Char = Obj.Character
		if Char ~= nil and Char.PrimaryPart ~= nil then
			Char:SetPrimaryPartCFrame(Cf)
		end
	end
	
	-- If the player's character is spawned.
	Obj.SetProperty("IsSpawned", false, function(val)
		--IsAwaitingSpawn = false
		
		if val == true then
			SpawnAtSelected()
		else
			if Obj.Character ~= nil then
				Obj.Character:Destroy()
			end
		end
	end)
	
	-- If the player's character can collide with other players.
	Obj.SetProperty("CanCharCollide", Spawner.PlayersCollideByDefault, function(val)
		SetCharCollidable(val)
	end)
	
	-- Sets if the character can auto-respawn.
	Obj.SetProperty("AutoRespawns", false, function(val)
		if val == true then
			Obj.IsSpawned = true -- Spawns the player
			SetHumanoidHealthConnected(true)
		else
			SetHumanoidHealthConnected(false)
		end
	end)
	
	Obj.SetInstanceDestroy(false)
	
	function Obj.OnDisposal()
		for i, v in pairs(Connections) do
			v:Disconnect()
		end
		
		Connections = {}
	end
	
	return Obj
end

return Spawner
