module Chip8
  module CPU
    class Processor
      PC_MASK = 0xFFFF

      # The timers should run at 60 Hz (16ms).
      TIMER_DELAY = 16

      PARAM_MASKS = {
        nnn: 0x0FFF,
        n:   0x000F,
        kk:  0x00FF,
        x:   0x0F00,
        y:   0x00F0
      }.freeze

      DECODE_FUNCS = {
        nnn: -> (i) { i & 0xFFF },
        n: -> (i) { i & 0xF },
        kk: -> (i) { i & 0xFF },
        x: -> (i) { (i >> 8) & 0xF },
        y: -> (i) { (i >> 4) & 0xF }
      }.freeze

      attr_reader :pc

      def initialize(mem, stack_offset, input)
        @log = Logging.get_logger 'cpu'
        @log.info 'Initializing CPU'
        @regs = Registers.new
        @mem = mem
        @stack = Stack.new @mem, stack_offset
        @display = Graphics::Display.new
        @input = input
        @pc = 0
        @elapsed = 0
        @log.info 'CPU initialized'
      end

      def pc=(value)
        @pc = value & PC_MASK
      end

      def self.decode(instruction, params)
        params.map { |p| DECODE_FUNCS[p].call(instruction) }
      end

      def self.parse(instruction)
        raise InstructionError.new(instruction) if @instructions.nil?

        entry = @instructions.find do |id, data|
          (data[:mask] & instruction) == id
        end

        raise InstructionError.new(instruction) if entry.nil?

        entry.last
      end

      def self.instruction(id, *args, &block)
        (@instructions ||= {})[id] = {
          mask: 0xFFFF & ~(args.reduce(0) { |a, e| a |= PARAM_MASKS[e] }),
          params: args,
          handler: block
        }
      end

      def tick(elapsed)
        @elapsed += elapsed

        if @elapsed >= TIMER_DELAY
          @regs.tick
          @elapsed -= TIMER_DELAY
        end

        if @regs.st > 0
          Audio.start unless Audio.playing?
        else
          Audio.stop if Audio.playing?
        end

        instr = next_instr
        increment_pc!
        data = self.class.parse instr
        instance_exec(*self.class.decode(instr, data[:params]), &data[:handler])
      end

      # Clear the screen.
      instruction(0x00E0) { @display.clear }

      # Return from subroutine.
      instruction(0x00EE) { self.pc = @stack.pop }

      # Jump to an address.
      instruction(0x1000, :nnn) { |addr| self.pc = addr }

      # Call a subroutine. Like #jp except the current value
      # of @pc is pushed on stack to return later.
      instruction 0x2000, :nnn do |addr|
        @stack.push self.pc
        self.pc = addr
      end

      # Skip instruction if equal.
      #
      # #se_b compares a register with an immediate byte value,
      # and skips the next instruction if they are equal.
      instruction 0x3000, :x, :kk do |x, byte|
        increment_pc! if @regs[x] == byte
      end

      # Skip instruction if *not* equal.
      #
      # #sne_b compares a register with an immediate byte value,
      # and skips the next instruction if they are *not* equal.
      instruction 0x4000, :x, :kk do |x, byte|
        increment_pc! if @regs[x] != byte
      end

      # Skip instruction if equal.
      #
      # #se_r compares two registers with eachother and skips the
      # next instruction if their contents are equal.
      instruction 0x5000, :x, :y do |x, y|
        increment_pc! if @regs[x] == @regs[y]
      end

      # Load a byte value into a register.
      instruction(0x6000, :x, :kk) { |x, byte| @regs[x] = byte }

      # Adds a byte value to a register.
      instruction(0x7000, :x, :kk) { |x, byte| @regs[x] += byte }

      # Copies the contents of a register into another.
      instruction(0x8000, :x, :y) { |x, y| @regs[x] = @regs[y] }

      # Performs a bitwise OR on the contents of two registers.
      # The result is stored in the first register.
      instruction(0x8001, :x, :y) { |x, y| @regs[x] |= @regs[y] }

      # Performs a bitwise AND on the contents of two registers.
      # The result is stored in the first register.
      instruction(0x8002, :x, :y) { |x, y| @regs[x] &= @regs[y] }

      # Performs a bitwise exclusive OR on the contents of two registers.
      # The results is stored in the first register.
      instruction(0x8003, :x, :y) { |x, y| @regs[x] ^= @regs[y] }

      # Adds the contents of two registers together and stores the
      # result in the first register. If the addition results in overflow,
      # VF is set to 1.
      instruction 0x8004, :x, :y do |x, y|
        result = @regs[x] + @regs[y]
        @regs[0xF] = result > 255 ? 1 : 0
        @regs[x] = result
      end

      # Subtracts the contents of Vy from Vx and stores the result in Vx.
      # If Vx > Vy, VF is set to 1 (*NOT* borrow).
      instruction 0x8005, :x, :y do |x, y|
        result = @regs[x] - @regs[y]
        @regs[0xF] = result < 0 ? 0 : 1
        @regs[x] = result
      end

      # Shifts Vx right one bit. If the LSB was 1, VF is set to 1, otherwise
      # VF is set to 0.
      instruction 0x8006, :x do |x|
        @regs[0xF] = @regs[x] & 0x1
        @regs[x] = @regs[x] >> 1
      end

      # Subtracts the contents of Vx from Vy and stores the result in Vx.
      # If Vy > Vx, VF is set to 1 (*NOT* borrow).
      instruction 0x8007, :x, :y do |x, y|
        result = @regs[y] - @regs[x]
        @regs[0xF] = result < 0 ? 0 : 1
      end

      # Shifts Vx left one bit. If the highest bit on Vx was set,
      # VF is set to 1.
      instruction 0x800E, :x do |x|
        @regs[0xF] = (@regs[x] & 0x80) == 0x80 ? 1 : 0
        @regs[x] = @regs[x] << 1
      end

      # Skip if not equal.
      # If Vx is *not* equal to Vy, the next instruction is skipped.
      instruction(0x9000, :x, :y) { |x, y| increment_pc! if @regs[x] != @regs[y] }

      # Sets the `I` register to an address value.
      instruction(0xA000, :nnn) { |addr| @regs.i = addr }

      # Jumps to `V0 + addr`, where `addr` is the argument to this
      # instruction.
      instruction(0xB000, :nnn) { |addr| self.pc = @regs[0x0] + addr }

      # Sets Vx to the result of performing a bitwise AND on a random byte
      # (between 0 and 255, inclusive) and the byte argument to this
      # instruction.
      instruction(0xC000, :x, :kk) { |x, byte| @regs[x] = RNG.generate & byte }

      # Displays a sprite on screen.
      #
      # The sprite location must be loaded into the `I` register.
      # The `n` parameter of the interpreter is the size of the sprite.
      # The `x` and `y` parameters determine where on the screen to draw
      # the sprite.
      #
      # If a collision occurs with an already drawn sprite, VF is set to 1.
      instruction 0xD000, :x, :y, :n do |x, y, nibble|
        data = @mem.read_array @regs.i, nibble
        sprite = Graphics::Sprite.new data
        collided = @display.draw_sprite sprite, @regs[x], @regs[y]
        @regs[0xF] = collided ? 1 : 0
      end

      # Skip next instruction if the key with value Vx is pressed.
      instruction(0xE09E, :x) { |x| increment_pc! if @input.key_down? @regs[x] }

      # Skip next instruction if the key with value Vx is *not* pressed.
      instruction(0xE0A1, :x) { |x| increment_pc! unless @input.key_down? @regs[x] }

      # Loads the value of the DT register into the Vx register.
      instruction(0xF007, :x) { |x| @regs[x] = @regs.dt }

      # Blocks execution until a key is pressed, and then stores
      # the value of the pressed key in Vx.
      instruction(0xF00A, :x) { |x| @regs[x] = @input.wait }

      # Copies the value in Vx into the DT register.
      instruction(0xF015, :x) { |x| @regs.dt = @regs[x] }

      # Copies the value in Vx into the ST register.
      instruction(0xF018, :x) { |x| @regs.st = @regs[x] }

      # Adds the contents of Vx and the `I` register together and
      # stores the result in the `I` register.
      instruction(0xF01E, :x) { |x| @regs.i += @regs[x] }

      # Sets the value of register `I` to the address in memory that
      # contains the sprite data for digit Vx.
      instruction 0xF029, :x do |x|
        offset = Interpreter::SPRITE_OFFSET
        size = Graphics::Sprites::STANDARD_SIZE
        @regs.i = offset + size * @regs[x]
      end

      # Store a BCD representation of Vx in memory locations
      # `I`, `I + 1`, and `I + 2`.
      instruction 0xF033, :x do |x|
        value = @regs[x]
        @mem[@regs.i] = value / 100 # Hundreds
        @mem[@regs.i + 1] = (value % 100) / 10 # Tens
        @mem[@regs.i + 2] = value % 10 # "Ones"
      end

      # Store registers V0 through Vx in memory starting at the location
      # pointed to by register `I`.
      instruction 0xF055, :x do |x|
        (x + 1).times { |r| @mem[@regs.i + r] = @regs[r] }
      end

      # Load values into registers V0 through Vx by reading data
      # from memory starting at the address pointed to by register `I`.
      instruction 0xF065, :x do |x|
        (x + 1).times { |r| @regs[r] = @mem[@regs.i + r] }
      end

      private

      def next_instr
        arr = @mem.read_array @pc, CPU::INSTRUCTION_SIZE
        (arr[0] << 8) | arr[1]
      end

      def increment_pc!
        @pc += CPU::INSTRUCTION_SIZE
      end
    end
  end
end
