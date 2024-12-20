module mem_addr_gen(
    input wire clk,
    input wire rst,
    input wire [9:0] h_cnt,
    input wire [9:0] v_cnt,
    output [16:0] pixel_addr
);
    parameter SCREEN_WIDTH = 640;
    parameter SCREEN_HEIGHT = 480;
    parameter IMG_WIDTH = 160;
    parameter IMG_HEIGHT = 120;

    // 使用更精確的定點運算

    // wire [9:0] x_final = (h_cnt * IMG_WIDTH) / SCREEN_WIDTH;
    // wire [9:0] y_final = (v_cnt * IMG_HEIGHT) / SCREEN_HEIGHT;

    // always @(*) begin
    //     if (h_cnt < SCREEN_WIDTH && v_cnt < SCREEN_HEIGHT) begin
    //         // Ensure coordinates are within image boundaries
    //         if (x_final < IMG_WIDTH && y_final < IMG_HEIGHT)
    //             pixel_addr = y_final * IMG_WIDTH + x_final;
    //         else
    //             pixel_addr = 0;
    //     end else begin
    //         pixel_addr = 0;
    //     end
    // end

    reg [7:0] position;

    // Scale h_cnt and v_cnt for 640x480 to 160x120
    assign pixel_addr = ((h_cnt >> 2) + 160 * (v_cnt >> 2)) % 19200;  // 640x480 -> 160x120

    always @ (posedge clk or posedge rst) begin
        if (rst)
            position <= 0;
        else if (position < 119)  // Adjust for 160x120
            position <= position + 1;
        else
            position <= 0;
    end
endmodule