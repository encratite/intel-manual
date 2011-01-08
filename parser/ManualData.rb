#coding: utf-8

require 'htmlentities'
require 'fileutils'

require 'nil/file'
require 'nil/string'

require_relative 'Instruction'
require_relative 'XMLParser'

require_relative 'ManualData/description'
require_relative 'ManualData/encoding'
require_relative 'ManualData/opcodes'
require_relative 'ManualData/operation'
require_relative 'ManualData/flags'
require_relative 'ManualData/exceptions'
require_relative 'ManualData/processedInstructions'

class ManualData
  class Error < Exception
    def initialize(message)
      super(message)
    end
  end

  attr_reader :instructions, :tableCount, :imageCount

  def initialize(descriptionWarningOutputDirectory)
    @instructions = []
    @html = HTMLEntities.new
    @output = ''
    @tableCount = 0
    @imageCount = 0
    @descriptionWarningOutputDirectory = descriptionWarningOutputDirectory
    FileUtils.mkdir_p(descriptionWarningOutputDirectory)
    @debugInstructions = []
    @active = true
  end

  def processPath(path)
    if !@active
      puts "Processing of #{path} was cancelled because single instruction debugging is activated and the instruction has already been parsed in a previous markup file"
      return 0
    end
    data = Nil.readFile(path)
    raise "Unable to read manual file \"#{path}\"" if data == nil
    instructionPattern = /<P id="LinkTarget_\d+">(ADC\u2014Add with Carry) <\/P>(.+?)<\/Sect>|<Sect>.*?<H4 id="LinkTarget_\d+">(.+?) <\/H4>(.*?)(?:<\/Sect>|<P id="LinkTarget_\d+">)/m
    data = data.gsub("\r", '')
    data.force_encoding('utf-8')
    data.scan(instructionPattern) do |match|
      if match.first == nil
        match = match[2..-1]
      end
      title, content = match
      parseInstruction(title, content)
    end
    return data.size
  end

  def parseTable(input)
    rowPattern = /<TR>(.*?)<\/TR>/m
    columnPattern = /<T[HD]>(.*?)<\/T[HD]>|(<)T[HD]\/>/
    rows = []
    input.scan(rowPattern) do |match|
      columns = []
      match.first.scan(columnPattern) do |match|
        entry = match.first
        entry = @html.decode(entry) if entry != nil
        columns << entry
      end
      rows << columns
    end
    #puts rows.inspect
    return rows
  end

  def parseInstruction(title, content)
    @warningOccurred = false

    titlePattern = /(.+?)(—|-)(.+?)/
    titleMatch = titlePattern.match(title)
    return if titleMatch == nil
    instruction = titleMatch[1].strip
    summary = titleMatch[2].strip
    return if instruction[0].isNumber

    #at the end of the second PDF
    return if instruction.index('.') != nil

    #VMRESUME is just a pseudo entry which actually refers to a previous section, hence no match
    return if instruction == 'VMRESUME'

    #return if instruction != 'ADDSUBPD'

    #puts "Processing instruction #{instruction}"
    STDOUT.flush

    #just for debugging purposes
    @currentInstruction = instruction

    if !@debugInstructions.empty? && !@debugInstructions.include?(instruction)
      return false
    end

    begin
      tablePattern = /<Table>(.*?)<\/Table>/m
      instructionPattern = /<T[HD]>Instruction.?<\/T[HD]>|<P>Opcode\*? Instruction/
      descriptionPattern = /<P>Description <\/P>/

      jumpString = 'Transfers program control'

      errorProc = proc do |reason|
        error "This is not an instruction section (#{reason} match failed)"
      end

      descriptionMatch = descriptionPattern.match(content)

      #the JMP instruction has an irregular description tag within a table
      if descriptionMatch == nil && content.index(jumpString) == nil
        errorProc.call('description')
      end

      instructionMatch = instructionPattern.match(content)
      if instructionMatch == nil
        errorProc.call('instruction')
      end

      opcodeTable = extractParagraphOpcodes(instruction, content)
      if opcodeTable == nil
        tableMatch = tablePattern.match(content)
        if tableMatch == nil
          errorProc.call('table')
        end
        tableContent = tableMatch[1]
        opcodeTable = extractTableOpcodes(instruction, tableContent)
      end

      opcodeTable.each do |row|
        row.map! do |column|
          if column == nil
            error "Encountered a nil column: #{opcodeTable.inspect}"
          end
          column.strip
        end
      end

      description = extractDescription(instruction, content)
      if description == nil
        error "Unable to extract the description"
      end

      encodingTable = getEncodingTable(instruction, content)

      operation = extractOperation(instruction, content)

      flagsAffected = extractFlagsAffected(instruction, content)
      fpuFlagsAffected = extractFlagsAffected(instruction, content, :fpuFlags)

      exceptions = extractExceptions(instruction, content)

      instructionName = instruction

      writeTag('Instruction', instructionName)
      writeTag('OpcodeTable', opcodeTable)
      writeTag('EncodingTable', encodingTable)
      writeTag('Description', description)
      writeTag('Operation', operation)
      writeTag('FlagsAffected', flagsAffected.inspect)
      writeTag('FPUFlagsAffected', fpuFlagsAffected)
      writeTag('Exceptions', exceptions.inspect)
      writeLine('')

      newInstruction = Instruction.new(instructionName, opcodeTable, encodingTable, operation, flagsAffected, fpuFlagsAffected)

      @instructions << newInstruction

      if @warningOccurred
        path = Nil.joinPaths(@descriptionWarningOutputDirectory, getInstructionFileName(instructionName, 'html'))
        Nil.writeFile(path, description)
      end

    rescue Error => error
      error = Error.new("In instruction #{instruction}: #{error.message}")
      raise error
    end

    return true
  end

  def writeTag(tag, data)
    data = data.inspect if data.class != String
    writeLine("<#{tag}>")
    writeLine(data)
    writeLine("</#{tag}>")
  end

  def writeLine(line)
    begin
      @output += "#{line}\n"
    rescue Encoding::CompatibilityError => exception
      puts "Error in the following line: #{line.inspect}"
      raise exception
    end
  end

  def writeOutput(path)
    Nil.writeFile(path, @output)
  end

  def warning(instruction, message)
    puts "Warning for instruction #{instruction.inspect}: #{message}"
    @warningOccurred = true
  end

  def error(message)
    raise Error.new(message)
  end

  def loadHardCodedInstructionFile(instruction, category, extension = nil)
    data = Nil.readFile("../hard-coded/#{category}/#{getInstructionFileName(instruction, extension)}")
    return data if data == nil
    data.force_encoding('utf-8')
    data.gsub!("\r", '')
    return data
  end

  def getInstructionFileName(instruction, extension = nil)
    output = instruction.gsub('/', '-').gsub(' ', '')
    if extension != nil
      output = "#{output}.html"
    end
    return output
  end
end
