require_relative 'string'

class ManualData
  def applyIndentation(count, line)
    return ("\t" * count) + line
  end

  def calculatePseudoCodeIndentation(codeLines)
    scopeStartKeywords =
      [
       'IF',
       'THEN',
      ]

    scopeEndKeywords =
      [
       'FI',
      ]

    output = []
    tabLevel = 0

    ifIndentationStack = []

    indentationCheck = lambda do
      if tabLevel < 0
        error "Indentation underflow on line #{line.inspect} in the following code:\n#{codeLines.join("\n")}\nPrevious indentation was:\n#{output.join("\n")}"
      end
    end

    stackCheck = lambda do
      if ifIndentationStack.empty?
        error "Empty indentation stack:\n#{output.join("\n")}"
      end
    end

    codeLines.each do |line|
      line = line.strip

      addLine = lambda do |preIncrement = 0, postIncrement = 0|
        tabLevel += preIncrement
        indentationCheck.call
        output << applyIndentation(tabLevel, line)
        tabLevel += postIncrement
        indentationCheck.call
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
      else
        addLine.call
      end
    end

    if tabLevel != 0
      error "Indentation level #{tabLevel} at the end of the following code:\n#{output.join("\n")}"
    end

    return output
  end

  def operationReplacements(input)
    replacements =
      [
       [/; [^\(]/, lambda { |match| match.gsub(' ', "\n") }],
       [' IF ', "\nIF "],
       ['*) ', "*)\n"],
       ['FI;rel/abs', 'FI; (* relative/absolute *)'],
       ['FI; near', 'FI; (* near *)'],
       [' THEN', "\nTHEN"],
       ["THEN DEST = temp;\nFI;", 'THEN DEST = temp;'],
      ]

    return replaceStrings(input, replacements)
  end

  def extractOperation(content)
    pattern = /<P>Operation <\/P>(.+?)<P>Flags Affected <\/P>/m
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
    input = operationReplacements(input)
    lines = input.split("\n")

    output = calculatePseudoCodeIndentation(lines)
    output = output.join("\n")
    return output
  end
end
