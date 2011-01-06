class ManualData
  #determines whether warnings should be printed for a particular instruction
  #I am going to add all the instructions I've already taken care of to this list so they no longer show up in the console all the time
  def isFullyProcessedInstruction(instruction)
    processedInstructions =
      [
       'ADDSUBPS',
       'ADDSUBPD',
       'CLI',
      ]
    return processedInstructions.include?(instruction)
  end
end
