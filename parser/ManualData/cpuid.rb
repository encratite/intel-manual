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
        if string[i..-1].matchLeft(delimiter) && i > lastTokenOffset
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

  def cpuidGenerateRegisterInformationMarkup(registerObjects, notes)
    output = "<table>\n"
    registerObjects.each do |registerObject|
      output += "<tr>\n"
      output += "<td>#{registerObject.register}</td>\n"
      output += "<td>#{registerObject.strings.first}</td>\n"
      registerObject.strings[1..-1].each do |string|
        output += "<tr>"
        output += "<td />\n"
        output += "<td>#{string}</td>\n"
        output += "</tr>"
      end
      output += "</tr>\n"
    end
    output += "</table>\n"
    if !notes.empty?
      output += "<ul>\n"
      output += "<li><b>Notes:</b></li>\n"
      notes.each do |text|
        output += "<li>#{text}</li>\n"
      end
      output += "</ul>\n"
    end
    return output
  end

  def cpuidParseRegisterInformation(text, delimiters, stringCounts, notes = [])
    pattern = /(.+?) NOTES: (.+)/
    match = text.match(pattern)
    if match != nil
      text = match[1]
      notes << match[2]
    end
    pattern = /^(E[ABCD]X )+(.+)/
    match = text.match(pattern)
    if match == nil
      error 'Unable to get a register match'
    end
    registerString = text[0, match.offset(1)[1]]
    registers = registerString.strip.split(' ')
    text = match[2].strip
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
    registerObjects = []
    registers.each do |register|
      stringCount = stringCounts[registerIndex]
      registerTokens = tokens[tokenIndex, stringCount]
      tokenIndex += stringCount
      registerIndex += 1
      registerObjects << RegisterInformation.new(register, registerTokens)
    end
    return cpuidGenerateRegisterInformationMarkup(registerObjects, notes)
  end
end
