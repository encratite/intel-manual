require 'sequel'

require 'nil/file'
require 'nil/string'

require_relative 'ManualData'

def retrieveContentObject(container, targetClass)
  container.content.each do |object|
    if object.class == targetClass
      return object
    end
  end
  return nil
end

def retrieveContentObjects(container, targetClass)
  output = []
  container.content.each do |object|
    if object.class == targetClass
      output << object
    end
  end
  return output
end

def getFirstContent(target)
  return nil if target == nil
  return target.content.first
end

def processInstruction(connection, instruction)
  content = instruction.content
  opcodeTable = content[0]
  opcodes = retrieveContentObjects(opcodeTable, OpcodeTableEntry)
  encodings = retrieveContentObjects(opcodeTable, OpcodeEncoding)
  description = getFirstContent(content[1])
  operation = getFirstContent(content[2])
  flagsAffected = getFirstContent(retrieveContentObject(content, FlagsAffected))
  fpuFlagsAffected = getFirstContent(retrieveContentObject(content, FPUFlagsAffected))
  instructionExceptionContainer = retrieveContentObject(content, InstructionExceptionContainer)
  instructionFields = {
    instruction_name: instruction.name,
    description: description,
    pseudo_code: operation,
    flags_affected: flagsAffected,
    fpu_flags_affected: fpuFlagsAffected,
  }
  instructionId = connection[:instruction].insert(instructionFields)
  opcodes.each do |opcode|
    opcodeFields = {
      instruction_id: instructionId,

      opcode: opcode.opcode,
      mnemonic_description: opcode.mnemonicDescription,
      encoding_identifier: opcode.encodingIdentifier,
      long_mode_validity: opcode.longMode,
      legacy_mode_validity: opcode.legacyMode,
      description: opcode.description,
    }
    connection[:instruction_opcode].insert(opcodeFields)
  end
end

def insertManualData(user, database, manualData)
  adapter = 'postgres'
  host = '127.0.0.1'
  password = ''
  connection =
    Sequel.connect(
                   adapter: adapter,
                   host: host,
                   user: user,
                   password: password,
                   database: database
                   )
  reference = manualData.instructionSetReference
  instructions = reference.content
  instructions.each do |instruction|
    processInstruction(connection, instruction)
  end
end

def parseReference(user, database, descriptionWarningOutputDirectory, inputPaths)
  begin
    totalSize = 0
    manualData = ManualData.new(descriptionWarningOutputDirectory)
    inputPaths.each do |path|
      puts "Processing #{path}"
      size = manualData.processPath(path)
      totalSize += size
    end
    puts "Loaded #{manualData.instructionCount} instruction(s) from #{inputPaths.size} file(s) totalling #{Nil.getSizeString(totalSize)} of XML"
    puts "Number of tables: #{manualData.tableCount}"
    puts "Number of images: #{manualData.imageCount}"
  rescue => exception
    puts exception.inspect
    puts exception.backtrace.map { |x| "\t#{x}\n" }
  end
end

if ARGV.size < 3
  puts '<PostgreSQL user> <PostgreSQL database> <description warning output directory> <input paths>'
  exit
end

user = ARGV[0]
database = ARGV[1]
descriptionWarningOutputDirectory = ARGV[2]
inputPaths = ARGV[3..-1]

parseReference(user, database, descriptionWarningOutputDirectory, inputPaths)
