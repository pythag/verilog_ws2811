/******************************************************************************
*                                                                             *
* Copyright 2016 myStorm Copyright and related                                *
* rights are licensed under the Solderpad Hardware License, Version 0.51      *
* (the “License”); you may not use this file except in compliance with        *
* the License. You may obtain a copy of the License at                        *
* http://solderpad.org/licenses/SHL-0.51. Unless required by applicable       *
* law or agreed to in writing, software, hardware and materials               *
* distributed under this License is distributed on an “AS IS” BASIS,          *
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or             *
* implied. See the License for the specific language governing                *
* permissions and limitations under the License.                              *
*                                                                             *
******************************************************************************/
module chip (
    // 25MHz clock input
    input  clk,
    // Led outputs
    output [3:0] led,
    // The WS2811 output
    output dout
  );

  wire clkhigh;

  // turn other leds off (active low)
  assign led[3:1] = 4'b111;
  assign led[0] = stepclock[0];

  reg [7:0] red;
  reg [7:0] green;
  reg [7:0] blue;

  reg [7:0] ledindex;
  reg [7:0] animationcounter;
  reg [7:0] stepclock;

  animationclock theanimationlock
  (
    .clk(clkhigh),
    .animationcounter(animationcounter),
    .stepclock(stepclock)
  );

  ledcontroller thecontroller
  (
    .clk(clkhigh),
    .mode(8'h01),
    .ledindex(ledindex),
    .animationcounter(animationcounter),
    .stepclock(stepclock),
    .red(red),
    .green(green),
    .blue(blue)
  );
  
  ws2811 driver
  (
    .clk(clkhigh),
    .reset(1'b0),

    .address(ledindex),

    .red_in(red),
    .green_in(green),
    .blue_in(blue),

    .DO(dout)
  );
   
  pll u_pll(
      .clock_in(clk),
      .clock_out(clkhigh),
      .locked()
  );

endmodule
