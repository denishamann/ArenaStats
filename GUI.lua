local _G = _G
local addonName = "ArenaStats"
local addonTitle = select(2, (C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo)(addonName))
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
   -- Hardcoded TBC Arena Maps
   [559] = "NAG",
   [562] = "BEA",
   [572] = "ROL",
}

function ArenaStats:CreateGUI()
    asGui = {}
    filters = {}
    filtered = {}
    rows = {}

    filters.bracket = 0
    filters.arenaType = 0
    filters.name = ""

    function ArenaStats:SetData(newRows)
        rows = newRows or {}
        self:SortTable()
        self:UpdateTableView()
    end

    asGui.f = AceGUI:Create("Frame")
    asGui.f:Hide()
    asGui.f:SetWidth(859)
    asGui.f:EnableResize(false)

    asGui.f:SetTitle(addonTitle)
    asGui.f:SetStatusText("Status Bar")
    asGui.f:SetLayout("Flow")
    
    -- Make window opaque solid black
    if asGui.f.frame.SetBackdrop then
        local backdrop = asGui.f.frame:GetBackdrop() or {}
        backdrop.bgFile = "Interface\\Buttons\\WHITE8X8"
        asGui.f.frame:SetBackdrop(backdrop)
        asGui.f.frame:SetBackdropColor(0, 0, 0, 0.85)
    end

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
    self:CreateScoreButton(tableHeader, 25, "")

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
    local text = ""
    if localeStr and localeStr ~= "" then
        text = L[localeStr]
    end
    btn:SetText(string.format(" %s ", text))
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
function ArenaStats:SortClassSpecTable(a, b)
    -- Sort nils to the end of the list
    if not a or not a.class then return false end
    if not b or not b.class then return true end

    -- Safe spec sort
    local specA = a.spec
    local specB = b.spec

    -- Healer check
    local isHealerA = self:IsHealerSpec(specA)
    local isHealerB = self:IsHealerSpec(specB)

    if isHealerA and not isHealerB then return false end
    if not isHealerA and isHealerB then return true end
    
    -- Default to class comparison
    return a.class < b.class
end
end

function ArenaStats:IsHealerSpec(spec) 
    return spec == "Restoration" or spec == "Discipline" or spec == "Holy"
end

-- Helper to populate reusable class/spec table
local function populateClassSpecTable(tbl, row, prefix)
    for i = 1, 5 do
        if not tbl[i] then tbl[i] = {} end
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

            -- Create or Update Delete Button
            -- Create or Update Delete Button
            if not button.Delete then
                button.Delete = CreateFrame("Button", nil, button)
                button.Delete:SetSize(16, 16)
                -- Moved 40px to the right as requested
                button.Delete:SetPoint("LEFT", button.EnemyFaction, "RIGHT", 40, 0)
                button.Delete:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                button.Delete:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
                button.Delete:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
                -- Ensure button intercepts clicks
                button.Delete:EnableMouse(true)
                button.Delete:SetFrameLevel(button:GetFrameLevel() + 5)
            end
            button.Delete:SetScript("OnClick", function()
                 ArenaStats:DeleteEntry(row)
            end)
            button.Delete:Show()

            button:EnableMouse(true)
            button:SetScript("OnClick", function()
                 ArenaStats:ShowMatchDetails(row)
            end)

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

function ArenaStats:ClassIconId(classSpec)
    if not classSpec then
        return nil
    end

    local spec = classSpec.spec
    local className = classSpec.class

    if className == "MAGE" then
        if spec == "Frost" then return "Interface\\Icons\\Spell_Frost_FrostBolt02" end
        if spec == "Fire" then return "Interface\\Icons\\Spell_Fire_FireBolt02" end
        if spec == "Arcane" then return "Interface\\Icons\\Spell_Holy_MagicalSentry" end
        return "Interface\\Icons\\ClassIcon_Mage"
    elseif className == "PRIEST" then
        if spec == "Shadow" then return "Interface\\Icons\\Spell_Shadow_ShadowWordPain" end
        if spec == "Holy" then return "Interface\\Icons\\Spell_Holy_HolyBolt" end
        if spec == "Discipline" then return "Interface\\Icons\\Spell_Holy_WordFortitude" end
        return "Interface\\Icons\\ClassIcon_Priest"
    elseif className == "DRUID" then
        if spec == "Restoration" then return "Interface\\Icons\\Spell_Nature_HealingTouch" end
        if spec == "Feral" then return "Interface\\Icons\\Ability_Racial_BearForm" end
        if spec == "Balance" then return "Interface\\Icons\\Spell_Nature_StarFall" end
        return "Interface\\Icons\\ClassIcon_Druid"
    elseif className == "SHAMAN" then
        if spec == "Restoration" then return "Interface\\Icons\\Spell_Nature_HealingWaveGreater" end
        if spec == "Elemental" then return "Interface\\Icons\\Spell_Nature_Lightning" end
        if spec == "Enhancement" then return "Interface\\Icons\\Spell_Nature_LightningShield" end
        return "Interface\\Icons\\ClassIcon_Shaman"
    elseif className == "PALADIN" then
        if spec == "Retribution" then return "Interface\\Icons\\Spell_Holy_AuraOfLight" end
        if spec == "Holy" then return "Interface\\Icons\\Spell_Holy_HolyBolt" end
        if spec == "Protection" then return "Interface\\Icons\\Spell_Holy_DevotionAura" end
        return "Interface\\Icons\\ClassIcon_Paladin"
    elseif className == "WARLOCK" then
        if spec == "Affliction" then return "Interface\\Icons\\Spell_Shadow_DeathCoil" end
        if spec == "Demonology" then return "Interface\\Icons\\Spell_Shadow_SummonFelGuard" end
        if spec == "Destruction" then return "Interface\\Icons\\Spell_Shadow_RainOfFire" end
        return "Interface\\Icons\\ClassIcon_Warlock"
    elseif className == "WARRIOR" then
        if spec == "Arms" then return "Interface\\Icons\\Ability_Warrior_SavageBlow" end
        if spec == "Fury" then return "Interface\\Icons\\Spell_Nature_BloodLust" end
        if spec == "Protection" then return "Interface\\Icons\\Ability_Warrior_DefensiveStance" end
        return "Interface\\Icons\\ClassIcon_Warrior"
    elseif className == "HUNTER" then
        if spec == "BeastMastery" then return "Interface\\Icons\\Ability_Hunter_BeastTaming" end
        if spec == "Marksmanship" then return "Interface\\Icons\\Ability_Marksmanship" end
        if spec == "Survival" then return "Interface\\Icons\\Ability_Hunter_SwiftStrike" end
        return "Interface\\Icons\\ClassIcon_Hunter"
    elseif className == "ROGUE" then
        if spec == "Assassination" then return "Interface\\Icons\\Ability_Rogue_Eviscerate" end
        if spec == "Combat" then return "Interface\\Icons\\Ability_BackStab" end
        if spec == "Subtlety" then return "Interface\\Icons\\Ability_Stealth" end
        return "Interface\\Icons\\ClassIcon_Rogue"
    elseif className == "DEATHKNIGHT" then
        return "Interface\\Icons\\Spell_DeathKnight_ClassIcon"
    end
    return nil
end

function ArenaStats:FactionIconId(factionId)
    if not factionId then return nil end

    if factionId == 0 then
        return "Interface\\Icons\\Inv_BannerPVP_01"
    else
        return "Interface\\Icons\\Inv_BannerPVP_02"
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
    if id == 559 then return "NAG" end
    if id == 562 then return "BEA" end
    if id == 572 then return "ROL" end

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
