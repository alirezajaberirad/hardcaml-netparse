(** Wire-format constants shared by the reference model and the RTL.

    Everything here is plain OCaml with no Hardcaml dependency, on purpose: the
    software model and the hardware must agree on the wire format by
    construction, not by two people reading the same RFC and hoping.

    {2 Byte-order convention}

    Offsets below are counted in bytes from the first byte on the wire (byte 0
    of the destination MAC). All multi-byte header fields are big-endian
    ("network byte order").

    AXI4-Stream, by contrast, carries the first byte on the wire in the
    {e least} significant lane, [tdata[7:0]]. The RTL therefore byte-reverses
    each beat on the way into the header accumulator so that packet byte 0 ends
    up at the {e top} of the accumulator. See {!Parser_core} and
    [doc/DESIGN.md]. This is stated once, here, and never re-derived. *)

(* ---- Ethernet II ---- *)

let off_eth_dst_mac = 0
let off_eth_src_mac = 6
let off_ethertype = 12
let eth_hdr_bytes = 14

(* ---- IPv4, starting at byte 14 ---- *)

let off_ip = 14
let off_ip_ver_ihl = 14
let off_ip_total_len = 16
let off_ip_flags_frag = 20
let off_ip_ttl = 22
let off_ip_proto = 23
let off_ip_checksum = 24
let off_ip_src = 26
let off_ip_dst = 30
let ipv4_hdr_bytes = 20

(* ---- UDP, starting at byte 34 ---- *)

let off_udp = 34
let off_udp_src_port = 34
let off_udp_dst_port = 36
let off_udp_len = 38
let off_udp_checksum = 40
let udp_hdr_bytes = 8

(** Total header window the parser must collect before it can decide anything:
    Ethernet (14) + IPv4 without options (20) + UDP (8). *)
let header_bytes = eth_hdr_bytes + ipv4_hdr_bytes + udp_hdr_bytes

let () = assert (header_bytes = 42)

(* ---- Field values ---- *)

let ethertype_ipv4 = 0x0800
let ethertype_vlan = 0x8100
let ip_version_4 = 4
let ip_ihl_no_options = 5
let ip_proto_udp = 17

(* ---- Derived geometry, as a function of datapath width ---- *)

(** Number of beats needed to cover the header window at [w] bytes per beat. *)
let n_beats ~w = (header_bytes + w - 1) / w

(** Size of the header accumulator. Rounded up to a whole number of beats, so
    the accumulator holds [n_beats * w] bytes of which the top {!header_bytes}
    are the ones we slice. *)
let acc_bytes ~w = n_beats ~w * w

let acc_bits ~w = acc_bytes ~w * 8

(** Minimum number of valid bytes required on the final header beat for the
    header to be complete. Below this the packet is a runt. *)
let min_bytes_last_beat ~w = header_bytes - ((n_beats ~w - 1) * w)

(** Bit range [(high, low)] of packet byte [off] (length [len] bytes) within the
    header accumulator. Because the accumulator is filled MSB-first, this range
    is independent of the datapath width -- that is the whole trick. *)
let acc_field_range ~w ~off ~len =
  let bits = acc_bits ~w in
  let high = bits - (off * 8) - 1 in
  let low = bits - ((off + len) * 8) in
  (high, low)
