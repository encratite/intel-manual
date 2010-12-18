#coding: utf-8

require 'htmlentities'

require 'nil/file'
require 'nil/string'

require_relative 'Instruction'
require_relative 'XMLParser'

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

  def postProcessRows(rows)
    return if rows.empty?
    headerColumns = rows.first.size
    rows[1..-1].each do |row|
      difference = headerColumns - row.size
      case difference
      when 1
        #we have discovered a case of column merges in the XML output
        mergeOffset = 1
        mergedColumn = row[mergeOffset]
        case mergedColumn
        when nil
          #the merged column is part of a split row - just replicate the nil
          row.insert(mergeOffset, nil)
          next
        end
        targets = ['A', 'B', 'Valid']
        hit = false
        targets.each do |target|
          string = target + ' '
          lastOffset = mergedColumn.size - string.size
          if mergedColumn[lastOffset..-1] == string
            mergedColumn.replace(mergedColumn[0..lastOffset])
            row.insert(mergeOffset + 1, target)
            hit = true
          end
        end
        if hit == false
          raise "Unable to split up erroneously merged columns: #{row.inspect}"
        end
      when 0
        #everything is in order
      else
        raise "Invalid row length discrepancy of #{difference}: #{rows.inspect}"
      end
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

  def splitMergedColumns(row)
    targets =
      [
       'A',
       'B',
       'Valid',
      ]

    #for cases where the second and the third column were merged
    targets.each do |target|
      target = ' ' + target + ' '
      mergedColumn = row[1]
      if mergedColumn != nil && mergedColumn.matchRight(target)
        fixedColumn = mergedColumn[0..mergedColumn.size - target.size - 1]
        mergedColumn.replace(fixedColumn)
        row.insert(2, target)
        return true
      end
    end
    return false
  end

  def processIrregularOpcodeRow(instruction, row, output)
    if row.size == 5
      return if splitMergedColumns(row)

      #for cases where a nil column is missing and the last column is part of the description
      if !output.empty?
        lastDescription = output[-1][-1].strip
        if !lastDescription.empty? && lastDescription[-1] != '.'
          match = true
          (row.size - 1).times do |i|
            if row[i] != nil
              match = false
              break
            end
          end
          if match && row[-1] != nil
            row.insert(0, nil)
            return
          end
        end
      end

      case instruction
      when 'LSL'
        row.insert(1, nil)
        return

      when 'MOV'
        targets =
          [
           'r8***,r/m8***',
           'moffs32*,EAX',
          ]
        targets.each do |target|
          if row[1].matchLeft(target)
            row.insert(2, nil)
            return
          end
        end

      when 'MOVZX'
        if row[0].matchLeft('/r')
          row.insert(1, nil)
          return
        end
      end

    elsif row.size == 4
      #for merged FPU rows
      return if splitMergedColumns(row)

      if instruction == 'FSTENV/FNSTENV'
        row.insert(0, nil)
        return
      end
    end
    raise "Unable to process irregular opcode row: #{row.inspect}"
  end

  def mergeRows(rows, &block)
    lastCompleteRow = nil
    output = []
    rows.each do |row|
      block.call(row, output, lastCompleteRow)
      append = false
      row.each do |column|
        if column == nil
          append = true
        end
      end
      if append
        if output.empty?
          raise "Encountered an empty column in the first row: #{rows.inspect}"
        end
        lastRow = output[-1]
        row.size.times do |i|
          toAppend = row[i]
          next if toAppend == nil
          lastRow[i] += toAppend
        end
      else
        output << row
        lastCompleteRow = row
      end
    end
    return output
  end

  def extractTableOpcodes(instruction, tableContent)
    rows = parseTable(tableContent)
    return nil if rows.empty?

    output = mergeRows(rows) do |row, output, lastCompleteRow|
      #6 for the normal ones, 5 for FPU stuff, they use another table format, 3 for the VM stuff in manual 2
      validColumnCounts = [3, 5, 6]
      if !validColumnCounts.include?(row.size) || (lastCompleteRow != nil && lastCompleteRow.size != row.size)
        processIrregularOpcodeRow(instruction, row, output)
      end
    end

    begin
      postProcessRows(output)
    rescue => exception
      raise exception
    end

    return output
  end

  def getLineInstruction(line)
    pattern = / ([A-Z]{3,}|[A-Z][A-Z0-9]{2,}) /
    match = pattern.match(line)
    return if match == nil
    instruction = match[1]
    return instruction
  end

  def performEncodingIdentifierSplit(line)
    targets =
      [
       'A',
       'B',
       'C',
      ]

    targets.each do |target|
      offset = line.index(" #{target} ")
      next if offset == nil
      offset += 1
      mnemonicData = line[0..offset - 1]
      line = line[offset + 1 + target.size..-1]
      return mnemonicData, target, line
    end

    return
  end

  def performExceptionalParagraphOpcodeProcessing(line, rows)
    row = nil
    if line.matchLeft('/1 m128 m128')
      #"/1 m128 m128 m128. If equal, set ZF and load RCX:RBX into m128. Else, clear ZF and load m128 into RDX:RAX. "
      pattern = /(.+?) (m128) (m128\..+)/
      match = pattern.match(line)
      raise "Unable to process CMPXCHG8B exceptional case" if match == nil
      row = [match[1], match[2], nil, nil, nil, match[3]]
    elsif line.matchLeft('r/m32.')
      row = []
      5.times { row << nil }
      row << line
    end

    raise "Unknown special case: #{line.inspect}" if row == nil

    rows << row
  end

  def getFirstUpperCaseOffsetAfterInstructionMnemonic(input)
    match = / .+?([A-Z])/.match(input)
    if match == nil
      raise "Unable to locate a post mnemonic upper case character in a reduced paragraph opcode line: #{line.inspect}"
    end
    return match.offset(1)[0]
  end

  def processParagraphOpcodeLine(instruction, line, rows)
    line = line.gsub("\t", '')
    instruction = getLineInstruction(line)
    #puts line.inspect
    #puts instruction.inspect
    if [nil, 'ZF'].include?(instruction)
      performExceptionalParagraphOpcodeProcessing(line, rows)
      return
    end

    offset = line.index(instruction)
    hexData = line[0..offset - 1]
    line = line[offset..-1]

    if instruction.size > 2 && instruction[0..1] == 'VM'
      offset = getFirstUpperCaseOffsetAfterInstructionMnemonic(line)

      mnemonicData = instruction
      description = line[offset..-1]
      row = [hexData, mnemonicData, description]
    else
      #puts line.inspect
      tokens = performEncodingIdentifierSplit(line)
      #puts tokens.inspect
      if tokens == nil
        raise "Unable to extract the encoding identifier from line #{line.inspect}"
      end
      mnemonicData, encodingIdentifier, line = tokens
      pattern = /(.+?) (.+?) (.+)/
      match = pattern.match(line)
      if match == nil
        raise "Unable to extract the validity and description columns from line #{line.inspect}"
      end

      longMode = match[1]
      legacyMode = match[2]
      description = match[3]
      row = [hexData, mnemonicData, encodingIdentifier, longMode, legacyMode, description]
    end

    rows << row
  end

  def extractParagraphOpcodes(instruction, content)
    return nil if instruction == 'PSLLW/PSLLD/PSLLQ'

    paragraphPattern = /<P>Opcode\*? Instruction.*?<\/P>(.*?)<P>(NOTES|Description)/m
    linePattern = /<P>(.*?)<\/P>/

    paragraphMatch = paragraphPattern.match(content)
    return nil if paragraphMatch == nil

    rows = []

    paragraphContent = paragraphMatch[1]
    paragraphContent.scan(linePattern) do |match|
      line = match.first
      processParagraphOpcodeLine(instruction, line, rows)
    end

    rows = mergeRows(rows) {}

    return rows
  end

  def extractEncodingParagraph(input)
    input = @html.decode(input)
    encodingParagraphPattern = /<P>Op\/En Operand ?1 Operand ?2 Operand ?3 Operand ?4.*\n(.+?)\n<\/P>/
    match = encodingParagraphPattern.match(input)
    return nil if match == nil
    content = match[1]

    targets =
      [
       '<XMM0>',
       'imm8/16/32',
       'imm8/16/32/64',
       'Displacement',
       'AL/AX/EAX/RAX',
       'implicit XMM0',
       'reg (r)',
       'reg (w)',
       'reg (r, w)',
       'Offset',
       'ModRM:reg (r)',
       'ModRM:reg (w)',
       'ModRM:reg (r, w)',
       'ModRM:r/m (r)',
       'ModRM:r/m (w)',
       'ModRM:r/m (r, w)',
       'imm8',
       'iw',
       'NA',
       'A',
       'B',
       'C',
      ]
    i = 0
    output = []
    while i < content.size
      if content[i] == ' '
        i += 1
        next
      end
      foundTarget = false
      targets.each do |target|
        remaining = content.size - i
        if target.size > remaining
          next
        end
        substring = content[i..i + target.size - 1]
        if substring == target
          foundTarget = true
          output << target
          i += target.size
          break
        end
      end
      if !foundTarget
        raise "Unable to process encoding string #{content.inspect}, previous matches were #{output.inspect}"
      end
    end
    return [output]
  end

  def extractEncodingTable(content)
    tablePattern = /<Table>(.+?)<\/Table>/m
    target = '<TD>Operand 1 </TD>'
    content.scan(tablePattern) do |match|
      tableContent = match[0]
      next if tableContent.index(target) == nil
      rows = parseTable(tableContent)
      if rows.size < 2
        raise "Invalid instruction encoding table: #{rows.inspect}"
      end

      #Ignore the header
      return rows[1..-1]
    end
    return nil
  end

  def removeNewlinesAroundLink(element, isLeftSideOfLink)
    if element.class != String
      raise "Encountered an unexpected class: #{element.class}"
    end
    return if element.empty?
    target = "\n"
    offset = isLeftSideOfLink ? element.size - 1 : 0
    if isLeftSideOfLink
      offset = -1
      left = 0
      right = -2
    else
      offset = 0
      left = 1
      right = -1
    end
    if element[offset] == target
      element.replace(element[left..right])
    end
  end

  def descriptionPostProcessing(node)
    if node.tag == 'Link'
      if node.content == nil
        raise "Encountered a <Link> tag without any content"
      end
      parentContent = node.parent.content
      offset = parentContent.index(node)
      if offset == nil
        raise "Unable to find a node in its parent's children"
      end
      left = offset - 1
      right = offset + 1
      replacement = parentContent[0..left] + node.content + parentContent[right..-1]
      if offset > 0
        removeNewlinesAroundLink(replacement[left], true)
      end
      if offset < replacement.size - 1
        removeNewlinesAroundLink(replacement[right], false)
      end
      parentContent.replace(replacement)
      return
    end
    return if node.content == nil
    nodes = node.content.reject { |x| x.class == String }
    nodes.each { |x| descriptionPostProcessing(x) }
  end

  def fixRootNewlines(root)
    root.content.each do |x|
      if x == "\n\n"
        x.replace("\n")
      end
    end
  end

  def removeTrailingSpaces(node)
    node.each do |element|
      if element.class == String
        if element.matchRight('. ')
          element.replace(element[0..-2])
        end
      else
        removeTrailingSpaces(element)
      end
    end
  end

  def lowerCaseTags(node)
    if node.tag != nil
      node.tag.downcase!
    end
    node.eachNode do |element|
      lowerCaseTags(element)
    end
  end

  def extractDescription(instruction, content)
    if instruction == 'JMP'
      descriptionPattern = /(<P>Transfers .+?data and limits. <\/P>)/m
    else
      #the second one is for MAXPD, the third one for GETSEC[SEXIT]
      descriptionPattern = /<P>Description <\/P>(.+?)(?:<P>(?:Operation|FPU Flags Affected) <\/P>|<Table>|<P>Operation in a Uni-Processor Platform <\/P>)/m
    end
    descriptionMatch = content.match(descriptionPattern)
    return nil if descriptionMatch == nil
    markup = descriptionMatch[1]
    root = XMLParser.parse(markup)
    descriptionPostProcessing(root)
    fixRootNewlines(root)
    removeTrailingSpaces(root)
    lowerCaseTags(root)
    return root
  end

  def getEncodingTable(instruction, content)
    if instruction == 'JMP'
      #too much of a pain, honestly
      encodingTable =
        [
         ['A', 'Offset', 'NA', 'NA', 'NA'],
         ['B', 'ModRM:r/m', 'NA', 'NA', 'NA'],
        ]
    else
      encodingTable = extractEncodingParagraph(content)
      if encodingTable == nil
        encodingTable = extractEncodingTable(content)
      end
    end
    return encodingTable
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

    #return if instruction != 'BT'

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
