/*
 * Copyright (c) 2026 Vighnesh Sawant
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none

module tt_um_vighnesh_sawant_plane (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire hsync, vsync, video_active;
    wire [9:0] x, y;

    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(x),
        .vpos(y)
    );

    reg [1:0] r, g, b;
    assign uo_out = {hsync, b[0], g[0], r[0], vsync, b[1], g[1], r[1]};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    reg [12:0] frame_count;
    reg [15:0] frame_lfsr;
    reg [18:0] pixel_lfsr;

    always @(posedge clk) begin
        if (!rst_n) begin
            frame_count <= 0;
            frame_lfsr  <= 16'hACE1;
            pixel_lfsr  <= 19'h1_AAAA;
        end else begin
            if (x == 0 && y == 0) begin
                pixel_lfsr  <= 19'h1_AAAA;
                frame_count <= frame_count + 1;

                if (frame_count[3:0] == 4'b0000) begin

                    // x^15 + x^13 + x^12 + x^10 + 1
                    frame_lfsr <= {frame_lfsr[14:0], frame_lfsr[15] ^ frame_lfsr[13] ^ frame_lfsr[12] ^ frame_lfsr[10]};
                end

            end else begin
                // x^19 + x^18 + x^17 + x^14 + 1
                pixel_lfsr <= {pixel_lfsr[17:0], pixel_lfsr[18] ^ pixel_lfsr[17] ^ pixel_lfsr[16] ^ pixel_lfsr[13]};
            end
        end
    end

    wire [11:0] fg_x = x + {frame_count[10:0], 1'b0};
    wire [11:0] mg_x = x + frame_count[11:0];
    wire [11:0] bg_x = x + {1'b0, frame_count[11:1]};

    wire [6:0] fg_block = fg_x[11:5];
    wire [6:0] mg_block = mg_x[11:4];
    wire [6:0] bg_block = bg_x[11:4];

    wire [6:0] fg_hash = fg_block ^ (fg_block << 2) ^ (fg_block >> 1) ^ 7'h55;
    wire [6:0] mg_hash = mg_block ^ (mg_block << 1) ^ (mg_block >> 2) ^ 7'hAA;
    wire [6:0] bg_hash = bg_block ^ (bg_block << 3) ^ (bg_block >> 1) ^ 7'h33;

    wire [9:0] fg_h = 10'd380 - {2'b00, fg_hash, 1'b0};
    wire [9:0] mg_h = 10'd300 - {3'b000, mg_hash};
    wire [9:0] bg_h = 10'd240 - {3'b000, bg_hash};

    wire is_fg = (y > fg_h);
    wire is_mg = (y > mg_h);
    wire is_bg = (y > bg_h);


    wire fg_pair = (fg_x[4:2] == 3'b010) || (fg_x[4:2] == 3'b101);
    wire mg_pair = (mg_x[3:1] == 3'b010) || (mg_x[3:1] == 3'b101);

    wire fg_roof_margin = (y > fg_h + 10'd10);
    wire mg_roof_margin = (y > mg_h + 10'd4);

    wire fg_win = is_fg && fg_roof_margin && fg_pair && (y[3:2] == 2'b00) && fg_hash[0];
    wire mg_win = is_mg && mg_roof_margin && mg_pair && (y[2:1] == 2'b00) && ~mg_hash[1];

    wire [9:0] plane_x = 10'd600 - frame_count[11:2];
    wire [9:0] plane_y = 10'd80 + (frame_count[7] ? frame_count[6:4] : ~frame_count[6:4]);

    wire plane_fuselage = (x > plane_x) && (x < plane_x + 35) && (y > plane_y + 10) && (y < plane_y + 18);
    wire plane_cockpit  = (x > plane_x + 4) && (x < plane_x + 12) && (y > plane_y + 6) && (y < plane_y + 10);
    wire plane_tail     = (x > plane_x + 28) && (x < plane_x + 35) && (y > plane_y + 2) && (y < plane_y + 10);
    wire plane_wing     = (x > plane_x + 12) && (x < plane_x + 24) && (y > plane_y + 14) && (y < plane_y + 22);

    wire is_plane = plane_fuselage | plane_cockpit | plane_tail | plane_wing;
    wire is_banner_string = (x > plane_x + 35) && (x < plane_x + 50) && (y == plane_y + 14);

    wire [9:0] banner_x_start = plane_x + 10'd50;
    wire [9:0] banner_y_start = plane_y + 10'd4;

    wire is_banner_bg = (x >= banner_x_start) && (x < banner_x_start + 10'd184) &&
                        (y >= banner_y_start - 2) && (y < banner_y_start + 10'd24);

    wire is_text_bounds = (x >= banner_x_start + 4) && (x < banner_x_start + 10'd180) &&
                          (y >= banner_y_start) && (y < banner_y_start + 10'd20);

    wire [9:0] local_x = x - (banner_x_start + 4);
    wire [9:0] local_y = y - banner_y_start;

    wire [5:0] grid_x = local_x[7:2];
    wire [2:0] grid_y = local_y[4:2];

    wire [43:0] active_row =
        (grid_y == 3'd0) ? 44'b1110_0101_0010_1010_1110_1110_1110_1110_1110_1010_1110 :
        (grid_y == 3'd1) ? 44'b0100_0101_1010_1010_0100_1010_1010_1000_1010_1010_0100 :
        (grid_y == 3'd2) ? 44'b0100_0101_0110_1110_0100_1110_1110_1110_1010_1010_0100 :
        (grid_y == 3'd3) ? 44'b0100_0101_0110_0100_0100_1010_1000_1000_1010_1010_0100 :
        (grid_y == 3'd4) ? 44'b0100_0101_0010_0100_0100_1010_1000_1110_1110_1110_0100 :
                           44'd0;

    wire [5:0] safe_index = (grid_x < 6'd44) ? (6'd43 - grid_x) : 6'd0;
    wire current_pixel_bit = (active_row >> safe_index) & 1'b1;
    wire is_text_pixel = is_text_bounds && (grid_x < 6'd44) && current_pixel_bit;

    wire is_star = (pixel_lfsr[18:10] == 9'b101101001) && (y < 130);

    wire star_twinkle = (pixel_lfsr[3:0] == frame_lfsr[3:0]) && frame_lfsr[15];

    always_comb begin
        if (!video_active) begin
            {r, g, b} = 6'b00_00_00;
        end else begin
            if (is_plane || is_text_pixel || is_banner_string) begin
                {r, g, b} = 6'b00_00_00;
            end else if (is_banner_bg) begin
                {r, g, b} = 6'b11_00_10;

            end else if (is_fg) begin
                {r, g, b} = fg_win ? 6'b11_01_01 : 6'b00_00_00;
            end else if (is_mg) begin
                {r, g, b} = mg_win ? 6'b00_11_11 : 6'b01_00_10;
            end else if (is_bg) begin
                {r, g, b} = 6'b01_00_01;

            end else begin
                if (is_star) begin
                    {r, g, b} = star_twinkle ? 6'b01_01_01 : 6'b11_11_11;
                end else if (y < 80) begin
                    {r, g, b} = 6'b00_00_01;
                end else if (y < 160) begin
                    {r, g, b} = 6'b01_00_10;
                end else if (y < 260) begin
                    {r, g, b} = 6'b10_00_01;
                end else begin
                    {r, g, b} = 6'b11_01_00;
                end
            end
        end
    end

endmodule
