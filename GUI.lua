local _G = _G
local addonName = "ArenaStats"
local addonTitle = select(2, _G.GetAddOnInfo(addonName))
local ArenaStats = _G.LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceGUI = _G.LibStub("AceGUI-3.0")
local sbyte = _G.string.byte

local filters, asGui
local rows, filtered

function ArenaStats:CSize(char)
    if not char then
        return 0
    elseif char > 240 then
        return 4
    elseif char > 225 then
        return 3
    elseif char > 192 then
        return 2
    else
        return 1
    end
end

function ArenaStats:StrSub(str, startChar, numChars)
    local startIndex = 1
    while startChar > 1 do
        local char = sbyte(str, startIndex)
        startIndex = startIndex + ArenaStats:CSize(char)
        startChar = startChar - 1
    end
    local currentIndex = startIndex
    while numChars > 0 and currentIndex <= #str do
        local char = sbyte(str, currentIndex)
        currentIndex = currentIndex + ArenaStats:CSize(char)
        numChars = numChars - 1
    end
    return str:sub(startIndex, currentIndex - 1)
end

function ArenaStats:CreateShortMapName(mapName)
    local mapNameTemp = {strsplit(" ", mapName)}
    local mapShortName = ""
    for i = 1, #mapNameTemp do
        mapShortName = mapShortName .. ArenaStats:StrSub(mapNameTemp[i], 0, 1)
    end
    return mapShortName
end

ArenaStats.mapListShortName = {
    [559] = ArenaStats:CreateShortMapName(GetRealZoneText(559)),
    [562] = ArenaStats:CreateShortMapName(GetRealZoneText(562)),
    [572] = ArenaStats:CreateShortMapName(GetRealZoneText(572)),
    [617] = ArenaStats:CreateShortMapName(GetRealZoneText(617)),
    [618] = ArenaStats:CreateShortMapName(GetRealZoneText(618))
}

function ArenaStats:CreateGUI()
    asGui = {}
    filters = {}
    filtered = {}
    rows = {}

    filters.bracket = 0
    filters.arenaType = 0
    filters.name = ""

    asGui.f = AceGUI:Create("Frame")
    asGui.f:Hide()
    asGui.f:SetWidth(859)
    asGui.f:EnableResize(false)

    asGui.f:SetTitle(addonTitle)
    asGui.f:SetStatusText("Status Bar")
    asGui.f:SetLayout("Flow")

    table.insert(_G.UISpecialFrames, "AsFrame")
    _G.AsFrame = asGui.f

    local exportButton = AceGUI:Create("Button")
    exportButton:SetWidth(100)
    exportButton:SetText(string.format(" %s ", L["Export"]))
    exportButton:SetCallback("OnClick", function() ArenaStats:ExportCSV() end)
    asGui.f:AddChild(exportButton)

    local exportTool = AceGUI:Create("Button")
    exportTool:SetWidth(120)
    exportTool:SetText(string.format(" %s ", L["Tool Website"]))
    exportTool:SetCallback("OnClick", function() ArenaStats:WebsiteURL() end)
    asGui.f:AddChild(exportTool)

    local bracketSizeDropdown = AceGUI:Create("Dropdown")
    bracketSizeDropdown:SetWidth(80)
    bracketSizeDropdown:SetCallback("OnValueChanged", function(_, _, val)
        ArenaStats:OnBracketChange(val)
    end)
    bracketSizeDropdown:SetList({
        [0] = _G.ALL,
        [2] = "2v2",
        [3] = "3v3",
        [5] = "5v5"
    })
    bracketSizeDropdown:SetValue(filters.bracket)
    asGui.f:AddChild(bracketSizeDropdown)

    local arenaTypeDropdown = AceGUI:Create("Dropdown")
    arenaTypeDropdown:SetWidth(100)
    arenaTypeDropdown:SetCallback("OnValueChanged", function(_, _, val)
        ArenaStats:OnArenaTypeChange(val)
    end)
    arenaTypeDropdown:SetList({
        [0] = _G.ALL,
        [true] = _G.ARENA_RATED,
        [false] = _G.ARENA_CASUAL
    })
    arenaTypeDropdown:SetValue(filters.arenaType)
    asGui.f:AddChild(arenaTypeDropdown)

    local nameFilter = AceGUI:Create("EditBox")
    nameFilter:SetLabel(L["Filter By Name"])
    nameFilter:SetWidth(150)
    nameFilter:SetCallback("OnEnterPressed", function(widget, event, text)
        self:OnFilterNameChange(text)
    end)
    asGui.f:AddChild(nameFilter)

    -- TABLE HEADER
    local tableHeader = AceGUI:Create("SimpleGroup")
    tableHeader:SetFullWidth(true)
    tableHeader:SetLayout("Flow")
    asGui.f:AddChild(tableHeader)

    local margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

    ArenaStats:CreateScoreButton(tableHeader, 145, "Date")
    ArenaStats:CreateScoreButton(tableHeader, 40, "Map")
    ArenaStats:CreateScoreButton(tableHeader, 94, "Duration")
    ArenaStats:CreateScoreButton(tableHeader, 100, "Team")
    ArenaStats:CreateScoreButton(tableHeader, 64, "Rating")
    ArenaStats:CreateScoreButton(tableHeader, 40, "MMR")
    ArenaStats:CreateScoreButton(tableHeader, 100, "Enemy Team")
    ArenaStats:CreateScoreButton(tableHeader, 75, "Enemy MMR")
    ArenaStats:CreateScoreButton(tableHeader, 80, "Enemy Faction")

    -- TABLE
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    asGui.f:AddChild(scrollContainer)

    asGui.scrollFrame = _G.CreateFrame("ScrollFrame", nil,
                                       scrollContainer.frame,
                                       "ArenaStatsHybridScrollFrame")
    _G.HybridScrollFrame_CreateButtons(asGui.scrollFrame,
                                       "ArenaStatsHybridScrollListItemTemplate")
    asGui.scrollFrame.update = function() ArenaStats:UpdateTableView() end

    -- Export frame

    asGui.exportFrame = AceGUI:Create("Frame")
    asGui.exportFrame:SetWidth(550)
    asGui.exportFrame.sizer_se:Hide()
    asGui.exportFrame:SetStatusText("")
    asGui.exportFrame:SetLayout("Flow")
    asGui.exportFrame:SetTitle(L["Export"])
    asGui.exportFrame:Hide()

    asGui.exportEditBox = AceGUI:Create("MultiLineEditBox")
    asGui.exportEditBox:SetLabel("Export String")
    asGui.exportEditBox:SetNumLines(29)
    asGui.exportEditBox:SetText("")
    asGui.exportEditBox:SetWidth(500)
    asGui.exportEditBox.button:Hide()
    asGui.exportEditBox.frame:SetClipsChildren(true)
    asGui.exportFrame:AddChild(asGui.exportEditBox)
    asGui.exportFrame.eb = asGui.exportEditBox
end

function ArenaStats:UpdateTableView() self:RefreshLayout() end

function ArenaStats:OnBracketChange(key)
    filters.bracket = key
    self:SortTable()
    self:UpdateTableView()
end

function ArenaStats:OnArenaTypeChange(key)
    filters.arenaType = key
    self:SortTable()
    self:UpdateTableView()
end

function ArenaStats:OnFilterNameChange(text)
    filters.name = text
    self:SortTable()
    self:UpdateTableView()
end

function ArenaStats:CreateScoreButton(tableHeader, width, localeStr)
    local btn = AceGUI:Create("Label")
    btn:SetWidth(width)
    btn:SetText(string.format(" %s ", L[localeStr]))
    btn:SetJustifyH("LEFT")
    tableHeader:AddChild(btn)
    local margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)
end

function ArenaStats:EnemyNameFilterRow(row)
    if filters.name == "" then
        return false
    end
    for category, val in pairs(row) do
        -- find player names within the row
        if (type(val) == "string" and category:sub(1, #"enemyPlayerName") == "enemyPlayerName") then
            -- if the filter.name value is anywhere within a substring of the player names
            if (string.find(val:lower(), filters.name:lower(), 1, true)) then
                return false
            end
        end
    end
    return true
end

function ArenaStats:FilterRow(row)
    if (filters.bracket ~= 0 and row["teamSize"] ~= filters.bracket) then
        return true
    end
    if (filters.arenaType ~= 0 and row["isRanked"] ~= filters.arenaType) then
        return true
    end
    if (self:EnemyNameFilterRow(row)) then
        return true
    end
    return false
end

function ArenaStats:SortTable()
    filtered = {}
    for i = 1, #rows do
        local row = rows[i]
        if (not self:FilterRow(row)) then table.insert(filtered, row) end
    end
end




function ArenaStats:SortClassSpecTable(a, b)
    -- Sort nils to the end of the list
    -- Healer specs pushed to the end (before nils)
    -- If no spec then sort by class as before
    if not a or not b then
        return not b
    end
    if not a.class or not b.class then
        return not b.class
    end
    if not a.spec or not b.spec then
        return a.class < b.class
    end
    if self:IsHealerSpec(a.spec) and not self:IsHealerSpec(b.spec) then
        return false
    end
    if not self:IsHealerSpec(a.spec) and self:IsHealerSpec(b.spec) then
        return true
    end
    
    return a.class < b.class
end

function ArenaStats:IsHealerSpec(spec) 
    return spec == "Restoration" or spec == "Discipline" or spec == "Holy"
end

function ArenaStats:RefreshLayout()
    local buttons = _G.HybridScrollFrame_GetButtons(asGui.scrollFrame)
    local offset = _G.HybridScrollFrame_GetOffset(asGui.scrollFrame)

    asGui.f:SetStatusText(string.format(L["Recorded %i arenas"], #rows))

    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex]
        local itemIndex = buttonIndex + offset
        local row = filtered[itemIndex]

        if (itemIndex <= #filtered) then
            button:SetID(itemIndex)
            button.Date:SetText(_G.date(L["%F %T"], row["endTime"]))
            button.Map:SetText(self:GetShortMapName(row["zoneId"]))
            button.Duration:SetText(self:HumanDuration(row["duration"]))
            local teamClasses = {
                row["teamPlayerClass1"], row["teamPlayerClass2"],
                row["teamPlayerClass3"], row["teamPlayerClass4"],
                row["teamPlayerClass5"]
            }

            local teamSpecs = {
                row["teamPlayerSpec1"], row["teamPlayerSpec2"],
                row["teamPlayerSpec3"], row["teamPlayerSpec4"],
                row["teamPlayerSpec5"]
            }

            local teamClassSpec = {
                { class = teamClasses[1], spec = teamSpecs[1] },
                { class = teamClasses[2], spec = teamSpecs[2] },
                { class = teamClasses[3], spec = teamSpecs[3] },
                { class = teamClasses[4], spec = teamSpecs[4] },
                { class = teamClasses[5], spec = teamSpecs[5] }
            }

            table.sort(teamClassSpec, function(a, b)
                return self:SortClassSpecTable(a, b)
            end)

            local teamPlayerNames = {
                row["teamPlayerName1"], row["teamPlayerName2"],
                row["teamPlayerName3"], row["teamPlayerName4"],
                row["teamPlayerName5"]
            }
            local enemyPlayerNames = {
                row["enemyPlayerName1"], row["enemyPlayerName2"],
                row["enemyPlayerName3"], row["enemyPlayerName4"],
                row["enemyPlayerName5"]
            }
            button:SetScript("OnEnter", function(self)
                ArenaStats:ShowTooltip(self, teamPlayerNames, enemyPlayerNames)
            end)
            button:SetScript("OnLeave", function()
                ArenaStats:HideTooltip()
            end)

            button.IconTeamPlayerClass1:SetTexture(self:ClassIconId(teamClassSpec[1]))
            button.IconTeamPlayerClass2:SetTexture(self:ClassIconId(teamClassSpec[2]))
            button.IconTeamPlayerClass3:SetTexture(self:ClassIconId(teamClassSpec[3]))
            button.IconTeamPlayerClass4:SetTexture(self:ClassIconId(teamClassSpec[4]))
            button.IconTeamPlayerClass5:SetTexture(self:ClassIconId(teamClassSpec[5]))

            button.Rating:SetText((row["newTeamRating"] or "-") .. " (" ..
                                      ((row["diffRating"] and row["diffRating"] >
                                          0 and "+" .. row["diffRating"] or
                                          row["diffRating"]) or "0") .. ")")

            button.Rating:SetTextColor(self:ColorForRating(row["diffRating"]))

            if (row["teamColor"] ~= nil and row["winnerColor"] ~= nil) then
                if (row["teamColor"] ~= row["winnerColor"]) then
                    button.Rating:SetTextColor(255, 0, 0, 1)
                else
                    button.Rating:SetTextColor(0, 255, 0, 1)
                end
            end
            button.MMR:SetText(row["mmr"] or "-")

            local enemyClasses = {
                row["enemyPlayerClass1"], row["enemyPlayerClass2"],
                row["enemyPlayerClass3"], row["enemyPlayerClass4"],
                row["enemyPlayerClass5"]
            }

            local enemySpecs = {
                row["enemyPlayerSpec1"], row["enemyPlayerSpec2"],
                row["enemyPlayerSpec3"], row["enemyPlayerSpec4"],
                row["enemyPlayerSpec5"]
            }

            local enemyClassSpec = {
                { class = enemyClasses[1], spec = enemySpecs[1] },
                { class = enemyClasses[2], spec = enemySpecs[2] },
                { class = enemyClasses[3], spec = enemySpecs[3] },
                { class = enemyClasses[4], spec = enemySpecs[4] },
                { class = enemyClasses[5], spec = enemySpecs[5] }
            }

            table.sort(enemyClassSpec, function(a, b)
                return self:SortClassSpecTable(a, b)
            end)

            button.IconEnemyPlayer1:SetTexture(self:ClassIconId(enemyClassSpec[1]))
            button.IconEnemyPlayer2:SetTexture(self:ClassIconId(enemyClassSpec[2]))
            button.IconEnemyPlayer3:SetTexture(self:ClassIconId(enemyClassSpec[3]))
            button.IconEnemyPlayer4:SetTexture(self:ClassIconId(enemyClassSpec[4]))
            button.IconEnemyPlayer5:SetTexture(self:ClassIconId(enemyClassSpec[5]))

            button.EnemyMMR:SetText(row["enemyMmr"] or "-")

            button.EnemyFaction:SetTexture(self:FactionIconId(
                                               row["enemyFaction"]))

            button:SetWidth(asGui.scrollFrame.scrollChild:GetWidth())
            button:Show()
        else
            button:Hide()
        end
    end

    local buttonHeight = asGui.scrollFrame.buttonHeight
    local totalHeight = #filtered * buttonHeight
    local shownHeight = #buttons * buttonHeight

    _G.HybridScrollFrame_Update(asGui.scrollFrame, totalHeight, shownHeight)
end

function ArenaStats:Show()
    if not _G.AsFrame then self:CreateGUI() end

    rows = ArenaStats:BuildTable()

    self:SortTable()
    self:RefreshLayout()
    _G.AsFrame:Show()
end

function ArenaStats:Hide() _G.AsFrame:Hide() end

function ArenaStats:Toggle()
    if _G.AsFrame and _G.AsFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function ArenaStats:HumanDuration(seconds)
    if seconds < 60 then return string.format(L["%is"], seconds) end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then
        return string.format(L["%im %is"], minutes, (seconds - minutes * 60))
    end
    local hours = math.floor(minutes / 60)
    return string.format(L["%ih %im"], hours, (minutes - hours * 60))
end

function ArenaStats:ClassIconId(classSpec)
    if not classSpec then
        return 0
    end

    local spec = classSpec.spec
    local className = classSpec.class

    if self.db.profile.showSpec.hide then
        spec = "" 
    end

    if not spec then
        spec = ""
    end

    if className == "MAGE" then
        if spec == "Frost" then
            return 135846
        end
        if spec == "Fire" then
            return 135809
        end
        if spec == "Arcane" then
            return 135932
        end
        return 626001
    elseif className == "PRIEST" then
        if spec == "Shadow" then
            return 136207
        end
        if spec == "Holy" then
            return 237542
        end
        if spec == "Discipline" then
            return 135940
        end
        return 626004
    elseif className == "DRUID" then
        if spec == "Restoration" then
            return 136041
        end
        if spec == "Feral" then
            return 136112
        end
        if spec == "Balance" then
            return 136096
        end
        return 625999
    elseif className == "SHAMAN" then
        if spec == "Restoration" then
            return 136052
        end
        if spec == "Elemental" then
            return 136048
        end
        if spec == "Enhancement" then
            return 136051
        end
        return 626006
    elseif className == "PALADIN" then
        if spec == "Retribution" then
            return 135873
        end
        if spec == "Holy" then
            return 135920
        end
        if spec == "Protection" then
            return 236264
        end
        return 626003
    elseif className == "WARLOCK" then
        if spec == "Affliction" then
            return 136145
        end
        if spec == "Demonology" then
            return 136172
        end
        if spec == "Destruction" then
            return 136186
        end
        return 626007
    elseif className == "WARRIOR" then
        if spec == "Arms" then
            return 132355
        end
        if spec == "Fury" then
            return 132347
        end
        if spec == "Protection" then
            return 132341
        end
        return 626008
    elseif className == "HUNTER" then
        if spec == "BeastMastery" then
            return 461112
        end
        if spec == "Marksmanship" then
            return 236179
        end
        if spec == "Survival" then
            return 461113
        end
        return 626000
    elseif className == "ROGUE" then
        if spec == "Assassination" then
            return 132292
        end
        if spec == "Combat" then
            return 132090
        end
        if spec == "Subtlety" then
            return 132320
        end
        return 626005
    elseif className == "DEATHKNIGHT" then
        if spec == "Frost" then
            return 135773
        end
        if spec == "Unholy" then
            return 135775
        end
        if spec == "Blood" then
            return 135770
        end
        return 135771
    end
end

function ArenaStats:FactionIconId(factionId)
    if not factionId then return 0 end

    if factionId == 0 then
        return 132485
    else
        return 132486
    end
end

function ArenaStats:ColorForRating(rating)
    if not rating or rating == 0 then return 255, 255, 255, 1 end

    if rating < 0 then
        return 255, 0, 0, 1
    else
        return 0, 255, 0, 1
    end
end

function ArenaStats:GetShortMapName(id)
    local name = ArenaStats.mapListShortName[id]
    if name then
        return name
    elseif id then
        return "E" .. id
    else
        return "E"
    end
end

function ArenaStats:ShowTooltip(owner, teamPlayerNames, enemyPlayerNames)
    AceGUI.tooltip:SetOwner(owner, "ANCHOR_TOP")
    AceGUI.tooltip:ClearLines()
    AceGUI.tooltip:AddLine(L["Names"])
    for i, name in ipairs(teamPlayerNames) do
        AceGUI.tooltip:AddLine(name, 0, 1, 0)
    end
    AceGUI.tooltip:AddLine('---------------')
    for i, name in ipairs(enemyPlayerNames) do
        AceGUI.tooltip:AddLine(name, 1, 0, 0)
    end
    if (ArenaStats:ShouldHideCharacterNamesTooltips()) then
        AceGUI.tooltip:Show()
    end
end

function ArenaStats:HideTooltip() AceGUI.tooltip:Hide() end

function ArenaStats:ExportFrame() return asGui.exportFrame end

function ArenaStats:ExportEditBox() return asGui.exportEditBox end
