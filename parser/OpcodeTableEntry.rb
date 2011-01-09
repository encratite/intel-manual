require 'nil/xml'
require 'nil/symbol'

class OpcodeTableEntry < Nil::XMLObject
  include SymbolicAssignment

  def initialize
    super()
    setName('Opcode')
  end
end
