module Chip8
  module CPU
    class Processor
      PC_MASK = 0xFFFF

      # The timers should run at 60 Hz (16ms).
      TIMER_DELAY = 16

      OPCODES = [
        { mask: 0xFFFF, match: 0x00E0, type:  nil, handler: :cls },      # 00E0: CLS
        { mask: 0xFFFF, match: 0x00EE, type:  nil, handler: :ret },      # 00EE: RET
        { mask: 0xF000, match: 0x1000, type: :nnn, handler: :jp },       # 1nnn: JP   addr
        { mask: 0xF000, match: 0x2000, type: :nnn, handler: :call },     # 2nnn: CALL addr
        { mask: 0xF000, match: 0x3000, type: :xkk, handler: :se_b },     # 3xkk: SE     Vx, byte
        { mask: 0xF000, match: 0x4000, type: :xkk, handler: :sne_b },    # 4xkk: SNE    Vx, byte
        { mask: 0xF00F, match: 0x5000, type:  :xy, handler: :se_r },     # 5xy0: SE     Vx,   Vy
        { mask: 0xF000, match: 0x6000, type: :xkk, handler: :ld_b },     # 6xkk: LD     Vx, byte
        { mask: 0xF000, match: 0x7000, type: :xkk, handler: :add_b },    # 7xkk: ADD    Vx, byte
        { mask: 0xF00F, match: 0x8000, type:  :xy, handler: :ld_r },     # 8xy0: LD     Vx,   Vy
        { mask: 0xF00F, match: 0x8001, type:  :xy, handler: :or },       # 8xy1: OR     Vx,   Vy
        { mask: 0xF00F, match: 0x8002, type:  :xy, handler: :and },      # 8xy2: AND    Vx,   Vy
        { mask: 0xF00F, match: 0x8003, type:  :xy, handler: :xor },      # 8xy3: XOR    Vx,   Vy
        { mask: 0xF00F, match: 0x8004, type:  :xy, handler: :add_r },    # 8xy4: ADD    Vx,   Vy
        { mask: 0xF00F, match: 0x8005, type:  :xy, handler: :sub },      # 8xy5: SUB    Vx,   Vy
        { mask: 0xF00F, match: 0x8006, type:   :x, handler: :shr },      # 8xy6: SHR    Vx{, Vy}
        { mask: 0xF00F, match: 0x8007, type:  :xy, handler: :subn },     # 8xy7: SUBN   Vx,   Vy
        { mask: 0xF00F, match: 0x800E, type:   :x, handler: :shl },      # 8xyE: SHL    Vx{, Vy}
        { mask: 0xF00F, match: 0x9000, type:  :xy, handler: :sne_r },    # 9xy0: SNE    Vx,   Vy
        { mask: 0xF000, match: 0xA000, type: :nnn, handler: :ld_i },     # Annn: LD      I, addr
        { mask: 0xF000, match: 0xB000, type: :nnn, handler: :jp_0 },     # Bnnn: JP     V0, addr
        { mask: 0xF000, match: 0xC000, type: :xkk, handler: :rnd },      # Cxkk: RND    Vx, byte
        { mask: 0xF000, match: 0xD000, type: :xyn, handler: :drw },      # Dxyn: DRW    Vx,   Vy, nibble
        { mask: 0xF0FF, match: 0xE09E, type:   :x, handler: :skp },      # Ex9E: SKP    Vx
        { mask: 0xF0FF, match: 0xE0A1, type:   :x, handler: :sknp },     # ExA1: SKNP   Vx
        { mask: 0xF0FF, match: 0xF007, type:   :x, handler: :ld_dt_r },  # Fx07: LD     Vx,   DT
        { mask: 0xF0FF, match: 0xF00A, type:   :x, handler: :ld_k },     # Fx0A: LD     Vx,    K
        { mask: 0xF0FF, match: 0xF015, type:   :x, handler: :ld_dt_w },  # Fx15: LD     DT,   Vx
        { mask: 0xF0FF, match: 0xF018, type:   :x, handler: :ld_st },    # Fx18: LD     ST,   Vx
        { mask: 0xF0FF, match: 0xF01E, type:   :x, handler: :add_i },    # Fx1E: ADD     I,   Vx
        { mask: 0xF0FF, match: 0xF029, type:   :x, handler: :ld_f },     # Fx29: LD      F,   Vx
        { mask: 0xF0FF, match: 0xF033, type:   :x, handler: :ld_bcd },   # Fx33: LD      B,   Vx
        { mask: 0xF0FF, match: 0xF055, type:   :x, handler: :ld_arr_w }, # Fx55: LD    [I],   Vx
        { mask: 0xF0FF, match: 0xF065, type:   :x, handler: :ld_arr_r }  # Fx65: LD     Vx,  [I]
      ]

      DECODE_FUNCS = {
        nnn: -> (i) { [i & 0xFFF] },
        xkk: -> (i) { [(i >> 8) & 0xF, i & 0xFF] },
        x: -> (i) { [(i >> 8) & 0xF] },
        xy: -> (i) { [(i >> 8) & 0xF, (i >> 4) & 0xF] },
        xyn: -> (i) { [(i >> 8) & 0xF, (i >> 4) & 0xF, i & 0xF] }
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

      # Takes an instruction and a format type. The block is called
      # with the parameterse in the order they appear in the instruction.
      #
      # @param instruction [Fixnum] The instruction data.
      # @param type [:nnn, :xkk, :xy, :xyn] The parameter format of the
      #   instruction.
      # @yield [*params]
      def self.decode(instruction, type, &block)
        params = DECODE_FUNCS[type].call(instruction)
        pstr = params.is_a?(Array) ? params.map { |e| e.to_s(16) }.join(', ') : params.to_s(16)
        block ? block.call(*params) : params
      end

      def self.parse(instruction)
        #entry = OPCODE_MAP.find { |mask, _| (mask & instruction) == mask }
        entry = OPCODES.find { |e| (e[:mask] & instruction) == e[:match] }

        raise InstructionError.new(instruction) if entry.nil?

        entry
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
        meth = data[:handler]
        type = data[:type]
        type.nil? ? send(meth) : send(meth, *self.class.decode(instr, type))
      end

      # Clear the screen.
      def cls
        @display.clear
      end

      # Return from subroutine.
      def ret
        self.pc = @stack.pop
      end

      # Jump to an address.
      def jp(addr)
        self.pc = addr
      end

      # Call a subroutine. Like #jp except the current value
      # of @pc is pushed on stack to return later.
      def call(addr)
        @stack.push pc
        self.pc = addr
      end

      # Skip instruction if equal.
      #
      # #se_b compares a register with an immediate byte value,
      # and skips the next instruction if they are equal.
      def se_b(x, byte)
        increment_pc! if @regs[x] == byte
      end

      # Skip instruction if *not* equal.
      #
      # #sne_b compares a register with an immediate byte value,
      # and skips the next instruction if they are *not* equal.
      def sne_b(x, byte)
        increment_pc! if @regs[x] != byte
      end

      # Skip instruction if equal.
      #
      # #se_r compares two registers with eachother and skips the
      # next instruction if their contents are equal.
      def se_r(x, y)
        increment_pc! if @regs[x] == @regs[y]
      end

      # Load a byte value into a register.
      def ld_b(x, byte)
        @regs[x] = byte
      end

      # Adds a byte value to a register.
      def add_b(x, byte)
        @regs[x] += byte
      end

      # Copies the contents of a register into another.
      def ld_r(x, y)
        @regs[x] = @regs[y]
      end

      # Performs a bitwise OR on the contents of two registers.
      # The result is stored in the first register.
      def or(x, y)
        @regs[x] |= @regs[y]
      end

      # Performs a bitwise AND on the contents of two registers.
      # The result is stored in the first register.
      def and(x, y)
        @regs[x] &= @regs[y]
      end

      # Performs a bitwise exclusive OR on the contents of two registers.
      # The results is stored in the first register.
      def xor(x, y)
        @regs[x] ^= @regs[y]
      end

      # Adds the contents of two registers together and stores the
      # result in the first register. If the addition results in overflow,
      # VF is set to 1.
      def add_r(x, y)
        result = @regs[x] + @regs[y]
        @regs[0xF] = result > 255 ? 1 : 0
        @regs[x] = result
      end

      # Subtracts the contents of Vy from Vx and stores the result in Vx.
      # If Vx > Vy, VF is set to 1 (*NOT* borrow).
      def sub(x, y)
        result = @regs[x] - @regs[y]
        @regs[0xF] = result < 0 ? 0 : 1
        @regs[x] = result
      end

      # Shifts Vx right one bit. If the LSB was 1, VF is set to 1, otherwise
      # VF is set to 0.
      def shr(x)
        @regs[0xF] = @regs[x] & 0x1
        @regs[x] = @regs[x] >> 1
      end

      # Subtracts the contents of Vx from Vy and stores the result in Vx.
      # If Vy > Vx, VF is set to 1 (*NOT* borrow).
      def subn(x, y)
        result = @regs[y] - @regs[x]
        @regs[0xF] = result < 0 ? 0 : 1
        @regs[x] = result
      end

      # Shifts Vx left one bit. If the highest bit on Vx was set,
      # VF is set to 1.
      def shl(x)
        @regs[0xF] = (@regs[x] & 0x80) == 0x80 ? 1 : 0
        @regs[x] = @regs[x] << 1
      end

      # Skip if not equal.
      # If Vx is *not* equal to Vy, the next instruction is skipped.
      def sne_r(x, y)
        increment_pc! if @regs[x] != @regs[y]
      end

      # Sets the `I` register to an address value.
      def ld_i(addr)
        @regs.i = addr
      end

      # Jumps to `V0 + addr`, where `addr` is the argument to this
      # instruction.
      def jp_0(addr)
        self.pc = @regs[0x0] + addr
      end

      # Sets Vx to the result of performing a bitwise AND on a random byte
      # (between 0 and 255, inclusive) and the byte argument to this
      # instruction.
      def rnd(x, byte)
        @regs[x] = RNG.generate & byte
      end

      # Displays a sprite on screen.
      #
      # The sprite location must be loaded into the `I` register.
      # The `n` parameter of the interpreter is the size of the sprite.
      # The `x` and `y` parameters determine where on the screen to draw
      # the sprite.
      #
      # If a collision occurs with an already drawn sprite, VF is set to 1.
      def drw(x, y, nibble)
        data = @mem.read_array @regs.i, nibble
        sprite = Graphics::Sprite.new data
        collided = @display.draw_sprite sprite, @regs[x], @regs[y]
        @regs[0xF] = collided ? 1 : 0
      end

      # Skip next instruction if the key with value Vx is pressed.
      def skp(x)
        increment_pc! if @input.key_down? @regs[x]
      end

      # Skip next instruction if the key with value Vx is *not* pressed.
      def sknp(x)
        increment_pc! unless @input.key_down? @regs[x]
      end

      # Loads the value of the DT register into the Vx register.
      def ld_dt_r(x)
        @regs[x] = @regs.dt
      end

      # Blocks execution until a key is pressed, and then stores
      # the value of the pressed key in Vx.
      def ld_k(x)
        @regs[x] = @input.wait
      end

      # Copies the value in Vx into the DT register.
      def ld_dt_w(x)
        @regs.dt = @regs[x]
      end

      # Copies the value in Vx into the ST register.
      def ld_st(x)
        @regs.st = @regs[x]
      end

      # Adds the contents of Vx and the `I` register together and
      # stores the result in the `I` register.
      def add_i(x)
        @regs.i += @regs[x]
      end

      # Sets the value of register `I` to the address in memory that
      # contains the sprite data for digit Vx.
      def ld_f(x)
        offset = Interpreter::SPRITE_OFFSET
        size = Graphics::Sprites::STANDARD_SIZE
        @regs.i = offset + size * @regs[x]
      end

      # Store a BCD representation of Vx in memory locations
      # `I`, `I + 1`, and `I + 2`.
      def ld_bcd(x)
        value = @regs[x]
        @mem[@regs.i] = value / 100 # Hundreds
        @mem[@regs.i + 1] = (value % 100) / 10 # Tens
        @mem[@regs.i + 2] = value % 10 # "Ones"
      end

      # Store registers V0 through Vx in memory starting at the location
      # pointed to by register `I`.
      def ld_arr_w(x)
        (x + 1).times { |r| @mem[@regs.i + r] = @regs[r] }
      end

      # Load values into registers V0 through Vx by reading data
      # from memory starting at the address pointed to by register `I`.
      def ld_arr_r(x)
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
