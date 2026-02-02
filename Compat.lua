local addonName = "ArenaStats"
local ArenaStats = LibStub("AceAddon-3.0"):GetAddon(addonName)

-- Detect client version
local _, _, _, interfaceVersion = GetBuildInfo()
ArenaStats.isTBC = interfaceVersion < 30000
ArenaStats.isCata = interfaceVersion >= 40000

-- C_AddOns.GetAddOnInfo wrapper
if C_AddOns and C_AddOns.GetAddOnInfo then
    ArenaStats.GetAddOnInfo = C_AddOns.GetAddOnInfo
else
    ArenaStats.GetAddOnInfo = GetAddOnInfo
end

-- Aura scanning wrapper
function ArenaStats:GetUnitBuff(unit, index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        -- Cata Classic
        local auraData = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
        if auraData then
            return auraData.name, auraData.spellId, auraData.sourceUnit
        end
        return nil
    else
        -- TBC Classic
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index)
        return name, spellId, nil  -- TBC doesn't provide sourceUnit from UnitBuff
    end
end
