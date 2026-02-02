local addonName = "ArenaStats"
local _, addonTitle, addonNotes = (C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo)(addonName)
local ArenaStats = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function ArenaStats:RegisterOptionsTable()
    AceConfig:RegisterOptionsTable(addonName, {
        name = "ArenaStats-TBC",
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
                    intro = { order = 0, type = "description", name = addonNotes },
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
                                    self:ReloadData()
                                end
                            },
                            testData = {
                                order = 20,
                                type = "execute",
                                name = L["Generate Test Data"],
                                desc = L["Generates a dummy arena record for testing purposes"],
                                func = function()
                                    self:TestData()
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
                            showCharacterNamesOnHover = {
                                order = 31,
                                type = "toggle",
                                name = L["Show character names on hover"],
                                get = function()
                                    return self.db.profile.showCharacterNamesOnHover
                                end,
                                set = function(_, val)
                                    self.db.profile.showCharacterNamesOnHover = val
                                end
                            }
                        }
                    },
                    group4 = {
                        order = 40,
                        type = "group",
                        name = L["Spec Detection"],
                        inline = true,
                        args = {
                            showSpec = {
                                order = 41,
                                type = "toggle",
                                name = L["Show specialization"],
                                get = function()
                                    return self.db.profile.showSpec
                                end,
                                set = function(_, val)
                                    self.db.profile.showSpec = val
                                end
                            }
                        }
                    }
                }
            },
            Profiles = AceDBOptions:GetOptionsTable(ArenaStats.db)
        }
    }, { "arenastats", "as" })
    AceConfigDialog:AddToBlizOptions(addonName, nil, nil, "General")

    AceConfigDialog:AddToBlizOptions(addonName, "Profiles", addonName,
        "Profiles")
end
