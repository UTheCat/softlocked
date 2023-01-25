-- Handles multiplayer stand display. Intended for the client.

-- REMINDER TO MAKE THIS SYNC AND NOT HAVE ISSUES WHEN PLAYERS DIE

-- By udev2192

local Players = game:GetService("Players")

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")

local CharAdapter = require(RepModules:WaitForChild("Adapters"):WaitForChild("CharacterAdapter"))
local Object = require(RepModules:WaitForChild("ObjectGetter")).GetClass()

local DestroyableStand = require(script.Parent:WaitForChild("DestroyableStand"))

RepModules = nil

local MultiplayerStand = {}

local function IsPlayer(Obj)
	return typeof(Obj) == "Instance" and Obj:IsA("Player")
end

function MultiplayerStand.New()
	local Multi = Object.New("MultiplayerStand")
	local PlayerCharAdapters = {}
	local PlayerStands = {}
	
	local PlayerAddingEvent = nil
	local PlayerRemovingEvent = nil
	
	-- If the local player is included to be added to
	-- the object's list.
	Multi.IncludeLocalPlayer = false
	
	-- Removes objects created for the specified player's stand
	local function RemovePlayerObjects(Player)
		local Stand = PlayerStands[Player]
		if Stand ~= nil then
			Stand.Dispose()
		end
		PlayerStands[Player] = nil
		Stand = nil
		
		local Adapter = PlayerCharAdapters[Player]
		if Adapter ~= nil then
			Adapter.Dispose()
		end
		
		PlayerCharAdapters[Player] = nil
		Adapter = nil
	end
	
	-- Clears all the stored player objects.
	function Multi.ClearPlayerObjects()
		for i, v in pairs(PlayerCharAdapters) do
			RemovePlayerObjects(i)
		end
	end
	
	-- Sets if stand giving is automated (by character respawn).
	function Multi.SetAutomated(IsAutomated)
		if IsAutomated == true then
			Multi.SetAutomated(false)
			
			-- Reconnect player events
			local function OnPlayerAdd(Player)
				if IsPlayer(Player) == true and (Multi.IncludeLocalPlayer == true or Player ~= Players.LocalPlayer) then
					local PlrAdapter = CharAdapter.New(Player)
					PlayerCharAdapters[Player] = PlrAdapter
					
					PlayerStands[Player] = DestroyableStand.New(PlrAdapter)
					PlrAdapter = nil
				end
			end
			
			for i, v in pairs(Players:GetPlayers()) do
				OnPlayerAdd(v)
			end
			
			PlayerAddingEvent = Players.PlayerAdded:Connect(OnPlayerAdd)
			PlayerRemovingEvent = Players.PlayerRemoving:Connect(RemovePlayerObjects)
		else
			if PlayerAddingEvent ~= nil then
				PlayerAddingEvent:Disconnect()
				PlayerAddingEvent = nil
			end
			
			if PlayerRemovingEvent ~= nil then
				PlayerRemovingEvent:Disconnect()
				PlayerRemovingEvent = nil
			end
		end
	end
	
	Multi.OnDisposal = function()
		Multi.SetAutomated(false)
		
		-- Remove all player objects stored here on disposal
		Multi.ClearPlayerObjects()
	end
	
	return Multi
end

return MultiplayerStand