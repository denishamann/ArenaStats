local _G = _G
local addonName = "ArenaStats"
local addonTitle = select(2, C_AddOns.GetAddOnInfo(addonName))
local ArenaStats = _G.LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceGUI = _G.LibStub("AceGUI-3.0")
local sbyte = _G.string.byte

local filters, asGui
local rows, filtered

-- Reusable tables to avoid garbage collection pressure during scroll refresh
local reusableTeamClassSpec = {{}, {}, {}, {}, {}}
local reusableEnemyClassSpec = {{}, {}, {}, {}, {}}
local reusableTeamPlayerNames = {}
local reusableEnemyPlayerNames = {}

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
        startIndex = startIndex + self:CSize(char)
        startChar = startChar - 1
    end
    local currentIndex = startIndex
    while numChars > 0 and currentIndex <= #str do
        local char = sbyte(str, currentIndex)
        currentIndex = currentIndex + self:CSize(char)
        numChars = numChars - 1
    end
    return str:sub(startIndex, currentIndex - 1)
end

function ArenaStats:CreateShortMapName(mapName)
    local mapNameTemp = {strsplit(" ", mapName)}
    local mapShortName = ""
    for i = 1, #mapNameTemp do
        mapShortName = mapShortName .. self:StrSub(mapNameTemp[i], 0, 1)
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

    self:CreateScoreButton(tableHeader, 145, "Date")
    self:CreateScoreButton(tableHeader, 40, "Map")
    self:CreateScoreButton(tableHeader, 94, "Duration")
    self:CreateScoreButton(tableHeader, 100, "Team")
    self:CreateScoreButton(tableHeader, 64, "Rating")
    self:CreateScoreButton(tableHeader, 40, "MMR")
    self:CreateScoreButton(tableHeader, 100, "Enemy Team")
    self:CreateScoreButton(tableHeader, 75, "Enemy MMR")
    self:CreateScoreButton(tableHeader, 80, "Enemy Faction")

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
    local lowerFilter = filters.name:lower()
    for i = 1, 5 do
        local name = row["enemyPlayerName" .. i]
        if name and name:lower():find(lowerFilter, 1, true) then
            return false
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

-- Helper to populate reusable class/spec table
local function populateClassSpecTable(tbl, row, prefix)
    for i = 1, 5 do
        tbl[i].class = row[prefix .. "Class" .. i]
        tbl[i].spec = row[prefix .. "Spec" .. i]
    end
end

-- Helper to check if any enemies exist in the class/spec table
local function hasAnyClassOrSpec(tbl)
    for i = 1, 5 do
        if tbl[i].class or tbl[i].spec then
            return true
        end
    end
    return false
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
            
            -- Nil protection for date display
            if row["endTime"] then
                button.Date:SetText(_G.date(L["%F %T"], row["endTime"]))
            else
                button.Date:SetText("-")
            end
            
            button.Map:SetText(self:GetShortMapName(row["zoneId"]))
            button.Duration:SetText(self:HumanDuration(row["duration"]))
            
            -- Reuse team class/spec table instead of creating new ones
            populateClassSpecTable(reusableTeamClassSpec, row, "teamPlayer")

            table.sort(reusableTeamClassSpec, function(a, b)
                return self:SortClassSpecTable(a, b)
            end)

            -- Populate reusable name tables for tooltip
            for i = 1, 5 do
                reusableTeamPlayerNames[i] = row["teamPlayerName" .. i]
                reusableEnemyPlayerNames[i] = row["enemyPlayerName" .. i]
            end
            
            -- Capture current names for this button's tooltip (needed for closure)
            local tooltipTeamNames = {unpack(reusableTeamPlayerNames)}
            local tooltipEnemyNames = {unpack(reusableEnemyPlayerNames)}
            
            button:SetScript("OnEnter", function(self)
                ArenaStats:ShowTooltip(self, tooltipTeamNames, tooltipEnemyNames)
            end)
            button:SetScript("OnLeave", function()
                ArenaStats:HideTooltip()
            end)

            button.IconTeamPlayerClass1:SetTexture(self:ClassIconId(reusableTeamClassSpec[1]))
            button.IconTeamPlayerClass2:SetTexture(self:ClassIconId(reusableTeamClassSpec[2]))
            button.IconTeamPlayerClass3:SetTexture(self:ClassIconId(reusableTeamClassSpec[3]))
            button.IconTeamPlayerClass4:SetTexture(self:ClassIconId(reusableTeamClassSpec[4]))
            button.IconTeamPlayerClass5:SetTexture(self:ClassIconId(reusableTeamClassSpec[5]))

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

            -- Reuse enemy class/spec table instead of creating new ones
            populateClassSpecTable(reusableEnemyClassSpec, row, "enemyPlayer")

            -- Don't sort if match ends immediately due to no enemies (otherwise gui crashes)
            if hasAnyClassOrSpec(reusableEnemyClassSpec) then
                table.sort(reusableEnemyClassSpec, function(a, b)
                    return self:SortClassSpecTable(a, b)
                end)
            end

            button.IconEnemyPlayer1:SetTexture(self:ClassIconId(reusableEnemyClassSpec[1]))
            button.IconEnemyPlayer2:SetTexture(self:ClassIconId(reusableEnemyClassSpec[2]))
            button.IconEnemyPlayer3:SetTexture(self:ClassIconId(reusableEnemyClassSpec[3]))
            button.IconEnemyPlayer4:SetTexture(self:ClassIconId(reusableEnemyClassSpec[4]))
            button.IconEnemyPlayer5:SetTexture(self:ClassIconId(reusableEnemyClassSpec[5]))

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

    rows = self:BuildTable()

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

-- Spec icon lookup table: [class][spec] = iconId, with "default" for class icon
local SPEC_ICONS = {
    MAGE = {
        Frost = 135846, Fire = 135809, Arcane = 135932,
        default = 626001
    },
    PRIEST = {
        Shadow = 136207, Holy = 237542, Discipline = 135940,
        default = 626004
    },
    DRUID = {
        Restoration = 136041, Feral = 136112, Balance = 136096,
        default = 625999
    },
    SHAMAN = {
        Restoration = 136052, Elemental = 136048, Enhancement = 136051,
        default = 626006
    },
    PALADIN = {
        Retribution = 135873, Holy = 135920, Protection = 236264,
        default = 626003
    },
    WARLOCK = {
        Affliction = 136145, Demonology = 136172, Destruction = 136186,
        default = 626007
    },
    WARRIOR = {
        Arms = 132355, Fury = 132347, Protection = 132341,
        default = 626008
    },
    HUNTER = {
        BeastMastery = 461112, Marksmanship = 236179, Survival = 461113,
        default = 626000
    },
    ROGUE = {
        Assassination = 132292, Combat = 132090, Subtlety = 132320,
        default = 626005
    },
    DEATHKNIGHT = {
        Frost = 135773, Unholy = 135775, Blood = 135770,
        default = 135771
    },
}

function ArenaStats:ClassIconId(classSpec)
    if not classSpec then
        return 0
    end

    local className = classSpec.class
    local classIcons = SPEC_ICONS[className]
    if not classIcons then
        return 0
    end

    local spec = classSpec.spec
    if not self.db.profile.showSpec or not spec then
        return classIcons.default
    end

    return classIcons[spec] or classIcons.default
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
    if self:ShouldShowCharacterNamesTooltips() then
        AceGUI.tooltip:Show()
    end
end

function ArenaStats:HideTooltip() AceGUI.tooltip:Hide() end

function ArenaStats:ExportFrame() return asGui.exportFrame end

function ArenaStats:ExportEditBox() return asGui.exportEditBox end
