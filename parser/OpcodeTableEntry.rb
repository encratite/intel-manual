require 'nil/xml'
require 'nil/symbol'

class OpcodeTableEntry < Nil::XMLObject
  include SymbolicAssignment
  attr_reader(
              :opcode,
              :instruction,
              #may be nil
              :encodingIdentifier,
              :longMode,
              :legacyMode,
              :description,
              )
end
