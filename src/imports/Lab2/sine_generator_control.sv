module sine_generator_control (
    input logic CLK,
    input logic RESET,
    input logic [31:0] PACKET_LEN,
    input logic MAC_READY,
    input logic M_AXIS_TREADY,

    output logic LOAD_INIT,
    output logic MAC_START,
    output logic MAC_CLEAR,
    output logic ADDR,
    output logic REG_WRITE,
    output logic M_AXIS_TVALID,
    output logic M_AXIS_TLAST
);

    typedef enum logic [1:0] {
        INIT,
        START,
        WAIT,
        WRITE
    } STATE_T;

    STATE_T STATE, NEXT_STATE;

    logic [31:0] COUNTER;
    logic OUT_FREE;
    logic LEN_VALID;
    logic LAST_SAMPLE;

    assign OUT_FREE = !M_AXIS_TVALID || M_AXIS_TREADY;
    assign LEN_VALID = (PACKET_LEN != 32'd0);
    assign LAST_SAMPLE = LEN_VALID && (COUNTER == PACKET_LEN - 32'd1);

    assign LOAD_INIT = (STATE == INIT);
    assign MAC_START = (STATE == START);
    assign MAC_CLEAR = (STATE == START) && !ADDR;
    assign REG_WRITE = (STATE == WRITE) && OUT_FREE;

    always_ff @(posedge CLK) begin
        if (RESET) begin
            STATE <= INIT;
            ADDR <= 1'b0;
        end else begin
            STATE <= NEXT_STATE;
            if (STATE == WAIT && MAC_READY) begin
                ADDR <= !ADDR;
            end
        end
    end

    always_comb begin
        NEXT_STATE = STATE;

        case (STATE)
            INIT: NEXT_STATE = START;

            START: NEXT_STATE = WAIT;

            WAIT: begin
                if (MAC_READY) begin
                    NEXT_STATE = ADDR ? WRITE : START;
                end
            end

            WRITE: begin
                if (OUT_FREE) begin
                    NEXT_STATE = START;
                end
            end

            default: NEXT_STATE = START;
        endcase
    end

    always_ff @(posedge CLK) begin
        if (RESET) begin
            M_AXIS_TVALID <= 1'b0;
            M_AXIS_TLAST <= 1'b0;
            COUNTER <= '0;
        end else begin
            if (M_AXIS_TVALID && M_AXIS_TREADY) begin
                M_AXIS_TVALID <= 1'b0;
            end

            if (REG_WRITE) begin
                M_AXIS_TVALID <= 1'b1;
                M_AXIS_TLAST <= LAST_SAMPLE;
                if (LEN_VALID) begin
                    COUNTER <= LAST_SAMPLE ? '0 : COUNTER + 1'b1;
                end
            end
        end
    end

endmodule