
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

    for i in range(32):
        print(command+" [get_ports {status["+str(i)+"]}]")
        print(command+" [get_ports {operation["+str(i)+"]}]")

    print(command+" [get_ports {reset}]")
    print(command+" [get_ports {finished}]")
    print(command+" [get_ports {matrix_mult_done}]")
    print(command+" [get_ports {matrix_conv_done}]")
    print(command+" [get_ports {multiplier_enable}]")
    print(command+" [get_ports {convolution_enable}]")
