
local addonName = "ArenaStats"
local ArenaStats = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceGUI = LibStub("AceGUI-3.0")

local asGui = ArenaStats.asGui or {} -- Ensure asGui reference exists or retrieve it correctly later (it's actually local in GUI.lua, we need to handle that)
-- Wait, 'asGui' is local in GUI.lua! I cannot access it directly here unless I expose it or attach it to ArenaStats. 
-- In GUI.lua: 'local filters, asGui'
-- In GUI.lua: 'function ArenaStats:CreateGUI() asGui = {} ...'
-- It seems I need to access the main frame or storage.
-- Let's check GUI.lua again. 'asGui' is file-local. But ArenaStats:CreateGUI saves 'asGui.f' to _G.AsFrame.
-- I should attach 'detailsFrame' to the ArenaStats object or use a property.
-- Better approach: ArenaStats.detailsFrame to store the frame reference.



function ArenaStats:ShowMatchDetails(row)
    if not self.detailsFrame then
        local frame = AceGUI:Create("Frame")
        frame:SetTitle(L["Match Details"])
        frame:SetLayout("Flow")
        frame:EnableResize(false)
        
        -- Make window opaque solid black
        if frame.frame.SetBackdrop then
            local backdrop = frame.frame:GetBackdrop() or {}
            backdrop.bgFile = "Interface\\Buttons\\WHITE8X8"
            frame.frame:SetBackdrop(backdrop)
            frame.frame:SetBackdropColor(0, 0, 0, 0.85)
        end
        
        self.detailsFrame = frame
    end
    
    local f = self.detailsFrame
    f:ReleaseChildren()

    -- Calculate dynamic height: Header(70) + TeamHeaders(40*2) + Rows(25 * numPlayers * 2) + Padding(100)
    local teamSize = row["teamSize"] or 2
    local rowHeight = 25
    local baseHeight = 270 -- Increased from 220
    local totalHeight = baseHeight + (teamSize * 2 * rowHeight)
    
    f:SetWidth(700)
    f:SetHeight(totalHeight)
    
    -- Anchor to the right of the main window if possible
    f:ClearAllPoints()
    if _G.AsFrame and _G.AsFrame.frame and _G.AsFrame.frame:IsShown() then
        f:SetPoint("TOPLEFT", _G.AsFrame.frame, "TOPRIGHT", 5, 0) -- 5px padding
    else
        f:SetPoint("CENTER")
    end
    
    -- Hide the bottom status bar as requested
    if f.statusbg then f.statusbg:Hide() end
    if f.statustext then f.statustext:Hide() end
    
    f:Show()

    -- [HEADER] Map Info
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")
    f:AddChild(headerGroup)

    local function GetFullMapName(id)
        if id == 559 then return "Nagrand Arena" end
        if id == 562 then return "Blade's Edge Arena" end
        if id == 572 then return "Ruins of Lordaeron" end
        return "Unknown Arena (" .. (id or "?") .. ")"
    end

    local mapName = GetFullMapName(row["zoneId"])
    local duration = self:HumanDuration(row["duration"])
    local dateStr = row["endTime"] and _G.date(L["%F %T"], row["endTime"]) or "-"

    local infoText = AceGUI:Create("Label")
    infoText:SetFullWidth(true)
    infoText:SetText(string.format("Map: %s      Duration: %s      Date: %s", mapName, duration, dateStr))
    infoText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    infoText:SetColor(1, 0.82, 0) -- Gold color
    headerGroup:AddChild(infoText)

    -- Shared function for table headers
    local function AddTableHeader(container)
        local grp = AceGUI:Create("SimpleGroup")
        grp:SetFullWidth(true)
        grp:SetLayout("Flow")
        
        local function AddCol(text, width)
            local lbl = AceGUI:Create("Label")
            lbl:SetText(text)
            lbl:SetWidth(width)
            lbl:SetColor(1, 0.82, 0) -- Gold
            lbl:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE") 
            grp:AddChild(lbl)
        end
        
        AddCol("", 25) -- Icon
        AddCol(L["Name"], 130)
        AddCol(L["Damage"], 80)
        AddCol(L["Healing"], 80)
        AddCol(L["Rating"], 100)
        AddCol(L["MMR"], 50)
        
        container:AddChild(grp)
    end

    -- Shared function for player row
    local function AddPlayerRow(container, name, class, spec, race, dmg, heal, ratingStr, mmr, diffRating)
        local grp = AceGUI:Create("SimpleGroup")
        grp:SetFullWidth(true)
        grp:SetLayout("Flow")
        
        -- Icon
        local icon = AceGUI:Create("Icon")
        icon:SetImage(self:ClassIconId({class=class, spec=spec}) or "Interface\\Icons\\Inv_Misc_QuestionMark")
        icon:SetImageSize(18, 18)
        icon:SetWidth(25)
        grp:AddChild(icon)

        -- Name (%s %s) -> Name (ClassColor)
        local label = AceGUI:Create("Label")
        local classColor = _G.RAID_CLASS_COLORS[class] or {r=1, g=1, b=1}
        label:SetText(name or "Unknown")
        label:SetColor(classColor.r, classColor.g, classColor.b)
        label:SetWidth(130)
        grp:AddChild(label)

        -- Damage
        local dmgLabel = AceGUI:Create("Label")
        dmgLabel:SetText(dmg or "-")
        dmgLabel:SetWidth(80)
        grp:AddChild(dmgLabel)

        -- Healing
        local healLabel = AceGUI:Create("Label")
        healLabel:SetText(heal or "-")
        healLabel:SetWidth(80)
        grp:AddChild(healLabel)

        -- Rating
        local ratingLabel = AceGUI:Create("Label")
        ratingLabel:SetText(ratingStr or "-")
        ratingLabel:SetWidth(100)
        
        -- Color logic based on diffRating
        local dr = diffRating or 0
        if dr > 0 then
            ratingLabel:SetColor(0, 1, 0) -- Green
        elseif dr < 0 then
            ratingLabel:SetColor(1, 0, 0) -- Red
        else
            ratingLabel:SetColor(1, 1, 1) -- White
        end
        
        grp:AddChild(ratingLabel)

        -- MMR
        local mmrLabel = AceGUI:Create("Label")
        mmrLabel:SetText(mmr or "-")
        mmrLabel:SetWidth(50)
        grp:AddChild(mmrLabel)

        container:AddChild(grp)
    end

    -- Format Rating String: "1500 (+12)"
    local function GetRatingStr(new, diff)
        local d = diff or 0
        local sign = (d > 0) and "+" or ""
        return string.format("%s (%s%s)", new or "-", sign, d)
    end

    -- [MY TEAM]
    local teamHeader = AceGUI:Create("Heading")
    teamHeader:SetText(L["Team"] .. " (" .. (row["teamName"] or "Unknown") .. ")")
    teamHeader:SetFullWidth(true)
    f:AddChild(teamHeader)
    
    AddTableHeader(f)

    local myRatingStr = GetRatingStr(row["newTeamRating"], row["diffRating"])
    local myMMR = row["mmr"]
    local myDiff = row["diffRating"]

    for i = 1, 5 do
        if row["teamPlayerClass" .. i] then
            AddPlayerRow(f, row["teamPlayerName" .. i], row["teamPlayerClass" .. i], 
                         row["teamPlayerSpec" .. i], row["teamPlayerRace" .. i], 
                         row["teamPlayerDamage" .. i], row["teamPlayerHealing" .. i],
                         myRatingStr, myMMR, myDiff)
        end
    end

    -- [ENEMY TEAM]
    local space = AceGUI:Create("Label")
    space:SetText(" ")
    space:SetFullWidth(true)
    f:AddChild(space)

    local enemyHeader = AceGUI:Create("Heading")
    enemyHeader:SetText(L["Enemy Team"] .. " (" .. (row["enemyTeamName"] or "Unknown") .. ")")
    enemyHeader:SetFullWidth(true)
    f:AddChild(enemyHeader)

    AddTableHeader(f)

    local enemyRatingStr = GetRatingStr(row["enemyNewTeamRating"], row["enemyDiffRating"])
    local enemyMMR = row["enemyMmr"]
    local enemyDiff = row["enemyDiffRating"]

    for i = 1, 5 do
        if row["enemyPlayerClass" .. i] then
            AddPlayerRow(f, row["enemyPlayerName" .. i], row["enemyPlayerClass" .. i], 
                         row["enemyPlayerSpec" .. i], row["enemyPlayerRace" .. i], 
                         row["enemyPlayerDamage" .. i], row["enemyPlayerHealing" .. i],
                         enemyRatingStr, enemyMMR, enemyDiff)
        end
    end
end
