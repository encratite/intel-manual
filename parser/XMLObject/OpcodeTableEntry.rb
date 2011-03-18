require 'nil/xml'
require 'nil/symbol'

class OpcodeTableEntry < Nil::XMLObject
  attr_reader :opcode, :mnemonicDescription, :encodingIdentifier, :longMode, :legacyMode, :description

  include SymbolicAssignment

  def initialize
    super()
    setName('Opcode')
  end
end
