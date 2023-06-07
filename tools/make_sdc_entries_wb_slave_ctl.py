
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
    #Wishbone
    for i in range(4):
      print(command+" [get_ports {wb_sel_i["+str(i)+"]}]")

    for i in range(32):
        print(command+" [get_ports {wb_adr_i["+str(i)+"]}]")
        print(command+" [get_ports {wb_data_i["+str(i)+"]}]")
        print(command+" [get_ports {wb_data_o["+str(i)+"]}]")

    print(command+" [get_ports {wb_rst_i}]")
    print(command+" [get_ports {wb_stb_i}]")
    print(command+" [get_ports {wb_cyc_i}]")
    print(command+" [get_ports {wb_we_i}]")
    print(command+" [get_ports {wb_ack_o}]")

    # System stuff
    print(command+" [get_ports {reset}]")
    print(command+" [get_ports {finished}]")
    for i in range(32):
        print(command+" [get_ports {status["+str(i)+"]}]")
        print(command+" [get_ports {operation["+str(i)+"]}]")
        print(command+" [get_ports {wbctrl_mem_addr["+str(i)+"]}]")
        print(command+" [get_ports {wbctrl_mem_data["+str(i)+"]}]")
        print(command+" [get_ports {sram_data["+str(i)+"]}]")
    
    for i in range(2):
      print(command+" [get_ports {wbctrl_mem_op["+str(i)+"]}]")

    for i in range(3):
      print(command+" [get_ports {irq["+str(i)+"]}]")

    for i in range(128):
      print(command+" [get_ports {la_data_in["+str(i)+"]}]")
      print(command+" [get_ports {la_data_out["+str(i)+"]}]")
      print(command+" [get_ports {la_oenb["+str(i)+"]}]")
    
    
    for i in range(16):
      print(command+" [get_ports {io_in["+str(i)+"]}]")
      print(command+" [get_ports {io_out["+str(i)+"]}]")
      print(command+" [get_ports {io_oeb["+str(i)+"]}]")

