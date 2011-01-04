# -*- coding: utf-8 -*-
class ManualData
  def replaceCommonStrings(input)
    replacements =
      [
       ["\u201C", '"'],
       ["\u201D", '"'],
       ["\uF02B", '+'],
       ["\uF02A", '*'],
       ["\u2019", "'"],
       ["\uF070", 'π'],
       ["\uF0A5", '∞'],
       ["\uF0AC", '='],
       ["\uF02D", '-'],
       ["\u2013", '-'],
       ["\uF03C", '<'],
       ["\uF03E", '>'],
       ["\uF03D", '='],
       ["\uF0DF", '='],
       ["\uF020", ' '], #what is this?!
       ["\uF0B9", '!='],
       ["\uF0B3", '>='],
       ["\uF0A3", '<='],
       ["\u00AB", '<<'],
       ["\u00BB", '>>'],
       ["\u2022", '='],
       ["\uF028", '('], #very strange... from PANDN
       ["\u20181", "'"], #another odd one, from the ROUND* functions
       ["\uF02F", '/'],

       ['log210', 'log<sub>2</sub>(10)'],
       ['log102', 'log<sub>10</sub>(2)'],
       ['log2e', 'log<sub>2</sub>(e)'],
       ['loge2', 'log<sub>e</sub>(2)'],

       ["&quot;", '"'],
       ['&lt;', '<'],
       ['&gt;', '>'],
       ['&amp;', '&'],

       ["\t", ' '],
       ['  ', ' '],
       [" \n", "\n"],
      ]

    return replaceStrings(input, replacements)
  end

  def replaceStrings(element, replacements, sanityCheckString = nil)
    output = element
    isSane = true
    replacements.each do |target, replacement|
      target.force_encoding('utf-8') if target === String
      begin
        case replacement
        when String
          output = output.gsub(target, replacement)
        when Proc, Method
          output = output.gsub(target) do |match|
            replacement.call(match)
          end
        else
          raise "Invalid replacement object: #{[target, replacement].inspect}, type is #{replacement.class}"
        end

        if isSane && sanityCheckString != nil
          index = output.index(sanityCheckString)
          #puts index
          if index == nil
            raise "Rule responsible for the disappearance of #{sanityCheckString.inspect}: #{[target, replacement].inspect}"
            isSane = false
          end
        end
      rescue Encoding::CompatibilityError => exception
        puts "Rule: #{[target, replacement].inspect}"
        raise exception
      end
    end

    return output
  end
end
