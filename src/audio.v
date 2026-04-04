`default_nettype none

module ambient_music_gen (
    input  wire clk,
    input  wire rst_n,
    output reg  audio_out
);

    reg [23:0] beat_counter;
    reg [2:0]  note_index;    
    
    reg [15:0] tone_counter;
    reg [15:0] tone_limit;

    always @(posedge clk) begin
        if (!rst_n) begin
            beat_counter <= 0;
            note_index   <= 0;
            tone_counter <= 0;
            audio_out    <= 0;
        end else begin
            if (beat_counter == 24'd12_499_999) begin
                beat_counter <= 0;
                note_index <= note_index + 1;
            end else begin
                beat_counter <= beat_counter + 1;
            end

            if (tone_counter >= tone_limit) begin
                tone_counter <= 0;
                audio_out <= ~audio_out;
            end else begin
                tone_counter <= tone_counter + 1;
            end
        end
    end

    always @(*) begin
        case (note_index)
            3'd0: tone_limit = 16'd47777;
            3'd1: tone_limit = 16'd37921;
            3'd2: tone_limit = 16'd31888;
            3'd3: tone_limit = 16'd25310;
            
            3'd4: tone_limit = 16'd35793;
            3'd5: tone_limit = 16'd28409;
            3'd6: tone_limit = 16'd23889;
            3'd7: tone_limit = 16'd18961;
            default: tone_limit = 16'd47777;
        endcase
    end

endmodule
