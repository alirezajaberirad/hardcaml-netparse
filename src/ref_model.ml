(** Pure-OCaml reference parser.

    This is the "obvious" implementation: index into a byte buffer, pull out the
    fields, apply the rules. No hardware concepts anywhere. It exists to be
    read and trusted, and then to be compared against the RTL on every packet
    the test bench generates.

    Keeping the reference model in the same language as the hardware -- rather
    than in a separate Python/SystemVerilog testbench -- means the two share
    {!Packet_defs} literally, so an offset can never drift between them. *)

type entry =
  { dst_ip : int (** 32-bit, host order *)
  ; dst_port : int (** 16-bit *)
  ; channel : int
  }

type verdict =
  { short : bool (** packet ended before the 42-byte header completed *)
  ; vlan : bool (** 802.1Q tagged: out of scope, rejected *)
  ; not_ipv4 : bool (** ethertype was neither IPv4 nor VLAN *)
  ; bad_ihl : bool (** version <> 4, or IPv4 options present (IHL > 5) *)
  ; not_udp : bool (** IP protocol was not 17 *)
  ; fragment : bool (** MF set or non-zero fragment offset *)
  ; bad_checksum : bool (** IPv4 header checksum did not verify *)
  ; dst_ip : int
  ; dst_port : int
  ; hit : bool (** matched an entry in the filter table *)
  ; channel : int
  ; pass : bool (** every check clean and a table hit *)
  }

let no_verdict =
  { short = true
  ; vlan = false
  ; not_ipv4 = false
  ; bad_ihl = false
  ; not_udp = false
  ; fragment = false
  ; bad_checksum = false
  ; dst_ip = 0
  ; dst_port = 0
  ; hit = false
  ; channel = 0
  ; pass = false
  }

(* ---- big-endian field readers ---- *)

let be8 buf off = Char.code (Bytes.get buf off)
let be16 buf off = (be8 buf off lsl 8) lor be8 buf (off + 1)

let be32 buf off =
  (be16 buf off lsl 16) lor be16 buf (off + 2)

(** One's-complement sum over [len] bytes at [off], with carries folded back in.
    Verifying a header means summing it {e including} its checksum field: a
    correct header yields [0xffff]. See doc/DESIGN.md section 4. *)
let ones_complement_sum buf ~off ~len =
  let rec go i acc = if i >= len then acc else go (i + 2) (acc + be16 buf (off + i)) in
  let sum = go 0 0 in
  (* Fold twice: ten 16-bit words need 20 bits, so one fold can itself carry. *)
  let sum = (sum land 0xffff) + (sum lsr 16) in
  (sum land 0xffff) + (sum lsr 16)

(** Compute the value that belongs in the checksum field of an IPv4 header whose
    checksum field is currently zero. Used by the packet generator to build
    well-formed packets. *)
let ipv4_checksum_for buf ~off =
  lnot (ones_complement_sum buf ~off ~len:Packet_defs.ipv4_hdr_bytes) land 0xffff

(* [entry] and [verdict] share dst_ip/dst_port/channel field names, and OCaml
   resolves a bare field access to the last-defined record type -- so these
   annotations are load-bearing, not decoration. *)
let lookup (table : entry list) ~dst_ip ~dst_port =
  let rec go : entry list -> entry option = function
    | [] -> None
    | e :: rest -> if e.dst_ip = dst_ip && e.dst_port = dst_port then Some e else go rest
  in
  go table

let parse ~(table : entry list) (packet : Bytes.t) : verdict =
  let open Packet_defs in
  if Bytes.length packet < header_bytes
  then no_verdict
  else begin
    let ethertype = be16 packet off_ethertype in
    let vlan = ethertype = ethertype_vlan in
    let not_ipv4 = (not vlan) && ethertype <> ethertype_ipv4 in
    let ver_ihl = be8 packet off_ip_ver_ihl in
    let version = ver_ihl lsr 4 in
    let ihl = ver_ihl land 0xf in
    let bad_ihl = version <> ip_version_4 || ihl <> ip_ihl_no_options in
    let proto = be8 packet off_ip_proto in
    let not_udp = proto <> ip_proto_udp in
    (* Fragment iff the More-Fragments flag is set or the offset is non-zero;
       both live in the same 16-bit word, so one mask covers it. *)
    let fragment = be16 packet off_ip_flags_frag land 0x3fff <> 0 in
    let bad_checksum =
      ones_complement_sum packet ~off:off_ip ~len:ipv4_hdr_bytes <> 0xffff
    in
    let dst_ip = be32 packet off_ip_dst in
    let dst_port = be16 packet off_udp_dst_port in
    let matched =
      (* A packet only reaches the filter if it is a well-formed IPv4/UDP frame;
         matching on fields of a malformed header would be meaningless. *)
      if vlan || not_ipv4 || bad_ihl || not_udp || fragment || bad_checksum
      then None
      else lookup table ~dst_ip ~dst_port
    in
    { short = false
    ; vlan
    ; not_ipv4
    ; bad_ihl
    ; not_udp
    ; fragment
    ; bad_checksum
    ; dst_ip
    ; dst_port
    ; hit = Option.is_some matched
    ; channel = (match matched with Some e -> e.channel | None -> 0)
    ; pass = Option.is_some matched
    }
  end

let to_string v =
  Printf.sprintf
    "pass=%b hit=%b ch=%d dst_ip=%08x dst_port=%d [%s%s%s%s%s%s%s]"
    v.pass
    v.hit
    v.channel
    v.dst_ip
    v.dst_port
    (if v.short then "short " else "")
    (if v.vlan then "vlan " else "")
    (if v.not_ipv4 then "not_ipv4 " else "")
    (if v.bad_ihl then "bad_ihl " else "")
    (if v.not_udp then "not_udp " else "")
    (if v.fragment then "frag " else "")
    (if v.bad_checksum then "bad_csum " else "")
