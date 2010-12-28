require 'nil/string'

require_relative 'string'

class ManualData
  def applyIndentation(count, line)
    return ("\t" * count) + line
  end

  def calculatePseudoCodeIndentation(codeLines)
    output = []
    tabLevel = 0

    ifIndentationStack = []

    codeLines.each do |line|
      line = line.strip

      indentationCheck = lambda do
        if tabLevel < 0
          error "Indentation underflow on line #{line.inspect} in:\n#{output.join("\n")}"
        end
      end

      stackCheck = lambda do
        if ifIndentationStack.empty?
          error "Empty indentation stack on line #{line.inspect}:\n#{output.join("\n")}"
        end
      end

      addLine = lambda do |preIncrement = 0, postIncrement = 0|
        tabLevel += preIncrement
        indentationCheck.call
        output << applyIndentation(tabLevel, line)
        tabLevel += postIncrement
        indentationCheck.call
      end

      #CPUID exception
      if line == 'DEFAULT: (* EAX = Value outside of recognized range for CPUID. *)'
        addLine.call
        next
      end

      if line.match(/:$/) || line.match(/: \(\*.*\*\)$/)
        addLine.call(0, 1)
        next
      end

      tokens = line.split(' ')
      next if tokens.empty?
      keyword = tokens[0].gsub(';', '')
      case keyword
      when 'IF'
        if tokens.size >= 2 && tokens[1] != '='
          ifIndentationStack << tabLevel
          addLine.call(0, 1)
        else
          addLine.call
        end
      when 'FI'
        stackCheck.call
        tabLevel = ifIndentationStack.pop
        output << applyIndentation(tabLevel, line)
      when 'ELSE'
        stackCheck.call
        tabLevel = ifIndentationStack[-1]
        output << applyIndentation(tabLevel, line)
        tabLevel += 1
      when 'CASE'
        addLine.call(0, 1)
      when 'END', 'BREAK', 'ESAC'
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

  def createComment(input)
    return "(* #{input} *)"
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
       [/\([A-Za-z][a-z]+ comparison\)/, lambda { |x| createComment(x[1..-2]) }],
       [' THEN', ''],
       ["\nTHEN\n", "\n"],
       ['THEN ', ''],
       ['ELSE (* Non-64-bit Mode *)', "FI;\nFI;\nELSE (* Non-64-bit Mode *)"],
       ["multiplication;\n", 'multiplication; '],
       #for the INT 3 thing
       ["&\n", '& '],
       [/<Link>.+?<\/Link>/m, lambda { |x| x[6..-8] }],
       [/\(\*.+?\*\)/m, lambda { |x| x.gsub("\n", '') }],
       ["=\n", '= '],
       ["\n\n", "\n"],
       [/\[\d+\s*:\s*\d+\]/, lambda { |x| x.gsub(' ', '') }],
       [/(^(BIT_REFLECT|MOD2).+)|Non-64-bit Mode:|FI64-bit Mode:/, lambda { |x| createComment(x) }],
       #risky?
       ['H: ', "H:\n"],
       ['* BREAKEAX = 4H:', "*)\nBREAK;\nEAX = 4H:"],
       ['ELSE ', "ELSE\n"],
       [' ELSE', "\nELSE"],
       [' FI;', "\nFI;"],
       #['IF (', 'IF('],
       ['( ', '('],
       [' )', ')'],
       ['ELES', 'ELSE'],
       ['EASC', 'ESAC'],
       ['ESAC:', 'ESAC;'],
       ['[ ', '['],
       [' ]', ']'],
       [/^[A-Z]+ (instruction )?(with|for) \d+[- ]bit.+?operand.*$/, lambda { |x| createComment(x) }],
       [/^64-BIT_MODE$/, lambda { |x| createComment(x) }],
       ['ELSEIF', "ELSE\nIF"],
       [/,[^ ]/, lambda { |x| ', ' + x[1..-1] }],
       [';FI;', ";\nFI;"],
       ['FI;FI;', "FI;\nFI;"],
       [';(*', '; (*'],
       ['*)IF', "*)\nIF"],
       [/[^ ]\*\)/, lambda { |x| x[0] + ' *)' }],
      ]

    convertToComments = [/^.+:$/, lambda { |x| createComment(x[0..-2]) }]
    convertToCommentsCommon =
      [
       [': ', ":\n"],
       convertToComments,
      ]

    repeatComment = [/^Repeat.+/, lambda { |x| createComment(x) }]

    case instruction
    when 'CRC32'
      replacements +=
        [
         ["Notes:\n", ''],
         [/^CRC32 instruction.+/, lambda { |x| createComment(x) }],
        ]
    when 'CPUID'
      replacements << ["BREAK;\nBREAK;", 'BREAK;']
    when 'IMUL'
      replacements << ["ELSE\nIF (NumberOfOperands = 2)", "FI;\nELSE\nIF (NumberOfOperands = 2)"]
    when 'INSERTPS'
      replacements +=
        [
         ['CASE (COUNT_D) OF', "ESAC;\nCASE (COUNT_D) OF"],
         ['IF (ZMASK[0] = 1)', "ESAC;\nIF (ZMASK[0] = 1)"],
        ]
    when 'INT n/INTO/INT 3'
      separator = "\n"
      input = input.gsub(' (1)', "\n(1)")
      lines = input.split(separator)
      6.times do |i|
        line = lines[i]
        line.replace(createComment(line))
      end
      input = lines.join(separator)
      replacements +=
        [
         ["(* idt operand to error_code is 0 because selector is used *)\nIF new code segment is conforming or new code-segment DPL = CPL", "(* idt operand to error_code is 0 because selector is used *)\nFI;\nIF new code segment is conforming or new code-segment DPL = CPL"],
         ['FI ELSE', 'ELSE'],
         [/INTRA-PRIVILEGE-LEVEL-INTERRUPT.+?END;/m, lambda { |x| x.gsub('IF (IA32_EFER.LMA = 0) (* Not IA-32e mode *)', "FI;\nFI;\nIF (IA32_EFER.LMA = 0) (* Not IA-32e mode *)") }],
         [/IF IDT gate is 32-bit.+?FI; /m, lambda { |x| x.gsub('FI; ', '') }],
         ['IDT gate is 16-bit)', 'IDT gate is 16-bit *)'],
         ['*)IF', "*)\nIF"],
         ['(error code pushed)or', '(error code pushed) or'],
         [')#SS', ")\n#SS"],
         [/INTRA-PRIVILEGE-LEVEL-INTERRUPT:.+?END;/m, lambda { |x| x.gsub("IF = 0;\n(* Interrupt flag set to 0;interrupts disabled *)", "IF = 0;\nFI;\n(* Interrupt flag set to 0;interrupts disabled *)") }],
         ["\nor", ' or'],
         [/INTERRUPT-FROM-VIRTUAL-8086-MODE:.+/m, lambda { |x| x.gsub("));\n(* idt operand", "));\nFI;\n(* idt operand") }],
        ]
    when 'IRET/IRETD'
      replacements +=
        [
         ["\nREAL-ADDRESS-MODE;", "\nREAL-ADDRESS-MODE:"],
         ['IA-32e-MODE:', "END;\nIA-32e-MODE:"],
         ['GOTO IA-32e-MODE-RETURN;', "FI;\nGOTO IA-32e-MODE-RETURN;\nEND;\n"],
        ]
    when 'JMP'
      replacements +=
        [
         ['(* OperandSize = 64) ', "(* OperandSize = 64 *)\n"],
         #[';FI;FI;FI;', ";\nFI;\nFI;\nFI;\n"],
        ]
    when 'LDS/LES/LFS/LGS/LSS'
      replacements +=
        [
         ["or\n", 'or '],
         [' ;', ';'],
         ["\nor", ' or'],
         [' IF ', "\nIF "],
         ['FI; (* Hidden flag;not accessible by software *)', '(* Hidden flag; not accessible by software *)'],
         ['64-BIT_MODE', '(* 64-BIT_MODE *)'],
         ['PREOTECTED MODE OR COMPATIBILITY MODE;', '(* PROTECTED MODE OR COMPATIBILITY MODE *)'],
         ["IF Segment marked not present\n#NP(selector);\nFI;\nFI;", "IF Segment marked not present\n#NP(selector);\nFI;"]
        ]
    when 'LODS/LODSB/LODSW/LODSD/LODSQ'
      replacements +=
        [
         ["FI;\nFI;\nELSE\nIF RAX = SRC; (* Quadword load *)", "FI;\nELSE\nIF RAX = SRC; (* Quadword load *)"],
        ]
      input += "\nFI;\nFI;"
    when 'LSL'
      input += "\nFI;"
    when 'LTR'
      replacements +=
        [
         ["#GP(0);", "#GP(0);\nFI;"],
         ["OR\nIF", "or if"],
        ]
    when 'MOVBE'
      replacements +=
        [
         [/IF \(OperandSize = \d+\) /, lambda { |x| x.strip + "\n" }],
        ]
      input += "\nFI;\nFI;"
    when 'MOVD/MOVQ', 'MOVS/MOVSB/MOVSW/MOVSD/MOVSQ', 'OUTS/OUTSB/OUTSW/OUTSD'
      replacements << convertToComments
    when 'MOVQ', 'MOVHPD', 'MOVHPS', 'MOVLPD', 'MOVLPS', 'MOVSS'
      replacements += convertToCommentsCommon
    when 'NOP'
      return nil
    when 'PEXTRB/PEXTRD/PEXTRQ'
      replacements << ["DEST = TEMP;\nESAC;", "DEST = TEMP;\nFI;\nESAC;"]
    when 'PHADDSW'
      replacements +=
        convertToCommentsCommon +
        [
         [' :', ':'],
        ]
    when 'PADDQ'
      replacements +=
        [[': ', ":\n"]] +
        convertToCommentsCommon
    when 'CMPPD', 'CMPSS'
      input += "\nESAC;"
    when 'PABSB/PABSW/PABSD'
      replacements << repeatComment
    when 'POP'
      replacements +=
        [
         [/1\..+?ELSE/m, 'ELSE'],
         [/^Loading.+/, lambda { |x| createComment(x) }],
         [/\n(OR|AND)/, lambda { |x| x.gsub("\n", ' ') }],
         ['PREOTECTED MODE OR COMPATIBILITY MODE;', '(* PROTECTED MODE OR COMPATIBILITY MODE *)'],
         ["FI;\nIF segment not marked present\n#NP(selector);\nELSE", "FI;\nIF segment not marked present\n#NP(selector);\nFI;\nELSE"],
        ]
    when 'POPF/POPFD/POPFQ'
      replacements +=
        [
         ["(* All non-reserved flags can be modified. *)\nFI;\nELSE", "(* All non-reserved flags can be modified. *)\nFI;\nFI;\nELSE"],
         repeatComment,
        ]
    end

    output = replaceStrings(input, replacements)
    case instruction
    when'CMPS/CMPSB/CMPSW/CMPSD/CMPSQ'
      output += "\nFI;"
    when 'PSIGNB/PSIGNW/PSIGND'
      fiCount = 0
      lines = output.split("\n")
      lines.each do |line|
        if line.matchLeft('IF')
          fiCount += 1
        elsif line.matchLeft('(*')
          line.replace(line + "\n" + ("FI;\n" * fiCount))
          fiCount = 0
        end
      end
      output = lines.join("\n")
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
    pattern = /<P>Operation <\/P>(.+?)<P>(Flags Affected|Intel C.+? Compiler Intrinsic Equivalents?) <\/P>/m
    match = content.match(pattern)
    return nil if match == nil
    operationContent = match[1]
    lines = []
    operationContent.scan(/<P>(.+?)<\/P>/m) do |match|
      token = match[0].strip
      token = replaceCommonStrings(token)
      lines << token
    end

    code = operationReplacements(instruction, lines.join("\n"))
    return code if code == nil
    codeLines = code.split("\n")

    output = calculatePseudoCodeIndentation(codeLines)
    unicodeCheck(instruction, output)
    output = output.join("\n")
    return output
  end
end
