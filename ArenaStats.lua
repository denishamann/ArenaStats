local addonName = "ArenaStatsTBC"
local addonTitle = select(2, _G.GetAddOnInfo(addonName))
local ArenaStats = _G.LibStub("AceAddon-3.0"):NewAddon(addonName,
                                                       "AceConsole-3.0",
                                                       "AceEvent-3.0")
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local libDBIcon = _G.LibStub("LibDBIcon-1.0")
local AceSerializer = _G.LibStub("AceSerializer-3.0")
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local GetBattlefieldStatus, GetBattlefieldTeamInfo, GetNumBattlefieldScores,
      GetBattlefieldScore, GetBattlefieldWinner, IsArenaSkirmish = GetBattlefieldStatus,
                                                  GetBattlefieldTeamInfo,
                                                  GetNumBattlefieldScores,
                                                  GetBattlefieldScore,
                                                  GetBattlefieldWinner,
                                                  IsArenaSkirmish
local UnitName, UnitRace, UnitClass, UnitGUID, UnitFactionGroup, UnitIsPlayer =
    UnitName, UnitRace, UnitClass, UnitGUID, UnitFactionGroup, UnitIsPlayer
local IsInGroup = IsInGroup

function ArenaStats:OnInitialize()
    self.db = _G.LibStub("AceDB-3.0"):New(addonName, {
        profile = {minimapButton = {hide = false}, maxHistory = 0},
        char = {history = {}}
    })
    self:Print("Tracking ready, have a nice session!")

    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
    self:RegisterEvent("ARENA_OPPONENT_UPDATE")

    self:DrawMinimapIcon()
    self:RegisterOptionsTable()

    self.arenaEnded = false
    self.current = {status = "none", stats = {}, units = {}}
    self:Reset()
end

function ArenaStats:UPDATE_BATTLEFIELD_STATUS(_, index)
    local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize,
          isRankedArena, suspendedQueue, bool, queueType =
        GetBattlefieldStatus(index)
    if (status == "active" and teamSize > 0 and IsActiveBattlefieldArena()) then
        self.arenaEnded = false
        self.current["status"] = status
        self.current["stats"]["isRanked"] = not IsArenaSkirmish()
        self.current["stats"]["zoneId"] = self:ZoneId(mapName)
        self.current["stats"]["teamSize"] = teamSize
        if (self.current["stats"]["startTime"] == nil or
            self.current["stats"]["startTime"] == '') then
            self.current["stats"]["startTime"] = _G.time()
        end
    end
end

function ArenaStats:SetLastArenaRankingData()

    local playerTeam = ''
    local greenTeam = {}
    local goldTeam = {}
    local myName = UnitName("player")

    for i = 1, GetNumBattlefieldScores() do
        local playerName, killingBlows, honorKills, deaths, honorGained,
              faction, rank, race, class, filename, damageDone, healingDone =
            GetBattlefieldScore(i)
        local teamIndex = select(6, GetBattlefieldScore(i))
        if teamIndex == 0 then
            table.insert(greenTeam, playerName)
        else
            table.insert(goldTeam, playerName)
        end
    end

    if self:Has_value(greenTeam, myName) then
        playerTeam = 'GREEN'
    elseif self:Has_value(goldTeam, myName) then
        playerTeam = 'GOLD'
    end

    for i = 0, 1 do
        local teamName, oldTeamRating, newTeamRating, teamMMR =
            GetBattlefieldTeamInfo(i);
        if teamMMR > 0 then
            if ((i == 0 and playerTeam == 'GREEN') or
                (i == 1 and playerTeam == 'GOLD')) then
                self.current["stats"]["teamName"] = teamName
                self.current["stats"]["oldTeamRating"] = oldTeamRating
                self.current["stats"]["newTeamRating"] = newTeamRating
                self.current["stats"]["diffRating"] = newTeamRating -
                                                          oldTeamRating
                self.current["stats"]["mmr"] = teamMMR
            else
                self.current["stats"]["enemyTeamName"] = teamName
                self.current["stats"]["enemyOldTeamRating"] = oldTeamRating
                self.current["stats"]["enemyNewTeamRating"] = newTeamRating
                self.current["stats"]["enemyDiffRating"] = newTeamRating -
                                                               oldTeamRating
                self.current["stats"]["enemyMmr"] = teamMMR
            end
        end
    end

    self.current["stats"]["enemyClass"] = {}
    self.current["stats"]["enemyName"] = {}
    self.current["stats"]["enemyRace"] = {}
    local idx = 0
    for k, v in pairs(self.current["units"]) do
        self.current["stats"]["enemyClass"][idx] = v["class"]:upper()
        self.current["stats"]["enemyName"][idx] = v["name"]
        self.current["stats"]["enemyRace"][idx] = v["race"]:upper()
        if self.current["stats"]["enemyFaction"] == nil then
            if v["faction"] == 'Alliance' then
                self.current["stats"]["enemyFaction"] = 1
            else
                self.current["stats"]["enemyFaction"] = 0
            end
        end
        idx = idx + 1
    end
end

function ArenaStats:UPDATE_BATTLEFIELD_SCORE()
    local battlefieldWinner = GetBattlefieldWinner()
    if battlefieldWinner == nil or self.arenaEnded then return end

    if self.current.status ~= 'none' then
        self.current["stats"]["endTime"] = _G.time()
        self.battlegroundEnded = true
        self:SetLastArenaRankingData()
        self:RecordArena()
    end
end

function ArenaStats:ARENA_OPPONENT_UPDATE(_, unit, updateReason)
    if updateReason == "seen" then
        ArenaStats:SpotEnemy(unit)
        ArenaStats:SetPartyData()
    end
end

function ArenaStats:SpotEnemy(unit)
    if UnitIsPlayer(unit) then
        local guid = UnitGUID(unit)
        local freshName, realm = UnitName(unit)
        if freshName == "Unknown" then freshName = "" end
        if (self.current["units"][guid] and
            not self:StringIsempty(self.current["units"][guid]["name"])) then
            freshName = self.current["units"][guid]["name"]
        end

        self.current["units"][guid] = {
            class = select(2, UnitClass(unit)),
            name = freshName,
            race = select(2, UnitRace(unit)),
            faction = select(2, UnitFactionGroup(unit))
        }
    end
end

function ArenaStats:SetPartyData()
    if self.current["stats"]["teamClass"] == nil then
        self.current["stats"]["teamClass"] = {}
    end
    if self.current["stats"]["teamCharName"] == nil then
        self.current["stats"]["teamCharName"] = {}
    end
    if self.current["stats"]["teamRace"] == nil then
        self.current["stats"]["teamRace"] = {}
    end

    self.current["stats"]["teamClass"][0] = select(2, UnitClass('player'))
    self.current["stats"]["teamCharName"][0] = UnitName("player")
    self.current["stats"]["teamRace"][0] = select(2, UnitRace("player"))

    if IsInGroup() then
        for i = 1, 4 do
            if UnitClass('party' .. i) then
                local _, englishClass = UnitClass('party' .. i)
                local partyPlayerName = UnitName('party' .. i)
                self.current["stats"]["teamClass"][i] = englishClass:upper()
                self.current["stats"]["teamCharName"][i] = partyPlayerName
                self.current["stats"]["teamRace"][i] = select(2, UnitRace(
                                                                  'party' .. i))
            end
        end
    end
end

function ArenaStats:Reset()
    self.arenaEnded = false
    self.current["status"] = "none"

    self.current["stats"] = {}
    self.current["units"] = {}
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
                _G.InterfaceOptionsFrame_OpenToCategory(addonName)
                _G.InterfaceOptionsFrame_OpenToCategory(addonName)
            else
                ArenaStats:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(string.format("%s |cff777777v%s|r", addonTitle,
                                          "0.7.6"))
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

    local ts = 0
    for i=0, 5 do
        if row["teamClass"][i] ~= nil then
            ts = ts + 1
        end
    end
    return ts
end

function ArenaStats:BuildTable()
    local tbl = {}

    local tableLength = #self.db.char.history

    for i = 1, tableLength do
        local row = self.db.char.history[tableLength + 1 - i]
        table.insert(tbl, {

            -- Common stats

            ["startTime"] = row["startTime"],
            ["endTime"] = row["endTime"],
            ["zoneId"] = row["zoneId"],
            ["isRanked"] = row["isRanked"],
            ["teamSize"] = ArenaStats:CalculateTeamSize(row),
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

            ["oldTeamRating"] = row["oldTeamRating"],
            ["newTeamRating"] = row["newTeamRating"],
            ["diffRating"] = row["diffRating"],
            ["mmr"] = row["mmr"],

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
            ["enemyFaction"] = row["enemyFaction"],

            ["enemyOldTeamRating"] = row["enemyOldTeamRating"],
            ["enemyNewTeamRating"] = row["enemyNewTeamRating"],
            ["enemyDiffRating"] = row["enemyDiffRating"],
            ["enemyMmr"] = row["enemyMmr"]

        })
    end
    return tbl
end

function ArenaStats:ZoneId(zoneName, x)
    if zoneName == L["Nagrand Arena"] then
        return 3698
    elseif zoneName == L["Blade's Edge Arena"] then
        return 3702
    elseif zoneName == L["Ruins of Lordaeron"] then
        return 3968
    end
    return nil
end

function ArenaStats:ZoneNameShort(zoneId)
    if zoneId == 3698 then
        return L["NA"]
    elseif zoneId == 3702 then
        return L["BEA"]
    elseif zoneId == 3968 then
        return L["RoL"]
    end
    return nil
end

function ArenaStats:ZoneName(zoneId)
    if zoneId == 3698 then
        return L["Nagrand Arena"]
    elseif zoneId == 3702 then
        return L["Blade's Edge Arena"]
    elseif zoneId == 3968 then
        return L["Ruins of Lordaeron"]
    end
    return nil
end

function ArenaStats:ResetDatabase()
    self.db:ResetDB()
    self:Print(L["Database reset"])
end

function ArenaStats:ExportCSV()

    local csv = "isRanked,startTime,endTime,zoneId,duration,teamName," ..
                    "teamPlayerName1,teamPlayerName2,teamPlayerName3,teamPlayerName4,teamPlayerName5," ..
                    "teamPlayerClass1,teamPlayerClass2,teamPlayerClass3,teamPlayerClass4,teamPlayerClass5," ..
                    "teamPlayerRace1,teamPlayerRace2,teamPlayerRace3,teamPlayerRace4,teamPlayerRace5," ..
                    "oldTeamRating,newTeamRating,diffRating,mmr," ..
                    "enemyOldTeamRating,enemyNewTeamRating,enemyDiffRating,enemyMmr,enemyTeamName," ..
                    "enemyPlayerName1,enemyPlayerName2,enemyPlayerName3,enemyPlayerName4,enemyPlayerName5," ..
                    "enemyPlayerClass1,enemyPlayerClass2,enemyPlayerClass3,enemyPlayerClass4,enemyPlayerClass5," ..
                    "enemyPlayerRace1,enemyPlayerRace2,enemyPlayerRace3,enemyPlayerRace4,enemyPlayerRace5,enemyFaction" ..
                    "\n"

    for _, row in ipairs(self.db.char.history) do
        csv = csv .. (self:YesOrNo(row["isRanked"])) .. "," ..
                  (row["startTime"] ~= nil and row["startTime"] or "") .. "," ..
                  (row["endTime"] ~= nil and row["endTime"] or "") .. "," ..
                  (row["zoneId"] ~= nil and row["zoneId"] or "") .. "," ..
                  (row["startTime"] ~= nil and row["endTime"] ~= nil and
                      row["endTime"] - row["startTime"] or "") .. "," ..

                  (row["teamName"] ~= nil and row["teamName"] or "") .. "," ..

                  (row["teamCharName"] and row["teamCharName"][0] ~= nil and
                      row["teamCharName"][0] or "") .. "," ..
                  (row["teamCharName"] and row["teamCharName"][1] ~= nil and
                      row["teamCharName"][1] or "") .. "," ..
                  (row["teamCharName"] and row["teamCharName"][2] ~= nil and
                      row["teamCharName"][2] or "") .. "," ..
                  (row["teamCharName"] and row["teamCharName"][3] ~= nil and
                      row["teamCharName"][3] or "") .. "," ..
                  (row["teamCharName"] and row["teamCharName"][4] ~= nil and
                      row["teamCharName"][4] or "") .. "," ..
                  (row["teamClass"] and row["teamClass"][0] ~= nil and
                      row["teamClass"][0] or "") .. "," ..
                  (row["teamClass"] and row["teamClass"][1] ~= nil and
                      row["teamClass"][1] or "") .. "," ..
                  (row["teamClass"] and row["teamClass"][2] ~= nil and
                      row["teamClass"][2] or "") .. "," ..
                  (row["teamClass"] and row["teamClass"][3] ~= nil and
                      row["teamClass"][3] or "") .. "," ..
                  (row["teamClass"] and row["teamClass"][4] ~= nil and
                      row["teamClass"][4] or "") .. "," ..
                  (row["teamRace"] and row["teamRace"][0] ~= nil and
                      row["teamRace"][0] or "") .. "," ..
                  (row["teamRace"] and row["teamRace"][1] ~= nil and
                      row["teamRace"][1] or "") .. "," ..
                  (row["teamRace"] and row["teamRace"][2] ~= nil and
                      row["teamRace"][2] or "") .. "," ..
                  (row["teamRace"] and row["teamRace"][3] ~= nil and
                      row["teamRace"][3] or "") .. "," ..
                  (row["teamRace"] and row["teamRace"][4] ~= nil and
                      row["teamRace"][4] or "") .. "," ..

                  (self:ComputeSafeNumber(row["oldTeamRating"])) .. "," ..
                  (self:ComputeSafeNumber(row["newTeamRating"])) .. "," ..
                  (self:ComputeSafeNumber(row["diffRating"])) .. "," ..
                  (self:ComputeSafeNumber(row["mmr"])) .. "," ..

                  (self:ComputeSafeNumber(row["enemyOldTeamRating"])) .. "," ..
                  (self:ComputeSafeNumber(row["enemyNewTeamRating"])) .. "," ..
                  (self:ComputeSafeNumber(row["enemyDiffRating"])) .. "," ..
                  (self:ComputeSafeNumber(row["enemyMmr"])) .. "," ..

                  (row["enemyTeamName"] ~= nil and row["enemyTeamName"] or "") ..
                  "," ..

                  (row["enemyName"] and row["enemyName"][0] ~= nil and
                      row["enemyName"][0] or "") .. "," ..
                  (row["enemyName"] and row["enemyName"][1] ~= nil and
                      row["enemyName"][1] or "") .. "," ..
                  (row["enemyName"] and row["enemyName"][2] ~= nil and
                      row["enemyName"][2] or "") .. "," ..
                  (row["enemyName"] and row["enemyName"][3] ~= nil and
                      row["enemyName"][3] or "") .. "," ..
                  (row["enemyName"] and row["enemyName"][4] ~= nil and
                      row["enemyName"][4] or "") .. "," ..
                  (row["enemyClass"] and row["enemyClass"][0] ~= nil and
                      row["enemyClass"][0] or "") .. "," ..
                  (row["enemyClass"] and row["enemyClass"][1] ~= nil and
                      row["enemyClass"][1] or "") .. "," ..
                  (row["enemyClass"] and row["enemyClass"][2] ~= nil and
                      row["enemyClass"][2] or "") .. "," ..
                  (row["enemyClass"] and row["enemyClass"][3] ~= nil and
                      row["enemyClass"][3] or "") .. "," ..
                  (row["enemyClass"] and row["enemyClass"][4] ~= nil and
                      row["enemyClass"][4] or "") .. "," ..
                  (row["enemyRace"] and row["enemyRace"][0] ~= nil and
                      row["enemyRace"][0] or "") .. "," ..
                  (row["enemyRace"] and row["enemyRace"][1] ~= nil and
                      row["enemyRace"][1] or "") .. "," ..
                  (row["enemyRace"] and row["enemyRace"][2] ~= nil and
                      row["enemyRace"][2] or "") .. "," ..
                  (row["enemyRace"] and row["enemyRace"][3] ~= nil and
                      row["enemyRace"][3] or "") .. "," ..
                  (row["enemyRace"] and row["enemyRace"][4] ~= nil and
                      row["enemyRace"][4] or "") .. "," ..
                  (self:ComputeFaction(row["enemyFaction"])) .. "," .. "\n"
    end

    ArenaStats:ExportFrame().eb:SetText(csv)
    ArenaStats:ExportFrame():Show()
    ArenaStats:ExportFrame().eb:SetFocus()
    ArenaStats:ExportFrame().eb:HighlightText(0, ArenaStats:ExportFrame().eb
                                                  .editBox:GetNumLetters())
end

function ArenaStats:Has_value(tab, val)
    for index, value in ipairs(tab) do if value == val then return true end end
    return false
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

function ArenaStats:StringIsempty(s) return s == nil or s == '' end
