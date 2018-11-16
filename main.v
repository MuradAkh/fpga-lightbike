module main (

);

endmodule

module game (

);

    localparam 
        G_IDLE = 2'd0,
        G_PAUSE1 = 2'd1,
        G_GAME = 2'd2,
        G_PAUSE2 = 2'd3,

        D_BOARD = 1'd0,
        D_PLAYERS = 1'd1,
        
        P0 = 2'd0,
        P1 = 2'd1,
        P2 = 2'd2,
        PE = 2'd3;

    reg [1:0] g_curr, g_next;
    reg d_curr, d_next;

    reg [2:0] p_state;
    reg [2:0] p_in_air;
    reg [7:0] p_pos [1:0][2:0];

    reg [1:0] g_state [119:0][159:0];

endmodule