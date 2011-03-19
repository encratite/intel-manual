require 'nil/xml'

class InstructionExceptionEntry < Nil::XMLObject
  attr_reader :name, :description

  def initialize(exception, description)
    super()
    setName('Exception')
    if exception != nil
      @name = exception
    end
    @description = description
  end
end
