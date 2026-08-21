module netparse_w8 (
    tdata,
    tkeep,
    clear,
    clock,
    tlast,
    tvalid,
    valid,
    pass,
    channel,
    dst_ip,
    dst_port,
    err_short,
    err_vlan,
    err_not_ipv4,
    err_bad_ihl,
    err_not_udp,
    err_fragment,
    err_bad_checksum
);

    input [63:0] tdata;
    input [7:0] tkeep;
    input clear;
    input clock;
    input tlast;
    input tvalid;
    output valid;
    output pass;
    output [1:0] channel;
    output [31:0] dst_ip;
    output [15:0] dst_port;
    output err_short;
    output err_vlan;
    output err_not_ipv4;
    output err_bad_ihl;
    output err_not_udp;
    output err_fragment;
    output err_bad_checksum;

    wire _111;
    wire _108;
    wire _104;
    wire _109;
    reg _112;
    wire _122;
    wire _123;
    reg _126;
    wire _134;
    wire _135;
    reg _138;
    wire _146;
    wire _147;
    reg _150;
    wire _162;
    wire _163;
    reg _166;
    wire _170;
    wire _171;
    reg _174;
    reg _177;
    wire [15:0] _183;
    reg [15:0] _184;
    wire [31:0] _190;
    reg [31:0] _191;
    wire [1:0] _222;
    wire [1:0] _217;
    wire [1:0] _215;
    wire [1:0] _213;
    wire [1:0] _214;
    wire [1:0] _216;
    wire [1:0] _218;
    wire [1:0] _220;
    reg [1:0] _223;
    wire _247;
    wire [15:0] _102;
    wire _99;
    wire [14:0] _98;
    wire [15:0] _100;
    wire [3:0] _94;
    wire [12:0] _93;
    wire [16:0] _95;
    wire [19:0] _76;
    wire [15:0] _71;
    wire [3:0] _70;
    wire [19:0] _72;
    wire [15:0] _68;
    wire [19:0] _69;
    wire [19:0] _73;
    wire [15:0] _62;
    wire [19:0] _63;
    wire [15:0] _59;
    wire [19:0] _60;
    wire [19:0] _64;
    wire [15:0] _55;
    wire [19:0] _56;
    wire [15:0] _52;
    wire [19:0] _53;
    wire [19:0] _57;
    wire [19:0] _65;
    wire [15:0] _47;
    wire [19:0] _48;
    wire [15:0] _44;
    wire [19:0] _45;
    wire [19:0] _49;
    wire [15:0] _40;
    wire [19:0] _41;
    wire [15:0] _37;
    wire [19:0] _38;
    wire [19:0] _42;
    wire [19:0] _50;
    wire [19:0] _66;
    wire [19:0] _74;
    reg [19:0] _90;
    wire [15:0] _91;
    wire [16:0] _92;
    wire [16:0] _96;
    wire [15:0] _97;
    wire [15:0] _101;
    wire _103;
    wire _243;
    wire [15:0] _114;
    wire [15:0] _113;
    wire [15:0] _115;
    wire _117;
    wire _118;
    reg _121;
    wire [7:0] _128;
    wire [7:0] _127;
    wire _129;
    wire _130;
    reg _133;
    wire [7:0] _140;
    wire [7:0] _139;
    wire _141;
    wire _142;
    reg _145;
    wire [15:0] _155;
    wire _156;
    wire _157;
    wire _154;
    wire _158;
    reg _161;
    wire [15:0] _152;
    wire [15:0] _151;
    wire _153;
    reg _169;
    reg _107;
    wire _238;
    wire _239;
    wire _240;
    wire _241;
    wire _242;
    wire _244;
    wire _245;
    wire [15:0] _209;
    wire _210;
    wire [31:0] _207;
    wire _208;
    wire _211;
    wire [15:0] _204;
    wire _205;
    wire [31:0] _202;
    wire _203;
    wire _206;
    wire [15:0] _199;
    wire _200;
    wire [31:0] _197;
    wire _198;
    wire _201;
    wire [15:0] _194;
    wire [15:0] _178;
    reg [15:0] _181;
    wire _195;
    wire [31:0] _192;
    wire _34;
    wire _35;
    wire [383:0] _33;
    wire [7:0] _231;
    wire [7:0] _230;
    wire [7:0] _229;
    wire [7:0] _228;
    wire [7:0] _227;
    wire [7:0] _226;
    wire [7:0] _225;
    wire [63:0] _12;
    wire [7:0] _224;
    wire [63:0] _232;
    wire [447:0] _233;
    wire [383:0] _234;
    wire [383:0] _13;
    reg [383:0] hdr_acc;
    wire [31:0] _185;
    reg [31:0] _188;
    wire _193;
    wire _196;
    wire _235;
    wire _236;
    wire _237;
    wire _246;
    wire _248;
    reg _251;
    wire _84;
    wire _82;
    wire _81;
    wire _83;
    wire _85;
    reg _88;
    wire [3:0] _305;
    wire _302;
    wire [2:0] _301;
    wire [3:0] _303;
    wire _298;
    wire [3:0] _299;
    wire _294;
    wire [3:0] _295;
    wire _290;
    wire [3:0] _291;
    wire _286;
    wire [3:0] _287;
    wire _282;
    wire [3:0] _283;
    wire _278;
    wire [3:0] _279;
    wire [7:0] _16;
    wire _275;
    wire [3:0] _276;
    wire [3:0] _280;
    wire [3:0] _284;
    wire [3:0] _288;
    wire [3:0] _292;
    wire [3:0] _296;
    wire [3:0] _300;
    wire [3:0] _304;
    wire _306;
    wire _307;
    wire _273;
    wire _308;
    wire [2:0] _270;
    wire [2:0] _257;
    wire [2:0] _258;
    wire _256;
    wire [2:0] _259;
    wire [2:0] _261;
    wire [2:0] _17;
    reg [2:0] _254;
    wire _271;
    wire _19;
    wire _21;
    wire gnd;
    wire vdd;
    wire _266;
    wire _23;
    wire _262;
    wire _267;
    wire _24;
    reg _265;
    wire _25;
    wire _268;
    wire _27;
    wire _269;
    wire _272;
    wire _309;
    wire _28;
    reg _80;
    wire _89;
    reg _312;
    reg _315;
    assign _111 = 1'b0;
    assign _108 = ~ _107;
    assign _104 = ~ _103;
    assign _109 = _104 & _108;
    always @(posedge _21) begin
        if (_19)
            _112 <= _111;
        else
            _112 <= _109;
    end
    assign _122 = ~ _107;
    assign _123 = _121 & _122;
    always @(posedge _21) begin
        if (_19)
            _126 <= _111;
        else
            _126 <= _123;
    end
    assign _134 = ~ _107;
    assign _135 = _133 & _134;
    always @(posedge _21) begin
        if (_19)
            _138 <= _111;
        else
            _138 <= _135;
    end
    assign _146 = ~ _107;
    assign _147 = _145 & _146;
    always @(posedge _21) begin
        if (_19)
            _150 <= _111;
        else
            _150 <= _147;
    end
    assign _162 = ~ _107;
    assign _163 = _161 & _162;
    always @(posedge _21) begin
        if (_19)
            _166 <= _111;
        else
            _166 <= _163;
    end
    assign _170 = ~ _107;
    assign _171 = _169 & _170;
    always @(posedge _21) begin
        if (_19)
            _174 <= _111;
        else
            _174 <= _171;
    end
    always @(posedge _21) begin
        if (_19)
            _177 <= _111;
        else
            _177 <= _107;
    end
    assign _183 = 16'b0000000000000000;
    always @(posedge _21) begin
        if (_19)
            _184 <= _183;
        else
            _184 <= _181;
    end
    assign _190 = 32'b00000000000000000000000000000000;
    always @(posedge _21) begin
        if (_19)
            _191 <= _190;
        else
            _191 <= _188;
    end
    assign _222 = 2'b00;
    assign _217 = 2'b01;
    assign _215 = 2'b10;
    assign _213 = 2'b11;
    assign _214 = _211 ? _213 : _222;
    assign _216 = _206 ? _215 : _214;
    assign _218 = _201 ? _217 : _216;
    assign _220 = _196 ? _222 : _218;
    always @(posedge _21) begin
        if (_19)
            _223 <= _222;
        else
            _223 <= _220;
    end
    assign _247 = ~ _244;
    assign _102 = 16'b1111111111111111;
    assign _99 = _96[16:16];
    assign _98 = 15'b000000000000000;
    assign _100 = { _98,
                    _99 };
    assign _94 = _90[19:16];
    assign _93 = 13'b0000000000000;
    assign _95 = { _93,
                   _94 };
    assign _76 = 20'b00000000000000000000;
    assign _71 = hdr_acc[127:112];
    assign _70 = 4'b0000;
    assign _72 = { _70,
                   _71 };
    assign _68 = hdr_acc[143:128];
    assign _69 = { _70,
                   _68 };
    assign _73 = _69 + _72;
    assign _62 = hdr_acc[159:144];
    assign _63 = { _70,
                   _62 };
    assign _59 = hdr_acc[175:160];
    assign _60 = { _70,
                   _59 };
    assign _64 = _60 + _63;
    assign _55 = hdr_acc[191:176];
    assign _56 = { _70,
                   _55 };
    assign _52 = hdr_acc[207:192];
    assign _53 = { _70,
                   _52 };
    assign _57 = _53 + _56;
    assign _65 = _57 + _64;
    assign _47 = hdr_acc[223:208];
    assign _48 = { _70,
                   _47 };
    assign _44 = hdr_acc[239:224];
    assign _45 = { _70,
                   _44 };
    assign _49 = _45 + _48;
    assign _40 = hdr_acc[255:240];
    assign _41 = { _70,
                   _40 };
    assign _37 = hdr_acc[271:256];
    assign _38 = { _70,
                   _37 };
    assign _42 = _38 + _41;
    assign _50 = _42 + _49;
    assign _66 = _50 + _65;
    assign _74 = _66 + _73;
    always @(posedge _21) begin
        if (_19)
            _90 <= _76;
        else
            if (_89)
                _90 <= _74;
    end
    assign _91 = _90[15:0];
    assign _92 = { gnd,
                   _91 };
    assign _96 = _92 + _95;
    assign _97 = _96[15:0];
    assign _101 = _97 + _100;
    assign _103 = _101 == _102;
    assign _243 = ~ _103;
    assign _114 = 16'b0011111111111111;
    assign _113 = hdr_acc[223:208];
    assign _115 = _113 & _114;
    assign _117 = _115 == _183;
    assign _118 = ~ _117;
    always @(posedge _21) begin
        if (_19)
            _121 <= _111;
        else
            if (_89)
                _121 <= _118;
    end
    assign _128 = 8'b00010001;
    assign _127 = hdr_acc[199:192];
    assign _129 = _127 == _128;
    assign _130 = ~ _129;
    always @(posedge _21) begin
        if (_19)
            _133 <= _111;
        else
            if (_89)
                _133 <= _130;
    end
    assign _140 = 8'b01000101;
    assign _139 = hdr_acc[271:264];
    assign _141 = _139 == _140;
    assign _142 = ~ _141;
    always @(posedge _21) begin
        if (_19)
            _145 <= _111;
        else
            if (_89)
                _145 <= _142;
    end
    assign _155 = 16'b0000100000000000;
    assign _156 = _151 == _155;
    assign _157 = ~ _156;
    assign _154 = ~ _153;
    assign _158 = _154 & _157;
    always @(posedge _21) begin
        if (_19)
            _161 <= _111;
        else
            if (_89)
                _161 <= _158;
    end
    assign _152 = 16'b1000000100000000;
    assign _151 = hdr_acc[287:272];
    assign _153 = _151 == _152;
    always @(posedge _21) begin
        if (_19)
            _169 <= _111;
        else
            if (_89)
                _169 <= _153;
    end
    always @(posedge _21) begin
        if (_19)
            _107 <= _111;
        else
            _107 <= _88;
    end
    assign _238 = _107 | _169;
    assign _239 = _238 | _161;
    assign _240 = _239 | _145;
    assign _241 = _240 | _133;
    assign _242 = _241 | _121;
    assign _244 = _242 | _243;
    assign _245 = ~ _244;
    assign _209 = 16'b0001000011100001;
    assign _210 = _181 == _209;
    assign _207 = 32'b11000000101010000000000100000010;
    assign _208 = _188 == _207;
    assign _211 = _208 & _210;
    assign _204 = 16'b0011101010011010;
    assign _205 = _181 == _204;
    assign _202 = 32'b11101111110000000000000000000011;
    assign _203 = _188 == _202;
    assign _206 = _203 & _205;
    assign _199 = 16'b0011101010011001;
    assign _200 = _181 == _199;
    assign _197 = 32'b11101111110000000000000000000010;
    assign _198 = _188 == _197;
    assign _201 = _198 & _200;
    assign _194 = 16'b0011101010011000;
    assign _178 = hdr_acc[95:80];
    always @(posedge _21) begin
        if (_19)
            _181 <= _183;
        else
            if (_89)
                _181 <= _178;
    end
    assign _195 = _181 == _194;
    assign _192 = 32'b11101111110000000000000000000001;
    assign _34 = ~ _25;
    assign _35 = _27 & _34;
    assign _33 = 384'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    assign _231 = _12[63:56];
    assign _230 = _12[55:48];
    assign _229 = _12[47:40];
    assign _228 = _12[39:32];
    assign _227 = _12[31:24];
    assign _226 = _12[23:16];
    assign _225 = _12[15:8];
    assign _12 = tdata;
    assign _224 = _12[7:0];
    assign _232 = { _224,
                    _225,
                    _226,
                    _227,
                    _228,
                    _229,
                    _230,
                    _231 };
    assign _233 = { hdr_acc,
                    _232 };
    assign _234 = _233[383:0];
    assign _13 = _234;
    always @(posedge _21) begin
        if (_19)
            hdr_acc <= _33;
        else
            if (_35)
                hdr_acc <= _13;
    end
    assign _185 = hdr_acc[143:112];
    always @(posedge _21) begin
        if (_19)
            _188 <= _190;
        else
            if (_89)
                _188 <= _185;
    end
    assign _193 = _188 == _192;
    assign _196 = _193 & _195;
    assign _235 = _196 | _201;
    assign _236 = _235 | _206;
    assign _237 = _236 | _211;
    assign _246 = _237 & _245;
    assign _248 = _246 & _247;
    always @(posedge _21) begin
        if (_19)
            _251 <= _111;
        else
            _251 <= _248;
    end
    assign _84 = ~ _28;
    assign _82 = ~ _25;
    assign _81 = _27 & _23;
    assign _83 = _81 & _82;
    assign _85 = _83 & _84;
    always @(posedge _21) begin
        if (_19)
            _88 <= _111;
        else
            _88 <= _85;
    end
    assign _305 = 4'b0010;
    assign _302 = _16[7:7];
    assign _301 = 3'b000;
    assign _303 = { _301,
                    _302 };
    assign _298 = _16[6:6];
    assign _299 = { _301,
                    _298 };
    assign _294 = _16[5:5];
    assign _295 = { _301,
                    _294 };
    assign _290 = _16[4:4];
    assign _291 = { _301,
                    _290 };
    assign _286 = _16[3:3];
    assign _287 = { _301,
                    _286 };
    assign _282 = _16[2:2];
    assign _283 = { _301,
                    _282 };
    assign _278 = _16[1:1];
    assign _279 = { _301,
                    _278 };
    assign _16 = tkeep;
    assign _275 = _16[0:0];
    assign _276 = { _301,
                    _275 };
    assign _280 = _276 + _279;
    assign _284 = _280 + _283;
    assign _288 = _284 + _287;
    assign _292 = _288 + _291;
    assign _296 = _292 + _295;
    assign _300 = _296 + _299;
    assign _304 = _300 + _303;
    assign _306 = _304 < _305;
    assign _307 = ~ _306;
    assign _273 = ~ _23;
    assign _308 = _273 | _307;
    assign _270 = 3'b101;
    assign _257 = 3'b001;
    assign _258 = _254 + _257;
    assign _256 = _254 == _270;
    assign _259 = _256 ? _254 : _258;
    assign _261 = _23 ? _301 : _259;
    assign _17 = _261;
    always @(posedge _21) begin
        if (_19)
            _254 <= _301;
        else
            if (_27)
                _254 <= _17;
    end
    assign _271 = _254 == _270;
    assign _19 = clear;
    assign _21 = clock;
    assign gnd = 1'b0;
    assign vdd = 1'b1;
    assign _266 = _28 ? vdd : _265;
    assign _23 = tlast;
    assign _262 = _27 & _23;
    assign _267 = _262 ? gnd : _266;
    assign _24 = _267;
    always @(posedge _21) begin
        if (_19)
            _265 <= _111;
        else
            _265 <= _24;
    end
    assign _25 = _265;
    assign _268 = ~ _25;
    assign _27 = tvalid;
    assign _269 = _27 & _268;
    assign _272 = _269 & _271;
    assign _309 = _272 & _308;
    assign _28 = _309;
    always @(posedge _21) begin
        if (_19)
            _80 <= _111;
        else
            _80 <= _28;
    end
    assign _89 = _80 | _88;
    always @(posedge _21) begin
        if (_19)
            _312 <= _111;
        else
            _312 <= _89;
    end
    always @(posedge _21) begin
        if (_19)
            _315 <= _111;
        else
            _315 <= _312;
    end
    assign valid = _315;
    assign pass = _251;
    assign channel = _223;
    assign dst_ip = _191;
    assign dst_port = _184;
    assign err_short = _177;
    assign err_vlan = _174;
    assign err_not_ipv4 = _166;
    assign err_bad_ihl = _150;
    assign err_not_udp = _138;
    assign err_fragment = _126;
    assign err_bad_checksum = _112;

endmodule
