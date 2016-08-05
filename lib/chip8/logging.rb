require 'logger'

module Chip8
  module Logging
    def self.get_logger(name)
      @log ||= Logger.new STDOUT
    end
  end
end
