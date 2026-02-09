-- =========================================================
-- FS25 NPC Favor Mod - NPC List Dialog
-- =========================================================
-- MessageDialog subclass that displays all active NPCs in a
-- styled popup table with per-column elements, color coding,
-- and per-row "Go" buttons to teleport to an NPC.
--
-- Shown via: DialogLoader.show("NPCListDialog", "setNPCSystem", g_NPCSystem)
-- =========================================================

NPCListDialog = {}
local NPCListDialog_mt = Class(NPCListDialog, MessageDialog)

NPCListDialog.MAX_ROWS = 16

-- Column suffixes matching XML id pattern: r{N}{suffix}
NPCListDialog.COLUMNS = {"num", "name", "act", "dist", "rel", "farm"}

function NPCListDialog.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or NPCListDialog_mt)
    self.npcSystem = nil
    self.rowNPCIndex = {}  -- rowNum -> activeNPCs index
    return self
end

function NPCListDialog:onCreate()
    local ok, err = pcall(function()
        NPCListDialog:superClass().onCreate(self)
    end)
    if not ok then
        print("[NPC Favor] NPCListDialog:onCreate() error: " .. tostring(err))
    end
end

function NPCListDialog:setNPCSystem(npcSystem)
    self.npcSystem = npcSystem
end

function NPCListDialog:onOpen()
    local ok, err = pcall(function()
        NPCListDialog:superClass().onOpen(self)
    end)
    if not ok then
        print("[NPC Favor] NPCListDialog:onOpen() error: " .. tostring(err))
        return
    end
    self:updateDisplay()
end

function NPCListDialog:updateDisplay()
    local sys = self.npcSystem
    if not sys then
        if self.titleText then self.titleText:setText("NPC System Not Available") end
        return
    end

    -- Reset row->NPC mapping
    self.rowNPCIndex = {}

    -- Title
    if self.titleText then
        self.titleText:setText(string.format("NPC Roster  (%d/%d)",
            sys.npcCount or 0, sys.settings and sys.settings.maxNPCs or 0))
    end

    -- Subtitle
    if self.subtitleText then
        local gameTime = sys:getCurrentGameTime()
        local hour = math.floor(gameTime / 60) % 24
        local min = math.floor(gameTime) % 60
        self.subtitleText:setText(string.format("Game Time: %02d:%02d", hour, min))
    end

    -- Clear all rows
    for i = 1, self.MAX_ROWS do
        self:clearRow(i)
    end

    -- Fill rows from active NPCs
    local rowIdx = 0
    if sys.activeNPCs then
        for i, npc in ipairs(sys.activeNPCs) do
            if npc.isActive and rowIdx < self.MAX_ROWS then
                rowIdx = rowIdx + 1
                self:fillRow(rowIdx, i, npc, sys)
            end
        end
    end

    -- Hide unused row backgrounds
    for i = rowIdx + 1, self.MAX_ROWS do
        local bg = self["r" .. i .. "bg"]
        if bg then bg:setVisible(false) end
    end

    -- Hide bottom divider if we used all rows (it'll overlap the button box)
    if self.bottomDivider then
        self.bottomDivider:setVisible(rowIdx > 0)
    end

    -- Footer
    if self.footerText then
        self.footerText:setText("Click Go to teleport to an NPC  |  Press E near NPC to interact")
    end
end

--- Clear a row's cells, hide its background and Go button layers.
function NPCListDialog:clearRow(rowNum)
    local prefix = "r" .. rowNum
    for _, col in ipairs(self.COLUMNS) do
        local elem = self[prefix .. col]
        if elem then
            elem:setText("")
            elem:setVisible(false)
        end
    end
    local bg = self[prefix .. "bg"]
    if bg then bg:setVisible(false) end
    -- 3-layer Go button: bg, text, hit
    local gobg = self[prefix .. "gobg"]
    if gobg then gobg:setVisible(false) end
    local gotxt = self[prefix .. "gotxt"]
    if gotxt then gotxt:setVisible(false) end
    local goBtn = self[prefix .. "go"]
    if goBtn then goBtn:setVisible(false) end
end

--- Fill a row with NPC data and color-code the cells.
function NPCListDialog:fillRow(rowNum, npcIndex, npc, sys)
    local prefix = "r" .. rowNum

    -- Store NPC index for teleport
    self.rowNPCIndex[rowNum] = npcIndex

    -- Show background
    local bg = self[prefix .. "bg"]
    if bg then bg:setVisible(true) end

    -- Show 3-layer Go button: bg, text, hit
    local gobg = self[prefix .. "gobg"]
    if gobg then gobg:setVisible(true) end
    local gotxt = self[prefix .. "gotxt"]
    if gotxt then gotxt:setVisible(true) end
    local goBtn = self[prefix .. "go"]
    if goBtn then goBtn:setVisible(true) end

    -- # column (index)
    local numElem = self[prefix .. "num"]
    if numElem then
        numElem:setText(tostring(npcIndex))
        numElem:setVisible(true)
    end

    -- Name column (bold white, personality-tinted)
    local nameElem = self[prefix .. "name"]
    if nameElem then
        nameElem:setText((npc.name or "Unknown"):sub(1, 18))
        nameElem:setVisible(true)
        local pr, pg, pb = self:getPersonalityColor(npc.personality)
        nameElem:setTextColor(pr, pg, pb, 1)
    end

    -- Activity column (role + current action)
    local actElem = self[prefix .. "act"]
    if actElem then
        local action = npc.currentAction or npc.aiState or "idle"
        actElem:setText(action:sub(1, 12))
        actElem:setVisible(true)
        -- Color: green for active states, dim for idle/sleeping
        if action == "idle" or action == "sleeping" or action == "resting" then
            actElem:setTextColor(0.55, 0.55, 0.6, 1)
        elseif action == "walking" or action == "traveling" then
            actElem:setTextColor(0.5, 0.8, 0.5, 1)
        elseif action == "working" or action == "field work" then
            actElem:setTextColor(0.9, 0.75, 0.3, 1)
        elseif action == "socializing" or action == "gathering" then
            actElem:setTextColor(0.5, 0.7, 0.9, 1)
        else
            actElem:setTextColor(0.75, 0.75, 0.75, 1)
        end
    end

    -- Distance column
    local distElem = self[prefix .. "dist"]
    if distElem then
        distElem:setVisible(true)
        if sys.playerPositionValid then
            local dx = npc.position.x - sys.playerPosition.x
            local dz = npc.position.z - sys.playerPosition.z
            local d = math.sqrt(dx * dx + dz * dz)
            distElem:setText(string.format("%.0fm", d))
            -- Color: closer = brighter, farther = dimmer
            if d < 50 then
                distElem:setTextColor(0.3, 1, 0.3, 1)
            elseif d < 150 then
                distElem:setTextColor(0.8, 0.8, 0.8, 1)
            elseif d < 300 then
                distElem:setTextColor(0.6, 0.6, 0.6, 1)
            else
                distElem:setTextColor(0.4, 0.4, 0.45, 1)
            end
        else
            distElem:setText("-")
            distElem:setTextColor(0.4, 0.4, 0.45, 1)
        end
    end

    -- Relationship column (color coded)
    local relElem = self[prefix .. "rel"]
    if relElem then
        local rel = npc.relationship or 0
        relElem:setText(tostring(rel))
        relElem:setVisible(true)
        local rr, rg, rb = self:getRelColor(rel)
        relElem:setTextColor(rr, rg, rb, 1)
    end

    -- Farm column (shows farm name + field count, falls back to home building)
    local farmElem = self[prefix .. "farm"]
    if farmElem then
        local farmStr = "-"
        if npc.farmName then
            local fieldCount = npc.assignedFields and #npc.assignedFields or 0
            farmStr = fieldCount > 0 and string.format("%s (%d)", npc.farmName, fieldCount) or npc.farmName
        elseif npc.homeBuildingName then
            farmStr = npc.homeBuildingName
        end
        farmElem:setText(farmStr:sub(1, 22))
        farmElem:setVisible(true)
        if npc.assignedFarmland then
            farmElem:setTextColor(0.5, 0.85, 0.5, 1)  -- Green = has farm
        else
            farmElem:setTextColor(0.6, 0.65, 0.7, 1)  -- Dim = no farm
        end
    end
end

--- Teleport the player to an NPC by row number.
function NPCListDialog:teleportToRow(rowNum)
    local npcIndex = self.rowNPCIndex[rowNum]
    if not npcIndex then return end

    local sys = self.npcSystem or g_NPCSystem
    if not sys or not sys.activeNPCs then return end

    local npc = sys.activeNPCs[npcIndex]
    if not npc or not npc.position then return end

    -- Close dialog first so the player can see where they land
    self:close()

    -- Teleport player 3m away from NPC (same logic as npcGoto)
    local angle = math.random() * math.pi * 2
    local x = npc.position.x + math.cos(angle) * 3
    local y = npc.position.y
    local z = npc.position.z + math.sin(angle) * 3

    if sys.getSafePosition then
        x, z = sys:getSafePosition(x, z, nil)
    end

    -- Snap to terrain
    if g_currentMission and g_currentMission.terrainRootNode then
        local ok, h = pcall(getTerrainHeightAtWorldPos,
            g_currentMission.terrainRootNode, x, 0, z)
        if ok and h then
            y = h + 0.05
        end
    end

    -- Teleport the player
    local teleported = false
    if g_localPlayer and g_localPlayer.rootNode and g_localPlayer.rootNode ~= 0 then
        pcall(function()
            setWorldTranslation(g_localPlayer.rootNode, x, y, z)
            teleported = true
        end)
    end
    if not teleported and g_currentMission and g_currentMission.player then
        local player = g_currentMission.player
        if player.rootNode and player.rootNode ~= 0 then
            pcall(function()
                setWorldTranslation(player.rootNode, x, y, z)
                teleported = true
            end)
        end
    end

    if teleported then
        print(string.format("[NPC Favor] Teleported to %s", npc.name or "NPC"))
    else
        print(string.format("[NPC Favor] Could not teleport to %s", npc.name or "NPC"))
    end
end

-- Generate onClickRow1..onClickRow16 handlers dynamically
for i = 1, NPCListDialog.MAX_ROWS do
    NPCListDialog["onClickRow" .. i] = function(self)
        self:teleportToRow(i)
    end
end

--- Relationship value -> color.
function NPCListDialog:getRelColor(value)
    if value < 15 then
        return 0.9, 0.3, 0.3     -- Red (hostile)
    elseif value < 30 then
        return 0.9, 0.55, 0.25   -- Orange (unfriendly)
    elseif value < 50 then
        return 0.85, 0.85, 0.4   -- Yellow (neutral)
    elseif value < 70 then
        return 0.5, 0.85, 0.5    -- Green (friendly)
    elseif value < 85 then
        return 0.3, 0.75, 0.9    -- Cyan (close friend)
    else
        return 0.5, 0.6, 1       -- Blue (best friend)
    end
end

--- Personality -> name color.
function NPCListDialog:getPersonalityColor(personality)
    local colors = {
        hardworking = {0.4, 0.9, 0.4},
        lazy        = {0.9, 0.9, 0.3},
        social      = {0.9, 0.6, 0.3},
        loner       = {0.6, 0.6, 0.7},
        generous    = {0.3, 0.9, 0.6},
        greedy      = {0.9, 0.4, 0.4},
        friendly    = {0.4, 0.7, 0.95},
        grumpy      = {0.9, 0.5, 0.3},
    }
    local c = colors[personality] or {1, 1, 1}
    return c[1], c[2], c[3]
end

function NPCListDialog:onClickClose()
    self:close()
end

function NPCListDialog:onClose()
    NPCListDialog:superClass().onClose(self)
end

print("[NPC Favor] NPCListDialog loaded")
