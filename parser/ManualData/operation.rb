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

    codeLines.each do |line|
      line = line.strip

      addLine = lambda do
        output << applyIndentation(tabLevel, line)
      end

      tokens = line.split(' ')
      next if tokens.empty?
      keyword = tokens[0].gsub(';', '')
      if scopeStartKeywords.include?(keyword)
        addLine.call
        tabLevel += 1
      elsif scopeEndKeywords.include?(keyword)
        tabLevel -= 1
        if tabLevel < 0
          error "Indentation underflow on line #{line.inspect} in the following code:\n#{codeLines.join("\n")}\nPrevious indentation was:\n#{output.join("\n")}"
        end
        addLine.call
      elsif keyword == 'ELSE'
        tabLevel -= 1
        addLine.call
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

  def extractOperation(content)
    pattern = /<P>Operation <\/P>(.+?)<P>Flags Affected <\/P>/m
    match = content.match(pattern)
    return nil if match == nil
    operationContent = match[1]
    lines = []
    operationContent.scan(/<P>(.+?)<\/P>/m) do |match|
      input = match[0].strip
      #puts input.inspect
      token = replaceCommonStrings(input)
      #puts token.inspect
      token.gsub!(/; [^\(]/) do |match|
        match.gsub(' ', "\n")
      end
      lines += token.split("\n")
    end
    output = calculatePseudoCodeIndentation(lines)
    output = output.join("\n")
    return output
  end
end
