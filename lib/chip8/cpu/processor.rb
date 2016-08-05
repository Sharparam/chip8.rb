module Chip8
  module CPU
    class Processor
      PC_MASK = 0xFFFF

      # The key in the map is a bitmask for the opcode,
      # the value is the method that will be called on Processor
      # for that opcode.
      #
      # When a method name is suffixed with `_b` or `_r`, it means
      # it has byte and register variants for one of its parameters.
      OPCODE_MAP = {
        # nnn/addr: 12-bit, lowest 12 bits
        # n/nibble:  4-bit, lowest 4 bits
        #        x:  4-bit, lower 4 bits of high byte
        #        y:  4-bit, upper 4 bits of low byte
        #  kk/byte:  8-bit, lowest 8 bits
        0x00E0 => :cls,      # 00E0: CLS
        0x00EE => :ret,      # 00EE: RET
        0x1FFF => :jp,       # 1nnn: JP   addr
        0x2FFF => :call,     # 2nnn: CALL addr
        0x3FFF => :se_b,     # 3xkk: SE     Vx, byte
        0x4FFF => :sne_b,    # 4xkk: SNE    Vx, byte
        0x5FF0 => :se_r,     # 5xy0: SE     Vx,   Vy
        0x6FFF => :ld_b,     # 6xkk: LD     Vx, byte
        0x7FFF => :add_b,    # 7xkk: ADD    Vx, byte
        0x8FF0 => :ld_r,     # 8xy0: LD     Vx,   Vy
        0x8FF1 => :or,       # 8xy1: OR     Vx,   Vy
        0x8FF2 => :and,      # 8xy2: AND    Vx,   Vy
        0x8FF3 => :xor,      # 8xy3: XOR    Vx,   Vy
        0x8FF4 => :add_r,    # 8xy4: ADD    Vx,   Vy
        0x8FF5 => :sub,      # 8xy5: SUB    Vx,   Vy
        0x8FF6 => :shr,      # 8xy6: SHR    Vx{, Vy}
        0x8FF7 => :subn,     # 8xy7: SUBN   Vx,   Vy
        0x8FFE => :shl,      # 8xyE: SHL    Vx{, Vy}
        0x9FF0 => :sne_r,    # 9xy0: SNE    Vx,   Vy
        0xAFFF => :ld_i,     # Annn: LD      I, addr
        0xBFFF => :jp_0,     # Bnnn: JP     V0, addr
        0xCFFF => :rnd,      # Cxkk: RND    Vx, byte
        0xDFFF => :drw,      # Dxyn: DRW    Vx,   Vy, nibble
        0xEF9E => :skp,      # Ex9E: SKP    Vx
        0xEFA1 => :sknp,     # ExA1: SKNP   Vx
        0xFF07 => :ld_dt_r,  # Fx07: LD     Vx,   DT
        0xFF0A => :ld_k,     # Fx0A: LD     Vx,    K
        0xFF15 => :ld_dt_w,  # Fx15: LD     DT,   Vx
        0xFF18 => :ld_st,    # Fx18: LD     ST,   Vx
        0xFF1E => :add_i,    # Fx1E: ADD     I,   Vx
        0xFF29 => :ld_f,     # Fx29: LD      F,   Vx
        0xFF33 => :ld_bcd,   # Fx33: LD      B,   Vx
        0xFF55 => :ld_arr_w, # Fx55: LD    [I],   Vx
        0xFF65 => :ld_arr_r  # Fx65: LD     Vx,  [I]
      }.freeze

      OPCODES = [
        { mask: 0xFFFF, match: 0x00E0, handler: :cls },      # 00E0: CLS
        { mask: 0xFFFF, match: 0x00EE, handler: :ret },      # 00EE: RET
        { mask: 0xF000, match: 0x1000, handler: :jp },       # 1nnn: JP   addr
        { mask: 0xF000, match: 0x2000, handler: :call },     # 2nnn: CALL addr
        { mask: 0xF000, match: 0x3000, handler: :se_b },     # 3xkk: SE     Vx, byte
        { mask: 0xF000, match: 0x4000, handler: :sne_b },    # 4xkk: SNE    Vx, byte
        { mask: 0xF00F, match: 0x5000, handler: :se_r },     # 5xy0: SE     Vx,   Vy
        { mask: 0xF000, match: 0x6000, handler: :ld_b },     # 6xkk: LD     Vx, byte
        { mask: 0xF000, match: 0x7000, handler: :add_b },    # 7xkk: ADD    Vx, byte
        { mask: 0xF00F, match: 0x8000, handler: :ld_r },     # 8xy0: LD     Vx,   Vy
        { mask: 0xF00F, match: 0x8001, handler: :or },       # 8xy1: OR     Vx,   Vy
        { mask: 0xF00F, match: 0x8002, handler: :and },      # 8xy2: AND    Vx,   Vy
        { mask: 0xF00F, match: 0x8003, handler: :xor },      # 8xy3: XOR    Vx,   Vy
        { mask: 0xF00F, match: 0x8004, handler: :add_r },    # 8xy4: ADD    Vx,   Vy
        { mask: 0xF00F, match: 0x8005, handler: :sub },      # 8xy5: SUB    Vx,   Vy
        { mask: 0xF00F, match: 0x8006, handler: :shr },      # 8xy6: SHR    Vx{, Vy}
        { mask: 0xF00F, match: 0x8007, handler: :subn },     # 8xy7: SUBN   Vx,   Vy
        { mask: 0xF00F, match: 0x800E, handler: :shl },      # 8xyE: SHL    Vx{, Vy}
        { mask: 0xF00F, match: 0x9000, handler: :sne_r },    # 9xy0: SNE    Vx,   Vy
        { mask: 0xF000, match: 0xA000, handler: :ld_i },     # Annn: LD      I, addr
        { mask: 0xF000, match: 0xB000, handler: :jp_0 },     # Bnnn: JP     V0, addr
        { mask: 0xF000, match: 0xC000, handler: :rnd },      # Cxkk: RND    Vx, byte
        { mask: 0xF000, match: 0xD000, handler: :drw },      # Dxyn: DRW    Vx,   Vy, nibble
        { mask: 0xF0FF, match: 0xE09E, handler: :skp },      # Ex9E: SKP    Vx
        { mask: 0xF0FF, match: 0xE0A1, handler: :sknp },     # ExA1: SKNP   Vx
        { mask: 0xF0FF, match: 0xF007, handler: :ld_dt_r },  # Fx07: LD     Vx,   DT
        { mask: 0xF0FF, match: 0xF00A, handler: :ld_k },     # Fx0A: LD     Vx,    K
        { mask: 0xF0FF, match: 0xF015, handler: :ld_dt_w },  # Fx15: LD     DT,   Vx
        { mask: 0xF0FF, match: 0xF018, handler: :ld_st },    # Fx18: LD     ST,   Vx
        { mask: 0xF0FF, match: 0xF01E, handler: :add_i },    # Fx1E: ADD     I,   Vx
        { mask: 0xF0FF, match: 0xF029, handler: :ld_f },     # Fx29: LD      F,   Vx
        { mask: 0xF0FF, match: 0xF033, handler: :ld_bcd },   # Fx33: LD      B,   Vx
        { mask: 0xF0FF, match: 0xF055, handler: :ld_arr_w }, # Fx55: LD    [I],   Vx
        { mask: 0xF0FF, match: 0xF065, handler: :ld_arr_r }  # Fx65: LD     Vx,  [I]
      ]

      DECODE_FUNCS = {
        nnn: -> (i) { [i & 0xFFF] },
        xkk: -> (i) { [(i >> 8) & 0xF, i & 0xFF] },
        x: -> (i) { (i >> 8) & 0xF },
        xy: -> (i) { [(i >> 8) & 0xF, (i >> 4) & 0xF] },
        xyn: -> (i) { [(i >> 8) & 0xF, (i >> 4) & 0xF, i & 0xF] }
      }.freeze

      attr_reader :pc

      def initialize(mem, stack_offset, input)
        @log = Logging.get_logger 'cpu'
        @regs = Registers.new
        @mem = mem
        @stack = Stack.new @mem, stack_offset
        @display = Graphics::Display.new
        @input = input
        @pc = 0
        @log.info 'CPU initialized'
      end

      def pc=(value)
        @pc = value & PC_MASK
      end

      def parse(instruction)
        #entry = OPCODE_MAP.find { |mask, _| (mask & instruction) == mask }
        entry = OPCODES.find { |e| (e[:mask] & instruction) == e[:match] }

        raise InstructionError.new(instruction) if entry.nil?

        meth = entry[:handler]

        raise UnsupportedInstructionError.new(instruction) unless self.respond_to? meth

        send meth, instruction
      end

      def tick
        @regs.tick
        instr = next_instr
        increment_pc!
        parse instr
      end

      # Clear the screen.
      def cls(instr)
        @display.clear
      end

      # Return from subroutine.
      def ret(instr)
        self.pc = @stack.pop
      end

      # Jump to an address.
      def jp(instr)
        decode(instr, :nnn) { |addr| self.pc = addr }
      end

      # Call a subroutine. Like #jp except the current value
      # of @pc is pushed on stack to return later.
      def call(instr)
        @stack.push pc
        decode(instr, :nnn) { |addr| self.pc = addr }
      end

      # Skip instruction if equal.
      #
      # #se_b compares a register with an immediate byte value,
      # and skips the next instruction if they are equal.
      def se_b(instr)
        decode(instr, :xkk) { |x, byte| increment_pc! if @regs[x] == byte }
      end

      # Skip instruction if *not* equal.
      #
      # #sne_b compares a register with an immediate byte value,
      # and skips the next instruction if they are *not* equal.
      def sne_b(instr)
        decode(instr, :xkk) { |x, byte| increment_pc! if @regs[x] != byte }
      end

      # Skip instruction if equal.
      #
      # #se_r compares two registers with eachother and skips the
      # next instruction if their contents are equal.
      def se_r(instr)
        decode(instr, :xy) { |x, y| increment_pc! if @regs[x] == @regs[y] }
      end

      # Load a byte value into a register.
      def ld_b(instr)
        decode(instr, :xkk) { |x, byte| @regs[x] = byte }
      end

      # Adds a byte value to a register.
      def add_b(instr)
        decode(instr, :xkk) { |x, byte | @regs[x] += byte }
      end

      # Copies the contents of a register into another.
      def ld_r(instr)
        decode(instr, :xy) { |x, y| @regs[x] = @regs[y] }
      end

      # Performs a bitwise OR on the contents of two registers.
      # The result is stored in the first register.
      def or(instr)
        decode(instr, :xy) { |x, y| @regs[x] |= @regs[y] }
      end

      # Performs a bitwise AND on the contents of two registers.
      # The result is stored in the first register.
      def and(instr)
        decode(instr, :xy) { |x, y| @regs[x] &= @regs[y] }
      end

      # Performs a bitwise exclusive OR on the contents of two registers.
      # The results is stored in the first register.
      def xor(instr)
        decode(instr, :xy) { |x, y| @regs[x] ^= @regs[y] }
      end

      # Adds the contents of two registers together and stores the
      # result in the first register. If the addition results in overflow,
      # VF is set to 1.
      def add_r(instr)
        x, y = decode(instr, :xy)
        result = @regs[x] + @regs[y]
        @regs[0xF] = result > 255 ? 1 : 0
        @regs[x] = result
      end

      # Subtracts the contents of Vy from Vx and stores the result in Vx.
      # If Vx > Vy, VF is set to 1 (*NOT* borrow).
      def sub(instr)
        x, y = decode(instr, :xy)
        result = @regs[x] - @regs[y]
        @regs[0xF] = result < 0 ? 0 : 1
        @regs[x] = result
      end

      # Shifts Vx right one bit. If the LSB was 1, VF is set to 1, otherwise
      # VF is set to 0.
      def shr(instr)
        x = decode(instr, :x)
        @regs[0xF] = @regs[x] & 0x1
        @regs[x] = @regs[x] >> 1
      end

      # Subtracts the contents of Vx from Vy and stores the result in Vx.
      # If Vy > Vx, VF is set to 1 (*NOT* borrow).
      def subn(instr)
        x, y = decode(instr, :xy)
        result = @regs[y] - @regs[x]
        @regs[0xF] = result < 0 ? 0 : 1
        @regs[x] = result
      end

      # Shifts Vx left one bit. If the highest bit on Vx was set,
      # VF is set to 1.
      def shl(instr)
        x = decode(instr, :x)
        @regs[0xF] = (@regs[x] & 0x80) == 0x80 ? 1 : 0
        @regs[x] = @regs[x] << 1
      end

      # Skip if not equal.
      # If Vx is *not* equal to Vy, the next instruction is skipped.
      def sne_r(instr)
        decode(instr, :xy) { |x, y| increment_pc! if @regs[x] != @regs[y] }
      end

      # Sets the `I` register to an address value.
      def ld_i(instr)
        decode(instr, :nnn) { |addr| @regs.i = addr }
      end

      # Jumps to `V0 + addr`, where `addr` is the argument to this
      # instruction.
      def jp_0(instr)
        decode(instr, :nnn) { |addr| self.pc = @regs[0x0] + addr }
      end

      # Sets Vx to the result of performing a bitwise AND on a random byte
      # (between 0 and 255, inclusive) and the byte argument to this
      # instruction.
      def rnd(instr)
        x, byte = decode(instr, :xkk)
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
      def drw(instr)
        x, y, nibble = decode(instr, :xyn)
        data = @mem.read_array @regs.i, nibble
        sprite = Graphics::Sprite.new data
        collided = @display.draw_sprite sprite, @regs[x], @regs[y]
        @regs[0xF] = collided ? 1 : 0
      end

      # Skip next instruction if the key with value Vx is pressed.
      def skp(instr)
        x = decode(instr, :x)
        increment_pc! if @input.key_down? @regs[x]
      end

      # Skip next instruction if the key with value Vx is *not* pressed.
      def sknp(instr)
        x = decode(instr, :x)
        increment_pc! unless @input.key_down? @regs[x]
      end

      # Loads the value of the DT register into the Vx register.
      def ld_dt_r(instr)
        decode(instr, :x) { |x| @regs[x] = @regs.dt }
      end

      # Blocks execution until a key is pressed, and then stores
      # the value of the pressed key in Vx.
      def ld_k(instr)
        decode(instr, :x) { |x| @regs[x] = @input.wait }
      end

      # Copies the value in Vx into the DT register.
      def ld_dt_w(instr)
        decode(instr, :x) { |x| @regs.dt = @regs[x] }
      end

      # Copies the value in Vx into the ST register.
      def ld_st(instr)
        decode(instr, :x) { |x| @regs.st = @regs[x] }
      end

      # Adds the contents of Vx and the `I` register together and
      # stores the result in the `I` register.
      def add_i(instr)
        decode(instr, :x) { |x| @regs.i += @regs[x] }
      end

      # Sets the value of register `I` to the address in memory that
      # contains the sprite data for digit Vx.
      def ld_f(instr)
        x = decode(instr, :x)
        offset = Interpreter::SPRITE_OFFSET
        size = Graphics::Sprites::STANDARD_SIZE
        @regs.i = offset + size * @regs[x]
      end

      # Store a BCD representation of Vx in memory locations
      # `I`, `I + 1`, and `I + 2`.
      def ld_bcd(instr)
        x = decode(instr, :x)
        value = @regs[x]
        @mem[@regs.i] = value / 100 # Hundreds
        @mem[@regs.i + 1] = (value % 100) / 10 # Tens
        @mem[@regs.i + 2] = value % 10 # "Ones"
      end

      # Store registers V0 through Vx in memory starting at the location
      # pointed to by register `I`.
      def ld_arr_w(instr)
        x = decode(instr, :x)
        (x + 1).times { |r| @mem[@regs.i + r] = @regs[r] }
      end

      # Load values into registers V0 through Vx by reading data
      # from memory starting at the address pointed to by register `I`.
      def ld_arr_r(instr)
        x = decode(instr, :x)
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

      # Takes an instruction and a format type. The block is called
      # with the parameterse in the order they appear in the instruction.
      #
      # @param instruction [Fixnum] The instruction data.
      # @param type [:nnn, :xkk, :xy, :xyn] The parameter format of the
      #   instruction.
      # @yield [*params]
      def decode(instruction, type, &block)
        params = DECODE_FUNCS[type].call(instruction)
        pstr = params.is_a?(Array) ? params.map { |e| e.to_s(16) }.join(', ') : params.to_s(16)
        block ? block.call(*params) : params
      end
    end
  end
end
