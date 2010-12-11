require_relative 'XMLParser'

data = '<a>left <b><Ctag property="test"/>inner</b> right</a>'

output = XMLParser.parse(data)
puts output.inspect
puts output.visualise
