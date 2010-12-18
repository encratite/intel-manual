class XMLNode
  #if it's the root node, then the tag is nil
  #if it's a <tag /> without any content, then this member will be nil
  attr_accessor :tag, :attributes, :content, :parent

  def initialize
    @content = []
  end

  def set(parent, tag, attributes)
    @parent = parent
    @tag = tag
    @attributes = attributes
  end

  def add(element)
    @content << element
  end

  def visualiseContent
    output = ''
    content.each do |i|
      if i.class == XMLNode
        output += i.visualise
      else
        output += i
      end
    end
    return output
  end

  def mainString
    output = @tag
    @attributes.each do |key, value|
      output += " #{key}=\"#{value}\""
    end
    return output
  end

  def visualise
    if @tag == nil
      output = visualiseContent
    else
      if @content == nil
        output = "<#{mainString} />"
      else
        output = "<#{mainString}>#{visualiseContent}</#{@tag}>"
      end
    end
    return output
  end

  def each(&block)
    if @content == nil
      return
    end
    @content.each do |element|
      block.call(element)
    end
  end

  def eachNode(&block)
    each do |element|
      if element.class == XMLNode
        block.call(element)
      end
    end
  end
end
