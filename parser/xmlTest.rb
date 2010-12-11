require_relative 'XMLParser'

data = '<a>left <b><c/>inner</b> right</a>'

puts data
parser = XMLParser.new
output = parser.parse(data)
puts output.inspect
puts output.visualise
