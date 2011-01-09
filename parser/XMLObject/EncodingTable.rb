require 'nil/xml'

require_relative 'InstructionOperantEncoding'

class EncodingTable < Nil::XMLObject
  def initialize(encodingTable)
    super()
    if encodingTable != nil
      encodingTable.each do |row|
        add(InstructionOperandEncoding.new(row[0], row[1..-1]))
      end
    end
  end
end
