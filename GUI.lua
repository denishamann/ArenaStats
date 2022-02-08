local addonName = "ArenaStatsTBC"
local addonTitle = select(2, _G.GetAddOnInfo(addonName))
local ArenaStats = _G.LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceGUI = _G.LibStub("AceGUI-3.0")
local f, scrollFrame, rows, stats
local exportFrame, exportEditBox

function ArenaStats:CreateGUI()
    f = AceGUI:Create("Frame")
    f:Hide()
    f:SetWidth(859)
    f:EnableResize(false)

    f:SetTitle(addonTitle)
    local frameName = addonName .. "_MainFrame"
    _G[frameName] = f
    table.insert(_G.UISpecialFrames, frameName)
    f:SetStatusText("Status Bar")
    f:SetLayout("Flow")

    local exportButton = AceGUI:Create("Button")
    exportButton:SetWidth(100)
    exportButton:SetText(string.format(" %s ", L["Export"]))
    f:AddChild(exportButton)
    exportButton:SetCallback("OnClick", function() ArenaStats:ExportCSV() end)

    -- TABLE HEADER
    local tableHeader = AceGUI:Create("SimpleGroup")
    tableHeader:SetFullWidth(true)
    tableHeader:SetLayout("Flow")
    f:AddChild(tableHeader)

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
    f:AddChild(scrollContainer)

    scrollFrame = _G.CreateFrame("ScrollFrame", nil, scrollContainer.frame,
                                 "ArenaStatsHybridScrollFrame")
    _G.HybridScrollFrame_CreateButtons(scrollFrame,
                                       "ArenaStatsHybridScrollListItemTemplate")
    scrollFrame.update = function() ArenaStats:UpdateTableView() end

    -- Export frame

    exportFrame = AceGUI:Create("Frame")
    exportFrame:SetWidth(550)
    exportFrame.sizer_se:Hide()
    exportFrame:SetStatusText("")
    exportFrame:SetLayout("Flow")
    exportFrame:SetTitle(L["Export"])
    exportFrame:Hide()
    exportEditBox = AceGUI:Create("MultiLineEditBox")
    exportEditBox:SetLabel('ExportString')
    exportEditBox:SetNumLines(29)
    exportEditBox:SetText("")
    exportEditBox:SetWidth(500)
    exportEditBox.button:Hide()
    exportEditBox.frame:SetClipsChildren(true)
    exportFrame:AddChild(exportEditBox)
    exportFrame.eb = exportEditBox
end

function ArenaStats:UpdateTableView() self:RefreshLayout() end

function ArenaStats:CreateScoreButton(tableHeader, width, localeStr)
    btn = AceGUI:Create("Label")
    btn:SetWidth(width)
    btn:SetText(string.format(" %s ", L[localeStr]))
    btn:SetJustifyH("LEFT")
    tableHeader:AddChild(btn)
    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)
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
    local buttons = _G.HybridScrollFrame_GetButtons(scrollFrame)
    local offset = _G.HybridScrollFrame_GetOffset(scrollFrame)

    f:SetStatusText(string.format(L["Recorded %i arenas"], #rows))

    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex]
        local itemIndex = buttonIndex + offset
        local row = rows[itemIndex]

        if (itemIndex <= #rows) then
            button:SetID(itemIndex)
            button.Date:SetText(_G.date(L["%F %T"], row["endTime"]))
            button.Map:SetText(self:ZoneNameShort(row["zoneId"]))
            button.Duration:SetText(self:HumanDuration(row["duration"]))
            local teamClasses = {row["teamPlayerClass1"], row["teamPlayerClass2"], row["teamPlayerClass3"], row["teamPlayerClass4"], row["teamPlayerClass5"]}
            table.sort(teamClasses, function (a,b) return ArenaStats:SortClassTable(a,b) end)

            button.IconTeamPlayerClass1:SetTexture(self:ClassIconId(teamClasses[1]))
            button.IconTeamPlayerClass2:SetTexture(self:ClassIconId(teamClasses[2]))
            button.IconTeamPlayerClass3:SetTexture(self:ClassIconId(teamClasses[3]))
            button.IconTeamPlayerClass4:SetTexture(self:ClassIconId(teamClasses[4]))
            button.IconTeamPlayerClass5:SetTexture(self:ClassIconId(teamClasses[5]))
            button.Rating:SetText((row["newTeamRating"] or "-") .. " (" ..
                                      ((row["diffRating"] and row["diffRating"] >
                                          0 and "+" .. row["diffRating"] or
                                          row["diffRating"]) or "0") .. ")")
            button.Rating:SetTextColor(self:ColorForRating(row["diffRating"]))
            button.MMR:SetText(row["mmr"] or "-")

            local enemyClasses = {row["enemyPlayerClass1"], row["enemyPlayerClass2"], row["enemyPlayerClass3"], row["enemyPlayerClass4"], row["enemyPlayerClass5"]}
            table.sort(enemyClasses, function (a,b) return ArenaStats:SortClassTable(a,b) end)

            button.IconEnemyPlayer1:SetTexture(self:ClassIconId(enemyClasses[1]))
            button.IconEnemyPlayer2:SetTexture(self:ClassIconId(enemyClasses[2]))
            button.IconEnemyPlayer3:SetTexture(self:ClassIconId(enemyClasses[3]))
            button.IconEnemyPlayer4:SetTexture(self:ClassIconId(enemyClasses[4]))
            button.IconEnemyPlayer5:SetTexture(self:ClassIconId(enemyClasses[5]))
            button.EnemyMMR:SetText(row["enemyMmr"] or "-")
            button.EnemyFaction:SetTexture(self:FactionIconId(
                                               row["enemyFaction"]))

            button:SetWidth(scrollFrame.scrollChild:GetWidth())
            button:Show()
        else
            button:Hide()
        end
    end

    local buttonHeight = scrollFrame.buttonHeight
    local totalHeight = #rows * buttonHeight
    local shownHeight = #buttons * buttonHeight

    _G.HybridScrollFrame_Update(scrollFrame, totalHeight, shownHeight)
end

function ArenaStats:Show()
    if not f then self:CreateGUI() end

    rows = ArenaStats:BuildTable()

    f:Show()
    self:RefreshLayout()
end

function ArenaStats:Hide() f:Hide() end

function ArenaStats:Toggle()
    if f and f:IsShown() then
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

function ArenaStats:ExportFrame() return exportFrame end
function ArenaStats:ExportEditBox() return exportEditBox end
