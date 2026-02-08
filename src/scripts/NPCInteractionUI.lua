-- =========================================================
-- TODO / FUTURE VISION
-- =========================================================
-- [x] World-space interaction hint with pulse animation
-- [x] NPC name + relationship level display above NPC
-- [x] Corner HUD favor list with progress bars
-- [x] Time-remaining color coding (green/yellow/red)
-- [x] Time-of-day aware greetings
-- [x] Personality-aware conversation topics
-- [x] Localized conversation topics (all strings use g_i18n:getText with fallbacks)
-- [ ] Thought bubbles above NPCs showing their current activity
-- [ ] Exclamation mark icon when NPC has a new favor to offer
-- [ ] Question mark icon when NPC has pending favor objective nearby
-- [ ] Minimap integration (favor locations shown on minimap)
-- [ ] Favor tracking waypoints (navigate to favor objectives)
-- [ ] Animated interaction prompt (bouncing icon instead of just text pulse)
-- [ ] Favor completion celebration effect (particles/sound/screen flash)
-- [ ] Consolidate getPersonalityColor() duplication with NPCDialog.lua
-- [ ] Speech bubble UI for casual NPC comments (not dialog, just ambient)
-- [ ] Proximity-based auto-greet (NPC waves/nods when you pass nearby)
-- [ ] Favor priority markers (urgent favors pulse faster or show warning icon)
-- [ ] Distance indicator in favor list (how far away is the favor location)
-- [ ] Favor category icons (delivery, repair, social, etc.)
-- [ ] Relationship change notifications ("+5 with John" floating text)
-- [ ] NPC portrait thumbnails in favor list
-- [ ] Collapsible favor list (toggle expand/collapse with keybind)
-- [ ] Sound effects for interaction hint appearance/disappearance
-- [ ] Custom icon overlays for different NPC states (working, idle, available)
-- [ ] Timer countdown warnings (notification when favor expires in 30 min)
-- [ ] Favor chain indicators (show if completing this unlocks another)
-- =========================================================

-- =========================================================
-- FS25 NPC Favor Mod - Interaction UI (HUD + Helper Methods)
-- =========================================================
-- Two responsibilities:
--
-- 1) World-space HUD rendering (called every frame from update):
--    - Floating "Press [E] to talk" hint above nearby NPCs (with pulse animation)
--    - NPC name + relationship level below the hint
--    - Corner HUD showing active favors list with progress bars and time-to-expire
--
-- 2) Helper methods called by NPCDialog.lua for dialog content:
--    - getGreetingForNPC()          — Time-of-day + relationship greeting
--    - getRandomConversationTopic() — Personality-aware random dialog
--    - getWorkStatusMessage()       — AI state description in NPC voice
--    - getPersonalityColor()        — RGB color per personality trait
--
-- Dialog rendering itself is handled by gui/NPCDialog.xml + src/gui/NPCDialog.lua.
--
-- FS25 overlay API: createImageOverlay() → setOverlayColor(id,...) → renderOverlay(id,...)
-- FS25 project() API: project(worldX, worldY, worldZ) → screenX, screenY, screenZ (0-1 normalized)
-- =========================================================

NPCInteractionUI = {}
NPCInteractionUI_mt = Class(NPCInteractionUI)

--- Create a new NPCInteractionUI instance.
-- @param npcSystem  NPCSystem reference (provides settings, favorSystem, scheduler, etc.)
-- @return NPCInteractionUI instance
function NPCInteractionUI.new(npcSystem)
    local self = setmetatable({}, NPCInteractionUI_mt)

    self.npcSystem = npcSystem           -- Back-reference to parent system

    -- World-space interaction hint state
    self.interactionHintVisible = false  -- Whether the hint is currently shown
    self.interactionHintNPC = nil        -- NPC the hint is attached to
    self.interactionHintTimer = 0        -- Accumulator for pulse animation

    -- HUD color palette (RGBA)
    self.UI_COLORS = {
        TEXT = {1, 1, 1, 1},                -- Standard white text
        TEXT_DIM = {0.8, 0.8, 0.8, 1},      -- Subdued text (relationship level)
        FAVOR_EASY = {0.3, 0.8, 0.3, 1},    -- Green: > 6 hours remaining
        FAVOR_MEDIUM = {0.8, 0.8, 0.3, 1},  -- Yellow: 2-6 hours remaining
        FAVOR_HARD = {0.8, 0.3, 0.3, 1}     -- Red: < 2 hours remaining
    }

    -- HUD text sizes (normalized screen height)
    self.UI_SIZES = {
        TEXT_SMALL = 0.014,
        TEXT_MEDIUM = 0.016
    }

    self.inputCooldown = 0       -- Debounce timer for input events
    self.animationTime = 0       -- Global animation accumulator

    -- 1x1 pixel overlay for drawing colored rectangles (FS25 requires overlay ID)
    self.bgOverlay = nil
    if createImageOverlay then
        self.bgOverlay = createImageOverlay("dataS/menu/base/graph_pixel.dds")
    end

    return self
end

-- =========================================================
-- Update Loop (simplified — no dialog rendering)
-- =========================================================

function NPCInteractionUI:update(dt)
    if self.inputCooldown > 0 then
        self.inputCooldown = self.inputCooldown - dt
    end
    self.animationTime = self.animationTime + dt

    -- World-space interaction hint above NPC
    self:updateInteractionHint(dt)

    -- Corner HUD: active favors list
    if self.npcSystem.settings.showFavorList then
        self:drawFavorList()
    end
end

-- =========================================================
-- World-Space Interaction Hint (above NPC head)
-- =========================================================

function NPCInteractionUI:updateInteractionHint(dt)
    if not self.interactionHintVisible or not self.interactionHintNPC then
        self.interactionHintTimer = 0
        return
    end

    self.interactionHintTimer = self.interactionHintTimer + dt

    local npc = self.interactionHintNPC
    local x, y, z = npc.position.x, npc.position.y + 2.5, npc.position.z

    local screenX, screenY = self:projectWorldToScreen(x, y, z)

    if screenX and screenY then
        local pulse = 0.5 + 0.5 * math.sin(self.interactionHintTimer * 3)
        local text = g_i18n:getText("npc_interact_hint") or "Press [E] to talk"

        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, pulse, 1)
        renderText(screenX, screenY + 0.05, self.UI_SIZES.TEXT_MEDIUM, text)
        setTextBold(false)

        -- Draw NPC name and relationship level
        if self.npcSystem.settings.showNames then
            local relationship = self.npcSystem.relationshipManager:getRelationshipColor(npc.relationship)
            setTextColor(relationship.r, relationship.g, relationship.b, 1)
            renderText(screenX, screenY, self.UI_SIZES.TEXT_SMALL, npc.name)

            local level = self.npcSystem.relationshipManager:getRelationshipLevel(npc.relationship)
            setTextColor(self.UI_COLORS.TEXT_DIM[1], self.UI_COLORS.TEXT_DIM[2],
                        self.UI_COLORS.TEXT_DIM[3], self.UI_COLORS.TEXT_DIM[4])
            renderText(screenX, screenY - 0.02, self.UI_SIZES.TEXT_SMALL * 0.9, level.name)
        end

        setTextAlignment(RenderText.ALIGN_LEFT)
    end
end

function NPCInteractionUI:showInteractionHint(npc, distance)
    if distance < 2 then
        self:hideInteractionHint()
        return
    end

    self.interactionHintVisible = true
    self.interactionHintNPC = npc
    self.interactionHintTimer = 0
end

function NPCInteractionUI:hideInteractionHint()
    self.interactionHintVisible = false
    self.interactionHintNPC = nil
end

-- =========================================================
-- Corner HUD: Active Favors List
-- =========================================================

function NPCInteractionUI:updateFavorList()
    self.favorListNeedsUpdate = true
end

--- Draw the corner HUD showing active favors with progress bars.
-- Color-coded by time remaining: green (>6h), yellow (2-6h), red (<2h).
-- Shows up to 5 favors with an overflow count.
function NPCInteractionUI:drawFavorList()
    if not self.npcSystem.settings.showFavorList then
        return
    end

    local favors = self.npcSystem.favorSystem:getActiveFavors()
    if #favors == 0 then
        return
    end

    if not self.bgOverlay then
        return
    end

    local startX = 0.02
    local startY = 0.7
    local lineHeight = 0.02
    local maxFavors = 5

    -- Draw background using overlay (FS25 requires overlay ID as first arg)
    local bgHeight = math.min(#favors, maxFavors) * lineHeight + 0.03
    setOverlayColor(self.bgOverlay, 0.1, 0.1, 0.1, 0.7)
    renderOverlay(self.bgOverlay, startX - 0.01, startY - bgHeight + 0.02, 0.25, bgHeight)

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(startX, startY, self.UI_SIZES.TEXT_MEDIUM, g_i18n:getText("npc_hud_active_favors") or "Active Favors:")
    setTextBold(false)

    for i = 1, math.min(#favors, maxFavors) do
        local favor = favors[i]
        local yPos = startY - (i * lineHeight)

        local timeRemaining = favor.timeRemaining or 0
        local hours = timeRemaining / (60 * 60 * 1000)

        local timeText
        if hours < 1 then
            timeText = string.format("%.0fm", hours * 60)
        else
            timeText = string.format("%.1fh", hours)
        end

        local npcName = favor.npcName
        if string.len(npcName) > 12 then
            npcName = string.sub(npcName, 1, 10) .. "..."
        end

        local text = string.format("%s - %s [%s]",
            npcName,
            string.sub(favor.description, 1, 20) .. (string.len(favor.description) > 20 and "..." or ""),
            timeText)

        local textColor = self.UI_COLORS.TEXT
        if hours < 2 then
            textColor = self.UI_COLORS.FAVOR_HARD
        elseif hours < 6 then
            textColor = self.UI_COLORS.FAVOR_MEDIUM
        else
            textColor = self.UI_COLORS.FAVOR_EASY
        end

        setTextColor(textColor[1], textColor[2], textColor[3], textColor[4])

        if favor.progress and favor.progress > 0 then
            text = text .. string.format(" (%d%%)", favor.progress)
        end

        renderText(startX, yPos, self.UI_SIZES.TEXT_SMALL, text)

        if favor.progress and favor.progress > 0 then
            local barWidth = 0.1
            local barHeight = 0.005
            local barY = yPos - 0.008

            -- Background bar
            setOverlayColor(self.bgOverlay, 0.1, 0.1, 0.1, 0.8)
            renderOverlay(self.bgOverlay, startX, barY, barWidth, barHeight)

            -- Progress bar
            local progressWidth = barWidth * (favor.progress / 100)
            setOverlayColor(self.bgOverlay, textColor[1], textColor[2], textColor[3], 0.8)
            renderOverlay(self.bgOverlay, startX, barY, progressWidth, barHeight)
        end
    end

    if #favors > maxFavors then
        local yPos = startY - ((maxFavors + 1) * lineHeight)
        setTextColor(0.7, 0.7, 0.7, 1)
        renderText(startX, yPos, self.UI_SIZES.TEXT_SMALL * 0.9,
                   string.format(g_i18n:getText("npc_hud_and_more") or "...and %d more", #favors - maxFavors))
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
end

-- =========================================================
-- Helper Methods (called by NPCDialog.lua)
-- =========================================================

--- Get RGB color for a personality trait (for text coloring).
-- NOTE: Duplicated in NPCDialog:getPersonalityColor(). See note there.
-- @param personality  Personality string (e.g., "hardworking", "lazy")
-- @return table  {r, g, b} color values
function NPCInteractionUI:getPersonalityColor(personality)
    local colors = {
        hardworking = {0.2, 0.8, 0.2},
        lazy = {0.8, 0.8, 0.2},
        social = {0.8, 0.5, 0.2},
        loner = {0.6, 0.6, 0.6},
        generous = {0.2, 0.8, 0.5},
        greedy = {0.8, 0.3, 0.3},
        friendly = {0.3, 0.6, 0.8},
        grumpy = {0.8, 0.4, 0.2}
    }
    return colors[personality] or {0.8, 0.8, 0.8}
end

--- Generate a time-of-day greeting adjusted by relationship level.
-- Low relationship = curt/dismissive, high = warm/friendly.
-- @param npc  NPC data table (uses npc.relationship)
-- @return string  Greeting text
function NPCInteractionUI:getGreetingForNPC(npc)
    local hour = self.npcSystem.scheduler:getCurrentHour()
    local relationship = npc.relationship

    local timeGreeting = ""
    if hour < 12 then
        timeGreeting = g_i18n:getText("npc_greeting_morning") or "Good morning"
    elseif hour < 18 then
        timeGreeting = g_i18n:getText("npc_greeting_afternoon") or "Good afternoon"
    else
        timeGreeting = g_i18n:getText("npc_greeting_evening") or "Good evening"
    end

    if relationship < 20 then
        return string.format(g_i18n:getText("npc_greeting_hostile") or "%s. What do you want?", timeGreeting)
    elseif relationship < 40 then
        return string.format(g_i18n:getText("npc_greeting_unfriendly") or "%s. Need something?", timeGreeting)
    elseif relationship < 60 then
        return g_i18n:getText("npc_dialog_hello") or "Hello there, neighbor!"
    elseif relationship < 80 then
        return string.format(g_i18n:getText("npc_greeting_friendly") or "%s, friend! How are you?", timeGreeting)
    else
        return string.format(g_i18n:getText("npc_greeting_best_friend") or "%s, my good friend! Great to see you!", timeGreeting)
    end
end

--- Pick a random conversation topic based on relationship level and personality.
-- @param npc  NPC data table
-- @return string  Conversation line
function NPCInteractionUI:getRandomConversationTopic(npc)
    local topics = {}

    if npc.relationship < 30 then
        topics = {
            g_i18n:getText("npc_topic_weather") or "The weather has been nice lately, hasn't it?",
            g_i18n:getText("npc_topic_farm") or "How's your farm doing?",
            g_i18n:getText("npc_topic_crops") or "Seen any good crops this season?"
        }
    elseif npc.relationship < 60 then
        topics = {
            g_i18n:getText("npc_topic_family") or "How's the family doing?",
            g_i18n:getText("npc_topic_weekend") or "Got any plans for the weekend?",
            g_i18n:getText("npc_topic_market") or "The market prices have been good this season."
        }
    else
        topics = {
            g_i18n:getText("npc_topic_friend") or "Good to see you, friend! How have you been?",
            g_i18n:getText("npc_topic_harvest_memory") or "Remember that time we helped each other with harvest?",
            g_i18n:getText("npc_topic_best_neighbor") or "You're one of the best neighbors I've had!"
        }
    end

    if npc.personality == "farmer" or npc.personality == "hardworking" then
        table.insert(topics, g_i18n:getText("npc_topic_fields_good") or "The fields are looking good this year.")
        table.insert(topics, g_i18n:getText("npc_topic_harvest_busy") or "Harvest season is always busy but rewarding.")
    elseif npc.personality == "social" then
        table.insert(topics, g_i18n:getText("npc_topic_other_neighbors") or "Have you talked to the other neighbors lately?")
        table.insert(topics, g_i18n:getText("npc_topic_gathering") or "We should have a neighborhood gathering sometime!")
    elseif npc.personality == "loner" then
        table.insert(topics, g_i18n:getText("npc_topic_quiet_day") or "Quiet day today. I like it that way.")
    end

    return topics[math.random(1, #topics)]
end

--- Get a first-person description of the NPC's current activity.
-- @param npc  NPC data table
-- @return string  Work status message in NPC's voice
function NPCInteractionUI:getWorkStatusMessage(npc)
    if not npc.currentAction then
        return g_i18n:getText("npc_work_nothing") or "I'm not doing much right now."
    end

    local messages = {
        idle = g_i18n:getText("npc_work_idle") or "I'm taking a break at the moment.",
        walking = g_i18n:getText("npc_work_walking") or "Just getting some exercise.",
        working = g_i18n:getText("npc_work_working") or "Working on the field. It's hard work but someone's got to do it!",
        driving = g_i18n:getText("npc_work_driving") or "Making some deliveries with my vehicle.",
        resting = g_i18n:getText("npc_work_resting") or "Taking it easy for a while.",
        socializing = g_i18n:getText("npc_work_socializing") or "Chatting with a neighbor.",
        traveling = g_i18n:getText("npc_work_traveling") or "Heading somewhere important."
    }

    return messages[npc.currentAction] or g_i18n:getText("npc_work_busy") or "I'm keeping busy."
end

-- =========================================================
-- Utility
-- =========================================================

--- Project a 3D world position to 2D screen coordinates (0-1 normalized).
-- @param worldX  World X position
-- @param worldY  World Y position
-- @param worldZ  World Z position
-- @return number, number  screenX, screenY (or nil, nil if behind camera)
function NPCInteractionUI:projectWorldToScreen(worldX, worldY, worldZ)
    -- FS25 project() takes 3 args (no camera node) and returns normalized 0-1 coords + depth
    if not project then
        return nil, nil
    end

    local screenX, screenY, screenZ = project(worldX, worldY, worldZ)

    -- screenZ > 0 means the point is in front of the camera
    if screenX and screenY and screenZ and screenZ > 0 then
        return screenX, screenY
    end

    return nil, nil
end

-- =========================================================
-- Cleanup
-- =========================================================

function NPCInteractionUI:delete()
    self:hideInteractionHint()
    if self.bgOverlay then
        delete(self.bgOverlay)
        self.bgOverlay = nil
    end
end
