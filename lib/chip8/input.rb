require 'sdl'

module Chip8
  class Input
    KEYMAP = {
      0x0 => SDL::Key::X,
      0x1 => SDL::Key::K1,
      0x2 => SDL::Key::K2,
      0x3 => SDL::Key::K3,
      0x4 => SDL::Key::Q,
      0x5 => SDL::Key::W,
      0x6 => SDL::Key::E,
      0x7 => SDL::Key::A,
      0x8 => SDL::Key::S,
      0x9 => SDL::Key::D,
      0xA => SDL::Key::Z,
      0xB => SDL::Key::C,
      0xC => SDL::Key::K4,
      0xD => SDL::Key::R,
      0xE => SDL::Key::F,
      0xF => SDL::Key::V
    }.freeze

    def initialize
      @state = {}
      @state.default = false
    end

    # Returns a value indicating whether the key with the specified
    # value is currently pressed down.
    def key_down?(value)
      @state[KEYMAP[value]]
    end

    # Blocks until a key is pressed and returns the value of the pressed key.
    def wait
      @key_event = Event.new
      @key_event.wait
      KEYMAP.key @last_key
    end

    def on_down(key)
      return false unless KEYMAP.value? key
      @state[key] = true
      @last_key = key
      ev = @key_event
      ev.set if ev
      true
    end

    def on_up(key)
      return false unless KEYMAP.value? key
      @state[key] = false
      true
    end
  end
end
