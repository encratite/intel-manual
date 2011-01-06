class RegisterInformation
  attr_reader :register, :strings
  def initialize(register, strings)
    @register = register
    @strings = strings
  end
end
