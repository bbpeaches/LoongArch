// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
// Date        : Mon Jul 27 11:18:44 2026
// Host        : bbpeaches running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim
//               D:/MyCode/2026LoongArch/src/soc/xilinx_ip/mult_gen_0/mult_gen_0_sim_netlist.v
// Design      : mult_gen_0
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a200tfbg676-2
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "mult_gen_0,mult_gen_v12_0_16,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "mult_gen_v12_0_16,Vivado 2019.2" *) 
(* NotValidForBitStream *)
module mult_gen_0
   (CLK,
    A,
    B,
    CE,
    P);
  (* x_interface_info = "xilinx.com:signal:clock:1.0 clk_intf CLK" *) (* x_interface_parameter = "XIL_INTERFACENAME clk_intf, ASSOCIATED_BUSIF p_intf:b_intf:a_intf, ASSOCIATED_RESET sclr, ASSOCIATED_CLKEN ce, FREQ_HZ 10000000, PHASE 0.000, INSERT_VIP 0" *) input CLK;
  (* x_interface_info = "xilinx.com:signal:data:1.0 a_intf DATA" *) (* x_interface_parameter = "XIL_INTERFACENAME a_intf, LAYERED_METADATA undef" *) input [31:0]A;
  (* x_interface_info = "xilinx.com:signal:data:1.0 b_intf DATA" *) (* x_interface_parameter = "XIL_INTERFACENAME b_intf, LAYERED_METADATA undef" *) input [31:0]B;
  (* x_interface_info = "xilinx.com:signal:clockenable:1.0 ce_intf CE" *) (* x_interface_parameter = "XIL_INTERFACENAME ce_intf, POLARITY ACTIVE_HIGH" *) input CE;
  (* x_interface_info = "xilinx.com:signal:data:1.0 p_intf DATA" *) (* x_interface_parameter = "XIL_INTERFACENAME p_intf, LAYERED_METADATA undef" *) output [63:0]P;

  wire [31:0]A;
  wire [31:0]B;
  wire CE;
  wire CLK;
  wire [63:0]P;
  wire [47:0]NLW_U0_PCASC_UNCONNECTED;
  wire [1:0]NLW_U0_ZERO_DETECT_UNCONNECTED;

  (* C_A_TYPE = "0" *) 
  (* C_A_WIDTH = "32" *) 
  (* C_B_TYPE = "0" *) 
  (* C_B_VALUE = "10000001" *) 
  (* C_B_WIDTH = "32" *) 
  (* C_CCM_IMP = "0" *) 
  (* C_CE_OVERRIDES_SCLR = "0" *) 
  (* C_HAS_CE = "1" *) 
  (* C_HAS_SCLR = "0" *) 
  (* C_HAS_ZERO_DETECT = "0" *) 
  (* C_LATENCY = "2" *) 
  (* C_MODEL_TYPE = "0" *) 
  (* C_MULT_TYPE = "1" *) 
  (* C_OPTIMIZE_GOAL = "1" *) 
  (* C_OUT_HIGH = "63" *) 
  (* C_OUT_LOW = "0" *) 
  (* C_ROUND_OUTPUT = "0" *) 
  (* C_ROUND_PT = "0" *) 
  (* C_VERBOSITY = "0" *) 
  (* C_XDEVICEFAMILY = "artix7" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  mult_gen_0_mult_gen_v12_0_16 U0
       (.A(A),
        .B(B),
        .CE(CE),
        .CLK(CLK),
        .P(P),
        .PCASC(NLW_U0_PCASC_UNCONNECTED[47:0]),
        .SCLR(1'b0),
        .ZERO_DETECT(NLW_U0_ZERO_DETECT_UNCONNECTED[1:0]));
endmodule

(* C_A_TYPE = "0" *) (* C_A_WIDTH = "32" *) (* C_B_TYPE = "0" *) 
(* C_B_VALUE = "10000001" *) (* C_B_WIDTH = "32" *) (* C_CCM_IMP = "0" *) 
(* C_CE_OVERRIDES_SCLR = "0" *) (* C_HAS_CE = "1" *) (* C_HAS_SCLR = "0" *) 
(* C_HAS_ZERO_DETECT = "0" *) (* C_LATENCY = "2" *) (* C_MODEL_TYPE = "0" *) 
(* C_MULT_TYPE = "1" *) (* C_OPTIMIZE_GOAL = "1" *) (* C_OUT_HIGH = "63" *) 
(* C_OUT_LOW = "0" *) (* C_ROUND_OUTPUT = "0" *) (* C_ROUND_PT = "0" *) 
(* C_VERBOSITY = "0" *) (* C_XDEVICEFAMILY = "artix7" *) (* ORIG_REF_NAME = "mult_gen_v12_0_16" *) 
(* downgradeipidentifiedwarnings = "yes" *) 
module mult_gen_0_mult_gen_v12_0_16
   (CLK,
    A,
    B,
    CE,
    SCLR,
    ZERO_DETECT,
    P,
    PCASC);
  input CLK;
  input [31:0]A;
  input [31:0]B;
  input CE;
  input SCLR;
  output [1:0]ZERO_DETECT;
  output [63:0]P;
  output [47:0]PCASC;

  wire \<const0> ;
  wire [31:0]A;
  wire [31:0]B;
  wire CE;
  wire CLK;
  wire [63:0]P;
  wire [47:0]PCASC;
  wire [1:0]NLW_i_mult_ZERO_DETECT_UNCONNECTED;

  assign ZERO_DETECT[1] = \<const0> ;
  assign ZERO_DETECT[0] = \<const0> ;
  GND GND
       (.G(\<const0> ));
  (* C_A_TYPE = "0" *) 
  (* C_A_WIDTH = "32" *) 
  (* C_B_TYPE = "0" *) 
  (* C_B_VALUE = "10000001" *) 
  (* C_B_WIDTH = "32" *) 
  (* C_CCM_IMP = "0" *) 
  (* C_CE_OVERRIDES_SCLR = "0" *) 
  (* C_HAS_CE = "1" *) 
  (* C_HAS_SCLR = "0" *) 
  (* C_HAS_ZERO_DETECT = "0" *) 
  (* C_LATENCY = "2" *) 
  (* C_MODEL_TYPE = "0" *) 
  (* C_MULT_TYPE = "1" *) 
  (* C_OPTIMIZE_GOAL = "1" *) 
  (* C_OUT_HIGH = "63" *) 
  (* C_OUT_LOW = "0" *) 
  (* C_ROUND_OUTPUT = "0" *) 
  (* C_ROUND_PT = "0" *) 
  (* C_VERBOSITY = "0" *) 
  (* C_XDEVICEFAMILY = "artix7" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  mult_gen_0_mult_gen_v12_0_16_viv i_mult
       (.A(A),
        .B(B),
        .CE(CE),
        .CLK(CLK),
        .P(P),
        .PCASC(PCASC),
        .SCLR(1'b0),
        .ZERO_DETECT(NLW_i_mult_ZERO_DETECT_UNCONNECTED[1:0]));
endmodule
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "XILINX"
`pragma protect encrypt_agent_info = "Xilinx Encryption Tool 2019.1"
`pragma protect key_keyowner="Cadence Design Systems.", key_keyname="cds_rsa_key", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=64)
`pragma protect key_block
HPMPLvpmoX7LOmPj78BMT9X1rCnPz6PdhVGZQ307N9haGfAdMGVirvGR3e0Glyn2ieoWqXA6qOQL
t0xn28+h0g==

`pragma protect key_keyowner="Synopsys", key_keyname="SNPS-VCS-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
Nxv/BnutRgdmHnLyK7kvDGjm7WGfFKW2mxQ6xUKF14zS4ziz5pSV0ueW4VqAzUyEPsErIAEuyV6F
m5KCqRBB197Q2NbZa7O7tdAqboX6tPAJzbB6u4U/MmNS1AQcSgtfj5srMbdBzDa5pR4V3HrI0MRj
0xhV1BWf725FYPP4av0=

`pragma protect key_keyowner="Aldec", key_keyname="ALDEC15_001", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
F5KGJgEDQsX2btdjtRUlSmNtuyodIhGXEa3/AXv1Y7qgSO8gknBfiqj5HcIaVA9b4npQpDnNcmq+
1ONAqLeLhdOm9TES+GsTAkh/lClvl89bzfqgOV33iqwQHYIHwSsWMRXT9JSUx+YWu+g6xKpT1Ycn
8BCPsq4QUJIqL6W16fheEHB/lkMgnespIWEYJJG6R6zvv2zG8GiU6cG8zHrRjdvAj8kOkhmiMvSd
YjGXJSMfjw7ojCPSUF+nb6WWhUEmoMA/6lgSVaXRm00YHSZ09k7rKTJWSXFSpTmkL2WOsQhNS0ek
jdTK2KF5K6z2YOK4zkfHgZ+fB0KJyANaLLJH/Q==

`pragma protect key_keyowner="ATRENTA", key_keyname="ATR-SG-2015-RSA-3", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
lFuQXeJ0hi7qnIKAR+37XCSOwp8bGLukonngcICceOVpL87+rxvhP5TyNJ/zXpAWDF0BaRYlGr7d
isPiUStrvUthNyOqCr4vFZyhCdY8n+Mrv3OCvLoLQSarxVXbaKbXb0tPsXJCUdXTrCt9mr5x0Nda
6DAI8FBPlFMAiqnFXnYMwlUiSlkNWUpInuNw7+1eD8kUdckEUV1PDwZ0yjpFqMokMH9oJjN6z0Yy
65D8Tqo288ZMfZQuIimjski+X6EK157XbpyuoZIuYLJ7j6oaATdintgfZpgGzVvhCZtMbx6/SJtR
efW5vLBGiGs7rPBPE2T8fosHGOvmeC9QBSj8Ww==

`pragma protect key_keyowner="Xilinx", key_keyname="xilinxt_2019_02", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
Q8VVvHzTNgU3tZr4+8ia7ylST+kbNPWskONHDOT1dTkB7cHZIAWyzXpQZPuEgk2wJq21PoqmVlG9
t08IYzkfC8vYQ2LRf2Co3SXc7p3gF2OFMC68J9Nf9D+/PXJCJy3QO4H8oO39l6bn8c56K2ARnK0R
mMIALbCWSBDGCWGQmXWZJ+xmDGs1KgTeiSW3bZRftWJ6K8l8BhMit8BLOY2Mi3jJ0WRhN8kKd6JT
D4NU1jTZT6jEtmI7Gnj/AXG6auTqDPHsVQzf+ZzBsLTfw83CFoO70xM997L5cZXlqz8fEDmxezkr
wWxPwJbJeVkRV3tUxlo2Bs2x1uVkXQeNVMI8jg==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VELOCE-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
oUeTLA0HA2uKORUHo1HidNC3lw54gxwlLUkv28qRPv1pz7AEVUbIJ7wsyu2Scju+EkC2Ivi8HbBn
jxkeqRDTAwAbAqIKnY3AdyfojN9Hb8SMLcLnpWLLCpb6E0vwA09r7uqKRZ8wYAgT9CPFvzpQ3zKt
9DTLgQ3rZtFxx2nfCug=

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VERIF-SIM-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
Fayrlym1l14Y48yZ195XboT9ZQmp/mAzUyHby3Y9qJTzDF+m6mRQ/ZbebObo8bu4VAm45JeETPx1
YI4UZNOK4IqKv0BZsAlzUfAYAmqmkmIJYbn2gWUCwXyKX5AoA4ONnlxEHxzZhqtsmEXvxwTEs25/
R7iLzeoMfmwwNHgPNQkteiR4zDlB76CYmgu6EOSUX5Nnitq1oh7qRuU8WqWN7lLfgIC6T7qNHwGD
RPze2yiP06fSG45jPrOn2fvBX9SRbUXjNtiFgmqim4anwJU46v7y3ubit/I6giZhz5PJMZfkDaFX
ag+uCMq4Q8ZEolqMBmjUjat86BdVd4Nmr0yUaA==

`pragma protect key_keyowner="Real Intent", key_keyname="RI-RSA-KEY-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
kIpxh3qIIkWUg8aLJSPKvKhKTPFH7T8fisti5RtNaftS7xh3KDsGLYnF1lYhH2RVXgzbdaVqvtED
5QJazVo6wUFI91xgFeOR5jX+Ny5UBUX2MngsK+UZyZg5+EdtSiDtiJNtQqgjq1Rn+XQCGF3xP80n
7YvuVMbgRHCAfWrWw7ZJ7Y3raRzeIkx+koPFio7XnC+QdRJ0ItO1YtQgF4Sg1Ihr5TH8/RrNn903
kPa+anH9spo3SFCf2Ts11UXAGLdIBmOLMtEAKjjCUbtmjGSeSc0gn2q2I+xRTFcegLevlr/iuLTw
3lFndBAoW40xOiCDjWZ6Rz7J+jZhsRl3D0Bhwg==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-PREC-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
KwuaS2expQ2xNLqKl9ANQW0l8RNrnnB5WeUSOwFrXJbzVq6TH8Q5M04mwvcM5aIoMGTMhob76hE7
MQXTSstaj2xAt4ThvdIuxGOgMeirwPK7hb0PBsBJyvdepAeGt2Q8t07NVWo5Srvo+LYBYtN/XaQW
v6I42N+DMks27t8E9hRwFDzunGTY9DUpGi1gUYULjjstITbX+SNWwP1lrwGqymfW07NjXtALnCvS
hk5PLcNpLVruLviNX6S3hwG0SKiEZRpBwBDsAMlTslWblHEiYOL9WWdu6ANBJjRxV46RYIjaFzlI
FY9FYubUHCaZ5iYSBIcebh75PXK+qhxU3Hh31w==

`pragma protect key_keyowner="Synplicity", key_keyname="SYNP15_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
jhbcak4Z/ZnHH405dXPVdL1qKvp8BtGP4tflBPgz5pXcu+xHbjOmV/X/euzRMSOUXXzw8lVVMleq
IhI8HyifJ7YHlql74MRFhQeWlok3Fe//v2lpo0QIUw024jj/bAkuaCcP4Q5l/KyWIcq6aqGfvfEY
HCOO4xiw7MNYAVzzWUYN4XVXyJ82722Na8VXJVeAoi2wM/YPu6HT0czFqhC434AlEVTTV+TuRmPT
OhJaYR8HRGqBaXomh6hPDVd6e3Nq1e2hB28tPAiFFW7nb7P5YLOBv6sM4t3AAYGERLGvmsd0phmB
xsKW8pgO1S/enndF2S2dwGEuH3cKmcNzAWK07w==

`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 26688)
`pragma protect data_block
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
hkC/fe5EbhG5AjPV
`pragma protect end_protected
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

endmodule
`endif
