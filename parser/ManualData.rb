#coding: utf-8

require 'htmlentities'

require 'nil/file'
require 'nil/string'

require_relative 'Instruction'
require_relative 'XMLParser'

require_relative 'ManualData/description'
require_relative 'ManualData/encoding'
require_relative 'ManualData/opcodes'

class ManualData
  def initialize
    @instructions = []
    @html = HTMLEntities.new
    @output = ''
  end

  def processPath(path)
    data = Nil.readFile(path)
    raise "Unable to read manual file \"#{path}\"" if data == nil
    instructionPattern = /<Sect>.*?<H4 id="LinkTarget_\d+">(.+?) <\/H4>(.*?)<\/Sect>/m
    data = data.gsub("\r", '')
    data.force_encoding('utf-8')
    data.scan(instructionPattern) do |match|
      title, content = match
      parseInstruction(title, content)
    end
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

  def warning(instruction, message)
    puts "Warning for instruction #{instruction.inspect}: #{message}"
  end

  def parseInstruction(title, content)
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

    tablePattern = /<Table>(.*?)<\/Table>/m
    instructionPattern = /<T[HD]>Instruction.?<\/T[HD]>|<P>Opcode\*? Instruction/
    descriptionPattern = /<P>Description <\/P>/

    jumpString = 'Transfers program control'

    error = proc do |reason|
      raise "This is not an instruction section (#{reason} match failed)"
    end

    descriptionMatch = descriptionPattern.match(content)

    #the JMP instruction has an irregular description tag within a table
    if descriptionMatch == nil && content.index(jumpString) == nil
      error.call('description')
    end

    instructionMatch = instructionPattern.match(content)
    if instructionMatch == nil
      error.call('instruction')
    end

    opcodeTable = extractParagraphOpcodes(instruction, content)
    if opcodeTable == nil
      tableMatch = tablePattern.match(content)
      if tableMatch == nil
        error.call('table')
      end
      tableContent = tableMatch[1]
      opcodeTable = extractTableOpcodes(instruction, tableContent)
    end

    opcodeTable.each do |row|
      row.map! do |column|
        if column == nil
          raise "Encountered a nil column: #{opcodeTable.inspect}"
        end
        column.strip
      end
    end

    description = extractDescription(instruction, content)
    if description == nil
      raise "Unable to extract the description of instruction #{instruction.inspect}"
    end

    encodingTable = getEncodingTable(instruction, content)

    writeLine(instruction.inspect)
    writeLine(opcodeTable.inspect)
    writeLine(encodingTable.inspect)
    writeLine(description.visualise)
    writeLine('')

    instruction = Instruction.new(opcodeTable, encodingTable)

    @instructions << instruction
  end

  def writeLine(line)
    @output += "#{line}\n"
  end

  def writeOutput(path)
    Nil.writeFile(path, @output)
  end
end
