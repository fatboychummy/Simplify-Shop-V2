local funcs = {}
local meta = {}
local met = {}
meta.__index = met
met.__type = "menuObject"

local ers = require("modules.etc.errors")
local ec = ers.create

function met:update()
  if self.selected > self.maxSelection then
    self.maxSelection = self.selected
  end
  if self.selected < self.maxSelection - 3 then
    self.maxSelection = self.selected + 3
  end
end

function met:selectDown()
  self.selected = self.selected - 1
  if self.selected < 1 then
    self.selected = #self.menuItems.selectables
  end

  return self
end

function met:selectUp()
  self.selected = self.selected + 1
  if self.selected > #self.menuItems.selectables then
    self.selected = 1
  end

  return self
end

function met:addMenuItem(selection, append, info)
  selection = type(selection) == "string" and selection
                or error(ec(1, "string", selection))
  --
  append = type(append) == "string" and append
           or type(append) == "nil" and ""
             or error(ec(2, "string or nil", append))
  --
  info = type(info) == "string" and info or type(info) == "nil" and ""
           or error(ec(3, "string or nil", info))
  --
  local m = self.menuItems
  table.insert(m.selectables, selection)
  table.insert(m.infos, info)
  table.insert(m.appends, append)

  return self
end

function met:changeAppend(selection, append)
  selection = type(selection) == "number" and selection
                or error(ec(1, "number", selection))
  append = type(append) == "string" and append
             or error(ec(2, "string", append))
  --
  local m = self.menuItems
  if m.selectables[selection] then
    m.appends[selection] = append
  else
    local mx = #m.selectables
    local es = "Selection out of range. Current:" .. tostring(selection) .. " "
    if selection > mx then
      es = es .. "> Max:" .. tostring(mx)
    else
      es = es .. "< Min:1"
    end
    error(es, 2)
  end

  return self
end

function met:draw()
  term.setBackgroundColor(self.colors.bg)
  term.setTextColor(self.colors.fg)
  term.clear()
  term.setCursorPos(1, 1)
  local ln = print(self.title)
  term.setBackgroundColor(self.colors.infobg)
  term.setTextColor(self.colors.infofg)
  local ln2 = print(self.info)
  local inc = ln + ln2 + 1
  print()
  term.setBackgroundColor(self.colors.bg)
  term.setTextColor(self.colors.fg)

  self:update()

  for i = self.maxSelection - 3, self.maxSelection do
    local selection = self.menuItems.selectables[i]
    if selection then
      if self.selected == i then
        io.write('>')
      else
        io.write(' ')
      end
      print(selection)
    end
  end

  term.setBackgroundColor(self.colors.appendbg)
  term.setTextColor(self.colors.appendfg)
  for i = self.maxSelection - 3, self.maxSelection do
    local append = self.menuItems.appends[i]
    if append then
      term.setCursorPos(15, inc + i)
      io.write(append)
    end
  end

  term.setBackgroundColor(self.colors.infobg)
  term.setTextColor(self.colors.infofg)
  term.setCursorPos(1, #self.menuItems.selectables + 3 + inc)
  print(self.menuItems.infos[self.selected])

  return self
end

function met:go(timeout)
  self = type(self) == "table" and self.__type == "menuObject" and self
           or error(ec(0, "menuObject", self))
  --
  local oldbg = term.getBackgroundColor()
  local oldfg = term.getTextColor()
  local tm = -1
  if type(timeout) == "number" then
    tm = os.startTimer(timeout)
    self.menuItems.infos[1] = self.menuItems.infos[1]
                                    .. " Autoselected after "
                                    .. tostring(timeout) .. " seconds "
                                    .. "of inactivity at startup."
  end

  self:update()

  while true do
    local ev = {os.pullEvent()}
    local event = ev[1]

    if event == "key" then
      local key = ev[2]
      if key == 200 then
        if tm ~= -1 then
          self.menuItems.infos[1] = self.menuItems.infos[1]:gsub(
            " Autoselected after "
              .. tostring(timeout) .. " seconds "
              .. "of inactivity at startup.",
            ""
          )
        end
        tm = -1
        -- go down (up, since inverted)
        self:selectDown()
      elseif key == 208 then
        if tm ~= -1 then
          self.menuItems.infos[1] = self.menuItems.infos[1]:gsub(
            " Autoselected after "
              .. tostring(timeout) .. " seconds "
              .. "of inactivity at startup.",
            ""
          )
        end
        tm = -1
        -- go up (down, since inverted)
        self:selectUp()
      elseif key == 28 then
        if tm ~= -1 then
          self.menuItems.infos[1] = self.menuItems.infos[1]:gsub(
            " Autoselected after "
              .. tostring(timeout) .. " seconds "
              .. "of inactivity at startup.",
          ""
          )
        end
        -- enter
        term.setTextColor(oldfg)
        term.setBackgroundColor(oldbg)
        return self.selected
      end
    elseif event == "timer" then
      if ev[2] == tm then
        self.menuItems.infos[1] = self.menuItems.infos[1]:gsub(
          " Autoselected after "
            .. tostring(timeout) .. " seconds "
            .. "of inactivity at startup.",
          ""
        )
        return 1
      end
    end

    self:draw()
  end
end

function funcs.newMenu()
  local tmp = {}
  setmetatable(tmp, meta)

  tmp.menuItems = {
    selectables = {
    },
    infos = {
    },
    appends = {
    }
  }
  tmp.colors = {
    bg = colors.black,
    fg = colors.white,
    appendbg = colors.black,
    appendfg = colors.gray,
    infobg = colors.black,
    infofg = colors.lightGray
  }

  tmp.selected = 1
  tmp.title = "Menu"
  tmp.info = "Select an item."
  tmp.maxSelection = 4


  return tmp
end

return funcs
