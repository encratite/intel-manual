require 'nil/file'
require 'nil/string'

require_relative 'ManualData'

if ARGV.size < 3
  puts '<XML output path> <description warning output directory> <input paths>'
  exit
end

outputPath = ARGV[0]
descriptionWarningOutputDirectory = ARGV[1]
inputPaths = ARGV[2..-1]

begin
  totalSize = 0
  manualData = ManualData.new(descriptionWarningOutputDirectory)
  inputPaths.each do |path|
    puts "Processing #{path}"
    size = manualData.processPath(path)
    totalSize += size
  end
  puts "Loaded #{manualData.instructionCount} instruction(s) from #{inputPaths.size} file(s) totalling #{Nil.getSizeString(totalSize)} of XML"
  puts "Number of tables: #{manualData.tableCount}"
  puts "Number of images: #{manualData.imageCount}"
  manualData.writeOutput(outputPath)
  puts "Size of XML output: #{Nil.getSizeString(File.size(outputPath))}"
rescue => exception
  puts exception.inspect
  puts exception.backtrace.map { |x| "\t#{x}\n" }
end
