require 'nil/symbol'

class OpcodeTableEntry
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
