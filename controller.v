module animationclock (input clk, output [7:0] animationcounter, output [7:0] stepclock);
	reg [32:0] count;

	assign animationcounter[7:0] = count[28:21];
	assign stepclock[7:0] = count[32:25];
	
	always @(posedge clk) begin
		count <= count + 1;
    end
endmodule

module ledcontroller (
	input clk, 
	input [7:0] mode, 
	input [2:0] colmode, 
	input [7:0] usera_red,
	input [7:0] usera_green,
	input [7:0] usera_blue,
	input [7:0] userb_red,
	input [7:0] userb_green,
	input [7:0] userb_blue,
	input [7:0] ledindex, 
	input [7:0] animationcounter, 
	input [7:0] stepclock, 
	output reg [7:0] red, 
	output reg [7:0] green, 
	output reg [7:0] blue);

	reg [1:0] colindex;

	reg [7:0] colmux_red;
	reg [7:0] colmux_green;
	reg [7:0] colmux_blue;

	reg [15:0] fractionalposition;
	reg [15:0] proxa;
	reg [7:0] proximity;

	reg [15:0] intensityfaded_red;
	reg [15:0] intensityfaded_green;
	reg [15:0] intensityfaded_blue;

	reg [7:0] steppedcol_red;
	reg [7:0] steppedcol_green;
	reg [7:0] steppedcol_blue;

	// Colour modes: 0 = Solid User Block A, 1 = Solid user block B, 2 = Gradient A to B, 3 = Waves A to B, 4 = Stepped RGBY, 5 = Fixed Rainbow, 6 = Moving Rainbow

	// Generate the non-clocked logic for faded proximity intensities
	always @* begin
		// Generate the fractional position 
		fractionalposition[15:0] <= animationcounter*49;
		// ABS type function
		if (fractionalposition>{ ledindex, 8'h00}) begin
			proxa[15:0] <= fractionalposition-{ ledindex, 8'h00};
		end else begin
			proxa[15:0] <= { ledindex, 8'h00}-fractionalposition;
		end
		// Actually generate the fading relative to the animation position
		if (proxa>=1024) begin
			proximity[7:0] <= 0;
		end else begin
			if (proxa<=8) begin
				proximity[7:0] <= 255;
			end else begin
				proximity[7:0] <= 256-(proxa/4);
			end
		end
	end

	// Generate the non-clocked logic for building stepped colours
	always @* begin
		colindex[1:0] <= stepclock[1:0] + ledindex;
		case (colindex)
			0: begin
				steppedcol_red[7:0] <= (8'hFF);
				steppedcol_green[7:0] <= (8'h00);
				steppedcol_blue[7:0] <= (8'h00);
			end
			1: begin
				steppedcol_red[7:0] <= (8'h00);
				steppedcol_green[7:0] <= (8'hFF);
				steppedcol_blue[7:0] <= (8'h00);
			end
			2: begin
				steppedcol_red[7:0] <= (8'h00);
				steppedcol_green[7:0] <= (8'h00);
				steppedcol_blue[7:0] <= (8'hFF);
			end
			3: begin
				steppedcol_red[7:0] <= (8'hFF);
				steppedcol_green[7:0] <= (8'hFF);
				steppedcol_blue[7:0] <= (8'h00);
			end
		endcase		
	end

	// The colour multiplexer
	always @* begin
		case (colmode)
			0: begin
				// Solid block of user A
				colmux_red[7:0] <= usera_red[7:0];
				colmux_green[7:0] <= usera_green[7:0];
				colmux_blue[7:0] <= usera_blue[7:0];
			end
			1: begin
				// Solid block of user B
				colmux_red[7:0] <= userb_red[7:0];
				colmux_green[7:0] <= userb_green[7:0];
				colmux_blue[7:0] <= userb_blue[7:0];
			end
			4: begin
				// Red, Green, Blue, Yellow stepped
				colmux_red[7:0] <= steppedcol_red[7:0];
				colmux_green[7:0] <= steppedcol_green[7:0];
				colmux_blue[7:0] <= steppedcol_blue[7:0];
			end
			default: begin
				colmux_red[7:0] <= 0;
				colmux_green[7:0] <= 0;
				colmux_blue[7:0] <= 0;
			end
		endcase
	end	

	always @(posedge clk) begin
		case (mode)
			0: begin
				// Just a solid block - no animation
				red[7:0] <= colmux_red[7:0];
				green[7:0] <= colmux_green[7:0];
				blue[7:0] <= colmux_blue[7:0];
			end
			1: begin
				// Faded block running up
				intensityfaded_red[15:0] = colmux_red[7:0] * proximity[7:0];
				intensityfaded_green[15:0] = colmux_green[7:0] * proximity[7:0];
				intensityfaded_blue[15:0] = colmux_blue[7:0] * proximity[7:0];
				red[7:0] <= intensityfaded_red[15:8];
				green[7:0] <= intensityfaded_green[15:8];
				blue[7:0] <= intensityfaded_blue[15:8];
			end
			default: begin
				red[7:0] <= (8'h00);
				green[7:0] <= (8'h00);
				blue[7:0] <= (8'h00);
			end			
		endcase
    end

endmodule