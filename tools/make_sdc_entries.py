
commands = [
  "set_input_delay -max 10 -clock [get_clocks \{clk\}]",
  "set_input_delay -min 0 -clock [get_clocks \{clk\}]",
  "set_input_transition -max 0.44",
  "set_input_transition -min 0.05",
  "set_output_delay -max 10 -clock [get_clocks \{clk\}]",
  "set_output_delay -min 0 -clock [get_clocks \{clk\}]",
  "set_load 0.14"
]

for command in commands:

    for i in range(31):
        print(command+" [get_ports {data_i["+str(i)+"]}]")
        print(command+" [get_ports {data_o["+str(i)+"]}]")
        print(command+" [get_ports {addr_o["+str(i)+"]}]")

    print(command+" [get_ports {reset}]")
    print(command+" [get_ports {enable}]")
    print(command+" [get_ports {done}]")
