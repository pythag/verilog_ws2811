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
    .mode(8'd1),
    .colmode(3'd5),
    .usera_red(8'd50),
    .usera_green(8'd0),
    .usera_blue(8'd0),
    .userb_red(8'd0),
    .userb_green(8'd0),
    .userb_blue(8'd50),
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
