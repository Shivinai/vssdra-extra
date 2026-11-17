`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2026 7:38:43 PM
// Design Name: 
// Module Name: goertzel_filter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module goertzel_filter#(
        parameter int NFILTER = 7,
        parameter int WIDTH = 32,
        parameter int FRAC = 14,
        parameter int I2S_WIDTH = 16
    )(
        input logic CLK,
        input logic RESET,
        
        input logic [31:0] BLOCK_LEN,
        input logic [(NFILTER*WIDTH)-1:0] COEFFS,
        
        input logic signed [I2S_WIDTH-1:0] s_axis_tdata,
        input logic s_axis_tvalid,
        input logic s_axis_tlast,
        output logic s_axis_tready,
        
        output logic m_axis_tlast,
        output logic m_axis_tvalid,
        output logic [NFILTER*WIDTH-1:0] m_axis_tdata1,
        output logic [NFILTER*WIDTH-1:0] m_axis_tdata2,
        input logic m_axis_tready
        
    );
    
    typedef enum logic [2:0] {
        IDLE,
        START,
        HOLDON,
        LOAD,
        FINISH
    } STATE_T;
    
    STATE_T STATE;
    
    localparam logic signed [WIDTH-1:0] S_MAX = {1'b0, {(WIDTH-1){1'b1}}};
    localparam logic signed [WIDTH-1:0] S_MIN = {1'b1, {(WIDTH-1){1'b0}}};
    
    logic signed [WIDTH-1:0] S1 [NFILTER];
    logic signed [WIDTH-1:0] S2 [NFILTER];
    logic signed [WIDTH-1:0] SAMPLE;
    logic [31:0] CNT;
    
    logic MAC_START;
    logic MAC_CLEAR;
    logic [NFILTER-1:0] MAC_READY;
    logic signed [WIDTH-1:0] MAC_DOUT [NFILTER];
    
    logic signed [WIDTH:0] SUM [NFILTER];
    logic signed [WIDTH-1:0] NEW_S [NFILTER];
    
    assign MAC_START = (STATE == START);
    assign MAC_CLEAR = (STATE == START);
    assign s_axis_tready = (STATE == IDLE);
    
    for (genvar g = 0; g < NFILTER; g++) begin : gen_filter
        
        mac #(
            .WIDTH(WIDTH),
            .FRAC(FRAC)
        ) u_mac (
            .CLK(CLK),
            .RESET(RESET),
            .CLEAR(MAC_CLEAR),
            .START(MAC_START),
            .DIN_A(COEFFS[g*WIDTH +: WIDTH]),
            .DIN_B(S1[g]),
            .READY(MAC_READY[g]),
            .DOUT(MAC_DOUT[g]),
            .ACC()
        );
        
        assign SUM[g] = (WIDTH+1)'(MAC_DOUT[g]) + (WIDTH+1)'(SAMPLE) - (WIDTH+1)'(S2[g]);
        assign NEW_S[g] = (SUM[g][WIDTH] != SUM[g][WIDTH-1]) ? (SUM[g][WIDTH] ? S_MIN : S_MAX) : SUM[g][WIDTH-1:0];
        
    end
    
    always_ff @(posedge CLK) begin
        if (RESET) begin
            STATE <= IDLE;
            SAMPLE <= '0;
            CNT <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            m_axis_tdata1 <= '0;
            m_axis_tdata2 <= '0;
            
            for (int i = 0; i < NFILTER; i++) begin
                S1[i] <= '0;
                S2[i] <= '0;
            end
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast <= 1'b0;
            end
            
            case (STATE)
                IDLE: begin
                    if (s_axis_tvalid) begin
                        SAMPLE <= WIDTH'(s_axis_tdata);
                        STATE <= START;
                    end
                end
                
                START: begin
                    STATE <= HOLDON;
                end
                
                HOLDON: begin
                    if (&MAC_READY) begin
                        STATE <= LOAD;
                    end
                end
                
                LOAD: begin
                    for (int i = 0; i < NFILTER; i++) begin
                        S2[i] <= S1[i];
                        S1[i] <= NEW_S[i];
                    end
                    
                    if (CNT + 32'd1 >= BLOCK_LEN) begin
                        STATE <= FINISH;
                    end else begin
                        CNT <= CNT + 32'd1;
                        STATE <= IDLE;
                    end
                end
                
                FINISH: begin
                    for (int i = 0; i < NFILTER; i++) begin
                        m_axis_tdata1[i*WIDTH +: WIDTH] <= S1[i];
                        m_axis_tdata2[i*WIDTH +: WIDTH] <= S2[i];
                        S1[i] <= '0;
                        S2[i] <= '0;
                    end
                    
                    m_axis_tvalid <= 1'b1;
                    m_axis_tlast <= 1'b1;
                    CNT <= '0;
                    STATE <= IDLE;
                end
                
                default: begin
                    STATE <= IDLE;
                end
            endcase
        end
    end
    
endmodule