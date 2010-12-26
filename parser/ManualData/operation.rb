require_relative 'string'

class ManualData
  def applyIndentation(count, line)
    return ("\t" * count) + line
  end

  def calculatePseudoCodeIndentation(codeLines)
    output = []
    tabLevel = 0

    ifIndentationStack = []

    stackCheck = lambda do
      if ifIndentationStack.empty?
        error "Empty indentation stack:\n#{output.join("\n")}"
      end
    end

    codeLines.each do |line|
      line = line.strip

      indentationCheck = lambda do
        if tabLevel < 0
          error "Indentation underflow on line #{line.inspect} in the following code:\n#{codeLines.join("\n")}\nPrevious indentation was:\n#{output.join("\n")}"
        end
      end

      addLine = lambda do |preIncrement = 0, postIncrement = 0|
        tabLevel += preIncrement
        indentationCheck.call
        output << applyIndentation(tabLevel, line)
        tabLevel += postIncrement
        indentationCheck.call
      end

      if !line.empty? && line[-1] == ':'
        addLine.call(0, 1)
        next
      end

      tokens = line.split(' ')
      next if tokens.empty?
      keyword = tokens[0].gsub(';', '')
      #puts "#{keyword.inspect} #{tabLevel}: #{line.inspect}"
      case keyword
      when 'IF'
        if tokens.size >= 2 && tokens[1] != '='
          ifIndentationStack << tabLevel
          addLine.call(0, 1)
        else
          addLine.call
        end
      when 'THEN'
        addLine.call(0, 1)
      when 'FI'
        stackCheck.call
        tabLevel = ifIndentationStack.pop
        output << applyIndentation(tabLevel, line)
      when 'ELSE'
        stackCheck.call
        tabLevel = ifIndentationStack[-1]
        output << applyIndentation(tabLevel, line)
        tabLevel += 1
      when 'END', 'BREAK'
        addLine.call(-1, 0)
      else
        addLine.call
      end
    end

    if tabLevel != 0
      data = output.join("\n")
      error "Indentation level #{tabLevel} at the end of the following code:\n#{data}"
    end

    return output
  end

  def operationReplacements(instruction, input)
    replacements =
      [
       ['ELSE If', 'ELSE IF'],
       [' IF ', "\nIF "],
       ['FI;rel/abs', 'FI; (* relative/absolute *)'],
       ['FI; near', 'FI; (* near *)'],
       ['*) ', "*)\n"],
       [/; [^\(]/, lambda { |match| match.gsub(' ', "\n") }],
       [' THEN', "\nTHEN"],
       ["THEN DEST = temp;\nFI;", 'THEN DEST = temp;'],
       ['IF DF = 0 (', "IF DF = 0\n("],
       #['; ', ";\n"],
       [/\([A-Za-z][a-z]+ comparison\)/, lambda { |x| "(* #{x[1..-2]} *)" }],
       [' THEN', ''],
       ["\nTHEN\n", "\n"],
       ['THEN ', ''],
       ['ELSE (* Non-64-bit Mode *)', "FI;\nFI;\nELSE (* Non-64-bit Mode *)"],
       ["multiplication;\n", 'multiplication; '],
       #for the INT 3 thing
       ["&\n", '& '],
       #['(* relative/absolute *) FI;', "(* relative/absolute *)\nFI;"
      ]

    if instruction == 'IMUL'
      replacements << ["ELSE\nIF (NumberOfOperands = 2)", "FI;\nELSE\nIF (NumberOfOperands = 2)"]
    end

    output = replaceStrings(input, replacements)
    case instruction
    when'CMPS/CMPSB/CMPSW/CMPSD/CMPSQ'
      output += "\nFI;"
    end
    return output
  end

  def unicodeCheck(instruction, lines)
    lines.each do |line|
      if line.inspect.index("\\u") != nil
        puts "Discovered unprocessed Unicode content in instruction #{instruction}: #{line.inspect}"
      end
    end
  end

  def extractOperation(instruction, content)
    pattern = /<P>Operation <\/P>(.+?)<P>(Flags Affected|Intel C\/C\+\+ Compiler Intrinsic Equivalent) <\/P>/m
    match = content.match(pattern)
    return nil if match == nil
    operationContent = match[1]
    lines = []
    operationContent.scan(/<P>(.+?)<\/P>/m) do |match|
      token = match[0].strip
      token = replaceCommonStrings(token)
      lines << token
    end

    input = lines.join("\n")
    input = operationReplacements(instruction, input)
    lines = input.split("\n")

    output = calculatePseudoCodeIndentation(lines)
    unicodeCheck(instruction, output)
    output = output.join("\n")
    return output
  end
end
