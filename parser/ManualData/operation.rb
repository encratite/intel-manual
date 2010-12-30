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
      if line.inspect.index("\\u") != nil && line.inspect.index("\\u00AE") == nil #ignore copyright thing
        puts "Discovered unprocessed Unicode content in instruction #{instruction}: #{line.inspect}"
      end
    end
  end

  def loadHardCodedOperation(instruction)
    data = Nil.readFile("../hard-coded/#{instruction}")
    return data if data == nil
    data.force_encoding('utf-8')
    return data
  end

  def extractOperation(instruction, content)
    hardCodedData = loadHardCodedOperation(instruction)
    if hardCodedData != nil
      hardCodedData = replaceCommonStrings(hardCodedData)
      code = operationReplacements(instruction, hardCodedData)
    else
      case instruction
      when 'FNOP', 'NOP'
        return '(* No operation *)'
      when 'PCMPESTRI', 'PCMPESTRM', 'PCMPISTRI', 'PCMPISTRM'
        return nil
      end
      pattern = /(?:<TH>Operation <\/TH>|<P>(?:Operation|Operation in a Uni-Processor Platform) <\/P>)(.+?)<P>(?:Flags Affected|Intel C.+? Compiler Intrinsic Equivalents?|IA-32e Mode Operation|FPU Flags Affected|x87 FPU and SIMD Floating-Point Exceptions|Protected Mode Exceptions|Intel.+?Compiler Intrinsic Equivalent|Numeric Exceptions) <\/P>/m
      match = content.match(pattern)
      error "Unable to parse operation" if match == nil
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
    end
    return code if code == nil
    codeLines = code.split("\n")
    
    output = calculatePseudoCodeIndentation(codeLines)
    unicodeCheck(instruction, output)
    output = output.join("\n")
    return output
  end
end
