local addonName = "ArenaStats"
local _, addonTitle, addonNotes = GetAddOnInfo(addonName)
local ArenaStats = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function ArenaStats:RegisterOptionsTable()
    AceConfig:RegisterOptionsTable(addonName, {
        name = addonName,
        descStyle = "inline",
        handler = ArenaStats,
        type = "group",
        args = {
            Toggle = {
                order = 0,
                type = "execute",
                name = L["Toggle"],
                desc = L["Opens or closes the main window"],
                func = function() self:Toggle() end
            },
            General = {
                order = 1,
                type = "group",
                name = L["Options"],
                args = {
                    intro = {order = 0, type = "description", name = addonNotes},
                    group1 = {
                        order = 10,
                        type = "group",
                        name = L["Database Settings"],
                        inline = true,
                        args = {
                            maxHistory = {
                                order = 11,
                                type = "range",
                                name = L["Maximum history records"],
                                desc = L["Battlegrounds records can impact memory usage (0 means unlimited)"],
                                min = 0,
                                max = 1000,
                                step = 10,
                                get = function()
                                    return self.db.profile.maxHistory
                                end,
                                set = function(_, val)
                                    self.db.profile.maxHistory = val
                                end
                            },
                            purge = {
                                order = 19,
                                type = "execute",
                                name = L["Purge database"],
                                desc = L["Delete all collected data"],
                                confirm = true,
                                func = function()
                                    self:ResetDatabase()
                                end
                            }
                        }
                    },
                    group2 = {
                        order = 20,
                        type = "group",
                        name = L["Minimap Button Settings"],
                        inline = true,
                        args = {
                            minimapButton = {
                                order = 21,
                                type = "toggle",
                                name = L["Show minimap button"],
                                get = function()
                                    return
                                        not self.db.profile.minimapButton.hide
                                end,
                                set = 'ToggleMinimapButton'
                            }
                        }
                    },
                    group3 = {
                        order = 30,
                        type = "group",
                        name = L["Interface Settings"],
                        inline = true,
                        args = {
                            characterNamesOnHover = {
                                order = 31,
                                type = "toggle",
                                name = L["Show character names on hover"],
                                get = function()
                                    return not self.db.profile
                                               .characterNamesOnHover.hide
                                end,
                                set = function()
                                    self.db.profile.characterNamesOnHover.hide =
                                        not self.db.profile
                                            .characterNamesOnHover.hide
                                end
                            }
                        }
                    }
                }
            },
            Profiles = AceDBOptions:GetOptionsTable(ArenaStats.db)
        }
    }, {"arenastats", "as"})
    AceConfigDialog:AddToBlizOptions(addonName, nil, nil, "General")

    AceConfigDialog:AddToBlizOptions(addonName, "Profiles", addonName,
                                     "Profiles")
end
