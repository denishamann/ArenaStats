local addonName = "ArenaStats"
local addonTitle = select(2, (C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo)(addonName))
local ArenaStats = _G.LibStub("AceAddon-3.0"):NewAddon(addonName,
                                                       "AceConsole-3.0",
                                                       "AceEvent-3.0")
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local libDBIcon = _G.LibStub("LibDBIcon-1.0")
local LibRaces = _G.LibStub("LibRaces-1.0")
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local GetBattlefieldStatus, GetBattlefieldTeamInfo, GetNumBattlefieldScores,
      GetBattlefieldScore, GetBattlefieldWinner, IsArenaSkirmish, IsInInstance,
      GetInstanceInfo = GetBattlefieldStatus, GetBattlefieldTeamInfo,
                        GetNumBattlefieldScores, GetBattlefieldScore,
                        GetBattlefieldWinner, IsArenaSkirmish, IsInInstance,
                        GetInstanceInfo
local UnitName, UnitRace, UnitClass, UnitGUID, UnitFactionGroup, UnitIsPlayer =
    UnitName, UnitRace, UnitClass, UnitGUID, UnitFactionGroup, UnitIsPlayer

function ArenaStats:OnInitialize()
    self.db = _G.LibStub("AceDB-3.0"):New(addonName, {
        profile = {
            minimapButton = {hide = false}, -- Note: LibDBIcon requires this format
            maxHistory = 0,
            showCharacterNamesOnHover = true,
            showSpec = true
        },
        char = {history = {}}
    })

    self:Print("Tracking ready, have a nice session!")
    self.specSpells = self:GetSpecSpells();

    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    self:RegisterEvent("ARENA_OPPONENT_UPDATE")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

    self:DrawMinimapIcon()
    self:RegisterOptionsTable()

    self.specTable = {}
    self.arenaEnded = false
    self.current = { status = "none", stats = {}, units = {} }
    
    -- Cache for BuildTable to avoid rebuilding on every GUI refresh
    self.tableCache = nil
    self.tableCacheSize = 0
    
    self:Reset()
end

function ArenaStats:OnDisable()
    self:UnregisterAllEvents()
    if _G.AsFrame then
        _G.AsFrame:Hide()
    end
end

function ArenaStats:OnSpecDetected(unitName, spec)
    local existingPlayer = self.specTable[unitName]

    if existingPlayer then
        return
    end

    self.specTable[unitName] = spec
end

function ArenaStats:ScanUnitBuffs(unit)
    if not unit then return end

    for n = 1, 30 do
        local name, spellID, unitCaster = self:GetUnitBuff(unit, n)

        if not name then
            break
        end

        if self.specSpells[spellID] then
            -- For TBC, we can't reliably get unitCaster, so we assume self-buffs
            if self.isTBC then
                local casterName = GetUnitName(unit, true)
                if casterName then
                    self:OnSpecDetected(casterName, self.specSpells[spellID])
                end
            elseif unitCaster then
                local unitPet = string.gsub(unit, "%d$", "pet%1")
                if UnitIsUnit(unit, unitCaster) or UnitIsUnit(unitPet, unitCaster) then
                    local casterName = GetUnitName(unitCaster, true)
                    if casterName then
                        self:OnSpecDetected(casterName, self.specSpells[spellID])
                    end
                end
            end
        end
    end
end

function ArenaStats:ARENA_OPPONENT_UPDATE(_, unit, updateReason)
    self:ScanUnitBuffs(unit)
end

function ArenaStats:UNIT_AURA(_, unit, isFullUpdate, updatedAuras)
    self:ScanUnitBuffs(unit)
end

function ArenaStats:UNIT_SPELLCAST_START(_, unit, castGUID, spellID)
    local spellName = spellID and GetSpellInfo(spellID) or nil

    if unit then
        self:ScanUnitBuffs(unit)
    end

    if spellID and self.specSpells[spellID] and unit then
        local name = GetUnitName(unit, true)
        if name then
            self:OnSpecDetected(name, self.specSpells[spellID])
        end
    end
end

function ArenaStats:UNIT_SPELLCAST_CHANNEL_START(_, unit, castGuid, spellId)
    if unit then
        self:ScanUnitBuffs(unit)
    end

    if spellId and self.specSpells[spellId] and unit then
        local name = GetUnitName(unit, true)
        if name then
            self:OnSpecDetected(name, self.specSpells[spellId])
        end
    end
end

function ArenaStats:UNIT_SPELLCAST_SUCCEEDED(_, unit, castGuid, spellId)
    if unit then
        self:ScanUnitBuffs(unit)
    end

    if spellId and self.specSpells[spellId] and unit then
        local name = GetUnitName(unit, true)
        if name then
            self:OnSpecDetected(name, self.specSpells[spellId])
        end
    end
end

function ArenaStats:ZONE_CHANGED_NEW_AREA()
    local _, instanceType = IsInInstance()
    if (instanceType == "arena") then
        self.arenaEnded = false
        self.specTable = {}
    end
end

function ArenaStats:UPDATE_BATTLEFIELD_STATUS(_, index)
    local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize,
    isRankedArena, suspendedQueue, bool, queueType =
        GetBattlefieldStatus(index)
    if (status == "active" and teamSize > 0 and IsActiveBattlefieldArena()) then
        self.current["status"] = status
        self.current["stats"]["teamSize"] = teamSize
        self.current["stats"]["isRanked"] = not IsArenaSkirmish()
        if (self.current["stats"]["startTime"] == nil or
                self.current["stats"]["startTime"] == '') then
            self.current["stats"]["startTime"] = _G.time()
        end
    end
end

function ArenaStats:GetSpecOrDefault(unitName)
    if not unitName then
        return "Unknown"
    end

    local detectedSpec = self.specTable[unitName]

    if detectedSpec then
        return detectedSpec
    end

    return "Unknown"
end

--- Collects and stores all arena ranking data at the end of a match.
--- This function is called when the battlefield score is updated and a winner is determined.
---
--- The function performs three main tasks:
--- 1. Identifies which team (GREEN=0 or GOLD=1) the player belongs to by scanning scores
--- 2. Retrieves team ratings and MMR for both teams from GetBattlefieldTeamInfo
--- 3. Collects individual player data (class, name, race, spec) for both teams
---
--- Data is stored in self.current["stats"] with 0-based indexing for player arrays
--- to maintain compatibility with the existing data format.
function ArenaStats:SetLastArenaRankingData()
    local playerTeam = ''
    local greenTeam = {}
    local goldTeam = {}
    local myName = UnitName("player")
    local numScores = GetNumBattlefieldScores()

    -- Step 1: Scan all players to determine which team we're on and group players by team
    -- GREEN team has teamIndex=0, GOLD team has teamIndex=1
    for i = 1, numScores do
        local data = { GetBattlefieldScore(i) }
        local teamIndex = data[6]
        
        -- Check if this player is us to determine our team color
        if data[1] == myName then
            playerTeam = (teamIndex == 0) and 'GREEN' or 'GOLD'
        end

        -- Group players into their respective teams
        if teamIndex == 0 then
            table.insert(greenTeam, data)
        else
            table.insert(goldTeam, data)
        end
    end

    self.current["stats"]["teamColor"] = playerTeam

    -- Step 2: Get team ratings and MMR from both teams
    -- Team index 0 = GREEN, Team index 1 = GOLD
    for i = 0, 1 do
        local teamName, oldTeamRating, newTeamRating, teamMMR =
            GetBattlefieldTeamInfo(i)
        if teamMMR > 0 then
            local isPlayerTeam = (i == 0 and playerTeam == 'GREEN') or
                                 (i == 1 and playerTeam == 'GOLD')
            if isPlayerTeam then
                self.current["stats"]["teamName"] = teamName
                self.current["stats"]["oldTeamRating"] = oldTeamRating
                self.current["stats"]["newTeamRating"] = newTeamRating
                self.current["stats"]["diffRating"] = newTeamRating - oldTeamRating
                self.current["stats"]["mmr"] = teamMMR
            else
                self.current["stats"]["enemyTeamName"] = teamName
                self.current["stats"]["enemyOldTeamRating"] = oldTeamRating
                self.current["stats"]["enemyNewTeamRating"] = newTeamRating
                self.current["stats"]["enemyDiffRating"] = newTeamRating - oldTeamRating
                self.current["stats"]["enemyMmr"] = teamMMR
            end
        end
    end

    -- Step 3: Initialize player data arrays and collect individual player info
    self.current["stats"]["teamClass"] = {}
    self.current["stats"]["teamCharName"] = {}
    self.current["stats"]["teamRace"] = {}
    self.current["stats"]["teamSpec"] = {}
    self.current["stats"]["teamDamage"] = {}
    self.current["stats"]["teamHealing"] = {}

    self.current["stats"]["enemyClass"] = {}
    self.current["stats"]["enemyName"] = {}
    self.current["stats"]["enemyRace"] = {}
    self.current["stats"]["enemySpec"] = {}
    self.current["stats"]["enemyDamage"] = {}
    self.current["stats"]["enemyHealing"] = {}

    -- Determine which raw data table corresponds to player's team vs enemy team
    local playerTeamTable = (playerTeam == 'GREEN') and greenTeam or goldTeam
    local enemyTeamTable = (playerTeam == 'GREEN') and goldTeam or greenTeam

    -- Helper to convert localized race name to uppercase race token
    local function convertRace(raceInput)
        if not raceInput then return '' end
        local race = LibRaces:GetRaceToken(raceInput)
        return race and race:upper() or ''
    end

    -- GetBattlefieldScore returns:
    -- [1]=playerName, [2]=killingBlows, [3]=honorKills, [4]=deaths, [5]=honorGained,
    -- [6]=faction, [7]=rank, [8]=race, [9]=class, [10]=classToken, [11]=damageDone, [12]=healingDone
    
    -- Collect player's team data (0-based indexing for storage)
    for i = 1, #playerTeamTable do
        local row = playerTeamTable[i]
        local raceUpper = convertRace(row[8])
        local idx = i - 1  -- Convert to 0-based index

        self.current["stats"]["teamClass"][idx] = row[10] and row[10]:upper() or ''
        self.current["stats"]["teamCharName"][idx] = row[1]
        self.current["stats"]["teamRace"][idx] = raceUpper
        self.current["stats"]["teamSpec"][idx] = self:GetSpecOrDefault(row[1])
        self.current["stats"]["teamDamage"][idx] = row[11]
        self.current["stats"]["teamHealing"][idx] = row[12]
    end

    -- Collect enemy team data (0-based indexing for storage)
    for i = 1, #enemyTeamTable do
        local row = enemyTeamTable[i]
        local raceUpper = convertRace(row[8])
        local idx = i - 1  -- Convert to 0-based index

        self.current["stats"]["enemyClass"][idx] = row[10] and row[10]:upper() or ''
        self.current["stats"]["enemyName"][idx] = row[1]
        self.current["stats"]["enemyRace"][idx] = raceUpper
        self.current["stats"]["enemyFaction"] = self:RaceToFaction(raceUpper)
        self.current["stats"]["enemyFaction"] = self:RaceToFaction(raceUpper)
        self.current["stats"]["enemySpec"][idx] = self:GetSpecOrDefault(row[1])
        self.current["stats"]["enemyDamage"][idx] = row[11]
        self.current["stats"]["enemyHealing"][idx] = row[12]
    end
end

-- Alliance races lookup table
local ALLIANCE_RACES = {
    HUMAN = true, GNOME = true, NIGHTELF = true,
    DRAENEI = true, DWARF = true, WORGEN = true
}

function ArenaStats:RaceToFaction(race)
    return ALLIANCE_RACES[race] and 1 or 0
end

function ArenaStats:UPDATE_BATTLEFIELD_SCORE()
    local battlefieldWinner = GetBattlefieldWinner()
    if battlefieldWinner == nil or self.arenaEnded then return end

    if self.current.status ~= 'none' then
        self.current["stats"]["zoneId"] = select(8, GetInstanceInfo())
        self.current["stats"]["endTime"] = _G.time()
        self.arenaEnded = true
        if (battlefieldWinner == 0) then
            self.current["stats"]["winnerColor"] = "GREEN";
        elseif (battlefieldWinner == 1) then
            self.current["stats"]["winnerColor"] = "GOLD";
        end
        self:SetLastArenaRankingData()
        if GetNumBattlefieldScores() ~= 0 then self:RecordArena() end
    end
end

function ArenaStats:Reset()
    self.current["status"] = "none"

    self.current["stats"] = {}
    self.current["units"] = {}
    self.specTable = {}
end

function ArenaStats:RecordArena()
    self:AddEntryToHistory(self.current["stats"])
    self:Print("Arena recorded")
    self:Reset()
end

function ArenaStats:AddEntryToHistory(stats)
    table.insert(self.db.char.history, stats)
    if self.db.profile.maxHistory > 0 then
        while (#self.db.char.history > self.db.profile.maxHistory) do
            table.remove(self.db.char.history, 1)
        end
    end
    -- Invalidate BuildTable cache since history changed
    self.tableCache = nil
end

function ArenaStats:DrawMinimapIcon()
    libDBIcon:Register(addonName,
        _G.LibStub("LibDataBroker-1.1"):NewDataObject(addonName,
            {
                type = "data source",
                text = addonName,
                icon = "interface/icons/achievement_arena_2v2_7",
                OnClick = function(self, button)
                    if button == "RightButton" then
                        _G.LibStub("AceConfigDialog-3.0"):Open(addonName)
                    else
                        ArenaStats:Toggle()
                    end
                end,
                OnTooltipShow = function(tooltip)
                    tooltip:AddLine(string.format("%s |cff777777v%s|r", addonTitle,
                        "0.2.5"))
                    tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Left Click"],
                        L["to open the main window"]))
                    tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Right Click"],
                        L["to open options"]))
                    tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Drag"],
                        L["to move this button"]))
                end
            }), self.db.profile.minimapButton)
end

function ArenaStats:ToggleMinimapButton()
    self.db.profile.minimapButton.hide = not self.db.profile.minimapButton.hide
    if self.db.profile.minimapButton.hide then
        libDBIcon:Hide(addonName)
    else
        libDBIcon:Show(addonName)
    end
end

function ArenaStats:CalculateTeamSize(row)
    if (row["teamSize"] ~= nil or row["teamClass"] == nil) then
        return row["teamSize"]
    end

    local teamSize = 0
    for i = 0, 5 do
        if row["teamClass"][i] ~= nil then teamSize = teamSize + 1 end
    end
    return teamSize
end

--- Builds a display-ready table from the history database.
--- Transforms the raw storage format (0-based indexed arrays) into a flat structure
--- with named fields (e.g., teamPlayerClass1, teamPlayerClass2, etc.) for easier GUI rendering.
--- Uses caching to avoid rebuilding when the history hasn't changed.
--- @return table[] Array of arena match records, sorted from newest to oldest
function ArenaStats:BuildTable()
    local tableLength = #self.db.char.history
    
    -- Return cached table if history size hasn't changed
    if self.tableCache and self.tableCacheSize == tableLength then
        return self.tableCache
    end
    
    local tbl = {}

    for i = 1, tableLength do
        local row = self.db.char.history[tableLength + 1 - i]
        table.insert(tbl, {

            ["_original"] = row,
            -- Common stats

            ["startTime"] = row["startTime"],
            ["endTime"] = row["endTime"],
            ["zoneId"] = self:RemapZoneId(row["zoneId"]),
            ["isRanked"] = row["isRanked"],
            ["teamSize"] = self:CalculateTeamSize(row),
            ["duration"] = (row["endTime"] and row["startTime"] and
                (row["endTime"] - row["startTime"]) or 0),

            -- Player's team

            ["teamName"] = row["teamName"],

            ["teamPlayerClass1"] = row["teamClass"] and row["teamClass"][0] or
                nil,
            ["teamPlayerClass2"] = row["teamClass"] and row["teamClass"][1] or
                nil,
            ["teamPlayerClass3"] = row["teamClass"] and row["teamClass"][2] or
                nil,
            ["teamPlayerClass4"] = row["teamClass"] and row["teamClass"][3] or
                nil,
            ["teamPlayerClass5"] = row["teamClass"] and row["teamClass"][4] or
                nil,
            ["teamPlayerName1"] = row["teamCharName"] and row["teamCharName"][0] or
                nil,
            ["teamPlayerName2"] = row["teamCharName"] and row["teamCharName"][1] or
                nil,
            ["teamPlayerName3"] = row["teamCharName"] and row["teamCharName"][2] or
                nil,
            ["teamPlayerName4"] = row["teamCharName"] and row["teamCharName"][3] or
                nil,
            ["teamPlayerName5"] = row["teamCharName"] and row["teamCharName"][4] or
                nil,
            ["teamPlayerRace1"] = row["teamRace"] and row["teamRace"][0] or nil,
            ["teamPlayerRace2"] = row["teamRace"] and row["teamRace"][1] or nil,
            ["teamPlayerRace3"] = row["teamRace"] and row["teamRace"][2] or nil,
            ["teamPlayerRace4"] = row["teamRace"] and row["teamRace"][3] or nil,
            ["teamPlayerRace5"] = row["teamRace"] and row["teamRace"][4] or nil,
            ["teamPlayerSpec1"] = row["teamSpec"] and row["teamSpec"][0] or nil,
            ["teamPlayerSpec2"] = row["teamSpec"] and row["teamSpec"][1] or nil,
            ["teamPlayerSpec3"] = row["teamSpec"] and row["teamSpec"][2] or nil,
            ["teamPlayerSpec4"] = row["teamSpec"] and row["teamSpec"][3] or nil,
            ["teamPlayerSpec5"] = row["teamSpec"] and row["teamSpec"][4] or nil,

            ["teamPlayerDamage1"] = row["teamDamage"] and row["teamDamage"][0] or 0,
            ["teamPlayerDamage2"] = row["teamDamage"] and row["teamDamage"][1] or 0,
            ["teamPlayerDamage3"] = row["teamDamage"] and row["teamDamage"][2] or 0,
            ["teamPlayerDamage4"] = row["teamDamage"] and row["teamDamage"][3] or 0,
            ["teamPlayerDamage5"] = row["teamDamage"] and row["teamDamage"][4] or 0,

            ["teamPlayerHealing1"] = row["teamHealing"] and row["teamHealing"][0] or 0,
            ["teamPlayerHealing2"] = row["teamHealing"] and row["teamHealing"][1] or 0,
            ["teamPlayerHealing3"] = row["teamHealing"] and row["teamHealing"][2] or 0,
            ["teamPlayerHealing4"] = row["teamHealing"] and row["teamHealing"][3] or 0,
            ["teamPlayerHealing5"] = row["teamHealing"] and row["teamHealing"][4] or 0,

            ["oldTeamRating"] = row["oldTeamRating"],
            ["newTeamRating"] = row["newTeamRating"],
            ["diffRating"] = row["diffRating"],
            ["mmr"] = row["mmr"],
            ["teamColor"] = row["teamColor"],
            ["winnerColor"] = row["winnerColor"],

            -- Enemy team

            ["enemyTeamName"] = row["enemyTeamName"],

            ["enemyPlayerClass1"] = row["enemyClass"] and row["enemyClass"][0] or
                nil,
            ["enemyPlayerClass2"] = row["enemyClass"] and row["enemyClass"][1] or
                nil,
            ["enemyPlayerClass3"] = row["enemyClass"] and row["enemyClass"][2] or
                nil,
            ["enemyPlayerClass4"] = row["enemyClass"] and row["enemyClass"][3] or
                nil,
            ["enemyPlayerClass5"] = row["enemyClass"] and row["enemyClass"][4] or
                nil,
            ["enemyPlayerName1"] = row["enemyName"] and row["enemyName"][0] or
                nil,
            ["enemyPlayerName2"] = row["enemyName"] and row["enemyName"][1] or
                nil,
            ["enemyPlayerName3"] = row["enemyName"] and row["enemyName"][2] or
                nil,
            ["enemyPlayerName4"] = row["enemyName"] and row["enemyName"][3] or
                nil,
            ["enemyPlayerName5"] = row["enemyName"] and row["enemyName"][4] or
                nil,
            ["enemyPlayerRace1"] = row["enemyRace"] and row["enemyRace"][0] or
                nil,
            ["enemyPlayerRace2"] = row["enemyRace"] and row["enemyRace"][1] or
                nil,
            ["enemyPlayerRace3"] = row["enemyRace"] and row["enemyRace"][2] or
                nil,
            ["enemyPlayerRace4"] = row["enemyRace"] and row["enemyRace"][3] or
                nil,
            ["enemyPlayerRace5"] = row["enemyRace"] and row["enemyRace"][4] or
                nil,
            ["enemyPlayerSpec1"] = row["enemySpec"] and row["enemySpec"][0] or nil,
            ["enemyPlayerSpec2"] = row["enemySpec"] and row["enemySpec"][1] or nil,
            ["enemyPlayerSpec3"] = row["enemySpec"] and row["enemySpec"][2] or nil,
            ["enemyPlayerSpec4"] = row["enemySpec"] and row["enemySpec"][3] or nil,
            ["enemyPlayerSpec5"] = row["enemySpec"] and row["enemySpec"][4] or nil,
            
            ["enemyPlayerDamage1"] = row["enemyDamage"] and row["enemyDamage"][0] or 0,
            ["enemyPlayerDamage2"] = row["enemyDamage"] and row["enemyDamage"][1] or 0,
            ["enemyPlayerDamage3"] = row["enemyDamage"] and row["enemyDamage"][2] or 0,
            ["enemyPlayerDamage4"] = row["enemyDamage"] and row["enemyDamage"][3] or 0,
            ["enemyPlayerDamage5"] = row["enemyDamage"] and row["enemyDamage"][4] or 0,

            ["enemyPlayerHealing1"] = row["enemyHealing"] and row["enemyHealing"][0] or 0,
            ["enemyPlayerHealing2"] = row["enemyHealing"] and row["enemyHealing"][1] or 0,
            ["enemyPlayerHealing3"] = row["enemyHealing"] and row["enemyHealing"][2] or 0,
            ["enemyPlayerHealing4"] = row["enemyHealing"] and row["enemyHealing"][3] or 0,
            ["enemyPlayerHealing5"] = row["enemyHealing"] and row["enemyHealing"][4] or 0,
            ["enemyFaction"] = row["enemyFaction"],

            ["enemyOldTeamRating"] = row["enemyOldTeamRating"],
            ["enemyNewTeamRating"] = row["enemyNewTeamRating"],
            ["enemyDiffRating"] = row["enemyDiffRating"],
            ["enemyMmr"] = row["enemyMmr"]

        })
    end
    
    -- Store in cache for subsequent calls
    self.tableCache = tbl
    self.tableCacheSize = tableLength
    
    return tbl
end

function ArenaStats:RemapZoneId(mapAreaId)
    -- remap old mapAreaId to instanceids (for backward compatibility)
    if mapAreaId == 3698 then
        return 559
    elseif mapAreaId == 3702 then
        return 562
    elseif mapAreaId == 3968 then
        return 572
    end
    return mapAreaId
end

function ArenaStats:ResetDatabase()
    self.db:ResetDB()
    -- Invalidate BuildTable cache since database was reset
    self.tableCache = nil
    self:Print(L["Database reset"])
end

-- Helper to safely get value or empty string
local function safeVal(val)
    return val ~= nil and val or ""
end

-- Helper to safely get indexed value from table
local function safeIndexedVal(tbl, index)
    return tbl and tbl[index] ~= nil and tbl[index] or ""
end

function ArenaStats:ExportCSV()
    local csvParts = {
        "isRanked,startTime,endTime,zoneId,duration,teamName,teamColor,winnerColor," ..
        "teamPlayerName1,teamPlayerName2,teamPlayerName3,teamPlayerName4,teamPlayerName5," ..
        "teamPlayerClass1,teamPlayerClass2,teamPlayerClass3,teamPlayerClass4,teamPlayerClass5," ..
        "teamPlayerRace1,teamPlayerRace2,teamPlayerRace3,teamPlayerRace4,teamPlayerRace5," ..
        "oldTeamRating,newTeamRating,diffRating,mmr," ..
        "enemyOldTeamRating,enemyNewTeamRating,enemyDiffRating,enemyMmr,enemyTeamName," ..
        "enemyPlayerName1,enemyPlayerName2,enemyPlayerName3,enemyPlayerName4,enemyPlayerName5," ..
        "enemyPlayerClass1,enemyPlayerClass2,enemyPlayerClass3,enemyPlayerClass4,enemyPlayerClass5," ..
        "enemyPlayerRace1,enemyPlayerRace2,enemyPlayerRace3,enemyPlayerRace4,enemyPlayerRace5,enemyFaction," ..
        "enemySpec1,enemySpec2,enemySpec3,enemySpec4,enemySpec5," ..
        "teamSpec1,teamSpec2,teamSpec3,teamSpec4,teamSpec5,\n"
    }

    for _, row in ipairs(self.db.char.history) do
        local duration = (row["startTime"] and row["endTime"]) and (row["endTime"] - row["startTime"]) or ""
        local rowParts = {
            self:YesOrNo(row["isRanked"]),
            safeVal(row["startTime"]),
            safeVal(row["endTime"]),
            safeVal(row["zoneId"]),
            duration,
            safeVal(row["teamName"]),
            safeVal(row["teamColor"]),
            safeVal(row["winnerColor"]),
            -- Team player names
            safeIndexedVal(row["teamCharName"], 0),
            safeIndexedVal(row["teamCharName"], 1),
            safeIndexedVal(row["teamCharName"], 2),
            safeIndexedVal(row["teamCharName"], 3),
            safeIndexedVal(row["teamCharName"], 4),
            -- Team player classes
            safeIndexedVal(row["teamClass"], 0),
            safeIndexedVal(row["teamClass"], 1),
            safeIndexedVal(row["teamClass"], 2),
            safeIndexedVal(row["teamClass"], 3),
            safeIndexedVal(row["teamClass"], 4),
            -- Team player races
            safeIndexedVal(row["teamRace"], 0),
            safeIndexedVal(row["teamRace"], 1),
            safeIndexedVal(row["teamRace"], 2),
            safeIndexedVal(row["teamRace"], 3),
            safeIndexedVal(row["teamRace"], 4),
            -- Team ratings
            self:ComputeSafeNumber(row["oldTeamRating"]),
            self:ComputeSafeNumber(row["newTeamRating"]),
            self:ComputeSafeNumber(row["diffRating"]),
            self:ComputeSafeNumber(row["mmr"]),
            -- Enemy ratings
            self:ComputeSafeNumber(row["enemyOldTeamRating"]),
            self:ComputeSafeNumber(row["enemyNewTeamRating"]),
            self:ComputeSafeNumber(row["enemyDiffRating"]),
            self:ComputeSafeNumber(row["enemyMmr"]),
            safeVal(row["enemyTeamName"]),
            -- Enemy player names
            safeIndexedVal(row["enemyName"], 0),
            safeIndexedVal(row["enemyName"], 1),
            safeIndexedVal(row["enemyName"], 2),
            safeIndexedVal(row["enemyName"], 3),
            safeIndexedVal(row["enemyName"], 4),
            -- Enemy player classes
            safeIndexedVal(row["enemyClass"], 0),
            safeIndexedVal(row["enemyClass"], 1),
            safeIndexedVal(row["enemyClass"], 2),
            safeIndexedVal(row["enemyClass"], 3),
            safeIndexedVal(row["enemyClass"], 4),
            -- Enemy player races
            safeIndexedVal(row["enemyRace"], 0),
            safeIndexedVal(row["enemyRace"], 1),
            safeIndexedVal(row["enemyRace"], 2),
            safeIndexedVal(row["enemyRace"], 3),
            safeIndexedVal(row["enemyRace"], 4),
            self:ComputeFaction(row["enemyFaction"]),
            -- Team specs
            safeIndexedVal(row["teamSpec"], 0),
            safeIndexedVal(row["teamSpec"], 1),
            safeIndexedVal(row["teamSpec"], 2),
            safeIndexedVal(row["teamSpec"], 3),
            safeIndexedVal(row["teamSpec"], 4),
            -- Enemy specs
            safeIndexedVal(row["enemySpec"], 0),
            safeIndexedVal(row["enemySpec"], 1),
            safeIndexedVal(row["enemySpec"], 2),
            safeIndexedVal(row["enemySpec"], 3),
            safeIndexedVal(row["enemySpec"], 4),
        }
        csvParts[#csvParts + 1] = table.concat(rowParts, ",") .. ",\n"
    end

    local csv = table.concat(csvParts)
    ArenaStats:ExportFrame().eb:SetText(csv)
    ArenaStats:ExportFrame():SetTitle(L["Export"])
    ArenaStats:ExportFrame().eb:SetNumLines(29)
    ArenaStats:ExportFrame().eb:SetLabel(
        "Export String " .. " (" .. string.len(csv) .. ") ")
    ArenaStats:ExportFrame():Show()
    ArenaStats:ExportFrame().eb:SetFocus()
    ArenaStats:ExportFrame().eb:HighlightText()
end

function ArenaStats:WebsiteURL()
    ArenaStats:ExportFrame():SetTitle(L["Tool"])
    ArenaStats:ExportFrame().eb:SetLabel("Tool Website URL")
    ArenaStats:ExportFrame().eb:SetNumLines(1)
    ArenaStats:ExportFrame().eb:SetText(
        "https://denishamann.github.io/arena-stats-visualizer/")
    ArenaStats:ExportFrame():Show()
    ArenaStats:ExportFrame().eb:SetFocus()
    ArenaStats:ExportFrame().eb:HighlightText()
end

function ArenaStats:ComputeFaction(factionId)
    if factionId == 1 then
        return "ALLIANCE"
    elseif factionId == 0 then
        return "HORDE"
    end
    return ""
end

function ArenaStats:YesOrNo(bool)
    if bool then
        return "YES"
    elseif not bool then
        return "NO"
    end
    return ""
end

function ArenaStats:ComputeSafeNumber(number)
    if number == nil then
        return ""
    elseif number == 0 then
        return "0"
    end
    return number
end

function ArenaStats:ShouldShowCharacterNamesTooltips()
    return self.db.profile.showCharacterNamesOnHover
end

function ArenaStats:TestData()
    local brackets = {2, 3, 5}
    local teamSize = brackets[math.random(#brackets)]
    local maps = {559, 562, 572}
    local zoneId = maps[math.random(#maps)]
    local duration = math.random(120, 900) -- 2 to 15 mins
    local startTime = _G.time() - duration
    local endTime = _G.time()

    local classes = {
        ["WARRIOR"] = {"Arms", "Fury", "Protection"},
        ["PALADIN"] = {"Holy", "Protection", "Retribution"},
        ["HUNTER"] = {"BeastMastery", "Marksmanship", "Survival"},
        ["ROGUE"] = {"Assassination", "Combat", "Subtlety"},
        ["PRIEST"] = {"Discipline", "Holy", "Shadow"},
        ["SHAMAN"] = {"Elemental", "Enhancement", "Restoration"},
        ["MAGE"] = {"Arcane", "Fire", "Frost"},
        ["WARLOCK"] = {"Affliction", "Demonology", "Destruction"},
        ["DRUID"] = {"Balance", "Feral", "Restoration"}
    }
    
    local classKeys = {}
    for k in pairs(classes) do table.insert(classKeys, k) end

    local function getRandomPlayer()
        local class = classKeys[math.random(#classKeys)]
        local specs = classes[class]
        local spec = specs[math.random(#specs)]
        local races = {"Human", "Orc", "Undead", "Night Elf", "Gnome", "Troll", "Dwarf", "Blood Elf", "Draenei"}
        return {
            name = "Player" .. math.random(1000),
            class = class,
            spec = spec,
            race = races[math.random(#races)]
        }
    end



    local teamColors = {"GOLD", "GREEN"}
    local myTeamColor = teamColors[math.random(2)]
    local winnerColor = teamColors[math.random(2)]

    local oldRating = math.random(1500, 2200)
    local enemyOldRating = math.random(1500, 2200)
    
    local change = math.random(10, 25)
    local newRating, enemyNewRating
    
    if myTeamColor == winnerColor then
        -- We won
        newRating = oldRating + change
        enemyNewRating = enemyOldRating - change
    else
        -- We lost
        newRating = oldRating - change
        enemyNewRating = enemyOldRating + change
    end

    local stats = {
        startTime = startTime,
        endTime = endTime,
        zoneId = zoneId,
        isRanked = true,
        teamSize = teamSize,
        teamName = "Test Team",
        teamColor = myTeamColor,
        winnerColor = winnerColor,
        oldTeamRating = oldRating,
        newTeamRating = newRating,
        mmr = math.random(1500, 2500),
        enemyTeamName = "Enemy Team",
        enemyOldTeamRating = enemyOldRating,
        enemyNewTeamRating = enemyNewRating,
        enemyMmr = math.random(1500, 2500),
        teamClass = {}, teamCharName = {}, teamRace = {}, teamSpec = {}, teamDamage = {}, teamHealing = {},
        enemyClass = {}, enemyName = {}, enemyRace = {}, enemySpec = {}, enemyDamage = {}, enemyHealing = {}, enemyFaction = math.random(0, 1)
    }
    stats.diffRating = stats.newTeamRating - stats.oldTeamRating
    stats.enemyDiffRating = stats.enemyNewTeamRating - stats.enemyOldTeamRating

    -- Generate players
    for i = 0, teamSize - 1 do
        local p = getRandomPlayer()
        stats.teamClass[i] = p.class
        stats.teamCharName[i] = p.name
        stats.teamRace[i] = string.upper(p.race)
        stats.teamSpec[i] = p.spec
        stats.teamDamage[i] = math.random(0, 100000)
        stats.teamHealing[i] = math.random(0, 100000)

        local e = getRandomPlayer()
        stats.enemyClass[i] = e.class
        stats.enemyName[i] = e.name
        stats.enemyRace[i] = string.upper(e.race)
        stats.enemySpec[i] = e.spec
        stats.enemyDamage[i] = math.random(0, 100000)
        stats.enemyHealing[i] = math.random(0, 100000)
    end

    self:AddEntryToHistory(stats)
    self:ReloadData()
    self:Print("Random test data generated")
end

function ArenaStats:DeleteEntry(entry)
    local target = entry._original or entry
    for i, v in ipairs(self.db.char.history) do
        if v == target then
            table.remove(self.db.char.history, i)
            self:ReloadData()
            self:Print("Match deleted.")
            return
        end
    end
end

function ArenaStats:Toggle()
    if asGui and asGui.f:IsShown() then
        asGui.f:Hide()
    else
        if not asGui then
            self:CreateGUI()
            if self.SetData then
                self:SetData(self:BuildTable())
            end
        else
            if self.SetData then
                self:SetData(self:BuildTable())
            end
        end
        asGui.f:Show()
    end
end

function ArenaStats:ReloadData()
    if self.SetData then
        self:SetData(self:BuildTable())
    end
end
