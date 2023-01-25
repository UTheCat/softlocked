-- Provides an object collects instances by their names.
-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))

local InstanceCollector = {}

local function GetArrayFromMap(Map)
	local Array = {}
	for i, v in pairs(Map) do
		table.insert(Array, v)
	end
	
	return Array
end

function InstanceCollector.New(SearchId)
	local Obj = Object.New("InstanceCollector")
	local AdaptedInst = nil -- The adapted instance.
	local AdaptConnections = {}
	
	-- The collection of instances. For sync safety,
	-- this is in key-value pairs.
	Obj.Instances = {}
	
	-- If the collector is looking for new instances.
	-- If an instance is found while this is false,
	-- it won't be added to the collection, nor
	-- will InstanceFound invoke itself for the
	-- found instance.
	Obj.IsLooking = true
	
	-- The part to look for when adding an instance
	-- to the collection. by its name.
	-- This is applied on the next refresh.
	Obj.SearchId = SearchId or ""
	
	local function MatchesId(inst)
		local Id = Obj.SearchId
		assert(typeof(Id) == "string", "The SearchId must be a string.")
		
		return typeof(inst) == "Instance" and string.match(inst.Name, Id)
	end
	
	-- Handles a found instance.
	local function HandleInstance(inst)
		if Obj.IsLooking == true then
			local Id = Obj.SearchId
			assert(typeof(Id) == "string", "The SearchId must be a string.")

			if Obj.Instances ~= nil then -- Just in case
				if MatchesId(inst) then
					-- Add to the collection
					Obj.Instances[inst] = inst

					-- Indicate collection finding.
					Object.FireCallback(Obj.InstanceFound, inst)

					-- Fire the collection callback.
					Object.FireCallback(Obj.CollectionChanged, GetArrayFromMap(Obj.Instances))
				end
			else
				return
			end
		end
	end
	
	local function DisconnectInstConnections()
		for i, v in pairs(AdaptConnections) do
			if typeof(v) == "RBXScriptConnection" then
				v:Disconnect()
			end
		end
		
		AdaptConnections = {}
	end
	
	-- Internally looks for the instances with the provided id.
	local function Search()
		DisconnectInstConnections() -- Just in case
		
		if typeof(AdaptedInst) == "Instance" then
			for i, v in pairs(AdaptedInst:GetDescendants()) do
				if MatchesId(v) then
					HandleInstance(v)
				end
			end
			
			AdaptConnections = {
				Add = AdaptedInst.DescendantAdded:Connect(HandleInstance),
				Remove = AdaptedInst.DescendantRemoving:Connect(function(inst)
					-- Indicate removal if the instance was in the collection.
					if typeof(Obj.Instances[inst]) == "Instance" then
						Object.FireCallback(Obj.InstanceRemoved, inst)
					end
					
					Obj.Instances[inst] = nil
				end)
			}
		end
	end
	
	-- Refreshes the collection.
	function Obj.Search()
		Search()
	end
	
	-- Sets the collector to look for instances that are the
	-- descendants of the provided instance.
	-- Parameters:
	-- Inst - The instance to adapt to. If this argument isn't an Instance,
	--		  the collection is cleared.
	function Obj.AdaptInstance(Inst)
		if typeof(Inst) == "Instance" then
			AdaptedInst = Inst
			Search()
		else
			DisconnectInstConnections()
			Obj.Instances = {}
		end
	end
	
	-- Fires when the collection changes.
	-- Parameters:
	-- Collection (table) - The array of instances in the collection.
	Obj.CollectionChanged = nil
	
	-- Fires when an instance has been found, therefore
	-- being added to the collection.
	-- Parameters:
	-- Inst (instance) - The instance found.
	Obj.InstanceFound = nil
	
	-- Fires when an instance in the collection is no longer a
	-- descendant of the adapted instance set using AdaptInstance().
	-- Parameters:
	-- Inst (instance) - The instance removed.
	Obj.InstanceRemoved = nil
	
	Obj.OnDisposal = function()
		DisconnectInstConnections()
		AdaptConnections = nil
	end
	
	return Obj
end

return InstanceCollector