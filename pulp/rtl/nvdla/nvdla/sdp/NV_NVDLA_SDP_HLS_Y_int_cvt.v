`define VLIB_BYPASS_POWER_CG
`define NV_FPGA_FIFOGEN
`define FIFOGEN_MASTER_CLK_GATING_DISABLED
`define FPGA
`define SYNTHESIS

// ================================================================
// NVDLA Open Source Project
//
// Copyright(c) 2016 - 2017 NVIDIA Corporation. Licensed under the
// NVDLA Open Hardware License; Check "LICENSE" which comes with
// this distribution for more information.
// ================================================================
// File Name: NV_NVDLA_SDP_HLS_Y_int_cvt.v
module NV_NVDLA_SDP_HLS_Y_int_cvt (
   cfg_cvt_bypass //|< i
  ,cfg_cvt_offset //|< i
  ,cfg_cvt_scale //|< i
  ,cfg_cvt_truncate //|< i
  ,cvt_data_in //|< i
  ,cvt_in_pvld //|< i
  ,cvt_out_prdy //|< i
  ,nvdla_core_clk //|< i
  ,nvdla_core_rstn //|< i
  ,cvt_data_out //|> o
  ,cvt_in_prdy //|> o
  ,cvt_out_pvld //|> o
  );
input cfg_cvt_bypass;
input [31:0] cfg_cvt_offset;
input [15:0] cfg_cvt_scale;
input [5:0] cfg_cvt_truncate;
input [15:0] cvt_data_in;
input cvt_in_pvld;
input cvt_out_prdy;
input nvdla_core_clk;
input nvdla_core_rstn;
output [31:0] cvt_data_out;
output cvt_in_prdy;
output cvt_out_pvld;
wire [32:0] cfg_offset_ext;
wire [15:0] cfg_scale;
wire [5:0] cfg_truncate;
wire [32:0] cvt_data_ext;
wire [31:0] cvt_dout;
wire final_out_prdy;
wire final_out_pvld;
wire mon_sub_c;
wire [48:0] mul_data_out;
wire [48:0] mul_dout;
wire mul_out_prdy;
wire mul_out_pvld;
wire [32:0] sub_data_out;
wire [32:0] sub_dout;
wire sub_in_prdy;
wire sub_in_pvld;
wire sub_out_prdy;
wire sub_out_pvld;
wire [31:0] tru_dout;
//sub
assign cfg_scale[15:0] = cfg_cvt_bypass ? {16 {1'b0}} : cfg_cvt_scale[15:0];
assign cfg_truncate[5:0] = cfg_cvt_bypass ? {6 {1'b0}} : cfg_cvt_truncate[5:0];
assign cfg_offset_ext[32:0] = cfg_cvt_bypass ? {33 {1'b0}} : ({{1{cfg_cvt_offset[31]}}, cfg_cvt_offset[31:0]});
assign cvt_data_ext[32:0] = cfg_cvt_bypass ? {33 {1'b0}} : ({{17{cvt_data_in[15]}}, cvt_data_in[15:0]});
assign {mon_sub_c,sub_dout[32:0]} = $signed(cvt_data_ext[32:0]) -$signed(cfg_offset_ext[32:0]);
NV_NVDLA_SDP_HLS_Y_INT_CVT_pipe_p1 pipe_p1 (
   .nvdla_core_clk (nvdla_core_clk) //|< i
  ,.nvdla_core_rstn (nvdla_core_rstn) //|< i
  ,.sub_dout (sub_dout[32:0]) //|< w
  ,.sub_in_pvld (sub_in_pvld) //|< w
  ,.sub_out_prdy (sub_out_prdy) //|< w
  ,.sub_data_out (sub_data_out[32:0]) //|> w
  ,.sub_in_prdy (sub_in_prdy) //|> w
  ,.sub_out_pvld (sub_out_pvld) //|> w
  );
//mul
assign mul_dout[48:0] = $signed(sub_data_out[32:0]) * $signed(cfg_scale[15:0]);
NV_NVDLA_SDP_HLS_Y_INT_CVT_pipe_p2 pipe_p2 (
   .nvdla_core_clk (nvdla_core_clk) //|< i
  ,.nvdla_core_rstn (nvdla_core_rstn) //|< i
  ,.mul_dout (mul_dout[48:0]) //|< w
  ,.mul_out_prdy (mul_out_prdy) //|< w
  ,.sub_out_pvld (sub_out_pvld) //|< w
  ,.mul_data_out (mul_data_out[48:0]) //|> w
  ,.mul_out_pvld (mul_out_pvld) //|> w
  ,.sub_out_prdy (sub_out_prdy) //|> w
  );
//truncate
NV_NVDLA_HLS_shiftrightsu #(.IN_WIDTH(33 + 16 ),.OUT_WIDTH(32 ),.SHIFT_WIDTH(6 )) y_cvt_shiftright_su (
   .data_in (mul_data_out[48:0]) //|< w
  ,.shift_num (cfg_truncate[5:0]) //|< w
  ,.data_out (tru_dout[31:0]) //|> w
  );
//signed
//unsigned
assign sub_in_pvld = cfg_cvt_bypass ? 1'b0 : cvt_in_pvld;
assign cvt_in_prdy = cfg_cvt_bypass ? final_out_prdy : sub_in_prdy;
assign mul_out_prdy = cfg_cvt_bypass ? 1'b1 : final_out_prdy;
assign final_out_pvld = cfg_cvt_bypass ? cvt_in_pvld : mul_out_pvld;
assign cvt_dout[31:0] = cfg_cvt_bypass ? {{16{cvt_data_in[15]}}, cvt_data_in[15:0]} : tru_dout[31:0];
NV_NVDLA_SDP_HLS_Y_INT_CVT_pipe_p3 pipe_p3 (
   .nvdla_core_clk (nvdla_core_clk) //|< i
  ,.nvdla_core_rstn (nvdla_core_rstn) //|< i
  ,.cvt_dout (cvt_dout[31:0]) //|< w
  ,.cvt_out_prdy (cvt_out_prdy) //|< i
  ,.final_out_pvld (final_out_pvld) //|< w
  ,.cvt_data_out (cvt_data_out[31:0]) //|> o
  ,.cvt_out_pvld (cvt_out_pvld) //|> o
  ,.final_out_prdy (final_out_prdy) //|> w
  );
endmodule // NV_NVDLA_SDP_HLS_Y_int_cvt
// **************************************************************************************************************
// Generated by ::pipe -m -bc -rand none -is sub_data_out[32:0] (sub_out_pvld,sub_out_prdy) <= sub_dout[32:0] (sub_in_pvld,sub_in_prdy)
// **************************************************************************************************************
module NV_NVDLA_SDP_HLS_Y_INT_CVT_pipe_p1 (
   nvdla_core_clk
  ,nvdla_core_rstn
  ,sub_dout
  ,sub_in_pvld
  ,sub_out_prdy
  ,sub_data_out
  ,sub_in_prdy
  ,sub_out_pvld
  );
input nvdla_core_clk;
input nvdla_core_rstn;
input [32:0] sub_dout;
input sub_in_pvld;
input sub_out_prdy;
output [32:0] sub_data_out;
output sub_in_prdy;
output sub_out_pvld;
reg [32:0] p1_pipe_data;
reg p1_pipe_ready;
reg p1_pipe_ready_bc;
reg p1_pipe_valid;
reg p1_skid_catch;
reg [32:0] p1_skid_data;
reg [32:0] p1_skid_pipe_data;
reg p1_skid_pipe_ready;
reg p1_skid_pipe_valid;
reg p1_skid_ready;
reg p1_skid_ready_flop;
reg p1_skid_valid;
reg [32:0] sub_data_out;
reg sub_in_prdy;
reg sub_out_pvld;
//## pipe (1) skid buffer
always @(
  sub_in_pvld
  or p1_skid_ready_flop
  or p1_skid_pipe_ready
  or p1_skid_valid
  ) begin
  p1_skid_catch = sub_in_pvld && p1_skid_ready_flop && !p1_skid_pipe_ready;
  p1_skid_ready = (p1_skid_valid)? p1_skid_pipe_ready : !p1_skid_catch;
end
always @(posedge nvdla_core_clk or negedge nvdla_core_rstn) begin
  if (!nvdla_core_rstn) begin
    p1_skid_valid <= 1'b0;
    p1_skid_ready_flop <= 1'b1;
    sub_in_prdy <= 1'b1;
  end else begin
  p1_skid_valid <= (p1_skid_valid)? !p1_skid_pipe_ready : p1_skid_catch;
  p1_skid_ready_flop <= p1_skid_ready;
  sub_in_prdy <= p1_skid_ready;
  end
end
always @(posedge nvdla_core_clk) begin
// VCS sop_coverage_off start
  p1_skid_data <= (p1_skid_catch)? sub_dout[32:0] : p1_skid_data;
// VCS sop_coverage_off end
end
always @(
  p1_skid_ready_flop
  or sub_in_pvld
  or p1_skid_valid
  or sub_dout
  or p1_skid_data
  ) begin
  p1_skid_pipe_valid = (p1_skid_ready_flop)? sub_in_pvld : p1_skid_valid;
// VCS sop_coverage_off start
  p1_skid_pipe_data = (p1_skid_ready_flop)? sub_dout[32:0] : p1_skid_data;
// VCS sop_coverage_off end
end
//## pipe (1) valid-ready-bubble-collapse
always @(
  p1_pipe_ready
  or p1_pipe_valid
  ) begin
  p1_pipe_ready_bc = p1_pipe_ready || !p1_pipe_valid;
end
always @(posedge nvdla_core_clk or negedge nvdla_core_rstn) begin
  if (!nvdla_core_rstn) begin
    p1_pipe_valid <= 1'b0;
  end else begin
  p1_pipe_valid <= (p1_pipe_ready_bc)? p1_skid_pipe_valid : 1'd1;
  end
end
always @(posedge nvdla_core_clk) begin
// VCS sop_coverage_off start
  p1_pipe_data <= (p1_pipe_ready_bc && p1_skid_pipe_valid)? p1_skid_pipe_data : p1_pipe_data;
// VCS sop_coverage_off end
end
always @(
  p1_pipe_ready_bc
  ) begin
  p1_skid_pipe_ready = p1_pipe_ready_bc;
end
//## pipe (1) output
always @(
  p1_pipe_valid
  or sub_out_prdy
  or p1_pipe_data
  ) begin
  sub_out_pvld = p1_pipe_valid;
  p1_pipe_ready = sub_out_prdy;
  sub_data_out[32:0] = p1_pipe_data;
end
//## pipe (1) assertions/testpoints
`ifndef VIVA_PLUGIN_PIPE_DISABLE_ASSERTIONS
wire p1_assert_clk = nvdla_core_clk;
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass disable_block NoWidthInBasedNum-ML
// spyglass disable_block STARC-2.10.3.2a
// spyglass disable_block STARC05-2.1.3.1
// spyglass disable_block STARC-2.1.4.6
// spyglass disable_block W116
// spyglass disable_block W154
// spyglass disable_block W239
// spyglass disable_block W362
// spyglass disable_block WRN_58
// spyglass disable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`ifdef ASSERT_ON
`ifdef FV_ASSERT_ON
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef SYNTHESIS
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef ASSERT_OFF_RESET_IS_X
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b0 : nvdla_core_rstn)
`else
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b1 : nvdla_core_rstn)
`endif // ASSERT_OFF_RESET_IS_X
`endif // SYNTHESIS
`endif // FV_ASSERT_ON
`ifndef SYNTHESIS
// VCS coverage off
  nv_assert_no_x #(0,1,0,"No X's allowed on control signals") zzz_assert_no_x_1x (nvdla_core_clk, `ASSERT_RESET, nvdla_core_rstn, (sub_out_pvld^sub_out_prdy^sub_in_pvld^sub_in_prdy)); // spyglass disable W504 SelfDeterminedExpr-ML 
// VCS coverage on
`endif
`undef ASSERT_RESET
`endif // ASSERT_ON
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass enable_block NoWidthInBasedNum-ML
// spyglass enable_block STARC-2.10.3.2a
// spyglass enable_block STARC05-2.1.3.1
// spyglass enable_block STARC-2.1.4.6
// spyglass enable_block W116
// spyglass enable_block W154
// spyglass enable_block W239
// spyglass enable_block W362
// spyglass enable_block WRN_58
// spyglass enable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass disable_block NoWidthInBasedNum-ML
// spyglass disable_block STARC-2.10.3.2a
// spyglass disable_block STARC05-2.1.3.1
// spyglass disable_block STARC-2.1.4.6
// spyglass disable_block W116
// spyglass disable_block W154
// spyglass disable_block W239
// spyglass disable_block W362
// spyglass disable_block WRN_58
// spyglass disable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`ifdef ASSERT_ON
`ifdef FV_ASSERT_ON
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef SYNTHESIS
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef ASSERT_OFF_RESET_IS_X
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b0 : nvdla_core_rstn)
`else
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b1 : nvdla_core_rstn)
`endif // ASSERT_OFF_RESET_IS_X
`endif // SYNTHESIS
`endif // FV_ASSERT_ON
// VCS coverage off
  nv_assert_hold_throughout_event_interval #(0,1,0,"valid removed before ready") zzz_assert_hold_throughout_event_interval_2x (nvdla_core_clk, `ASSERT_RESET, (sub_in_pvld && !sub_in_prdy), (sub_in_pvld), (sub_in_prdy)); // spyglass disable W504 SelfDeterminedExpr-ML 
// VCS coverage on
`undef ASSERT_RESET
`endif // ASSERT_ON
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass enable_block NoWidthInBasedNum-ML
// spyglass enable_block STARC-2.10.3.2a
// spyglass enable_block STARC05-2.1.3.1
// spyglass enable_block STARC-2.1.4.6
// spyglass enable_block W116
// spyglass enable_block W154
// spyglass enable_block W239
// spyglass enable_block W362
// spyglass enable_block WRN_58
// spyglass enable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`endif
endmodule // NV_NVDLA_SDP_HLS_Y_INT_CVT_pipe_p1
// **************************************************************************************************************
// Generated by ::pipe -m -bc -rand none -is mul_data_out[48:0] (mul_out_pvld,mul_out_prdy) <= mul_dout[48:0] (sub_out_pvld,sub_out_prdy)
// **************************************************************************************************************
module NV_NVDLA_SDP_HLS_Y_INT_CVT_pipe_p2 (
   nvdla_core_clk
  ,nvdla_core_rstn
  ,mul_dout
  ,mul_out_prdy
  ,sub_out_pvld
  ,mul_data_out
  ,mul_out_pvld
  ,sub_out_prdy
  );
input nvdla_core_clk;
input nvdla_core_rstn;
input [48:0] mul_dout;
input mul_out_prdy;
input sub_out_pvld;
output [48:0] mul_data_out;
output mul_out_pvld;
output sub_out_prdy;
reg [48:0] mul_data_out;
reg mul_out_pvld;
reg [48:0] p2_pipe_data;
reg p2_pipe_ready;
reg p2_pipe_ready_bc;
reg p2_pipe_valid;
reg p2_skid_catch;
reg [48:0] p2_skid_data;
reg [48:0] p2_skid_pipe_data;
reg p2_skid_pipe_ready;
reg p2_skid_pipe_valid;
reg p2_skid_ready;
reg p2_skid_ready_flop;
reg p2_skid_valid;
reg sub_out_prdy;
//## pipe (2) skid buffer
always @(
  sub_out_pvld
  or p2_skid_ready_flop
  or p2_skid_pipe_ready
  or p2_skid_valid
  ) begin
  p2_skid_catch = sub_out_pvld && p2_skid_ready_flop && !p2_skid_pipe_ready;
  p2_skid_ready = (p2_skid_valid)? p2_skid_pipe_ready : !p2_skid_catch;
end
always @(posedge nvdla_core_clk or negedge nvdla_core_rstn) begin
  if (!nvdla_core_rstn) begin
    p2_skid_valid <= 1'b0;
    p2_skid_ready_flop <= 1'b1;
    sub_out_prdy <= 1'b1;
  end else begin
  p2_skid_valid <= (p2_skid_valid)? !p2_skid_pipe_ready : p2_skid_catch;
  p2_skid_ready_flop <= p2_skid_ready;
  sub_out_prdy <= p2_skid_ready;
  end
end
always @(posedge nvdla_core_clk) begin
// VCS sop_coverage_off start
  p2_skid_data <= (p2_skid_catch)? mul_dout[48:0] : p2_skid_data;
// VCS sop_coverage_off end
end
always @(
  p2_skid_ready_flop
  or sub_out_pvld
  or p2_skid_valid
  or mul_dout
  or p2_skid_data
  ) begin
  p2_skid_pipe_valid = (p2_skid_ready_flop)? sub_out_pvld : p2_skid_valid;
// VCS sop_coverage_off start
  p2_skid_pipe_data = (p2_skid_ready_flop)? mul_dout[48:0] : p2_skid_data;
// VCS sop_coverage_off end
end
//## pipe (2) valid-ready-bubble-collapse
always @(
  p2_pipe_ready
  or p2_pipe_valid
  ) begin
  p2_pipe_ready_bc = p2_pipe_ready || !p2_pipe_valid;
end
always @(posedge nvdla_core_clk or negedge nvdla_core_rstn) begin
  if (!nvdla_core_rstn) begin
    p2_pipe_valid <= 1'b0;
  end else begin
  p2_pipe_valid <= (p2_pipe_ready_bc)? p2_skid_pipe_valid : 1'd1;
  end
end
always @(posedge nvdla_core_clk) begin
// VCS sop_coverage_off start
  p2_pipe_data <= (p2_pipe_ready_bc && p2_skid_pipe_valid)? p2_skid_pipe_data : p2_pipe_data;
// VCS sop_coverage_off end
end
always @(
  p2_pipe_ready_bc
  ) begin
  p2_skid_pipe_ready = p2_pipe_ready_bc;
end
//## pipe (2) output
always @(
  p2_pipe_valid
  or mul_out_prdy
  or p2_pipe_data
  ) begin
  mul_out_pvld = p2_pipe_valid;
  p2_pipe_ready = mul_out_prdy;
  mul_data_out[48:0] = p2_pipe_data;
end
//## pipe (2) assertions/testpoints
`ifndef VIVA_PLUGIN_PIPE_DISABLE_ASSERTIONS
wire p2_assert_clk = nvdla_core_clk;
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass disable_block NoWidthInBasedNum-ML
// spyglass disable_block STARC-2.10.3.2a
// spyglass disable_block STARC05-2.1.3.1
// spyglass disable_block STARC-2.1.4.6
// spyglass disable_block W116
// spyglass disable_block W154
// spyglass disable_block W239
// spyglass disable_block W362
// spyglass disable_block WRN_58
// spyglass disable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`ifdef ASSERT_ON
`ifdef FV_ASSERT_ON
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef SYNTHESIS
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef ASSERT_OFF_RESET_IS_X
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b0 : nvdla_core_rstn)
`else
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b1 : nvdla_core_rstn)
`endif // ASSERT_OFF_RESET_IS_X
`endif // SYNTHESIS
`endif // FV_ASSERT_ON
`ifndef SYNTHESIS
// VCS coverage off
  nv_assert_no_x #(0,1,0,"No X's allowed on control signals") zzz_assert_no_x_3x (nvdla_core_clk, `ASSERT_RESET, nvdla_core_rstn, (mul_out_pvld^mul_out_prdy^sub_out_pvld^sub_out_prdy)); // spyglass disable W504 SelfDeterminedExpr-ML 
// VCS coverage on
`endif
`undef ASSERT_RESET
`endif // ASSERT_ON
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass enable_block NoWidthInBasedNum-ML
// spyglass enable_block STARC-2.10.3.2a
// spyglass enable_block STARC05-2.1.3.1
// spyglass enable_block STARC-2.1.4.6
// spyglass enable_block W116
// spyglass enable_block W154
// spyglass enable_block W239
// spyglass enable_block W362
// spyglass enable_block WRN_58
// spyglass enable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass disable_block NoWidthInBasedNum-ML
// spyglass disable_block STARC-2.10.3.2a
// spyglass disable_block STARC05-2.1.3.1
// spyglass disable_block STARC-2.1.4.6
// spyglass disable_block W116
// spyglass disable_block W154
// spyglass disable_block W239
// spyglass disable_block W362
// spyglass disable_block WRN_58
// spyglass disable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`ifdef ASSERT_ON
`ifdef FV_ASSERT_ON
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef SYNTHESIS
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef ASSERT_OFF_RESET_IS_X
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b0 : nvdla_core_rstn)
`else
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b1 : nvdla_core_rstn)
`endif // ASSERT_OFF_RESET_IS_X
`endif // SYNTHESIS
`endif // FV_ASSERT_ON
// VCS coverage off
  nv_assert_hold_throughout_event_interval #(0,1,0,"valid removed before ready") zzz_assert_hold_throughout_event_interval_4x (nvdla_core_clk, `ASSERT_RESET, (sub_out_pvld && !sub_out_prdy), (sub_out_pvld), (sub_out_prdy)); // spyglass disable W504 SelfDeterminedExpr-ML 
// VCS coverage on
`undef ASSERT_RESET
`endif // ASSERT_ON
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass enable_block NoWidthInBasedNum-ML
// spyglass enable_block STARC-2.10.3.2a
// spyglass enable_block STARC05-2.1.3.1
// spyglass enable_block STARC-2.1.4.6
// spyglass enable_block W116
// spyglass enable_block W154
// spyglass enable_block W239
// spyglass enable_block W362
// spyglass enable_block WRN_58
// spyglass enable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`endif
endmodule // NV_NVDLA_SDP_HLS_Y_INT_CVT_pipe_p2
// **************************************************************************************************************
// Generated by ::pipe -m -bc -rand none -is cvt_data_out[31:0] (cvt_out_pvld,cvt_out_prdy) <= cvt_dout[31:0] (final_out_pvld,final_out_prdy)
// **************************************************************************************************************
module NV_NVDLA_SDP_HLS_Y_INT_CVT_pipe_p3 (
   nvdla_core_clk
  ,nvdla_core_rstn
  ,cvt_dout
  ,cvt_out_prdy
  ,final_out_pvld
  ,cvt_data_out
  ,cvt_out_pvld
  ,final_out_prdy
  );
input nvdla_core_clk;
input nvdla_core_rstn;
input [31:0] cvt_dout;
input cvt_out_prdy;
input final_out_pvld;
output [31:0] cvt_data_out;
output cvt_out_pvld;
output final_out_prdy;
reg [31:0] cvt_data_out;
reg cvt_out_pvld;
reg final_out_prdy;
reg [31:0] p3_pipe_data;
reg p3_pipe_ready;
reg p3_pipe_ready_bc;
reg p3_pipe_valid;
reg p3_skid_catch;
reg [31:0] p3_skid_data;
reg [31:0] p3_skid_pipe_data;
reg p3_skid_pipe_ready;
reg p3_skid_pipe_valid;
reg p3_skid_ready;
reg p3_skid_ready_flop;
reg p3_skid_valid;
//## pipe (3) skid buffer
always @(
  final_out_pvld
  or p3_skid_ready_flop
  or p3_skid_pipe_ready
  or p3_skid_valid
  ) begin
  p3_skid_catch = final_out_pvld && p3_skid_ready_flop && !p3_skid_pipe_ready;
  p3_skid_ready = (p3_skid_valid)? p3_skid_pipe_ready : !p3_skid_catch;
end
always @(posedge nvdla_core_clk or negedge nvdla_core_rstn) begin
  if (!nvdla_core_rstn) begin
    p3_skid_valid <= 1'b0;
    p3_skid_ready_flop <= 1'b1;
    final_out_prdy <= 1'b1;
  end else begin
  p3_skid_valid <= (p3_skid_valid)? !p3_skid_pipe_ready : p3_skid_catch;
  p3_skid_ready_flop <= p3_skid_ready;
  final_out_prdy <= p3_skid_ready;
  end
end
always @(posedge nvdla_core_clk) begin
// VCS sop_coverage_off start
  p3_skid_data <= (p3_skid_catch)? cvt_dout[31:0] : p3_skid_data;
// VCS sop_coverage_off end
end
always @(
  p3_skid_ready_flop
  or final_out_pvld
  or p3_skid_valid
  or cvt_dout
  or p3_skid_data
  ) begin
  p3_skid_pipe_valid = (p3_skid_ready_flop)? final_out_pvld : p3_skid_valid;
// VCS sop_coverage_off start
  p3_skid_pipe_data = (p3_skid_ready_flop)? cvt_dout[31:0] : p3_skid_data;
// VCS sop_coverage_off end
end
//## pipe (3) valid-ready-bubble-collapse
always @(
  p3_pipe_ready
  or p3_pipe_valid
  ) begin
  p3_pipe_ready_bc = p3_pipe_ready || !p3_pipe_valid;
end
always @(posedge nvdla_core_clk or negedge nvdla_core_rstn) begin
  if (!nvdla_core_rstn) begin
    p3_pipe_valid <= 1'b0;
  end else begin
  p3_pipe_valid <= (p3_pipe_ready_bc)? p3_skid_pipe_valid : 1'd1;
  end
end
always @(posedge nvdla_core_clk) begin
// VCS sop_coverage_off start
  p3_pipe_data <= (p3_pipe_ready_bc && p3_skid_pipe_valid)? p3_skid_pipe_data : p3_pipe_data;
// VCS sop_coverage_off end
end
always @(
  p3_pipe_ready_bc
  ) begin
  p3_skid_pipe_ready = p3_pipe_ready_bc;
end
//## pipe (3) output
always @(
  p3_pipe_valid
  or cvt_out_prdy
  or p3_pipe_data
  ) begin
  cvt_out_pvld = p3_pipe_valid;
  p3_pipe_ready = cvt_out_prdy;
  cvt_data_out[31:0] = p3_pipe_data;
end
//## pipe (3) assertions/testpoints
`ifndef VIVA_PLUGIN_PIPE_DISABLE_ASSERTIONS
wire p3_assert_clk = nvdla_core_clk;
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass disable_block NoWidthInBasedNum-ML
// spyglass disable_block STARC-2.10.3.2a
// spyglass disable_block STARC05-2.1.3.1
// spyglass disable_block STARC-2.1.4.6
// spyglass disable_block W116
// spyglass disable_block W154
// spyglass disable_block W239
// spyglass disable_block W362
// spyglass disable_block WRN_58
// spyglass disable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`ifdef ASSERT_ON
`ifdef FV_ASSERT_ON
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef SYNTHESIS
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef ASSERT_OFF_RESET_IS_X
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b0 : nvdla_core_rstn)
`else
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b1 : nvdla_core_rstn)
`endif // ASSERT_OFF_RESET_IS_X
`endif // SYNTHESIS
`endif // FV_ASSERT_ON
`ifndef SYNTHESIS
// VCS coverage off
  nv_assert_no_x #(0,1,0,"No X's allowed on control signals") zzz_assert_no_x_5x (nvdla_core_clk, `ASSERT_RESET, nvdla_core_rstn, (cvt_out_pvld^cvt_out_prdy^final_out_pvld^final_out_prdy)); // spyglass disable W504 SelfDeterminedExpr-ML 
// VCS coverage on
`endif
`undef ASSERT_RESET
`endif // ASSERT_ON
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass enable_block NoWidthInBasedNum-ML
// spyglass enable_block STARC-2.10.3.2a
// spyglass enable_block STARC05-2.1.3.1
// spyglass enable_block STARC-2.1.4.6
// spyglass enable_block W116
// spyglass enable_block W154
// spyglass enable_block W239
// spyglass enable_block W362
// spyglass enable_block WRN_58
// spyglass enable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass disable_block NoWidthInBasedNum-ML
// spyglass disable_block STARC-2.10.3.2a
// spyglass disable_block STARC05-2.1.3.1
// spyglass disable_block STARC-2.1.4.6
// spyglass disable_block W116
// spyglass disable_block W154
// spyglass disable_block W239
// spyglass disable_block W362
// spyglass disable_block WRN_58
// spyglass disable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`ifdef ASSERT_ON
`ifdef FV_ASSERT_ON
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef SYNTHESIS
`define ASSERT_RESET nvdla_core_rstn
`else
`ifdef ASSERT_OFF_RESET_IS_X
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b0 : nvdla_core_rstn)
`else
`define ASSERT_RESET ((1'bx === nvdla_core_rstn) ? 1'b1 : nvdla_core_rstn)
`endif // ASSERT_OFF_RESET_IS_X
`endif // SYNTHESIS
`endif // FV_ASSERT_ON
// VCS coverage off
  nv_assert_hold_throughout_event_interval #(0,1,0,"valid removed before ready") zzz_assert_hold_throughout_event_interval_6x (nvdla_core_clk, `ASSERT_RESET, (final_out_pvld && !final_out_prdy), (final_out_pvld), (final_out_prdy)); // spyglass disable W504 SelfDeterminedExpr-ML 
// VCS coverage on
`undef ASSERT_RESET
`endif // ASSERT_ON
`ifdef SPYGLASS_ASSERT_ON
`else
// spyglass enable_block NoWidthInBasedNum-ML
// spyglass enable_block STARC-2.10.3.2a
// spyglass enable_block STARC05-2.1.3.1
// spyglass enable_block STARC-2.1.4.6
// spyglass enable_block W116
// spyglass enable_block W154
// spyglass enable_block W239
// spyglass enable_block W362
// spyglass enable_block WRN_58
// spyglass enable_block WRN_61
`endif // SPYGLASS_ASSERT_ON
`endif
endmodule // NV_NVDLA_SDP_HLS_Y_INT_CVT_pipe_p3
