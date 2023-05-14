--[[
Zipline.lua by udev2192

Zipline class modified to be used by BaseInteractive
]]--

local ZiplineService = script.Parent.Parent:WaitForChild("ZiplineService")

local Object = require(ZiplineService:WaitForChild("Object"))
local ConfigDefaults = require(ZiplineService:WaitForChild("ConfigDefaults"))
local Display = require(ZiplineService:WaitForChild("Display"))

-- Calculation modules
local Bezier = require(ZiplineService:WaitForChild("Bezier"))
local Spline = require(ZiplineService:WaitForChild("Spline"))

local Zipline = {}

-- Attribute names
local DISPLAY_PRECISION_ATTRIBUTE = "DisplayPrecision"
local FORMULA_ATTRIBUTE = "GenerationMode"
local PATH_DISPLAYED_ATTRIBUTE = "DisplaysPath"
local PRECISION_ATTRIBUTE = "Precision"
local THICKNESS_ATTRIBUTE = "Thickness"

-- Multiplier for the part group size when using precision
-- as the variable.
local DISPLAY_PRECISION_MULTIPLIER = 0.3

local DISPLAY_PRECISION_MIN = 0.0001
local DISPLAY_PRECISION_MAX = 10

-- The name given to the start parts on ziplines.
Zipline.START_PART_COLLECTION = "CurvedZiplineMechanic1"

-- "Bezier" or "Spline"
-- Bezier = Faster generation
-- Spline = Accurate generation (currently broken, so don't use)
-- This is a beta flag that is no longer in use.
--Zipline.DEFAULT_GENERATION_MODE = "Bezier"

-- For smooth ziplining
-- (No longer used as this is a customizable option)
--Zipline.MAGNITUDE_MULTIPLIER = 60

-- Generation mode enum that specifies
-- the formula that a zipline uses to generate a zipline.
Zipline.GenerationMode = {
	Linear = 1,
	Quadratic = 2,
	Cubic = 3
}

-- Allows for better curve generation.
-- This has released so it is no longer a flag, rather
-- a toggleable option for each zipline.
--Zipline.ENABLE_CUBIC_GENERATION = false

function Zipline.GetCollection()
	local Collection = _G[Zipline.START_PART_COLLECTION]
	if Collection == nil then
		_G[Zipline.START_PART_COLLECTION] = {}
	end
	
	return _G[Zipline.START_PART_COLLECTION]
end

Zipline.GetCollection() -- Do for initialization

local function CheckIsModel(Model)
	assert(typeof(Model) == "Instance" and Model:IsA("Model"), "Argument 1 must be a model.")
end

local function IsBasePart(Part)
	return typeof(Part) == "Instance" and Part:IsA("BasePart")
end

local function IsAllParts(...)
	local ps = {...}
	
	if #ps > 0 then
		for i, v in pairs(ps) do
			if IsBasePart(v) == false then
				return false
			end
		end
		
		return true
	else
		return false
	end
end

local function AddToCollection(Part, Zip)
	if IsBasePart(Part) then
		_G[Zipline.START_PART_COLLECTION][Part] = Zip
	end
end

local function RemoveFromCollection(Part)
	_G[Zipline.START_PART_COLLECTION][Part] = nil
end

-- Returns the zipline associated with the instance provided.
function Zipline.GetZipline(inst)
	assert(typeof(inst) == "Instance", "Argument 1 must be an Instance.")
	return Zipline.GetCollection()[inst]
end

-- Calculates the course of the zipline.
function Zipline.GetZiplineCourse(Zip, Parts, Fidelity, Formula)
	local NumParts = #Parts
	local i = 1
	local Beziers = {}

	local GenerationMode = Zipline.GenerationMode
	local Linear = GenerationMode.Linear
	local Quadratic = GenerationMode.Quadratic
	local Cubic = GenerationMode.Cubic

	GenerationMode = nil

	while i < NumParts do
		local part1 = Parts[i]
		local part2 = Parts[i + 1]
		local part3 = Parts[i + 2]
		local part4 = Parts[i + 3]

		if Formula == Cubic and IsBasePart(part4) then
			-- Use the cubic bezier function.
			-- Laggy, so not recommended.
			if IsAllParts(part1, part2, part3, part4) then
				local p1 = part1.Position
				local p2 = part2.Position
				local p3 = part3.Position
				local p4 = part4.Position

				local bz = Bezier.New(Bezier.Cubic, (p4 - p1).Magnitude * Fidelity, p1, p2, p3, p4)
				Zip.TotalDistance += bz.TotalDist
				table.insert(Beziers, bz)
				bz.Dispose()
			end

			i += 3 -- Not 4, because the 3rd might not be the last
		elseif (Formula == Quadratic or Formula == Cubic) and IsBasePart(part3) then -- Check if there's 3 or more points remaining
			-- Use the quadratic bezier function.
			if IsAllParts(part1, part2, part3) then
				local p1 = part1.Position
				local p2 = part2.Position
				local p3 = part3.Position

				local bz = Bezier.New(Bezier.Quadratic, (p3 - p1).Magnitude * Fidelity, p1, p2, p3)
				Zip.TotalDistance += bz.TotalDist
				table.insert(Beziers, bz)
				bz.Dispose()
			end

			i += 2 -- Not 3, because the 3rd might not be the last
		elseif (Formula == Linear or Formula == Quadratic or Formula == Cubic) and IsBasePart(part2) then
			-- Use the linear bezier function.
			if IsAllParts(part1, part2) then
				local p1 = part1.Position
				local p2 = part2.Position

				local bz = Bezier.New(Bezier.Linear, (p2 - p1).Magnitude * Fidelity, p1, p2)
				Zip.TotalDistance += bz.TotalDist
				table.insert(Beziers, bz)

				bz.Dispose()
			end
			
			i += 1 -- Not 2, because the 2nd might not be the last
		else
			break
		end
	end

	return Beziers
end

--Zipline.GenerationFuncs = {
--	-- Format: Generator = {GeneratorFunc, LerpFunc}
	
--	Bezier = {
--		function(Zip, Parts, Fidelity, Formula)
--			local NumParts = #Parts
--			local i = 1
--			local Beziers = {}
			
--			local GenerationMode = Zipline.GenerationMode
--			local Linear = GenerationMode.Linear
--			local Quadratic = GenerationMode.Quadratic
--			local Cubic = GenerationMode.Cubic
			
--			GenerationMode = nil

--			while i < NumParts do
--				local part1 = Parts[i]
--				local part2 = Parts[i + 1]
--				local part3 = Parts[i + 2]
--				local part4 = Parts[i + 3]
				
--				if Formula == Cubic and IsBasePart(part4) then
--					-- Use the cubic bezier function.
--					-- Laggy, so not recommended.
--					if IsAllParts(part1, part2, part3, part4) then
--						local p1 = part1.Position
--						local p2 = part2.Position
--						local p3 = part3.Position
--						local p4 = part4.Position

--						local bz = Bezier.New(Bezier.Cubic, (p4 - p1).Magnitude * Fidelity, p1, p2, p3, p4)
--						Zip.TotalDistance += bz.TotalDist
--						table.insert(Beziers, bz)
--						bz.Dispose()
--					end

--					i += 3 -- Not 4, because the 3rd might not be the last
--				elseif Formula == Quadratic and IsBasePart(part3) then -- Check if there's 3 or more points remaining
--					-- Use the quadratic bezier function.
--					if IsAllParts(part1, part2, part3) then
--						local p1 = part1.Position
--						local p2 = part2.Position
--						local p3 = part3.Position

--						local bz = Bezier.New(Bezier.Quadratic, (p3 - p1).Magnitude * Fidelity, p1, p2, p3)
--						Zip.TotalDistance += bz.TotalDist
--						table.insert(Beziers, bz)
--						bz.Dispose()
--					end

--					i += 2 -- Not 3, because the 3rd might not be the last
--				elseif Formula == Linear and IsBasePart(part2) then
--					-- Use the linear bezier function.
--					if IsAllParts(part1, part2) then
--						local p1 = part1.Position
--						local p2 = part2.Position

--						local bz = Bezier.New(Bezier.Linear, (p2 - p1).Magnitude * Fidelity, p1, p2)
--						Zip.TotalDistance += bz.TotalDist
--						table.insert(Beziers, bz)

--						bz.Dispose()
--					end
--				else
--					break
--				end
--			end

--			return Beziers
--		end,
		
--		Bezier.LerpCombined
--	},
	
--	Spline = {
--		function(Zip, Parts)
--			local vectors = {}
--			for i, v in ipairs(Parts) do
--				if IsBasePart(v) then
--					table.insert(vectors, v.Position)
--				end
--			end

--			local sp = Spline.NewVector3(vectors)
--			return {sp}
--		end,
		
--		Spline.LerpCombined
--	}
--}

-- Generates a new rideable zipline from a model.
function Zipline.New(Model)
	CheckIsModel(Model)

	local Zip = Object.New("Zipline")
	Zip.StartPart = nil
	Zip.TotalDistance = 0
	
	-- Configurable attributes
	Zip.DisplayThickness = ConfigDefaults.FillValue(THICKNESS_ATTRIBUTE, Model:GetAttribute(THICKNESS_ATTRIBUTE))
	Zip.SetProperty("Precision", ConfigDefaults.FillValue(PRECISION_ATTRIBUTE, Model:GetAttribute(PRECISION_ATTRIBUTE)), Zip.Refresh)
	Zip.SetProperty("GenerationMode", ConfigDefaults.FillValue(FORMULA_ATTRIBUTE, Model:GetAttribute(FORMULA_ATTRIBUTE)), Zip.Refresh)
	
	local ZipDecorPart = Model:WaitForChild("Decor", 5)
	assert(IsBasePart(ZipDecorPart), "The BasePart named 'Decor' wasn't found in the model.")
	local ZiplineTransparency = ZipDecorPart.Transparency
	ZipDecorPart.CanCollide = false
	ZipDecorPart.Transparency = 1

	local ZiplinePath = Instance.new("Folder")
	ZiplinePath.Name = "ZiplinePath"
	
	-- Handles the zipline course's segments and returns them.
	function Zip.GetCourse(model)
		CheckIsModel(model)

		local Points = model:WaitForChild("Segments", 5)
		if Points ~= nil then
			local FoundStart = false

			-- Manual order detection is needed due to GetChildren() randomness
			local NumParts = #Points:GetChildren()
			local Parts = {}
			for i = 1, NumParts, 1 do
				local p = Points:FindFirstChild(tostring(i))
				if IsBasePart(p) then
					if FoundStart == false then
						FoundStart = true
						Zip.StartPart = p

						AddToCollection(p, Zip)
					end

					p.CanCollide = false
					table.insert(Parts, p)
				end
			end

			return Zipline.GetZiplineCourse(Zip, Parts, Zip.Precision, Zip.GenerationMode)
		end
	end
	
	-- Returns the configuration attribute of the zipline's model.
	function Zip.GetModelSetting(Attribute)
		return ConfigDefaults.FillValue(Attribute, Model:GetAttribute(Attribute))
	end

	-- Returns a combination of zipline display lines from the given bezier set.
	function Zip.GetZipDisplay(BezierSet)
		-- Set the part group size to account for
		local DisplayPrecision = math.clamp(Zip.GetModelSetting(DISPLAY_PRECISION_ATTRIBUTE), DISPLAY_PRECISION_MIN, DISPLAY_PRECISION_MAX)
		
		local PrecisionMultiplied = math.floor(Zip.Precision or 1 * (1 / DisplayPrecision))
		local GroupSize = math.max(PrecisionMultiplied, 1)
		PrecisionMultiplied, DisplayPrecision = nil, nil
		
		local Set = {}
		
		local d = Display.New()
		d.PartGroupSize = GroupSize
		d.Thickness = Zip.DisplayThickness
		d.Material = ZipDecorPart.Material
		d.Color = ZipDecorPart.Color
		d.Transparency = ZiplineTransparency
		d.Refresh(BezierSet)
		d.Parts.Parent = ZiplinePath

		return Set
	end

	function Zip.Refresh()
		local BezierSet = Zip.GetCourse(Model)
		Zip.BezierSet = BezierSet
		
		-- Display zipline if enabled.
		if Zip.GetModelSetting(PATH_DISPLAYED_ATTRIBUTE) == true then
			Zip.Display = Zip.GetZipDisplay(BezierSet)
		end
		
		BezierSet = nil
	end

	-- Initialize the zipline
	Zip.Refresh()

	-- The parent property of the zipline display model.
	Zip.SetProperty("ModelParent", nil, function(parent)
		if parent == nil or typeof(parent) == "Instance" then
			ZiplinePath.Parent = parent
		end
	end)

	-- Gets a lerped value over the course of the zipline
	function Zip.LerpTo(Time)
		Time = math.clamp(Time, 0, 1)
		return Bezier.LerpCombined(Time, Zip.BezierSet)
	end

	Zip.OnDisposal = function()
		if Zip.StartPart ~= nil then
			RemoveFromCollection(Zip.StartPart)
		end
		
		-- Dispose other objects
		if Zip.BezierSet ~= nil then
			for i, v in pairs(Zip.BezierSet) do
				v.Dispose()
			end
		end
		
		if Zip.DisplaySet ~= nil then
			for i, v in pairs(Zip.DisplaySet) do
				v.Dispose()
			end
		end
	end

	-- Listen for model changes
	Zip.AddEvent = Model.ChildAdded:Connect(function(c)
		if IsBasePart(c) then
			Zip.Refresh()
		end
	end)
	Zip.RemoveEvent = Model.ChildRemoved:Connect(function(c)
		if IsBasePart(c) then
			Zip.Refresh()
		end
	end)

	return Zip
end

return Zipline