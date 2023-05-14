--[[
A basic module used to replicate stuff.
Similar to Replica by DataBrain.

Each replicator is referenced by instance name.

The BaseReplicator is basically for security in
client-to-server requests. The class is meant to
be extended by other modules.

Made by udev2192
]]--

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local PLAYER_ARGUMENT_INDEX = 1
local GLOBAL_INDICATOR = "ReplicatorContents"

local REMOTE_EVENT_ID = "_Event"
local REMOTE_FUNC_ID = "_Function"

-- If this is true, players who error the callback
-- when the server calls InvokeClient() will be kicked.
local CLIENT_INVOKE_KICKING = true

local BaseReplicator = {}
local Connections = {}

local RemoteFolder = nil

-- Server-client enums.
BaseReplicator.Client = 0
BaseReplicator.Server = 1

local function DoIsServerCheck()
	assert(RunService:IsServer(), "This action can only be performed from the server.")
end

local function IsFunc(f)
	return typeof(f) == "function"
end

local function IsPlayer(Player)
	return Player ~= nil and typeof(Player) == "Instance" and Player:IsA("Player")
end

-- Checks if the client-to-server request is valid
local function IsRequestValid(Replicator, Player)
	if RunService:IsServer() == true then
		if Replicator ~= nil then
			if IsPlayer(Player) then
				
				-- Check if the direction of the request is valid, if the player is whitelisted, and if the player is on send cooldown.
				if Replicator.ServerUseOnly == false and Replicator.IsWhitelisted(Player) and Replicator.IsOnCooldown(Player) == false then
					return true
				else
					-- Kick for sending the request from the client to the server
					-- when unauthorized.
					if Replicator.KickingEnabled then
						Player:Kick("Unauthorized request.")
					end

					return false
				end
			else
				return false
			end
		else
			return false
		end
	else
		-- Sanity checks aren't done on the client, so return true.
		return true
	end
end

-- Initializes/disposes the global table.
-- The global table for the server only.
local function ToggleGlobalTable(Enabled)
	DoIsServerCheck()
	
	if Enabled == true then
		if _G[GLOBAL_INDICATOR] == nil then
			_G[GLOBAL_INDICATOR] = {}
		end
	else
		_G[GLOBAL_INDICATOR] = nil
	end
end

local function GetGlobal(idx)
	return _G[GLOBAL_INDICATOR][idx]
end

local function SetGlobal(idx, val)
	_G[GLOBAL_INDICATOR][idx] = val
end

local function GetRemotesFolder()
	return RemoteFolder or script:WaitForChild(GLOBAL_INDICATOR, 5)
end

-- Creates a remote set for the replicator id
local function CreateReplicatorRemotes(Id)
	assert(typeof(Id) == "string", "Argument 1 must be a string.")

	DoIsServerCheck()
	
	local RemFolder = GetRemotesFolder()

	local RemEvent = Util.CreateInstance("RemoteEvent", {
		Name = Id .. REMOTE_EVENT_ID,
		Parent = RemFolder
	})

	local RemFunc = Util.CreateInstance("RemoteFunction", {
		Name = Id .. REMOTE_FUNC_ID,
		Parent = RemFolder
	})
	
	RemFolder = nil

	return RemEvent, RemFunc
end

local function GetReplicatorRemotes(Id)
	local RemFolder = GetRemotesFolder()
	
	if RemFolder ~= nil then
		local RemEvent = RemFolder:WaitForChild(Id .. REMOTE_EVENT_ID)
		local RemFunction = RemFolder:WaitForChild(Id .. REMOTE_FUNC_ID)
		
		return RemEvent, RemFunction
	else
		warn("Couldn't load the remotes folder.")
		return nil
	end
end

local function AddReplicator(id, rep)
	local RemEvent, RemFunction = nil, nil
	
	-- Connect event listeners.
	if RunService:IsServer() then
		RemEvent, RemFunction = CreateReplicatorRemotes(id)
		
		RemEvent.OnServerEvent:Connect(function(Player, ...)
			if IsRequestValid(rep, Player) then
				rep.FireServerListeners(Player, ...)
			end
		end)
		RemFunction.OnServerInvoke = function(Player, ...)
			if IsRequestValid(rep, Player) then
				local func = rep.ServerCallback
				if IsFunc(func) then
					return func(Player, ...)
				else
					return nil
				end
			else
				return nil
			end
		end
	else
		RemEvent, RemFunction = GetReplicatorRemotes(id)
		
		RemEvent.OnClientEvent:Connect(rep.FireClientListeners)
		RemFunction.OnClientInvoke = function(...)
			local func = rep.ClientCallback
			if IsFunc(func) then
				return func(...)
			end
		end
	end
	
	-- Events will be disconnected once the remotes get destroyed
end

local function DeleteReplicator(id)
	-- Destroy replicator remotes
	local Event, Func = GetReplicatorRemotes(id)
	if Event ~= nil then
		Event:Destroy()
	end
	if Func ~= nil then
		Func:Destroy()
	end
	Event, Func = nil, nil
end

-- IsReturning = true means RemoteFunction, otherwise,
-- it means RemoteEvent
local function FireReplicatorCallbacks(IsReturning, Id, ...)
	if BaseReplicator ~= nil then
		-- Get remotes.
		local RemEvent, RemFunction = GetReplicatorRemotes(Id)
		if RemEvent ~= nil and RemFunction ~= nil then
			local Remotes = {
				Event = RemEvent,
				Function = RemFunction
			}
			RemEvent, RemFunction = nil, nil

			-- Fire the callback.
			if IsReturning == true then
				local remote = Remotes.Function
				if remote ~= nil then
					if RunService:IsServer() then
						local Args = {...}
						local Player = Args[1]

						if IsPlayer(Player) then
							table.remove(Args, 1) -- Remove the player from the sent arguments.
							local Success, Result = pcall(function()
								return remote:InvokeClient(Player, Id, table.unpack(Args))
							end)

							-- If the client errors the request, assume they are
							-- exploiting, so kick them.
							if Success ~= true and CLIENT_INVOKE_KICKING then
								Player:Kick("no")
							end

							return Result
						end
					else
						return remote:InvokeServer(...)
					end
				end
			else
				local remote = Remotes.Event
				if remote ~= nil then
					if RunService:IsServer() then
						remote:FireClient(...)
					else
						remote:FireServer(...)
					end
				end
			end
		end
	end
end

-- Splits the player argument from the rest of the table,
-- then returns the result as two values.
local function SplitPlayerArgument(Args)
	if typeof(PLAYER_ARGUMENT_INDEX) == "number" then
		local Player = Args[PLAYER_ARGUMENT_INDEX]
		table.remove(Args, PLAYER_ARGUMENT_INDEX)
		
		return Player, Args
	end
end

-- Toggles internal instance event connections.
local function ToggleEvents(Enabled)
	local Remotes = GetGlobal("Remotes")

	if Remotes ~= nil then
		local RemoteEvent = Remotes.RemoteEvent
		local RemoteFunction = Remotes.RemoteFunction

		if RunService:IsServer() then
			Connections.ServerEvent = RemoteEvent.OnServerEvent:Connect(function(Player, Id, ...)
				local Replicators = GetGlobal("Replicators")
				if Replicators ~= nil then
					local Rep = Replicators[Id]
					if Rep ~= nil then
						if IsRequestValid(Rep, Player) == true then
							-- Fire replicator listeners.
							BaseReplicator.FireListeners(Player, ...)
						end
					else
						return
					end
				end
			end)
		else
			Connections.ClientEvent = RemoteEvent.OnClientEvent:Connect(function(Id, ...)
				local Replicators = GetGlobal("Replicators")
				if Replicators ~= nil then
					local Rep = Replicators[Id]
					if Rep ~= nil then
						BaseReplicator.FireListeners(...)
					else
						return
					end
				end
			end)
		end
	end
end

local function DoListenerFuncCheck(id, f)
	assert(id ~= nil, "Argument #1 cannot be nil.")
	assert(typeof(f) == "function", "Argument #2 must be a function.")
end

local function DoesReplicatorExist(Id)
	return GetGlobal("Replicators")[Id] ~= nil
end

-- Returns the server-side variant of the Replicator specified.
-- It will contain all the security properties and functions.
local function GetServerVariant(Rep)
	DoIsServerCheck()
	
	local Id = Rep.Id
	local Whitelisted = {} -- Whitelisted players.
	local Cooldown = {} -- Players on send cooldown.
	
	Rep.ServerListeners = {}
	
	Rep.IsServerVariant = true
	
	-- Sets if future sends/requests from clients go through
	-- a player UserId whitelist.
	-- If this is true and an unauthorized client sends a request,
	-- they are kicked if SECURITY_KICKING_ENABLED is true.
	Rep.UsesWhitelist = true

	-- Determines if only sending data to clients is permitted.
	-- If this and KickingEnabled are both set to true,
	-- clients that send requests will be kicked.
	Rep.ServerUseOnly = false

	-- Sets if kicking a player is enabled when they send a
	-- request invalidly.
	Rep.KickingEnabled = false
	
	-- Cooldown period between each client-to-server request in seconds.
	Rep.CooldownTime = 0
	
	-- The callback used for Obj.Request() on the server.
	-- Type: function(...)
	Rep.ServerCallback = nil
	
	-- If the 
	
	-- Returns if the player passes the security checks.
	local function PassesChecks(Player)
		return Rep.IsWhitelisted(Player) and Rep.IsOnCooldown(Player) == false
	end

	-- Adds a player to the cooldown.
	local function AddPlayerToCooldown(Player)
		local Time = Rep.CooldownTime

		if typeof(Time) == "number" and Time > 0 then
			coroutine.wrap(function()
				-- Cooldown the player.
				Cooldown[Player] = true

				-- Wait.
				local Elapsed = 0
				while Cooldown ~= nil and Elapsed < Time do
					Elapsed += RunService.Heartbeat:Wait()
				end

				if Cooldown ~= nil then -- In case Dispose() was done before time is up.
					Cooldown[Player] = nil -- Take the player off the cooldown.
				end
			end)()
		end
	end
	
	-- Adds a server listener
	function Rep.AddServerListener(f)
		DoIsServerCheck()
		
		if IsFunc(f) then
			Rep.ServerListeners[f] = f
		end
	end
	
	-- Removes a server listener.
	function Rep.RemoveServerListener(f)
		Rep.ServerListeners[f] = nil
	end
	
	-- Clears all server remote listeners.
	function Rep.ClearServerListeners()
		Rep.ServerListeners = {}
	end
	
	-- Adds a player to the whitelist.
	function Rep.AddToWhitelist(Player)
		assert(IsPlayer(Player), "Argument 1 must be a Player instance.")
		
		Whitelisted[Player.UserId] = true
	end
	
	-- Removes a player from the whitelist.
	function Rep.RemoveFromWhitelist(Player)
		assert(IsPlayer(Player), "Argument 1 must be a Player instance.")
		
		Whitelisted[Player.UserId] = nil
	end
	
	-- Clears the stored player whitelist.
	function Rep.ClearWhitelist()
		for i, v in pairs(Whitelisted) do
			Rep.RemoveFromWhitelist(v)
		end
	end
	
	-- Fires all of the replicator's server listeners.
	function Rep.FireServerListeners(Player, ...)
		if IsPlayer(Player) == true then
			AddPlayerToCooldown(Player)
			
			local Listeners = Rep.ServerListeners

			if typeof(Listeners) == "table" then
				for i, v in pairs(Listeners) do
					if typeof(v) == "function" then
						-- Call the listener.
						v(Player, ...)
					end
				end
			end

			Listeners = nil
		end
	end
	
	-- Rep.Send for server-side usage.
	function Rep.SendToClient(Player, ...)
		DoIsServerCheck()
		Rep.Send(Player, ...)
	end
	
	-- Returns true if the player is whitelisted or if
	-- whitelisting isn't in use.
	function Rep.IsWhitelisted(Player)
		return Rep.UsesWhitelist == false or Whitelisted[Player] == true
	end
	
	-- Returns true if the specified player isn't in the cooldown.
	function Rep.IsOnCooldown(Player)
		return Cooldown[Player] ~= nil
	end
	
	-- Server disposal callback.
	Rep.OnDisposal = function()
		Whitelisted = nil
		Cooldown = nil

		if RunService:IsServer() then
			DeleteReplicator(Id)
		end
		
		Id = nil
	end
	
	return Rep
end

-- Initalization function.
local function Initialize()
	assert(RunService:IsServer(), "Lol nope")
	
	-- Initialize the table.
	ToggleGlobalTable(true)

	if _G[GLOBAL_INDICATOR].IsInitialized == nil then
		SetGlobal("IsInitialized", true)
		_G[GLOBAL_INDICATOR].Replicators = {}

		-- Create instances.
		RemoteFolder = Util.CreateInstance("Folder", {
			Name = GLOBAL_INDICATOR,
			Parent = script
		})

		--local RemoteEvent = Util.CreateInstance("RemoteEvent", {
		--	Name = GLOBAL_INDICATOR .. "RemEvent",
		--	Parent = RemoteFolder
		--})

		--local RemoteFunction = Util.CreateInstance("RemoteFunction", {
		--	Name = GLOBAL_INDICATOR .. "RemFunction",
		--	Parent = RemoteFolder
		--})
		
		SetGlobal("RemotesFolder", RemoteFolder)
		
		--local Remotes = {}
		--Remotes.Event = RemoteEvent
		--Remotes.Function = RemoteFunction
		--RemoteEvent, RemoteFunction = nil, nil

		--SetGlobal("Remotes", Remotes)
		--SetGlobal("Whitelist", {})
	end
end

if RunService:IsServer() then
	Initialize()
end
--ToggleEvents(true)

-- Wrapper for determining if the script context is on the server.
function BaseReplicator.IsServer()
	return RunService:IsServer()
end

-- Constructs a new Replicator.
-- Its functions take advantage of script context.
function BaseReplicator.New(Id)
	--assert(RunService:IsServer(), "Replicators can only be constructed from the server.")
	assert(typeof(Id) == "string", "Argument #1 must be a string.")
	
	--if RunService:IsServer() == true then
	--	assert(DoesReplicatorExist(Id) == false, "Replicator '" .. Id "' has already been initalized from the server.")
	--end

	local Obj = Object.New("Replicator")
	
	Obj.ClientListeners = {}
	
	Obj.IsServerVariant = false
	Obj.Id = Id

	-- Adds a remote listener executed on the client.
	-- Parameters:
	-- f (function) - the function to bind
	function Obj.AddClientListener(f)
		if IsFunc(f) then
			Obj.ClientListeners[f] = f
		end
	end

	-- Removes a remote listener from being executed on the client.
	-- Adds a remote listener.
	-- Parameters:
	-- f (function) - the function to bind
	function Obj.RemoveClientListener(f)
		Obj.ClientListeners[f] = nil
	end
	
	-- Clears all client remote listeners.
	function Obj.ClearClientListeners()
		Obj.ClientListeners = {}
	end

	-- The callback used for Obj.Request() on the client.
	-- Type: function(...)
	Obj.ClientCallback = nil

	-- Sends data to the other end of the server/client boundary.
	-- Works like the RemoteEvent.
	function Obj.Send(...)
		FireReplicatorCallbacks(false, Id, ...)
	end

	-- Requests data from the other end of the server/client boundary
	-- and then returns it.
	--
	-- Works like the RemoteFunction.
	function Obj.Request(...)
		return FireReplicatorCallbacks(true, Id, ...)
	end
	
	-- Fires the replicator's remote function callback.
	function Obj.FireFuncCallback(Receiver, ...)
		local Callback = Obj.RequestCallback
		
		if typeof(Callback) == "function" then
			Callback(...)
		end
		
		Callback = nil
	end
	
	-- Fires all of the replicator's client listeners.
	function Obj.FireClientListeners(...)
		local Listeners = Obj.ClientListeners

		if typeof(Listeners) == "table" then
			for i, v in pairs(Listeners) do
				if typeof(v) == "function" then
					-- Call the listener.
					v(...)
				end
			end
		end

		Listeners = nil
	end
	
	-- Initialize replicator remotes.
	AddReplicator(Id, Obj)
	
	if RunService:IsServer() == true then
		-- See GetServerVariant for doc stuff.
		return GetServerVariant(Obj)
	else
		return Obj
	end
end

-- Returns a replicator by id. If it doesn't exist,
-- this will create a replicator if called from
-- the server, otherwise, it will return nil.
-- This returns two things, the replicator if it
-- exists and if it was just created by this function.
function BaseReplicator.GetReplicator(Id)
	DoIsServerCheck()
	assert(typeof(Id) == "string", "Argument #1 must be a string.")

	local Replicators = GetGlobal("Replicators")
	if Replicators ~= nil then
		local Rep = Replicators[Id]
		local JustCreated = false

		if Rep == nil then
			if RunService:IsServer() == true then
				-- Create if non-existent
				JustCreated = true
				Rep = BaseReplicator.New(Id)
			end
		end
		
		-- Return the replicator.
		return Rep, JustCreated
	else
		return nil
	end
end

return BaseReplicator