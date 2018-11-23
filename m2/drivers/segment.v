module segment(
    input [3:0] select,
    output reg [6:0] hex
);

    always @(*)
    begin: lut
        case(select)
            4'h0: hex <= ~7'h3F;
            4'h1: hex <= ~7'h06;
            4'h2: hex <= ~7'h5B;
            4'h3: hex <= ~7'h4F;
            4'h4: hex <= ~7'h66;
            4'h5: hex <= ~7'h6D;
            4'h6: hex <= ~7'h7D;
            4'h7: hex <= ~7'h07;
            4'h8: hex <= ~7'h7F;
            4'h9: hex <= ~7'h6F;
            4'hA: hex <= ~7'h77;
            4'hB: hex <= ~7'h7C;
            4'hC: hex <= ~7'h39;
            4'hD: hex <= ~7'h5E;
            4'hE: hex <= ~7'h79;
            4'hF: hex <= ~7'h71;
        endcase
    end

endmodule