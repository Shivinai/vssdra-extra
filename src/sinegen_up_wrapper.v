`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/01/2026 04:55:39 PM
// Design Name: 
// Module Name: sinegen_up_wrapper
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


module sinegen_up_wrapper #(
    parameter integer ID = 0)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi:m_axis, ASSOCIATED_RESET s_axi_aresetn" *)
    
    input s_axi_aclk,
    input s_axi_aresetn,
    input s_axi_awvalid,
    input [9:0] s_axi_awaddr,
    input [2:0] s_axi_awprot,
    output s_axi_awready,
  
    input s_axi_wvalid,
    input [31:0] s_axi_wdata,
    input [3:0] s_axi_wstrb,
    output s_axi_wready,
  
    output s_axi_bvalid,
    output [1:0] s_axi_bresp,
    input s_axi_bready,
  
    input s_axi_arvalid,
    input [9:0] s_axi_araddr,
    input [2:0] s_axi_arprot,
    output s_axi_arready,
  
    output s_axi_rvalid,
    output [1:0] s_axi_rresp,
    output [31:0] s_axi_rdata,
    input s_axi_rready,
  
    output [15:0] m_axis_tdata,
    output m_axis_tvalid,
    input m_axis_tready,
    output m_axis_tlast
);
    localparam [31:0] CORE_VERSION = {16'h0000, 8'h00, 8'h01};
    localparam [31:0] CORE_MAGIC = 32'h4C414232;

    wire up_clk = s_axi_aclk;
    wire up_rreq_s;
    wire up_wreq_s;
    wire [7:0] up_raddr_s;
    wire [7:0] up_waddr_s;
    wire [31:0] up_wdata_s;
    reg up_wack = 0;
    reg up_rack = 0;
    reg [31:0] up_rdata = 0;

    reg r_enable = 0;
    reg [15:0] r_b1 = 16'd15137;
    reg [15:0] r_y1 = 16'd3135;
    reg [31:0] r_len = 32'd64;

    up_axi #(.AXI_ADDRESS_WIDTH(10)) u_up_axi (
        .up_rstn(s_axi_aresetn),
        .up_clk(up_clk),
        .up_axi_awvalid(s_axi_awvalid),
        .up_axi_awaddr(s_axi_awaddr),
        .up_axi_awready(s_axi_awready),
        .up_axi_wvalid(s_axi_wvalid),
        .up_axi_wdata(s_axi_wdata),
        .up_axi_wstrb(s_axi_wstrb),
        .up_axi_wready(s_axi_wready),
        .up_axi_bvalid(s_axi_bvalid),
        .up_axi_bresp(s_axi_bresp),
        .up_axi_bready(s_axi_bready),
        .up_axi_arvalid(s_axi_arvalid),
        .up_axi_araddr(s_axi_araddr),
        .up_axi_arready(s_axi_arready),
        .up_axi_rvalid(s_axi_rvalid),
        .up_axi_rresp(s_axi_rresp),
        .up_axi_rdata(s_axi_rdata),
        .up_axi_rready(s_axi_rready),
        .up_wreq(up_wreq_s),
        .up_waddr(up_waddr_s),
        .up_wdata(up_wdata_s),
        .up_wack(up_wack),
        .up_rreq(up_rreq_s),
        .up_raddr(up_raddr_s),
        .up_rdata(up_rdata),
        .up_rack(up_rack)
    );
    
    always @(posedge up_clk) begin
        if (!s_axi_aresetn) begin
            up_wack <= 0; r_enable <= 0; r_b1 <= 16'd15137; r_y1 <= 16'd3135; r_len <= 32'd64;
        end else begin
            up_wack <= up_wreq_s;
        
        if (up_wreq_s) case (up_waddr_s)
            8'h03: r_enable <= up_wdata_s[0];
            8'h04: r_b1 <= up_wdata_s[15:0];
            8'h05: r_y1 <= up_wdata_s[15:0];
            8'h06: r_len <= up_wdata_s;
            default: ;
        endcase
        end
    end

    always @(posedge up_clk) begin
        if (!s_axi_aresetn) begin
            up_rack <= 0; up_rdata <= 0; 
        end else begin
            up_rack <= up_rreq_s;
      
        if (up_rreq_s) case (up_raddr_s)
            8'h00: up_rdata <= CORE_VERSION;
            8'h01: up_rdata <= ID;
            8'h02: up_rdata <= CORE_MAGIC;
            8'h03: up_rdata <= {31'd0, r_enable};
            8'h04: up_rdata <= {16'd0, r_b1};
            8'h05: up_rdata <= {16'd0, r_y1};
            8'h06: up_rdata <= r_len;
            default: up_rdata <= 0;
        endcase else up_rdata <= 0;
        end
    end

    wire core_rst = ~s_axi_aresetn | ~r_enable;

    sine_generator #(.WIDTH(16), .FRAC(13)) u_sine (
        .CLK(up_clk),
        .RESET(core_rst),
        .B1_COEF(r_b1),
        .Y1_INIT(r_y1),
        .PACKET_LEN(r_len),
        .M_AXIS_TREADY(m_axis_tready),
        .M_AXIS_TVALID(m_axis_tvalid),
        .M_AXIS_TLAST(m_axis_tlast),
        .M_AXIS_TDATA(m_axis_tdata)
    );
  
endmodule
