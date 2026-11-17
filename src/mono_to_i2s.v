`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2026 12:01:05 AM
// Design Name: 
// Module Name: mono_to_i2s
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


module mono_to_i2s (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis:m_axis:out_axis, ASSOCIATED_RESET aresetn" *)
    input wire aclk,
    input wire aresetn,

    input wire [15:0] s_axis_tdata,
    input wire s_axis_tvalid,
    input wire s_axis_tlast,
    output wire s_axis_tready,

    output wire [31:0] m_axis_tdata,
    output wire [2:0] m_axis_tid,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    
    output wire [15:0] out_axis_tdata,
    output wire out_axis_tvalid,
    output wire out_axis_tlast,
    input wire out_axis_tready
);
    reg channel;
    reg [7:0] frame;

    wire [15:0] sample = s_axis_tvalid ? s_axis_tdata : 16'd0;
    wire [3:0] pre = channel ? 4'b0011 : ((frame == 8'd0) ? 4'b0001 : 4'b0010);

    assign m_axis_tdata = {4'b0000, sample, 8'b00000000, pre};
    assign m_axis_tid = {2'b00, channel};
    assign m_axis_tvalid = aresetn;
    assign s_axis_tready = m_axis_tready & channel & aresetn;

    assign out_axis_tdata  = s_axis_tdata;
    assign out_axis_tvalid = s_axis_tvalid & s_axis_tready;
    assign out_axis_tlast = s_axis_tlast;

    always @(posedge aclk) begin
        if (!aresetn) begin
            channel <= 1'b0;
            frame <= 8'd0;
        end else if (m_axis_tvalid && m_axis_tready) begin
            channel <= ~channel;
            if (channel) frame <= (frame == 8'd191) ? 8'd0 : frame + 8'd1;
        end
    end
endmodule