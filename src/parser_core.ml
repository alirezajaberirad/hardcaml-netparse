(** Line-rate Ethernet / IPv4 / UDP header parser and filter.

    The datapath width is a functor parameter, so one source generates the
    32/64/128/256/512-bit variants. See doc/DESIGN.md for the architecture; the
    short version is:

    - shift each arriving beat into a wide header accumulator, MSB first, so
      that packet byte [k] always lands at a fixed bit offset regardless of the
      datapath width. This is what makes the design parameterizable: no
      per-width byte muxing, no straddling cases.
    - once the whole 42-byte window has landed, slice every field out of the
      accumulator at once and run the checks in a two-stage pipeline. *)

open Hardcaml
open Signal

module type Config = sig
  (** Datapath width in bytes. 4, 8, 16, 32 and 64 are exercised by the test
      suite; anything >= 1 elaborates. *)
  val datapath_bytes : int

  (** Filter rules, applied in list order (first match wins). These are ordinary
      OCaml values that become constant comparators in the netlist. *)
  val table : Ref_model.entry list
end

module Make (Cfg : Config) = struct
  let w = Cfg.datapath_bytes
  let data_bits = w * 8
  let n_beats = Packet_defs.n_beats ~w
  let acc_bits = Packet_defs.acc_bits ~w
  let min_bytes_last = Packet_defs.min_bytes_last_beat ~w
  let table = Cfg.table

  let channel_bits =
    let max_channel =
      List.fold_left (fun a (e : Ref_model.entry) -> max a e.channel) 0 table
    in
    max 1 (Signal.num_bits_to_represent max_channel)

  let count_bits = max 1 (Signal.num_bits_to_represent (n_beats - 1))
  let keep_bits = max 1 (Signal.num_bits_to_represent w)

  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; tvalid : 'a
      ; tdata : 'a [@bits data_bits]
      ; tkeep : 'a [@bits w]
      ; tlast : 'a
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { valid : 'a (** one-cycle pulse: a packet verdict is on the bus *)
      ; pass : 'a
      ; channel : 'a [@bits channel_bits]
      ; dst_ip : 'a [@bits 32]
      ; dst_port : 'a [@bits 16]
      ; err_short : 'a
      ; err_vlan : 'a
      ; err_not_ipv4 : 'a
      ; err_bad_ihl : 'a
      ; err_not_udp : 'a
      ; err_fragment : 'a
      ; err_bad_checksum : 'a
      }
    [@@deriving hardcaml]
  end

  (* ---- small helpers ---- *)

  (** Reverse the byte lanes of a beat.

      AXI4-Stream puts the first byte on the wire in [tdata[7:0]]; the
      accumulator wants it at the top. Doing the swap once here is what lets
      every field offset in {!Packet_defs} be a plain constant. *)
  let byteswap s =
    let n = width s / 8 in
    concat_msb (List.init n (fun k -> select s ((k * 8) + 7) (k * 8)))

  let popcount s =
    let ow = max 1 (Signal.num_bits_to_represent (width s)) in
    List.fold_left (fun a b -> a +: uresize b ow) (zero ow) (bits_lsb s)

  let reduce_or = function [] -> gnd | x :: xs -> List.fold_left ( |: ) x xs

  (** Balanced adder tree.

      [List.fold_left ( +: )] over ten words builds a *linear* chain ten adders
      deep. Pairing and halving instead gives depth ceil(log2 10) = 4. On a
      carry-chain FPGA that is the whole difference: the first version made the
      checksum the critical path at every datapath width, which showed up as a
      near-identical Fmax for 32- and 64-bit variants that otherwise share no
      logic. *)
  let rec sum_tree = function
    | [] -> zero 20
    | [ x ] -> x
    | xs ->
      let rec pair = function
        | a :: b :: rest -> (a +: b) :: pair rest
        | rest -> rest
      in
      sum_tree (pair xs)

  (** Slice packet byte range [off, off+len) out of the header accumulator. *)
  let field acc ~off ~len =
    let high, low = Packet_defs.acc_field_range ~w ~off ~len in
    select acc high low

  let create (i : Signal.t I.t) : Signal.t O.t =
    let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
    let reg ?(enable = vdd) d = Signal.reg spec ~enable d in

    (* ---------------------------------------------------------------- *)
    (* Framing: where are we inside the current packet?                  *)
    (* ---------------------------------------------------------------- *)

    (* [hdr_done] latches once this packet's header window has been captured,
       so the accumulator stops shifting and the payload cannot push the header
       back out. It also stops [header_complete] re-firing on every subsequent
       beat when n_beats = 1, where the beat counter is permanently 0. *)
    let hdr_done = wire 1 in
    let header_complete = wire 1 in

    let beat_count =
      reg_fb spec ~enable:i.tvalid ~width:count_bits ~f:(fun c ->
        mux2
          i.tlast
          (zero count_bits)
          (mux2 (c ==: of_int ~width:count_bits (n_beats - 1)) c (c +:. 1)))
    in

    (* On the final header beat a short packet may end early, in which case
       tkeep says how many of this beat's bytes are real. Non-final beats carry
       a full set of lanes by AXI-Stream convention. *)
    let last_beat_has_enough =
      ~:(i.tlast) |: (popcount i.tkeep >=: of_int ~width:keep_bits min_bytes_last)
    in
    let at_last_header_beat = beat_count ==: of_int ~width:count_bits (n_beats - 1) in

    header_complete
    <== (i.tvalid &: ~:hdr_done &: at_last_header_beat &: last_beat_has_enough);

    (* Packet ended before the 42-byte window completed: a runt. *)
    let short_packet = i.tvalid &: i.tlast &: ~:hdr_done &: ~:header_complete in

    hdr_done
    <== reg_fb spec ~enable:vdd ~width:1 ~f:(fun d ->
          mux2 (i.tvalid &: i.tlast) gnd (mux2 header_complete vdd d));

    (* ---------------------------------------------------------------- *)
    (* Header accumulator                                                *)
    (* ---------------------------------------------------------------- *)

    let acc =
      reg_fb spec ~enable:(i.tvalid &: ~:hdr_done) ~width:acc_bits ~f:(fun a ->
        (* Shift left by one beat and drop in the byte-swapped lanes. Sized so
           that after n_beats shifts, packet byte 0 sits at the MSB. *)
        select (a @: byteswap i.tdata) (acc_bits - 1) 0)
    in
    ignore (acc -- "hdr_acc" : Signal.t);

    (* ---------------------------------------------------------------- *)
    (* Stage 1: slice the header, start the checksum                     *)
    (* ---------------------------------------------------------------- *)

    (* [acc] is a register, so the final header beat is not visible on its
       output until the cycle *after* [header_complete]. Sampling the fields on
       [header_complete] itself reads the accumulator one beat stale -- which at
       W = 4 means dst_ip lands on the source address. Hence [hdr_captured]:
       everything downstream is enabled one cycle later, and this is why the
       pipeline is three stages deep rather than two. *)
    let hdr_captured = reg header_complete in
    let short_captured = reg short_packet in
    let s1_en = hdr_captured |: short_captured in
    let s1_valid = reg s1_en in
    let s1_short = reg short_captured in

    (* acc is stable during this cycle: accumulation was disabled by hdr_done. *)
    let ethertype = field acc ~off:Packet_defs.off_ethertype ~len:2 in
    let ver_ihl = field acc ~off:Packet_defs.off_ip_ver_ihl ~len:1 in
    let proto = field acc ~off:Packet_defs.off_ip_proto ~len:1 in
    let flags_frag = field acc ~off:Packet_defs.off_ip_flags_frag ~len:2 in

    let is_vlan = ethertype ==: of_int ~width:16 Packet_defs.ethertype_vlan in
    let is_ipv4 = ethertype ==: of_int ~width:16 Packet_defs.ethertype_ipv4 in

    let s1_vlan = reg ~enable:s1_en is_vlan in
    let s1_not_ipv4 = reg ~enable:s1_en (~:is_vlan &: ~:is_ipv4) in
    let s1_bad_ihl =
      reg
        ~enable:s1_en
        (ver_ihl
         <>: of_int
               ~width:8
               ((Packet_defs.ip_version_4 lsl 4) lor Packet_defs.ip_ihl_no_options))
    in
    let s1_not_udp =
      reg ~enable:s1_en (proto <>: of_int ~width:8 Packet_defs.ip_proto_udp)
    in
    (* More-Fragments flag and the fragment offset share one word, so a single
       mask covers "this is part of a fragmented datagram". *)
    let s1_fragment =
      reg ~enable:s1_en ((flags_frag &: of_int ~width:16 0x3fff) <>: zero 16)
    in
    let s1_dst_ip = reg ~enable:s1_en (field acc ~off:Packet_defs.off_ip_dst ~len:4) in
    let s1_dst_port =
      reg ~enable:s1_en (field acc ~off:Packet_defs.off_udp_dst_port ~len:2)
    in

    (* Ten 16-bit words summed flat. Worst case 10 * 0xffff = 0x9fff6, so 20
       bits carries the sum with nothing lost; the folds happen in stage 2 to
       keep this stage's adder tree off the critical path. *)
    let ip_words =
      List.init (Packet_defs.ipv4_hdr_bytes / 2) (fun k ->
        field acc ~off:(Packet_defs.off_ip + (2 * k)) ~len:2)
    in
    let s1_csum_sum =
      reg ~enable:s1_en (sum_tree (List.map (fun x -> uresize x 20) ip_words))
    in

    (* ---------------------------------------------------------------- *)
    (* Stage 2: fold the checksum, match the table, emit the verdict     *)
    (* ---------------------------------------------------------------- *)

    let fold1 = uresize (select s1_csum_sum 15 0) 17 +: uresize (select s1_csum_sum 19 16) 17 in
    let fold2 = uresize (select fold1 15 0) 16 +: uresize (select fold1 16 16) 16 in
    let checksum_ok = fold2 ==: ones 16 in

    let malformed =
      s1_short
      |: s1_vlan
      |: s1_not_ipv4
      |: s1_bad_ihl
      |: s1_not_udp
      |: s1_fragment
      |: ~:checksum_ok
    in

    (* Fully associative compare: every rule is checked in the same cycle, so
       classification takes fixed time no matter how the table is populated. *)
    let matches =
      List.map
        (fun (e : Ref_model.entry) ->
           (s1_dst_ip ==: of_int ~width:32 e.dst_ip)
           &: (s1_dst_port ==: of_int ~width:16 e.dst_port))
        table
    in
    let hit = reduce_or matches &: ~:malformed in
    (* Fold right so that earlier table entries win, matching the reference
       model's first-match-wins lookup. *)
    let channel =
      List.fold_right
        (fun ((e : Ref_model.entry), m) acc ->
           mux2 m (of_int ~width:channel_bits e.channel) acc)
        (List.combine table matches)
        (zero channel_bits)
    in

    { O.valid = reg s1_valid
    ; pass = reg (hit &: ~:malformed)
    ; channel = reg channel
    ; dst_ip = reg s1_dst_ip
    ; dst_port = reg s1_dst_port
    ; err_short = reg s1_short
    ; err_vlan = reg (s1_vlan &: ~:s1_short)
    ; err_not_ipv4 = reg (s1_not_ipv4 &: ~:s1_short)
    ; err_bad_ihl = reg (s1_bad_ihl &: ~:s1_short)
    ; err_not_udp = reg (s1_not_udp &: ~:s1_short)
    ; err_fragment = reg (s1_fragment &: ~:s1_short)
    ; err_bad_checksum = reg (~:checksum_ok &: ~:s1_short)
    }
  ;;

  (** Total latency from the last header beat to [valid], in cycles. *)
  let latency = 3
end
