---@class NPCSettingsUI
NPCSettingsUI = {}
local NPCSettingsUI_mt = Class(NPCSettingsUI)

function NPCSettingsUI.new(settings)
    local self = setmetatable({}, NPCSettingsUI_mt)
    self.settings = settings
    self.injected = false
    return self
end

function NPCSettingsUI:inject()
    if self.injected then return end

    local page = g_gui.screenControllers[InGameMenu].pageSettings
    if not page then
        Logging.error("[NPC] Settings page not found - cannot inject!")
        return
    end

    local layout = page.generalSettingsLayout
    if not layout then
        Logging.error("[NPC] Settings layout not found!")
        return
    end

    local section = UIHelper.createSection(layout, "npc_section")
    if not section then
        Logging.error("[NPC] Failed to create settings section!")
        return
    end

    self.enabledOption = UIHelper.createBinaryOption(
        layout, "npc_enabled", "npc_enabled_short", self.settings.enabled,
        function(val) self.settings.enabled = val; self.settings:save(); print("[NPC] Mod " .. (val and "enabled" or "disabled")) end,
        getTextSafe("npc_enabled_long")
    )

    self.showNamesOption = UIHelper.createBinaryOption(
        layout, "npc_show_names", "npc_show_names_short", self.settings.showNames,
        function(val) self.settings.showNames = val; self.settings:save(); print("[NPC] Show names: " .. tostring(val)) end,
        getTextSafe("npc_show_names_long")
    )

    self.notificationsOption = UIHelper.createBinaryOption(
        layout, "npc_show_notifications", "npc_show_notifications_short", self.settings.showNotifications,
        function(val) self.settings.showNotifications = val; self.settings:save(); print("[NPC] Notifications: " .. tostring(val)) end,
        getTextSafe("npc_show_notifications_long")
    )

    self.debugOption = UIHelper.createBinaryOption(
        layout, "npc_debug", "npc_debug_short", self.settings.debugMode,
        function(val) self.settings.debugMode = val; self.settings:save(); print("[NPC] Debug mode: " .. tostring(val)) end,
        getTextSafe("npc_debug_long")
    )

    self.favorsOption = UIHelper.createBinaryOption(
        layout, "npc_enable_favors", "npc_enable_favors_short", self.settings.enableFavors,
        function(val) self.settings.enableFavors = val; self.settings:save(); print("[NPC] Favors: " .. tostring(val)) end,
        getTextSafe("npc_enable_favors_long")
    )

    self.maxNPCsOption = UIHelper.createNumberOption(
        layout, "npc_max_count", "npc_max_count_short", self.settings.maxNPCs, 1, 50,
        function(val) self.settings.maxNPCs = val; self.settings:save(); print("[NPC] Max NPCs: " .. val) end,
        getTextSafe("npc_max_count_long")
    )

    self.injected = true
    layout:invalidateLayout()
    print("[NPC] Settings UI injected successfully")
end

function NPCSettingsUI:refreshUI()
    if not self.injected then return end
    if self.enabledOption then self.enabledOption:setIsChecked(self.settings.enabled) end
    if self.showNamesOption then self.showNamesOption:setIsChecked(self.settings.showNames) end
    if self.notificationsOption then self.notificationsOption:setIsChecked(self.settings.showNotifications) end
    if self.debugOption then self.debugOption:setIsChecked(self.settings.debugMode) end
    if self.favorsOption then self.favorsOption:setIsChecked(self.settings.enableFavors) end
    if self.maxNPCsOption then self.maxNPCsOption:setValue(self.settings.maxNPCs) end
    print("[NPC] UI refreshed")
end

function NPCSettingsUI:ensureResetButton(settingsFrame)
    if not settingsFrame or not settingsFrame.menuButtonInfo then
        print("[NPC] ensureResetButton - settingsFrame invalid")
        return
    end
    if not self._resetButton then
        self._resetButton = {
            inputAction = InputAction.MENU_EXTRA_1,
            text = getTextSafe("npc_reset"),
            callback = function()
                print("[NPC] Reset button clicked!")
                if self.settings then
                    self.settings:resetToDefaults()
                    self:refreshUI()
                end
            end,
            showWhenPaused = true
        }
    end
    for _, btn in ipairs(settingsFrame.menuButtonInfo) do
        if btn == self._resetButton then return end
    end
    table.insert(settingsFrame.menuButtonInfo, self._resetButton)
    settingsFrame:setMenuButtonInfoDirty()
    print("[NPC] Reset button added to footer!")
end

function getTextSafe(key)
    if not g_i18n then return key end
    local text = g_i18n:getText(key)
    return (text == nil or text == "") and key or text
end
