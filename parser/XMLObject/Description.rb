require 'nil/xml'

class Description < Nil::XMLObject
  def initialize(description)
    super()
    setContent(description)
    setName('Description')
  end
end
