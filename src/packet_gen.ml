(** Builds well-formed Ethernet/IPv4/UDP frames, plus the malformed variants the
    parser is supposed to reject.

    Generating stimulus in OCaml rather than capturing a pcap keeps the tests
    hermetic and lets the checksum be computed with the same
    {!Ref_model.ones_complement_sum} the checker uses -- if that routine is
    wrong, the generator and the reference model are wrong in the same
    direction and the RTL comparison still holds. *)

let put8 buf off v = Bytes.set buf off (Char.chr (v land 0xff))

let put16 buf off v =
  put8 buf off (v lsr 8);
  put8 buf (off + 1) v

let put32 buf off v =
  put16 buf off (v lsr 16);
  put16 buf (off + 2) v

let put_mac buf off mac = List.iteri (fun k b -> put8 buf (off + k) b) mac

type spec =
  { dst_mac : int list
  ; src_mac : int list
  ; src_ip : int
  ; dst_ip : int
  ; src_port : int
  ; dst_port : int
  ; payload_len : int
  ; ethertype : int
  ; ver_ihl : int
  ; proto : int
  ; flags_frag : int
  ; corrupt_checksum : bool
  }

let default =
  { dst_mac = [ 0x00; 0x11; 0x22; 0x33; 0x44; 0x55 ]
  ; src_mac = [ 0x66; 0x77; 0x88; 0x99; 0xaa; 0xbb ]
  ; src_ip = 0xc0a80101 (* 192.168.1.1 *)
  ; dst_ip = 0xc0a80102 (* 192.168.1.2 *)
  ; src_port = 12345
  ; dst_port = 4321
  ; payload_len = 18 (* -> 60-byte frame, the Ethernet minimum *)
  ; ethertype = Packet_defs.ethertype_ipv4
  ; ver_ihl = (Packet_defs.ip_version_4 lsl 4) lor Packet_defs.ip_ihl_no_options
  ; proto = Packet_defs.ip_proto_udp
  ; flags_frag = 0
  ; corrupt_checksum = false
  }

let build (s : spec) : Bytes.t =
  let open Packet_defs in
  let total = header_bytes + s.payload_len in
  let buf = Bytes.make total '\000' in
  (* Ethernet *)
  put_mac buf off_eth_dst_mac s.dst_mac;
  put_mac buf off_eth_src_mac s.src_mac;
  put16 buf off_ethertype s.ethertype;
  (* IPv4 *)
  put8 buf off_ip_ver_ihl s.ver_ihl;
  put8 buf (off_ip + 1) 0;
  put16 buf off_ip_total_len (ipv4_hdr_bytes + udp_hdr_bytes + s.payload_len);
  put16 buf (off_ip + 4) 0x1234;
  put16 buf off_ip_flags_frag s.flags_frag;
  put8 buf off_ip_ttl 64;
  put8 buf off_ip_proto s.proto;
  put16 buf off_ip_checksum 0;
  put32 buf off_ip_src s.src_ip;
  put32 buf off_ip_dst s.dst_ip;
  (* Checksum is computed over the header with the checksum field zeroed. *)
  let csum = Ref_model.ipv4_checksum_for buf ~off:off_ip in
  put16 buf off_ip_checksum (if s.corrupt_checksum then csum lxor 0xffff else csum);
  (* UDP *)
  put16 buf off_udp_src_port s.src_port;
  put16 buf off_udp_dst_port s.dst_port;
  put16 buf off_udp_len (udp_hdr_bytes + s.payload_len);
  put16 buf off_udp_checksum 0;
  (* Payload: a recognisable ramp, so a mis-sliced field shows up as an obvious
     value rather than as plausible-looking noise. *)
  for k = 0 to s.payload_len - 1 do
    put8 buf (header_bytes + k) (k land 0xff)
  done;
  buf

let random_mac st = List.init 6 (fun _ -> Random.State.int st 256)

(** A random but entirely well-formed frame. [table] seeds the address pool so
    that roughly half the traffic hits a filter rule -- testing only misses
    would leave the match path unexercised. *)
let random_good st ~(table : Ref_model.entry list) =
  let use_table = table <> [] && Random.State.bool st in
  let dst_ip, dst_port =
    if use_table
    then (
      let e = List.nth table (Random.State.int st (List.length table)) in
      (e.dst_ip, e.dst_port))
    else Random.State.bits st land 0xffffffff, Random.State.int st 65536
  in
  build
    { default with
      dst_mac = random_mac st
    ; src_mac = random_mac st
    ; src_ip = Random.State.bits st land 0xffffffff
    ; dst_ip
    ; src_port = Random.State.int st 65536
    ; dst_port
    ; payload_len = Random.State.int st 64
    }

(** The adversarial set: one packet per rejection reason, plus the boundary
    cases where the header exactly fills or just fails to fill the accumulator. *)
let corpus ~(table : Ref_model.entry list) =
  let hit = match table with e :: _ -> e | [] -> Ref_model.{ dst_ip = 0; dst_port = 0; channel = 0 } in
  let base = { default with dst_ip = hit.dst_ip; dst_port = hit.dst_port } in
  [ "minimum-length frame (42B, no payload)", build { base with payload_len = 0 }
  ; "table hit, 18B payload", build base
  ; "table miss", build { base with dst_ip = 0xdeadbeef; dst_port = 9999 }
  ; "bad IPv4 checksum", build { base with corrupt_checksum = true }
  ; "not IPv4 (ARP ethertype)", build { base with ethertype = 0x0806 }
  ; "VLAN tagged", build { base with ethertype = Packet_defs.ethertype_vlan }
  ; "IPv4 options (IHL=6)", build { base with ver_ihl = 0x46 }
  ; "not UDP (TCP)", build { base with proto = 6 }
  ; "fragment (offset set)", build { base with flags_frag = 0x0025 }
  ; "fragment (MF flag)", build { base with flags_frag = 0x2000 }
  ; "IPv6 version nibble", build { base with ver_ihl = 0x65 }
  ; "large payload (1024B)", build { base with payload_len = 1024 }
  ; (* Runts: the header window never completes. 41 bytes is the interesting
       one -- one byte short of a decision. *)
    "runt: 41 bytes", Bytes.sub (build base) 0 41
  ; "runt: 20 bytes", Bytes.sub (build base) 0 20
  ; "runt: 1 byte", Bytes.sub (build base) 0 1
  ]
