`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/17/2026 12:38:31 AM
// Design Name: 
// Module Name: goertzel_up_wrapper
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


module goertzel_up_wrapper #(
    parameter integer ID = 0)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi:s_axis, ASSOCIATED_RESET s_axi_aresetn" *)
    
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
  
    input [31:0] s_axis_tdata,
    input [2:0] s_axis_tid,
    input s_axis_tvalid,
    output s_axis_tready
);
    localparam integer NFILTER = 7;
    localparam [31:0] CORE_VERSION = {16'h0000, 8'h00, 8'h01};
    localparam [31:0] CORE_MAGIC = 32'h47525A4C;
 
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
    reg [31:0] r_len = 32'd1200;
    reg [4:0] r_shift = 5'd12;
    reg r_chan = 1'b0;
    reg [31:0] r_coef [0:NFILTER-1];
    
    reg [31:0] r_block_cnt = 0;
    reg [31:0] r_overrun = 0;
    reg [31:0] r_last_raw = 0;
    integer i;
 
    wire core_rst = ~s_axi_aresetn | ~r_enable;
    
    wire m_axis_tlast;
    wire m_axis_tvalid;
    wire m_axis_tready = 1'b1;
    wire [NFILTER*32-1:0] m_axis_tdata1;
    wire [NFILTER*32-1:0] m_axis_tdata2;
 
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
            up_wack <= 0;
            r_enable <= 0;
            r_len <= 32'd1200;
            r_shift <= 5'd12;
            r_chan <= 1'b0;
            
            for (i = 0; i < NFILTER; i = i + 1) begin
                r_coef[i] <= 32'd0;
            end
        end else begin
            up_wack <= up_wreq_s;
        
            if (up_wreq_s) case (up_waddr_s)
                8'h03: r_enable <= up_wdata_s[0];
                8'h04: r_len <= up_wdata_s;
                8'h05: begin
                    r_shift <= up_wdata_s[4:0];
                    r_chan <= up_wdata_s[8];
                end
                default: begin
                    if (up_waddr_s >= 8'h10 && up_waddr_s <= 8'h16) begin
                        r_coef[up_waddr_s[2:0]] <= up_wdata_s;
                    end
                end
            endcase
        end
    end
 
    always @(posedge up_clk) begin
        if (!s_axi_aresetn) begin
            up_rack <= 0;
            up_rdata <= 0; 
        end else begin
            up_rack <= up_rreq_s;
      
            if (up_rreq_s) case (up_raddr_s)
                8'h00: up_rdata <= CORE_VERSION;
                8'h01: up_rdata <= ID;
                8'h02: up_rdata <= CORE_MAGIC;
                8'h03: up_rdata <= {31'd0, r_enable};
                8'h04: up_rdata <= r_len;
                8'h05: up_rdata <= {23'd0, r_chan, 3'd0, r_shift};
                8'h06: up_rdata <= r_block_cnt;
                8'h07: up_rdata <= r_overrun;
                8'h08: up_rdata <= r_last_raw;
                default: begin
                    if (up_raddr_s >= 8'h10 && up_raddr_s <= 8'h16) begin
                        up_rdata <= r_coef[up_raddr_s[2:0]];
                    end else if (up_raddr_s >= 8'h18 && up_raddr_s <= 8'h1E) begin
                        up_rdata <= m_axis_tdata1[up_raddr_s[2:0]*32 +: 32];
                    end else if (up_raddr_s >= 8'h20 && up_raddr_s <= 8'h26) begin
                        up_rdata <= m_axis_tdata2[up_raddr_s[2:0]*32 +: 32];
                    end else begin
                        up_rdata <= 0;
                    end
                end
            endcase else up_rdata <= 0;
        end
    end
 
    wire chan_hit = s_axis_tvalid & (s_axis_tid[0] == r_chan);
    wire [31:0] sample_sh = s_axis_tdata >> r_shift;
    wire signed [15:0] sample16 = sample_sh[15:0];
    wire filter_tready;
    
    assign s_axis_tready = 1'b1;
 
    always @(posedge up_clk) begin
        if (core_rst) begin
            r_block_cnt <= 0;
            r_overrun <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                r_block_cnt <= r_block_cnt + 1;
            end
            
            if (chan_hit && !filter_tready) begin
                r_overrun <= r_overrun + 1;
            end
        end
    end
    
    always @(posedge up_clk) begin
        if (chan_hit) begin
            r_last_raw <= s_axis_tdata;
        end
    end
 
    goertzel_filter #(
        .NFILTER(NFILTER),
        .WIDTH(32),
        .FRAC(14),
        .I2S_WIDTH(16)
    ) u_goertzel (
        .CLK(up_clk),
        .RESET(core_rst),
        .BLOCK_LEN(r_len),
        .COEFFS({r_coef[6], r_coef[5], r_coef[4], r_coef[3], r_coef[2], r_coef[1], r_coef[0]}),
        .s_axis_tdata(sample16),
        .s_axis_tvalid(chan_hit),
        .s_axis_tlast(1'b0),
        .s_axis_tready(filter_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tdata1(m_axis_tdata1),
        .m_axis_tdata2(m_axis_tdata2),
        .m_axis_tready(m_axis_tready)
    );
  
endmodule