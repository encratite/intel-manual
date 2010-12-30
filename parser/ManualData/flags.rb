class ManualData
  def extractFlagsAffected(instruction, content)
    pattern = /<P>Flags Affected <\/P>(.+?)<P>(?:Protected Mode Exceptions|Exceptions \(All Operating Modes\)|Intel|Use of Prefixes)[^<]*<\/P>/m
    match = content.match(pattern)
    if match == nil
      if content.index(">Flags Affected") != nil
        error "Unable to extract the flags"
      end
      return nil
    end
    output = []
    flagContent = replaceCommonStrings(match[1])
    flagContent.scan(/<P>(.+?) <\/P>/) do |match|
      output << match[0].gsub(/<Link>(.+?)<\/Link>/) do |x|
        x[6..-9]
      end
    end
    return output
  end
end
