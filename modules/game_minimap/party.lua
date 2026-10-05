MinimapParty = MinimapParty or {}

local function hasMethod(widget, methodName)
    return widget and widget[methodName] and type(widget[methodName]) == 'function'
end

function MinimapParty.update(minimapWidget)
    if hasMethod(minimapWidget, 'showParty') then
        minimapWidget:showParty()
    end
end

function MinimapParty.reset(minimapWidget)
    if hasMethod(minimapWidget, 'resetParty') then
        minimapWidget:resetParty()
    end
end

function MinimapParty.updateFloor(minimapWidget, floor)
    if hasMethod(minimapWidget, 'FloorUpdate') then
        minimapWidget:FloorUpdate(floor)
    end
end

function MinimapParty.changeView(minimapWidget, showNames)
    if hasMethod(minimapWidget, 'ViewUpdate') then
        minimapWidget:ViewUpdate(showNames and 'Show' or 'Hide')
    end
end
