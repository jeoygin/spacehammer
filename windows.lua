local windows = {}

-- define screens

local mainScreen = hs.screen.allScreens()[1]
local secondScreen = hs.screen.allScreens()[2]

-- hs.window.setFrameCorrectness = true

-- define window movement/resize operation mappings
local arrowMap = {
  k = { half = { 0, 0, 1,.5}, movement = { 0,-20}, complement = "h", resize = "Shorter" },
  j = { half = { 0,.5, 1,.5}, movement = { 0, 20}, complement = "l", resize = "Taller" },
  h = { half = { 0, 0,.5, 1}, movement = {-20, 0}, complement = "j", resize = "Thinner" },
  l = { half = {.5, 0,.5, 1}, movement = { 20, 0}, complement = "k", resize = "Wider" },
}

-- compose screen quadrants from halves
local function quadrant(t1, t2)
  return {t1[1] + t2[1], t1[2] + t2[2], .5, .5}
end

-- move and/or resize windows
local function rect(rect)
  return function()
    undo:push()
    local win = fw()
    if win then win:move(rect) end
  end
end

-- Fetch next index but cycle back when at the end
--
-- > getNextIndex({1,2,3}, 3)
-- 1
-- > getNextIndex({1}, 1)
-- 1
-- @return int
local function getNextIndex(table, currentIndex)
  nextIndex = currentIndex + 1
  if nextIndex > #table then
    nextIndex = 1
  end

  return nextIndex
end

local function getNextWindow(windows, window)
  if type(windows) == "string" then
    windows = hs.application.find(windows):allWindows()
  end

  windows = hs.fnutils.filter(windows, hs.window.isStandard)
  windows = hs.fnutils.filter(windows, hs.window.isVisible)

  -- need to sort by ID, since the default order of the window
  -- isn't usable when we change the mainWindow
  -- since mainWindow is always the first of the windows
  -- hence we would always get the window succeeding mainWindow
  table.sort(windows, function(w1, w2)
    return w1:id() > w2:id()
  end)

  lastIndex = hs.fnutils.indexOf(windows, window)
  if not lastIndex then return window end

  return windows[getNextIndex(windows, lastIndex)]
end

-- Needed to enable cycling of application windows
lastToggledApplication = ''

function launchOrCycleFocus(applicationName)
  return function()
    local nextWindow = nil
    local targetWindow = nil
    local focusedWindow          = hs.window.focusedWindow()
    local lastToggledApplication = focusedWindow and focusedWindow:application():name()

    if not focusedWindow then return nil end
    if lastToggledApplication == applicationName then
      nextWindow = getNextWindow(applicationName, focusedWindow)
      -- Becoming main means
      -- * gain focus (although docs say differently?)
      -- * next call to launchOrFocus will focus the main window <- important
      -- * when fetching allWindows() from an application mainWindow will be the first one
      --
      -- If we have two applications, each with multiple windows
      -- i.e:
      --
      -- Google Chrome: {window1} {window2}
      -- Firefox:       {window1} {window2} {window3}
      --
      -- and we want to move between Google Chrome {window2} and Firefox {window3}
      -- when pressing the hotkeys for those applications, then using becomeMain
      -- we cycle until those windows (i.e press hotkey twice for Chrome) have focus
      -- and then the launchOrFocus will trigger that specific window.
      nextWindow:becomeMain()
      nextWindow:focus()
    else
      hs.application.launchOrFocus(applicationName)
    end

    if nextWindow then
      targetWindow = nextWindow
    else
      targetWindow = hs.window.focusedWindow()
    end

    if not targetWindow then
      return nil
    end
  end
end

windows.bind = function(modal, fsm)
  -- maximize window
  modal:bind("","m", function()
               rect({0, 0, 1, 1})()
               windows.highlighActiveWin()
  end)

  -- fullscreen
  modal:bind("","f", function()
               fw():toggleFullScreen()
  end)

  -- center on screen
  modal:bind("","c", function()
               fw():centerOnScreen()
  end)

  -- undo
  modal:bind("", "u", function() undo:pop() end)

  -- moving/re-sizing windows
  hs.fnutils.each({"h", "l", "k", "j"}, function(arrow)
      local dir = { h = "Left", j = "Down", k = "Up", l = "Right"}
      -- screen halves
      modal:bind({}, arrow, function()
          undo:push()
          rect(arrowMap[arrow].half)()
      end)
      -- incrementally
      modal:bind({"alt"}, arrow, function()
          undo:push()
          hs.grid['pushWindow'..dir[arrow]](fw()) 
      end)

      modal:bind({"shift"}, arrow, function()
          undo:push()
          hs.grid['resizeWindow'..arrowMap[arrow].resize](fw())
      end)
  end)

  -- window grid
  hs.grid.setMargins({0, 0})
  modal:bind("", "g", function()
                local gridSize = hs.grid.getGrid()
                undo:push()
                hs.grid.setGrid("3x2")
                hs.grid.show(function() hs.grid.setGrid(gridSize) end)
                fsm:toIdle()
  end)

  -- jumping between windows
  hs.fnutils.each({"h", "l", "k", "j"}, function(arrow)
      modal:bind({"cmd"}, arrow, function()
          if arrow == "h" then fw().filter.defaultCurrentSpace:focusWindowWest(nil, true, true) end
          if arrow == "l" then fw().filter.defaultCurrentSpace:focusWindowEast(nil, true, true) end
          if arrow == "j" then fw().filter.defaultCurrentSpace:focusWindowSouth(nil, true, true) end
          if arrow == "k" then fw().filter.defaultCurrentSpace:focusWindowNorth(nil, true, true) end
          windows.highlighActiveWin()
      end)
  end)

  -- moving windows around screens
  modal:bind({}, 'n', function() undo:push(); fw():moveOneScreenNorth() end)
  modal:bind({}, 's', function() undo:push(); fw():moveOneScreenSouth() end)
  modal:bind({}, 'e', function() undo:push(); fw():moveOneScreenEast() end)
  modal:bind({}, 'w', function() undo:push(); fw():moveOneScreenWest() end)
  modal:bind({}, '1', function() undo:push(); fw():moveToScreen(mainScreen) end)
  modal:bind({}, '2', function() undo:push(); fw():moveToScreen(secondScreen) end)
end

-- undo for window operations
undo = {}

function undo:push()
  local win = fw()
  if win and not undo[win:id()] then
    self[win:id()] = win:frame()
  end
end

function undo:pop()
  local win = fw()
  if win and self[win:id()] then
    win:setFrame(self[win:id()])
    self[win:id()] = nil
  end
end

windows.highlighActiveWin = function()
  local rect = hs.drawing.rectangle(fw():frame())
  rect:setStrokeColor({["red"]=1,  ["blue"]=0, ["green"]=1, ["alpha"]=1})
  rect:setStrokeWidth(5)
  rect:setFill(false)
  rect:show()
  hs.timer.doAfter(0.3, function() rect:delete() end)
end

windows.activateApp = function(appName)
  launchOrCycleFocus(appName)()
  local app = hs.application.find(appName)
  if app then
    app:activate()
    hs.timer.doAfter(0.1, windows.highlighActiveWin)
    app:unhide()
  end
end

windows.setMouseCursorAtApp = function(appTitle)
  local sf = hs.application.find(appTitle):findWindow(appTitle):frame()
  local desired_point = hs.geometry.point(sf._x + sf._w - (sf._w * 0.10), sf._y + sf._h - (sf._h * 0.10)) 
  hs.mouse.setAbsolutePosition(desired_point)
end
return windows
