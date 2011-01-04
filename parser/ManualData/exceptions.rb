require_relative '../InstructionException'

class ManualData
  def extractExceptionType(exceptionName, exceptionPattern, symbol, instruction, content, acceptAllOperatingModes)
    case instruction
    when 'CMPSS', 'INVLPG'
      return 'None.' if exceptionName == 'Compatibility Mode Exceptions'
    when 'GETSEC[WAKEUP]'
      #this is broken in the reference
      return 'GETSEC[WAKEUP] is not recognized in real-address mode.' if exceptionName == 'Real-Address Mode Exceptions'
    end
    target = exceptionPattern
    if acceptAllOperatingModes
      target = Regexp.union(target, 'Exceptions (All Operating Modes)', 'Exceptions (All Modes of Operation)')
    end
    pattern = /<P>(#{target}) <\/P>(?:(.+?)(?:VM-[eE]xit Condition|<P>[^<]+?Exceptions <\/P>|<\/H4>|<TD>GETSEC\[WAKEUP\] is not recognized in real-address mode\.|Exceptions \(All Operating Modes\))|(.+))/m
    #puts pattern.inspect
    match = content.match(pattern)
    if match == nil
      return extractSpecialExceptionType(symbol, instruction, content)
    end
    exceptionName = match[1]
    exceptionContent = match[2] || match[3]
    raise "Bad exception content: #{exceptionContent.inspect}" if exceptionContent.index(" Exceptions") != nil
    return exceptionContent
  end

  def extractSpecialExceptionType(symbol, instruction, content)
    return if symbol == nil
    pattern = /Protected Mode Exceptions Real Mode Exceptions|Protected Mode Exceptions Real-Address Mode Exceptions/
    beginningMatch = content.match(pattern)
    return nil if beginningMatch == nil
    beginning = beginningMatch.offset(0)[0]
    tableBeginning = content.index('<Table>', beginning)
    error 'Unable to locate the table in a special exception type instruction' if tableBeginning == nil
    virtualMatch = content.match(/Virtual[- ]8086 Mode Exceptions/)
    error 'Unable to determine the offset of the V8086 mode' if virtualMatch == nil
    virtualOffset = virtualMatch.offset(0)[0]
    tableEnd = content.rindex('</Table>', virtualOffset)
    error 'Unable to locate the end of the table in a special exception type instruction' if tableEnd == nil
    case symbol
    when :protected
      tableContent = content[tableBeginning, tableEnd - tableBeginning]
      return tableContent
    when :real
      realContent = content[tableEnd, virtualOffset - tableEnd]
      return realContent
    else
      raise "Unknown symbol: #{symbol.inspect}"
    end
  end

  def processExceptionMarkup(markup, useTable = true)
    replacements =
      [
       ['IF', 'If'],
       ['>GP', '>#GP'],
       ['Same exceptions as in Real Address Mode ', 'Same exceptions as in Real Address Mode.'],
       ['Same exceptions as in Protected Mode ', 'Same exceptions as in Protected Mode.'],
      ]
    scanPattern = /<(?:TD|TH|P)>(.+?)<\/(?:TD|TH|P)>/m
    tokens = []
    replaceStrings(markup, replacements).scan(scanPattern) do |match|
      token = replaceCommonStrings(match[0].strip)
      tokens << token
    end
    text = tokens.join(' ')
    return text if !useTable
    originalText = text.dup
    exceptionPattern = /^(#[A-Z]+(?:\(.+?\))?|Reason \(GETSEC\)) /
    delimiterPattern = /\. (#[A-Z]+(?:\(.+?\))?) /
    nilExceptionNamePattern = /^(?:(?:Same exceptions|Same as|When the source operand|Invalid|Overflow|General|Exceptions may|The only exceptions generated|All protected mode).*?\.|Not applicable\.|None\.|None;.+|None$)/
    exceptionTable = []
    while true
      text = text.strip
      match = text.match(nilExceptionNamePattern)
      if match != nil
        output = match[0]
        tokens << [nil, output]
        text = text[output.size..-1]
        next
      end
      match = text.match(exceptionPattern)
      break if match == nil
      exception = match[1]
      descriptionBeginning = exception.size + 1
      match = text.match(delimiterPattern)
      if match == nil
        descriptionEnd = text.size
      else
        descriptionEnd = match.offset(1)[0]
      end
      description = text[descriptionBeginning, descriptionEnd - descriptionBeginning]
      tokens << [exception, description]
      text = text[descriptionEnd..-1]
    end
    if !text.empty?
      error "Unable to parse the rest of the text: #{text.inspect}\nIn the following markup: #{markup.inspect}\nIn the following text: #{originalText.inspect}"
    end
    return exceptionTable
  end

  def extractExceptions(instruction, content)
    #return if instruction != 'GETSEC[ENTERACCS]'
    exceptions =
      [
       ['Protected Mode Exceptions', true, :protected],
       InstructionException.regex('Real-Address Mode Exceptions', /Real[- ](?:Address )?Mode Exceptions/, true, :real),
       InstructionException.regex('Virtual-8086 Mode Exceptions', /Virtual[- ]8086 Mode Exceptions/, true),
       ['Compatibility Mode Exceptions', true],
       ['64-Bit Mode Exceptions', true],

       ['Exceptions'],
       InstructionException.new('SIMD Floating-Point Exceptions', false, nil, false),
       ['Floating-Point Exceptions'],
       ['Numeric Exceptions'],
       ['VM-Exit Condition'],
      ].map do |data|
      if InstructionException === data
        data
      else
        InstructionException.new(*data)
      end
    end

    output = {}

    exceptions.each do |exception|
      exceptionMarkup = extractExceptionType(exception.name, exception.pattern, exception.symbol, instruction, content, exception.isEssential)
      if exceptionMarkup == nil
        if exception.isEssential
          puts content.inspect
          error "Unable to extract data for essential exception #{exception.name.inspect}"
        else
          exceptionData = nil
        end
      else
        exceptionData = processExceptionMarkup(exceptionMarkup, exception.usesTableDescription)
        error "Empty parsed data: #{exceptionMarkup.inspect}" if exceptionData == nil
      end
      #puts "#{instruction} #{exception.name.inspect}: #{exceptionMarkup.inspect}"
      output[exception.name] = exceptionData
    end
    return output
  end
end
