--[[
A basic module used to replicate stuff.
Similar to Replica by DataBrain.

Each replicator is referenced by instance name.

The BaseReplicator is basically for security in
client-to-server requests. The class is meant to
be extended by other modules via a subclass.

Rewritten to be much more simple.

The BaseReplicator.GetCurrentTime() function is used for time-sensitive stuff 
to clog the task scheduler the least possible and because
it always uses UTC time.

Timestamps sent by the client are no longer used by the server because
they can be easily be spoofed on platforms like Android without closing
the session

The client's time could also be significantly ahead of the server's,
so don't make checks based on that either

Made by udev2192
]]--

--[[
The name of the remotes folder.
]]--
local REMOTES_FOLDER_NAME = "Remotes"

--[[
The name of the class that does the actual replication.
]]--
local REPLICATION_CLASS_NAME = "RemoteEvent"

--[[
The name of the instance attribute that specifies
a server-set cooldown.
]]--
local COOLDOWN_ATTRIBUTE_NAME = "Cooldown"

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

ReplicatedStorage, RepModules, UtilRepModules = nil

-- do not add "!strict" to the top of this module (otherwise, studio will crash)
type ErrorTable = {Id: number, Message: string}

local BaseReplicator = {}
BaseReplicator.__index = BaseReplicator
BaseReplicator.ClassName = script.Name

--[[
<table> - Numbers for specifying response timeout in milliseconds.
]]--
BaseReplicator.TimeoutValues = {
	NoTimeout = 0,
	Optimal = 5000
}

--[[
<table> - Received message types (for RemoteEvent handling).
		  This is for internal use only.
]]--
BaseReplicator.MessageType = {
	-- Sent as a request
	Request = 0,

	-- Sent as a response from a request
	Response = 1,

	-- Sent as an event (with no response expected)
	Event = 2
}

--[[
Creates a possible error.

Params:
Id <number> - The numerical id of the error
Message <string> - The error message

Returns:
<table> - The created error table ([parameter name] = value)
]]--
function BaseReplicator.CreateError(Id: number, Message: string)
	assert(typeof(Id) == "number", "Argument 1 must be a number.")
	assert(typeof(Message) == "string", "Argument 2 must be a string.")

	return {
		Id = Id,
		Message = Message
	}
end

--[[
Returns:
<table> - The table holding the Signal class.
]]--
function BaseReplicator.GetSignalClass()
	return Signal
end

--[[
<table> - Error messages that may pop-up during a request.
		  Errors aren't limited to the ones provided in this table
		  (for example, an error could occur because of the code
		  or something else).
		  
		  See BaseReplicator.CreateError() for more info.
]]--
BaseReplicator.Errors = {
	Closed = BaseReplicator.CreateError(1, "Requests to the server may have been closed off."),
	Timeout = BaseReplicator.CreateError(2, "Request couldn't be returned before the specified time ran out."),
	Unauthorized = BaseReplicator.CreateError(3, "This request has been denied."),
	Cooldown = BaseReplicator.CreateError(4, "Can't send request while on cooldown"),
	Prevented = BaseReplicator.CreateError(5, "Can't send a request at this time"),
	ZeroTimeout = BaseReplicator.CreateError(6, "Can't send the request because the timeout is set at 0 ms."),
	InvalidTime = BaseReplicator.CreateError(7, "Time format is invalid"),
	InvalidFormat = BaseReplicator.CreateError(8, "Request format is invalid"),
	Blank = BaseReplicator.CreateError(9, "Request is blank"),
	Cancelled = BaseReplicator.CreateError(10, "Request was cancelled"),
	InvalidRequestId = BaseReplicator.CreateError(11, "Request identifier is invalid, or isn't a number."),
	MissingLocation = BaseReplicator.CreateError(12, "The folder housing the remote couldn't be found."),
	Unknown = BaseReplicator.CreateError(13, "Request failed due to an unknown error.")
}

function BaseReplicator.AssertServer()
	assert(RunService:IsServer(), "This action can only be performed from the server.")
end

local function IsFunc(f)
	return f == nil or typeof(f) == "function"
end

local function DoFuncCheck(f)
	assert(f == nil or IsFunc(f), "Property must be a function or nil.")
end

local function IsResponse(MessageType, Response)
	return MessageType == BaseReplicator.MessageType.Response and typeof(Response) == "table"
end

local RemotesFolder

--[[
Initializes BaseReplicator so that it's able to function.
]]--
function BaseReplicator.Enable()
	if RunService:IsServer() then
		RemotesFolder = script:FindFirstChild(REMOTES_FOLDER_NAME)
	else
		RemotesFolder = script:WaitForChild(REMOTES_FOLDER_NAME)
	end

	if RemotesFolder == nil then
		if RunService:IsServer() then
			RemotesFolder = Util.CreateInstance("Folder", {
				Name = REMOTES_FOLDER_NAME,
				Parent = script
			})
		else
			RemotesFolder = nil
			warn("Couldn't find the remotes folder which is needed for", BaseReplicator.ClassName, "to work.")
		end
	end
end

BaseReplicator.Enable()

function BaseReplicator.IsServer()
	return RunService:IsServer()
end

--[[
Returns:
<number> - The current timestamp in milliseconds.
]]--
function BaseReplicator.GetCurrentTime()
	return DateTime.now().UnixTimestampMillis
end

--[[
Creates a dictionary request via the following parameters
(table keys are named after the parameters).

Creating the response with this function is for the sake of
type constraining and not having to.

Params:
RequestId <number> - The identification number of the request
ShouldRespond <boolean> - If a response is expected
TimeSent <number> - When the request was sent in millisecond time.
... <variant> - The arguments to send.

Returns:
<table> - The table created with the following data:
	RequestId <number> - See params
	ShouldRespond <boolean> - See params
	TimeSent <number> - When the request was sent.
	Args <table> - The request arguments in an array.
]]--
function BaseReplicator.CreateRequestParams(RequestId: number, ShouldRespond: boolean, TimeSent: number?, ...: any)
	assert(typeof(RequestId) == "number", "Request identification number (arg #1) is required.")
	assert(typeof(ShouldRespond) == "boolean", "Please specify whether or not a response is expected as a boolean (arg #2).")

	if typeof(TimeSent) ~= "number" then
		TimeSent = nil
	end

	return {
		RequestId = RequestId,
		ShouldRespond = ShouldRespond,
		TimeSent = TimeSent,
		Args = table.pack(...)
	}
end

--[[
Creates a dictionary response via the following parameters
(table keys are named after the parameters).

Creating the response with this function is for the sake of
type constraining and not having to.

The table returned will also have a value called "Ping"
that describes the estimated latency in milliseconds

Params:
RequestId <number> - The request id to send back. This should use the value
					 from the corresponding RequestParams.
TimeSent <number?> - When the corresponding request was sent in millisecond timestamp.
Error <table?> - A table describing the error that occurred
						or nil if no error happened (see BaseReplicator.CreateError() for
						more info).

Data <... any> - The data arguments in the response. Can be any value.

Returns:
<table> - The table created.
]]--
function BaseReplicator.CreateResponse(RequestId: number, TimeSent: number?, Error: ErrorTable, ...: any)
	assert(typeof(RequestId) == "number", "Request identification number (arg #1) is required.")

	if typeof(TimeSent) ~= "number" then
		TimeSent = nil--BaseReplicator.GetCurrentTime()
	end

	if typeof(Error) ~= "table" then
		Error = nil
	end

	return {
		TimeSent = TimeSent,
		Error = Error,
		RequestId = RequestId,
		Data = table.pack(...)
	}
end

-- Constructor
function BaseReplicator.New(Id: string)
	assert(typeof(Id) == "string", "Argument 1 must be a string.")

	local Rep = Object.New(BaseReplicator.ClassName)

	-- RequestIds that are waiting for a response
	local ActiveRequests = {}

	local ServerRespondConnection
	local ClientRespondConnection

	local MainClientReceiver

	Rep.Name = Id

	Id = nil

	--[[
	<number> - How long to wait for a response before cancelling
			   the corresponding request (in milliseconds).
			   Set to 0 for no timeout.
	]]--
	Rep.Timeout = BaseReplicator.TimeoutValues.NoTimeout

	--[[
	<number> - Millisecond timestamp when the last request was sent.
	]]--
	Rep.LastSentAt = 0
	
	--[[
	<number> - The remaining cooldown wait in seconds
	]]--
	Rep.CooldownRemaining = 0
	
	--[[
	<boolean> - Whether or not the current device will wait until the cooldown
				has expired before sending another request		.
				This timer starts right after sending the request
	]]--
	Rep.AutoCooldownWaitEnabled = true
	
	--[[
	<boolean> - Whether or not the cooldown timer is active for the current device
	]]--
	Rep.IsCooldownActive = false

	-- Function for using the corresponding callback.
	local function UseCallback(RequestParams, ...)
		local Callback

		if RunService:IsServer() then
			Callback = Rep.ServerCallback
		else
			Callback = Rep.ClientCallback
		end

		if Callback ~= nil then
			return Callback(RequestParams, ...)
		end

		return nil
	end
	
	--[[
	Starts the request cooldown timer
	
	Params:
	Cooldown <number> - The cooldown period
	]]--
	function Rep.WaitForCooldown(Cooldown: number)
		Rep.CooldownRemaining = Cooldown
		
		if Cooldown > 0 then
			Rep.IsCooldownActive = true
			--print("start cooldown", Rep.CooldownRemaining)
			
			while Rep.CooldownRemaining > 0 do
				--print("cooldown remaining", Rep.CooldownRemaining)
				Rep.CooldownRemaining = math.max(Rep.CooldownRemaining - task.wait(), 0)
			end
			
			--print("cooldown end", Rep.CooldownRemaining)
		end
		
		Rep.IsCooldownActive = false
	end

	--[[
	Returns:
	<table> - A dictionary of information regarding whether a
			  request across the server-client boundary can be made.
			  Contents include:
			  
			  CanSend <boolean>: Whether or not a request can be made based on
			  					 two factors: cooldown and remote presence.
			  
			  Time <number>: Millisecond timestamp that the inquiry was made on.
			  
			  Container <Folder>: The folder instance containing the replication
			  				   	  instance(s) and the cooldown attribute.
			  
			  Remote <RemoteEvent>: The actual remote that will be doing the
			  						replication (should be inside the folder).
			  				   	  
	]]--
	function Rep.CanSendRequest()
		local CurrentTime = BaseReplicator.GetCurrentTime()

		local Response = {
			Time = CurrentTime,

			-- Cooldown time remaining in milliseconds
			CooldownRemaining = 0,

			-- Total cooldown time specified by the server in milliseconds
			CooldownTime = 0
		}

		local IsSendable = false
		local ErrorMessage = nil

		local Name = Rep.Name
		local Folder = RemotesFolder:FindFirstChild(Name)
		if Name ~= nil and Folder ~= nil then
			Response.Container = Folder

			-- Get the cooldown
			local Cooldown
			if RunService:IsServer() then
				Cooldown = Rep.CooldownTime
			else
				Cooldown = Folder:GetAttribute(COOLDOWN_ATTRIBUTE_NAME)
			end
			Rep.CooldownTime = Cooldown

			local Remote = Folder:FindFirstChildOfClass(REPLICATION_CLASS_NAME)
			if Remote ~= nil then
				Response.Remote = Remote

				-- Use greater than, just to stay safe
				local LastSentAt = Rep.LastSentAt

				if Cooldown ~= nil then					
					if RunService:IsServer() or Cooldown == 0 or (Rep.IsCooldownActive == false and Rep.CooldownRemaining <= 0) then
						IsSendable = true
					else
						--Response.CooldownRemaining = math.max(CurrentTime - LastSentAt, 0)
						ErrorMessage = BaseReplicator.Errors.Cooldown
					end
				else
					warn("Cannot send request, no cooldown was provided.")
				end
			else
				ErrorMessage = BaseReplicator.Errors.Closed
			end
		else
			ErrorMessage = BaseReplicator.Errors.Closed
		end

		Response.CanSend = IsSendable
		Response.Error = ErrorMessage

		return Response
	end

	--[[
		<function> - The callback used whenever an error occurs
					 after a request was sent.
					 
		Callback params:
		Player <Player> - The player instance that sent the request which
						  resulted in an error. If the request isn't from
						  a client, this argument is nil.
		Error <table> - The error table. See BaseReplicator.CreateError() and BaseReplicator.Errors for
						more info
		RequestParams <table> - The request parameters. Please
								note that this isn't guaranteed to
								be a table (if it isn't,
								the BaseReplicator.InvalidFormat error
								is used).
	]]--
	Rep.SetProperty("OnError", nil, DoFuncCheck)

	--[[
	Fires the error callback.
	
	Parameters are the same as those for the OnError callback.
	]]--
	function Rep.Error(Player: Player, Error: ErrorTable, RequestParams)
		local OnError = Rep.OnError
		if OnError then
			OnError(Player, Error, RequestParams)
		end
	end

	-- Make sure the player object passed here is a player or nil
	local function HandleRequest(RequestParams: {}, Player: Player?, Remote: RemoteEvent)
		local SendError

		-- Do sanity checks for argument types and sending time
		if typeof(RequestParams) == "table" then
			local RequestId = RequestParams.RequestId

			if typeof(RequestId) == "number" then
				local IsTimeValid
				local TimeSent
				local IsServer = RunService:IsServer()
				if RunService:IsClient() then
					TimeSent = RequestParams.TimeSent
					IsTimeValid = typeof(TimeSent) == "number"
				elseif IsServer then
					-- Don't check client-sent time
					IsTimeValid = true
				else
					IsTimeValid = false
				end
				
				if IsTimeValid then
					local Args = RequestParams.Args

					if typeof(Args) == "table" then
						--RequestParams.ReceiveTime = CurrentTime
						Rep.RequestReceived.Fire(Player, RequestParams)

						-- Handle a requested response if told to do so
						local ShouldRespond = RequestParams.ShouldRespond
						if typeof(ShouldRespond) == "boolean" then
							if ShouldRespond == true then
								local Data = UseCallback(Player, RequestParams, table.unpack(Args))
								local MessageRespond = BaseReplicator.MessageType.Response

								if IsServer then
									Remote:FireClient(
										Player,
										MessageRespond,
										BaseReplicator.CreateResponse(
											RequestId,
											TimeSent,
											nil,
											Data
										)
									)
								else
									Remote:FireServer(
										MessageRespond,
										BaseReplicator.CreateResponse(
											RequestId,
											nil,--TimeSent,
											nil,
											Data
										)
									)
								end

								return
							end
						else
							SendError = BaseReplicator.Errors.InvalidFormat
						end
					else
						SendError = BaseReplicator.Errors.InvalidFormat
					end
				else
					SendError = BaseReplicator.Errors.InvalidTime
				end
			else
				SendError = BaseReplicator.Errors.InvalidRequestId
			end
		else
			SendError = BaseReplicator.Errors.InvalidFormat
		end

		-- If there's an error, pass it to the callback
		if SendError then
			Rep.Error(Player, SendError, RequestParams)
		end
	end

	--[[
	Server only stuff.
	
	Anything here is only accessible from the server.
	]]--
	if RunService:IsServer() then
		local IsOpen = false

		--[[
		<table> - Whitelisted player IDs
		]]--
		local Whitelist = {}

		--[[
		<table> - Player IDs on cooldown
		]]--
		local PlayerCooldown = {}

		local MainServerReceiver

		--[[
		<boolean> - If the player id whitelist is being used.
		]]--
		Rep.UsePlayerWhitelist = true

		local function GetContainer()
			return Rep.CanSendRequest().Container
		end

		--[[
		<number> - The duration in milliseconds that players have
			       to wait before sending another request.
			       This number only applies on the server for
			       security reasons.
		]]--
		Rep.SetProperty("CooldownTime", 0, function(NewCooldown)
			BaseReplicator.AssertServer()

			-- Try to set the attribute on the container
			local Container = GetContainer()
			if Container ~= nil then
				Container:SetAttribute(COOLDOWN_ATTRIBUTE_NAME, NewCooldown or 0)
			end

			Container = nil
		end)

		--[[
		<function> - The callback set for the server
				   	 (or nil if there isn't one).
				   	 
		Callback params:
		Player <Player> - The player instance that sent the request
		RequestParams <table> - The request parameters table.
								See BaseReplicator.CreateRequestParams()
								for more info.
		... <variant> - The developer-defined arguments.
		]]--
		Rep.SetProperty("ServerCallback", nil, function(f)
			BaseReplicator.AssertServer()
			DoFuncCheck(f)
		end)

		--[[
		Adds a player's user id to the cooldown.
		
		Params:
		UserId <number> - The user id to place on the cooldown.
		]]--
		function Rep.AddToCooldown(UserId)
			local Cooldown = Rep.CooldownTime

			-- Initially check if a cooldown is needed
			-- by seeing if the cooldown is greater than 0 ms
			-- and that the user id isn't already cooling down
			if Cooldown ~= nil and table.find(PlayerCooldown, UserId) == nil then
				table.insert(PlayerCooldown, UserId)

				task.delay(Cooldown / 1000, function()
					local Index = table.find(PlayerCooldown, UserId)
					if Index ~= nil then
						table.remove(PlayerCooldown, Index)
					end
				end)
			end
		end

		--[[
		Removes a user id from the whitelist.
		
		Params:
		Id <number> - The user id to remove.
		]]--
		function Rep.RemoveFromWhitelist(Id)
			local Index = table.find(Whitelist, Id)

			if Index ~= nil then
				table.remove(Whitelist, Index)
			end
		end

		--[[
		Adds a user id to the whitelist.
		
		Params:
		Id <number> - The user id to add.
		]]--
		function Rep.AddToWhitelist(Id)
			table.insert(Whitelist, Id)
		end

		--[[
		Disconnects the remote event receiver and destroys it.
		]]--
		function Rep.Close()
			BaseReplicator.AssertServer()

			IsOpen = false

			local Container = GetContainer()
			if Container ~= nil then
				Container:Destroy()
				Container = nil
			end

			if MainServerReceiver ~= nil then
				MainServerReceiver:Disconnect()
				MainServerReceiver = nil
			end
		end

		--[[
		Connects a listener to a server handling and
		creates the instances needed for replication.
		]]--
		function Rep.Open()
			BaseReplicator.AssertServer()

			if IsOpen == false then
				local Container = Instance.new("Folder")
				Container.Name = Rep.Name
				Container:SetAttribute(COOLDOWN_ATTRIBUTE_NAME, Rep.CooldownTime)

				local Remote = Instance.new(REPLICATION_CLASS_NAME)

				--[[
				<function> - The server listener. This is where
							 the security is handled.
				]]--
				MainServerReceiver = Remote.OnServerEvent:Connect(function(Player, MessageType, RequestParams)
					local UserId = Player.UserId
					local Errors = BaseReplicator.Errors
					local SendError

					if (Rep.UsePlayerWhitelist == false or table.find(Whitelist, UserId)) then
						if table.find(PlayerCooldown, UserId) == nil then
							if MessageType == BaseReplicator.MessageType.Request then
								Rep.AddToCooldown(UserId)
								HandleRequest(RequestParams, Player, Remote)
							end							
						else
							SendError = Errors.Cooldown
						end
					else
						SendError = Errors.Unauthorized
					end

					if SendError then
						Rep.Error(Player, SendError, RequestParams)
					end

					--UserId = nil

					-- Use the error callback if one happened
					-- The error is not passed back to avoid
					-- crashing via data sending by default
					--if SendError ~= nil then
					--	local OnError = Rep.OnError

					--	if OnError ~= nil then
					--		if RequestParams ~= nil then

					--		end

					--		OnError(Player, SendError, RequestParams)
					--	end
					--end
				end)

				Remote.Parent = Container
				Container.Parent = RemotesFolder

				Container = nil
			end

			IsOpen = true
		end
	end

	--[[
	<function> - The callback set for the client
				 (or nil if there isn't one).
				 
	Callback params:
	RequestParams <table> - The request parameters table.
							See BaseReplicator.CreateRequestParams()
							for more info.
	... <variant> - The developer-defined arguments.
	]]--
	Rep.SetProperty("ClientCallback", nil, DoFuncCheck)

	--[[
	Closes the main client listener needed for messages
	sent to the client.
	]]--
	function Rep.CloseClient()
		if MainClientReceiver ~= nil then
			MainClientReceiver:Disconnect()
			MainClientReceiver = nil
		end
	end

	--[[
	Opens the main client listener needed for messages
	sent to the client.
	]]--
	function Rep.OpenClient()
		if MainClientReceiver == nil then
			local Remote = Rep.CanSendRequest().Remote

			if Remote then
				MainClientReceiver = Remote.OnClientEvent:Connect(function(MessageType, RequestParams)
					if MessageType == BaseReplicator.MessageType.Request then
						HandleRequest(RequestParams, nil, Remote)
					end
				end)
			end
		end
	end

	--[[
	Returns true if the specified request id is active (waiting for a response),
	or false if not.
	
	Params:
	RequestId <number> - The request id to check
	
	Returns:
	<boolean> - If the request id is active.
	]]--
	function Rep.IsRequestActive(RequestId)
		return table.find(ActiveRequests, RequestId) ~= nil
	end

	local function RemoveRequestId(RequestId: number)
		local Index = table.find(ActiveRequests, RequestId)

		if Index then
			table.remove(ActiveRequests, Index)
		end
	end

	--[[
	Cancels a request that expected a response.
	
	Params:
	RequestId <number> - The id of the request to cancel
	]]--
	function Rep.Cancel(RequestId: number)
		assert(typeof(RequestId) == "number", "Argument 1 must be a number.")

		RemoveRequestId(RequestId)

		Rep.ResponseReceived.Fire(
			BaseReplicator.CreateResponse(
				RequestId,
				BaseReplicator.GetCurrentTime(),
				BaseReplicator.Errors.Cancelled
			)
		)
	end

	--[[
	Cancels all requests that expected a response and
	notifies on each clear.
	]]--
	function Rep.CancelAll()
		--for i, v in ipairs(Connections) do
		--	Connections:Disconnect()
		--	table.remove(Connections, i)
		--end

		for i, v in pairs(ActiveRequests) do
			Rep.Cancel(v)
		end
	end

	local function DisconnectResponseRemote()
		if ServerRespondConnection then
			ServerRespondConnection:Disconnect()
			ServerRespondConnection = nil
		end

		if ClientRespondConnection then
			ClientRespondConnection:Disconnect()
			ClientRespondConnection = nil
		end
	end

	local function HandleResponse(Response)
		--if Connection ~= nil then
		--	Connection:Disconnect()
		--	Connection = nil

		--	local ConnectionIndex = table.find(Connections, Connection)
		--	if ConnectionIndex ~= nil then
		--		table.remove(Connections, ConnectionIndex)
		--	end
		--	ConnectionIndex = nil
		--end

		if typeof(Response) == "table" then
			local RequestId = Response.RequestId

			if typeof(RequestId) == "number" then -- Sanity check
				--local Index = table.find(ActiveRequests, RequestId)
				--if Index then
				--	table.remove(ActiveRequests, Index)
				--end
				RemoveRequestId(RequestId)

				-- Disconnect listener if there are no active requests left
				if #ActiveRequests <= 0 then
					DisconnectResponseRemote()
				end

				-- Fire response event
				--Response.ReceiveTime = BaseReplicator.GetCurrentTime()
				Rep.ResponseReceived.Fire(Response)
			end
		end
	end

	-- Adds a request id to the queue
	local function AddRequestId(RequestId: number)
		assert(Rep.IsRequestActive(RequestId) == false, "Request #" .. RequestId .. " is still active.")
		table.insert(ActiveRequests, RequestId)

		local Timeout = Rep.Timeout
		if Timeout > BaseReplicator.TimeoutValues.NoTimeout then
			Timeout /= 1000

			task.spawn(function()
				local Elapsed = 0

				while true do
					-- Drop the request once the cooldown expires
					if Elapsed > Timeout and Rep.IsRequestActive(RequestId) then
						-- Indicate that the timeout expired
						HandleResponse(
							BaseReplicator.CreateResponse(
								RequestId,
								BaseReplicator.GetCurrentTime(),
								BaseReplicator.Errors.Timeout
							)
						)

						break
					elseif Rep.IsRequestActive(RequestId) == false then
						break
					end

					Elapsed += task.wait()
				end
			end)
		end
	end

	local function ConnectResponseRemote(Remote: RemoteEvent)
		if RunService:IsServer() then
			if ServerRespondConnection == nil then
				ServerRespondConnection = Remote.OnServerEvent:Connect(function(Player, MsgType, Response)
					if IsResponse(MsgType, Response) then
						Response.Sender = Player

						HandleResponse(Response)
					end
				end)
			end
		else
			if ClientRespondConnection == nil then
				ClientRespondConnection = Remote.OnClientEvent:Connect(function(MsgType, Response)
					if IsResponse(MsgType, Response) then
						HandleResponse(Response)
					end
				end)
			end
		end
	end


	--[[
	Sends a request across the server-client boundary.
	
	Params:
	RequestParams <table> - A table of parameters to send made by CreateRequestParams()
	Player <Player?> - An argument used by the server to specify which player to send the
					   request to. Leave this as nil to send to all players.
	]]--
	function Rep.Request(RequestParams, Player: Player?)
		assert(typeof(RequestParams) == "table", "Argument 1 must be a table.")

		local RequestId: number = RequestParams.RequestId
		assert(typeof(RequestId) == "number", "RequestParams does not specify request identification number.")

		-- Make the request
		--local Timeout = Rep.Timeout / 1000
		local Inquiry = Rep.CanSendRequest()
		local SendTime = Inquiry.Time

		local Connection

		if Inquiry.CanSend == true then
			Rep.LastSentAt = SendTime

			-- Stuff used to send
			local Remote = Inquiry.Remote
			--local RequestParams = BaseReplicator.CreateRequestParams(SendTime, ...)
			local ResponseReceived = false

			-- If a response is expected, keep note of that
			if RequestParams.ShouldRespond == true then
				AddRequestId(RequestId)
				ConnectResponseRemote(Remote)
			end

			-- Listen for the first response received, then fire
			local MessageRequest = BaseReplicator.MessageType.Request
			if RunService:IsServer() then
				if Player then
					Remote:FireClient(Player, MessageRequest, RequestParams)
				else
					Remote:FireAllClients(MessageRequest, RequestParams)
				end
			else
				Remote:FireServer(MessageRequest, RequestParams)
			end
			
			Rep.IsCooldownActive = true
			task.spawn(Rep.WaitForCooldown, Rep.CooldownTime / 1000)
			--print("request sent", Rep.CooldownTime / 1000)

			return
		else
			-- Indicate the request being cancelled, as it's not ready
			-- to make one
			HandleResponse(
				BaseReplicator.CreateResponse(
					RequestParams.RequestId,
					Inquiry.Time,
					Inquiry.Error
				)
			)
		end
	end

	--[[
	Fired when a request has been received. Listeners binded
	to this signal do not affect the response returned
	by a Request() call.
	
	Params:
	Player <Player> - The player instance that sent the message.
					  If this isn't the server, 
					  this argument is nil.
	RequestParams <table> - The request parameters in a table.
	]]--
	Rep.RequestReceived = Signal.New()

	--[[
	Fired when a response has been received from a Request() call.
	
	Along with the keys from CreateResponse(), the response table
	passed here will also include:
	
	ReceiveTime <number> - The millisecond timestamp when the response
						   was received.
	
	Sender <Player> - If the response came from a client, this
					  describes the player instance that sent it,
					  nil if it didn't.
	
	Params:
	Response <table> - A response table generated by
					   BaseReplicator.CreateResponse()
	]]--
	Rep.ResponseReceived = Signal.New()

	Rep.OnDisposal = function()
		DisconnectResponseRemote()
		Rep.RequestReceived.DisconnectAll()
		Rep.ResponseReceived.DisconnectAll()

		Rep.CancelAll()

		if RunService:IsServer() then
			local CloseFunc = Rep.Close

			if CloseFunc ~= nil then
				CloseFunc()
			end

			CloseFunc = nil
		end
	end

	return Rep
end

return BaseReplicator