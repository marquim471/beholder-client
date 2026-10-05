wheelWindow = nil
wheelOfDestinyWindow = nil
gemAtelierWindow = nil
fragmentWindow = nil
newPresetWindow = nil
renamePresetWindow = nil
exportCodeWindow = nil
deletePresetWindow = nil
checkSavePresetWindow = nil
selectedNewPresetRadio = nil
local summaryVisible = false
local wheelKeyboardFocusClaimId = nil
local wheelSearchFocusSuppressUntil = {}

wheelPanel = nil
centerReferencePoint = nil

if not SkillwheelStringsLibrary then
  SkillwheelStringsLibrary = {}
end

function claimWheelKeyboardFocus(ownerWidget, targetWidget, editable, name)
  local consoleModule = modules.game_console
  if not ownerWidget or ownerWidget:isDestroyed() then
    return nil
  end

  if not consoleModule or not consoleModule.claimKeyboardFocus then
    if targetWidget and not targetWidget:isDestroyed() then
      targetWidget:focus()
    else
      ownerWidget:focus()
    end
    return nil
  end

  if wheelKeyboardFocusClaimId then
    consoleModule.releaseKeyboardFocus(wheelKeyboardFocusClaimId, {
      restoreChat = false
    })
  end

  wheelKeyboardFocusClaimId = consoleModule.claimKeyboardFocus(ownerWidget, {
    target = targetWidget or ownerWidget,
    editable = editable,
    cursorToEnd = editable,
    name = name or "wheel_window"
  })

  return wheelKeyboardFocusClaimId
end

function releaseWheelKeyboardFocus(options)
  if not wheelKeyboardFocusClaimId then
    return
  end

  modules.game_console.releaseKeyboardFocus(wheelKeyboardFocusClaimId, options)
  wheelKeyboardFocusClaimId = nil
end

local function isWheelSearchFocusSuppressed(tabName)
  return (wheelSearchFocusSuppressUntil[tabName] or 0) > g_clock.millis()
end

local function suppressWheelSearchFocus(tabName)
  wheelSearchFocusSuppressUntil[tabName] = g_clock.millis() + 250
end

local function getWheelSearchWidget(tabName)
  local tabWindow = nil
  if tabName == "gem" then
    tabWindow = gemAtelierWindow
  elseif tabName == "fragment" then
    tabWindow = fragmentWindow
  end

  if not tabWindow then
    return nil
  end

  local filterPanel = tabWindow.recursiveGetChildById and tabWindow:recursiveGetChildById("filterPanel") or nil
  if filterPanel and filterPanel.searchText then
    return filterPanel.searchText
  end

  return tabWindow.recursiveGetChildById and tabWindow:recursiveGetChildById("searchText") or nil
end

function clearWheelSearchFocus(tabName)
  local searchText = getWheelSearchWidget(tabName)
  if not searchText then
    return
  end

  if searchText.clearFocus then
    searchText:clearFocus()
  end
  if searchText.ungrabKeyboard then
    searchText:ungrabKeyboard()
  end
end

local function restoreWheelNavigationFocus()
  local consoleModule = modules.game_console
  if consoleModule and consoleModule.isChatEnabled and consoleModule.isChatEnabled() then
    return
  end

  local interfaceModule = modules.game_interface
  local rootPanel = interfaceModule and interfaceModule.getRootPanel and interfaceModule.getRootPanel() or nil
  local mapPanel = interfaceModule and interfaceModule.getMapPanel and interfaceModule.getMapPanel() or nil
  if rootPanel and mapPanel and rootPanel.focusChild then
    rootPanel:focusChild(mapPanel, KeyboardFocusReason)
  end
  if mapPanel and mapPanel.focus then
    mapPanel:focus()
  elseif rootPanel and rootPanel.focus then
    rootPanel:focus()
  end
end

function releaseWheelSearchInput(tabName, suppressFocus)
  if suppressFocus then
    suppressWheelSearchFocus(tabName)
  end

  releaseWheelKeyboardFocus()
  clearWheelSearchFocus(tabName)
  restoreWheelNavigationFocus()

  if suppressFocus then
    scheduleEvent(function()
      releaseWheelKeyboardFocus()
      clearWheelSearchFocus(tabName)
      restoreWheelNavigationFocus()
    end, 20)

    scheduleEvent(function()
      releaseWheelKeyboardFocus()
      clearWheelSearchFocus(tabName)
      restoreWheelNavigationFocus()
    end, 120)
  end
end

function bindWheelSearchFocusHandlers(tabName)
  local searchText = getWheelSearchWidget(tabName)
  if not searchText or searchText.wheelSearchFocusHandlersBound then
    return
  end

  searchText.wheelSearchFocusHandlersBound = true

  local previousOnFocusChange = searchText.onFocusChange
  searchText.onFocusChange = function(widget, focused)
    if previousOnFocusChange then
      previousOnFocusChange(widget, focused)
    end

    if focused and not isWheelSearchFocusSuppressed(tabName) then
      claimWheelKeyboardFocus(wheelWindow, widget, true, "wheel_" .. tabName .. "_search")
    else
      releaseWheelKeyboardFocus()
      clearWheelSearchFocus(tabName)
    end
  end

  local previousOnMousePress = searchText.onMousePress
  searchText.onMousePress = function(widget, mousePos, mouseButton)
    if previousOnMousePress then
      previousOnMousePress(widget, mousePos, mouseButton)
    end

    if mouseButton == MouseLeftButton and not isWheelSearchFocusSuppressed(tabName) then
      scheduleEvent(function()
        if widget and (not widget.isDestroyed or not widget:isDestroyed()) and not isWheelSearchFocusSuppressed(tabName) then
          claimWheelKeyboardFocus(wheelWindow, widget, true, "wheel_" .. tabName .. "_search")
        end
      end, 1)
    end

    return false
  end
end

local function updateWheelButtonHighlight(amount)
  if not wheelButton then
    return
  end

  local shouldShow = (amount or 0) > 0
  local highlight = wheelButton:getChildById('highlight')
  local bright = wheelButton:getChildById('brightButton')

  if highlight then
    highlight:setVisible(shouldShow)
  end

  if bright then
    bright:setVisible(shouldShow)
  end
end

-- A truthy return stops signalcall, so the loader result must not reach the other onGameStart handlers.
local function onGameStart()
  WheelOfDestiny.loadWheelPresets()
end

function init()
  wheelWindow = g_ui.displayUI('wheel')
  mainPanel = wheelWindow:getChildById('mainPanel')

  wheelOfDestinyWindow = g_ui.loadUI('styles/wheelMenu', mainPanel)
  wheelOfDestinyWindow:hide()

  gemAtelierWindow = g_ui.loadUI('styles/gemMenu', mainPanel)
  gemAtelierWindow:hide()
  
  local affinitiesBox = gemAtelierWindow:recursiveGetChildById('affinitiesBox')
  local qualitiesBox = gemAtelierWindow:recursiveGetChildById('qualitiesBox')
  
  if affinitiesBox then
    affinitiesBox.onOptionChange = function(widget, text, data)
      if GemAtelier and GemAtelier.onSortAffinity then
        GemAtelier.onSortAffinity(widget, widget.currentIndex)
      end
    end
  end
  
  if qualitiesBox then
    qualitiesBox.onOptionChange = function(widget, text, data)
      if GemAtelier and GemAtelier.onSortQuality then
        GemAtelier.onSortQuality(widget, widget.currentIndex)
      end
    end
  end

  fragmentWindow = g_ui.loadUI('styles/fragmentMenu', mainPanel)
  fragmentWindow:hide()

  newPresetWindow = g_ui.displayUI('styles/newPreset')
  newPresetWindow:hide()

  renamePresetWindow = g_ui.displayUI('styles/renamePreset')
  renamePresetWindow:hide()

  loadConfigJson()

  selectedNewPresetRadio = UIRadioGroup.create()
  selectedNewPresetRadio:addWidget(newPresetWindow.contentPanel.useEmpty)
  selectedNewPresetRadio:addWidget(newPresetWindow.contentPanel.copyPreset)
  selectedNewPresetRadio:addWidget(newPresetWindow.contentPanel.import)
  selectedNewPresetRadio:selectWidget(newPresetWindow.contentPanel.import)
  selectedNewPresetRadio.onSelectionChange = WheelOfDestiny.onNewPresetSelectionChange

  local addOneButton = wheelOfDestinyWindow:recursiveGetChildById('addOne')
  local rmvOneButton = wheelOfDestinyWindow:recursiveGetChildById('rmvOne')

  g_mouse.bindAutoPress(addOneButton, function()
    onAddOne()
  end, 500, nil)

  g_mouse.bindAutoPress(rmvOneButton, function()
    onRmvOne()
  end, 500, nil)

  loadMenu('wheelMenu')
  toggleTabBarButtons('informationButton')
  hide()
  connect(g_game, {
    onGameEnd = onGameEnd,
    onGameStart = onGameStart,
    onDestinyWheel = WheelOfDestiny.onDestinyWheel,
    --onUnlockGem = GemAtelier.onUnlockGem, --disabled because it's in TODO
    onResourceBalance = onResourceBalance,
  })
  
  if modules.game_mainpanel then
    wheelButton = modules.game_mainpanel.addToggleButton('wheelButton', tr('Wheel of Destiny'),   
      '/images/options/button_skillwheeldialog', toggle, false, 10)  
    wheelButton:setOn(false)
    if g_game.getLocalPlayer() and ResourceTypes and ResourceTypes.WHEEL_OF_DESTINY then
      local wheelPoints = g_game.getLocalPlayer():getResourceBalance(ResourceTypes.WHEEL_OF_DESTINY) or 0
      updateWheelButtonHighlight(wheelPoints)
    end
  end
end

function terminate()
  disconnect(g_game, {
    onGameEnd = onGameEnd,
    onGameStart = onGameStart,
    onDestinyWheel = WheelOfDestiny.onDestinyWheel,
    --onUnlockGem = GemAtelier.onUnlockGem, --disabled because it's in TODO
    onResourceBalance = onResourceBalance
  })

  if wheelWindow then
    releaseWheelSearchInput("gem")
    releaseWheelSearchInput("fragment")
    releaseWheelKeyboardFocus({
      restoreChat = false
    })
    wheelWindow:destroy()
    wheelWindow = nil
  end
end

function toggle()
  if wheelWindow:isVisible() then
    wheelWindow:hide()
    wheelWindow:ungrabMouse()
    releaseWheelSearchInput("gem")
    releaseWheelSearchInput("fragment")
    releaseWheelKeyboardFocus()
    restoreWheelNavigationFocus()
  else
    wheelWindow:focus()
    claimWheelKeyboardFocus(wheelWindow, wheelWindow, false, "wheel_main")
    loadMenu('wheelMenu')
    if gemAtelierWindow:isVisible() then
      gemAtelierWindow:hide()
    end
    if fragmentWindow:isVisible() then
      fragmentWindow:hide()
    end

    g_game.openWheel(g_game.getLocalPlayer():getId())
    wheelWindow:recursiveGetChildById('tabContent'):setVisible(false)
    WheelOfDestiny.onRemoveClick()
  end
end

function hide()
  wheelWindow:ungrabMouse()
  releaseWheelSearchInput("gem")
  releaseWheelSearchInput("fragment")
  releaseWheelKeyboardFocus()
  wheelWindow:hide()
  restoreWheelNavigationFocus()
end

function onGameEnd()
  hide()
  if wheelButton then
    updateWheelButtonHighlight(0)
  end
  WheelOfDestiny.saveWheelPresets()

  newPresetWindow:hide()
  renamePresetWindow:hide()

  if exportCodeWindow then
    exportCodeWindow:destroy()
    exportCodeWindow = nil
  end

  if exportCodeWindow then
    exportCodeWindow:destroy()
    exportCodeWindow = nil
  end

  if checkSavePresetWindow then
    checkSavePresetWindow:destroy()
    checkSavePresetWindow = nil
  end

  WheelOfDestiny.currentPreset = {}
  wheelWindow:ungrabMouse()
  releaseWheelSearchInput("gem")
  releaseWheelSearchInput("fragment")
  releaseWheelKeyboardFocus({
    restoreChat = false
  })
end

function show()
  g_game.openWheel(g_game.getLocalPlayer():getId())
end

-- check click point
function onWheelClick(position)
  WheelOfDestiny.onWheelClick(position)
end

function loadMenu(menuId)
  wheelWindow:ungrabMouse()
  releaseWheelKeyboardFocus({
    restoreChat = false
  })
  
  if wheelOfDestinyWindow:isVisible() then
    wheelOfDestinyWindow:hide()
  end
  if gemAtelierWindow:isVisible() then
    gemAtelierWindow:hide()
  end
  if newPresetWindow:isVisible() then
    newPresetWindow:hide()
  end
  if fragmentWindow:isVisible() then
    fragmentWindow:hide()
  end

  wheelMenuButton = wheelWindow.optionsTabBar:getChildById('wheelMenu')
  gemMenuButton = wheelWindow.optionsTabBar:getChildById('gemMenu')
  fragmentMenuButton = wheelWindow.optionsTabBar:getChildById('fragmentMenu')

  if menuId == 'wheelMenu' then
    releaseWheelSearchInput("gem")
    releaseWheelSearchInput("fragment")
    gemAtelierWindow:hide()
    fragmentWindow:hide()
    wheelPanel = wheelOfDestinyWindow:getChildById('wheelPanel')

    wheelPanel.onMouseMove = WheelOfDestiny.onMouseMove

    centerReferencePoint = wheelOfDestinyWindow:recursiveGetChildById('centerReferencePoint')
    wheelMenuButton:setChecked(true)
    gemMenuButton:setChecked(false)
    fragmentMenuButton:setChecked(false)
    local informationButton = wheelWindow.mainPanel.wheelMenu.info.presetTabBar:getChildById('informationButton')
    local managePresetsButton = wheelWindow.mainPanel.wheelMenu.info.presetTabBar:getChildById('managePresetsButton')
    local summaryButton = wheelWindow.mainPanel.wheelMenu.dedicationPerks:getChildById('summaryButton')
    local summaryOpenedButton = wheelWindow.mainPanel.wheelMenu.summary:getChildById('summaryButton')
    informationButton.onClick = function() toggleTabBarButtons('informationButton') end
    managePresetsButton.onClick = function() 
      toggleTabBarButtons('managePresetsButton')
      scheduleEvent(function() WheelOfDestiny.configurePresets() end, 50)
    end
    summaryButton.onClick = function() toggleSummary() end
    summaryOpenedButton.onClick = function() toggleSummary() end
    toggleTabBarButtons('informationButton')

    if WheelOfDestiny.lastSelectedGemVessel and WheelOfDestiny.lastSelectedGemVessel:isVisible() then
      local currentDomain = WheelOfDestiny.lastSelectedGemVessel:getId():gsub("selectVessel", "")
      WheelOfDestiny.onGemVesselClick(tonumber(currentDomain))
    end
    Workshop.createFragments()
    wheelOfDestinyWindow:show(true)
    claimWheelKeyboardFocus(wheelWindow, wheelWindow, false, "wheel_main")
  elseif menuId == 'gemMenu' then
    releaseWheelSearchInput("fragment")
    Workshop.createFragments()
    GemAtelier.resetFields()
    GemAtelier.showGems(true)
    gemAtelierWindow:show(true)
    bindWheelSearchFocusHandlers("gem")
    clearWheelSearchFocus("gem")
    claimWheelKeyboardFocus(wheelWindow, wheelWindow, false, "wheel_gem")
    wheelMenuButton:setChecked(false)
    fragmentMenuButton:setChecked(false)
    gemMenuButton:setChecked(true)
  elseif menuId == 'fragmentMenu' then
    releaseWheelSearchInput("gem")
    Workshop.createFragments()
    Workshop.showFragmentList(true)
    fragmentWindow:show(true)
    bindWheelSearchFocusHandlers("fragment")
    clearWheelSearchFocus("fragment")
    claimWheelKeyboardFocus(wheelWindow, wheelWindow, false, "wheel_fragment")
    wheelMenuButton:setChecked(false)
    gemMenuButton:setChecked(false)
    fragmentMenuButton:setChecked(true)
  end
end

function toggleSummary()
  summaryVisible = not summaryVisible

  local summaryPanel = wheelWindow.mainPanel.wheelMenu:getChildById('summary')
  local dedicationPerksPanel = wheelWindow.mainPanel.wheelMenu:getChildById('dedicationPerks')
  local convictionPerksPanel = wheelWindow.mainPanel.wheelMenu:getChildById('convictionPerks')
  local vesselsPanel = wheelWindow.mainPanel.wheelMenu:getChildById('vessels')
  local revelationPerksPanel = wheelWindow.mainPanel.wheelMenu:getChildById('revelationPerks')

  summaryPanel:setVisible(summaryVisible)
  dedicationPerksPanel:setVisible(not summaryVisible)
  convictionPerksPanel:setVisible(not summaryVisible)
  vesselsPanel:setVisible(not summaryVisible)
  revelationPerksPanel:setVisible(not summaryVisible)
  WheelOfDestiny.configureSummary()
end

function toggleTabBarButtons(selectedButtonId)
  local informationButton = wheelWindow.mainPanel.wheelMenu.info.presetTabBar:getChildById('informationButton')
  local managePresetsButton = wheelWindow.mainPanel.wheelMenu.info.presetTabBar:getChildById('managePresetsButton')
  local tabContent = wheelWindow.mainPanel.wheelMenu.info.tabContent

  if selectedButtonId == 'informationButton' then
    informationButton:setSize(tosize("174 34"))
    informationButton:setImageSource('/images/game/wheel/informationSelection')
    informationButton:setImageClip(torect("0 0 174 34"))
    managePresetsButton:setSize(tosize("34 34"))
    managePresetsButton:setImageSource('/images/game/wheel/small_manage_button')
    managePresetsButton:setImageClip(torect("0 0 34 34"))
    tabContent.manage:setVisible(false)
    tabContent.information:setVisible(true)
  elseif selectedButtonId == 'managePresetsButton' then
    informationButton:setSize(tosize("34 34"))
    informationButton:setImageSource('/images/game/wheel/small_information_button')
    informationButton:setImageClip(torect("0 0 34 34"))
    managePresetsButton:setSize(tosize("174 34"))
    managePresetsButton:setImageSource('/images/game/wheel/manageSelect')
    managePresetsButton:setImageClip(torect("0 0 174 34"))
    tabContent.information:setVisible(false)
    tabContent.manage:setVisible(true)
  end
end

function onResourceBalance(resourceType, value)
  if wheelButton and ResourceTypes and resourceType == ResourceTypes.WHEEL_OF_DESTINY then
    updateWheelButtonHighlight(value)
  end

  if not wheelWindow:isVisible() then
    return true
  end
  local player = g_game.getLocalPlayer()
  
  local bankMoney = player:getResourceBalance(ResourceTypes.BANK_BALANCE)
  local characterMoney = player:getResourceBalance(ResourceTypes.GOLD_EQUIPPED)
  local lesserFragment = player:getResourceBalance(ResourceTypes.LESSER_FRAGMENTS)
  local greaterFragment = player:getResourceBalance(ResourceTypes.GREATER_FRAGMENTS)

  local value = bankMoney + characterMoney

  wheelWindow.moneyPanel.gold:setText(formatMoney(value, ','))
  wheelWindow.lesserFragmentPanel.gold:setText(lesserFragment)
  wheelWindow.greaterFragmentPanel.gold:setText(greaterFragment)

end

function loadConfigJson()
	local file = "/json/SkillwheelStringsJsonLibrary.json"
	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			return g_logger.debug("Error while reading characterdata file. Details: " .. result)
		end

		SkillwheelStringsLibrary = result
	end
end
