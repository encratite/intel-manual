require_relative 'string'

class ManualData
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
    hardCodedData = loadHardCodedInstructionFile(instruction, 'opcodes')
    if hardCodedData != nil
      return eval(hardCodedData)
    end
    paragraphPattern = /<P>Opcode\*? Instruction.*?<\/P>(.*?)<P>(NOTES|Description)/m
    linePattern = /<P>(.*?)<\/P>/

    paragraphMatch = paragraphPattern.match(content)
    return nil if paragraphMatch == nil

    rows = []

    paragraphContent = replaceCommonStrings(paragraphMatch[1])
    #paragraphContent = paragraphMatch[1]
    paragraphContent.scan(linePattern) do |match|
      line = match.first
      processParagraphOpcodeLine(instruction, line, rows)
    end

    rows = mergeRows(rows) {}
    rows = rows.map do |row|
      row.map do |column|
        output = replaceCommonStrings(column)
        if column.index('sign-extend') != nil
          #puts column.inspect
          #puts output.inspect
        end
        output
      end
    end

    return rows
  end
end
