-- =========================================================
-- TODO / FUTURE VISION
-- =========================================================
-- ESC MENU INTEGRATION:
-- [x] Hook InGameMenuSettingsFrame.onFrameOpen to inject elements
-- [x] Section headers for NPC Favor System, Display, Gameplay, Debug
-- [x] BinaryOption toggle: Enable NPC System
-- [x] BinaryOption toggle: Show NPC Names
-- [x] BinaryOption toggle: Show Notifications
-- [x] BinaryOption toggle: Show Favor List
-- [x] BinaryOption toggle: Show Relationship Bars
-- [x] BinaryOption toggle: Show Map Markers
-- [x] BinaryOption toggle: Enable Favors
-- [x] BinaryOption toggle: Enable Gifts
-- [x] BinaryOption toggle: Allow Multiple Favors
-- [x] BinaryOption toggle: Relationship Decay
-- [x] BinaryOption toggle: Debug Mode
-- [x] MultiTextOption dropdown: Max NPC Count (2-16)
-- [x] MultiTextOption dropdown: Max Active Favors (1-10)
-- [x] Update UI from current settings on frame open
-- [x] Callback handlers with multiplayer event routing
-- [x] Hook updateGameSettings for live refresh
-- FUTURE ENHANCEMENTS:
-- [ ] Slider or MultiTextOption for favor difficulty (easy/normal/hard)
-- [ ] Slider for relationship gain/loss multiplier
-- [ ] Sound volume controls (effects, voice lines, UI sounds)
-- [ ] Performance preset dropdown (low/normal/high)
-- [ ] "Reset to Defaults" button in the settings section
-- =========================================================

-- =========================================================
-- FS25 NPC Favor Mod - Settings Integration
-- =========================================================
-- Adds NPC settings to ESC > Settings > Game Settings page
-- Pattern from: FS25_UsedPlus UsedPlusSettingsMenuExtension
--
-- Hooks InGameMenuSettingsFrame.onFrameOpen to add elements
-- dynamically using standard FS25 profiles.
--
-- Layout (13 controls under single "NPC Favor System" header):
--   Enable NPC System, Max NPC Count, Show NPC Names,
--   Show Notifications, Show Favor List, Show Relationship Bars,
--   Show Map Markers, Enable Favors, Enable Gifts,
--   Allow Multiple Favors, Max Active Favors, Relationship Decay,
--   Debug Mode
-- =========================================================

NPCSettingsIntegration = {}
NPCSettingsIntegration_mt = Class(NPCSettingsIntegration)

-- Max NPC dropdown values
NPCSettingsIntegration.maxNPCOptions = {"2", "4", "6", "8", "10", "12", "16"}
NPCSettingsIntegration.maxNPCValues = {2, 4, 6, 8, 10, 12, 16}

-- Max Active Favors dropdown values
NPCSettingsIntegration.maxActiveFavorsOptions = {"1", "2", "3", "5", "8", "10"}
NPCSettingsIntegration.maxActiveFavorsValues = {1, 2, 3, 5, 8, 10}

-- HUD Scale dropdown values
NPCSettingsIntegration.hudScaleOptions = {"0.75x", "1.0x", "1.25x", "1.5x"}
NPCSettingsIntegration.hudScaleValues = {0.75, 1.0, 1.25, 1.5}

-- Constructor (called from NPCSystem.new)
function NPCSettingsIntegration.new(npcSystem)
    local self = setmetatable({}, NPCSettingsIntegration_mt)
    self.npcSystem = npcSystem
    return self
end

function NPCSettingsIntegration:initialize()
    -- Hooks are installed at file load time (see bottom of file)
end

function NPCSettingsIntegration:update(dt)
end

function NPCSettingsIntegration:delete()
end

-- =========================================================
-- Settings Frame Hook (called when ESC > Settings opens)
-- =========================================================

function NPCSettingsIntegration:onFrameOpen()
    -- 'self' here is the InGameMenuSettingsFrame instance
    if self.npcfavor_initDone then
        return
    end

    NPCSettingsIntegration:addSettingsElements(self)

    -- Refresh layout
    self.gameSettingsLayout:invalidateLayout()

    if self.updateAlternatingElements then
        self:updateAlternatingElements(self.gameSettingsLayout)
    end
    if self.updateGeneralSettings then
        self:updateGeneralSettings(self.gameSettingsLayout)
    end

    self.npcfavor_initDone = true
    print("[NPC Settings] Added NPC controls to settings menu")

    -- Update UI to reflect current settings
    NPCSettingsIntegration:updateSettingsUI(self)
end

-- =========================================================
-- Add all settings elements (1 section header, 13 controls)
-- =========================================================

function NPCSettingsIntegration:addSettingsElements(frame)
    -- Single section header so the mod is easy to find in a long settings list
    NPCSettingsIntegration:addSectionHeader(frame,
        g_i18n:getText("npc_section") or "NPC Favor System"
    )

    -- Core
    frame.npcfavor_enabledToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onEnabledToggleChanged",
        g_i18n:getText("npc_enabled_short") or "Enable NPC System",
        g_i18n:getText("npc_enabled_long") or "Enable or disable the living NPC neighborhood system"
    )

    frame.npcfavor_maxNPCs = NPCSettingsIntegration:addMultiTextOption(
        frame, "onMaxNPCsChanged",
        NPCSettingsIntegration.maxNPCOptions,
        g_i18n:getText("npc_max_count_short") or "Max NPC Count",
        g_i18n:getText("npc_max_count_long") or "Maximum number of active NPCs in the world"
    )

    -- Display
    frame.npcfavor_showNamesToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onShowNamesToggleChanged",
        g_i18n:getText("npc_show_names_short") or "Show NPC Names",
        g_i18n:getText("npc_show_names_long") or "Display NPC names above their heads"
    )

    frame.npcfavor_notificationsToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onNotificationsToggleChanged",
        g_i18n:getText("npc_show_notifications_short") or "Show Notifications",
        g_i18n:getText("npc_show_notifications_long") or "Show NPC notification messages on screen"
    )

    frame.npcfavor_showFavorListToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onShowFavorListToggleChanged",
        g_i18n:getText("npc_show_favor_list_short") or "Show Favor List",
        g_i18n:getText("npc_show_favor_list_long") or "Show the active favor list on the HUD"
    )

    frame.npcfavor_hudLockedToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onHudLockedToggleChanged",
        g_i18n:getText("npc_hud_locked_short") or "Lock Favor HUD",
        g_i18n:getText("npc_hud_locked_long") or "When locked, the favor list cannot be moved with F8"
    )

    frame.npcfavor_hudScale = NPCSettingsIntegration:addMultiTextOption(
        frame, "onHudScaleChanged",
        NPCSettingsIntegration.hudScaleOptions,
        g_i18n:getText("npc_hud_scale_short") or "Favor HUD Scale",
        g_i18n:getText("npc_hud_scale_long") or "Size of the active favors list on screen"
    )

    frame.npcfavor_showRelBarsToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onShowRelBarsToggleChanged",
        g_i18n:getText("npc_show_rel_bars_short") or "Show Relationship Bars",
        g_i18n:getText("npc_show_rel_bars_long") or "Show relationship progress bars when talking to NPCs"
    )

    frame.npcfavor_showMapMarkersToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onShowMapMarkersToggleChanged",
        g_i18n:getText("npc_show_map_markers_short") or "Show Map Markers",
        g_i18n:getText("npc_show_map_markers_long") or "Show NPC location markers on the map"
    )

    -- Gameplay
    frame.npcfavor_favorsToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onFavorsToggleChanged",
        g_i18n:getText("npc_enable_favors_short") or "Enable Favors",
        g_i18n:getText("npc_enable_favors_long") or "Allow NPCs to ask the player for favors"
    )

    frame.npcfavor_giftsToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onGiftsToggleChanged",
        g_i18n:getText("npc_enable_gifts_short") or "Enable Gifts",
        g_i18n:getText("npc_enable_gifts_long") or "Allow giving gifts to NPCs to improve relationships"
    )

    frame.npcfavor_multiFavorsToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onMultiFavorsToggleChanged",
        g_i18n:getText("npc_allow_multi_favors_short") or "Allow Multiple Favors",
        g_i18n:getText("npc_allow_multi_favors_long") or "Allow accepting multiple favors at the same time"
    )

    frame.npcfavor_maxActiveFavors = NPCSettingsIntegration:addMultiTextOption(
        frame, "onMaxActiveFavorsChanged",
        NPCSettingsIntegration.maxActiveFavorsOptions,
        g_i18n:getText("npc_max_active_favors_short") or "Max Active Favors",
        g_i18n:getText("npc_max_active_favors_long") or "Maximum number of favors you can have active at once"
    )

    frame.npcfavor_relDecayToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onRelDecayToggleChanged",
        g_i18n:getText("npc_rel_decay_short") or "Relationship Decay",
        g_i18n:getText("npc_rel_decay_long") or "Relationships slowly decrease over time if not maintained"
    )

    -- Debug
    frame.npcfavor_debugToggle = NPCSettingsIntegration:addBinaryOption(
        frame, "onDebugToggleChanged",
        g_i18n:getText("npc_debug_short") or "Debug Mode",
        g_i18n:getText("npc_debug_long") or "Show debug information and NPC paths"
    )
end

-- =========================================================
-- GUI Element Builders (FS25 profile-based)
-- =========================================================

function NPCSettingsIntegration:addSectionHeader(frame, text)
    local textElement = TextElement.new()
    local textElementProfile = g_gui:getProfile("fs25_settingsSectionHeader")
    textElement.name = "sectionHeader"
    textElement:loadProfile(textElementProfile, true)
    textElement:setText(text)
    frame.gameSettingsLayout:addElement(textElement)
    textElement:onGuiSetupFinished()
end

function NPCSettingsIntegration:addBinaryOption(frame, callbackName, title, tooltip)
    local bitMap = BitmapElement.new()
    local bitMapProfile = g_gui:getProfile("fs25_multiTextOptionContainer")
    bitMap:loadProfile(bitMapProfile, true)

    local binaryOption = BinaryOptionElement.new()
    binaryOption.useYesNoTexts = true
    local binaryOptionProfile = g_gui:getProfile("fs25_settingsBinaryOption")
    binaryOption:loadProfile(binaryOptionProfile, true)
    binaryOption.target = NPCSettingsIntegration
    binaryOption:setCallback("onClickCallback", callbackName)

    local titleElement = TextElement.new()
    local titleProfile = g_gui:getProfile("fs25_settingsMultiTextOptionTitle")
    titleElement:loadProfile(titleProfile, true)
    titleElement:setText(title)

    local tooltipElement = TextElement.new()
    local tooltipProfile = g_gui:getProfile("fs25_multiTextOptionTooltip")
    tooltipElement.name = "ignore"
    tooltipElement:loadProfile(tooltipProfile, true)
    tooltipElement:setText(tooltip)

    binaryOption:addElement(tooltipElement)
    bitMap:addElement(binaryOption)
    bitMap:addElement(titleElement)

    binaryOption:onGuiSetupFinished()
    titleElement:onGuiSetupFinished()
    tooltipElement:onGuiSetupFinished()

    frame.gameSettingsLayout:addElement(bitMap)
    bitMap:onGuiSetupFinished()

    return binaryOption
end

function NPCSettingsIntegration:addMultiTextOption(frame, callbackName, texts, title, tooltip)
    local bitMap = BitmapElement.new()
    local bitMapProfile = g_gui:getProfile("fs25_multiTextOptionContainer")
    bitMap:loadProfile(bitMapProfile, true)

    local multiTextOption = MultiTextOptionElement.new()
    local multiTextOptionProfile = g_gui:getProfile("fs25_settingsMultiTextOption")
    multiTextOption:loadProfile(multiTextOptionProfile, true)
    multiTextOption.target = NPCSettingsIntegration
    multiTextOption:setCallback("onClickCallback", callbackName)
    multiTextOption:setTexts(texts)

    local titleElement = TextElement.new()
    local titleProfile = g_gui:getProfile("fs25_settingsMultiTextOptionTitle")
    titleElement:loadProfile(titleProfile, true)
    titleElement:setText(title)

    local tooltipElement = TextElement.new()
    local tooltipProfile = g_gui:getProfile("fs25_multiTextOptionTooltip")
    tooltipElement.name = "ignore"
    tooltipElement:loadProfile(tooltipProfile, true)
    tooltipElement:setText(tooltip)

    multiTextOption:addElement(tooltipElement)
    bitMap:addElement(multiTextOption)
    bitMap:addElement(titleElement)

    multiTextOption:onGuiSetupFinished()
    titleElement:onGuiSetupFinished()
    tooltipElement:onGuiSetupFinished()

    frame.gameSettingsLayout:addElement(bitMap)
    bitMap:onGuiSetupFinished()

    return multiTextOption
end

-- =========================================================
-- Update UI from current settings
-- =========================================================

function NPCSettingsIntegration:findValueIndex(values, target)
    for i, v in ipairs(values) do
        if v == target then
            return i
        end
    end
    return 1
end

function NPCSettingsIntegration:updateSettingsUI(frame)
    if not frame.npcfavor_initDone then
        return
    end

    local settings = g_NPCSystem and g_NPCSystem.settings
    if not settings then
        return
    end

    -- NPC Favor System section
    if frame.npcfavor_enabledToggle then
        frame.npcfavor_enabledToggle:setIsChecked(settings.enabled == true, false, false)
    end
    if frame.npcfavor_maxNPCs then
        local index = NPCSettingsIntegration:findValueIndex(
            NPCSettingsIntegration.maxNPCValues, settings.maxNPCs
        )
        frame.npcfavor_maxNPCs:setState(index)
    end

    -- Display section
    if frame.npcfavor_showNamesToggle then
        frame.npcfavor_showNamesToggle:setIsChecked(settings.showNames == true, false, false)
    end
    if frame.npcfavor_notificationsToggle then
        frame.npcfavor_notificationsToggle:setIsChecked(settings.showNotifications == true, false, false)
    end
    if frame.npcfavor_showFavorListToggle then
        frame.npcfavor_showFavorListToggle:setIsChecked(settings.showFavorList == true, false, false)
    end
    if frame.npcfavor_hudLockedToggle then
        frame.npcfavor_hudLockedToggle:setIsChecked(settings.favorHudLocked == true, false, false)
    end
    if frame.npcfavor_hudScale then
        local index = NPCSettingsIntegration:findValueIndex(
            NPCSettingsIntegration.hudScaleValues, settings.favorHudScale
        )
        frame.npcfavor_hudScale:setState(index)
    end
    if frame.npcfavor_showRelBarsToggle then
        frame.npcfavor_showRelBarsToggle:setIsChecked(settings.showRelationshipBars == true, false, false)
    end
    if frame.npcfavor_showMapMarkersToggle then
        frame.npcfavor_showMapMarkersToggle:setIsChecked(settings.showMapMarkers == true, false, false)
    end

    -- Gameplay section
    if frame.npcfavor_favorsToggle then
        frame.npcfavor_favorsToggle:setIsChecked(settings.enableFavors == true, false, false)
    end
    if frame.npcfavor_giftsToggle then
        frame.npcfavor_giftsToggle:setIsChecked(settings.enableGifts == true, false, false)
    end
    if frame.npcfavor_multiFavorsToggle then
        frame.npcfavor_multiFavorsToggle:setIsChecked(settings.allowMultipleFavors == true, false, false)
    end
    if frame.npcfavor_maxActiveFavors then
        local index = NPCSettingsIntegration:findValueIndex(
            NPCSettingsIntegration.maxActiveFavorsValues, settings.maxActiveFavors
        )
        frame.npcfavor_maxActiveFavors:setState(index)
    end
    if frame.npcfavor_relDecayToggle then
        frame.npcfavor_relDecayToggle:setIsChecked(settings.relationshipDecay == true, false, false)
    end

    -- Debug section
    if frame.npcfavor_debugToggle then
        frame.npcfavor_debugToggle:setIsChecked(settings.debugMode == true, false, false)
    end
end

function NPCSettingsIntegration:updateGameSettings()
    NPCSettingsIntegration:updateSettingsUI(self)
end

-- =========================================================
-- Callback Handlers
-- =========================================================

local function getSettings()
    return g_NPCSystem and g_NPCSystem.settings
end

-- Helper: Apply setting locally and route through multiplayer event
local function applySetting(key, value, logMsg)
    local settings = getSettings()
    if not settings then return end

    if g_server ~= nil then
        -- Server/single-player: apply in memory, broadcast to clients.
        -- Disk persistence happens via saveToXMLFile hook on game save (UsedPlus pattern).
        settings[key] = value
        -- Broadcast to all clients
        if NPCSettingsSyncEvent and g_server then
            g_server:broadcastEvent(NPCSettingsSyncEvent.newSingle(key, value), false)
        end
    else
        -- Client: send to server for validation and broadcast
        if NPCSettingsSyncEvent then
            NPCSettingsSyncEvent.sendSingleToServer(key, value)
        end
    end

    if logMsg then
        print("[NPC Favor] " .. logMsg)
    end
end

-- NPC Favor System section callbacks
function NPCSettingsIntegration:onEnabledToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("enabled", value, "NPC system " .. (value and "enabled" or "disabled"))
end

function NPCSettingsIntegration:onMaxNPCsChanged(state)
    local value = NPCSettingsIntegration.maxNPCValues[state] or 8
    applySetting("maxNPCs", value, "Max NPCs set to " .. value)
end

-- Display section callbacks
function NPCSettingsIntegration:onShowNamesToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("showNames", value)
end

function NPCSettingsIntegration:onNotificationsToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("showNotifications", value)
end

function NPCSettingsIntegration:onShowFavorListToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("showFavorList", value)
end

function NPCSettingsIntegration:onHudLockedToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("favorHudLocked", value, "Favor HUD " .. (value and "locked" or "unlocked"))
end

function NPCSettingsIntegration:onHudScaleChanged(state)
    local value = NPCSettingsIntegration.hudScaleValues[state] or 1.0
    applySetting("favorHudScale", value, "Favor HUD scale set to " .. value)
    -- Apply to live HUD immediately
    if g_NPCSystem and g_NPCSystem.favorHUD then
        g_NPCSystem.favorHUD.scale = value
    end
end

function NPCSettingsIntegration:onShowRelBarsToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("showRelationshipBars", value)
end

function NPCSettingsIntegration:onShowMapMarkersToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("showMapMarkers", value)
    -- Toggle existing map hotspots immediately
    if g_NPCSystem and g_NPCSystem.entityManager and g_NPCSystem.entityManager.toggleAllMapHotspots then
        g_NPCSystem.entityManager:toggleAllMapHotspots(value)
    end
end

-- Gameplay section callbacks
function NPCSettingsIntegration:onFavorsToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("enableFavors", value)
end

function NPCSettingsIntegration:onGiftsToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("enableGifts", value)
end

function NPCSettingsIntegration:onMultiFavorsToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("allowMultipleFavors", value)
end

function NPCSettingsIntegration:onMaxActiveFavorsChanged(state)
    local value = NPCSettingsIntegration.maxActiveFavorsValues[state] or 5
    applySetting("maxActiveFavors", value, "Max active favors set to " .. value)
end

function NPCSettingsIntegration:onRelDecayToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("relationshipDecay", value)
end

-- Debug section callbacks
function NPCSettingsIntegration:onDebugToggleChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    applySetting("debugMode", value, "Debug mode " .. (value and "enabled" or "disabled"))
end

-- =========================================================
-- Initialize Hooks (runs at file load time)
-- =========================================================

local function initHooks()
    if not InGameMenuSettingsFrame then
        return
    end

    -- Hook into settings frame open to add our elements
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(
        InGameMenuSettingsFrame.onFrameOpen,
        NPCSettingsIntegration.onFrameOpen
    )

    -- Hook into updateGameSettings to refresh our values
    if InGameMenuSettingsFrame.updateGameSettings then
        InGameMenuSettingsFrame.updateGameSettings = Utils.appendedFunction(
            InGameMenuSettingsFrame.updateGameSettings,
            NPCSettingsIntegration.updateGameSettings
        )
    end
end

initHooks()
