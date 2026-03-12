-- Get Addon's name and Blizzard's Addon Stub
local AddonName, addon = ...

-- Local handle to the Engine
local x = addon.engine

-- Forward declare the function so it can be referenced in InitOptions
local function UpdateExcludedSpellsOptionsCallback(self)
    -- Update the excluded spells options with current spell list
    local args = {}
    local spellIdList = {}
    local addonSelf = self -- Make a copy of self for the closures
    
    -- Get spell IDs from buttonSpellIds
    if self.buttonSpellIds then
        for spellIdentifier, _ in pairs(self.buttonSpellIds) do
            table.insert(spellIdList, spellIdentifier)
        end
    end
    
    -- Sort spell IDs for consistent ordering
    table.sort(spellIdList, function(a, b) return a < b end)
    
    -- Create checkboxes for each spell
    for index, spellIdentifier in ipairs(spellIdList) do
        local spellInformation = C_Spell.GetSpellInfo(spellIdentifier)
        local spellNameText = spellInformation and spellInformation.name
        local spellIconTexture = spellInformation and spellInformation.iconID
        
        -- Create local copies for the closures to avoid Lua closure issue
        local spellIdForClosure = spellIdentifier
        local nameTextForClosure = spellNameText
        local iconTextureForClosure = spellIconTexture
        
        args["spell_" .. spellIdentifier] = {
            type = "toggle",
            name = function()
                -- Return spell name with icon texture
                if iconTextureForClosure then
                    return "|T" .. iconTextureForClosure .. ":16|t " .. (nameTextForClosure or "Unknown Spell (" .. spellIdForClosure .. ")")
                else
                    return nameTextForClosure or "Unknown Spell (" .. spellIdForClosure .. ")"
                end
            end,
            desc = function()
                -- Return spell description
                local spellLinkText = C_Spell.GetSpellLink(spellIdForClosure)
                return spellLinkText or "Spell ID: " .. spellIdForClosure
            end,
            get = function()
                return addonSelf:IsSpellIdExcluded({}, spellIdForClosure)
            end,
            set = function(_, value)
                addonSelf:SetSpellIdExcluded({}, spellIdForClosure, value)
                addonSelf:UpdateEverything()
            end,
            width = "full",
        }
    end
    
    -- If no spells found, show a message
    if #spellIdList == 0 then
        args.note = {
            type = "description",
            name = "No spells found. Please open your spellbook or use abilities to populate the list.",
            fontSize = "medium",
        }
    end
    
    -- Update the options table
    wipe(self.optionsTables.excludedSpells.args)
    for key, value in pairs(args) do
        self.optionsTables.excludedSpells.args[key] = value
    end
    
    -- Refresh the options dialog if it's open
    local dialog = LibStub('AceConfigDialog-3.0')
    if dialog.OpenFrames and dialog.OpenFrames[AddonName] then
        dialog:SelectGroup(AddonName, "excludedSpells")
        dialog:SelectGroup(AddonName, "general") -- Reset to general tab
        dialog:SelectGroup(AddonName, "excludedSpells") -- Back to excluded spells
    end
end

function x:InitOptions()
    -- Build general options
    local generalOptions = {
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
    }
    
    -- Build excluded spells options (will be updated dynamically)
    local excludedSpellsOptions = {
        type = "group",
        name = "Excluded Spells",
        desc = "Select spells to exclude from glowing",
        args = {},
    }
    
    LibStub('AceConfig-3.0'):RegisterOptionsTable(AddonName, {
        type = "group",
        args = {
            general = generalOptions,
            excludedSpells = excludedSpellsOptions,
        },
    })
    
    -- Store references for updates
    self.optionsTables = {
        general = generalOptions,
        excludedSpells = excludedSpellsOptions,
    }
    
    -- Schedule initial update of excluded spells options
    self:ScheduleTimer(UpdateExcludedSpellsOptionsCallback, 0.1, self)
    
    -- Register chat commands and settings
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

    if Settings and Settings.RegisterAddOnCategory then
        local frame = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
        frame.name = AddonName

        local button = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
        button:SetSize(200, 40)
        button:SetPoint('CENTER')
        button:SetText('Open Options')
        button:SetScript('OnClick', function()
            LibStub('AceConfigDialog-3.0'):Open(AddonName)
        end)

        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(frame, AddonName))
    end
end

-- Make the function available as a method on the engine object
x.UpdateExcludedSpellsOptions = UpdateExcludedSpellsOptionsCallback

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