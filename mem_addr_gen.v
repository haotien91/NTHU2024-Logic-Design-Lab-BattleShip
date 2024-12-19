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

    // 使用更精確的定點運算
    wire [31:0] x_scaled = (h_cnt * IMG_WIDTH * 1024) / SCREEN_WIDTH;
    wire [31:0] y_scaled = (v_cnt * IMG_HEIGHT * 1024) / SCREEN_HEIGHT;
    
    wire [9:0] x_final = x_scaled[19:10];  // 除以1024
    wire [9:0] y_final = y_scaled[19:10];

    always @(*) begin
        if (h_cnt < SCREEN_WIDTH && v_cnt < SCREEN_HEIGHT) begin
            if (x_final >= IMG_WIDTH || y_final >= IMG_HEIGHT)
                pixel_addr = 0;
            else
                pixel_addr = y_final * IMG_WIDTH + x_final;
        end else begin
            pixel_addr = 0;
        end
    end
endmodule