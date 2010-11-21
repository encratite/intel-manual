require 'nil/file'

require_relative 'ManualData'

if ARGV.size < 2
	puts '<SQL output path> <input paths>'
	exit
end

outputPath = ARGV[0]
inputPaths = ARGV[1..-1]

manualData = ManualData.new
inputPaths.each do |path|
	manualData.processPath(path)
end
