# frozen_string_literal: true

module Chip8
  module Disassembler
    class << self
      def disassemble(program, out)
        log.info "Disassembling #{program.path} to #{out}"

        asm = []
        pos = 0x200

        program.each do |instruction|
          line = StringIO.new
          line << "#{pos.to_s(16)} "

          begin
            data = CPU::Processor.parse instruction

            parts = data[:handler].to_s.split('_')
            func = parts.first.upcase
            suffix = parts.last

            line << func

            if data[:type]
              line << ' '

              params = CPU::Processor.decode instruction, data[:type]

              case data[:type]
              when :nnn
                case suffix
                when '0'
                  fstr = 'V0, 0x%03x'
                when 'i'
                  fstr = 'I, 0x%03x'
                else
                  fstr = '0x%03x'
                end
              when :xkk
                fstr = 'V%x, 0x%02x'
              when :xyn
                fstr = 'V%x, V%x, 0x%x'
              when :xy
                fstr = 'V%x, V%x'
              when :x
                case data[:handler]
                when :ld_dt_r
                  fstr = 'V%x, DT'
                when :ld_k
                  fstr = 'V%x, K'
                when :ld_dt_w
                  fstr = 'DT, V%x'
                when :ld_st
                  fstr = 'ST, V%x'
                when :add_i
                  fstr = 'I, V%x'
                when :ld_f
                  fstr = 'F, V%x'
                when :ld_b
                  fstr = 'B, V%x'
                when :ld_arr_w
                  fstr = '[I], V%x'
                when :ld_arr_r
                  fstr = 'V%x, [I]'
                else
                  fstr = 'V%x'
                end
              end

              line << format(fstr, *params)
            end
          rescue InstructionError
            # This means that the "instruction" is probably
            # just data, which means it's sprite data, since CHIP-8
            # doesn't have any other kind of data(?).
            line << format('%04x # DATA', instruction)
          end

          asm << line.string

          pos += 2
        end

        File.open(out, 'w') do |file|
          file.write asm.join("\n")
        end

        log.info "Wrote #{asm.size} ASM lines to #{out}"
      end

      private

      def log
        @log ||= Logging.get_logger 'disassembler'
      end
    end
  end
end
