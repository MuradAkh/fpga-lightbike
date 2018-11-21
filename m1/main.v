module main (
    input CLOCK_50,
    	// Your inputs and outputs here
    input [3:0] KEY,
    input [9:0] SW,
    output [9:0] LEDR,

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
        counter <= counter == 22'd0 ? 22'd2500000 : counter - 1'b1;
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
            make_lut[9'h052],
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
        LEDR[9:2]
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
    output reg [5:0] colour,    
    output reg [7:0] x,
    output reg [6:0] y,
    output plot,

    output round_finished,
    output disp_continue,

    output [7:0] LEDR
);
    wire [1:0] turning_dir [2:0];
    assign {turning_dir[2], turning_dir[1], turning_dir[0]} = turn;


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
        D_HEIGHT = 7'd120,
        
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
        C_P2W = 4'd12;        

    reg [2:0] p_state;
    assign round_finished = ^p_state && ~&p_state || ~|p_state; // round is finished when one or zero player standing
    // assign round_finished = 1'b0;

    // reg [2:0] p_in_air;
    reg [6:0] p_pos_x [2:0];
    reg [5:0] p_pos_y [2:0];

    assign LEDR[7:5] = p_state;
    // 00 is up, 01 is right, 10 is down, 11 is left
    reg [1:0] p_dir [2:0];


    // RAM 
    // PORT a -> game logic
    // PORT b -> draw logic
    reg [12:0] address_a;
    wire [12:0] address_b;

    reg [1:0] data_a, data_b;

    reg wren_a;
    wire wren_b;

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


    // counter to let the game wait 32 ticks until starting
    reg [4:0] disp_counter;
    assign disp_continue = disp_counter == 0;

    reg [12:0] reset_counter;


    reg [3:0] logic_state, next_logic_state;

    always @(*)
    begin: move_check_players_control
        if(run_game) begin
            wren_a = 1'b0;
            
            case(next_logic_state)
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
                C_P1W: begin
                    address_a = p_pos_x[1] + p_pos_y[1] * WIDTH;
                end
                C_P2W: begin
                    address_a = p_pos_x[2] + p_pos_y[2] * WIDTH;
                end
                default:;
            endcase

            case(logic_state)
                L_IDLE: next_logic_state <= game_clk ? W_P0 : L_IDLE;
                W_P0: next_logic_state <= W_P1;
                W_P1: next_logic_state <= W_P2;
                W_P2: next_logic_state <= M_P0;
                M_P0: next_logic_state <= M_P1;
                M_P1: next_logic_state <= M_P2;
                M_P2: next_logic_state <= C_P0W;
                C_P0W: next_logic_state <= C_P0;
                C_P0: next_logic_state <= C_P1W;
                C_P1W: next_logic_state <= C_P1;
                C_P1: next_logic_state <= C_P2W;
                C_P2W: next_logic_state <= C_P2;
                C_P2: next_logic_state <= L_IDLE;
            endcase
        end else if(reset_game) begin
            wren_a <= 1'b1;
            address_a <= reset_counter;
            data_a <= 2'b11;
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
            disp_counter = disp_counter - 1'b1;
        end
    end

    always @(posedge CLOCK_50)
    begin: game_logic
        if(reset_game) begin

            p_state <= 3'b111;
            
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
                        p_pos_x[0] >= WIDTH ||
                        p_pos_y[0] >= HEIGHT) p_state[0] = 1'b0;
                end
                C_P1: begin
                    if(
                        p_pos_x[1] >= WIDTH ||
                        p_pos_y[1] >= HEIGHT) p_state[1] = 1'b0;
                end
                C_P2: begin
                    if(
                        p_pos_x[2] >= WIDTH ||
                        p_pos_y[2] >= HEIGHT) p_state[2] = 1'b0;
                end
                default:;
            endcase

            logic_state <= next_logic_state;

        end
    end
            
    reg [14:0] draw_counter;
    assign address_b = (draw_counter % D_WIDTH) / 2'd2 + (draw_counter / D_WIDTH) / 2'd2 * WIDTH;
    assign wren_b = 1'd0;

    always @(posedge CLOCK_50)
    begin: draw_logic
        if(!reset_n)
            draw_counter <= D_WIDTH * D_HEIGHT - 1'b1;
        else
            draw_counter <= draw_counter == 15'd0 ? D_WIDTH * D_HEIGHT - 1 : draw_counter - 1; 
    end

    assign plot = 1'b1;

    always @(*)
    begin: b_logic

        x = draw_counter % D_WIDTH;
        y = draw_counter / D_WIDTH;
        
        case(q_b)
            P0: colour <= P0_C;
            P1: colour <= P1_C;
            P2: colour <= P2_C;
            PE: colour <= PE_C;
        endcase
    end

endmodule