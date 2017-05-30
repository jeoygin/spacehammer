require "preload"
local machine = require "statemachine"
local windows = require "windows"
local slack = require "slack"
local multimedia = require "multimedia"

require "preview-app"
require "caffeine"

local displayModalText = function(txt)
  hs.alert.closeAll()
  alert(txt, 999999)
end

allowedApps = {"Emacs", "iTerm2"}
hs.hints.showTitleThresh = 4
hs.hints.titleMaxSize = 10
hs.hints.fontSize = 30
hs.hints.hintChars = {"S","A","D","F","J","K","L","E","W","C","M","P","G","H"}

local filterAllowedApps = function(w)
  if (not w:isStandard()) and (not utils.contains(allowedApps, w:application():name())) then
    return false;
  end
  return true;
end

modals = {
  main = {
    init = function(self, fsm) 
      if self.modal then
        self.modal:enter()
      else
        self.modal = hs.hotkey.modal.new({"cmd"}, "space")
      end
      self.modal:bind("","space", nil, function() fsm:toIdle(); windows.activateApp("Alfred 3") end)
      self.modal:bind("","w", nil, function() fsm:toWindows() end)
      self.modal:bind("","a", nil, function() fsm:toApps() end)
      self.modal:bind("", "m", nil, function() fsm:toMedia() end)
      self.modal:bind("","j", nil, function()
                        local wns = hs.fnutils.filter(hs.window.allWindows(), filterAllowedApps)
                        hs.hints.windowHints(wns, nil, true)
                        fsm:toIdle()
      end)
      self.modal:bind("", "r", nil, function() hs.reload() end)
      self.modal:bind("","escape", function() fsm:toIdle() end)
      function self.modal:entered() displayModalText "w \t- windows\na \t- apps\n j \t- jump\nm - media\nr \t- reload" end
    end 
  },
  windows = {
    init = function(self, fsm)
      self.modal = hs.hotkey.modal.new()
      displayModalText "cmd + hjkl \t jumping\nhjkl \t\t\t\t halves\nalt + hjkl \t\t increments\nshift + hjkl \t resize\nn, p \t\t\t\t next, prev screen\ng \t\t\t\t\t grid\nm \t\t\t\t maximize\nf \t\t\t\t\t full screen\nc \t\t\t\t\t center\nu \t\t\t\t\t undo"
      self.modal:bind("","escape", function() fsm:toIdle() end)
      self.modal:bind({"cmd"}, "space", nil, function() fsm:toIdle(); fsm:toMain() end)
      windows.bind(self.modal, fsm)
      self.modal:enter()
    end
  },
  apps = {
    init = function(self, fsm)
      self.modal = hs.hotkey.modal.new()
      displayModalText "e \t emacs\nc \t chrome\nt \t terminal\ns \t slack\nb \t brave\nw \t 企业微信\nq \t QQ\nm  NeteaseMusic"
      self.modal:bind("","escape", function() fsm:toIdle() end)
      self.modal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)
      hs.fnutils.each({
          { key = "t", app = "iTerm2" },
          { key = "c", app = "Google Chrome" },
          { key = "b", app = "Brave" },
          { key = "e", app = "Emacs" },
          { key = "f", app = "Finder" },
          { key = "w", app = "企业微信" },
          { key = "q", app = "QQ" },
          { key = "m", app = "NeteaseMusic" },
          { key = "g", app = "Gitter" }}, function(item)

          self.modal:bind("", item.key, function() windows.activateApp(item.app); fsm:toIdle()  end)
      end)

      slack.bind(self.modal, fsm)

      self.modal:enter()
    end
  },
  media = {
    init = function(self, fsm)
      self.modal = hs.hotkey.modal.new()
      displayModalText "h \t previous track\nl \t next track\nk \t volume up\nj \t volume down\np \t play/pause\na \t launch player"

      self.modal:bind("","escape", function() fsm:toIdle() end)
      self.modal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)

      multimedia.bind(self.modal, fsm)
      self.modal:enter()
    end
  }
}

local initModal = function(state, fsm)
  local m = modals[state]
  m.init(m, fsm)
end

exitAllModals = function()
  utils.each(modals, function(m)
               if m.modal then
                 m.modal:exit()
               end
  end)
end

local fsm = machine.create({
    initial = "idle",
    events = {
      { name = "toIdle",    from = "*", to = "idle" },
      { name = "toMain",    from = '*', to = "main" },
      { name = "toWindows", from = {'main','idle'}, to = "windows" },
      { name = "toApps",    from = {'main', 'idle'}, to = "apps" },
      { name = "toMedia",   from = {'main', 'idle'}, to = "media" }
    },
    callbacks = {
      onidle = function(self, event, from, to)
        hs.alert.closeAll()
        exitAllModals()
      end,
      onmain = function(self, event, from, to)
        -- modals[from].modal:exit()
        initModal(to, self)
      end,
      onwindows = function(self, event, from, to)
        -- modals[from].modal:exit()
        initModal(to, self)
      end,
      onapps = function(self, event, from, to)
        -- modals[from].modal:exit()
        initModal(to, self)
      end,
      onmedia = function(self, event, from, to)
        initModal(to, self)
      end,
    }
})

switcher = hs.window.switcher.new(hs.window.filter.new():setCurrentSpace(true):setDefaultFilter())

hs.hotkey.bind('alt', 'tab' , function() switcher:next() end)

fsm:toMain()

hs.alert.show("Config Loaded")
