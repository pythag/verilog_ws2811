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
	input [7:0] blocksize,
	input [7:0] usera_red,
	input [7:0] usera_green,
	input [7:0] usera_blue,
	input [7:0] userb_red,
	input [7:0] userb_green,
	input [7:0] userb_blue,
	input [7:0] masterfader,
	input [7:0] ledindex, 
	input [7:0] animationcounter, 
	input [7:0] stepclock, 
	output reg [7:0] red, 
	output reg [7:0] green, 
	output reg [7:0] blue);

	reg [2:0] phase;

	reg [1:0] colindex;

	reg [7:0] colmux_red;
	reg [7:0] colmux_green;
	reg [7:0] colmux_blue;

	reg [7:0] normalisedledindex;

	reg [15:0] fractionalposition;
	reg [15:0] proxa;
	reg [7:0] proximity;

	reg [15:0] gradientfaded_red;
	reg [15:0] gradientfaded_green;
	reg [15:0] gradientfaded_blue;

	reg [15:0] intensityfaded_red;
	reg [15:0] intensityfaded_green;
	reg [15:0] intensityfaded_blue;

	reg [15:0] finalfaded_red;
	reg [15:0] finalfaded_green;
	reg [15:0] finalfaded_blue;

	reg [7:0] rainbowpos_red;
	reg [7:0] rainbowpos_green;
	reg [7:0] rainbowpos_blue;

	reg [7:0] steppedcol_red;
	reg [7:0] steppedcol_green;
	reg [7:0] steppedcol_blue;

	reg [7:0] predimmed_red;
	reg [7:0] predimmed_green;
	reg [7:0] predimmed_blue;

	reg [24:0] rainbowlookup [0:255];
	reg [24:0] rainbowsplit;

	initial begin
		$readmemh("rainbow.hex", rainbowlookup, 0, 255);
	end

	always @(posedge clk) begin
		phase <= phase + 1;
		case (phase)
			// Phase is the calculation stage
			// Stage 0 Calculate some standard numbers required for several effects
			// animationcounter (input) - 0 to 255, ramps up during animation
			// normalisedledindex - represent the current pixel we're outputting (calculating) in the range 0 (first) to 255 (last)
			// fractionalposition - how far along the string is the animation currently at. Range 0 to (numleds*256)
			// proxa - abs value of distance from animation pixel. Range 0 to (numleds*256)
			// proximity - represents a rising 8-bit intensity when close to the animation point
			0: begin
				// normalisedledindex[7:0] <= { ledindex, 8'h00} / 64; // Numleds + 1
				// normalisedledindex[7:0] <= ledindex+animationcounter;
				if ((colmode==3)||(colmode==6)) begin
					normalisedledindex[7:0] <= (ledindex*blocksize)+animationcounter;
				end else begin
					normalisedledindex[7:0] <= ledindex*blocksize + ledindex; // Numleds + 1
				end
				// Generate the fractional position - somehow need to make this go negative?
				fractionalposition[15:0] <= animationcounter*55; // numleds + 5
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
			// Stage 1 - Generate colours based upon ledindex / normalisedledidex
			1: begin
				// Generate the stepped colours
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
				// Generate the static rainbow
				rainbowsplit <= rainbowlookup[normalisedledindex];
				rainbowpos_red[7:0] <= rainbowsplit[24:17];
				rainbowpos_green[7:0] <= rainbowsplit[16:8];
				rainbowpos_blue[7:0] <= rainbowsplit[7:0];
			end
			2: begin
				// The colour multiplexer
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
					2: begin
						// Static Gradient from A to B
						gradientfaded_red = usera_red * normalisedledindex + userb_red * (255-normalisedledindex);
						gradientfaded_green = usera_green * normalisedledindex + userb_green * (255-normalisedledindex);
						gradientfaded_blue = usera_blue * normalisedledindex + userb_blue * (255-normalisedledindex);
						colmux_red[7:0] <= gradientfaded_red[15:8];
						colmux_green[7:0] <= gradientfaded_green[15:8];
						colmux_blue[7:0] <= gradientfaded_blue[15:8];
					end
					3: begin
						// Moving Gradient from A to B
						gradientfaded_red = usera_red * normalisedledindex + userb_red * (255-normalisedledindex);
						gradientfaded_green = usera_green * normalisedledindex + userb_green * (255-normalisedledindex);
						gradientfaded_blue = usera_blue * normalisedledindex + userb_blue * (255-normalisedledindex);
						colmux_red[7:0] <= gradientfaded_red[15:8];
						colmux_green[7:0] <= gradientfaded_green[15:8];
						colmux_blue[7:0] <= gradientfaded_blue[15:8];
					end
					4: begin
						// Red, Green, Blue, Yellow stepped
						colmux_red[7:0] <= steppedcol_red[7:0];
						colmux_green[7:0] <= steppedcol_green[7:0];
						colmux_blue[7:0] <= steppedcol_blue[7:0];
					end
					5: begin
						// Fixed rainbow
						colmux_red[7:0] <= rainbowpos_red[7:0];
						colmux_green[7:0] <= rainbowpos_green[7:0];
						colmux_blue[7:0] <= rainbowpos_blue[7:0];
					end
					6: begin
						// Moving rainbow
						colmux_red[7:0] <= rainbowpos_red[7:0];
						colmux_green[7:0] <= rainbowpos_green[7:0];
						colmux_blue[7:0] <= rainbowpos_blue[7:0];
					end
					default: begin
						// Black
						colmux_red[7:0] <= 0;
						colmux_green[7:0] <= 0;
						colmux_blue[7:0] <= 0;
					end
				endcase
			end
			3: begin
				// The final output multiplexer
				case (mode)
					0: begin
						// Just a solid block - no animation
						predimmed_red[7:0] <= colmux_red[7:0];
						predimmed_green[7:0] <= colmux_green[7:0];
						predimmed_blue[7:0] <= colmux_blue[7:0];
					end
					1: begin
						// Faded block running up
						intensityfaded_red[15:0] = colmux_red[7:0] * proximity[7:0];
						intensityfaded_green[15:0] = colmux_green[7:0] * proximity[7:0];
						intensityfaded_blue[15:0] = colmux_blue[7:0] * proximity[7:0];
						predimmed_red[7:0] <= intensityfaded_red[15:8];
						predimmed_green[7:0] <= intensityfaded_green[15:8];
						predimmed_blue[7:0] <= intensityfaded_blue[15:8];
					end
					default: begin
						predimmed_red[7:0] <= (8'h00);
						predimmed_green[7:0] <= (8'h00);
						predimmed_blue[7:0] <= (8'h00);
					end			
				endcase
			end
			5: begin
				finalfaded_red = predimmed_red * masterfader;
				finalfaded_green = predimmed_green * masterfader;
				finalfaded_blue = predimmed_blue * masterfader;
				red <= finalfaded_red[15:8];;
				green <= finalfaded_green[15:8];;
				blue <= finalfaded_blue[15:8];;
			end
		endcase
	end	

endmodule