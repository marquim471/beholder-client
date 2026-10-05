local deathTexts = {
    regular_death = [[Alas! Brave adventurer, you have met a sad fate.
But do not despair, for the gods will bring you back
into the world in exchange for a small sacrifice.

Simply click on {Ok, #ffffff} to resume your journeys in Tibia
or on {Cancel, #ffffff} to get to your character list!

%1]],
    unfair_death = [[Alas! Brave adventurer, you have met a sad fate.
But do not despair, for the gods will bring you back
into the world in exchange for a small sacrifice.

This death penalty has been reduced by %1%
because it was an unfair fight.

Simply click on {Ok, #ffffff} to resume your journeys in Tibia
or on {Cancel, #ffffff} to get to your character list!

%2]],
    adventurers_blessing = [[Alas! Brave adventurer, you have met a sad fate.
But do not despair, for the gods will bring you back
into the world.

The death penalty has been reduced by 100%
because you are blessed with the Adventurer's Blessing.

Simply click on {Ok, #ffffff} to resume your journeys in Tibia
or on {Cancel, #ffffff} to get to your character list!

%1]],
    no_penalty = [[Alas! Brave adventurer, you have met a sad fate.
But in this dark hour fortune smiled on you and the
gods will bring you back into the world for free.

You lost the battle, but you did not lose any items,
experience or skill points. You also kept any possible
blessings or an Amulet of Loss you may have worn.

Simply click on {Ok, #ffffff} to resume your journeys in Tibia
or on {Cancel, #ffffff} to get to your character list!

%1]],
    store_button = [[Click on {Store, #ffffff} to resume your journeys and to shop
blessings to ease the pain if you are unfortunate
enough to lose another fight!]],
    store_button_no_loss = [[If you are not protected by any blessings but like to
get some in case you are unfortunate enough to lose
another fight, click on {Store, #ffffff} to shop for them and
to resume your journeys!]],
    store_button_subsequent_blessing = [[You were not protected by all blessings at the time
of your death. Save some of your lost skill and
experience points by purchasing the blessing
{Death Redemption, #ffffff} in the {Store, #ffffff}.]],
}

local reconnectEvent
local openStoreAfterLogin = false

deathController = Controller:new()
function deathController:onInit()
    deathController:registerEvents(g_game, {
        onDeath = display,
    })
end

function deathController:onTerminate()
   deathController.ui = destroyWindows()
end

function deathController:onGameStart()
    if openStoreAfterLogin then
        openStoreAfterLogin = false
        self:scheduleEvent(function() modules.game_store.show() end, 500, 'openStoreAfterDeath')
    end
end

function deathController:onGameEnd()
    deathController.ui = destroyWindows()
end

function destroyWindows()
    if reconnectEvent then removeEvent(reconnectEvent); reconnectEvent = nil end
    if deathController.ui and not deathController.ui:isDestroyed() then
        deathController.ui:destroy()
    end
    return nil
end

function display(deathType, penalty, canUseDeathRedemption)
    displayDeadMessage()
    openWindow(deathType, penalty, canUseDeathRedemption)
    scheduleReconnect()
end

function displayDeadMessage()
    local advanceLabel = modules.game_interface.getRootPanel():recursiveGetChildById('middleCenterLabel')
    if advanceLabel:isVisible() then
        return
    end

    modules.game_textmessage.displayGameMessage(tr('You are dead.'))
end

function openWindow(deathType, penalty, canUseDeathRedemption)
    deathController.ui = destroyWindows()
    deathController.ui = g_ui.displayUI('deathwindow', rootWidget)
    deathController.ui:enableTitlebarDrag(17, 10)

    local key = deathType == DeathType.Blessed and 'adventurers_blessing'
        or deathType == DeathType.NoPenalty and 'no_penalty'
        or penalty < 100 and 'unfair_death' or 'regular_death'
    local extra = canUseDeathRedemption and deathTexts.store_button_subsequent_blessing
        or deathType == DeathType.NoPenalty and deathTexts.store_button_no_loss
        or deathTexts.store_button
    local message = deathTexts[key]
    if key == 'unfair_death' then
        message = message:gsub('%%1', tostring(100 - penalty)):gsub('%%2', function() return extra end)
    else
        message = message:gsub('%%1', function() return extra end)
    end
    local textLabel = deathController.ui:getChildById('labelText')
    textLabel:setTextWrap(false)
    textLabel:setColoredText(message)
    local width = math.max(300, math.min(765, textLabel:getTextSize().width + 32))
    deathController.ui:setWidth(width)
    textLabel:setWidth(width - 32)
    textLabel:setTextWrap(true)
    textLabel:setHeight(textLabel:getTextSize().height)
    deathController.ui:setHeight(textLabel:getHeight() + 87)

    local okButton = deathController.ui:getChildById('buttonOk')
    local cancelButton = deathController.ui:getChildById('buttonCancel')

    local okFunc = function()
        CharacterList.doLogin()
        deathController.ui = destroyWindows()
    end
    local cancelFunc = function()
        openStoreAfterLogin = false
        g_game.safeLogout()
        deathController.ui = destroyWindows()
    end

    deathController.ui.onEnter = okFunc
    deathController.ui.onEscape = cancelFunc

    okButton.onClick = okFunc
    cancelButton.onClick = cancelFunc
    deathController.ui.buttonStore.onClick = function()
        openStoreAfterLogin = true
        okFunc()
    end
end

function scheduleReconnect()
    if not g_settings.getBoolean('autoReconnect') then
        return
    end
    reconnectEvent = scheduleEvent(function()
        reconnectEvent = nil
        deathController.ui = destroyWindows()
        g_game.cancelLogin()
        CharacterList.doLogin()
    end, 2000)
end
