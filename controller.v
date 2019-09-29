module animationclock (input clk, output [7:0] animationcounter, output [7:0] stepclock);
	reg [32:0] count;

	assign animationcounter[7:0] = count[28:21];
	assign stepclock[7:0] = count[32:25];
	
	always @(posedge clk) begin
		count <= count + 1;
    end
endmodule

module ledcontroller (input clk, input [7:0] mode, input [7:0] ledindex, input [7:0] animationcounter, input [7:0] stepclock, output reg [7:0] red, output reg [7:0] green, output reg [7:0] blue);

	wire [1:0] colindex;

	wire [15:0] fractionalposition;
	wire [15:0] proxa;
	wire [7:0] proximity;

	assign colindex[1:0] = stepclock[1:0] + ledindex;
	assign fractionalposition=animationcounter*49; // Number of leds in the string goes here
	assign proxa[15:0] = (fractionalposition>{ ledindex, 8'h00}) ? (fractionalposition-{ ledindex, 8'h00} ) : ({ ledindex, 8'h00}-fractionalposition);
	assign proximity[7:0] = (proxa>=1024) ? 0 : (proxa<=8) ? 255: 256-(proxa/4);

	always @(posedge clk) begin
		case (mode)
			0: begin
				// Red, Green, Blue, Yellow stepped
				case (colindex)
					0: begin
						red[7:0] <= (8'hFF);
						green[7:0] <= (8'h00);
						blue[7:0] <= (8'h00);
					end
					1: begin
						red[7:0] <= (8'h00);
						green[7:0] <= (8'hFF);
						blue[7:0] <= (8'h00);
					end
					2: begin
						red[7:0] <= (8'h00);
						green[7:0] <= (8'h00);
						blue[7:0] <= (8'hFF);
					end
					3: begin
						red[7:0] <= (8'hFF);
						green[7:0] <= (8'hFF);
						blue[7:0] <= (8'h00);
					end
				endcase
			end
			1: begin
				// Faded block running up
				red[7:0] <= (8'h00);
				green[7:0] <= (8'h00);
				blue[7:0] <= proximity[7:0];
			end
			default: begin
				red[7:0] <= (8'h00);
				green[7:0] <= (8'h00);
				blue[7:0] <= (8'h00);
			end			
		endcase
    end

endmodule