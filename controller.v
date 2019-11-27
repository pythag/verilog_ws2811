module lfsr (
	output [10:0] out,
	input clk
	);

	wire linear_feedback;

	reg [15:0] lfsrreg;

	assign linear_feedback = !(lfsrreg[15] ^ lfsrreg[13] ^ lfsrreg[12] ^ lfsrreg[10]);
	assign out = lfsrreg[10:0];

	always @(posedge clk) begin
		lfsrreg <= {lfsrreg[14:0], linear_feedback};
	end 

endmodule


module animationclock (input clk, output [7:0] animationcounter, output [7:0] stepclock);
	reg [32:0] count;

	assign animationcounter[7:0] = count[28:21];
	assign stepclock[7:0] = count[32:25];
	
	always @(posedge clk) begin
		count <= count + 1;
    end
endmodule

// Essentially a colour multiplexer (single channel at a time)
module colourchannelcalculator(
	input clk,
	input [7:0] colmode, 
	input [7:0] usera, 
	input [7:0] userb, 
	input [7:0] normalisedledindex,
	input [15:0] fractionalposition,
	input [7:0] steppedcol,
	input [7:0] rainbowpos,
	output [7:0] colmux);

	reg [7:0] throwaway;
	reg [7:0] colmuxr;

	assign colmux = colmuxr;

	always @(posedge clk) begin
		case (colmode)
			0: begin
				// Solid block of user A
				colmuxr <= usera;
			end
			1: begin
				// Solid block of user B
				colmuxr <= userb;
			end
			2: begin
				// Static Gradient from A to B
				{ colmuxr, throwaway } <= usera * normalisedledindex + userb * (255-normalisedledindex);
			end
			3: begin
				// Moving Gradient from A to B (movement is handled by controller adjusting normalisedledindex)
				{ colmuxr, throwaway } <= usera * normalisedledindex + userb * (255-normalisedledindex);
			end
			4: begin
				// Red, Green, Blue, Yellow stepped
				colmuxr <= steppedcol;
			end
			5: begin
				// Fixed rainbow
				colmuxr <= rainbowpos;
			end
			6: begin
				// Moving rainbow (movement is handled by controller adjusting normalisedledindex)
				colmuxr <= rainbowpos;
			end
			default: begin
				// Black
				colmuxr <= 0;
			end
		endcase
	end
endmodule

module outputmultiplexer (
	input clk,
	input [7:0] mode,
	input [7:0] colmux,
	input [7:0] proximity,
	output [7:0] predimmed);

	reg [7:0] predimmedr;

	reg [7:0] throwaway;

	assign predimmed=predimmedr;

	always @(posedge clk) begin
		case (mode)
			0: begin
				// Just a solid block - no animation
				predimmedr <= colmux;
			end
			1: begin
				// Faded block running up
				{ predimmedr, throwaway } <= colmux * proximity;
			end
			default: begin
				predimmedr <= (8'h00);
			end			
		endcase
	end
endmodule


module ledcontroller (
	input clk, 
	input [7:0] mode, 
	input [7:0] colmode, 
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
	input [7:0] glitterrate,
	input [7:0] glittervolume,
	output reg [7:0] red, 
	output reg [7:0] green, 
	output reg [7:0] blue);

	wire [15:0] fadeout;

	reg [7:0] usera_mux;
	reg [7:0] userb_mux;

	reg [4:0] phase; // 32 computational cycles per pixel required.

	reg [1:0] colindex;

	reg [7:0] colmux_mux;

	reg [7:0] normalisedledindex;

	reg [15:0] fractionalposition;
	reg [15:0] proxa;
	reg [7:0] proximity;

	reg [7:0] rainbowpos_mux;

	reg [7:0] steppedcol_red;
	reg [7:0] steppedcol_green;
	reg [7:0] steppedcol_blue;
	reg [7:0] steppedcol_mux;

	reg [7:0] predimmed_mux;

	reg [24:0] rainbowlookup [0:255];

	reg [255:0] glitterpos;
	reg [7:0] glitterclock;
	reg glittercalculating;
	reg [7:0] glitteri;
	reg [4:0] glitterdivider;

	reg [10:0] lfsrout;

	initial begin
		$readmemh("rainbow.hex", rainbowlookup, 0, 255);
	end

	colourchannelcalculator thecolourcalculator
	(
		.clk(clk),
		.colmode(colmode),
		.usera(usera_mux), 
		.userb(userb_mux), 
		.normalisedledindex(normalisedledindex),
		.fractionalposition(fractionalposition),
		.steppedcol(steppedcol_mux),
		.rainbowpos(rainbowpos_mux),
		.colmux(colmux_mux)
	);

	outputmultiplexer theoutputmux
	(
		.clk(clk),
		.mode(mode),
		.proximity(proximity),
		.colmux(colmux_mux),
		.predimmed(predimmed_mux)
	);

	lfsr thelfrs
	(
		.clk(clk),
		.out(lfsrout)
	);

	assign fadeout = predimmed_mux * masterfader;

	always @(posedge clk) begin
		phase <= phase + 1;
		case (phase)

			// Stage 0 Calculate some standard numbers required for several effects
			// animationcounter (input) - 0 to 255, ramps up during animation
			// normalisedledindex - represent the current pixel we're outputting (calculating) in the range 0 (first) to 255 (last)
			// fractionalposition - how far along the string is the animation currently at. Range 0 to (numleds*256)
			0: begin
				// A bit of a short-cut here - rainbow and gradient animation is achieved by manipulating this normalisedledindex
				if ((colmode==3)||(colmode==6)) begin
					normalisedledindex <= (ledindex*blocksize)+animationcounter;
				end else begin
					normalisedledindex <= ledindex*blocksize + ledindex; // Numleds + 1
				end
				// Generate the fractional position - somehow need to make this go negative?
				fractionalposition <= animationcounter*55; // numleds + 5
				// Deal with populating the glitterpos array randomly
				glitterdivider <= glitterdivider +1;
				if (glitterdivider==0) begin
					if (glitterclock<=glitterrate) begin
						glitterpos[glitteri] <= (lfsrout<glittervolume);
						glitteri <= glitteri + 1;
						glitterclock <= 255;
					end	else begin
						glitterclock <= glitterclock-1;
					end
				end
			end


			// Stage 1 - Generate colours based upon ledindex / normalisedledidex
			// proxa - abs value of distance from animation pixel. Range 0 to (numleds*256)
			// TODO: Use blocksize for this too
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

				// Generate the proximity values
				// ABS type function
				if (fractionalposition>{ ledindex, 8'h00}) begin
					proxa[15:0] <= fractionalposition-{ ledindex, 8'h00};
				end else begin
					proxa[15:0] <= { ledindex, 8'h00}-fractionalposition;
				end
			end

			// Stage 2 - actually generate the fading relative to the animation position
			// proximity - represents a rising 8-bit intensity when close to the animation point
			2: begin
				if (proxa>=1024) begin
					proximity <= 0;
				end else begin
					if (proxa<=8) begin
						proximity <= 255;
					end else begin
						proximity <= 256-(proxa/4);
					end
				end			
			end

			3: begin
				usera_mux <= usera_red;
				userb_mux <= userb_red;
				steppedcol_mux <= steppedcol_red;
				rainbowpos_mux <= rainbowlookup[normalisedledindex][24:17];
			end
			// Skip a clock so result can propogate through the output mux and master fader
			5: begin
				if (glitterpos[normalisedledindex]) begin
					red <= 255;
				end else begin
					red <= fadeout[15:8];
				end
			end
			6: begin
				usera_mux <= usera_green;
				userb_mux <= userb_green;
				steppedcol_mux <= steppedcol_green;
				rainbowpos_mux <= rainbowlookup[normalisedledindex][16:8];
			end
			// Skip
			8: begin
				if (glitterpos[normalisedledindex]) begin
					green <= 255;
				end else begin
					green <= fadeout[15:8];
				end
			end
			9: begin
				usera_mux <= usera_blue;
				userb_mux <= userb_blue;
				steppedcol_mux <= steppedcol_blue;
				rainbowpos_mux <= rainbowlookup[normalisedledindex][7:0];
			end
			// Skip
			11: begin
				if (glitterpos[normalisedledindex]) begin
					blue <= 255;
				end else begin
					blue <= fadeout[15:8];
				end
			end
		endcase
	end	

endmodule