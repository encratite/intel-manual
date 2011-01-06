require_relative '../parser/ManualData'

text = "EAX EBX ECX EDX Version Information: Type, Family, Model, and Stepping ID (see Figure 3-5) Bits 7-0: Brand Index Bits 15-8: CLFLUSH line size (Value * 8 = cache line size in bytes) Bits 23-16: Maximum number of addressable IDs for logical processors in this physical package*. Bits 31-24: Initial APIC ID Feature Information (see Figure 3-6 and Table 3-15) Feature Information (see Figure 3-7 and Table 3-16) NOTES: * The nearest power-of-2 integer that is not smaller than EBX[23:16] is the number of unique initial APIC IDs reserved for addressing different logical processors in a physical package."

delimiters = [
              'Bits',
              'Feature',
             ]

stringCounts = [1, 4, 2]

puts ManualData.new.cpuidParseRegisterInformation(text, delimiters, stringCounts).inspect
