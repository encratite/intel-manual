# -*- coding: utf-8 -*-

class ManualData
  def replaceCommonStrings(input)
    replacements =
      [
       ["\u201C", '"'],
       ["\u201D", '"'],
       ["&quot;", '"'],
       ["\uF02B", '+'],
       ["\uF02A", '*'],
       ["\u2019", "'"],
       ["\uF070", 'π'],
       ["\uF0A5", '∞'],
       ["\uF0AC", '='],
       ["\uF02D", '-'],
       ['log210', 'log<sub>2</sub>(10)'],
       ['log102', 'log<sub>10</sub>(2)'],
       ['log2e', 'log<sub>2</sub>(e)'],
       ['loge2', 'log<sub>e</sub>(2)'],
       ['  ', ' '],
       [" \n", "\n"],
      ]

    return replaceStrings(input, replacements)
  end

  def replaceStrings(element, replacements)
    output = element
    replacements.each do |target, replacement|
      if replacement.class == String
        output = element.gsub(target, replacement)
      else
        output = element.gsub(target) do |match|
          replacement.call(match)
        end
      end
    end
    return output
  end
end
