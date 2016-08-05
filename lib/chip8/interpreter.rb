# frozen_string_literal: true

require 'sdl'

module Chip8
  class Interpreter
    SPRITE_OFFSET = 0

    STACK_OFFSET = SPRITE_OFFSET + Graphics::Sprites::STANDARD_SIZE * Graphics::Sprites::STANDARD.size

    PROGRAM_OFFSET = 0x200

    CPU_DELAY = 0.001

    DELAY_STEP = 0.001

    DELAY_STEP_MOD = 5

    def initialize(file)
      @log = Logging.get_logger 'interpreter'

      init_sdl
      init_memory

      @input = Chip8::Input.new
      @cpu = CPU::Processor.new @mem, STACK_OFFSET, @input

      @cpu_delay = CPU_DELAY

      load file
    end

    def load(file)
      @program = Program.new file

      offset = PROGRAM_OFFSET

      @program.each_as_array do |arr|
        @mem.write_array arr, offset
        offset += 2
      end

      @cpu.pc = PROGRAM_OFFSET
    end

    def start
      @last_tick = Time.now
      @cpu_thread = Thread.new { cpu_loop }
      sdl_loop
    end

    def disassemble(out)
      Disassembler.disassemble @program, out
    end

    def cpu_loop
      loop do
        elapsed = (Time.now - @last_tick) * 1000
        @cpu.tick elapsed
        @last_tick = Time.now
        sleep @cpu_delay
      end
    rescue => e
      @log.error 'CPU loop died with error'
      @log.error e
    end

    def sdl_loop
      loop do
        while event = SDL::Event.poll
          case event
          when SDL::Event::KeyDown
            exit if event.sym == SDL::Key::ESCAPE

            handled = @input.on_down event.sym

            break if handled

            shift = (event.mod & SDL::Key::MOD_LSHIFT) == SDL::Key::MOD_LSHIFT

            case event.sym
            when SDL::Key::F1
              mod_speed -DELAY_STEP * (shift ? DELAY_STEP_MOD : 1)
            when SDL::Key::F2
              mod_speed DELAY_STEP * (shift ? DELAY_STEP_MOD : 1)
            end
          when SDL::Event::KeyUp
            @input.on_up event.sym
          when SDL::Event::Quit
            exit
          end
        end

        sleep 0.016
      end
    end

    private

    def init_memory
      @mem = Chip8::Memory.new
      init_sprites
    end

    def init_sprites
      Graphics::Sprites::STANDARD.each_with_index do |sprite, index|
        mem_idx = SPRITE_OFFSET + index * Graphics::Sprites::STANDARD_SIZE
        @mem.write_sprite sprite, mem_idx
      end
    end

    def init_sdl
      SDL.init SDL::INIT_VIDEO | SDL::INIT_AUDIO
    end

    def mod_speed(amount)
      @cpu_delay += amount
      @cpu_delay = 0 if @cpu_delay < 0
      @log.info "CPU delay set to #{@cpu_delay}"
    end
  end
end
