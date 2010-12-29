# -*- coding: utf-8 -*-

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

      cpuidMatch = line == 'DEFAULT: (* EAX = Value outside of recognized range for CPUID. *)'
      rclMatch = line.match(/^SIZE = \d+:$/)

      if cpuidMatch || rclMatch
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
      when 'CASE', 'WHILE', 'FOR'
        addLine.call(0, 1)
      when 'END', 'ESAC', 'ELIHW', 'ROF'
        addLine.call(-1, 0)
      when 'BREAK'
        addLine.call(0, -1)
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
       [/(^(BIT_REFLECT|MOD2).+)|Non-64-bit Mode:|FI64-bit Mode:/, method(:createComment)],
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
       [/^[A-Z]+ (instruction )?(with|for) \d+[- ][Bb]it.+?operand.*$/, method(:createComment)],
       [/^(64-BIT_MODE|64-bit Mode:)$/, method(:createComment)],
       ['ELSEIF', "ELSE\nIF"],
       ['ELSIF', "ELSE\nIF"],
       [/,[^ ]/, lambda { |x| ', ' + x[1..-1] }],
       [';FI;', ";\nFI;"],
       ['FI;FI;', "FI;\nFI;"],
       [';(*', '; (*'],
       ['*)IF', "*)\nIF"],
       [/[^ ]\*\)/, lambda { |x| x[0] + ' *)' }],
       ["\nDO\n", "\n"],
       ["\nOD;", ''],
       [/\/\/ *.+/, lambda { |x| createComment(x[2..-1].strip) }],
       ["\t", ''],
       [/ +/, ' '],
       #["*) ", "*)\n"],
       [/[^ =!]=/, lambda { |x| x[0] + ' =' }],
       [/=[^ =!]/, lambda { |x| '= ' + x[-1]  }],
       [/ (or|OR|and|AND)\n/, lambda { |x| x[0..-2] + ' ' }],
       ['> =', '>='],
       ['< =', '<='],
      ]

    convertToComments = [/^.+:$/, lambda { |x| createComment(x[0..-2]) }]
    convertToCommentsCommon =
      [
       [': ', ":\n"],
       convertToComments,
      ]

    repeatComment = [/^Repeat.+/, method(:createComment)]

    sanityCheckString = nil

    case instruction
    when 'CRC32'
      replacements +=
        [
         ["Notes:\n", ''],
         [/^CRC32 instruction.+/, method(:createComment)],
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
         [/^Repeat operation.+/, method(:createComment)],
         ['otherwise, EXT is ELSE', "otherwise, EXT is 1. *)"],
         ['(* PE = 1 *)', 'IF PE = 1'],
         ['REAL-ADDRESS-MODE:', "FI;\nREAL-ADDRESS-MODE:"],
        ]
    when 'IRET/IRETD'
      replacements +=
        [
         ["\nREAL-ADDRESS-MODE;", "\nREAL-ADDRESS-MODE:"],
         ['IA-32e-MODE:', "END;\nIA-32e-MODE:"],
         ['GOTO IA-32e-MODE-RETURN;', "FI;\nGOTO IA-32e-MODE-RETURN;\nEND;\n"],
         [/FOR each of segment register \(ES, FS, GS, and DS\).+?END;/m, lambda { |x| x.gsub("END;", "ROF;\nEND;") }],
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
    when 'MOV'
      replacements +=
        [
         [/^Loading.+points\.$/, method(:createComment)],
         ["\nor", ' or'],
         #[/1\..+?ELSE/m, 'ELSE'],
         [/1\..+?EBP\n/m, ''],
        ]
      #sanityCheckString = 'If a code instruction breakpoint'
      #puts sanityCheckString
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
    when 'MWAIT'
      replacements =
        [
         ['{', ''],
         ['}', ''],
        ] + replacements +
        [
         ['Set the stat', "ELIHW;\nSet the stat"],
        ]
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
         [/^Loading.+/, method(:createComment)],
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
    when 'PSIGNB/PSIGNW/PSIGND'
      replacements +=
        [
         [' Repeat', "\nRepeat"],
         repeatComment,
         [') D', ")\nD"],
        ]
    when 'PSUBQ'
      replacements = [[': DEST', ":\nDEST"]] + replacements
    when 'PUSHF/PUSHFD'
      input += "\nFI;"
    when 'RCL/RCR/ROL/ROR'
      replacements +=
        [
         ['2SIZE', 'pow(2, SIZE'],
         ["tempCOUNT = tempCOUNT - 1;\n(* ROL and ROR instructions *)", "tempCOUNT = tempCOUNT - 1;\nELIHW;\n(* ROL and ROR instructions *)"],
        ]
    when 'RDPMC'
      replacements +=
        [
         [/^Most.+/, method(:createComment)],
         ["(* Intel Core 2 Duo processor family and Intel Xeon processor 3000, 5100, 5300, 7400 series *)", "FI;\nFI;\n(* Intel Core 2 Duo processor family and Intel Xeon processor 3000, 5100, 5300, 7400 series *)"],
         ["(* P6 family processors and Pentium processor with MMX technology *)", "FI;\nFI;\nFI;\n(* P6 family processors and Pentium processor with MMX technology *)"],
         ["FI; (* Processors with CPUID family 15 *)", "FI;\n(* Processors with CPUID family 15 *)"],
        ]
      input += "\nFI;\nFI;"
    when 'REP/REPE/REPZ/REPNE/REPNZ'
      input += "\nELIHW;"
    when 'SAL/SAR/SHL/SHR'
      replacements +=
        [
         ["FI\n", "FI;\n"],
         ["tempCOUNT = tempCOUNT - 1;", "tempCOUNT = tempCOUNT - 1;\nELIHW;"],
        ]
    when 'SCAS/SCASB/SCASW/SCASD'
      replacements << [/^F$/, 'FI;']
    when 'STI'
      replacements +=
        [
         ["FI;)", 'FI;'],
        ]
    when 'TEST'
      replacements << ['FI:', 'FI;']
    when 'XSAVE'
      input += "\nROF;"
    when 'INVEPT'
      #somewhat guessed
      input += "\nFI;\nFI;"
    when 'INVVPID'
      #guessed, too
      input += "\nFI;\nFI;"
    when 'VMCALL'
      replacements +=
        [
         ["\nof", " of"],
         ["\nIntel", " Intel"],
         ["Archi\n", "Archi"],
         ['  ', ' '],
         #["active\n", "active "],
         [" \nin", " in"],
         [" \n", " "],
         ["\n)", ")"],
         ["read revision identifier in MSEG;", "read revision identifier in MSEG;" + ("FI;\n" * 9)],
        ]
    when 'VMCLEAR'
      replacements +=
        [
         ["OR\n", "OR "],
         ["and\n", "and "],
        ]
      #guessed
      input += "\nFI;" * 3
    when 'VMLAUNCH/VMRESUME'
      replacements = [[/^Further.+/, '']] + replacements
      input += "\nFI;" * 6
    when 'VMPTRLD'
      replacements =
        [
         [/1\..+?\)\./m, '']
        ] + replacements
      input += "\nFI;" * 3
    when 'VMPTRST'
      input += "\nFI;" * 2
    when 'VMREAD'
      input += "\nFI;" * 4
    when 'VMWRITE'
      input += "\nFI;" * 5
    when 'VMXOFF'
      replacements +=
        [
         ['IF outside SMX operation2', "(* A logical processor is outside SMX operation if GETSEC[SENTER] has not been executed or if GETSEC[SEXIT] was executed after the last execution of GETSEC[SENTER]. See Chapter 6, Safer Mode Extensions Reference. *)\nIF outside SMX operation"],
        ]
      input += "\nFI;" * 3
    when 'VMXON'
      replacements +=
        [
         ["or\n", "or "],
         ["and\n", "and "],
         [/operation\d/, 'operation'],
        ]
      input += "\nFI;" * 3
    when 'GETSEC[CAPABILITIES]'
      replacements +=
        [
         ["1;\n", "1;\nFI;\n"],
         ['VM Exit (reason = "GETSEC instruction");', "VM Exit (reason =\"GETSEC instruction\");\nFI;"],
         [';;', ';'],
         ["END;", "FI;\nEND;"],
        ]
    when 'GETSEC[ENTERACCS]'
      replacements =
        [["OD;", "FI;\nROF;"]] +
        replacements +
        [
         ["FOR I = 0 to IA32_MCG_CAP.COUNT-1 DO", ("FI;\n" * 4) + "FOR I = 0 to IA32_MCG_CAP.COUNT - 1"],
         ["ACBASE = EBX;", "FI;\nACBASE = EBX;"],
         ["IF (secondary thread(s)", "FI;\nIF (secondary thread(s)"],
         ['Mask SMI', "FI;\nMask SMI"],
         ['IF (AC module header version', "FI;\nIF (AC module header version"],
         ['(* Authenticate', "FI;\n(* Authenticate"],
         ["SIGNATURE = DECRYPT", "FI;\nSIGNATURE = DECRYPT"],
         ["COMPUTEDSIGNATURE = HASH", "ROF;\nCOMPUTEDSIGNATURE = HASH"],
         ["IF (SIGNATURE<>COMPUTEDSIGNATURE)", "ROF;\nIF (SIGNATURE<>COMPUTEDSIGNATURE)"],
         ["ACMCONTROL = ACRAM[CodeControl];", "FI;\nACMCONTROL = ACRAM[CodeControl];"],
         ["IF (ACMCONTROL reserved bits are set)", "FI;\nIF (ACMCONTROL reserved bits are set)"],
         ["IF ((ACRAM[GDTBasePtr] < ", "FI;\nIF ((ACRAM[GDTBasePtr] < "],
         ["IF ((ACMCONTROL.0 = 1)", "FI;\nIF ((ACMCONTROL.0 = 1)"],
         ["IF ((ACEntryPoint ", "FI;\nIF ((ACEntryPoint "],
         [")))TXT-SHUTDOWN(#BadACMFormat);", ")))\nTXT-SHUTDOWN(#BadACMFormat);\nFI;"],
         ["IF ((ACRAM[SegSel] >", "FI;\nIF ((ACRAM[SegSel] >"],
         ["IF ((ACRAM[SegSel].TI = 1)", "FI;\nIF ((ACRAM[SegSel].TI = 1)"],
        ]
    when 'GETSEC[EXITACCS]'
      replacements +=
        [
         ['instructionboundary', 'instruction boundary'],
         ["IF (OperandSize = 32)", ("FI;\n" * 4) + "IF (OperandSize = 32)"],
        ]
    when 'GETSEC[SENTER]'
      replacements +=
        convertToCommentsCommon +
        [
         ['FOR I = 0 to IA32_MCG_CAP.COUNT-1 DO', ("FI;\n" * 4) + "FOR I = 0 to IA32_MCG_CAP.COUNT - 1"],
         ["IF (IA32_MCG_STATUS.MCIP = 1) or (IERR pin is asserted)", "ROF;\nIF (IA32_MCG_STATUS.MCIP = 1) or (IERR pin is asserted)"],
         ["ACBASE = EBX;", "FI;\nACBASE = EBX;"],
         ["Mask SMI, INIT, A20M, and NMI external pin events;", "FI;\nMask SMI, INIT, A20M, and NMI external pin events;"],
         ["TXT-SHUTDOWN(#IllegalEvent);\nFI;\nFI;\nFI;\nFI;", "TXT-SHUTDOWN(#IllegalEvent);\nFI;"],
         ["IF (Voltage or bus ratio status are NOT at a known good state)", "FI;\nIF (Voltage or bus ratio status are NOT at a known good state)"],
         ["IA32_MISC_ENABLE = (IA32_MISC_ENABLE & MASK_CONST *)", "FI;\nIA32_MISC_ENABLE = (IA32_MISC_ENABLE & MASK_CONST *)"],
         ["DONE = TXT.READ(LT.STS);\nWHILE (not DONE);", "DONE = FALSE;\nWHILE (not DONE)\nDONE = TXT.READ(LT.STS);\nELIHW;"],
         ["DONE = FALSE;", "FI;\nDONE = FALSE;"],
         ["IF (ACRAM memory type != WB)", "ROF;\nIF (ACRAM memory type != WB)"],
         ["IF (AC module header version is not supported) OR (ACRAM[ModuleType] <> 2)", "FI;\nIF (AC module header version is not supported) OR (ACRAM[ModuleType] <> 2)"],
         ["KEY = GETKEY(ACRAM, ACBASE);", "FI;\nKEY = GETKEY(ACRAM, ACBASE);"],
         ["SIGNATURE = DECRYPT(ACRAM, ACBASE, KEY);", "FI;\nSIGNATURE = DECRYPT(ACRAM, ACBASE, KEY);"],
         ["COMPUTEDSIGNATURE = HASH(ACRAM, ACBASE, ACSIZE);", "ROF;\nCOMPUTEDSIGNATURE = HASH(ACRAM, ACBASE, ACSIZE);"],
         ["IF (SIGNATURE != COMPUTEDSIGNATURE)", "ROF;\nIF (SIGNATURE != COMPUTEDSIGNATURE)"],
         ["ACMCONTROL = ACRAM[CodeControl];", "FI;\nACMCONTROL = ACRAM[CodeControl];"],
         ["IF (ACMCONTROL reserved bits are set)", "FI;\nIF (ACMCONTROL reserved bits are set)"],
         ["IF ((ACRAM[GDTBasePtr] < (ACRAM[HeaderLen] ", "FI;\nIF ((ACRAM[GDTBasePtr] < (ACRAM[HeaderLen] "],
         ["IF ((ACMCONTROL.0 = 1) and (ACMCONTROL.1 = 1) and (snoop hit to modified", "FI;\nIF ((ACMCONTROL.0 = 1) and (ACMCONTROL.1 = 1) and (snoop hit to modified"],
         ["IF ((ACEntryPoint > = ACSIZE) or (ACEntryPoint < (ACRAM[HeaderLen] * 4 + Scratch_size)))", "FI;\nIF ((ACEntryPoint > = ACSIZE) or (ACEntryPoint < (ACRAM[HeaderLen] * 4 + Scratch_size)))"],
         ["IF ((ACRAM[SegSel] > (ACRAM[GDTLimit] - 15)) or (ACRAM[SegSel] < 8))", "FI;\nIF ((ACRAM[SegSel] > (ACRAM[GDTLimit] - 15)) or (ACRAM[SegSel] < 8))"],
         ["IF ((ACRAM[SegSel].TI = 1) or (ACRAM[SegSel].RPL!= 0))", "FI;\nIF ((ACRAM[SegSel].TI = 1) or (ACRAM[SegSel].RPL!= 0))"],
         ["ACRAM[SCRATCH.SIGNATURE_LEN_CONST] = EDX;", "FI;\nACRAM[SCRATCH.SIGNATURE_LEN_CONST] = EDX;"],
         ["EIP = ACEntryPoint;\nEND;", "EIP = ACEntryPoint;\nROF;"],
        ]
    when 'GETSEC[SEXIT]'
      replacements +=
        convertToCommentsCommon +
        [
         ["SignalTXTMsg(SEXIT);", "FI;\nFI;\nFI;\nFI;\nSignalTXTMsg(SEXIT);"],
         ["Unmask SMI, INIT, A20M, and NMI external pin events;\nEND;", "Unmask SMI, INIT, A20M, and NMI external pin events;\nELIHW;"],
         ["SignalTXTMsg(SEXITAck);", "FI;\nSignalTXTMsg(SEXITAck);"],
         ["DONE = READ(LT.STS);", "FI;\nDONE = READ(LT.STS);"],
        ]
    end

    output = replaceStrings(input, replacements, sanityCheckString)
    case instruction
    when'CMPS/CMPSB/CMPSW/CMPSD/CMPSQ'
      output += "\nFI;"
    when 'PSIGNB/PSIGNW/PSIGND'
      fiCount = 0
      performReplacement = lambda do |line, isComment = true|
        replacement = "\n" + ("FI;\n" * fiCount)
        replacement += line if isComment
        line.replace(replacement)
        fiCount = 0
      end
      lines = output.split("\n")
      lines.each do |line|
        if line.matchLeft('IF')
          fiCount += 1
        elsif line.matchLeft('(*')
          performReplacement.call(line)
        end
      end
      if !lines.empty?
        performReplacement.call(lines[-1], false)
      end
      output = lines.join("\n")
    when 'GETSEC[SENTER]'
      #puts output
      #exit
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
    pattern = /<P>(?:Operation|Operation in a Uni-Processor Platform) <\/P>(.+?)<P>(Flags Affected|Intel C.+? Compiler Intrinsic Equivalents?|IA-32e Mode Operation) <\/P>/m
    match = content.match(pattern)
    return nil if match == nil
    operationContent = match[1]
    lines = []
    operationContent.scan(/<(?:P|TD)>(.+?)<\/(?:P|TD)>/m) do |match|
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
