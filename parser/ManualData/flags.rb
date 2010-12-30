class ManualData
  def extractFlagsAffected(instruction, content, mode = :regularFlags)
    targetMap =
      {
      regularFlags: "Flags Affected",
      fpuFlags: "FPU Flags Affected",
    }
    target = targetMap[mode]
    raise "Invalid mode" if target == nil
    pattern = /<P>#{target} <\/P>(.+?)<P>(?:Protected Mode Exceptions|Exceptions \(All Operating Modes\)|Intel|Use of Prefixes|Floating-Point Exceptions)[^<]*<\/P>/m
    match = content.match(pattern)
    if match == nil
      if content.index(">#{target}") != nil
        error "Unable to extract the flags"
      end
      return nil
    end
    output = []
    flagContent = replaceCommonStrings(match[1])
    flagContent.scan(/<(?:P|TD)>(.+?)[ \n]<(?:\/P|TD)>/m) do |match|
      output << match[0].gsub("\n", ' ').gsub(/<Link>(.+?)<\/Link>/) do |x|
        x[6..-9]
      end
    end
    output = output.join(' ')
    if mode == :fpuFlags
      case instruction
      when 'FPREM1'
        return 'C0: Set to bit 2 (Q2) of the quotient. C1: Set to 0 if stack underflow occurred; otherwise, set to least significant bit of quotient (Q0). C2: Set to 0 if reduction complete; set to 1 if incomplete. C3: Set to bit 1 (Q1) of the quotient.'
      when 'FXTRACT'
        return 'C1: Set to 0 if stack underflow occurred; set to 1 if stack overflow occurred. C0, C2, C3 are undefined.'
      end
      replacements =
        [
         ['C1 Set', 'C1: Set'],
         ['C0, C2, C3 Undefined.', 'C0, C2, C3 are undefined.'],
         ['C0, C2, C3 See Table', 'For C0, C2, C3, see Table'],
        ]
      output = replaceStrings(output, replacements)
      if output.empty? || output.index('</')
        puts "#{instruction}: #{flagContent.inspect}"
      else
        #puts "#{instruction}: #{output.inspect}"
      end
    end
    return output
  end
end
