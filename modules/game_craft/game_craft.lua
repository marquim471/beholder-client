local OPCODE = 150

local craftWindow
local recipeList
local detailsPanel
local balanceLabel
local searchInput
local statusLabel
local craftButton

local recipes = {}
local selectedRecipe = nil
local playerBalance = 0

-- Forward declarations for local functions
local create, destroy, toggle, refresh, updateBalance, onExtendedOpcode, sendData
local onRecipeClick, updateRecipeList, updateDetails, onSearchTextChange, craft, formatNumber
local onGameStart, onGameEnd

function init()
  g_logger.info('[CraftSystem] Initializing module...')

  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
  })

  ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)

  if g_game.isOnline() then
    create()
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
  })

  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  destroy()
end

onGameStart = function()
  create()
end

onGameEnd = function()
  destroy()
end

create = function()
  if craftWindow then return craftWindow end

  local root = g_ui.getRootWidget()
  if not root then return nil end

  local oldWindow = root:getChildById('craftWindow')
  if oldWindow then
    oldWindow:destroy()
  end

  craftWindow = g_ui.displayUI('game_craft')
  if not craftWindow then
    g_logger.error('[CraftSystem] Could not load game_craft UI')
    return nil
  end
  craftWindow:hide()

  local mainPanel = craftWindow:getChildById('mainPanel')
  if not mainPanel then
    g_logger.error('[CraftSystem] Could not find mainPanel in craftWindow')
    return nil
  end

  recipeList = mainPanel:getChildById('recipeList')
  if recipeList then
    recipeList.onChildFocusChange = function(self, focusedChild)
      if focusedChild then
        onRecipeClick(focusedChild)
      end
    end
  end

  detailsPanel = mainPanel:getChildById('detailsPanel')
  if detailsPanel then
    statusLabel = detailsPanel:getChildById('statusLabel')
    local craftBtn = detailsPanel:getChildById('craftButton')
    if craftBtn then
      craftBtn.onClick = craft
    end
  end

  balanceLabel = craftWindow:getChildById('balanceLabel')
  searchInput = craftWindow:getChildById('searchInput')
  if searchInput then
    searchInput.onTextChange = function(self, text)
      onSearchTextChange(text)
    end
  end

  local closeBtn = craftWindow:getChildById('closeButton')
  if closeBtn then
    closeBtn.onClick = toggle
  end

  local refreshBtn = craftWindow:getChildById('refreshButton')
  if refreshBtn then
    refreshBtn.onClick = refresh
  end

  if not craftButton and modules.client_topmenu and modules.client_topmenu.addRightGameButton then
    craftButton = modules.client_topmenu.addRightGameButton('craftButton', tr('Craft System'), '/images/topbuttons/spelllist', toggle)
  end

  return craftWindow
end

destroy = function()
  if craftWindow then
    craftWindow:destroy()
    craftWindow = nil
  end

  local root = g_ui.getRootWidget()
  if root then
    local oldWindow = root:getChildById('craftWindow')
    if oldWindow then
      oldWindow:destroy()
    end
  end

  if craftButton then
    if type(craftButton) == 'userdata' and not craftButton:isDestroyed() then
      craftButton:destroy()
    end
    craftButton = nil
  end

  statusLabel = nil
  balanceLabel = nil
  searchInput = nil
  recipeList = nil
  detailsPanel = nil
  selectedRecipe = nil
  recipes = {}
end

toggle = function()
  if not craftWindow or not recipeList then
    create()
  end
  if not craftWindow then return end

  if craftWindow:isVisible() then
    craftWindow:hide()
  else
    craftWindow:show()
    craftWindow:raise()
    craftWindow:focus()
    refresh()
  end
end

refresh = function()
  sendData({action = 'fetch'})
end

updateBalance = function()
  if not balanceLabel then return end
  balanceLabel:setText(string.format('Balance: %s gp', formatNumber(playerBalance)))
end

onExtendedOpcode = function(protocol, opcode, buffer)
  if opcode ~= OPCODE then return end

  local jsonLib = json or JSON
  local status, data = pcall(function() return jsonLib.decode(buffer) end)
  if not status or not data then
    g_logger.error('[CraftSystem] Failed to decode buffer: ' .. tostring(buffer))
    return
  end

  if data.action == 'list' then
    if not craftWindow or not recipeList then
      create()
    end

    recipes = data.recipes or {}
    playerBalance = data.balance or 0
    updateBalance()
    updateRecipeList()

    if craftWindow and not craftWindow:isVisible() then
      craftWindow:show()
      craftWindow:raise()
      craftWindow:focus()
    end
  elseif data.action == 'status' then
    if statusLabel then
      statusLabel:setText(data.message or '')
      if data.success then
        statusLabel:setColor('#33ff33')
      else
        statusLabel:setColor('#ff3333')
      end
    end
  end
end

sendData = function(data)
  local protocol = g_game.getProtocolGame()
  if protocol then
    local jsonLib = json or JSON
    protocol:sendExtendedOpcode(OPCODE, jsonLib.encode(data))
  end
end

onRecipeClick = function(widget)
  local index = widget.recipeIndex
  selectedRecipe = recipes[index]
  updateDetails()
end

updateRecipeList = function()
  if not craftWindow or not recipeList then
    create()
  end
  if not recipeList then
    g_logger.error('[CraftSystem] recipeList is nil in updateRecipeList')
    return
  end

  local lastSelectedId = selectedRecipe and selectedRecipe.id or nil
  recipeList:destroyChildren()
  local filterText = (searchInput and searchInput:getText() or ''):lower()

  local toFocus = nil
  for i, recipe in ipairs(recipes) do
    if filterText == '' or recipe.name:lower():find(filterText, 1, true) then
      local widget = g_ui.createWidget('CraftListItem', recipeList)
      widget:setId('recipe_' .. i)
      local nameLabel = widget:getChildById('name')
      if nameLabel then
        nameLabel:setText(recipe.name)
      end
      local itemWidget = widget:getChildById('item')
      if itemWidget then
        itemWidget:setItemId(recipe.resultId)
      end
      widget.recipeIndex = i

      if lastSelectedId and recipe.id == lastSelectedId then
        toFocus = widget
      end
    end
  end

  if toFocus then
    recipeList:focusChild(toFocus)
  else
    selectedRecipe = nil
    updateDetails()
  end
end

updateDetails = function()
  if not detailsPanel then return end

  local resultName = detailsPanel:getChildById('resultName')
  local resultItem = detailsPanel:getChildById('resultItem')
  local resultDesc = detailsPanel:getChildById('resultDescription')
  local ingredientsList = detailsPanel:getChildById('ingredientsList')
  local craftBtn = detailsPanel:getChildById('craftButton')

  if not selectedRecipe then
    if resultName then resultName:setText('Select a recipe') end
    if resultItem then resultItem:setItemId(0) end
    if resultDesc then resultDesc:setText('') end
    if ingredientsList then ingredientsList:destroyChildren() end
    if craftBtn then craftBtn:setEnabled(false) end
    if statusLabel then statusLabel:setText('') end
    return
  end

  if resultName then resultName:setText(selectedRecipe.name) end
  if resultItem then resultItem:setItemId(selectedRecipe.resultId) end
  if resultDesc then resultDesc:setText(string.format('Produces: 1x %s', selectedRecipe.name)) end

  if ingredientsList then
    ingredientsList:destroyChildren()
  end

  local canCraft = true

  -- Add Gold Cost as an ingredient if > 0
  if selectedRecipe.gold and selectedRecipe.gold > 0 and ingredientsList then
    local widget = g_ui.createWidget('IngredientItem', ingredientsList)
    local itm = widget:getChildById('item')
    if itm then itm:setItemId(3031) end
    local nm = widget:getChildById('name')
    if nm then nm:setText(string.format('%s gp', formatNumber(selectedRecipe.gold))) end

    local countLabel = widget:getChildById('count')
    if countLabel then
      countLabel:setText(string.format('%s / %s', formatNumber(playerBalance), formatNumber(selectedRecipe.gold)))
      if playerBalance < selectedRecipe.gold then
        countLabel:setColor('#ff3333')
        canCraft = false
      else
        countLabel:setColor('#33ff33')
      end
    end
  end

  if selectedRecipe.ingredients and ingredientsList then
    for _, ingredient in ipairs(selectedRecipe.ingredients) do
      local widget = g_ui.createWidget('IngredientItem', ingredientsList)
      local itm = widget:getChildById('item')
      if itm then itm:setItemId(ingredient.itemId) end

      local nm = widget:getChildById('name')
      if nm then nm:setText(string.format('%dx %s', ingredient.requiredAmount, ingredient.name)) end

      local playerAmount = ingredient.playerAmount or 0
      local requiredAmount = ingredient.requiredAmount or 0

      local countLabel = widget:getChildById('count')
      if countLabel then
        countLabel:setText(string.format('%d / %d', playerAmount, requiredAmount))
        if playerAmount < requiredAmount then
          countLabel:setColor('#ff3333')
          canCraft = false
        else
          countLabel:setColor('#33ff33')
        end
      end
    end
  end

  if craftBtn then
    craftBtn:setEnabled(canCraft)
  end
end

onSearchTextChange = function(text)
  updateRecipeList()
end

craft = function()
  if not selectedRecipe then return end
  if statusLabel then
    statusLabel:setText('Crafting...')
    statusLabel:setColor('#ffffff')
  end
  sendData({action = 'craft', recipeId = selectedRecipe.id})
end

formatNumber = function(value)
  local formatted = tostring(math.floor(tonumber(value) or 0))
  local k
  repeat
    formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1.%2')
  until k == 0
  return formatted
end

modules.game_craft = {
  init = init,
  terminate = terminate,
  toggle = toggle,
  create = create,
  destroy = destroy,
  refresh = refresh,
}
