require 'nil/file'

def performReplacements(string)
  replacements =
    [
     ["\uF02D", '-'],
     ["\u2022", '&infin;'],
     ["\uF02B", '+'],
     ["\uF020", ''],
     ["\uF02F", '/'],
     ["\uF070", '&pi;'],
     ["\uF0B1", '&plusmn;'],
     [';*', '; *'],
     ['*+', '* +'],
     ['- F', '-F'],
     ['F+', 'F +'],
     ['+ &', ' +&'],
     ['- 0', '-0'],
     ['0NaN', '0 NaN'],
     ['F-', 'F -'],
     ['0+', '0 +'],
     ['0-', '0 -'],
     [';to', ';@to@'],
     [' or ', '@or'],
     ['***', '** *'],
     ['***', '** *'],
     ['0*', '0 *'],
    ]

  replacements.each do |target, replacement|
    string = string.gsub(target, replacement)
  end

  return string
end

if ARGV.size != 1
  puts '<path to pasted table file contents>'
  exit
end

path = ARGV[0]
lines = Nil.readLines(path)
if lines == nil
  puts "Unable to read #{path}"
  exit
end

lines.each do |line|
  line.force_encoding('utf-8')
  line.replace(performReplacements(line))
  puts line.inspect
end

#exit

puts '<table>'
first = true
lines.each do |line|
  puts '<tr>'
  if first
    first = false
    puts '<td />'
  end
  tokens = line.split(' ')
  tokens.each do |token|
    token = token.gsub('@', ' ')
    puts "<td>#{token}</td>"
  end
  puts '</tr>'
end
puts '</table>'
