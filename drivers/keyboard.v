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