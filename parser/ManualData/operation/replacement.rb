# -*- coding: utf-8 -*-
class ManualData
  def operationReplacements(instruction, input)
    replacements = getGlobalOperatorReplacements

    convertToComments = [/^.+:$/, lambda { |x| createComment(x[0][0..-2]) }]
    convertToCommentsCommon =
      [
       [': ', ":\n"],
       convertToComments,
      ]

    repeatComment = [/^Repeat.+/, method(:createComment)]

    insertBreaks = [/:\n.+/, lambda { |x| x[0] + "\nBREAK;" }]

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
    when 'F2XM1'
      return 'ST(0) = (pow(2, ST(0)) - 1);'
    when 'FICOM/FICOMP', 'FUCOM/FUCOMP/FUCOMPP'
      replacements << insertBreaks
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
         [/INTRA-PRIVILEGE-LEVEL-INTERRUPT.+?END;/m, lambda { |x| x[0].gsub('IF (IA32_EFER.LMA = 0) (* Not IA-32e mode *)', "FI;\nFI;\nIF (IA32_EFER.LMA = 0) (* Not IA-32e mode *)") }],
         [/IF IDT gate is 32-bit.+?FI; /m, lambda { |x| x[0].gsub('FI; ', '') }],
         ['IDT gate is 16-bit)', 'IDT gate is 16-bit *)'],
         ['*)IF', "*)\nIF"],
         ['(error code pushed)or', '(error code pushed) or'],
         [')#SS', ")\n#SS"],
         [/INTRA-PRIVILEGE-LEVEL-INTERRUPT:.+?END;/m, lambda { |x| x[0].gsub("IF = 0;\n(* Interrupt flag set to 0;interrupts disabled *)", "IF = 0;\nFI;\n(* Interrupt flag set to 0;interrupts disabled *)") }],
         ["\nor", ' or'],
         [/INTERRUPT-FROM-VIRTUAL-8086-MODE:.+/m, lambda { |x| x[0].gsub("));\n(* idt operand", "));\nFI;\n(* idt operand") }],
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
         [/FOR each of segment register \(ES, FS, GS, and DS\).+?END;/m, lambda { |x| x[0].gsub("END;", "ROF;\nEND;") }],
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
    when 'MAXPD', 'MAXPS', 'MINPD', 'MINPS'
      replacements +=
        [
         ['= IF', "=\nIF"],
         ["\nFI;", ''],
         ["\nDEST[127:64] =", "\nFI;\nFI;\nFI;\nFI;\nDEST[127:64] ="],
         ['@', "\nFI;\nFI;\nFI;\nFI;"],
        ]
      input += '@'
    when 'MAXSD', 'MAXSS'
      replacements +=
        [
         ['= IF', "=\nIF"],
         ["\nFI;", ''],
         ['IF (DEST[63:0] = SNaN)', "ELSE\nIF (DEST[63:0] = SNaN)"],
         ["(*", "FI;\nFI;\nFI;\nFI;\n(*"],
        ]
    when 'MINSD', 'MINSS'
      replacements +=
        [
         ['= IF', "=\nIF"],
         ["\nFI;", ''],
         [" (*", "\nFI;\nFI;\nFI;\nFI;\n(*"],
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
         [/IF \(OperandSize = \d+\) /, lambda { |x| x[0].strip + "\n" }],
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
         [/\n(OR|AND)/, lambda { |x| x[0].gsub("\n", ' ') }],
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
      replacements =
        [[/^Further.+/, '']] +
        replacements +
        [[" (see Section 22.7, in the\nIntel® 64 and IA-32 \nArchitectures Software Developer's Manual, Volume 3B\n);", "; (* see Section 22.7, in the Intel® 64 and IA-32 Architectures Software Developer's Manual, Volume 3B *)"]]
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
    when 'GETSEC[PARAMETERS]'
       replacements +=
        [
         ["IF (EBX = 0)", "FI;\nFI;\nFI;\nIF (EBX = 0)"],
         ['¨ ', ' = '],
         ['END;', "FI;\nFI;\nEND;"],
        ]
    when 'GETSEC[SMCTRL]'
      replacements << ["END", ("FI;\n" * 3) + "END;"]
    when 'GETSEC[WAKEUP]'
      replacements +=
        [
         ["SignalTXTMsg(WAKEUP);\nEND;", "SignalTXTMsg(WAKEUP);\nFI;"],
         ["RLP_SIPI_WAKEUP_FROM_SENTER_ROUTINE: (RLP only)", "FI;\nFI;\nFI;\n(* RLP_SIPI_WAKEUP_FROM_SENTER_ROUTINE: (RLP only) *)"],
         ["WHILE (no SignalWAKEUP event);", "WHILE (no SignalWAKEUP event)\nELIHW;"],
         ["IF (IA32_SMM_MONITOR_CTL[0] = 0)", "FI;\nIF (IA32_SMM_MONITOR_CTL[0] = 0)"],
         ["Mask A20M, and NMI external pin events (unmask INIT);", "FI;\nMask A20M, and NMI external pin events (unmask INIT);"],
         ["IF ((TempSegSel > TempGDTRLIMIT-15) or (TempSegSel < 8))", "FI;\nIF ((TempSegSel > TempGDTRLIMIT-15) or (TempSegSel < 8))"],
         ["IF ((TempSegSel.TI = 1) or (TempSegSel.RPL!= 0))", "FI;\nIF ((TempSegSel.TI = 1) or (TempSegSel.RPL!= 0))"],
         ["CR0.[PG, CD, W, AM, WP] = 0;", "FI;\nCR0.[PG, CD, W, AM, WP] = 0;"],
         ["END;", ''],
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
    when 'VMLAUNCH/VMRESUME'
      #puts output
      #exit
    end
    return output
  end
end
