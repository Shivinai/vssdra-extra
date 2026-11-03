module sine_generator #(
    parameter int WIDTH = 16,
    parameter int FRAC = 13
) (
    input logic signed [WIDTH-1:0] B1_COEF,
    input logic signed [WIDTH-1:0] Y1_INIT,
    input logic [31:0] PACKET_LEN,
    
    input logic CLK,
    input logic RESET,
    input logic M_AXIS_TREADY,
    
    output logic M_AXIS_TVALID,
    output logic M_AXIS_TLAST,
    output logic signed [WIDTH-1:0] M_AXIS_TDATA
);

    localparam int MINUS_ONE = -(1 << FRAC);

    logic LOAD_INIT;
    logic MAC_START;
    logic MAC_CLEAR;
    logic MAC_READY;
    logic ADDR;
    logic REG_WRITE;

    logic signed [WIDTH-1:0] COEFF;
    logic signed [WIDTH-1:0] SAMPLE;
    logic signed [WIDTH-1:0] MAC_DOUT;
    logic signed [WIDTH-1:0] Y_N1;
    logic signed [WIDTH-1:0] Y_N2;
    logic signed [WIDTH-1:0] Y_N1_DIN;

    always_comb begin
        if (ADDR) begin
            COEFF  = WIDTH'(MINUS_ONE);
            SAMPLE = Y_N2;
        end else begin
            COEFF  = B1_COEF;
            SAMPLE = Y_N1;
        end
    end

    sine_generator_control u_sine_generator_control (
        .CLK (CLK),
        .RESET (RESET),
        .PACKET_LEN (PACKET_LEN),
        .MAC_READY (MAC_READY),
        .M_AXIS_TREADY (M_AXIS_TREADY),
        .LOAD_INIT (LOAD_INIT),
        .MAC_START (MAC_START),
        .MAC_CLEAR (MAC_CLEAR),
        .ADDR (ADDR),
        .REG_WRITE (REG_WRITE),
        .M_AXIS_TVALID (M_AXIS_TVALID),
        .M_AXIS_TLAST (M_AXIS_TLAST)
    );

    mac #(
        .WIDTH(WIDTH),
        .FRAC(FRAC)
    ) u_mac (
        .CLK (CLK),
        .RESET (RESET),
        .CLEAR (MAC_CLEAR),
        .START (MAC_START),
        .DIN_A (COEFF),
        .DIN_B (SAMPLE),
        .READY (MAC_READY),
        .DOUT (MAC_DOUT),
        .ACC()
    );

    assign Y_N1_DIN = LOAD_INIT ? WIDTH'(Y1_INIT) : MAC_DOUT;

    register #(
        .WIDTH(WIDTH)
    ) u_register_y1 (
        .CLK (CLK),
        .RESET (RESET),
        .ENABLE (REG_WRITE || LOAD_INIT),
        .DIN (Y_N1_DIN),
        .DOUT (Y_N1)
    );

    register #(
        .WIDTH(WIDTH)
    ) u_register_y2 (
        .CLK (CLK),
        .RESET (RESET),
        .ENABLE (REG_WRITE),
        .DIN (Y_N1),
        .DOUT (Y_N2)
    );

    register #(
        .WIDTH(WIDTH)
    ) u_register_out (
        .CLK (CLK),
        .RESET (RESET),
        .ENABLE (REG_WRITE),
        .DIN (MAC_DOUT),
        .DOUT (M_AXIS_TDATA)
    );

endmodule
