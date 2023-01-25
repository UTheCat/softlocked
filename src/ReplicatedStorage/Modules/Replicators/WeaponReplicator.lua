-- The replicator for weapons.
local Replicators = script.Parent

local Base = require(Replicators:WaitForChild("BaseReplicator"))

local WeaponReplicator = {}

function WeaponReplicator.New(Weapon)
	assert(typeof(Weapon) == "table", "Argument 1 must be a BaseWeapon.")
	
	local BaseRep = Base.New(Weapon.Name)
	
	if Base.IsServer() then
		BaseRep.CooldownTime = Weapon.FireCooldown
	end
	
	return BaseRep
end

return WeaponReplicator