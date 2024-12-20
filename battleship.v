module BattleshipGame (
    input wire clk,
    input wire rst,
    inout wire PS2_CLK,
    inout wire PS2_DATA,
    output wire [3:0] vgaRed,
    output wire [3:0] vgaGreen, 
    output wire [3:0] vgaBlue,
    output wire hsync,
    output wire vsync,
    output reg [3:0] LED
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
    parameter SCREEN_WIDTH = 640;
    parameter SCREEN_HEIGHT = 480;
    parameter IMG_WIDTH = 160;
    parameter IMG_HEIGHT = 120;

    parameter BOARD_X_START = 50;  // 左側留出空間
    parameter BOARD_Y_START = 100;  // 上方留出空間
    parameter CELL_SIZE = 32;      // 調整格子大小，讓10x10的板子能夠適當的顯示
    
    // Ship colors (12-bit RGB)
    parameter SHIP_COLOR = 12'h8F8;      // Light green
    parameter SUBMARINE_COLOR = 12'h00F;  // Dark blue
    parameter HIT_COLOR = 12'hF80;       // Orange
    parameter MISS_COLOR = 12'h888;      // Gray
    parameter WARNING_COLOR = 12'hF55;    // Red for warnings
    

    // 連續轟炸提示區域
    parameter CONTINUOUS_HINT_X = 500;  // 右側提示位置
    parameter CONTINUOUS_HINT_Y = 300;
    parameter CONTINUOUS_HINT_WIDTH = 100;
    parameter CONTINUOUS_HINT_HEIGHT = 50;
    
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
    wire been_ready;
    
    // Game boards (0: empty, 1: ship, 2: hit, 3: miss)
    reg [1:0] board_p1 [0:BOARD_SIZE-1][0:BOARD_SIZE-1];
    reg [1:0] board_p2 [0:BOARD_SIZE-1][0:BOARD_SIZE-1];
    reg [2:0] check_ship [0:BOARD_SIZE-1][0:BOARD_SIZE-1];  // 用於記錄每格對應的船種


    // Ship placement tracking
    reg [2:0] current_ship;
    reg [9:0] ship_pos_x, ship_pos_y;
    reg ship_vertical;
    reg [4:0] ships_placed_p1, ships_placed_p2;
    reg [3:0] submarine_pos_p1_x;
    reg [3:0] submarine_pos_p1_y;
    reg [3:0] submarine_pos_p2_x;
    reg [3:0] submarine_pos_p2_y;
    
    // Game state variables
    reg player1_turn;
    reg [9:0] cursor_x, cursor_y;
    reg submarine_power_p1, submarine_power_p2;
    reg continuous_hit;
    reg continuous_hit_p1, continuous_hit_p2;
    
    // Warning display
    reg show_warning;
    reg [31:0] warning_counter;

    // 調整 Warning 顯示區域
    wire is_warning_border = show_warning && 
        ((h_cnt < 5) || (h_cnt >= SCREEN_WIDTH-5) || 
         (v_cnt < 5) || (v_cnt >= SCREEN_HEIGHT-5));

    // 炸完等待三秒
    reg wait_3sec;
    reg [31:0] wait_3sec_counter;

    reg key_pressed;
    reg [8:0] pressed_key;

    // Background image handling
    wire [16:0] pixel_addr;
    wire [11:0] pixel_data_bg [0:4];  // For 5 background images
    
    // 在顯示邏輯中添加提示區域
    wire in_continuous_hint = (h_cnt >= CONTINUOUS_HINT_X) && 
            (h_cnt < CONTINUOUS_HINT_X + CONTINUOUS_HINT_WIDTH) &&
            (v_cnt >= CONTINUOUS_HINT_Y) && 
            (v_cnt < CONTINUOUS_HINT_Y + CONTINUOUS_HINT_HEIGHT);

    // wire is_board_border = (h_cnt == BOARD_X_START + BOARD_SIZE * CELL_SIZE) || 
    //         (v_cnt == BOARD_Y_START + BOARD_SIZE * CELL_SIZE) ||
    //         (h_cnt == BOARD_X_START) ||
    //         (v_cnt == BOARD_Y_START);

    wire is_board_border = 
    (h_cnt >= BOARD_X_START && h_cnt < BOARD_X_START + BOARD_SIZE * CELL_SIZE &&  // 水平方向
     (v_cnt == BOARD_Y_START || v_cnt == BOARD_Y_START + BOARD_SIZE * CELL_SIZE - 1)) ||  // 上下邊框
    (v_cnt >= BOARD_Y_START && v_cnt < BOARD_Y_START + BOARD_SIZE * CELL_SIZE &&  // 垂直方向
     (h_cnt == BOARD_X_START || h_cnt == BOARD_X_START + BOARD_SIZE * CELL_SIZE - 1));  // 左右邊框

    // Clock divider for VGA
    clock_divider #(.n(2)) clk_div (
        .clk(clk),
        .clk_div(pclk)
    );
    
    // 背景圖片地址產生器
    mem_addr_gen addr_gen (
        .clk(clk),
        .rst(rst),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .pixel_addr(pixel_addr)
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
        .key_valid(been_ready),
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
            wait_3sec_counter <= 0;
            key_pressed <= 0;
            pressed_key <= 9'b0;
            submarine_pos_p1_x <= 0;
            submarine_pos_p1_y <= 0;
            submarine_pos_p2_x <= 0;
            submarine_pos_p2_y <= 0;
            LED <= 4'b0000;
            continuous_hit_p1 <= 0;
            continuous_hit_p2 <= 0;

            // Clear boards
            for (i = 0; i < BOARD_SIZE; i = i + 1) begin
                for (j = 0; j < BOARD_SIZE; j = j + 1) begin
                    board_p1[i][j] <= 0;
                    board_p2[i][j] <= 0;
                    check_ship[i][j] <= 0;
                end
            end
        end else begin
            // State transitions and game logic
            case (state)
                INIT: begin
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
                    wait_3sec_counter <= 0;
                    key_pressed <= 0;
                    pressed_key <= 9'b0;
                    submarine_pos_p1_x <= 0;
                    submarine_pos_p1_y <= 0;
                    submarine_pos_p2_x <= 0;
                    submarine_pos_p2_y <= 0;
                    LED <= 4'b0000;
                    continuous_hit_p1 <= 0;
                    continuous_hit_p2 <= 0;

                    // Clear boards
                    for (i = 0; i < BOARD_SIZE; i = i + 1) begin
                        for (j = 0; j < BOARD_SIZE; j = j + 1) begin
                            board_p1[i][j] <= 0;
                            board_p2[i][j] <= 0;
                            check_ship[i][j] <= 0;
                        end
                    end

                    if (been_ready && key_down[last_change] == 1'b1 && last_change == 9'h5A) begin  // Enter key
                        state <= SETUP;
                    end
                end
                
                SETUP: begin
                    if (been_ready && key_down[last_change] == 1'b0 && last_change == pressed_key) begin
                        key_pressed <= 1'b0;
                        pressed_key <= 9'b0;
                        LED <= 4'b0000;
                    end

                    // 如果當前沒有任一按鍵被按下or其他按鍵被按著，才可以更新
                    // Ship placement logic
                    if (been_ready && key_down[last_change] == 1'b1 && !key_pressed) begin
                        key_pressed <= 1'b1;
                        pressed_key <= last_change;
                        case (last_change)
                            9'h1D: begin  // Up
                                ship_pos_y <= (ship_pos_y > 0) ? ship_pos_y - 1 : 0;
                                LED <= 4'b1000;  // LED[3]
                            end
                            9'h1B: begin  // Down
                                ship_pos_y <= (ship_pos_y < BOARD_SIZE-1) ? ship_pos_y + 1 : ship_pos_y;
                                LED <= 4'b0100;  // LED[2]
                            end
                            9'h1C: begin  // Left
                                ship_pos_x <= (ship_pos_x > 0) ? ship_pos_x - 1 : 0;
                                LED <= 4'b0010;  // LED[1]
                            end
                            9'h23: begin  // Right
                                ship_pos_x <= (ship_pos_x < BOARD_SIZE-1) ? ship_pos_x + 1 : ship_pos_x;
                                LED <= 4'b0001;  // LED[0]
                            end
                            9'h12: ship_vertical <= ~ship_vertical;  // Shift for rotation
                            9'h5A: begin  // Enter for placement
                                if (is_valid_placement(1'b0)) begin
                                    place_ship();
                                    if (current_ship == DESTROYER) begin
                                        if (player1_turn && !ships_placed_p1[4]) begin
                                            ships_placed_p1[4] <= 1;
                                            player1_turn <= 0;
                                            current_ship <= CARRIER;
                                        end else if (!player1_turn && !ships_placed_p2[4]) begin
                                            ships_placed_p2[4] <= 1;
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
                    if (check_game_over(0)) begin
                        state <= FINISH;
                    end
                    else begin
                        if (been_ready && key_down[last_change] == 1'b0 && last_change == pressed_key) begin
                            key_pressed <= 1'b0;
                            pressed_key <= 9'b0;
                            LED <= 4'b0000;
                        end
                        // Game playing logic
                        if (been_ready && key_down[last_change] == 1'b1 && !key_pressed) begin
                            key_pressed <= 1'b1;
                            pressed_key <= last_change;

                            case (last_change)
                                9'h1D: begin  // Up
                                    cursor_y <= (cursor_y > 0) ? cursor_y - 1 : 0;
                                    LED <= 4'b1000;
                                end
                                9'h1B: begin  // Down
                                    cursor_y <= (cursor_y < BOARD_SIZE-1) ? cursor_y + 1 : cursor_y;
                                    LED <= 4'b0100;
                                end
                                9'h1C: begin  // Left
                                    cursor_x <= (cursor_x > 0) ? cursor_x - 1 : 0;
                                    LED <= 4'b0010;
                                end
                                9'h23: begin  // Right
                                    cursor_x <= (cursor_x < BOARD_SIZE-1) ? cursor_x + 1 : cursor_x;
                                    LED <= 4'b0001;
                                end
                                9'h29: begin  // Space for shooting
                                    if (player1_turn) begin
                                        if (board_p2[cursor_y][cursor_x] == 1) begin  // Hit
                                            board_p2[cursor_y][cursor_x] <= 2;
                                            if (continuous_hit_p1) begin  // 如果開啟了連續轟炸
                                                wait_3sec <= 1;
                                                wait_3sec_counter <= 32'd100_000_000;
                                                // player1_turn <= 1;  // 保持當前玩家
                                            end else begin
                                                wait_3sec <= 1;
                                                wait_3sec_counter <= 32'd100_000_000;
                                                //player1_turn <= 0;  // 換對手
                                            end
                                        end
                                        else if(board_p2[cursor_y][cursor_x] == 2 || board_p2[cursor_y][cursor_x] == 3) begin
                                            // warning
                                            show_warning <= 1;
                                            warning_counter <= 32'd75_000_000;
                                        end
                                        else begin  // Miss
                                            board_p2[cursor_y][cursor_x] <= 3;
                                            continuous_hit_p1 <= 0;  // 關閉連續轟炸
                                            wait_3sec <= 1;
                                            wait_3sec_counter <= 32'd100_000_000;
                                            //player1_turn <= 0;  // 換對手
                                        end
                                    end else begin  // 玩家2的回合
                                        if (board_p1[cursor_y][cursor_x] == 1) begin  // Hit
                                            board_p1[cursor_y][cursor_x] <= 2;
                                            if (continuous_hit_p2) begin  // 如果開啟了連續轟炸
                                                wait_3sec <= 1;
                                                wait_3sec_counter <= 32'd100_000_000;
                                                //player1_turn <= 0;  // 保持當前玩家
                                            end else begin
                                                wait_3sec <= 1;
                                                wait_3sec_counter <= 32'd100_000_000;
                                                //player1_turn <= 1;  // 換對手
                                            end
                                        end 
                                        else if(board_p1[cursor_y][cursor_x] == 2 || board_p1[cursor_y][cursor_x] == 3) begin
                                            // warning
                                            show_warning <= 1;
                                            warning_counter <= 32'd75_000_000;
                                        end
                                        else begin  // Miss
                                            board_p1[cursor_y][cursor_x] <= 3;
                                            continuous_hit_p2 <= 0;  // 關閉連續轟炸
                                            wait_3sec <= 1;
                                            wait_3sec_counter <= 32'd100_000_000;
                                            // player1_turn <= 1;  // 換對手
                                        end
                                        
                                    end
                                    
                                    // Check for game end
                                    if (check_game_over(0)) begin
                                        state <= FINISH;
                                    end
                                end
                                9'h58: begin  // Caps Lock for submarine power
                                    if (player1_turn && submarine_power_p1 && !is_submarine_destroyed(1'b0)) begin
                                        continuous_hit_p1 <= 1;
                                        submarine_power_p1 <= 0;
                                    end else if (!player1_turn && submarine_power_p2 && !is_submarine_destroyed(1'b0)) begin
                                        continuous_hit_p2 <= 1;
                                        submarine_power_p2 <= 0;
                                    end else begin
                                        show_warning <= 1;
                                        warning_counter <= 32'd75_000_000;
                                    end
                                end
                            endcase
                        end
                    end
                end
                
                FINISH: begin
                    if (been_ready && key_down[last_change] == 1'b1 && last_change == 9'h5A) begin  // Enter key
                        state <= INIT;
                    end
                end

                default: begin
                    LED <= 4'b0000;  // 其他狀態關閉 LED
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

            // wait 3 second timer
            if (wait_3sec) begin
                if (wait_3sec_counter > 0) begin
                    wait_3sec_counter <= wait_3sec_counter - 1;
                end else begin
                    wait_3sec <= 0;
                    if(continuous_hit_p1) player1_turn <= 1;
                    else if(continuous_hit_p2) player1_turn <= 0; 
                    else player1_turn <= !player1_turn;
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
                SUBMARINE: begin 
                    ship_length = 3;
                    // 記錄潛水艦位置
                    if (player1_turn) begin
                        submarine_pos_p1_x = ship_pos_x;
                        submarine_pos_p1_y = ship_pos_y;
                    end else begin
                        submarine_pos_p2_x = ship_pos_x;
                        submarine_pos_p2_y = ship_pos_y;
                    end
                end
                DESTROYER: ship_length = 2;
                default: ship_length = 0;
            endcase
            
            // Place ship
            for (i = 0; i < ship_length; i = i + 1) begin
                if (ship_vertical) begin
                    if (player1_turn) begin
                        board_p1[ship_pos_y + i][ship_pos_x] <= 1;
                        check_ship[ship_pos_y + i][ship_pos_x] <= current_ship;
                    end else begin
                        board_p2[ship_pos_y + i][ship_pos_x] <= 1;
                        check_ship[ship_pos_y + i][ship_pos_x] <= current_ship;
                    end
                end else begin
                    if (player1_turn) begin
                        board_p1[ship_pos_y][ship_pos_x + i] <= 1;
                        check_ship[ship_pos_y][ship_pos_x + i] <= current_ship;
                    end else begin
                        board_p2[ship_pos_y][ship_pos_x + i] <= 1;
                        check_ship[ship_pos_y][ship_pos_x + i] <= current_ship;
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
    reg is_submarine;

    // Display logic
    always @(*) begin
        if (!valid) begin
            pixel_data = 12'h000;
        end else begin
            if (is_warning_border) begin
                pixel_data = WARNING_COLOR;
            end else begin
                case (state)
                    INIT: begin
                        pixel_data = pixel_data_bg[0];
                    end
                    
                    SETUP: begin
                        if (is_board_border) begin
                            pixel_data = 12'hFFF;  // White border
                        end 
                        else if (in_board) begin
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
                                    is_submarine = check_is_submarine(grid_x, grid_y);
                                    pixel_data = (check_ship[grid_y][grid_x] == SUBMARINE) ? SUBMARINE_COLOR : SHIP_COLOR;
                                end else begin
                                    pixel_data = (player1_turn ? pixel_data_bg[3] : pixel_data_bg[4]);
                                end
                            end
                        end else if (is_in_ship_display(CARRIER, 5) && 
                            !(player1_turn ? ships_placed_p1[CARRIER] : ships_placed_p2[CARRIER])) begin
                            pixel_data = (current_ship == CARRIER) ? 12'hFFF : SHIP_COLOR;
                        end else if (is_in_ship_display(BATTLESHIP, 4) &&
                                    !(player1_turn ? ships_placed_p1[BATTLESHIP] : ships_placed_p2[BATTLESHIP])) begin
                            pixel_data = (current_ship == BATTLESHIP) ? 12'hFFF : SHIP_COLOR;
                        end else if (is_in_ship_display(CRUISER, 3) &&
                                    !(player1_turn ? ships_placed_p1[CRUISER] : ships_placed_p2[CRUISER])) begin
                            pixel_data = (current_ship == CRUISER) ? 12'hFFF : SHIP_COLOR;
                        end else if (is_in_ship_display(SUBMARINE, 3) &&
                                    !(player1_turn ? ships_placed_p1[SUBMARINE] : ships_placed_p2[SUBMARINE])) begin
                            pixel_data = (current_ship == SUBMARINE) ? 12'hFFF : SUBMARINE_COLOR;
                        end else if (is_in_ship_display(DESTROYER, 2) &&
                                    !(player1_turn ? ships_placed_p1[DESTROYER] : ships_placed_p2[DESTROYER])) begin
                            pixel_data = (current_ship == DESTROYER) ? 12'hFFF : SHIP_COLOR;
                        end else begin
                            pixel_data = (player1_turn ? pixel_data_bg[3] : pixel_data_bg[4]);
                        end
                    end
                    
                    GAME: begin
                        if (is_board_border) begin
                            pixel_data = 12'hFFF;  // White border
                        end 
                        else if (in_board) begin
                            grid_x = board_x / CELL_SIZE;
                            grid_y = board_y / CELL_SIZE;
                            
                            // Grid lines
                            if ((board_x % CELL_SIZE == 0) || (board_y % CELL_SIZE == 0)) begin
                                pixel_data = 12'hFFF;
                            end else begin
                                // Show cursor
                                if ((grid_x == cursor_x) && (grid_y == cursor_y) && wait_3sec == 0) begin
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
                        end else if (in_continuous_hint && 
                            ((player1_turn && continuous_hit_p1) || 
                             (!player1_turn && continuous_hit_p2))) begin
                            // 顯示連續轟炸提示
                            pixel_data = 12'hF00;  // 紅色提示
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
            end
        end
    end

    function check_is_submarine;
        input [3:0] x;
        input [3:0] y;
        reg result;
        integer i;
        begin
            result = 0;
            if (player1_turn) begin
                if (board_p1[y][x] == 1) begin  // 檢查是否有船
                    for (i = 0; i < 3; i = i + 1) begin
                        if (submarine_pos_p1_x == x && submarine_pos_p1_y + i == y)
                            result = 1;
                        if (submarine_pos_p1_y == y && submarine_pos_p1_x + i == x)
                            result = 1;
                    end
                end
            end else begin
                // 檢查 Player 2 的潛水艦
                if (board_p2[y][x] == 1) begin
                    for (i = 0; i < 3; i = i + 1) begin
                        if (submarine_pos_p2_x == x && submarine_pos_p2_y + i == y)
                            result = 1;
                        if (submarine_pos_p2_y == y && submarine_pos_p2_x + i == x)
                            result = 1;
                    end
                end
            end
            check_is_submarine = result;
        end
    endfunction


    
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
    
    function is_submarine_destroyed;
        input dummy;  // Verilog functions require an input
        reg destroyed;
        integer i;
        begin
            destroyed = 1;  // 假設潛艇已被摧毀
            if (player1_turn) begin
                // 檢查玩家1的潛艇位置
                for (i = 0; i < 3; i = i + 1) begin
                    if (board_p1[submarine_pos_p1_y + i][submarine_pos_p1_x] != 2 &&  // 垂直方向
                        board_p1[submarine_pos_p1_y][submarine_pos_p1_x + i] != 2)    // 水平方向
                        destroyed = 0;  // 若未全擊中，則潛艇未被摧毀
                end
            end else begin
                // 檢查玩家2的潛艇位置
                for (i = 0; i < 3; i = i + 1) begin
                    if (board_p2[submarine_pos_p2_y + i][submarine_pos_p2_x] != 2 &&  // 垂直方向
                        board_p2[submarine_pos_p2_y][submarine_pos_p2_x + i] != 2)    // 水平方向
                        destroyed = 0;  // 若未全擊中，則潛艇未被摧毀
                end
            end
            is_submarine_destroyed = destroyed;
        end
    endfunction

    // VGA output assignment
    // assign vgaRed = pixel_data[11:8];
    // assign vgaGreen = pixel_data[7:4];
    // assign vgaBlue = pixel_data[3:0];
    
    assign {vgaRed, vgaGreen, vgaBlue} = (valid==1'b1) ? pixel_data : 12'b0;


endmodule