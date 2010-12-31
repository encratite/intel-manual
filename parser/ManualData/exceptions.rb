class ManualData
  def extractExceptionType(exception, symbol, isEssential, instruction, content)
    pattern = /<P>(#{exception}) <\/P>(?:(.+?)(?:<P>[^<]+?Exceptions <\/P>)|(.+))/m
    match = content.match(pattern)
    if match == nil
      return extractSpecialExceptionType(exception, symbol, isEssential, instruction, content)
    end
    exceptionName = match[1]
    exceptionContent = match[2] || match[3]
    return exceptionContent
  end

  def extractSpecialExceptionType(exception, symbol, isEssential, instruction, content)
    return nil if symbol == nil
    trigger = 'Protected Mode Exceptions Real-Address Mode Exceptions'
    beginning = content.index(trigger)
    return nil if beginning == nil
    tableBeginning = content.index('<Table>', beginning)
    error 'Unable to locate the table in a special exception type instruction' if tableBeginning == nil
    tableEnd = content.rindex('</Table>', tableBeginning)
    error 'Unable to locate the end of the table in a special exception type instruction' if tableEnd == nil
    case symbol
    when :protected
      tableContent = content[tableBeginning, tableEnd - tableBeginning]
      puts tableContent.inspect
      return tableContent
    when :real
      realContent = content[tableEnd..-1]
      pattern = /(?:(.+?)(?:<P>[^<]+?Exceptions <\/P>)|(.+))/m
      match = realContent.match(pattern)
      error 'Unable to get a match in a special exception type instruction'
      realData = match[1]
      return realData
    end
  end

  def extractExceptions(instruction, content)
    exceptions =
      [
       #exception name pattern, essential
       ['Protected Mode Exceptions', true, :protected],
       ['Real-Address Mode Exceptions', true, :real],
       ['Virtual-8086 Mode Exceptions', true, nil],
       ['Compatibility Mode Exceptions', true, nil],
       ['64-Bit Mode Exceptions', true, nil],

       ['SIMD Floating-Point Exceptions', false, nil],
       ['Floating-Point Exceptions', false, nil],
       ['Numeric Exceptions', false, nil],
      ]

    exceptions.each do |exception, isEssential, symbol|
      exceptionData = extractExceptionType(exception, symbol, isEssential, instruction, content)
      if exceptionData == nil && isEssential
        error "Unable to extract data for essential exception #{exception}"
      end
      puts "#{instruction} #{exception.inspect}: #{exceptionData.inspect}"
    end
  end
end
