# frozen_string_literal: true

require 'sdl'

module Chip8
  class Interpreter
    SPRITE_OFFSET = 0

    STACK_OFFSET = SPRITE_OFFSET + Graphics::Sprites::STANDARD_SIZE * Graphics::Sprites::STANDARD.size

    PROGRAM_OFFSET = 0x200

    CPU_DELAY = 0.016

    def initialize(file)
      @log = Logging.get_logger 'interpreter'

      init_sdl
      init_memory

      @input = Chip8::Input.new
      @cpu = CPU::Processor.new @mem, STACK_OFFSET, @input

      load file
    end

    def load(file)
      program = Program.new file

      offset = PROGRAM_OFFSET

      program.each_as_array do |arr|
        @mem.write_array arr, offset
        offset += 2
      end

      @cpu.pc = PROGRAM_OFFSET
    end

    def start
      @cpu_thread = Thread.new { cpu_loop }
      sdl_loop
    end

    def cpu_loop
      loop do
        @cpu.tick
        sleep CPU_DELAY
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

            @input.on_down event.sym
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
  end
end
