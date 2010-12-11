require 'nil/file'

require_relative 'ManualData'

if ARGV.size < 2
	puts '<SQL output path> <input paths>'
	exit
end

outputPath = ARGV[0]
inputPaths = ARGV[1..-1]

begin
	manualData = ManualData.new
	inputPaths.each do |path|
		puts "Processing #{path}"
		manualData.processPath(path)
	end
	manualData.writeOutput(outputPath)
rescue => exception
	puts exception.inspect
	puts exception.backtrace.map { |x| "\t#{x}\n" }
end
