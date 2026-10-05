local showHighlightedUnderline = false
local NPC_DIALOG_HEADER_COLOR = "white"

local function getHighlightedText(text, color, highlightColor)
    color = color or "white"
    highlightColor = highlightColor or "#1f9ffe"
    local firstBrace = text:find("{", 1, true)
    if not firstBrace then
        return string.format("{%s, %s}", text, color)
    end
    local parts = {}
    local lastPos = 1
    for startPos, content, endPos in text:gmatch("()%{([^}]*)%}()") do
        if startPos > lastPos then
            parts[#parts + 1] = string.format("{%s, %s}", text:sub(lastPos, startPos - 1), color)
        end
        local textPart = content:match("([^,]+)") or content
        local trimmed = textPart
        local highlighted = trimmed
        if showHighlightedUnderline then
            highlighted = string.format("[text-event]%s[/text-event]", trimmed)
        else
            highlighted = string.format("[text-event]%s%s[/text-event]", string.char(1), trimmed)
        end
        parts[#parts + 1] = string.format("{%s, %s}", highlighted, highlightColor)
        lastPos = endPos
    end
    if lastPos <= #text then
        parts[#parts + 1] = string.format("{%s, %s}", text:sub(lastPos), color)
    end
    return table.concat(parts)
end

local function createDialogLabel(consoleBuffer, entry)
    local label = g_ui.createWidget('ConsoleLabel', consoleBuffer)
    label:setId("consoleLabel" .. consoleBuffer:getChildCount())

    if entry.coloredData then
        label:setColoredText(entry.coloredData)
        label.coloredData = entry.coloredData
    else
        label:setText(entry.text or "")
    end

    if entry.color then
        label:setColor(entry.color)
    end

    if entry.name then
        label.name = entry.name
    end

    if entry.clickable and not label:hasEventListener(EVENT_TEXT_CLICK) then
        label:setEventListener(EVENT_TEXT_CLICK)
        connect(label, {
            onTextClick = function(w, t)
                controllerNpcTrader:onConsoleTextClicked(w, t)
            end
        })
    end

    return label
end

local function buildTalkingToEntry(npcName, timestamp)
    local prefix = timestamp and (timestamp .. " ") or ""
    return {
        text = prefix .. "talking to " .. npcName,
        color = NPC_DIALOG_HEADER_COLOR
    }
end

function controllerNpcTrader:ensureDialogHeader(consoleBuffer)
    if not consoleBuffer or consoleBuffer:getChildCount() > 0 or not self.creatureName or self.creatureName == "" then
        return
    end

    createDialogLabel(consoleBuffer, buildTalkingToEntry(self.creatureName, os.date('%H:%M')))
end

function controllerNpcTrader:onConsoleTextClicked(widget, text)
    if type(widget) == "string" and not text then
        text = widget
        widget = nil
    end

    if not text or text == "" then
        return
    end

    local npcTab = modules.game_console.consoleTabBar:getTab("NPCs")
    if npcTab then
        modules.game_console.sendMessage(text, npcTab)
        onNpcTalk(g_game.getCharacterName(), 0, MessageModes.NpcTo, text)
    end
    if text == "bye" then
        controllerNpcTrader:onCloseNpcTrade()
    end
end

function controllerNpcTrader:cloneConsoleMessages()
    local consoleBuffer = self:findWidget("#consoleBuffer")

    if consoleBuffer then
        consoleBuffer:destroyChildren()
        self:ensureDialogHeader(consoleBuffer)
    end
end

-- temp fix. can't drag the left panel to move the window.
function controllerNpcTrader:setupWindowDragBehavior()
    if not self.ui then
        return
    end
    local dragHandle = self:findWidget("#dragHandle")
    if not dragHandle then
        return
    end
    dragHandle:setDraggable(true)
    dragHandle.onDragEnter = function(widget, mousePos)
        return self.ui:onDragEnter(mousePos)
    end
    dragHandle.onDragMove = function(widget, mousePos, mouseMoved)
        self.ui:onDragMove(mousePos, mouseMoved)
        return true
    end
    dragHandle.onDragLeave = function(widget, droppedWidget, mousePos)
        self.ui:onDragLeave(droppedWidget, mousePos)
        return true
    end
end

function controllerNpcTrader:fitNpcWindowToParent()
    if not self.ui then return end
    local parent = self.ui:getParent():getRect()
    local width = math.max(self.isTradeOpen and 510 or 308, math.min(self.ui:getWidth(), parent.width))
    local height = math.max(350, math.min(self.ui:getHeight(), parent.height))
    self.dialogX = math.max(0, math.min(self.dialogX or 0, parent.width - width))
    self.dialogY = math.max(0, math.min(self.dialogY or 0, parent.height - height))
    self.ui:setSize({width = width, height = height})
    self.ui:setPosition({x = parent.x + self.dialogX, y = parent.y + self.dialogY})
    self.ui.onGeometryChange(self.ui)
end

function controllerNpcTrader:saveDialogGeometry()
    if not self.ui then return end
    local geometry = self.dialogGeometry or {}
    geometry.x = self.dialogX
    geometry.y = self.dialogY
    geometry.height = self.ui:getHeight()
    geometry[self.isTradeOpen and 'tradeWidth' or 'chatWidth'] = self.ui:getWidth()
    g_settings.setNode('npc-dialog', geometry)
end

function controllerNpcTrader:setupWindowResizeBehavior()
    local right = self.ui:getChildById('rightResizeBorder')
    if not right then
        right = g_ui.createWidget('ResizeBorder', self.ui)
        right:setId('rightResizeBorder')
        right:addAnchor(AnchorRight, 'parent', AnchorRight)
        right:addAnchor(AnchorTop, 'parent', AnchorTop)
        right:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        right:setMarginTop(17)
        right.vertical = false

        local bottom = g_ui.createWidget('ResizeBorder', self.ui)
        bottom:setId('bottomResizeBorder')
        bottom:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        bottom:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        bottom:addAnchor(AnchorRight, 'parent', AnchorRight)
        bottom.vertical = true
        bottom:setMinimum(350)

        local onDragMove = self.ui.onDragMove
        self.ui.onDragMove = function(widget, mousePos, mouseMoved)
            onDragMove(widget, mousePos, mouseMoved)
            self.dialogX = widget:getX() - widget:getParent():getX()
            self.dialogY = widget:getY() - widget:getParent():getY()
        end

        self.ui.onGeometryChange = function(widget)
            self.dialogWidth = widget:getWidth()
            self.dialogHeight = widget:getHeight()
            right:setMinimum(self.isTradeOpen and 510 or 308)
            local parent = widget:getParent():getRect()
            right:setMaximum(math.max(right:getMinimum(), parent.width - math.max(0, widget:getX() - parent.x)))
            bottom:setMaximum(math.max(bottom:getMinimum(), parent.height - math.max(0, widget:getY() - parent.y)))
        end
        local parent = self.ui:getParent()
        local onParentGeometryChange = function() self:fitNpcWindowToParent() end
        connect(parent, {onGeometryChange = onParentGeometryChange})
        connect(self.ui, {onDestroy = function()
            disconnect(parent, {onGeometryChange = onParentGeometryChange})
        end})
    end
    self.ui.onGeometryChange(self.ui)
end

function controllerNpcTrader:initNpcWindow(creature, buttons)
    if self:isLegacyMode() then
        return
    end
    self:connectNpcTalkEvent()
    self.widthConsole = self.DEFAULT_CONSOLE_WIDTH
    self.isTradeOpen = false
    if creature then
        self.creatureName = creature:getName() or "Unknown"
        self.outfit = creature:getOutfit()
    else
        self.creatureName = "Unknown"
        self.outfit = "/game_npctrade/assets/images/icon-npcdialog-multiplenpcs"
    end
    self.buttons = buttons or self.buttons or self.buttonsDefault
    self:updateChatButton()
    if not self.ui or not self.ui:isVisible() then
        self.dialogGeometry = g_settings.getNode('npc-dialog') or {}
        local geometry = self.dialogGeometry
        self.dialogWidth = math.max(308, tonumber(geometry.chatWidth) or self.DEFAULT_CONSOLE_WIDTH)
        self.widthConsole = self.dialogWidth
        self.dialogHeight = math.max(350, tonumber(geometry.height) or 412)
        self.dialogX = tonumber(geometry.x) or 0
        self.dialogY = tonumber(geometry.y) or 0
        self:loadHtml('templates/game_npctrader.html')
        local parent = self.ui:getParent():getRect()
        self.dialogX = tonumber(geometry.x) or math.max(0, math.floor((parent.width - self.TRADE_CONSOLE_WIDTH) / 2))
        self.dialogY = tonumber(geometry.y) or math.max(0, math.floor((parent.height - self.dialogHeight) / 2))
        self.ui:setSize({width = self.dialogWidth, height = self.dialogHeight})
    end
    self:setupWindowDragBehavior()
    self:setupWindowResizeBehavior()
    self:fitNpcWindowToParent()
    local title = self:findWidget(".title")
    local banner = self:findWidget(".img")
    if title and banner then
        title.onTextChange = function(widget)
            widget:setTextWrap(false)
            widget:setWidth(math.max(70, widget:getTextSize().width))
            banner:setWidth(widget:getWidth() + 99)
        end
        title:setText(self.creatureName)
        title.onTextChange(title)
    end
    local creatureOutfit = self:findWidget("#creatureOutfit")
    if creatureOutfit then
        if type(self.outfit) == "string" then
            creatureOutfit:setImageSource(self.outfit)
        else
            creatureOutfit:setOutfit(self.outfit)
        end
    end
    self:cloneConsoleMessages()
end

function onNpcChatWindow(data)
    if controllerNpcTrader:isLegacyMode() then
        controllerNpcTrader:legacy_show()
        return
    end
    if type(data) ~= "table" or type(data.npcIds) ~= "table" or #data.npcIds == 0 then
        return
    end
    -- The server appends every greeting NPC to the list and builds the buttons from the
    -- LAST id (the active conversation); npcIds[1] is the oldest, e.g. a bystander that
    -- happened to be in talk range. Showing npcIds[1] paints the wrong name and outfit.
    local creature = g_map.getCreatureById(data.npcIds[#data.npcIds])
    if creature then
        controllerNpcTrader:initNpcWindow(creature, data.buttons)
    end
end

function controllerNpcTrader:onConsoleKeyPress(event)
    if event.value == KeyEnter then
        local input = controllerNpcTrader:findWidget(".inputConsole")
        if input then
            local text = input:getText()
            if text and #text > 0 then
                controllerNpcTrader:onConsoleTextClicked(nil, text)
                input:clearText()
            end
        end
    end
end

function onNpcTalk(name, level, mode, text, channelId, creaturePos)
    if not controllerNpcTrader.ui or not controllerNpcTrader.ui:isVisible() then
        return
    end

    if mode == MessageModes.NpcTo or mode == MessageModes.NpcFrom or mode == MessageModes.NpcFromStartBlock then
        local consoleBuffer = controllerNpcTrader:findWidget("#consoleBuffer")
        if consoleBuffer then
            controllerNpcTrader:ensureDialogHeader(consoleBuffer)
            local consoleModule = modules.game_console
            local SpeakTypes = consoleModule and consoleModule.SpeakTypes or {}
            local color = '#5FF7F7'
            if SpeakTypes[mode] and SpeakTypes[mode].color then
                color = SpeakTypes[mode].color
            end
            local fullText = text
            if mode == MessageModes.NpcFrom or mode == MessageModes.NpcFromStartBlock then
                fullText = name .. " says: " .. text
            elseif mode == MessageModes.NpcTo then
                fullText = name .. ": " .. text
            end
            local entry = {
                text = fullText,
                color = color,
                name = mode == MessageModes.NpcTo and g_game.getCharacterName() or name,
                clickable = true
            }
            if getHighlightedText then
                entry.coloredData = getHighlightedText(fullText, color, "#1f9ffe")
            end
            createDialogLabel(consoleBuffer, entry)
        end
    end
end

function controllerNpcTrader:updateChatButton()
    local isChatEnabled = modules.game_console.isChatEnabled()
    self.chatMode = isChatEnabled and tr('Chat On') or tr('Chat Off')
    local inputConsole = self:findWidget(".inputConsole")
    if inputConsole then
        inputConsole:setEnabled(isChatEnabled)
    end
end

function controllerNpcTrader:toggleChatMode()
    modules.game_console.toggleChat()
    self:updateChatButton()
end
