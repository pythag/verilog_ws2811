###############################################################################
#                                                                             #
# Copyright 2016 myStorm Copyright and related                                #
# rights are licensed under the Solderpad Hardware License, Version 0.51      #
# (the “License”); you may not use this file except in compliance with        #
# the License. You may obtain a copy of the License at                        #
# http://solderpad.org/licenses/SHL-0.51. Unless required by applicable       #
# law or agreed to in writing, software, hardware and materials               #
# distributed under this License is distributed on an “AS IS” BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or             #
# implied. See the License for the specific language governing                #
# permissions and limitations under the License.                              #
#                                                                             #
###############################################################################

chip.bin: chip.v ws2811.v controller.v pll.v ws2811.pcf
	yosys -q -p "synth_ice40 -json chip.json" chip.v ws2811.v pll.v controller.v
	nextpnr-ice40 --hx8k --package tq144:4k --pcf ws2811.pcf --json chip.json --asc chip.txt
	icepack chip.txt chip.bin

pll.v: Makefile
	icepll -i 25 -o 64 -m -f $@

.PHONY: upload
upload:
	scp chip.bin pi@fpgapi:/tmp/
	# stty -F /dev/ttyACM0 raw
	# cat chip.bin >/dev/ttyACM0

.PHONY: clean
clean:
	$(RM) -f chip.json chip.txt chip.ex chip.bin
