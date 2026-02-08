-- =========================================================
-- TODO / FUTURE VISION
-- =========================================================
-- UI HELPERS:
-- [x] Settings button creation for parent menu integration
-- [x] Section header and enable toggle injection into game menus
-- [ ] Slider controls for numeric settings (interaction radius, NPC count)
-- [ ] Dropdown/multi-select for NPC personality presets
-- [ ] Visual preview of setting changes before applying
-- [ ] Tooltip enrichment with current value and default value display
--
-- SETTINGS MANAGEMENT:
-- [x] Generic get/set with default value fallback
-- [x] Auto-save on toggle change
-- [ ] Settings validation (min/max bounds, type checking)
-- [ ] Settings reset to defaults (per-setting and bulk reset)
-- [ ] Import/export settings as shareable XML for community presets
-- [ ] Settings change event callbacks for live-updating systems
-- [ ] Per-savegame settings profiles (different configs per farm)
-- =========================================================

-- =========================================================
-- FS25 NPC Favor Mod - Settings Helper
-- =========================================================
-- Utility functions for handling settings
-- =========================================================

SettingsHelper = {}

function SettingsHelper.createSettingsButton(parent, settings)
    local button = {
        type = "button",
        name = "npcSettingsButton",
        text = "NPC Settings",
        position = {0.02, 0.02},
        size = {0.12, 0.04},
        onClick = function()
            if settings and settings.showFullSettingsMenu then
                settings:showFullSettingsMenu()
            end
        end
    }
    
    return button
end

function SettingsHelper.addSettingsToMenu(menu, settings)
    if not menu or not settings then
        return false
    end
    
    -- Add NPC section header
    local section = {
        type = "sectionTitle",
        name = "npcSection",
        text = "NPC Favor System",
        position = {0.02, 0.9},
        size = {0.96, 0.04}
    }
    
    -- Add enable toggle
    local toggle = {
        type = "checkbox",
        name = "npcEnabled",
        text = "Enable NPC System",
        tooltip = "Enable or disable the living NPC neighborhood system",
        position = {0.04, 0.85},
        size = {0.92, 0.04},
        isChecked = settings.enabled,
        onChange = function(checked)
            settings.enabled = checked
            if settings.save then
                settings:save()
            end
        end
    }
    
    -- Add to menu
    table.insert(menu.elements, section)
    table.insert(menu.elements, toggle)
    
    return true
end

function SettingsHelper.getSettingsValue(settings, key, defaultValue)
    if not settings then
        return defaultValue
    end
    
    return settings[key] or defaultValue
end

function SettingsHelper.setSettingsValue(settings, key, value)
    if not settings then
        return false
    end
    
    settings[key] = value
    return true
end