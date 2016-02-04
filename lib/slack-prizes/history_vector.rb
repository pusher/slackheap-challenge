module SlackPrizes
  class HistoryVector
    def initialize(length = 2)
      @history = []
      @max_length = length
    end

    def add(element)
      if @history[0] != element
        @history.unshift(element)
        while @history.size > @max_length
          @history.pop
        end
      end
    end

    def peek
      @history[0]
    end

    def peek_excluding(undesirable)
      @history.find { |e| e != undesirable }
    end
  end
end
