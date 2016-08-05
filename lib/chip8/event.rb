# frozen_string_literal: true

module Chip8
  # Taken from here: https://emptysqua.re/blog/an-event-synchronization-primitive-for-ruby/
  class Event
    def initialize
      @lock = Mutex.new
      @cond = ConditionVariable.new
      @flag = false
    end

    def set
      @lock.synchronize do
        @flag = true
        @cond.broadcast
      end
    end

    def wait
      @lock.synchronize do
        @cond.wait(@lock) unless @flag
      end
    end
  end
end
