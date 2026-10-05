local iconTopMenu = nil
local contextMenu
local function updateEnergyBar(bar, value, maximum)
    bar.text:setTextOverflowLength(0)
    bar.text:setText(value)
    local length = #bar.text:getText()
    while length > 1 and bar.text:getTextSize().width > bar.text:getWidth() do
        length = length - 1
        bar.text:setTextOverflowLength(length)
    end
    bar.text.energyValueTruncated = length < #bar.text:getText()
    if bar.text.refreshHoverTooltip then bar.text.refreshHoverTooltip() end
    local fraction = maximum > 0 and math.max(0, math.min(1, value / maximum)) or 0
    local width = math.floor(bar.total:getWidth() * fraction + 0.5)
    bar.current:setVisible(width > 0)
    if width > 0 then
        bar.current:setWidth(width)
        bar.current:setImageClip({x = 0, y = 0, width = width, height = 11})
    end
end

local function healthManaEvent()
    local player = g_game.getLocalPlayer()
    if not player then return end
    updateEnergyBar(healthManaController.ui.health, player:getHealth(), player:getMaxHealth())
    updateEnergyBar(healthManaController.ui.mana, player:getMana(), player:getMaxMana())
end

healthManaController = Controller:new()
healthManaController:setUI('healthinfo', modules.game_interface.getMainRightPanel())

function setStatusBarsVisible(visible)
    healthManaController.ui:setVisible(visible)
    if iconTopMenu then iconTopMenu:setOn(visible) end
end

local function showContextMenu(pos)
    contextMenu = UIContextMenu.create({
        {text = tr('Show Customisable Status Bars'),
         checked = modules.client_options.getOption('showCustomisableStatusBars'),
         callback = function(value) modules.client_options.setOption('showCustomisableStatusBars', value) end},
        {text = tr('Show Status Bars'),
         checked = modules.client_options.getOption('showStatusBars'),
         callback = function(value) modules.client_options.setOption('showStatusBars', value) end}
    })
    local destroy = contextMenu.onDestroy
    contextMenu.onDestroy = function(self)
        if contextMenu == self then contextMenu = nil end
        destroy(self)
    end
    contextMenu:display(pos)
end

function healthManaController:onInit()
    self.ui.onMouseRelease = function(widget, pos, button)
        if button ~= MouseRightButton then return false end
        showContextMenu(pos)
        return true
    end
    self.ui.health.icon:setImageSource('/images/healthmana/hitpoints_symbol')
    self.ui.health.current:setImageSource('/images/healthmana/hitpoints_bar_filled')
    self.ui.mana.icon:setImageSource('/images/healthmana/mana_symbol')
    self.ui.mana.current:setImageSource('/images/healthmana/mana_bar_filled')
    self.ui.health.text:setTextOverflowCharacter(string.char(133))
    self.ui.mana.text:setTextOverflowCharacter(string.char(133))
    for _, bar in ipairs({self.ui.health, self.ui.mana}) do
        bar.text:setPhantom(false)
        UIHoverTooltip.configure(bar.text, function(widget)
            return widget.energyValueTruncated and widget:getText() or ''
        end)
    end
end

function healthManaController:onTerminate()
    if contextMenu then contextMenu:destroy() end
    if iconTopMenu then
        iconTopMenu:destroy()
        iconTopMenu = nil
    end
end

function healthManaController:onGameStart()
    setStatusBarsVisible(modules.client_options.getOption('showStatusBars'))
    healthManaController:registerEvents(LocalPlayer, {
        onHealthChange = healthManaEvent,
        onManaChange = healthManaEvent
    }):execute()
end

function extendedView(extendedView)
    if extendedView then
        if not iconTopMenu then
            iconTopMenu = modules.client_topmenu.addTopRightToggleButton('healthMana', tr('Show health'),
                '/images/topbuttons/healthinfo', toggle)
            iconTopMenu:setOn(healthManaController.ui:isVisible())
            healthManaController.ui:setBorderColor('black')
            healthManaController.ui:setBorderWidth(2)
        end
    else
        if iconTopMenu then
            iconTopMenu:destroy()
            iconTopMenu = nil
        end
        healthManaController.ui:setBorderColor('alpha')
        healthManaController.ui:setBorderWidth(0)
        local mainRightPanel = modules.game_interface.getMainRightPanel()
        if not mainRightPanel:hasChild(healthManaController.ui) then
            mainRightPanel:insertChild(2, healthManaController.ui)
        end
        setStatusBarsVisible(modules.client_options.getOption('showStatusBars'))
    end
    healthManaController.ui.moveOnlyToMain = not extendedView
end

function toggle()
    modules.client_options.setOption('showStatusBars', not healthManaController.ui:isVisible())
end
