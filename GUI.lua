local _G = _G
local addonName = "ArenaStatsTBC"
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
    [572] = ArenaStats:CreateShortMapName(GetRealZoneText(572))
}

function ArenaStats:CreateGUI()
    asGui = {}
    filters = {}
    filtered = {}
    rows = {}

    filters.bracket = 0
    filters.arenaType = 0

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
    asGui.exportEditBox:SetLabel('ExportString')
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

function ArenaStats:FilterRow(row)
    if (filters.bracket ~= 0 and row["teamSize"] ~= filters.bracket) then
        return true
    end
    if (filters.arenaType ~= 0 and row["isRanked"] ~= filters.arenaType) then
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

function ArenaStats:SortClassTable(a, b)
    -- regular sort, pushes nils to end
    if (not a or not b) then
        return not b
    else
        return a < b
    end
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
            table.sort(teamClasses, function(a, b)
                return ArenaStats:SortClassTable(a, b)
            end)

            button.IconTeamPlayerClass1:SetTexture(self:ClassIconId(
                                                       teamClasses[1]))
            button.IconTeamPlayerClass2:SetTexture(self:ClassIconId(
                                                       teamClasses[2]))
            button.IconTeamPlayerClass3:SetTexture(self:ClassIconId(
                                                       teamClasses[3]))
            button.IconTeamPlayerClass4:SetTexture(self:ClassIconId(
                                                       teamClasses[4]))
            button.IconTeamPlayerClass5:SetTexture(self:ClassIconId(
                                                       teamClasses[5]))
            button.Rating:SetText((row["newTeamRating"] or "-") .. " (" ..
                                      ((row["diffRating"] and row["diffRating"] >
                                          0 and "+" .. row["diffRating"] or
                                          row["diffRating"]) or "0") .. ")")
            button.Rating:SetTextColor(self:ColorForRating(row["diffRating"]))
            button.MMR:SetText(row["mmr"] or "-")

            local enemyClasses = {
                row["enemyPlayerClass1"], row["enemyPlayerClass2"],
                row["enemyPlayerClass3"], row["enemyPlayerClass4"],
                row["enemyPlayerClass5"]
            }
            table.sort(enemyClasses, function(a, b)
                return ArenaStats:SortClassTable(a, b)
            end)

            button.IconEnemyPlayer1:SetTexture(self:ClassIconId(enemyClasses[1]))
            button.IconEnemyPlayer2:SetTexture(self:ClassIconId(enemyClasses[2]))
            button.IconEnemyPlayer3:SetTexture(self:ClassIconId(enemyClasses[3]))
            button.IconEnemyPlayer4:SetTexture(self:ClassIconId(enemyClasses[4]))
            button.IconEnemyPlayer5:SetTexture(self:ClassIconId(enemyClasses[5]))
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

function ArenaStats:ClassIconId(className)

    if not className then return 0 end

    if className == "MAGE" then
        return 626001
    elseif className == "PRIEST" then
        return 626004
    elseif className == "DRUID" then
        return 625999
    elseif className == "SHAMAN" then
        return 626006
    elseif className == "PALADIN" then
        return 626003
    elseif className == "WARLOCK" then
        return 626007
    elseif className == "WARRIOR" then
        return 626008
    elseif className == "HUNTER" then
        return 626000
    elseif className == "ROGUE" then
        return 626005
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
    else
        return "E" .. id
    end
end

function ArenaStats:ExportFrame() return asGui.exportFrame end
function ArenaStats:ExportEditBox() return asGui.exportEditBox end
