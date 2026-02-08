-- =========================================================
-- FS25 NPC Favor Mod - Interaction UI
-- =========================================================
-- Handles player-NPC interactions and favor management UI
-- =========================================================

NPCInteractionUI = {}
NPCInteractionUI_mt = Class(NPCInteractionUI)

function NPCInteractionUI.new(npcSystem)
    local self = setmetatable({}, NPCInteractionUI_mt)
    
    self.npcSystem = npcSystem
    
    -- UI State
    self.isDialogOpen = false
    self.currentNPC = nil
    self.interactionHintVisible = false
    self.interactionHintNPC = nil
    self.interactionHintTimer = 0
    
    -- UI Elements
    self.uiElements = {
        dialogBackground = nil,
        dialogTitle = nil,
        dialogText = nil,
        dialogOptions = {},
        favorList = nil,
        relationshipBar = nil,
        giftSelection = nil
    }
    
    -- Favor UI
    self.activeFavorWindow = nil
    self.favorDetailsWindow = nil
    
    -- Constants
    self.UI_COLORS = {
        BACKGROUND = {0.1, 0.1, 0.1, 0.9},
        BACKGROUND_LIGHT = {0.2, 0.2, 0.2, 0.8},
        TEXT = {1, 1, 1, 1},
        TEXT_DIM = {0.8, 0.8, 0.8, 1},
        TEXT_HIGHLIGHT = {1, 1, 0.8, 1},
        HIGHLIGHT = {0.3, 0.6, 0.3, 1},
        HIGHLIGHT_ALT = {0.3, 0.3, 0.6, 1},
        BUTTON_NORMAL = {0.2, 0.2, 0.2, 0.8},
        BUTTON_HOVER = {0.3, 0.5, 0.3, 0.9},
        BUTTON_ACTIVE = {0.4, 0.7, 0.4, 1.0},
        BUTTON_DANGER = {0.6, 0.3, 0.3, 0.9},
        RELATIONSHIP_LOW = {1, 0.3, 0.3, 1},
        RELATIONSHIP_MED = {1, 0.8, 0.3, 1},
        RELATIONSHIP_HIGH = {0.3, 1, 0.3, 1},
        FAVOR_EASY = {0.3, 0.8, 0.3, 1},
        FAVOR_MEDIUM = {0.8, 0.8, 0.3, 1},
        FAVOR_HARD = {0.8, 0.3, 0.3, 1}
    }
    
    -- UI Sizes
    self.UI_SIZES = {
        DIALOG_WIDTH = 0.4,
        DIALOG_HEIGHT = 0.3,
        OPTION_HEIGHT = 0.03,
        TEXT_SMALL = 0.014,
        TEXT_MEDIUM = 0.016,
        TEXT_LARGE = 0.020,
        MARGIN = 0.01
    }
    
    -- Input handling
    self.inputCooldown = 0
    self.inputCooldownDuration = 0.2 -- 200ms cooldown

    -- Dialog option cycling (E key navigates, Q closes)
    self.selectedOptionIndex = 0  -- 0 = no selection yet, 1+ = option index
    self.lastOptionExecuteTime = 0

    -- Animation
    self.animationTime = 0
    self.dialogOpenAnimation = false

    return self
end

function NPCInteractionUI:update(dt)
    -- Update input cooldown
    if self.inputCooldown > 0 then
        self.inputCooldown = self.inputCooldown - dt
    end
    
    -- Update animation
    self.animationTime = self.animationTime + dt
    
    -- Update interaction hint with timer
    self:updateInteractionHint(dt)
    
    -- Check for interaction key press
    self:checkInteractionInput()
    
    -- Update and render dialog if open
    if self.isDialogOpen then
        self:updateDialog(dt)
        self:drawDialogBackground()
        self:drawDialogContent()
        self:drawDialogOptions()

        -- Show current message if any
        if self.showingMessage and self.dialogMessage then
            self:drawDialogMessage()
        end
    end
    
    -- Draw active favors list
    if self.npcSystem.settings.showFavorList then
        self:drawFavorList()
    end
end

function NPCInteractionUI:updateInteractionHint(dt)
    if not self.interactionHintVisible or not self.interactionHintNPC then
        self.interactionHintTimer = 0
        return
    end
    
    self.interactionHintTimer = self.interactionHintTimer + dt
    
    -- Draw hint above NPC
    local npc = self.interactionHintNPC
    local x, y, z = npc.position.x, npc.position.y + 2.5, npc.position.z
    
    -- Convert world position to screen position
    local screenX, screenY = self:projectWorldToScreen(x, y, z)
    
    if screenX and screenY then
        -- Calculate animation (pulse effect)
        local pulse = 0.5 + 0.5 * math.sin(self.interactionHintTimer * 3)
        
        -- Draw "Press E to talk" text with pulse effect
        local text = g_i18n:getText("npc_interact_hint") or "Press [E] to talk"
        
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, pulse, 1)
        renderText(screenX, screenY + 0.05, self.UI_SIZES.TEXT_MEDIUM, text)
        setTextBold(false)
        
        -- Draw NPC name
        if self.npcSystem.settings.showNames then
            local relationship = self.npcSystem.relationshipManager:getRelationshipColor(npc.relationship)
            setTextColor(relationship.r, relationship.g, relationship.b, 1)
            renderText(screenX, screenY, self.UI_SIZES.TEXT_SMALL, npc.name)
            
            -- Draw relationship level
            local level = self.npcSystem.relationshipManager:getRelationshipLevel(npc.relationship)
            setTextColor(self.UI_COLORS.TEXT_DIM[1], self.UI_COLORS.TEXT_DIM[2], 
                        self.UI_COLORS.TEXT_DIM[3], self.UI_COLORS.TEXT_DIM[4])
            renderText(screenX, screenY - 0.02, self.UI_SIZES.TEXT_SMALL * 0.9, level.name)
        end
        
        setTextAlignment(RenderText.ALIGN_LEFT)
    end
end

function NPCInteractionUI:showInteractionHint(npc, distance)
    -- Only show hint if not too close to prevent flickering
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

function NPCInteractionUI:checkInteractionInput()
    -- Input is handled via action events in main.lua (NPC_INTERACT + NPC_DIALOG_CLOSE)
    -- E key: opens dialog or cycles options (npcInteractActionCallback)
    -- Q key: closes dialog (npcDialogCloseCallback)
end

-- Called by main.lua E key callback when dialog is open
function NPCInteractionUI:selectAndExecuteNextOption()
    if not self.isDialogOpen or not self.currentNPC then
        return
    end

    -- Throttle rapid presses
    local currentTime = g_currentMission and g_currentMission.time or 0
    if currentTime - self.lastOptionExecuteTime < 500 then
        return
    end
    self.lastOptionExecuteTime = currentTime

    -- Reset auto-close timer on interaction
    self.dialogAutoCloseTimer = 0

    local options = self:getDialogOptions()
    if #options == 0 then
        return
    end

    -- Advance to next option
    self.selectedOptionIndex = self.selectedOptionIndex + 1
    if self.selectedOptionIndex > #options then
        self.selectedOptionIndex = 1
    end

    local selected = options[self.selectedOptionIndex]
    if selected then
        if self.npcSystem.settings.debugMode then
            print(string.format("[NPC Favor] Dialog option: %s (%s)", selected.text, selected.action))
        end
        self:handleDialogOption(selected.action)
    end
end

-- Returns the name of the next option (for E key prompt text)
function NPCInteractionUI:getCurrentOptionName()
    if not self.isDialogOpen or not self.currentNPC then
        return nil
    end

    local options = self:getDialogOptions()
    if #options == 0 then
        return nil
    end

    local nextIndex = self.selectedOptionIndex + 1
    if nextIndex > #options then
        nextIndex = 1
    end

    local nextOption = options[nextIndex]
    if nextOption then
        return nextOption.text
    end

    return "Next option"
end

function NPCInteractionUI:openDialog(npc)
    if not npc or not npc.canInteract or self.isDialogOpen then
        return
    end
    
    self.currentNPC = npc
    self.isDialogOpen = true
    self.dialogOpenAnimation = true
    self.animationTime = 0
    self.selectedOptionIndex = 0  -- Reset option cycling
    self.lastOptionExecuteTime = 0
    
    -- Create dialog UI
    self:createDialogUI()
    
    -- Update relationship info
    self:updateRelationshipDisplay()
    
    -- Play sound if enabled
    if self.npcSystem.settings.soundEffects and g_soundManager then
        g_soundManager:playSample(g_soundManager.samples.GUI_CLICK)
    end
    
    if self.npcSystem.settings.debugMode then
        print(string.format("Opened dialog with %s (Relationship: %d)", 
            npc.name, npc.relationship))
    end
end

function NPCInteractionUI:createDialogUI()
    -- In actual implementation, create proper UI elements
    -- For now, we'll use the existing debug rendering system
    print("Dialog UI created (simulated)")
end

function NPCInteractionUI:updateDialog(dt)
    if not self.isDialogOpen then
        return
    end

    -- Auto-close after 60 seconds of inactivity
    self.dialogAutoCloseTimer = (self.dialogAutoCloseTimer or 0) + dt
    if self.dialogAutoCloseTimer > 60 then
        self:closeDialog()
        self.dialogAutoCloseTimer = 0
        return
    end

    -- Decay dialog message timer
    if self.showingMessage and self.messageTimer then
        self.messageTimer = self.messageTimer - dt
        if self.messageTimer <= 0 then
            self.showingMessage = false
            self.dialogMessage = nil
        end
    end
end

function NPCInteractionUI:drawDialogMessage()
    if not self.dialogMessage then
        return
    end

    local centerX = 0.5
    local centerY = 0.5
    local width = self.UI_SIZES.DIALOG_WIDTH - 0.04
    local msgY = centerY - 0.02

    -- Message background
    setOverlayColor(0.15, 0.15, 0.2, 0.95)
    renderOverlay(centerX - width/2, msgY - 0.04, width, 0.08)

    -- Message text (handle newlines by splitting)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(0.9, 0.95, 1.0, 1)

    local lines = {}
    for line in self.dialogMessage:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    for i, line in ipairs(lines) do
        local lineY = msgY + 0.02 - (i - 1) * 0.018
        renderText(centerX, lineY, self.UI_SIZES.TEXT_SMALL, line)
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
end

function NPCInteractionUI:drawDialogBackground()
    -- Safety check for animation time
    if not self.animationTime then
        self.animationTime = 0
    end
    
    -- Calculate animation progress
    local animationProgress = 1.0
    if self.dialogOpenAnimation then
        animationProgress = math.min(1.0, self.animationTime * 5) -- 0.2 second animation
        if animationProgress >= 1.0 then
            self.dialogOpenAnimation = false
        end
    end
    
    -- Get screen dimensions
    local screenWidth, screenHeight = getScreenMode()
    if not screenWidth or not screenHeight then
        return
    end
    
    -- Draw semi-transparent overlay
    local overlayColor = self.UI_COLORS.BACKGROUND
    setOverlayColor(overlayColor[1], overlayColor[2], overlayColor[3], overlayColor[4] * 0.7 * animationProgress)
    renderOverlay(0, 0, 1, 1)
    
    -- Draw dialog box with animation
    local centerX = 0.5
    local centerY = 0.5
    local width = self.UI_SIZES.DIALOG_WIDTH * animationProgress
    local height = self.UI_SIZES.DIALOG_HEIGHT * animationProgress
    
    -- Dialog background
    setOverlayColor(unpack(self.UI_COLORS.BACKGROUND))
    renderOverlay(centerX - width/2, centerY - height/2, width, height)
    
    -- Draw border with highlight
    local borderThickness = 0.002
    setOverlayColor(unpack(self.UI_COLORS.HIGHLIGHT))
    
    -- Top border
    renderOverlay(centerX - width/2, centerY - height/2, width, borderThickness)
    -- Bottom border
    renderOverlay(centerX - width/2, centerY + height/2 - borderThickness, width, borderThickness)
    -- Left border
    renderOverlay(centerX - width/2, centerY - height/2, borderThickness, height)
    -- Right border
    renderOverlay(centerX + width/2 - borderThickness, centerY - height/2, borderThickness, height)
    
    -- Draw corners
    local cornerSize = 0.008
    setOverlayColor(unpack(self.UI_COLORS.HIGHLIGHT_ALT))
    renderOverlay(centerX - width/2, centerY - height/2, cornerSize, cornerSize) -- Top-left
    renderOverlay(centerX + width/2 - cornerSize, centerY - height/2, cornerSize, cornerSize) -- Top-right
    renderOverlay(centerX - width/2, centerY + height/2 - cornerSize, cornerSize, cornerSize) -- Bottom-left
    renderOverlay(centerX + width/2 - cornerSize, centerY + height/2 - cornerSize, cornerSize, cornerSize) -- Bottom-right
    
    -- Reset overlay color
    setOverlayColor(0, 0, 0, 0)
end

function NPCInteractionUI:drawDialogContent()
    if not self.currentNPC then
        return
    end
    
    local npc = self.currentNPC
    local centerX = 0.5
    local centerY = 0.5
    local width = self.UI_SIZES.DIALOG_WIDTH
    local height = self.UI_SIZES.DIALOG_HEIGHT
    
    -- NPC name with personality
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(centerX, centerY + height/2 - 0.04, self.UI_SIZES.TEXT_LARGE, npc.name)
    setTextBold(false)
    
    -- Personality tag
    local personalityColor = self:getPersonalityColor(npc.personality)
    setTextColor(personalityColor[1], personalityColor[2], personalityColor[3], 1)
    renderText(centerX, centerY + height/2 - 0.07, self.UI_SIZES.TEXT_SMALL, 
               string.format("(%s)", npc.personality))
    
    -- Greeting based on relationship and time of day
    local greeting = self:getGreetingForNPC(npc)
    setTextColor(0.9, 0.9, 0.9, 1)
    renderText(centerX, centerY + height/2 - 0.10, self.UI_SIZES.TEXT_MEDIUM, greeting)
    
    -- Relationship info with bar
    self:drawRelationshipBar(npc, centerX, centerY + height/2 - 0.15)
    
    -- Current status
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(centerX, centerY + height/2 - 0.20, self.UI_SIZES.TEXT_SMALL, 
               "Current: " .. npc.currentAction)
    
    -- Last interaction time
    if npc.lastInteractionTime and npc.lastInteractionTime > 0 then
        local timeSince = g_currentMission.time - npc.lastInteractionTime
        local days = math.floor(timeSince / (24 * 60 * 60 * 1000))
        
        if days > 0 then
            local dayText = days == 1 and "day" or "days"
            setTextColor(0.7, 0.7, 0.7, 1)
            renderText(centerX, centerY + height/2 - 0.23, self.UI_SIZES.TEXT_SMALL * 0.9, 
                       string.format("Last talked: %d %s ago", days, dayText))
        end
    end
    
    setTextAlignment(RenderText.ALIGN_LEFT)
end

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

function NPCInteractionUI:getGreetingForNPC(npc)
    local hour = self.npcSystem.scheduler:getCurrentHour()
    local relationship = npc.relationship
    
    -- Time-based greetings
    local timeGreeting = ""
    if hour < 12 then
        timeGreeting = "Good morning"
    elseif hour < 18 then
        timeGreeting = "Good afternoon"
    else
        timeGreeting = "Good evening"
    end
    
    -- Relationship-based modifiers
    if relationship < 20 then
        return string.format("%s. What do you want?", timeGreeting)
    elseif relationship < 40 then
        return string.format("%s. Need something?", timeGreeting)
    elseif relationship < 60 then
        return g_i18n:getText("npc_dialog_hello") or "Hello there, neighbor!"
    elseif relationship < 80 then
        return string.format("%s, friend! How are you?", timeGreeting)
    else
        return string.format("%s, my good friend! Great to see you!", timeGreeting)
    end
end

function NPCInteractionUI:drawRelationshipBar(npc, centerX, yPos)
    local width = 0.2
    local height = 0.015
    
    -- Draw background bar
    setOverlayColor(0.1, 0.1, 0.1, 0.8)
    renderOverlay(centerX - width/2, yPos, width, height)
    
    -- Draw filled portion based on relationship
    local fillWidth = width * (npc.relationship / 100)
    local relationshipColor = self.npcSystem.relationshipManager:getRelationshipColor(npc.relationship)
    setOverlayColor(relationshipColor.r, relationshipColor.g, relationshipColor.b, 0.8)
    renderOverlay(centerX - width/2, yPos, fillWidth, height)
    
    -- Draw border
    setOverlayColor(0.3, 0.3, 0.3, 1)
    renderOverlay(centerX - width/2, yPos, width, 0.001) -- Top
    renderOverlay(centerX - width/2, yPos + height - 0.001, width, 0.001) -- Bottom
    renderOverlay(centerX - width/2, yPos, 0.001, height) -- Left
    renderOverlay(centerX + width/2 - 0.001, yPos, 0.001, height) -- Right
    
    -- Draw relationship text
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(1, 1, 1, 1)
    local level = self.npcSystem.relationshipManager:getRelationshipLevel(npc.relationship)
    renderText(centerX, yPos - 0.005, self.UI_SIZES.TEXT_SMALL, 
               string.format("Relationship: %d/100 (%s)", npc.relationship, level.name))
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function NPCInteractionUI:drawDialogOptions()
    local centerX = 0.5
    local centerY = 0.5
    local width = self.UI_SIZES.DIALOG_WIDTH
    local height = self.UI_SIZES.DIALOG_HEIGHT

    local options = self:getDialogOptions()
    local optionHeight = self.UI_SIZES.OPTION_HEIGHT
    local spacing = 0.005

    -- Calculate total options height
    local totalHeight = #options * (optionHeight + spacing) - spacing
    local startY = centerY - totalHeight/2 + 0.02

    -- Determine which option will be selected next (for highlighting)
    local nextIndex = self.selectedOptionIndex + 1
    if nextIndex > #options then
        nextIndex = 1
    end

    for i, option in ipairs(options) do
        local optionX = centerX - width/2 + self.UI_SIZES.MARGIN
        local optionY = startY + (i-1) * (optionHeight + spacing)
        local optionWidth = width - 2 * self.UI_SIZES.MARGIN

        -- Highlight the next option that E will execute
        local isNext = (i == nextIndex)
        local isDisabled = option.disabled or false
        local wasLastSelected = (i == self.selectedOptionIndex)

        -- Draw button background
        local color = self.UI_COLORS.BUTTON_NORMAL
        if isDisabled then
            color = {0.1, 0.1, 0.1, 0.5}
        elseif isNext then
            color = self.UI_COLORS.BUTTON_HOVER  -- Highlight next option
        elseif wasLastSelected then
            color = self.UI_COLORS.BUTTON_ACTIVE  -- Show last executed
        elseif option.isDanger then
            color = self.UI_COLORS.BUTTON_DANGER
        end

        setOverlayColor(unpack(color))
        renderOverlay(optionX, optionY, optionWidth, optionHeight)

        -- Draw border on highlighted option
        if isNext and not isDisabled then
            setOverlayColor(unpack(self.UI_COLORS.HIGHLIGHT))
            renderOverlay(optionX, optionY, optionWidth, 0.001)
            renderOverlay(optionX, optionY + optionHeight - 0.001, optionWidth, 0.001)
            renderOverlay(optionX, optionY, 0.001, optionHeight)
            renderOverlay(optionX + optionWidth - 0.001, optionY, 0.001, optionHeight)
        end

        -- Draw button text with arrow indicator for next option
        setTextAlignment(RenderText.ALIGN_CENTER)
        if isDisabled then
            setTextColor(0.5, 0.5, 0.5, 1)
        elseif isNext then
            setTextColor(1, 1, 0.8, 1)  -- Highlighted text color
        else
            setTextColor(1, 1, 1, 1)
        end

        local displayText = option.text
        if isNext then
            displayText = "> " .. option.text .. " <"
        end

        renderText(optionX + optionWidth/2, optionY + optionHeight/2 - 0.005,
                   self.UI_SIZES.TEXT_SMALL, displayText)
    end

    -- Draw key hints at bottom of dialog
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(0.6, 0.6, 0.6, 1)
    local hintY = startY - 0.02
    renderText(centerX, hintY, self.UI_SIZES.TEXT_SMALL * 0.85, "[E] Select option  [Q] Close")

    setTextAlignment(RenderText.ALIGN_LEFT)
end

function NPCInteractionUI:getDialogOptions()
    if not self.currentNPC then
        return {}
    end
    
    local npc = self.currentNPC
    local options = {}
    
    -- Always available options
    table.insert(options, {
        text = "Talk",
        action = "talk",
        description = "Have a conversation"
    })
    
    table.insert(options, {
        text = "Ask about work",
        action = "ask_work",
        description = "Ask what they're working on"
    })
    
    -- Favor options based on relationship
    if npc.relationship >= 20 then
        local hasActiveFavor = false
        for _, favor in ipairs(self.npcSystem.favorSystem:getActiveFavors()) do
            if favor.npcId == npc.id then
                hasActiveFavor = true
                break
            end
        end
        
        if hasActiveFavor then
            table.insert(options, {
                text = "Check favor progress",
                action = "check_favor",
                description = "Check progress on active favor"
            })
        else
            table.insert(options, {
                text = "Ask for favor",
                action = "ask_favor",
                description = "Ask if they need help with something"
            })
        end
    end
    
    -- Gift options based on relationship
    if npc.relationship >= 30 then
        table.insert(options, {
            text = "Give gift",
            action = "give_gift",
            description = "Give a gift to improve relationship"
        })
    end
    
    -- Relationship info
    table.insert(options, {
        text = "Relationship info",
        action = "check_relationship",
        description = "View detailed relationship information"
    })
    
    -- Close option
    table.insert(options, {
        text = "Close",
        action = "close",
        isActive = true
    })
    
    return options
end

function NPCInteractionUI:handleDialogOption(action)
    if not self.currentNPC then
        return
    end
    
    local npc = self.currentNPC
    
    if action == "talk" then
        self:showDialogMessage(self:getRandomConversationTopic(npc))
        
    elseif action == "ask_work" then
        self:showDialogMessage(self:getWorkStatusMessage(npc))
        
    elseif action == "ask_favor" then
        self:handleAskFavor(npc)
        
    elseif action == "check_favor" then
        self:showActiveFavorDetails(npc)
        
    elseif action == "give_gift" then
        self:openGiftSelection(npc)
        
    elseif action == "check_relationship" then
        self:showRelationshipDetails(npc)
        
    elseif action == "close" then
        self:closeDialog()
    end
end

function NPCInteractionUI:getRandomConversationTopic(npc)
    local topics = {}
    
    -- Add relationship-based topics
    if npc.relationship < 30 then
        topics = {
            "The weather has been nice lately, hasn't it?",
            "How's your farm doing?",
            "Seen any good crops this season?"
        }
    elseif npc.relationship < 60 then
        topics = {
            "How's the family doing?",
            "Got any plans for the weekend?",
            "The market prices have been good this season."
        }
    else
        topics = {
            "Good to see you, friend! How have you been?",
            "Remember that time we helped each other with harvest?",
            "You're one of the best neighbors I've had!"
        }
    end
    
    -- Add personality-based topics
    if npc.personality == "farmer" or npc.personality == "hardworking" then
        table.insert(topics, "The fields are looking good this year.")
        table.insert(topics, "Harvest season is always busy but rewarding.")
    elseif npc.personality == "social" then
        table.insert(topics, "Have you talked to the other neighbors lately?")
        table.insert(topics, "We should have a neighborhood gathering sometime!")
    elseif npc.personality == "loner" then
        table.insert(topics, "Quiet day today. I like it that way.")
    end
    
    return topics[math.random(1, #topics)]
end

function NPCInteractionUI:getWorkStatusMessage(npc)
    if not npc.currentAction then
        return "I'm not doing much right now."
    end
    
    local messages = {
        idle = "I'm taking a break at the moment.",
        walking = "Just getting some exercise.",
        working = "Working on the field. It's hard work but someone's got to do it!",
        driving = "Making some deliveries with my vehicle.",
        resting = "Taking it easy for a while.",
        socializing = "Chatting with a neighbor.",
        traveling = "Heading somewhere important."
    }
    
    return messages[npc.currentAction] or "I'm keeping busy."
end

function NPCInteractionUI:handleAskFavor(npc)
    -- NPC asks for favor
    if self.npcSystem.favorSystem:tryGenerateFavorRequest() then
        self:showDialogMessage(string.format("%s: \"Could you help me with something?\"", npc.name))
    else
        self:showDialogMessage(string.format("%s: \"I don't need anything right now, but thanks for asking!\"", npc.name))
    end
end

function NPCInteractionUI:showActiveFavorDetails(npc)
    -- Find active favor for this NPC
    local activeFavor = nil
    for _, favor in ipairs(self.npcSystem.favorSystem:getActiveFavors()) do
        if favor.npcId == npc.id then
            activeFavor = favor
            break
        end
    end
    
    if not activeFavor then
        self:showDialogMessage("No active favors with this NPC.")
        return
    end
    
    -- Calculate time remaining
    local timeRemaining = activeFavor.timeRemaining or 0
    local hours = timeRemaining / (60 * 60 * 1000)
    
    local timeText
    if hours < 1 then
        local minutes = hours * 60
        timeText = string.format("%.0f minutes", minutes)
    else
        timeText = string.format("%.1f hours", hours)
    end
    
    local message = string.format(
        "Active Favor: %s\n" ..
        "Progress: %d%%\n" ..
        "Time remaining: %s\n" ..
        "Reward: +%d relationship, $%d",
        activeFavor.description,
        activeFavor.progress or 0,
        timeText,
        activeFavor.reward.relationship or 0,
        activeFavor.reward.money or 0
    )
    
    self:showDialogMessage(message)
end

function NPCInteractionUI:openGiftSelection(npc)
    -- In full implementation, show gift selection UI
    -- For now, give a simple gift
    local giftResult = self.npcSystem.relationshipManager:giveGiftToNPC(
        npc.id, 
        "money", 
        500
    )
    
    if giftResult then
        self:showDialogMessage(string.format("You gave a gift to %s. They appreciate it!", npc.name))
    else
        self:showDialogMessage("Couldn't give a gift right now.")
    end
end

function NPCInteractionUI:showRelationshipDetails(npc)
    local info = self.npcSystem.relationshipManager:getRelationshipInfo(npc.id)
    if not info then
        self:showDialogMessage("No relationship information available.")
        return
    end
    
    -- Calculate favor statistics
    local completedFavors = 0
    local failedFavors = 0
    
    for _, favor in ipairs(self.npcSystem.favorSystem:getCompletedFavors()) do
        if favor.npcId == npc.id then
            completedFavors = completedFavors + 1
        end
    end
    
    for _, favor in ipairs(self.npcSystem.favorSystem:getFailedFavors()) do
        if favor.npcId == npc.id then
            failedFavors = failedFavors + 1
        end
    end
    
    local totalFavors = completedFavors + failedFavors
    local successRate = totalFavors > 0 and math.floor((completedFavors / totalFavors) * 100) or 0
    
    local details = string.format(
        "Relationship with %s:\n" ..
        "Level: %s (%d/100)\n" ..
        "Favors: %d completed, %d failed (%d%% success rate)\n" ..
        "Personality: %s\n" ..
        "Next favor possible: %s",
        info.npc.name,
        info.level.name,
        info.value,
        completedFavors,
        failedFavors,
        successRate,
        info.npc.personality,
        info.nextFavorEstimate or "now"
    )
    
    self:showDialogMessage(details)
end

function NPCInteractionUI:showDialogMessage(message)
    -- Store message for display
    self.dialogMessage = message
    self.showingMessage = true
    self.messageTimer = 5.0 -- Show for 5 seconds
end

function NPCInteractionUI:updateRelationshipDisplay()
    -- Update relationship bar color and value
    if not self.currentNPC then
        return
    end
    
    local npc = self.currentNPC
    local color = self.npcSystem.relationshipManager:getRelationshipColor(npc.relationship)
    
    -- Could update UI elements here
    -- For now, just update the color cache
    self.currentRelationshipColor = color
end

function NPCInteractionUI:closeDialog()
    self.isDialogOpen = false
    self.currentNPC = nil
    self.dialogMessage = nil
    self.showingMessage = false
    self.dialogOpenAnimation = false
    
    -- Play sound if enabled
    if self.npcSystem.settings.soundEffects and g_soundManager then
        g_soundManager:playSample(g_soundManager.samples.GUI_CLICK)
    end
end

function NPCInteractionUI:updateFavorList()
    -- Update the displayed list of active favors
    -- Called when favors are added or completed
    self.favorListNeedsUpdate = true
end

function NPCInteractionUI:drawFavorList()
    if not self.npcSystem.settings.showFavorList then
        return
    end
    
    local favors = self.npcSystem.favorSystem:getActiveFavors()
    if #favors == 0 then
        return
    end
    
    -- Draw favor list in corner of screen
    local startX = 0.02
    local startY = 0.7
    local lineHeight = 0.02
    local maxFavors = 5 -- Show max 5 favors at once
    
    -- Background for favor list
    local bgHeight = math.min(#favors, maxFavors) * lineHeight + 0.03
    setOverlayColor(0.1, 0.1, 0.1, 0.7)
    renderOverlay(startX - 0.01, startY - bgHeight + 0.02, 0.25, bgHeight)
    
    -- Title
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(startX, startY, self.UI_SIZES.TEXT_MEDIUM, "Active Favors:")
    setTextBold(false)
    
    for i = 1, math.min(#favors, maxFavors) do
        local favor = favors[i]
        local yPos = startY - (i * lineHeight)
        
        -- Calculate time remaining
        local timeRemaining = favor.timeRemaining or 0
        local hours = timeRemaining / (60 * 60 * 1000)
        
        local timeText
        if hours < 1 then
            local minutes = hours * 60
            timeText = string.format("%.0fm", minutes)
        else
            timeText = string.format("%.1fh", hours)
        end
        
        -- Truncate NPC name if too long
        local npcName = favor.npcName
        if string.len(npcName) > 12 then
            npcName = string.sub(npcName, 1, 10) .. "..."
        end
        
        -- Draw favor info
        local text = string.format("%s - %s [%s]", 
            npcName, 
            string.sub(favor.description, 1, 20) .. (string.len(favor.description) > 20 and "..." or ""), 
            timeText)
        
        -- Color based on urgency
        local textColor = self.UI_COLORS.TEXT
        if hours < 2 then
            textColor = self.UI_COLORS.FAVOR_HARD -- Red for urgent
        elseif hours < 6 then
            textColor = self.UI_COLORS.FAVOR_MEDIUM -- Yellow for medium
        else
            textColor = self.UI_COLORS.FAVOR_EASY -- Green for plenty of time
        end
        
        setTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
        
        -- Add progress indicator for multi-step favors
        if favor.progress and favor.progress > 0 then
            text = text .. string.format(" (%d%%)", favor.progress)
        end
        
        renderText(startX, yPos, self.UI_SIZES.TEXT_SMALL, text)
        
        -- Draw progress bar for favors with progress
        if favor.progress and favor.progress > 0 then
            local barWidth = 0.1
            local barHeight = 0.005
            local barY = yPos - 0.008
            
            -- Background
            setOverlayColor(0.1, 0.1, 0.1, 0.8)
            renderOverlay(startX, barY, barWidth, barHeight)
            
            -- Progress
            local progressWidth = barWidth * (favor.progress / 100)
            setOverlayColor(textColor[1], textColor[2], textColor[3], 0.8)
            renderOverlay(startX, barY, progressWidth, barHeight)
        end
    end
    
    -- Show "more" indicator if there are more favors
    if #favors > maxFavors then
        local yPos = startY - ((maxFavors + 1) * lineHeight)
        setTextColor(0.7, 0.7, 0.7, 1)
        renderText(startX, yPos, self.UI_SIZES.TEXT_SMALL * 0.9, 
                   string.format("...and %d more", #favors - maxFavors))
    end
    
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function NPCInteractionUI:projectWorldToScreen(worldX, worldY, worldZ)
    if not g_currentMission or not g_currentMission.camera then
        return nil, nil
    end
    
    -- Get camera properties
    local cameraNode = g_currentMission.camera
    local screenWidth, screenHeight = getScreenMode()
    
    -- Convert world to screen coordinates
    local screenX, screenY, screenZ = project(cameraNode, worldX, worldY, worldZ)
    
    if screenX and screenY then
        -- Normalize to 0-1 range
        screenX = screenX / screenWidth
        screenY = screenY / screenHeight
        return screenX, screenY
    end
    
    return nil, nil
end

function NPCInteractionUI:delete()
    -- Clean up UI elements
    self:closeDialog()
    self:hideInteractionHint()
    
    -- Clear any UI elements that were created
    for _, element in pairs(self.uiElements) do
        if element and element.delete then
            element:delete()
        end
    end
    
    self.uiElements = {}
end