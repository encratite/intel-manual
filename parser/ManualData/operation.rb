# -*- coding: utf-8 -*-

require 'nil/string'
require 'nil/file'

require_relative 'string'

require_relative 'operation/global'
require_relative 'operation/indentation'
require_relative 'operation/replacement'

class ManualData
  def applyIndentation(count, line)
    return ("\t" * count) + line
  end

  def createComment(input)
    return "(* #{input} *)"
  end

  def unicodeCheck(instruction, lines)
    lines.each do |line|
      if line.inspect.index("\\u") != nil
        puts "Discovered unprocessed Unicode content in instruction #{instruction}: #{line.inspect}"
      end
    end
  end

  def loadHardCodedOperation(instruction)
    return Nil.readFile("../hard-coded/#{instruction}")
  end

  def extractOperation(instruction, content)
    #hardCodedData = loadHardCodedOperation(instruction)
    #return hardCodedData if hardCodedData != nil
    case instruction
    when 'FNOP'
      return '(* No operation *)'
    end
    pattern = /(?:<TH>Operation <\/TH>|<P>(?:Operation|Operation in a Uni-Processor Platform) <\/P>)(.+?)<P>(?:Flags Affected|Intel C.+? Compiler Intrinsic Equivalents?|IA-32e Mode Operation|FPU Flags Affected|x87 FPU and SIMD Floating-Point Exceptions|Protected Mode Exceptions|Intel.+?Compiler Intrinsic Equivalent) <\/P>/m
    match = content.match(pattern)
    return nil if match == nil
    operationContent = match[1]
    if operationContent == nil
      puts match.inspect
    end
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
