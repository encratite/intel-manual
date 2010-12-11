require_relative 'XMLNode'

class XMLParser
	def parseMarkup(markup, offset = 0)
		content = []
		while offset < markup.size
			tagOffset = markup.index('<', offset)
			break if tagOffset == nil
			if offset != tagOffset
				string = markup[offset..tagOffset - 1]
				content << string
			end
			tagOffset += 1
			endOfTag = markup.index('>', tagOffset)
			tagContent = markup[tagOffset..endOfTag - 1]
			tagPattern = /^\s*([A-Za-z])+\s*$|^\s*\/\s*([A-Za-z])+$|^\s*([A-Za-z])\s*\/\s*$/
			match = tagContent.match(tagPattern)
			if match == nil
				raise "Invalid tag content: #{tagContent}"
			end
			offset = endOfTag + 1
			if match[1] != nil
				#new tag
				tag = match[1]
				tagContent, offset = parseMarkup(markup, offset)
				node = XMLNode.new(tag, tagContent)
				content << node
			elsif match[2] != nil
				#regular closing tag
				tag = match[2]
				#can't be bothered to check the tag and such really, that would require a stack check
				#I am basically presuming that the XML input is not totally malformed, which should be the case here
				return content, offset
			else
				#tag without content
				tag = match[3]
				node = XMLNode.new(tag, nil)
				content << node
			end
		end
		if offset != markup.size
			string = markup[offset..-1]
			content << string
		end
		return content, offset
	end

	def parse(input)
		content, offset = parseMarkup(input)
		output = XMLNode.new(nil, content)
		return output
	end
end
