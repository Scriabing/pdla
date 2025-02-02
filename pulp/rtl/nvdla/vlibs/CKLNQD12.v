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
// File Name: CKLNQD12.v
module CKLNQD12 (
  TE
 ,E
 ,CP
 ,Q
 );
input TE ;
input E ;
input CP ;
output Q ;
reg qd;
always @(negedge CP)
    qd <= TE | E;
assign Q = CP & qd;
endmodule
