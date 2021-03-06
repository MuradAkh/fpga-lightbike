module main (
    input CLOCK_50,
    	// Your inputs and outputs here
    input [3:0] KEY,
    input [9:0] SW,
    output [9:0] LEDR,
    output [6:0] HEX5,
    output [6:0] HEX4,
    output [6:0] HEX3,
    output [6:0] HEX2,
    output [6:0] HEX1,
    output [6:0] HEX0,

    output VGA_CLK,   						//	VGA Clock
    output VGA_HS,							//	VGA H_SYNC
    output VGA_VS,							//	VGA V_SYNC
    output VGA_BLANK_N,						//	VGA BLANK
    output VGA_SYNC_N,						//	VGA SYNC
    output [9:0] VGA_R,   						//	VGA Red[9:0]
    output [9:0] VGA_G,	 						//	VGA Green[9:0]
    output [9:0] VGA_B,   						//	VGA Blue[9:0]

    input PS2_CLK,
    input PS2_DAT
);

    reg [21:0] counter;
    always @(posedge CLOCK_50)
    begin
		if(~KEY[0])
			counter <= 22'd0;
        else
			counter <= counter == 22'd0 ? 22'd2000000 : counter - 1'b1;
    end

    wire game_clk;
    assign game_clk = counter == 0;

    wire [24:0] out;
    wire [511:0] make_lut, persist_lut, break_lut;

    controller keyboard(
        CLOCK_50,
        PS2_CLK,
        PS2_DAT,
        KEY[0],
        ~game_clk,
        1'b1,
        ~game_clk,
        out,
        make_lut,
        persist_lut,
        break_lut
    );


    wire round_finished, disp_continue, reset_game, run_game;
    wire enter_pressed;
    assign enter_pressed = make_lut[9'h05A];


    game_ctrl control(
        CLOCK_50,
        game_clk,
        KEY[0],

        round_finished,
        disp_continue,

        enter_pressed,
        reset_game,
        run_game,

        LEDR[1:0]
    );

    game_data data(
        CLOCK_50,
        game_clk,
        KEY[0],

        reset_game,
        run_game,

        {
            // make_lut[9'h04C], //-> ECF
            // make_lut[9'h052],
            // make_lut[9'h033],
            // make_lut[9'h03B],
            // make_lut[9'h01C], 
            // make_lut[9'h01B]
            make_lut[9'h052], //-> PERSONAL
            make_lut[9'h05D],
            make_lut[9'h033],
            make_lut[9'h03B],
            make_lut[9'h01C], 
            make_lut[9'h01B]
        },
		
        colour,
        x,
        y,
        plot,

        round_finished,
        disp_continue,
        LEDR[9:2],

        HEX5,
        HEX4,
        HEX3,
        HEX2,
        HEX1,
        HEX0,

        {SW[0], SW[1], SW[2]}
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
    output reg reset_game,
    output reg run_game,

    output [1:0] LEDR
);

    localparam 
        G_IDLE = 2'd1,  // wait for player to start
        G_GAME = 2'd2,  // game state
        G_DISP = 2'd3;  // pause to give players time to reset

    reg [1:0] g_curr, g_next;

    assign LEDR[1:0] = g_curr;

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

    always @(*)
    begin: control_sig
        reset_game = 1'b0;
        run_game = 1'b0;

        case(g_curr)
            G_IDLE: reset_game = 1'b1;
            G_GAME: run_game = 1'b1;
            default:;
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
    output [5:0] colour,    
    output [7:0] x,
    output [6:0] y,
    output plot,

    output round_finished,
    output disp_continue,

    output [7:0] LEDR,
    output [6:0] HEX5,
    output [6:0] HEX4,
    output [6:0] HEX3,
    output [6:0] HEX2,
    output [6:0] HEX1,
    output [6:0] HEX0,

    input [2:0] initial_players

);

    // RAM 
    // PORT a -> game logic
    // PORT b -> draw logic
    wire [12:0] address_a, address_b;

    wire [1:0] data_a, data_b;

    wire wren_a, wren_b;

    wire [1:0] q_a, q_b;

    ram game_state(
        address_a,
        address_b,
        CLOCK_50,
        data_a,
        data_b,
        wren_a,
        wren_b,
        q_a,
        q_b
    );

    wire [2:0] p_state;
    assign LEDR[7:5] = p_state;

    ram_port_a_controls game_logic(
        CLOCK_50,
        game_clk,

        q_a,
        wren_a,
        address_a,
        data_a,

        reset_game,
        run_game,
        turn,
        disp_continue,
        round_finished,
        p_state,

        initial_players
    );

    ram_port_b_controls draw_death(
        CLOCK_50,
        q_b,
        wren_b,
        address_b,
        data_b,

        x,
        y,
        colour,
        plot,

        p_state,
        reset_n
    );


    wire [23:0] scores;


    round_counter score(
        game_clk,
        reset_n,
        round_finished,
        p_state,
        scores
    );

    hex_to_dec p0(
        scores[7:0],
        HEX5,
        HEX4
    );

    hex_to_dec p1(
        scores[15:8],
        HEX3,
        HEX2
    );

    hex_to_dec p2(
        scores[23:16],
        HEX1,
        HEX0
    );

endmodule

module hex_to_dec(
    input [7:0] score,
    output [6:0] HEX1,
    output [6:0] HEX0
);

    segment h1(
        score / 10,
        HEX1
    );

    segment h0(
        score % 10,
        HEX0
    );

endmodule

module round_counter(
    input game_clk,
    input reset_n,
    input round_finished,
    input [2:0] p_state,
    output reg [23:0] scores
);

    reg prev;

    always @(posedge game_clk) begin
        if(~reset_n) begin
            prev = 1'b0; 
            scores <= 24'd0;
        end begin
            if(round_finished == 1'b1 && prev == 1'b0)
                scores <= {
                    scores[23:16] + p_state[2],
                    scores[15:8] + p_state[1],
                    scores[7:0] + p_state[0]
                };
            prev <= round_finished;
        end
    end
endmodule


module ram_port_a_controls(

    /* RAM CONTROLS */
    input CLOCK_50,
    input game_clk,
    input [1:0] q_a,
    output reg wren_a,
    output reg [12:0] address_a,
    output reg [1:0] data_a,

    /* GAME LOGIC */
    input reset_game,
    input run_game,
    input [5:0] turn,
    output disp_continue,
    output round_finished,
    output reg [2:0] p_state,

    input [2:0] initial_players
);


    assign round_finished = ^p_state && ~&p_state || ~|p_state; // round is finished when one or zero player standing

    // reg [2:0] p_in_air;
    reg [6:0] p_pos_x [2:0];
    reg [5:0] p_pos_y [2:0];

    // 00 is up, 01 is right, 10 is down, 11 is left
    reg [1:0] p_dir [2:0];

    wire [1:0] turning_dir [2:0];
    assign {turning_dir[2], turning_dir[1], turning_dir[0]} = turn;


    localparam
        P0 = 2'd0,
        P1 = 2'd1,
        P2 = 2'd2,
        PE = 2'd3,

        WIDTH = 7'd80,
        HEIGHT = 6'd60,
        
        L_IDLE = 4'd0,
        W_P0 = 4'd1,
        W_P1 = 4'd2,
        W_P2 = 4'd3,

        M_P0 = 4'd4,
        M_P1 = 4'd5,
        M_P2 = 4'd6,

        C_P0 = 4'd7,
        C_P1 = 4'd8,
        C_P2 = 4'd9,
        C_P0W = 4'd10,
        C_P1W = 4'd11,
        C_P2W = 4'd12,
        C_P0W2 = 4'd13,
        C_P1W2 = 4'd14,
        C_P2W2 = 4'd15;       

    // counter to let the game wait 32 ticks until starting
    reg [4:0] disp_counter;
    assign disp_continue = disp_counter == 5'd0;

    reg [12:0] reset_counter;


    reg [3:0] logic_state, next_logic_state;

    always @(*)
    begin: move_check_players_control
        if(run_game) begin
            wren_a = 1'b0;
            data_a = PE;
            
            case(logic_state)
                W_P0: begin
                    wren_a = p_state[0];
                    address_a = p_pos_x[0] + p_pos_y[0] * WIDTH;
                    data_a = P0;
                end
                W_P1: begin
                    wren_a = p_state[1];
                    address_a = p_pos_x[1] + p_pos_y[1] * WIDTH;
                    data_a = P1;
                end
                W_P2: begin
                    wren_a = p_state[2];
                    address_a = p_pos_x[2] + p_pos_y[2] * WIDTH;
                    data_a = P2;
                end
                C_P0W: begin
                    address_a = p_pos_x[0] + p_pos_y[0] * WIDTH;
                end
                C_P0W2: begin
                    address_a = p_pos_x[0] + p_pos_y[0] * WIDTH;
                end
                C_P0: begin
                    address_a = p_pos_x[0] + p_pos_y[0] * WIDTH;
                end
                C_P1W: begin
                    address_a = p_pos_x[1] + p_pos_y[1] * WIDTH;
                end
                C_P1W2: begin
                    address_a = p_pos_x[1] + p_pos_y[1] * WIDTH;
                end
                C_P1: begin
                    address_a = p_pos_x[1] + p_pos_y[1] * WIDTH;
                end
                C_P2W: begin
                    address_a = p_pos_x[2] + p_pos_y[2] * WIDTH;
                end
                C_P2W2: begin
                    address_a = p_pos_x[2] + p_pos_y[2] * WIDTH;
                end
                C_P2: begin
                    address_a = p_pos_x[2] + p_pos_y[2] * WIDTH;
                end
                default:;
            endcase

            case(logic_state)
                L_IDLE: next_logic_state <= game_clk ? C_P0W : L_IDLE;
                C_P0W: next_logic_state <= C_P0W2;
                C_P0W2: next_logic_state <= C_P0;
                C_P0: next_logic_state <= C_P1W;
                C_P1W: next_logic_state <= C_P1W2;
                C_P1W2: next_logic_state <= C_P1;
                C_P1: next_logic_state <= C_P2W;
                C_P2W: next_logic_state <= C_P2W2;
                C_P2W2: next_logic_state <= C_P2;
                C_P2: next_logic_state <= W_P0;
                W_P0: next_logic_state <= W_P1;
                W_P1: next_logic_state <= W_P2;
                W_P2: next_logic_state <= M_P0;
                M_P0: next_logic_state <= M_P1;
                M_P1: next_logic_state <= M_P2;
                M_P2: next_logic_state <= L_IDLE;
            endcase
        end else if(reset_game) begin
            wren_a <= 1'b1;
            address_a <= reset_counter;
            data_a <= PE;
        end else begin end
    end

    always @(posedge game_clk) begin
        if(reset_game) begin
            p_dir[2] = 2'd1;
            p_dir[1] = 2'd3;
            p_dir[0] = 2'd0;
            disp_counter <= 5'b11111;
        end else if(run_game) begin
            integer player;
            for(player = 0; player < 3; player = player + 1) begin
                case(turning_dir[player])
                    2'b01: p_dir[player] = p_dir[player] + 2'b1;
                    2'b10: p_dir[player] = p_dir[player] - 2'b1;
                    default:;
                endcase
            end
        end else begin
            disp_counter <= disp_counter - 1'b1;
        end
    end

    always @(posedge CLOCK_50)
    begin: game_logic
        if(reset_game) begin

            p_state <= initial_players;
            
            p_pos_x[2] <= 8'd45;
            p_pos_x[1] <= 8'd35;
            p_pos_x[0] <= 8'd40;

            p_pos_y[2] <= 7'd35;
            p_pos_y[1] <= 7'd35;
            p_pos_y[0] <= 7'd25;

            logic_state <= L_IDLE;

            reset_counter <= reset_counter == 13'd0 ? WIDTH * HEIGHT - 1 : reset_counter - 1'b1;
        end
        else if(run_game) begin
            case(logic_state)
                M_P0: begin
                    case(p_dir[0])
                        2'b00: p_pos_y[0] = p_pos_y[0] - 1'b1;
                        2'b01: p_pos_x[0] = p_pos_x[0] + 1'b1;
                        2'b10: p_pos_y[0] = p_pos_y[0] + 1'b1;
                        2'b11: p_pos_x[0] = p_pos_x[0] - 1'b1;
                    endcase
                end
                M_P1: begin
                    case(p_dir[1])
                        2'b00: p_pos_y[1] = p_pos_y[1] - 1'b1;
                        2'b01: p_pos_x[1] = p_pos_x[1] + 1'b1;
                        2'b10: p_pos_y[1] = p_pos_y[1] + 1'b1;
                        2'b11: p_pos_x[1] = p_pos_x[1] - 1'b1;
                    endcase
                end
                M_P2: begin
                    case(p_dir[2])
                        2'b00: p_pos_y[2] = p_pos_y[2] - 1'b1;
                        2'b01: p_pos_x[2] = p_pos_x[2] + 1'b1;
                        2'b10: p_pos_y[2] = p_pos_y[2] + 1'b1;
                        2'b11: p_pos_x[2] = p_pos_x[2] - 1'b1;
                    endcase
                end
                C_P0: begin
                    if(
                        q_a != PE ||
                        p_pos_x[0] >= WIDTH ||
                        p_pos_y[0] >= HEIGHT) p_state[0] = 1'b0;
                end
                C_P1: begin
                    if(
                        q_a != PE || 
                        p_pos_x[1] >= WIDTH ||
                        p_pos_y[1] >= HEIGHT) p_state[1] = 1'b0;
                end
                C_P2: begin
                    if(
                        q_a != PE || 
                        p_pos_x[2] >= WIDTH ||
                        p_pos_y[2] >= HEIGHT) p_state[2] = 1'b0;
                end
                default:;
            endcase

            logic_state <= next_logic_state;

        end
    end

endmodule

module ram_port_b_controls(

    /* RAM CONTROLS */
    input CLOCK_50,
    input [1:0] q_b,
    output reg wren_b,
    output reg [12:0] address_b,
    output reg [1:0] data_b,

    /* SCREEN CONTROLS */
    output reg [7:0] x,
    output reg [6:0] y,
    output reg [5:0] colour,
    output reg plot,

    /* OTHER */
    input [2:0] p_state,
    input reset_n
);


    localparam
        P0 = 2'd0,
        P1 = 2'd1,
        P2 = 2'd2,
        PE = 2'd3,
        
        
        P0_C = 6'b011111,
        P1_C = 6'b001100,
        P2_C = 6'b111000,
        PE_C = 6'b000001,
        // P0_C = 6'b110000,
        // P1_C = 6'b001100,
        // P2_C = 6'b000011,
        // PE_C = 6'b000000,

        WIDTH = 7'd80,
        HEIGHT = 6'd60,

        D_WIDTH = 8'd160,
        D_HEIGHT = 7'd120;      

    /* DRAWING */
    reg [14:0] draw_counter;

    localparam D_FETCH = 2'd0, D_FETCH2 = 2'd1, D_DRAW = 2'd2;
    reg [1:0] draw_state, next_draw_state;

    /* DRAW COUNTER */
    always @(posedge CLOCK_50)
    begin: d_counter
        if(!reset_n) begin
            draw_state = D_FETCH;
            draw_counter <= 0;
        end
        else begin 
            draw_state = next_draw_state;
            if(draw_state == D_FETCH) draw_counter <= draw_counter == 15'd0 ? D_WIDTH * D_HEIGHT - 1 : draw_counter - 1; 
        end
    end

    always @(*)
    begin: d_fsm
        case(draw_state)
            D_FETCH: next_draw_state <= D_FETCH2;
            D_FETCH2: next_draw_state <= D_DRAW;
            D_DRAW: next_draw_state <= D_FETCH;
        endcase
    end

    always @(*)
    begin: d_control
        wren_b = 1'b0;
        plot = 1'b0;

        case(draw_state)

            D_FETCH: begin
                address_b <= ((draw_counter % D_WIDTH) >> 1'b1) + ((draw_counter / D_WIDTH) >> 1'b1) * WIDTH;
            end
            D_FETCH2: begin
            end
            D_DRAW: begin
                x = draw_counter % D_WIDTH;
                y = draw_counter / D_WIDTH;
                plot = 1'b1;

                case(q_b)
                    P0: colour = P0_C;
                    P1: colour = P1_C;
                    P2: colour = P2_C;
                    PE: colour = PE_C;
                endcase

                if(q_b != PE && !p_state[q_b]) begin
                    wren_b = 1'b1;
                    data_b <= PE;
                end
            end
        endcase
    end


endmodule