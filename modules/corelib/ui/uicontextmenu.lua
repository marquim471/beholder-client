UIContextMenu = {}

function UIContextMenu.create(entries)
    local menu = g_ui.createWidget('ContextMenu')
    menu:setGameMenu(true)
    menu:getLayout():setSpacing(3)
    local function addOption(text, callback, checked, shortcut, disabled, iconSource)
        local checkable = checked ~= nil
        local inset = checkable and 18 or 2
        local button = g_ui.createWidget('ContextMenuButton', menu)
        if checkable then
            button:setChecked(checked)
            local indicator = g_ui.createWidget('UIWidget', button)
            indicator:setSize({width = 12, height = 12})
            indicator:setImageSource('/images/ui/checkbox-' .. (checked and 'checked' or 'unchecked'))
            indicator:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            indicator:addAnchor(AnchorTop, 'parent', AnchorTop)
            indicator:setMarginLeft(2)
            indicator:setMarginTop(2)
            indicator:setPhantom(true)
        end
        local function addLabel(text, right)
            local label
            for _, offset in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {0, 0}}) do
                label = g_ui.createWidget('UIWidget', button)
                label:setFont('verdana-bold-11px-native')
                label:setText(text)
                label:setTextAlign(AlignLeft)
                label:setColor(offset[1] == 0 and offset[2] == 0 and (disabled and '#707070' or '#f7f7f7') or 'black')
                label:setSize(label:getTextSize())
                label:addAnchor(right and AnchorRight or AnchorLeft, 'parent', right and AnchorRight or AnchorLeft)
                label:addAnchor(AnchorTop, 'parent', AnchorTop)
                if right then
                    label:setMarginRight(2 - offset[1])
                else
                    label:setMarginLeft(inset + offset[1])
                end
                label:setMarginTop(2 + offset[2])
                label:setPhantom(true)
            end
            return label:getTextSize().width
        end
        local width = addLabel(text, false) + 50 + inset
        if shortcut then width = width + addLabel(shortcut, true) end
        if iconSource then
            local icon = g_ui.createWidget('UIWidget', button)
            icon:setSize({width = 12, height = 12})
            icon:setImageSource(iconSource)
            icon:addAnchor(AnchorRight, 'parent', AnchorRight)
            icon:addAnchor(AnchorTop, 'parent', AnchorTop)
            icon:setMarginRight(6)
            icon:setMarginTop(3)
            icon:setPhantom(true)
            width = width + 20
        end
        menu:setWidth(math.max(menu:getWidth(), width))
        button:setEnabled(not disabled)
        button.onClick = function()
            local position = menu:getPosition()
            if checkable then button:setChecked(not checked) end
            menu:destroy()
            if checkable then callback(not checked) else callback(position) end
        end
        return button
    end
    menu.addOption = function(self, text, callback, shortcut, disabled, iconSource)
        return addOption(text, callback, nil, shortcut, disabled, iconSource)
    end
    menu.addOptionWithIcon = function(self, text, iconOrCb, cbOrIcon, shortcut, disabled)
        local icon = iconOrCb
        local cb = cbOrIcon
        if type(iconOrCb) == "function" then
            cb = iconOrCb
            icon = cbOrIcon
        end
        return addOption(text, cb, nil, shortcut, disabled, icon)
    end
    menu.addCheckBox = function(self, text, checked, callback)
        local button
        button = addOption(text, function(value) callback(button, value) end, checked)
        return button
    end
    menu.addSeparator = function(self)
        g_ui.createWidget('ContextMenuSeparator', self)
    end
    for _, entry in ipairs(entries) do
        addOption(entry.text, entry.callback, entry.checked)
    end
    return menu
end
