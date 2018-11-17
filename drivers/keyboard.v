`include "segment.v"

module keyboard(
    output [9:0] LEDR,
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5,
    input [3:0] KEY,
    input PS2_DAT,
    input PS2_CLK,
    input CLOCK_50
);

    wire [511:0] make, persist, break;
    wire reset_make, reset_persist, reset_break;

    assign LEDR[0] = make[8'h1C];
    assign LEDR[1] = persist[8'h1C];
    assign LEDR[2] = break[8'h1C];

    controller con(
        CLOCK_50,
        PS2_CLK,
        PS2_DAT,
        KEY[0],
        reset_make,
        reset_persist,
        reset_break,
        scan,
        make,
        persist, 
        break
    );

    wire [24:0] scan;

    segment h0(
        scan[3:0],
        HEX0
    );
    segment h1(
        scan[7:4],
        HEX1
    );
    segment h2(
        scan[11:8],
        HEX2
    );
    segment h3(
        scan[15:12],
        HEX3
    );
    segment h4(
        scan[19:16],
        HEX4
    );
    segment h5(
        scan[23:20],
        HEX5
    );

    reg [23:0] divided;
    wire rate;
    assign rate = (divided == 24'h000000) ? 1 : 0;

    always @(posedge CLOCK_50)
    begin
        if(divided == 0)
            divided = 4'h4C4B40;
        
        divided = divided - 1'b1;
    end

    assign reset_break = !rate;
    assign reset_make = !rate;
    assign reset_persist = 1'b1;
    
endmodule


module controller(
    input c50,
    input pc,
    input pd,
    input reset_all,
    input reset_make,
    input reset_persist,
    input reset_break,
    output reg [24:0] out,
    output reg [511:0] make_lut,
    output reg [511:0] persist_lut,
    output reg [511:0] break_lut
);

    reg [15:0] denoise;
    wire pcf;
    assign pcf = (&denoise) ? 1'b1 : ((~|denoise) ? 1'b0 : pcf);

    always @(posedge c50)
    begin
        denoise <= {denoise[14:0], pc};
    end

    // ** RAW SHIFTED DATA ** //
    reg [11:0] data;
    // ** CURRENT SCAN CODE BUFFER ** //
    reg [23:0] scan;

    reg prev_pcf;

    always @(negedge c50)
    begin
        
        // ** RESET LOGIC ** //
        if(!reset_all) 
        begin
            make_lut <= 512'd0;
            persist_lut <= 512'd0;
            break_lut <= 512'd0;
            scan <= 24'h000000;
            data = 11'b11111111111;
        end
        else
        begin
            if(!reset_make)
                make_lut <= 512'd0;
            if(!reset_persist)
                persist_lut <= 512'd0;
            if(!reset_break)
                break_lut <= 512'd0;
        end

        if(pcf == 1'b0 && prev_pcf == 1'b1) 
        begin
            // shift right
            data = {pd, data[11:1]};
            // if all shifted in
            if(data[0] == 1'b0)
            begin
                case(data[9:2])
                    8'hE0: scan[23:16] = data[9:2];
                    8'hF0: scan[15:8] = data[9:2];
                    default: begin
                        // full code
                        scan[7:0] = data[9:2];
                        out = scan;
                        
                        if(scan[15:8] == 8'hF0)
                        begin
                            // break code
                            persist_lut[{scan[23:16] == 8'hE0, scan[7:0]}] = 1'b0;
                            break_lut[{scan[23:16] == 8'hE0, scan[7:0]}] = 1'b1;
                        end
                        else
                        begin
                            // make code
                            make_lut[{scan[23:16] == 8'hE0, scan[7:0]}] = ~persist_lut[{scan[23:16] == 8'hE0, scan[7:0]}];
                            persist_lut[{scan[23:16] == 8'hE0, scan[7:0]}] = 1'b1;
                        end
                        
                        scan = 25'h000000;
                    end
                endcase

                data = 11'b11111111111;
            end
        end

        prev_pcf = pcf;
    end

endmodule