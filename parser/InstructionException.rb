class InstructionException
  attr_reader :name, :isEssential, :symbol, :usesTableDescription
  attr_accessor :pattern

  def initialize(name, isEssential = false, symbol = nil, usesTableDescription = true)
    @name = name
    @pattern = name
    @isEssential = isEssential
    @symbol = symbol
    @usesTableDescription = usesTableDescription
  end

  def self.regex(name, pattern, isEssential = false, symbol = nil)
    output = InstructionException.new(name, isEssential, symbol)
    output.pattern = pattern
    return output
  end
end
