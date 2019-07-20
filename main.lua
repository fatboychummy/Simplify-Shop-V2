--[[
0

]]

-- requires

local smenus = require("modules.text.menus.simple")
local imenus = require("modules.text.menus.insert")
local qmenus = require("modules.text.menus.questions")
local cache = require("modules.item.cache")
local bsod = require("modules.etc.bsod")
local monitor = require("modules.etc.monitor")
local ep = require("modules.etc.extraPeripherals")

local modules = {
  smenus,
  imenus,
  qmenus,
  cache,
  bsod,
  monitor,
  ep
}

-- miniinit
local build = 0
local mon
local settingsLocation = "/.shopsettings"


-- shop settings.
local sets = {
  "shop.shopName",
  "shop.shopOwner",
  "shop.refreshRate",
  "shop.dataLocation",
  "shop.cacheSaveName",
  "shop.logLocation",
  "shop.rebootTime",
  "shop.autorun",
  "shop.autorunTime",
  "shop.monitor.monitor",
  "shop.monitor.textScale",
  defaults = {
    "Unnamed Shop",
    "Unknown",
    10,
    "/data",
    "/data/cache.ic",
    "/data/logs",
    30,
    true,
    5,
    "ERROR 3",
    0.5
  }
}

local function checkSettings()
  for i = 1, #sets do
    if type(settings.get(sets[i])) == "nil" then
      print("Missing settings value:", sets[i])
      os.sleep(0.2)
      settings.set(sets[i], sets.defaults[i])
      settings.save(settingsLocation)
    end
  end
end

local function updateCheck()
  --TODO: finish this.
end

local function updateCheckString()
  --TODO: call updateCheck and return a string depending on what is returned.
  return "No updates available."
end

local function notify(...)
  local args = {...}
  -- notify modules
  for i, module in ipairs(modules) do
    if type(module) == "table" then
      if type(module.notify) == "function" then
        module.notify(table.unpack(args))
      end
    end
  end

  -- notify self
  if args[1] == "settings_update" then
    mon = peripheral.wrap(settings.get("shop.monitor"))
    if type(mon) ~= "table" then
      local monName = peripheral.findString("monitor")[1]
      mon = peripheral.wrap(monName)
      settings.set("shop.monitor", monName)
    end
  end
  monitor.setupMonitor(mon)
end

local function mainMenu()
  local menu = smenus.newMenu()
  menu.title = "Simplify Shop V2B" .. tostring(build)
  menu:addMenuItem(
    "Run",
    "Run the shop.",
    "Run the shop."
  )
  --
  menu:addMenuItem(
    "Update",
    updateCheckString(),
    "Updates the shop and reboots."
  )
  --
  menu:addMenuItem(
    "Add/Remove",
    "Add/Remove shop item(s).",
    "Use a helpful UI to add or remove items in your shop."
  )
  --
  menu:addMenuItem(
    "Options",
    "Edit shop config.",
    "Open a menu which allows you to change core settings for the shop."
  )
  --
  menu:addMenuItem(
    "Error",
    "Debug Error",
    "Force an error to do some random debugging."
  )

  return menu:go(settings.get("shop.autorun")
                 and settings.get("shop.autorunTime"))
end

local function optionsMenu()
  local menu = imenus.newMenu()
  menu.title = "Settings"
  menu.info = "Select an item to edit it's value."

  menu:addMenuItem(
    "Shop name",
    "string",
    settings.get("shop.shopName") or "ERROR 1",
    "The name to be displayed for the shop."
  )
  menu:addMenuItem(
    "Shop owner",
    "string",
    settings.get("shop.shopOwner") or "ERROR 1",
    "Who owns this shop?"
  )
  menu:addMenuItem(
    "Refresh rate",
    "number",
    settings.get("shop.refreshRate") or -1,
    "Speed at which the shop will refresh it's screen (in seconds)."
  )
  menu:addMenuItem(
    "Data folder",
    "string",
    settings.get("shop.dataLocation") or "ERROR 1",
    "File system location at which the data folder will be stored"
  )
  menu:addMenuItem(
    "Cache Name",
    "string",
    settings.get("shop.cacheSaveName") or "ERROR 1",
    "Location at which the cache will be saved."
  )
  menu:addMenuItem(
    "Log folder",
    "string",
    settings.get("shop.logLocation") or "ERROR 1",
    "Location at which the logs folder will be saved."
  )
  menu:addMenuItem(
    "Error Timer",
    "number",
    settings.get("shop.rebootTime") or "ERROR 1",
    "When an error occurs, the shop will wait this time (in seconds) to reboot."
  )
  local autorun = settings.get("shop.autorun")
  if type(autorun) == "boolean" then
    menu:addMenuItem(
      "Autorun",
      "boolean",
      autorun,
      "Should the shop autorun on boot?"
    )
  else
    menu:addMenuItem(
      "Autorun",
      "boolean",
      true,
      "Should the shop autorun on boot?"
    )
  end
  menu:addMenuItem(
    "Autorun Time",
    "number",
    settings.get("shop.autorunTime") or "ERROR 1",
    "How long should the shop wait until being run if autorun enabled?"
  )
  menu:addMenuItem(
    "Monitor",
    "string",
    settings.get("shop.monitor.monitor") or peripheral.findString("monitor")[1]
      or "NO MONITOR",
    "The name of the monitor on the wired network."
  )
  menu:addMenuItem(
    "Text Size",
    "number",
    settings.get("shop.monitor.textScale") or 0.5,
    "The scale of the text for the monitor.  Min 0.5, max 4"
  )

  local function updater()
    for i = 1, #sets do
      settings.set(sets[i], menu.menuItems.appends[i])
    end
    settings.save(settingsLocation)
    notify("settings_update")
    for i = 1, #sets do
      local append = menu.menuItems.appends[i]
      if settings.get(sets[i]) ~= append then
        menu.menuItems.appends[i] = settings.get(sets[i])
      end
    end
  end

  menu:go(updater)

  updater()
end

local function errorMenu(err)
  local menu = smenus.newMenu()
  menu.title = "Error"
  menu.info = err

  menu:addMenuItem(
    "Reboot",
    "Reboot the shop.",
    "Reboot the shop."
  )
  menu:addMenuItem(
    "Return",
    "",
    "Return to the shell."
  )

  return menu:go(settings.get("shop.rebootTime") or 30)
end

local function scanChest()
  term.clear()
  term.setCursorPos(1, 1)

  local front = peripheral.getType("front")

  local function scan()
    local chest = peripheral.wrap("front")
    local size = chest.size()
    local ls = chest.list()
    local items = {}
    local cacheItems = cache.getCache()

    for i = 1, size do
      if ls[i] then
        local flag = true
        for j = 1, #items do
          if items[j].name == ls[i].name
             and items[j].damage == ls[i].damage then
            flag = false
            break
          end
        end
        if flag then
          for k, v in pairs(cacheItems) do
            for k2, v2 in pairs(v) do
              if k == ls[i].name and k2 == ls[i].damage then
                flag = false
              end
            end
          end
        end

        if flag then
          items[#items + 1] = {
            name = ls[i].name,
            damage = ls[i].damage,
            displayName = chest.getItemMeta(i).displayName
          }
        end
      end
    end
    return items
  end

  if front and (front:find("chest") or front:find("shulker")) then
    print("Chest or shulker box in front, scanning it.")
    return scan()
  end

  print("No chest or shulker box in front. Waiting for you to place one.")
  while true do
    local ev, side = os.pullEvent("peripheral")
    if side == "front" then
      front = peripheral.getType("front")
      if front and (front:find("chest") or front:find("shulker")) then
        print("Shulker or chest attached, scanning in 5 seconds.")
        os.sleep(5)
        return scan()
      else
        print("That is not a valid chest or shulker box.")
      end
    end
  end
end

local function getDetails(items)
  local tmp = {}
  for i, item in ipairs(items) do
    local menu = qmenus.new()
    menu:addQuestion(
      "Scanned '" .. item.name .. "' with damage "
      .. tostring(item.damage) .. ".",
      "string",
      "Enter the name you wish to use for this item.\n"
      .. "Leave blank to enter '" .. item.displayName .. "'."
    )
    menu:addQuestion(
      "For the previous item, what shall the cost in krist per item be?",
      "number",
      "Enter the cost per item you wish to charge for the previous item."
    )
    menu:go()

    if menu.questions.a[1] == "" then
      menu.questions.a[1] = item.displayName
    end

    tmp[#tmp + 1] = {
      name = item.name,
      damage = item.damage,
      displayName = menu.questions.a[1],
      value = menu.questions.a[2]
    }
  end

  return tmp
end

local function addItem()
  local menu = smenus.newMenu()
  menu.title = "Add Items."
  menu.info = "Add items via a chest in front of the turtle."

  menu:addMenuItem(
    "Scan",
    "Scan the chest.",
    "Scan the chest. You will be prompted for each item for it's price and etc."
  )
  menu:addMenuItem(
    "Return",
    "Go back.",
    "Return to the startup page."
  )

  local a = menu:go()

  if a == 1 then
    local items = scanChest()
    local the_deets = getDetails(items)
    for i, item in ipairs(the_deets) do
      cache.addToCache(item.displayName, item.name, item.damage, item.value)
    end
    -- scan the chest
  elseif a == 2 then
    -- Return
    return
  end
end

local function actuallyRemove(registry)
  local menu = smenus.newMenu()
  menu.title = "Confirmation"
  menu.info = "Item to be deleted: " .. tostring(registry.key) .. " ["
              .. tostring(registry.damage) .. "]"

  menu:addMenuItem(
    "Yes",
    "Delete item.",
    "Delete the item (Warning: this is permanent)."
  )
  menu:addMenuItem(
    "No",
    "Keep item.",
    "Do not remove the item from the shop."
  )

  local ans = menu:go()
  if ans == 1 then
    cache.removeFromCache(registry.key, registry.damage)
  end
end

local function removeItem()
  while true do
    local menu = smenus.newMenu()
    menu.title = "Delete items."
    menu.info = "Select an item to delete."

    local registry = {}
    local cacheItems = cache.getCache()

    for key, reg in pairs(cacheItems) do
      for damage, registration in pairs(reg) do
        local sName = registration.name
        if #sName > 12 then
          sName = sName:sub(1, 9) .. "..."
        end
        menu:addMenuItem(
          sName,
          "Remove this item",
          "Remove the item " .. key .. "[" .. tostring(damage) .. "]"
        )
        registry[#registry + 1] = {key = key, damage = damage}
      end
    end
    menu:addMenuItem(
      "Return",
      "Go back.",
      "Return to the previous menu."
    )
    local ans = menu:go()

    if ans == #menu.menuItems.selectables then
      break
    else
      actuallyRemove(registry[ans])
    end
  end
end

local function cacheEdit(c, registry)
  local menu = imenus.newMenu()
  menu.title = "Edit item."
  menu.info = registry.key .. " with damage " .. tostring(registry.damage)
              .. "."

  menu:addMenuItem(
    "Display Name",
    "string",
    c[registry.key][registry.damage].name,
    "The name to be displayed for this item."
  )
  menu:addMenuItem(
    "Value",
    "number",
    c[registry.key][registry.damage].value,
    "The value of this item (krist per item)"
  )
  menu:addMenuItem(
    "Enabled",
    "boolean",
    c[registry.key][registry.damage].enabled,
    "If disabled, the shop will not display this item, but it will not be deleted."
  )

  menu:go()
  if menu.menuItems.appends[3] then
    menu.menuItems.appends[3] = true
  else
    menu.menuItems.appends[3] = false
  end

  cache.addToCache(
    menu.menuItems.appends[1],
    registry.key,
    registry.damage,
    menu.menuItems.appends[2],
    menu.menuItems.appends[3]
  )
end

local function editItem()
  while true do
    local c = cache.getCache()

    local menu = smenus.newMenu()
    menu.title = "Edit Item Data"
    menu.info = "Change values of items in your shop."

    local registry = {}

    for key, reg in pairs(c) do
      for damage, registration in pairs(reg) do
        local sName = registration.name
        if #sName > 12 then
          sName = sName:sub(1, 9) .. "..."
        end
        menu:addMenuItem(
          sName,
          "Edit this item.",
          "Edit the item " .. key .. "[" .. tostring(damage) .. "]"
        )
        registry[#registry + 1] = {key = key, damage = damage}
      end
    end

    menu:addMenuItem(
      "Return",
      "Go back.",
      "Return to the previous page."
    )

    local ans = menu:go()
    if ans == #registry + 1 then
      return
    else
      cacheEdit(c, registry[ans])
    end
  end
end

local function addRemove()
  local menu = smenus.newMenu()

  menu.title = "Add or Remove Items"

  menu:addMenuItem(
    "Add Items",
    "Add items to the shop.",
    "Use a helpful UI to add items to your shop."
  )
  menu:addMenuItem(
    "Edit Items",
    "Edit prices for items.",
    "Edit the prices for items sold at your shop."
  )
  menu:addMenuItem(
    "Remove Items",
    "Remove items from shop.",
    "Use a helpful UI to remove items from your shop."
  )
  menu:addMenuItem(
    "Return",
    "Go back.",
    "Return to the startup page."
  )

  while true do
    local ans = menu:go()
    if ans == 1 then
      addItem()
    elseif ans == 2 then
      editItem()
    elseif ans == 3 then
      removeItem()
    elseif ans == 4 then
      -- return to main
      return
    end
  end
end

local function main()
  -- init
  print("Initializing.")
  os.sleep(0.1)
  print("Checking settings.")
  if not settings.load(settingsLocation) then
    print("No settings are saved, creating them.")
    os.sleep(0.5)
    for i = 1, #sets do
      settings.set(sets[i], sets.defaults[i])
      print(sets[i], " - ", sets.defaults[i])
      os.sleep(0.1)
    end
    settings.save(settingsLocation)
    print("Saved settings.")
    os.sleep(0.5)
  end

  checkSettings()

  print("Grabbing monitor.")
  local monitorName = settings.get("shop.monitor")
  if not monitorName or monitorName:find("ERROR")
      or monitorName == "INVALID" then
    monitorName = peripheral.findString("monitor")[1]
    if monitorName then
      settings.set("shop.monitor", monitorName)
      settings.save(settingsLocation)
      notify("settings_update")
      print("No monitor was selected, Auto-selected " .. monitorName)
      os.sleep(3)
    else
      error("No monitor")
    end
  end

  mon = peripheral.wrap(monitorName)
  monitor.setupMonitor(mon)

  print("Checking Cache")
  os.sleep(0.1)
  cache.setSaveLocation(settings.get("shop.cacheSaveName"))
  if not cache.load() then
    print("No cache file found.")
    os.sleep(0.5)
  end

  mon.clear()
  mon.setCursorPos(1, 1)
  mon:print("Starting...")
  os.sleep(0.1)
  mon:print("Awaiting input...")
  mon:print("")

  local selection = 0
  repeat
    selection = mainMenu()
    if selection == 2 then
      --TODO: update
    elseif selection == 3 then
      addRemove()
    elseif selection == 4 then
      optionsMenu()
    elseif selection == 5 then
      error("Generated error " .. tostring(math.random(1, 1000000)))
    end
  until selection == 1
    --TODO: shop
    mon:print("Running.")
end

local ok, err = pcall(main)

if not ok then
  pcall(notify, "error")
  bsod(err, mon)
  if err ~= "Terminated" then
    local psx, psy = mon.getCursorPos()
    mon.setCursorPos(1, psy + 2)
    mon.write("Rebooting in " .. tostring(settings.get("shop.rebootTime") or 30)
              .. " seconds.")
    local ans = errorMenu(err)
    if ans == 1 then
      mon.setBackgroundColor(colors.black)
      mon.setTextColor(colors.white)
      mon.clear()
      mon.setCursorPos(1, 1)
      mon.write("Rebooting.")
      os.reboot()
    else
      return
    end
  end
end

--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
--TODO: COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT COMMENT
