require 'rexml/document'


data = '<a>left <b>inner</b> right</a>'
xml = REXML::Document.new(data)
puts xml.elements.inspect
