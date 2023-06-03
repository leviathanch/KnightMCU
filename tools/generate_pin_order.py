
buses = [
  "data_i",
  "data_o",
  "addr_o"
]

for b in buses:
  for i in range(32):
      print(b+"\\["+str(i)+"\\]")
