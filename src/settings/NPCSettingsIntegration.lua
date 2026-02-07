NPCSettingsIntegration = {}
NPCSettingsIntegration_mt = Class(NPCSettingsIntegration)

function NPCSettingsIntegration.new(npcSystem)
    local self = setmetatable({}, NPCSettingsIntegration_mt)
    self.npcSystem = npcSystem
    self.settingsMenu = nil
    return self
end

function NPCSettingsIntegration:initialize()
    self:hookSettingsMenu()
end

function NPCSettingsIntegration:hookSettingsMenu()
    if not g_currentMission or not g_currentMission.inGameMenu then return end
    local inGameMenu = g_currentMission.inGameMenu
    if inGameMenu.settingsMenu then
        self:addSettingsToMenu(inGameMenu.settingsMenu)
    end
    if inGameMenu.onSettingsMenuOpen then
        local original = inGameMenu.onSettingsMenuOpen
        inGameMenu.onSettingsMenuOpen = function(...)
            original(...)
            self:addSettingsToMenu(inGameMenu.settingsMenu)
        end
    end
end

function NPCSettingsIntegration:addSettingsToMenu(settingsMenu)
    if not settingsMenu or not settingsMenu.pageFrames then return end
    for _, page in ipairs(settingsMenu.pageFrames) do
        if page.name == "pageGeneral" then
            self:addNPCControlsToPage(page)
            break
        end
    end
end

function NPCSettingsIntegration:addNPCControlsToPage(pageFrame)
    if not pageFrame.elements then return end
    for _, element in ipairs(pageFrame.elements) do
        if element.name and element.name:find("npc_") then return end
    end

    local insertIndex = 1
    for i, element in ipairs(pageFrame.elements) do
        if element.name and (element.name == "game" or element.name == "gameSettings") then
            insertIndex = i + 1
            break
        end
    end

    local npcSection = {
        type = "sectionTitle",
        name = "npcSectionTitle",
        text = g_i18n:getText("npc_section") or "NPC Favor System",
        position = {0.02, 0.9},
        size = {0.96, 0.04}
    }

    local enabledControl = {
        type = "checkbox",
        name = "npcEnabled",
        text = g_i18n:getText("npc_enabled_short") or "Enable NPC System",
        tooltip = g_i18n:getText("npc_enabled_long") or "Enable or disable the living NPC neighborhood system",
        position = {0.04, 0.85},
        size = {0.92, 0.04},
        isChecked = self.npcSystem.settings.enabled,
        onChange = function(checked)
            self.npcSystem.settings.enabled = checked
            self.npcSystem.settings:save()
        end
    }

    table.insert(pageFrame.elements, insertIndex, npcSection)
    table.insert(pageFrame.elements, insertIndex + 1, enabledControl)

    for i = insertIndex + 2, #pageFrame.elements do
        if pageFrame.elements[i].position then
            pageFrame.elements[i].position[2] = pageFrame.elements[i].position[2] - 0.10
        end
    end
    print("[NPC Settings] Added NPC controls to settings menu")
end

function NPCSettingsIntegration:createFullSettingsMenu()
    if not self.settingsMenu then
        self.settingsMenu = NPCSettingsMenu.new(self.npcSystem)
    end
end

function NPCSettingsIntegration:showFullSettingsMenu()
    if not self.settingsMenu then self:createFullSettingsMenu() end
    if self.settingsMenu then self.settingsMenu:open() end
end

function NPCSettingsIntegration:update(dt)
    if self.settingsMenu then self.settingsMenu:update(dt) end
end

function NPCSettingsIntegration:delete()
    if self.settingsMenu then
        self.settingsMenu:delete()
        self.settingsMenu = nil
    end
end
