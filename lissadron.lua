-- lissadron                 
-- 
-- 
--      drone fields forever
-- 
-- 
--
-- @LFSaw            [20200227]
-- 
-- E1 fix amp 
-- E2 x
-- E3 y
-- K2 seed-1
-- K3 seed+1
-- K1 shift
-- <shift>-E1 tune 
-- <shift>-E2 seed-steps
-- <shift>-E3 seed-step frequency
-- <shift>-K2 randomise seed
-- <shift>-K3 seed+1
-- 
-- https://llllllll.co/t/haven/

engine.name = "Lissadron"

local state = {shift = false, lastTouchedCtl = nil, lastTouchedCounter = 0, lastTouchedClock_id = nil}

-- knobs and encoders
local kn = { k1=1, k2=2, k3=3 }
local en = { e1=1, e2=2, e3=3 }

local specs = {}
local viewport = { width = 128, height = 64, c_width = 64, c_height = 32, frame = 0, hilight = 15, lolight = 2 }




--- inits ----------------------------------

function init_ctls()
  makeSynthCtl("amp", -90, 0, "linear", 0.0, -50, "")
  makeSynthCtl("attack", 0.01, 2, "linear", 0.0, 0.05, "")
  makeSynthCtl("decay", 0, 2, "linear", 0.0, 1, "")
  makeSynthCtl("midiNote", 1, 110, "linear", 0.25, 43, "")
  makeSynthCtl("seed", 0, 18013, "linear", 1, 2020, "")
  params:add_separator()
  makeSynthCtl("x0", -1, 1, "linear", 0.0, 0, "")
  makeSynthCtl("x1", -1, 1, "linear", 0.0, 0, "")
  params:add_separator()
  makeCtl("slfoFreq", 1, 40,  "linear", 1, 1, "")
  makeCtl("slfoSteps", 1, 24, "linear", 1, 1)
  makeSynthCtl("lTime", 0.01, 3, "exp", 0, 0.1)
  makeSynthCtl("trigOnSeed", 0, 1, "linear", 1, 1, "")
  params:bang()
end

function init_screenTimer()
  local screen_timer = metro.init()
  screen_timer.time = 1 / 15
  screen_timer.event = function() redraw() end
  screen_timer:start()
end


--- sequencing ----------------------------------

local sequencer_id -- clock id for sequencer position
local seedOffset

function init_sequencer()
  seedOffset = 0
  sequencer_id = clock.run(sequencer)
end
  

function sequencer()
  while true do
    local lastOffset = seedOffset
    local steps = params:get("slfoSteps")
    local freq = 1/params:get("slfoFreq")
    print(freq)

    if (steps > 1) then
      seedOffset = (seedOffset + 1)%steps
    else 
      seedOffset = 0
      engine.seedOffset(seedOffset)
      -- sequencer_id = nil
      -- break
    end

    if lastOffset ~= seedOffset then
      engine.seedOffset(seedOffset)
    end
    clock.sync(freq)
  end
end

function clock.transport.start()
  if (sequencer_id ~= nil) then
    clock.cancel(sequencer_id)
  end
  print("clock-start")
  init_sequencer()
end

function clock.transport.stop()
  if sequencer_id ~= nil then
    clock.cancel(sequencer_id)
    sequencer_id = nil
    print("clock-stop")
  end
end



--- MIDI ----------------------------------
local midi_signal_in

function midi_connect()
  midi_signal_in = midi.connect(1)
  midi_signal_in.event = on_midi_event
end

function on_midi_event(data)
  msg = midi.to_msg(data)
  update_from_midi(msg)
  -- print(msg)
end

function update_from_midi(msg)
  if msg.type == 'note_on' then
    params:set("midiNote", msg.note)
    if (sequencer_id == nil) or (params:get("slfoSteps") == 1) then -- trigger if sequencer is not running
      engine.trig(1)
      print(msg.note)
      offFunc = function() 
        clock.sleep(0.01)
        engine.trig(0)
      end
      clock.run(offFunc)
    end
  end
  -- if msg.type == 'note_off' then
  --   engine.trig(0)
  -- end

  -- OP-1 fix for transport
  if msg.type == 'song_position' then
    clock.transport.start()
  end
  -- if msg.type == 'stop' then
  --   clock.transport.stop()
  -- end
  -- if msg.type == 'start' then
  --   clock.transport.start()
  -- end

  -- if msg.type ~= "clock" then
  --   print(msg.type)
  -- end
end

----------------------------------------------
function init()
  midi_connect()
  init_ctls()
  init_screenTimer()
  init_sequencer()
  screen.level(viewport.hilight)
  screen.line_width(1)
  screen.font_size(10)
end


--- drawing ----------------------------------

function draw_state(x, y, size, brightness, amp, lTime, x0, x1)
  -- screen.aa(0)
  screen.line_width(1)
  screen.level(math.random(1, brightness))
  local w = 1 + (size * x0)
  local h = 1 + (size * x1)
  screen.rect(x - (w/2), y - (h/2), w, h)
  screen.fill()
end

function draw_value(x, y, size, brightness, value)
  screen.level(brightness)
  screen.move(x, y)
  screen.aa(0)
  screen.font_size(size)
  screen.text_center(tostring(value))
end

function draw_params()
  amp = params:get_raw("amp")
  seed = params:get("seed")
  math.randomseed(seed)

  x0 = params:get_raw("x0")
  x1 = params:get_raw("x1")
  local slfoFreq = 1 - params:get_raw("slfoFreq")
  local slfoSteps = math.floor(params:get("slfoSteps"))
  local lTime = params:get_raw("lTime")

  -- amp visualisation?
  -- screen.aa(1)
  -- screen.circle(viewport.c_width, viewport.c_height, 1 + (amp * viewport.c_height * 0.8))
  -- screen.stroke()

  screen.aa(0)

  screen.level(math.random(1, 15))
  screen.rect(0, viewport.c_height, viewport.width, 14)
  screen.fill()
  screen.level(math.random(1, 15))
  screen.rect(0, viewport.c_height-14, viewport.width, 14)
  screen.fill()
  screen.level(math.floor(slfoFreq * 16))
  screen.rect(0, viewport.c_height-28, viewport.width, 14)
  screen.fill()

  slfoSteps = math.min(slfoSteps, 24) -- prevent too many objects to be drawn
  size = 10
  dt = viewport.width/slfoSteps
  for i=1,slfoSteps do
    draw_state(
      dt * i - (dt*0.5),
      viewport.c_height,
      size, 10,
      amp, lTime, x0, x1
    )
  end

  if state.lastTouchedCtl ~= nil then
    local val = params:get(state.lastTouchedCtl)
    draw_value(viewport.c_width/2, 12, 10, state.lastTouchedCounter, string.format("%.2f", val))
  end

end

function redraw()
  screen.clear()

  draw_params()

  -- print(state.lastTouchedCounter)

  screen.update()
end


--- knobs and pots ----------------------------------

function key(n, val)
  if n == kn.k1 then
    state.shift = (val == 1)
  end

  local seed = params:get("seed")
  if n == kn.k2 and val == 1 then
    if state.shift then
      params:set("seed", (seed-131) % 18013, false)
    else
      params:set("seed", seed-1, false)
    end
  elseif n == kn.k3 and val == 1 then
    if state.shift then
      params:set("seed", (seed+131) % 18013, false)
    else
      params:set("seed", seed+1, false)
    end
  end
end

function enc(n, delta)
  local delta = delta
  if n == en.e1 then
    if state.shift then 
      params:delta("midiNote", delta)
    else
      params:delta("amp", delta)
    end
  end    
  if n == en.e2 then
    if state.shift then 
      params:delta("slfoSteps", delta)
    else
      params:delta("x0", delta)
    end
  end
  if n == en.e3 then
    if state.shift then 
      params:delta("slfoFreq", delta)
    else
      params:delta("x1", delta)
    end
  end
end


--- helpers ----------------------------------

function makeSynthCtl(name, min, max, warp, default, start, label)
  local spec = controlspec.new(min, max, warp, default, start, label)
  specs[name] = spec


  local updateFunc = function(val) 
    state.lastTouchedCtl = name
    state.lastTouchedCounter = 16
    -- if state.lastTouchedClock_id ~=nil then
    --   clock.cancel(state.lastTouchedClock_id)
    -- end
    
    local viewReleaseFunc = function() 
      clock.sleep(0.5); 
      while state.lastTouchedCounter > 0 do
        state.lastTouchedCounter = state.lastTouchedCounter - 1
        clock.sleep(0.2); 
      end
      state.lastTouchedCtl = nil 
    end
    
    clock.run(viewReleaseFunc)
    engine[name](val) 
  end

  params:add{
    type="control",
    id=name,
    controlspec=spec,
    action=updateFunc
  }
end

function makeCtl(name, min, max, warp, default, start, label)
  local spec = controlspec.new(min, max, warp, default, start, label)
  specs[name] = spec

  local updateFunc = function(val) 
    state.lastTouchedCtl = name
    if state.lastTouchedClock_id ~=nil then
      clock.cancel(state.lastTouchedClock_id)
    end
    
    local viewReleaseFunc = function() 
      clock.sleep(0.5); 
      while state.lastTouchedCounter > 0 do
        state.lastTouchedCounter = state.lastTouchedCounter - 1
        clock.sleep(0.2); 
      end
      state.lastTouchedCtl = nil 
    end
    
    clock.run(viewReleaseFunc)
  end

  params:add{
    type="control",
    id=name,
    controlspec=spec,
    action=updateFunc
  }
end

