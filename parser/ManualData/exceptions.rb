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
    pattern = /<P>(#{target}) <\/P>(?:(.+?)(?:VM-exit Condition|<P>[^<]+?Exceptions <\/P>|<\/H4>|<TD>GETSEC\[WAKEUP\] is not recognized in real-address mode\.)|(.+))/m
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
       ['SIMD Floating-Point Exceptions'],
       ['Floating-Point Exceptions'],
       ['Numeric Exceptions'],
      ].map do |data|
      if InstructionException === data
        data
      else
        InstructionException.new(*data)
      end
    end

    exceptions.each do |exception|
      exceptionData = extractExceptionType(exception.name, exception.pattern, exception.symbol, instruction, content, exception.isEssential)
      if exceptionData == nil && exception.isEssential
        puts content.inspect
        error "Unable to extract data for essential exception #{exception.name.inspect}"
      end
      puts "#{instruction} #{exception.name.inspect}: #{exceptionData.inspect}"
    end
  end
end
