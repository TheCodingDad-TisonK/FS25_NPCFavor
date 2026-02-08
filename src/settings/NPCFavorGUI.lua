-- =========================================================
-- FS25 NPC Favor Mod - GUI and Console Commands
-- =========================================================
-- Handles console commands and GUI integration
-- =========================================================

NPCFavorGUI = {}
NPCFavorGUI_mt = Class(NPCFavorGUI)

function NPCFavorGUI.new(npcSystem)
    local self = setmetatable({}, NPCFavorGUI_mt)
    self.npcSystem = npcSystem
    
    return self
end

function NPCFavorGUI:registerConsoleCommands()
    addConsoleCommand("npcStatus", "Show NPC system status", "npcStatus", self)
    addConsoleCommand("npcSpawn", "Spawn an NPC with optional name", "npcSpawn", self)
    addConsoleCommand("npcList", "List all active NPCs", "npcList", self)
    addConsoleCommand("npcReset", "Reset/Initialize NPC system", "npcReset", self)
    addConsoleCommand("npcHelp", "Show help message", "npcHelp", self)
    addConsoleCommand("npcDebug", "Toggle debug mode", "npcDebug", self)
    addConsoleCommand("npcReload", "Reload NPC settings", "npcReload", self)
    addConsoleCommand("npcTest", "Test function", "npcTest", self)

    print("[NPC Favor] Console commands registered")
end

-- Console command handler functions that route to NPCSystem
function NPCFavorGUI:npcStatus()
    if g_NPCSystem then
        return g_NPCSystem:consoleCommandStatus()
    else
        return "NPC System not initialized. Try reloading the save or type 'NPCReset'."
    end
end

function NPCFavorGUI:npcSpawn(name)
    if g_NPCSystem then
        return g_NPCSystem:consoleCommandSpawn(name or "")
    else
        return "NPC System not initialized"
    end
end

function NPCFavorGUI:npcList()
    if g_NPCSystem then
        return g_NPCSystem:consoleCommandList()
    else
        return "NPC System not initialized"
    end
end

function NPCFavorGUI:npcReset()
    if g_NPCSystem then
        return g_NPCSystem:consoleCommandReset()
    else
        return "NPC System not initialized"
    end
end

function NPCFavorGUI:npcHelp()
    local helpText = [[
=== NPC Favor Mod Commands ===
npcStatus           - Show NPC system status
npcSpawn [name]     - Spawn an NPC with optional name
npcList             - List all active NPCs
npcReset            - Reset/Initialize NPC system
npcHelp             - Show this help message
npcDebug [on|off]   - Toggle debug mode
npcReload           - Reload NPC settings
npcTest             - Test function

=== Interaction ===
Press E near an NPC to interact
Favors will appear in your task list

=== Troubleshooting ===
If commands don't work, try:
1. Type 'NPCReset' to force initialization
2. Save and reload the game
3. Check game console for NPC Favor messages
]]
    return helpText
end

function NPCFavorGUI:npcDebug(state)
    if not g_NPCSystem then
        return "NPC System not initialized. Type 'NPCReset' first."
    end
    
    if state == "on" then
        g_NPCSystem.settings.debugMode = true
        g_NPCSystem.settings:save()
        return "Debug mode enabled"
    elseif state == "off" then
        g_NPCSystem.settings.debugMode = false
        g_NPCSystem.settings:save()
        return "Debug mode disabled"
    else
        return "Usage: npcDebug [on|off]"
    end
end

function NPCFavorGUI:npcReload()
    if g_NPCSystem then
        g_NPCSystem.settings:load()
        return "NPC settings reloaded"
    else
        return "NPC System not initialized"
    end
end

function NPCFavorGUI:npcTest()
    print("[NPC Favor] Test function called - console commands are working!")
    return "NPC Favor test successful. Type 'npcHelp' for commands."
end

function NPCFavorGUI:delete()
    -- Clean up if needed
end