module BattleshipGame (
    input wire clk,
    input wire rst,
    inout wire PS2_CLK,
    inout wire PS2_DATA,
    output wire [3:0] vgaRed,
    output wire [3:0] vgaGreen, 
    output wire [3:0] vgaBlue,
    output wire hsync,
    output wire vsync
);

    // Parameters for game states
    parameter INIT = 2'b00;
    parameter SETUP = 2'b01;
    parameter GAME = 2'b10;
    parameter FINISH = 2'b11;

    // Parameters for ships
    parameter CARRIER = 3'd0;    // 5 blocks
    parameter BATTLESHIP = 3'd1; // 4 blocks
    parameter CRUISER = 3'd2;    // 3 blocks
    parameter SUBMARINE = 3'd3;  // 3 blocks
    parameter DESTROYER = 3'd4;  // 2 blocks

    // Game board size
    parameter BOARD_SIZE = 10;
    
    // VGA Parameters
    parameter SCREEN_WIDTH = 1920;
    parameter SCREEN_HEIGHT = 1080;
    parameter BG_WIDTH = 160;
    parameter BG_HEIGHT = 120;

    parameter BOARD_X_START = 100;  // Starting X coordinate of game board
    parameter BOARD_Y_START = 100;  // Starting Y coordinate of game board
    parameter CELL_SIZE = 40;       // Size of each cell in pixels
    
    // Ship colors (12-bit RGB)
    parameter SHIP_COLOR = 12'h8F8;      // Light green
    parameter SUBMARINE_COLOR = 12'h00F;  // Dark blue
    parameter HIT_COLOR = 12'hF80;       // Orange
    parameter MISS_COLOR = 12'h888;      // Gray
    parameter WARNING_COLOR = 12'hF55;    // Red for warnings
    
    // State and clock
    reg [1:0] state;
    wire pclk;  // 25MHz clock for VGA
    
    // VGA signals
    wire [9:0] h_cnt, v_cnt;
    wire valid;
    reg [11:0] pixel_data;
    
    // Keyboard signals
    wire [511:0] key_down;
    wire [8:0] last_change;
    wire key_valid;
    
    // Game boards (0: empty, 1: ship, 2: hit, 3: miss)
    reg [1:0] board_p1 [0:BOARD_SIZE-1][0:BOARD_SIZE-1];
    reg [1:0] board_p2 [0:BOARD_SIZE-1][0:BOARD_SIZE-1];
    
    // Ship placement tracking
    reg [2:0] current_ship;
    reg [9:0] ship_pos_x, ship_pos_y;
    reg ship_vertical;
    reg [4:0] ships_placed_p1, ships_placed_p2;
    
    // Game state variables
    reg player1_turn;
    reg [9:0] cursor_x, cursor_y;
    reg submarine_power_p1, submarine_power_p2;
    reg continuous_hit;
    
    // Warning display
    reg show_warning;
    reg [31:0] warning_counter;
    
    // Background image handling
    reg [16:0] pixel_addr;
    wire [11:0] pixel_data_bg [0:4];  // For 5 background images
    
    // Clock divider for VGA
    clock_divider #(.n(2)) clk_div (
        .clk(clk),
        .clk_div(pclk)
    );
    
    // VGA controller
    vga_controller vga_ctrl (
        .pclk(pclk),
        .reset(rst),
        .hsync(hsync),
        .vsync(vsync),
        .valid(valid),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt)
    );
    
    // Keyboard decoder
    KeyboardDecoder key_decoder (
        .key_down(key_down),
        .last_change(last_change),
        .key_valid(key_valid),
        .PS2_DATA(PS2_DATA),
        .PS2_CLK(PS2_CLK),
        .rst(rst),
        .clk(clk)
    );
    
    // Background memory blocks
    blk_mem_gen_0 img0(.clka(clk), .addra(pixel_addr), .douta(pixel_data_bg[0]));  // INIT
    blk_mem_gen_3 img3(.clka(clk), .addra(pixel_addr), .douta(pixel_data_bg[1]));  // P1 WIN
    blk_mem_gen_4 img4(.clka(clk), .addra(pixel_addr), .douta(pixel_data_bg[2]));  // P2 WIN
    blk_mem_gen_1 img1(.clka(clk), .addra(pixel_addr), .douta(pixel_data_bg[3]));  // P1 TURN
    blk_mem_gen_2 img2(.clka(clk), .addra(pixel_addr), .douta(pixel_data_bg[4]));  // P2 TURN

    reg [11:0] scaled_x, scaled_y;

    // Pixel address calculation
    always @(*) begin
        if (valid) begin
            // 計算縮放後的坐標
            scaled_x = (h_cnt * BG_WIDTH) / SCREEN_WIDTH;
            scaled_y = (v_cnt * BG_HEIGHT) / SCREEN_HEIGHT;
            
            // 計算對應的像素地址
            pixel_addr = scaled_y * BG_WIDTH + scaled_x;
        end else begin
            pixel_addr = 0;
        end
    end

    integer i, j;

    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT;
            current_ship <= CARRIER;
            ship_pos_x <= 0;
            ship_pos_y <= 0;
            ship_vertical <= 0;
            ships_placed_p1 <= 0;
            ships_placed_p2 <= 0;
            player1_turn <= 1;
            cursor_x <= 0;
            cursor_y <= 0;
            submarine_power_p1 <= 1;
            submarine_power_p2 <= 1;
            continuous_hit <= 0;
            show_warning <= 0;
            warning_counter <= 0;
            
            // Clear boards
            for (i = 0; i < BOARD_SIZE; i = i + 1) begin
                for (j = 0; j < BOARD_SIZE; j = j + 1) begin
                    board_p1[i][j] <= 0;
                    board_p2[i][j] <= 0;
                end
            end
        end else begin
            // State transitions and game logic
            case (state)
                INIT: begin
                    if (key_valid && last_change == 9'h5A) begin  // Enter key
                        state <= SETUP;
                    end
                end
                
                SETUP: begin
                    // Ship placement logic
                    if (key_valid) begin
                        case (last_change)
                            9'h75: ship_pos_y <= (ship_pos_y > 0) ? ship_pos_y - 1 : 0;  // Up
                            9'h72: ship_pos_y <= (ship_pos_y < BOARD_SIZE-1) ? ship_pos_y + 1 : ship_pos_y;  // Down
                            9'h6B: ship_pos_x <= (ship_pos_x > 0) ? ship_pos_x - 1 : 0;  // Left
                            9'h74: ship_pos_x <= (ship_pos_x < BOARD_SIZE-1) ? ship_pos_x + 1 : ship_pos_x;  // Right
                            9'h12: ship_vertical <= ~ship_vertical;  // Shift for rotation
                            9'h5A: begin  // Enter for placement
                                if (is_valid_placement(1'b0)) begin
                                    place_ship();
                                    if (current_ship == DESTROYER) begin
                                        if (player1_turn && ships_placed_p1[4]) begin
                                            player1_turn <= 0;
                                            current_ship <= CARRIER;
                                        end else if (!player1_turn && ships_placed_p2[4]) begin
                                            state <= GAME;
                                        end
                                    end else begin
                                        current_ship <= current_ship + 1;
                                    end
                                end else begin
                                    show_warning <= 1;
                                    warning_counter <= 32'd75_000_000;  // 3 seconds at 25MHz
                                end
                            end
                        endcase
                    end
                end
                
                GAME: begin
                    // Game playing logic
                    if (key_valid) begin
                        case (last_change)
                            9'h75: cursor_y <= (cursor_y > 0) ? cursor_y - 1 : 0;  // Up
                            9'h72: cursor_y <= (cursor_y < BOARD_SIZE-1) ? cursor_y + 1 : cursor_y;  // Down
                            9'h6B: cursor_x <= (cursor_x > 0) ? cursor_x - 1 : 0;  // Left
                            9'h74: cursor_x <= (cursor_x < BOARD_SIZE-1) ? cursor_x + 1 : cursor_x;  // Right
                            9'h29: begin  // Space for shooting
                                if (player1_turn) begin
                                    if (board_p2[cursor_y][cursor_x] == 1) begin  // Hit
                                        board_p2[cursor_y][cursor_x] <= 2;
                                        if (continuous_hit && submarine_power_p1) begin
                                            continuous_hit <= 1;
                                        end else begin
                                            player1_turn <= 0;
                                        end
                                    end else begin  // Miss
                                        board_p2[cursor_y][cursor_x] <= 3;
                                        continuous_hit <= 0;
                                        player1_turn <= 0;
                                    end
                                end else begin
                                    if (board_p1[cursor_y][cursor_x] == 1) begin  // Hit
                                        board_p1[cursor_y][cursor_x] <= 2;
                                        if (continuous_hit && submarine_power_p2) begin
                                            continuous_hit <= 1;
                                        end else begin
                                            player1_turn <= 1;
                                        end
                                    end else begin  // Miss
                                        board_p1[cursor_y][cursor_x] <= 3;
                                        continuous_hit <= 0;
                                        player1_turn <= 1;
                                    end
                                end
                                
                                // Check for game end
                                if (check_game_over(0)) begin
                                    state <= FINISH;
                                end
                            end
                            9'h58: begin  // Caps Lock for submarine power
                                if (player1_turn && submarine_power_p1) begin
                                    continuous_hit <= 1;
                                    submarine_power_p1 <= 0;
                                end else if (!player1_turn && submarine_power_p2) begin
                                    continuous_hit <= 1;
                                    submarine_power_p2 <= 0;
                                end else begin
                                    show_warning <= 1;
                                    warning_counter <= 32'd75_000_000;
                                end
                            end
                        endcase
                    end
                end
                
                FINISH: begin
                    if (key_valid && last_change == 9'h5A) begin  // Enter key
                        state <= INIT;
                    end
                end
            endcase
            
            // Warning timer
            if (show_warning) begin
                if (warning_counter > 0) begin
                    warning_counter <= warning_counter - 1;
                end else begin
                    show_warning <= 0;
                end
            end
        end
    end

    // Helper function to check if ship placement is valid
    function is_valid_placement;
        input dummy;  // Verilog requires input for functions
        reg valid;
        integer i;
        reg [2:0] ship_length;
        begin
            valid = 1;
            
            // Get ship length
            case (current_ship)
                CARRIER: ship_length = 5;
                BATTLESHIP: ship_length = 4;
                CRUISER: ship_length = 3;
                SUBMARINE: ship_length = 3;
                DESTROYER: ship_length = 2;
                default: ship_length = 0;
            endcase
            
            // Check boundaries
            if (ship_vertical) begin
                if (ship_pos_y + ship_length > BOARD_SIZE) valid = 0;
            end else begin
                if (ship_pos_x + ship_length > BOARD_SIZE) valid = 0;
            end
            
            // Check overlap
            if (valid) begin
                for (i = 0; i < ship_length; i = i + 1) begin
                    if (ship_vertical) begin
                        if (player1_turn) begin
                            if (board_p1[ship_pos_y + i][ship_pos_x] != 0) valid = 0;
                        end else begin
                            if (board_p2[ship_pos_y + i][ship_pos_x] != 0) valid = 0;
                        end
                    end else begin
                        if (player1_turn) begin
                            if (board_p1[ship_pos_y][ship_pos_x + i] != 0) valid = 0;
                        end else begin
                            if (board_p2[ship_pos_y][ship_pos_x + i] != 0) valid = 0;
                        end
                    end
                end
            end
            
            is_valid_placement = valid;
        end
    endfunction
    
    // Helper function to place ship on board
    task place_ship;
        reg [2:0] ship_length;
        integer i;
        begin
            // Get ship length
            case (current_ship)
                CARRIER: ship_length = 5;
                BATTLESHIP: ship_length = 4;
                CRUISER: ship_length = 3;
                SUBMARINE: ship_length = 3;
                DESTROYER: ship_length = 2;
                default: ship_length = 0;
            endcase
            
            // Place ship
            for (i = 0; i < ship_length; i = i + 1) begin
                if (ship_vertical) begin
                    if (player1_turn) begin
                        board_p1[ship_pos_y + i][ship_pos_x] <= 1;
                    end else begin
                        board_p2[ship_pos_y + i][ship_pos_x] <= 1;
                    end
                end else begin
                    if (player1_turn) begin
                        board_p1[ship_pos_y][ship_pos_x + i] <= 1;
                    end else begin
                        board_p2[ship_pos_y][ship_pos_x + i] <= 1;
                    end
                end
            end
            
            // Mark ship as placed
            if (player1_turn) begin
                ships_placed_p1[current_ship] <= 1;
            end else begin
                ships_placed_p2[current_ship] <= 1;
            end
        end
    endtask

// Helper function to check for game over
    function check_game_over;
        input dummy;  // Verilog requires input for functions
        reg game_over;
        integer i, j;
        reg p1_alive, p2_alive;
        begin
            game_over = 0;
            p1_alive = 0;
            p2_alive = 0;
            
            // Check for any remaining ships
            for (i = 0; i < BOARD_SIZE; i = i + 1) begin
                for (j = 0; j < BOARD_SIZE; j = j + 1) begin
                    if (board_p1[i][j] == 1) p1_alive = 1;
                    if (board_p2[i][j] == 1) p2_alive = 1;
                end
            end
            
            if (!p1_alive || !p2_alive) game_over = 1;
            check_game_over = game_over;
        end
    endfunction
    
    // VGA Display Logic
    wire [9:0] board_x = h_cnt - BOARD_X_START;
    wire [9:0] board_y = v_cnt - BOARD_Y_START;
    wire in_board = (h_cnt >= BOARD_X_START) && (h_cnt < BOARD_X_START + BOARD_SIZE * CELL_SIZE) &&
                   (v_cnt >= BOARD_Y_START) && (v_cnt < BOARD_Y_START + BOARD_SIZE * CELL_SIZE);
                   
    wire [9:0] ship_display_x = 500;  // Right side of screen for ship display
    wire [9:0] ship_display_y = 100;
    wire [9:0] ship_spacing = 60;  // Vertical spacing between ships
    
    // Ship display area calculation
    function is_in_ship_display;
        input [9:0] ship_idx;
        input [9:0] ship_length;
        reg result;
        begin
            result = (h_cnt >= ship_display_x) && 
                    (h_cnt < ship_display_x + ship_length * 20) &&
                    (v_cnt >= ship_display_y + ship_idx * ship_spacing) &&
                    (v_cnt < ship_display_y + ship_idx * ship_spacing + 20);
            is_in_ship_display = result;
        end
    endfunction
    

    reg [3:0] grid_x, grid_y;
    reg [1:0] cell_state;

    // Display logic
    always @(*) begin
        if (!valid) begin
            pixel_data = 12'h000;
        end else begin
            case (state)
                INIT: begin
                    pixel_data = pixel_data_bg[0];
                end
                
                SETUP: begin
                    if (in_board) begin
                        // Calculate grid position
                        grid_x = board_x / CELL_SIZE;
                        grid_y = board_y / CELL_SIZE;
                        
                        // Grid lines
                        if ((board_x % CELL_SIZE == 0) || (board_y % CELL_SIZE == 0)) begin
                            pixel_data = 12'hFFF;  // White grid lines
                        end else begin
                            // Current ship placement preview
                            if (is_ship_position(grid_x, grid_y)) begin
                                if (is_valid_placement(1'b0)) begin
                                    pixel_data = (current_ship == SUBMARINE) ? SUBMARINE_COLOR : SHIP_COLOR;
                                end else begin
                                    pixel_data = 12'hF00;  // Red for invalid placement
                                end
                            end else if (player1_turn ? board_p1[grid_y][grid_x] : board_p2[grid_y][grid_x]) begin
                                pixel_data = SHIP_COLOR;  // Already placed ships
                            end else begin
                                pixel_data = (player1_turn ? pixel_data_bg[3] : pixel_data_bg[4]);
                            end
                        end
                    end else if (is_in_ship_display(CARRIER, 5) && !ships_placed_p1[CARRIER]) begin
                        pixel_data = (current_ship == CARRIER) ? 12'hFFF : SHIP_COLOR;
                    end else if (is_in_ship_display(BATTLESHIP, 4) && !ships_placed_p1[BATTLESHIP]) begin
                        pixel_data = (current_ship == BATTLESHIP) ? 12'hFFF : SHIP_COLOR;
                    end else if (is_in_ship_display(CRUISER, 3) && !ships_placed_p1[CRUISER]) begin
                        pixel_data = (current_ship == CRUISER) ? 12'hFFF : SHIP_COLOR;
                    end else if (is_in_ship_display(SUBMARINE, 3) && !ships_placed_p1[SUBMARINE]) begin
                        pixel_data = (current_ship == SUBMARINE) ? 12'hFFF : SUBMARINE_COLOR;
                    end else if (is_in_ship_display(DESTROYER, 2) && !ships_placed_p1[DESTROYER]) begin
                        pixel_data = (current_ship == DESTROYER) ? 12'hFFF : SHIP_COLOR;
                    end else begin
                        pixel_data = (player1_turn ? pixel_data_bg[3] : pixel_data_bg[4]);
                    end
                end
                
                GAME: begin
                    if (in_board) begin
                        grid_x = board_x / CELL_SIZE;
                        grid_y = board_y / CELL_SIZE;
                        
                        // Grid lines
                        if ((board_x % CELL_SIZE == 0) || (board_y % CELL_SIZE == 0)) begin
                            pixel_data = 12'hFFF;
                        end else begin
                            // Show cursor
                            if ((grid_x == cursor_x) && (grid_y == cursor_y)) begin
                                pixel_data = 12'hFF0;  // Yellow cursor
                            end else begin
                                // Display hits and misses
                                cell_state = player1_turn ? board_p2[grid_y][grid_x] : board_p1[grid_y][grid_x];
                                case (cell_state)
                                    2'b10: pixel_data = HIT_COLOR;    // Hit
                                    2'b11: pixel_data = MISS_COLOR;   // Miss
                                    default: pixel_data = (player1_turn ? pixel_data_bg[3] : pixel_data_bg[4]);
                                endcase
                            end
                        end
                    end else begin
                        pixel_data = (player1_turn ? pixel_data_bg[3] : pixel_data_bg[4]);
                    end
                end
                
                FINISH: begin
                    if (check_p1_win(1'b0)) begin
                        pixel_data = pixel_data_bg[1];  // Player 1 win background
                    end else begin
                        pixel_data = pixel_data_bg[2];  // Player 2 win background
                    end
                end
            endcase
            
            // Warning overlay
            if (show_warning) begin
                if ((h_cnt < 10) || (h_cnt >= SCREEN_WIDTH-10) || 
                    (v_cnt < 10) || (v_cnt >= SCREEN_HEIGHT-10)) begin
                    pixel_data = WARNING_COLOR;
                end
            end
        end
    end

    // Helper function to check if current pixel is part of ship placement
    function is_ship_position;
        input [3:0] grid_x;
        input [3:0] grid_y;
        reg result;
        reg [2:0] ship_length;
        integer i;
        begin
            result = 0;
            
            // Get ship length
            case (current_ship)
                CARRIER: ship_length = 5;
                BATTLESHIP: ship_length = 4;
                CRUISER: ship_length = 3;
                SUBMARINE: ship_length = 3;
                DESTROYER: ship_length = 2;
                default: ship_length = 0;
            endcase
            
            if (ship_vertical) begin
                if (grid_x == ship_pos_x) begin
                    for (i = 0; i < ship_length; i = i + 1) begin
                        if (grid_y == ship_pos_y + i) result = 1;
                    end
                end
            end else begin
                if (grid_y == ship_pos_y) begin
                    for (i = 0; i < ship_length; i = i + 1) begin
                        if (grid_x == ship_pos_x + i) result = 1;
                    end
                end
            end
            
            is_ship_position = result;
        end
    endfunction
    
    // Helper function to check if Player 1 wins
    function check_p1_win;
        input dummy;
        reg win;
        integer i, j;
        reg p2_alive;
        begin
            win = 0;
            p2_alive = 0;
            
            for (i = 0; i < BOARD_SIZE; i = i + 1) begin
                for (j = 0; j < BOARD_SIZE; j = j + 1) begin
                    if (board_p2[i][j] == 1) p2_alive = 1;
                end
            end
            
            if (!p2_alive) win = 1;
            check_p1_win = win;
        end
    endfunction
    
    // VGA output assignment
    assign vgaRed = pixel_data[11:8];
    assign vgaGreen = pixel_data[7:4];
    assign vgaBlue = pixel_data[3:0];
    
endmodule