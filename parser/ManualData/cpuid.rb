require 'nil/string'

require_relative 'RegisterInformation'

class ManualData
  def parseMergedRegisterString(string, delimiters)
    output = []
    i = 0
    lastTokenOffset = 0
    while i < string.size do
      match = false
      delimiters.each do |delimiter|
        if string[i..-1].matchLeft(delimiter)
          token = string[lastTokenOffset, i - lastTokenOffset].strip
          output << token
          lastTokenOffset = i
          match = true
        end
      end
      i += 1
    end
    lastToken = string[lastTokenOffset..-1]
    output << lastToken
    return output
  end

  def cpuidParseRegisterInformation(text, delimiters, stringCounts)
    notes = nil
    pattern = /(.+?) (NOTES:.+)/
    match = text.match(pattern)
    if match != nil
      text = match[1]
      notes = match[2]
    end
    pattern = /^(E[ABCD]X )+(.+)/
    match = text.match(pattern)
    if match == nil
      error 'Unable to get a register match'
    end
    #puts match.inspect
    registerString = text[0, match.offset(1)[1]]
    puts registerString.inspect
    registers = registerString.strip.split(' ')
    text = match[2]
    tokens = parseMergedRegisterString(text, delimiters)
    if registers.size != stringCounts.size
      error "Register/string count mismatch: #{registers.inspect}, #{stringCounts.inspect}"
    end
    sum = stringCounts.inject(0) { |state, x| state += x }
    if sum != tokens.size
      error "String count sum/token count mismatch: #{sum} vs. #{tokens.size}\n#{stringCounts.inspect}, #{tokens.inspect}"
    end
    tokenIndex = 0
    registerIndex = 0
    output = []
    registers.each do |register|
      stringCount = stringCounts[registerIndex]
      registerTokens = tokens[tokenIndex, stringCount]
      tokenIndex += stringCount
      registerIndex += 1
      output << RegisterInformation.new(register, registerTokens)
    end
    return output
  end
end
