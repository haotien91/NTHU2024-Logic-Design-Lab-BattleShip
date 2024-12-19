module mem_addr_gen(
    input wire clk,
    input wire rst,
    input wire [9:0] h_cnt,
    input wire [9:0] v_cnt,
    output reg [16:0] pixel_addr
);
    parameter SCREEN_WIDTH = 640;
    parameter SCREEN_HEIGHT = 480;
    parameter IMG_WIDTH = 160;
    parameter IMG_HEIGHT = 120;

    // 改進的縮放算法
    wire [19:0] scaled_x_20 = (h_cnt * IMG_WIDTH * 20'd1024) / SCREEN_WIDTH;
    wire [19:0] scaled_y_20 = (v_cnt * IMG_HEIGHT * 20'd1024) / SCREEN_HEIGHT;
    wire [9:0] scaled_x = scaled_x_20[19:10];  // 除以1024，取整數部分
    wire [9:0] scaled_y = scaled_y_20[19:10];

    // 邊界處理
    wire [9:0] final_x = (scaled_x >= IMG_WIDTH) ? (IMG_WIDTH - 1) : scaled_x;
    wire [9:0] final_y = (scaled_y >= IMG_HEIGHT) ? (IMG_HEIGHT - 1) : scaled_y;

    always @(*) begin
        if (h_cnt < SCREEN_WIDTH && v_cnt < SCREEN_HEIGHT) begin
            pixel_addr = final_y * IMG_WIDTH + final_x;
        end else begin
            pixel_addr = 0;
        end
    end
endmodule