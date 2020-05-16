-- lissadron                 
-- 
-- 
--     seeding fields forever
-- 
-- 
--
-- @LFSaw             [20200516]
-- 
-- E1 amp -- legato
-- E2 x0  -- meta parameter
-- E3 x1  -- meta parameter
--
-- K2 seed--
-- K3 seed++
-- <shift>-K2 seed - 131
-- <shift>-K3 seed + 131
--
-- <shift>-E1 note 
-- <shift>-E2 seq_steps
-- <shift>-E3 seq_freq
-- 
-- K1 <shift>
--
-- additional parameters include 
-- control of euclidean 
-- sequencer patterns and 
-- lazyness of control updates
--
-- https://llllllll.co/t/lissadron/

engine.name = "Lissadron"

bjorklund = require "lissadron/lib/bjorklund"


state = {shift = false, last_touched_ctl = nil, last_touched_counter = 0, last_seed_offset = 0, seed_offset = 0, seq_pattern = nil}

-- knobs and encoders
local kn = { k1=1, k2=2, k3=3 }
local en = { e1=1, e2=2, e3=3 }

local specs = {}
local viewport = { width = 128, height = 64, c_width = 64, c_height = 32, frame = 0, hilight = 15, lolight = 2 }

local symbols = {"@", "*", "#", "-", "+", "\\", "/", "|", "«", "»", "≠", "$", "i", "!", "\'", "\"", "=", "0"}
local intFormats = {seed = 1, seq_steps = 1, seq_freq = 1, note = 1}

--- inits ----------------------------------

function init_ctls()
  make_synth_ctl("amp", -90, 0, "linear", 0.0, -90, "")
  make_synth_ctl("attack", 0.01, 0.8, "linear", 0.0, 0.02, "")
  make_synth_ctl("decay", 0, 1, "linear", 0.0, 0.3, "")
  make_seq_dependant_ctl("note", 0, 127, "linear", 0.25, 52, "")
  make_seq_dependant_ctl("seed", 0, 16383, "linear", 1, 3079, "") -- 14bit
  params:add_separator()
  make_synth_ctl("x0", 0, 1, "linear", 0.0, 0.5, "")
  make_synth_ctl("x1", 0, 1, "linear", 0.0, 0.5, "")
  params:add_separator()
  make_ctl("seq_freq", 1, 40,  "linear", 1, 1, "")
  make_ctl("seq_steps", 1, 24, "linear", 1, 1)
  -- make_ctl("seq_pulses", 1, 24, "linear", 1, 24)
  make_ctl("seq_fill", 0, 1, "linear", 0, 1)
  make_ctl("seq_shift", 0, 1, "linear", 0, 0)
  make_synth_ctl("lazy", 0.01, 1, "exp", 0.0, 0.1)
  make_synth_ctl("trigOnSeed", 0, 1, "linear", 1, 1, "")
  params:bang()
end

function init_screenTimer()
  local screen_timer = metro.init()
  screen_timer.time = 1 / 15
  screen_timer.event = function() redraw() end
  screen_timer:start()

  local releaseFunc = function () 
    while true do
      if state.last_touched_counter > 0 then
        state.last_touched_counter = state.last_touched_counter - 1
      end
      -- print(state.last_touched_counter)
      clock.sleep(0.1); 
    end
  end
  
  state.last_touched_counter = 0
  clock.run(releaseFunc)
end


--- sequencing ----------------------------------

local seq_id -- clock id for sequencer position

function init_seq()
  state.seed_offset = -1

  update_seq_pattern()
  -- state.seq_pattern = bjorklund.bjorklund(1, 1, 0)
  seq_id = clock.run(sequencer)
end
  

function sequencer()
  while true do
    local steps = params:get("seq_steps")
    local freq  = 1/params:get("seq_freq")

    if (steps > 1) then
      update_seq_pattern()
      state.last_seed_offset = state.seed_offset
      state.seed_offset = (state.seed_offset + 1)%steps
    else 
      state.seed_offset = 0
      state.last_seed_offset = 0
      engine.seedOffset(0)
      -- seq_id = nil
      -- break
    end

    
    if (state.last_seed_offset ~= state.seed_offset) then
      if (state.seq_pattern[state.seed_offset+1] == 1) then
        -- print(state.seed_offset)
        engine.note(params:get("note"))
        engine.seed(params:get("seed"))
        engine.trig(1)
        engine.seedOffset(state.seed_offset)
        local offFunc = function() 
          clock.sleep(0.01)
          engine.trig(0)
        end
        clock.run(offFunc)
      end
    end

    redraw()
    clock.sync(freq)
  end
end

function clock.transport.start()
  if (seq_id ~= nil) then
    clock.cancel(seq_id)
  end
  print("clock-start")
  init_seq()
end

function clock.transport.stop()
  if seq_id ~= nil then
    clock.cancel(seq_id)
    seq_id = nil
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
    params:set("note", msg.note)
    if (seq_id == nil) or (params:get("seq_steps") == 1) then -- trigger if sequencer is not running
      engine.trig(1)
      -- print(msg.note)
      local offFunc = function() 
        clock.sleep(0.01)
        engine.trig(0)
      end
      clock.run(offFunc)
    end
  end

  -- OP-1 fix for transport
  if msg.type == 'song_position' then
    clock.transport.start()
  end
end

----------------------------------------------
function init()
  midi_connect()
  init_ctls()
  init_screenTimer()
  init_seq()
  screen.level(viewport.hilight)
  screen.line_width(1)
  screen.font_size(10)
end


--- drawing ----------------------------------

function draw_xy(x, y, size, brightness, x0, x1)
  local w = x0 * (size-4)
  local h = x1 * (size-4)

  screen.level(brightness)
  screen.line_width(1)
  screen.rect(x, y, size, size)
  screen.stroke()
  screen.rect(x + w + 1, y + size - h - 3, 1, 1)
  screen.fill()
end

function draw_state(x, y, size, brightness, amp, lazy, x0, x1, selected, seed)
  -- screen.aa(0)
  math.randomseed(seed)

  screen.line_width(1)
  local level
  level = math.random(1, math.max(1, brightness))

  local w
  local h
  if math.random() >= 0.5 then
    w = math.random(1, math.floor(size * (x0 + 1)))
    h = math.random(1, math.floor(size * (x1 + 1)))
  else
    h = math.random(1, math.floor(size * (x0 + 1)))
    w = math.random(1, math.floor(size * (x1 + 1)))
  end

  -- -- sequencer cursor
  -- if selected then
  --   screen.level(16)
  --   screen.rect(x - 0.5, y-(size/2)-2, 1, 1)
  --   screen.rect(x - 0.5, y+(size/2), 1, 1)
  --   screen.fill()
  -- end

  -- element
  if brightness > 0 then
    screen.level(level)
    screen.rect(x - (w/2), y - (h/2), w, h)
    screen.fill()

    -- screen.aa(1)
    local f_size = math.random(5, 20)
    screen.move(x-1, y - 20 + (f_size/2))
    screen.font_size(f_size)
    if selected then
      screen.level(16)
    else  
      screen.level(math.max(2, 12-level))
    end
    screen.text_center(symbols[math.random(1, #symbols)])
    -- screen.aa(0)
  end

end

function draw_value(x, y, size, brightness, value)
  screen.level(brightness)
  screen.move(x, y)
  screen.aa(0)
  screen.font_size(size)
  screen.text(tostring(value))
end


-- draw everything
function draw_params()
  local amp = params:get_raw("amp")
  local seed = params:get("seed")
  local x0 = params:get_raw("x0")
  local x1 = params:get_raw("x1")
  local seq_freq = 1 - params:get_raw("seq_freq")
  local seq_steps = params:get("seq_steps")
  local lazy = params:get_raw("lazy")

  math.randomseed(seed)

  screen.aa(0)

  -- screen.level(math.random(1, 15))
  -- screen.rect(0, viewport.c_height, viewport.width, 14)
  -- screen.fill()
  -- screen.level(math.random(1, 15))
  -- screen.rect(0, viewport.c_height-14, viewport.width, 14)
  -- screen.fill()
  -- screen.level(math.floor((1-seq_freq) * 16))
  -- screen.rect(0, viewport.c_height-28, viewport.width, 14)
  -- screen.fill()

  -- screen.level(5)
  -- screen.rect(0, viewport.c_height, viewport.width, 1)
  -- screen.fill()

  seq_steps = math.min(seq_steps, 24) -- prevent too many objects to be drawn
  local size = 10
  local dt = viewport.width/seq_steps
  if seq_steps > 1 then
    -- make sure to have the right pattern size
    if #state.seq_pattern ~= seq_steps then
      update_seq_pattern()
    end

    for i=1,seq_steps do
      if state.seq_pattern[i] > 0 then
        draw_state(
          dt * i - (dt*0.5),
          viewport.c_height,
          size, 16,
          amp, lazy, x0, x1, ((state.seed_offset+1) == i),
          seed + (i-1)
        )
      else
        draw_state(
          dt * i - (dt*0.5),
          viewport.c_height,
          size, 0,
          amp, lazy, x0, x1, ((state.seed_offset+1) == i),
          seed + (i-1)
        )
      end
      -- draw_value(
      --   dt * i - (dt*0.5),
      --   viewport.c_height,
      --   size, 16,
      --   i
      -- )

    end
  else
      draw_state(
        dt/2,
        viewport.c_height,
        size, 16,
        amp, lazy, x0, x1, false,
        seed
      )
  end

  draw_xy(viewport.width - 14, viewport.height - 14, 10, 16, x0, x1)

  if state.last_touched_counter > 0 then
    local val = params:get(state.last_touched_ctl)
    if intFormats[state.last_touched_ctl] == nil then
      val = string.format("%.3f", val)
    else
      val = string.format("%i", math.floor(val))
    end
    local brightness = math.min(state.last_touched_counter, 16)
    draw_value(5               , viewport.height - 7, 10, brightness, val)
    draw_value(viewport.c_width - 10, viewport.height - 7, 10, brightness, state.last_touched_ctl)
  end
end






function redraw()
  screen.clear()
  draw_params()
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
      params:delta("note", delta)
    else
      params:delta("amp", delta)
    end
  end    
  if n == en.e2 then
    if state.shift then 
      params:delta("seq_steps", delta)
    else
      params:delta("x0", delta)
    end
  end
  if n == en.e3 then
    if state.shift then 
      params:delta("seq_freq", delta)
    else
      params:delta("x1", delta)
    end
  end
end


--- helpers ----------------------------------

function make_synth_ctl(name, min, max, warp, default, start, label)
  local spec = controlspec.new(min, max, warp, default, start, label)
  specs[name] = spec

  local update_func = function(val) 
    state.last_touched_ctl = name
    state.last_touched_counter = 32
    engine[name](val) 
  end

  params:add{
    type="control",
    id=name,
    controlspec=spec,
    action=update_func
  }
end

function make_seq_dependant_ctl(name, min, max, warp, default, start, label)
  local spec = controlspec.new(min, max, warp, default, start, label)
  specs[name] = spec

  local update_func = function(val) 
    state.last_touched_ctl = name
    state.last_touched_counter = 32
    if ( ((params:get("seq_steps") < 2) or (seq_id == nil)) ) then -- only update if sequencer is not running
      engine[name](val) 
    end
  end

  params:add{
    type="control",
    id=name,
    controlspec=spec,
    action=update_func
  }
end

function update_seq_pattern()
    local steps = params:get("seq_steps")
    state.seq_pattern = bjorklund.bjorklund(steps, math.max(1, math.ceil(params:get("seq_fill") * steps)), math.floor(params:get("seq_shift") * (steps-1)))
end

function make_ctl(name, min, max, warp, default, start, label)
  local spec = controlspec.new(min, max, warp, default, start, label)
  specs[name] = spec

  local update_func = function(val) 
    state.last_touched_ctl = name
    state.last_touched_counter = 32
    update_seq_pattern()

    -- engine[name](val) 
  end

  params:add{
    type="control",
    id=name,
    controlspec=spec,
    action=update_func
  }
end

