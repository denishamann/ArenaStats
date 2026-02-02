local addonName = "ArenaStats"
local ArenaStats = LibStub("AceAddon-3.0"):GetAddon(addonName)

-- TBC spec detection not implemented yet
-- Spell IDs are completely different from Cata and need research
local specSpells = {}

function ArenaStats:GetSpecSpells()
    return specSpells
end
