class ManualData
  def extractOperation(content)
    pattern = /<P>Operation <\/P>(.+?)<P>Flags Affected <\/P>/
    match = content.match(pattern)
    return nil if match == nil
    operationContent = match[1]
    lines = []
    operationContent.scan(/<P>(.+?)<\/P>/m) do |match|
      token = performCommonReplacements(match[0])
      token.gsub!(/; [^\(]/) do |match|
        match.gsub(' ', "\n")
      end
      lines += token.split("\n")
    end
  end
end
