class ManualData
  def extractExceptionType(exception, isEssential, instruction, content)
    pattern = /<P>(#{exception} Exceptions) <\/P>(.+?)(?:<P>.+?Exceptions<\/P>|<\/Sect>|<H4.+?>)/m
    match = content.match(pattern)
    return nil if match == nil
    exceptionName = match[1]
    exceptionContent = match[2]
  end

  def extractExceptions(instruction, content)
    exceptions =
      [
       #exception name pattern, essential
       ['Protected Mode', true],
       ['Real-Address Mode', true],
       ['Virtual-8086 Mode', true],
       ['Compatibility Mode', true],
       ['64-Bit Mode', true],

       ['SIMD Floating-Point', false],
       ['Floating-Point', false],
       ['Numeric', false],
      ]
  end
end
