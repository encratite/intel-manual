class ManualData
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

  def trimEncodingTable(table)
    return nil if table == nil
    table.each do |row|
      row.each do |column|
        column.replace(column.strip)
      end
    end
  end

  def getEncodingTable(instruction, content)
    if instruction == 'JMP'
      #too much of a pain to parse, honestly, so just hard-code this for now
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
    encodingTable = trimEncodingTable(encodingTable)
    return encodingTable
  end
end
