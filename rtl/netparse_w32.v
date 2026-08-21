module netparse_w32 (
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

    input [255:0] tdata;
    input [31:0] tkeep;
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
    wire _271;
    wire [15:0] _102;
    wire _99;
    wire [14:0] _98;
    wire [15:0] _100;
    wire [3:0] _94;
    wire [12:0] _93;
    wire [16:0] _95;
    wire [19:0] _76;
    wire [15:0] _72;
    wire [3:0] _71;
    wire [19:0] _73;
    wire [15:0] _68;
    wire [19:0] _69;
    wire [15:0] _64;
    wire [19:0] _65;
    wire [15:0] _60;
    wire [19:0] _61;
    wire [15:0] _56;
    wire [19:0] _57;
    wire [15:0] _52;
    wire [19:0] _53;
    wire [15:0] _48;
    wire [19:0] _49;
    wire [15:0] _44;
    wire [19:0] _45;
    wire [15:0] _40;
    wire [19:0] _41;
    wire [15:0] _37;
    wire [19:0] _38;
    wire [19:0] _42;
    wire [19:0] _46;
    wire [19:0] _50;
    wire [19:0] _54;
    wire [19:0] _58;
    wire [19:0] _62;
    wire [19:0] _66;
    wire [19:0] _70;
    wire [19:0] _74;
    reg [19:0] _90;
    wire [15:0] _91;
    wire [16:0] _92;
    wire [16:0] _96;
    wire [15:0] _97;
    wire [15:0] _101;
    wire _103;
    wire _267;
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
    wire _262;
    wire _263;
    wire _264;
    wire _265;
    wire _266;
    wire _268;
    wire _269;
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
    wire [511:0] _33;
    wire [7:0] _255;
    wire [7:0] _254;
    wire [7:0] _253;
    wire [7:0] _252;
    wire [7:0] _251;
    wire [7:0] _250;
    wire [7:0] _249;
    wire [7:0] _248;
    wire [7:0] _247;
    wire [7:0] _246;
    wire [7:0] _245;
    wire [7:0] _244;
    wire [7:0] _243;
    wire [7:0] _242;
    wire [7:0] _241;
    wire [7:0] _240;
    wire [7:0] _239;
    wire [7:0] _238;
    wire [7:0] _237;
    wire [7:0] _236;
    wire [7:0] _235;
    wire [7:0] _234;
    wire [7:0] _233;
    wire [7:0] _232;
    wire [7:0] _231;
    wire [7:0] _230;
    wire [7:0] _229;
    wire [7:0] _228;
    wire [7:0] _227;
    wire [7:0] _226;
    wire [7:0] _225;
    wire [255:0] _12;
    wire [7:0] _224;
    wire [255:0] _256;
    wire [767:0] _257;
    wire [511:0] _258;
    wire [511:0] _13;
    reg [511:0] hdr_acc;
    wire [31:0] _185;
    reg [31:0] _188;
    wire _193;
    wire _196;
    wire _259;
    wire _260;
    wire _261;
    wire _270;
    wire _272;
    reg _275;
    wire _84;
    wire _82;
    wire _81;
    wire _83;
    wire _85;
    reg _88;
    wire [5:0] _425;
    wire _422;
    wire [4:0] _421;
    wire [5:0] _423;
    wire _418;
    wire [5:0] _419;
    wire _414;
    wire [5:0] _415;
    wire _410;
    wire [5:0] _411;
    wire _406;
    wire [5:0] _407;
    wire _402;
    wire [5:0] _403;
    wire _398;
    wire [5:0] _399;
    wire _394;
    wire [5:0] _395;
    wire _390;
    wire [5:0] _391;
    wire _386;
    wire [5:0] _387;
    wire _382;
    wire [5:0] _383;
    wire _378;
    wire [5:0] _379;
    wire _374;
    wire [5:0] _375;
    wire _370;
    wire [5:0] _371;
    wire _366;
    wire [5:0] _367;
    wire _362;
    wire [5:0] _363;
    wire _358;
    wire [5:0] _359;
    wire _354;
    wire [5:0] _355;
    wire _350;
    wire [5:0] _351;
    wire _346;
    wire [5:0] _347;
    wire _342;
    wire [5:0] _343;
    wire _338;
    wire [5:0] _339;
    wire _334;
    wire [5:0] _335;
    wire _330;
    wire [5:0] _331;
    wire _326;
    wire [5:0] _327;
    wire _322;
    wire [5:0] _323;
    wire _318;
    wire [5:0] _319;
    wire _314;
    wire [5:0] _315;
    wire _310;
    wire [5:0] _311;
    wire _306;
    wire [5:0] _307;
    wire _302;
    wire [5:0] _303;
    wire [31:0] _16;
    wire _299;
    wire [5:0] _300;
    wire [5:0] _304;
    wire [5:0] _308;
    wire [5:0] _312;
    wire [5:0] _316;
    wire [5:0] _320;
    wire [5:0] _324;
    wire [5:0] _328;
    wire [5:0] _332;
    wire [5:0] _336;
    wire [5:0] _340;
    wire [5:0] _344;
    wire [5:0] _348;
    wire [5:0] _352;
    wire [5:0] _356;
    wire [5:0] _360;
    wire [5:0] _364;
    wire [5:0] _368;
    wire [5:0] _372;
    wire [5:0] _376;
    wire [5:0] _380;
    wire [5:0] _384;
    wire [5:0] _388;
    wire [5:0] _392;
    wire [5:0] _396;
    wire [5:0] _400;
    wire [5:0] _404;
    wire [5:0] _408;
    wire [5:0] _412;
    wire [5:0] _416;
    wire [5:0] _420;
    wire [5:0] _424;
    wire _426;
    wire _427;
    wire _297;
    wire _428;
    wire _294;
    wire _282;
    wire _280;
    wire _283;
    wire _285;
    wire _17;
    reg _278;
    wire _295;
    wire _19;
    wire _21;
    wire gnd;
    wire vdd;
    wire _290;
    wire _23;
    wire _286;
    wire _291;
    wire _24;
    reg _289;
    wire _25;
    wire _292;
    wire _27;
    wire _293;
    wire _296;
    wire _429;
    wire _28;
    reg _80;
    wire _89;
    reg _432;
    reg _435;
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
    assign _271 = ~ _268;
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
    assign _72 = hdr_acc[255:240];
    assign _71 = 4'b0000;
    assign _73 = { _71,
                   _72 };
    assign _68 = hdr_acc[271:256];
    assign _69 = { _71,
                   _68 };
    assign _64 = hdr_acc[287:272];
    assign _65 = { _71,
                   _64 };
    assign _60 = hdr_acc[303:288];
    assign _61 = { _71,
                   _60 };
    assign _56 = hdr_acc[319:304];
    assign _57 = { _71,
                   _56 };
    assign _52 = hdr_acc[335:320];
    assign _53 = { _71,
                   _52 };
    assign _48 = hdr_acc[351:336];
    assign _49 = { _71,
                   _48 };
    assign _44 = hdr_acc[367:352];
    assign _45 = { _71,
                   _44 };
    assign _40 = hdr_acc[383:368];
    assign _41 = { _71,
                   _40 };
    assign _37 = hdr_acc[399:384];
    assign _38 = { _71,
                   _37 };
    assign _42 = _38 + _41;
    assign _46 = _42 + _45;
    assign _50 = _46 + _49;
    assign _54 = _50 + _53;
    assign _58 = _54 + _57;
    assign _62 = _58 + _61;
    assign _66 = _62 + _65;
    assign _70 = _66 + _69;
    assign _74 = _70 + _73;
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
    assign _267 = ~ _103;
    assign _114 = 16'b0011111111111111;
    assign _113 = hdr_acc[351:336];
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
    assign _127 = hdr_acc[327:320];
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
    assign _139 = hdr_acc[399:392];
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
    assign _151 = hdr_acc[415:400];
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
    assign _262 = _107 | _169;
    assign _263 = _262 | _161;
    assign _264 = _263 | _145;
    assign _265 = _264 | _133;
    assign _266 = _265 | _121;
    assign _268 = _266 | _267;
    assign _269 = ~ _268;
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
    assign _178 = hdr_acc[223:208];
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
    assign _33 = 512'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    assign _255 = _12[255:248];
    assign _254 = _12[247:240];
    assign _253 = _12[239:232];
    assign _252 = _12[231:224];
    assign _251 = _12[223:216];
    assign _250 = _12[215:208];
    assign _249 = _12[207:200];
    assign _248 = _12[199:192];
    assign _247 = _12[191:184];
    assign _246 = _12[183:176];
    assign _245 = _12[175:168];
    assign _244 = _12[167:160];
    assign _243 = _12[159:152];
    assign _242 = _12[151:144];
    assign _241 = _12[143:136];
    assign _240 = _12[135:128];
    assign _239 = _12[127:120];
    assign _238 = _12[119:112];
    assign _237 = _12[111:104];
    assign _236 = _12[103:96];
    assign _235 = _12[95:88];
    assign _234 = _12[87:80];
    assign _233 = _12[79:72];
    assign _232 = _12[71:64];
    assign _231 = _12[63:56];
    assign _230 = _12[55:48];
    assign _229 = _12[47:40];
    assign _228 = _12[39:32];
    assign _227 = _12[31:24];
    assign _226 = _12[23:16];
    assign _225 = _12[15:8];
    assign _12 = tdata;
    assign _224 = _12[7:0];
    assign _256 = { _224,
                    _225,
                    _226,
                    _227,
                    _228,
                    _229,
                    _230,
                    _231,
                    _232,
                    _233,
                    _234,
                    _235,
                    _236,
                    _237,
                    _238,
                    _239,
                    _240,
                    _241,
                    _242,
                    _243,
                    _244,
                    _245,
                    _246,
                    _247,
                    _248,
                    _249,
                    _250,
                    _251,
                    _252,
                    _253,
                    _254,
                    _255 };
    assign _257 = { hdr_acc,
                    _256 };
    assign _258 = _257[511:0];
    assign _13 = _258;
    always @(posedge _21) begin
        if (_19)
            hdr_acc <= _33;
        else
            if (_35)
                hdr_acc <= _13;
    end
    assign _185 = hdr_acc[271:240];
    always @(posedge _21) begin
        if (_19)
            _188 <= _190;
        else
            if (_89)
                _188 <= _185;
    end
    assign _193 = _188 == _192;
    assign _196 = _193 & _195;
    assign _259 = _196 | _201;
    assign _260 = _259 | _206;
    assign _261 = _260 | _211;
    assign _270 = _261 & _269;
    assign _272 = _270 & _271;
    always @(posedge _21) begin
        if (_19)
            _275 <= _111;
        else
            _275 <= _272;
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
    assign _425 = 6'b001010;
    assign _422 = _16[31:31];
    assign _421 = 5'b00000;
    assign _423 = { _421,
                    _422 };
    assign _418 = _16[30:30];
    assign _419 = { _421,
                    _418 };
    assign _414 = _16[29:29];
    assign _415 = { _421,
                    _414 };
    assign _410 = _16[28:28];
    assign _411 = { _421,
                    _410 };
    assign _406 = _16[27:27];
    assign _407 = { _421,
                    _406 };
    assign _402 = _16[26:26];
    assign _403 = { _421,
                    _402 };
    assign _398 = _16[25:25];
    assign _399 = { _421,
                    _398 };
    assign _394 = _16[24:24];
    assign _395 = { _421,
                    _394 };
    assign _390 = _16[23:23];
    assign _391 = { _421,
                    _390 };
    assign _386 = _16[22:22];
    assign _387 = { _421,
                    _386 };
    assign _382 = _16[21:21];
    assign _383 = { _421,
                    _382 };
    assign _378 = _16[20:20];
    assign _379 = { _421,
                    _378 };
    assign _374 = _16[19:19];
    assign _375 = { _421,
                    _374 };
    assign _370 = _16[18:18];
    assign _371 = { _421,
                    _370 };
    assign _366 = _16[17:17];
    assign _367 = { _421,
                    _366 };
    assign _362 = _16[16:16];
    assign _363 = { _421,
                    _362 };
    assign _358 = _16[15:15];
    assign _359 = { _421,
                    _358 };
    assign _354 = _16[14:14];
    assign _355 = { _421,
                    _354 };
    assign _350 = _16[13:13];
    assign _351 = { _421,
                    _350 };
    assign _346 = _16[12:12];
    assign _347 = { _421,
                    _346 };
    assign _342 = _16[11:11];
    assign _343 = { _421,
                    _342 };
    assign _338 = _16[10:10];
    assign _339 = { _421,
                    _338 };
    assign _334 = _16[9:9];
    assign _335 = { _421,
                    _334 };
    assign _330 = _16[8:8];
    assign _331 = { _421,
                    _330 };
    assign _326 = _16[7:7];
    assign _327 = { _421,
                    _326 };
    assign _322 = _16[6:6];
    assign _323 = { _421,
                    _322 };
    assign _318 = _16[5:5];
    assign _319 = { _421,
                    _318 };
    assign _314 = _16[4:4];
    assign _315 = { _421,
                    _314 };
    assign _310 = _16[3:3];
    assign _311 = { _421,
                    _310 };
    assign _306 = _16[2:2];
    assign _307 = { _421,
                    _306 };
    assign _302 = _16[1:1];
    assign _303 = { _421,
                    _302 };
    assign _16 = tkeep;
    assign _299 = _16[0:0];
    assign _300 = { _421,
                    _299 };
    assign _304 = _300 + _303;
    assign _308 = _304 + _307;
    assign _312 = _308 + _311;
    assign _316 = _312 + _315;
    assign _320 = _316 + _319;
    assign _324 = _320 + _323;
    assign _328 = _324 + _327;
    assign _332 = _328 + _331;
    assign _336 = _332 + _335;
    assign _340 = _336 + _339;
    assign _344 = _340 + _343;
    assign _348 = _344 + _347;
    assign _352 = _348 + _351;
    assign _356 = _352 + _355;
    assign _360 = _356 + _359;
    assign _364 = _360 + _363;
    assign _368 = _364 + _367;
    assign _372 = _368 + _371;
    assign _376 = _372 + _375;
    assign _380 = _376 + _379;
    assign _384 = _380 + _383;
    assign _388 = _384 + _387;
    assign _392 = _388 + _391;
    assign _396 = _392 + _395;
    assign _400 = _396 + _399;
    assign _404 = _400 + _403;
    assign _408 = _404 + _407;
    assign _412 = _408 + _411;
    assign _416 = _412 + _415;
    assign _420 = _416 + _419;
    assign _424 = _420 + _423;
    assign _426 = _424 < _425;
    assign _427 = ~ _426;
    assign _297 = ~ _23;
    assign _428 = _297 | _427;
    assign _294 = 1'b1;
    assign _282 = _278 + _294;
    assign _280 = _278 == _294;
    assign _283 = _280 ? _278 : _282;
    assign _285 = _23 ? _111 : _283;
    assign _17 = _285;
    always @(posedge _21) begin
        if (_19)
            _278 <= _111;
        else
            if (_27)
                _278 <= _17;
    end
    assign _295 = _278 == _294;
    assign _19 = clear;
    assign _21 = clock;
    assign gnd = 1'b0;
    assign vdd = 1'b1;
    assign _290 = _28 ? vdd : _289;
    assign _23 = tlast;
    assign _286 = _27 & _23;
    assign _291 = _286 ? gnd : _290;
    assign _24 = _291;
    always @(posedge _21) begin
        if (_19)
            _289 <= _111;
        else
            _289 <= _24;
    end
    assign _25 = _289;
    assign _292 = ~ _25;
    assign _27 = tvalid;
    assign _293 = _27 & _292;
    assign _296 = _293 & _295;
    assign _429 = _296 & _428;
    assign _28 = _429;
    always @(posedge _21) begin
        if (_19)
            _80 <= _111;
        else
            _80 <= _28;
    end
    assign _89 = _80 | _88;
    always @(posedge _21) begin
        if (_19)
            _432 <= _111;
        else
            _432 <= _89;
    end
    always @(posedge _21) begin
        if (_19)
            _435 <= _111;
        else
            _435 <= _432;
    end
    assign valid = _435;
    assign pass = _275;
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
