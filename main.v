module main (
    input CLOCK_50,
    	// Your inputs and outputs here
    input [3:0] KEY,
    input [9:0] SW,

    output VGA_CLK,   						//	VGA Clock
    output VGA_HS,							//	VGA H_SYNC
    output VGA_VS,							//	VGA V_SYNC
    output VGA_BLANK_N,						//	VGA BLANK
    output VGA_SYNC_N,						//	VGA SYNC
    output VGA_R,   						//	VGA Red[9:0]
    output VGA_G,	 						//	VGA Green[9:0]
    output VGA_B,   						//	VGA Blue[9:0]

    input PS2_CLK,
    input PS2_DAT
);

    reg [21:0] counter;
    always @(posedge CLOCK_50)
    begin
        counter <= counter == 22'd0 ? 22'd2500000 : counter - 1'b1;
    end

    wire game_clk;
    assign game_clk = counter == 0;

    wire [24:0] out;
    wire [511:0] make_lut, persist_lut, break_lut;

    keyboard controller(
        CLOCK_50,
        game_clk,
        PS2_CLK,
        PS2_DAT,
        1'b0,
        1'b1,
        1'b0,
        1'b1,
        out,
        make_lut,
        persist_lut,
        break_lut
    );


    wire round_finished, disp_continue, reset_game, run_game;
    wire enter_pressed;
    assign enter_pressed = make_lut[9'h5A];


    game_ctrl control(
        CLOCK_50,
        game_clk,
        KEY[0],

        round_finished,
        disp_continue,

        enter_pressed,
        reset_game,
        run_game
    );

    game_data data(
        CLOCK_50,
        game_clk,
        KEY[0],

        reset_game,
        run_game,

        6'b000000,

        colour,
        x,
        y,
        plot,

        round_finished,
        disp_continue

    );

    // Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [5:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire plot;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(KEY[0]),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(plot),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 2;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			

endmodule

module game_ctrl (
    input CLOCK_50, // 50 Mhz 
    input game_clk, // 20 hz
    input reset_n,
    
    // inputs from datapath
    input round_finished,
    input disp_continue,

    // inputs from keyboard
    input enter_pressed,

    // outputs to datapath
    output reset_game,
    output run_game
);

    localparam 
        G_IDLE = 2'd0,  // wait for player to start
        G_GAME = 2'd1,  // game state
        G_DISP = 2'd2;  // pause to give players time to reset

    reg [1:0] g_curr, g_next;
    assign reset_game = g_curr == G_IDLE;
    assign run_game = g_curr == G_GAME;

    always @(posedge game_clk)
    begin: game_fsm
        if(!reset_n)
            g_curr <= G_IDLE;
        else g_curr <= g_next;
    end

    always @(*)
    begin: game_next_fsm
        case(g_curr)
            G_IDLE: g_next <= enter_pressed ? G_GAME : G_IDLE;
            G_GAME: g_next <= round_finished ? G_DISP : G_GAME;
            G_DISP: g_next <= disp_continue ? G_IDLE : G_DISP;
        endcase 
    end

endmodule

module game_data(
    input CLOCK_50,
    input game_clk,
    input reset_n,
    
    input reset_game,
    input run_game,

    // 01 represents right
    // 10 represents left
    // 11 represents same dir
    // 00 represents same dir
    input [5:0] turn,
    
    // r, g, b, 2 bits each
    output reg [5:0] colour,    
    output reg [7:0] x,
    output reg [6:0] y,
    output reg plot,

    output round_finished,
    output disp_continue
);
    wire [1:0] turning_dir [2:0];
    assign {turning_dir[2], turning_dir[1], turning_dir[0]} = turn;


    localparam
        P0 = 2'd0,
        P1 = 2'd1,
        P2 = 2'd2,
        PE = 2'd3,
        
        P0_C = 6'b110100,
        P1_C = 6'b001010,
        P2_C = 6'b111011,
        PE_C = 6'b010101,

        WIDTH = 160,
        HEIGHT = 120;

    reg [2:0] p_state;
    assign round_finished = ^p_state && ~&p_state || ~|p_state; // round is finished when one player standing

    // reg [2:0] p_in_air;
    reg [7:0] p_pos_x [2:0];
    reg [6:0] p_pos_y [2:0];

    // 00 is up, 01 is right, 10 is down, 11 is left
    reg [1:0] p_dir [2:0];

    //  per cell         x      y
    reg [1:0] g_state [159:0][119:0];


    // counter to let the game wait 32 ticks until starting
    reg [4:0] disp_counter;
    assign disp_continue = disp_counter == 0;

    always @(posedge game_clk)
    begin: game_logic
        if(reset_game) begin
            integer i, j;
            for(i = 0; i < 120; i = i + 1) begin
                for(j = 0; j < HEIGHT; j = j + 1) begin
                    g_state[i][j] <= PE;
                end
            end
            disp_counter <= 5'b0;
            p_state <= 3'b111;
            
            p_pos_x[2] <= 8'd85;
            p_pos_x[1] <= 8'd75;
            p_pos_x[0] <= 8'd80;

            p_pos_y[2] <= 7'd65;
            p_pos_y[1] <= 7'd65;
            p_pos_y[0] <= 7'd55;

            p_dir[2] = 2'd0;
            p_dir[1] = 2'd3;
            p_dir[0] = 2'd2;
        end
        else if(run_game) begin
            // all the run game logic, 
            // update player positions
            // then first clear the board if player is dead

            // player movement
            integer player;
            integer i;
            integer j;

            for(player = 0; player < 3; player = player + 1) begin

                // check if player is still alive
                if(p_state[player] == 1'b1) begin
                    // turn player
                    case(turning_dir[player])
                        2'b01: p_dir[player] = p_dir[player] + 1;
                        2'b10: p_dir[player] = p_dir[player] - 1;
                        default:;
                    endcase

                    // movement
                    case(p_dir[player])
                        2'b00: begin // up
                            if(p_pos_y[player] <= 0) p_state[player] = 1'b0;
                            else p_pos_y[player] = p_pos_y[player] - 1'b1;
                        end
                        2'b10: begin // down
                            if(p_pos_y[player] >= HEIGHT - 1) p_state[player] = 1'b0;
                            else p_pos_y[player] = p_pos_y[player] + 1'b1;
                        end
                        2'b11: begin // left
                            if(p_pos_x[player] <= 0) p_state[player] = 1'b0;
                            else p_pos_x[player] = p_pos_x[player] - 1'b1;
                        end
                        2'b01: begin // right
                            if(p_pos_x[player] >= WIDTH - 1) p_state[player] = 1'b0;
                            else p_pos_x[player] = p_pos_x[player] + 1'b1;
                        end
                    endcase

                    // kill player if this block is not empty
                    if(g_state[player][p_pos_x[player]][p_pos_y[player]] != PE) p_state[player] = 1'b0;
                end
            end

            // set the block to be that player's
            for(player = 0; player < 3; player = player + 1) begin
                if (p_state[player] == 1'b1) begin
                    g_state[p_pos_x[player]][p_pos_y[player]] = player;
                end
            end

            // clear board
            for(i = 0; i < WIDTH; i = i + 1) begin
                for(j = 0; j < HEIGHT; j = j + 1) begin
                    case(g_state[i][j])
                        P0: g_state[i][j] = p_state[0] ? P0 : PE;
                        P1: g_state[i][j] = p_state[1] ? P1 : PE;
                        P2: g_state[i][j] = p_state[2] ? P2 : PE;
                        default: g_state[i][j] = PE;
                    endcase
                end
            end
        end
        else begin
            // display state
            disp_counter <= disp_counter - 1;
        end
    end


    reg [14:0] draw_counter;
    always @(posedge CLOCK_50)
    begin: draw_logic
        if(!reset_n)
            draw_counter <= WIDTH * HEIGHT - 1;
        else
            draw_counter <= draw_counter == 0 ? WIDTH * HEIGHT - 1 : draw_counter - 1; 
    end

    always @(*)
    begin: plot_logic

        x = draw_counter % WIDTH;
        y = draw_counter / WIDTH;
        
        plot <= 1'b1;
        case(g_state[x][y])
            P0: colour <= P0_C;
            P1: colour <= P1_C;
            P2: colour <= P2_C;
            PE: colour <= PE_C;
        endcase
    end

endmodule