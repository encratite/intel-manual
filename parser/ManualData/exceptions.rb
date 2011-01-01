require_relative '../InstructionException'

class ManualData
  def extractExceptionType(exception, symbol, instruction, content, acceptAllOperatingModes)
    case instruction
    when 'CMPSS'
      return 'None.' if exception == 'Compatibility Mode Exceptions'
    end
    target = exception
    if acceptAllOperatingModes
      target = Regexp.union(target, 'Exceptions (All Operating Modes)')
    end
    pattern = /<P>(#{target}) <\/P>(?:(.+?)(?:<P>[^<]+?Exceptions <\/P>)|<\/H4>|(.+))/m
    match = content.match(pattern)
    if match == nil
      return extractSpecialExceptionType(exception, symbol, instruction, content)
    end
    exceptionName = match[1]
    exceptionContent = match[2] || match[3]
    return exceptionContent
  end

  def extractSpecialExceptionType(exception, symbol, instruction, content)
    return nil if symbol == nil
    trigger = 'Protected Mode Exceptions Real-Address Mode Exceptions'
    beginning = content.index(trigger)
    return nil if beginning == nil
    tableBeginning = content.index('<Table>', beginning)
    error 'Unable to locate the table in a special exception type instruction' if tableBeginning == nil
    virtualOffset = content.index('Virtual-8086 Mode Exceptions')
    error 'Unable to determine the offset of the V8086 mode' if virtualOffset == nil
    tableEnd = content.rindex('</Table>', virtualOffset)
    error 'Unable to locate the end of the table in a special exception type instruction' if tableEnd == nil
    case symbol
    when :protected
      tableContent = content[tableBeginning, tableEnd - tableBeginning]
      return tableContent
    when :real
      realContent = content[tableEnd, virtualOffset - tableEnd]
      return realContent
    end
  end

  def extractExceptions(instruction, content)
    exceptions =
      [
       ['Protected Mode Exceptions', true, :protected],
       InstructionException.regex('Real-Address Mode Exceptions', /Real[- ]Address Mode Exceptions/, true, :real),
       InstructionException.regex('Virtual-8086 Mode Exceptions', /Virtual[- ]8086 Mode Exceptions/, true),
       ['Compatibility Mode Exceptions', true],
       ['64-Bit Mode Exceptions', true],

       ['Exceptions'],
       ['SIMD Floating-Point Exceptions'],
       ['Floating-Point Exceptions'],
       ['Numeric Exceptions'],
      ].map do |data|
      if data === InstructionException
        data
      else
        InstructionException.new(*data)
      end
    end

    exceptions.each do |exception|
      exceptionData = extractExceptionType(exception.pattern, exception.symbol, instruction, content, exception.isEssential)
      if exceptionData == nil && exception.isEssential
        #uts content.inspect
        error "Unable to extract data for essential exception #{exception.name.inspect}"
      end
      puts "#{instruction} #{exception.name.inspect}: #{exceptionData.inspect}"
    end
  end
end
