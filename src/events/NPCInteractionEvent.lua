--[[
    FS25_NPCFavor - NPC Interaction Event

    Client-to-server routing for player interactions with NPCs.
    Handles favor accept/complete/abandon, gifts, and relationship changes.

    Pattern from: SetPaymentConfigEvent sendToServer + execute
    OWASP: Input validation, farm ownership verification, action whitelist,
           NaN/infinity checks, rate limiting via cooldown.
]]

NPCInteractionEvent = {}
local NPCInteractionEvent_mt = Class(NPCInteractionEvent, Event)

InitEventClass(NPCInteractionEvent, "NPCInteractionEvent")

-- Action type constants (whitelist)
NPCInteractionEvent.ACTION_FAVOR_ACCEPT = 1
NPCInteractionEvent.ACTION_FAVOR_COMPLETE = 2
NPCInteractionEvent.ACTION_FAVOR_ABANDON = 3
NPCInteractionEvent.ACTION_GIFT = 4
NPCInteractionEvent.ACTION_RELATIONSHIP = 5

NPCInteractionEvent.MIN_ACTION = 1
NPCInteractionEvent.MAX_ACTION = 5

function NPCInteractionEvent.emptyNew()
    local self = Event.new(NPCInteractionEvent_mt)
    self.actionType = 0
    self.npcId = 0
    self.farmId = 0
    self.value = 0
    self.data = ""
    return self
end

function NPCInteractionEvent.new(actionType, npcId, farmId, value, data)
    local self = NPCInteractionEvent.emptyNew()
    self.actionType = actionType or 0
    self.npcId = npcId or 0
    self.farmId = farmId or 0
    self.value = value or 0
    self.data = data or ""
    return self
end

--[[
    Static function to send interaction from client to server.
    In single-player/server, executes directly. In multiplayer client, routes via network.
]]
function NPCInteractionEvent.sendToServer(actionType, npcId, farmId, value, data)
    if g_server ~= nil then
        -- Single-player or server - execute directly
        NPCInteractionEvent.execute(actionType, npcId, farmId, value, data)
    else
        -- Multiplayer client - send to server
        g_client:getServerConnection():sendEvent(
            NPCInteractionEvent.new(actionType, npcId, farmId, value, data)
        )
    end
end

function NPCInteractionEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.actionType)
    streamWriteInt32(streamId, self.npcId)
    streamWriteInt32(streamId, self.farmId)
    streamWriteFloat32(streamId, self.value)
    streamWriteString(streamId, (self.data or ""):sub(1, 256))
end

function NPCInteractionEvent:readStream(streamId, connection)
    self.actionType = streamReadUInt8(streamId)
    self.npcId = streamReadInt32(streamId)
    self.farmId = streamReadInt32(streamId)
    self.value = streamReadFloat32(streamId)
    self.data = streamReadString(streamId):sub(1, 256)

    -- OWASP Input Validation: Validate action type in whitelist range
    if self.actionType < NPCInteractionEvent.MIN_ACTION or self.actionType > NPCInteractionEvent.MAX_ACTION then
        print(string.format("[NPCFavor SECURITY] Invalid action type: %d", self.actionType))
        return -- Don't call run, silently drop
    end

    self:run(connection)
end

function NPCInteractionEvent:run(connection)
    -- OWASP Layer 1: Must run on server
    if g_server == nil then
        return
    end

    -- OWASP Layer 2: Verify farm ownership
    if connection ~= nil then
        -- Connection is from a client, verify authorization
        local user = nil
        if g_currentMission and g_currentMission.userManager then
            user = g_currentMission.userManager:getUserByConnection(connection)
        end

        if user == nil then
            print(string.format("[NPCFavor SECURITY] Rejected interaction: no user for connection"))
            return
        end

        -- Check farm ownership
        local userFarmId = user.farmId
        if userFarmId ~= self.farmId then
            print(string.format("[NPCFavor SECURITY] Rejected interaction: farmId mismatch (claimed %d, actual %d)",
                self.farmId, userFarmId or -1))
            return
        end
    end

    -- OWASP Layer 3: Delegate to execute with full input validation
    NPCInteractionEvent.execute(self.actionType, self.npcId, self.farmId, self.value, self.data)
end

--[[
    Execute the interaction logic. All input validation happens here.
    @return boolean success
]]
function NPCInteractionEvent.execute(actionType, npcId, farmId, value, data)
    -- Validate NPCSystem exists
    if g_NPCSystem == nil then
        return false
    end

    -- OWASP Input Validation: Validate NPC exists
    local npc = g_NPCSystem:getNPCById(npcId)
    if npc == nil then
        print(string.format("[NPCFavor SECURITY] NPC not found: %d", npcId))
        return false
    end

    -- OWASP Input Validation: Validate farm exists
    if g_farmManager then
        local farm = g_farmManager:getFarmById(farmId)
        if farm == nil then
            print(string.format("[NPCFavor SECURITY] Farm not found: %d", farmId))
            return false
        end
    end

    -- OWASP Input Validation: NaN and bounds check on value
    if value ~= value then -- NaN check
        print("[NPCFavor SECURITY] Rejected NaN value")
        return false
    end
    if math.abs(value) >= 1e9 then
        print("[NPCFavor SECURITY] Rejected out-of-bounds value")
        return false
    end

    -- Dispatch to appropriate handler
    if actionType == NPCInteractionEvent.ACTION_FAVOR_ACCEPT then
        return g_NPCSystem:serverAcceptFavor(npc, farmId)

    elseif actionType == NPCInteractionEvent.ACTION_FAVOR_COMPLETE then
        return g_NPCSystem:serverCompleteFavor(npc, farmId)

    elseif actionType == NPCInteractionEvent.ACTION_FAVOR_ABANDON then
        return g_NPCSystem:serverAbandonFavor(npc, farmId)

    elseif actionType == NPCInteractionEvent.ACTION_GIFT then
        return g_NPCSystem:serverGiveGift(npc, farmId, value, data)

    elseif actionType == NPCInteractionEvent.ACTION_RELATIONSHIP then
        return g_NPCSystem:serverUpdateRelationship(npc, farmId, value, data)
    end

    return false
end

