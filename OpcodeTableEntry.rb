class OpcodeTableEntry
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
