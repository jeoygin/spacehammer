local multimedia = {}

multimedia.mKey = function (key)
  return function()
    hs.eventtap.event.newSystemKeyEvent(string.upper(key), true):post()
    hs.timer.usleep(5)
    hs.eventtap.event.newSystemKeyEvent(string.upper(key), false):post()
  end
end

multimedia.bind = function(modal, fsm)
  modal:bind("", "a", function()
               hs.application.launchOrFocus("Google Play Music Desktop Player")
               fsm:toIdle()
  end)
  modal:bind("", "h", function() multimedia.mKey("previous")(); fsm:toIdle() end)
  modal:bind("", "l", function() multimedia.mKey("next")(); fsm:toIdle() end)
  local sUp = multimedia.mKey("sound_up")
  modal:bind("", "k", sUp, nil, sUp)
  local sDn = multimedia.mKey("sound_down")
  modal:bind("", "j", sDn, nil, sDn)
  local pl = function() multimedia.mKey("play")(); fsm:toIdle() end
  modal:bind("", "p", pl)
end

return multimedia
