-- Get Addon's name and Blizzard's Addon Stub
local AddonName, addon = ...

-- Local handle to the Engine
local x = addon.engine

function x:InitOptions()
    LibStub('AceConfig-3.0'):RegisterOptionsTable(AddonName, {
        type = "group",
        args = {
            general = {
                type = "group",
                name = "General",
                args = {
                    cooldownMinimum = {
                        type = "range",
                        name = "Cooldown Minimum",
                        desc = "Only glow buttons of spells with a cooldown of at least X seconds.",
                        min = 0,
                        max = 300,
                        step = 1,
                        get = function() return self.db.profile.cooldownMinimum end,
                        set = function(_, value)
                            self.db.profile.cooldownMinimum = value
                            self:UpdateEverything()
                        end,
                    },
                    glowType = {
                        type = "select",
                        name = "Glow Type",
                        desc = "Which type of glow do you want?",
                        values = {
                            ["pixel"] = "Pixel Glow",
                            ["autocast"] = "Auto Cast Shine",
                            ["procc"] = "Proc Glow",
                            ["blizz"] = "Action Button Glow"
                        },
                        get = function() return self.db.profile.glowType end,
                        set = function(_, value)
                            self.db.profile.glowType = value
                            self:UpdateEverything()
                        end,
                    },
                    disableOutOfCombat = {
                        type = "toggle",
                        name = "Disable out of combat",
                        desc = "Only enable the glows while in combat.",
                        get = function() return self.db.profile.disableOutOfCombat end,
                        set = function(_, value)
                            self.db.profile.disableOutOfCombat = value
                            self:UpdateEverything()
                        end,
                    },
                },
            },
        },
    })

    local aceConfig = LibStub('AceConfig-3.0')
    aceConfig:RegisterOptionsTable(AddonName, {
        type = "group",
        args = {
            general = {
                type = "group",
                name = "General",
                args = {
                    cooldownMinimum = {
                        type = "range",
                        name = "Cooldown Minimum",
                        desc = "Only glow buttons of spells with a cooldown of at least X seconds.",
                        min = 0,
                        max = 300,
                        step = 1,
                        get = function() return self.db.profile.cooldownMinimum end,
                        set = function(_, value)
                            self.db.profile.cooldownMinimum = value
                            self:UpdateEverything()
                        end,
                    },
                    glowType = {
                        type = "select",
                        name = "Glow Type",
                        desc = "Which type of glow do you want?",
                        values = {
                            ["pixel"] = "Pixel Glow",
                            ["autocast"] = "Auto Cast Shine",
                            ["procc"] = "Proc Glow",
                            ["blizz"] = "Action Button Glow"
                        },
                        get = function() return self.db.profile.glowType end,
                        set = function(_, value)
                            self.db.profile.glowType = value
                            self:UpdateEverything()
                        end,
                    },
                    disableOutOfCombat = {
                        type = "toggle",
                        name = "Disable out of combat",
                        desc = "Only enable the glows while in combat.",
                        get = function() return self.db.profile.disableOutOfCombat end,
                        set = function(_, value)
                            self.db.profile.disableOutOfCombat = value
                            self:UpdateEverything()
                        end,
                    },
                },
            },
        },
    })

    local function OpenSettings()
        LibStub('AceConfigDialog-3.0'):Open(AddonName)
    end

    self:RegisterChatCommand('cdbg', OpenSettings)
    self:RegisterChatCommand('cdbuttonglow', OpenSettings)

    if AddonCompartmentFrame then
        AddonCompartmentFrame:RegisterAddon({
            text = AddonName,
            registerForAnyClick = true,
            notCheckable = true,
            func = function()
                LibStub('AceConfigDialog-3.0'):Open(AddonName)
            end
        })
    end
end

function x:SlashCommand(msg)
    if not msg or msg == '' then
        LibStub('AceConfigDialog-3.0'):Open(AddonName)
        return
    end

    if msg == 'update' then
        self:UpdateEverything()
        return
    end

    if msg == 'show' then
        self:ShowButtonSpells()
        return
    end

    if msg == 'debug' then
        self.debug = not self.debug
        return
    end

    local command, args = msg:match('^([a-zA-Z0-9-]+) (.*)')
    if command == 'analyse-btn' or command == 'analyze-btn' then
        self:AnalyseButton(_G[args], true)
        return
    end

    self:Print('Unknown chat command "/cdbg ' .. msg .. '"')
end

function x:GetCooldownMinimum()
    return self.db.profile.cooldownMinimum
end

function x:SetCooldownMinimum(_, value)
    self.db.profile.cooldownMinimum = value
    self:UpdateEverything()
end

function x:GetGlowType()
    return self.db.profile.glowType
end

function x:GetDisableOutOfCombat()
    return self.db.profile.disableOutOfCombat
end

function x:DisableOutOfCombat()
    return self.db.profile.disableOutOfCombat
end

function x:SetDisableOutOfCombat(_, value)
    self.db.profile.disableOutOfCombat = value
    if self:DisableOutOfCombat() and not self.inCombat then
        self:HideAllActiveGlows(true)
    end
end

function x:SetGlowType(_, value)
    self:HideAllActiveGlows(false)
    self.db.profile.glowType = value
    for _, button in pairs(self.activeGlows) do
        self:ShowGlow(button)
    end
end

function x:IsSpellIdExcluded(_, spellId)
    if not self.db.profile.excludedSpellIds[self.playerClass] or not self.db.profile.excludedSpellIds[self.playerClass][self.playerSpecId] then
        return false
    end
    return self.db.profile.excludedSpellIds[self.playerClass][self.playerSpecId][tostring(spellId)]
end

function x:SetSpellIdExcluded(_, spellId, isExcluded)
    if not self.db.profile.excludedSpellIds[self.playerClass] then
        self.db.profile.excludedSpellIds[self.playerClass] = {}
    end
    if not self.db.profile.excludedSpellIds[self.playerClass][self.playerSpecId] then
        self.db.profile.excludedSpellIds[self.playerClass][self.playerSpecId] = {}
    end
    if isExcluded then
        self.db.profile.excludedSpellIds[self.playerClass][self.playerSpecId][tostring(spellId)] = true
    else
        self.db.profile.excludedSpellIds[self.playerClass][self.playerSpecId][tostring(spellId)] = nil
    end
    self:UpdateEverything()
end
