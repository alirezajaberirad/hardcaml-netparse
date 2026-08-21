(lang dune 3.0)
(name netparse)
(generate_opam_files true)

(source
 (github alirezajaberirad/hardcaml-netparse))

(authors "Alireza Jaberi Rad")
(maintainers "Alireza Jaberi Rad")
(license MIT)

(package
 (name netparse)
 (synopsis "Line-rate Ethernet/IPv4/UDP packet parser and filter in Hardcaml")
 (description
  "A width-parameterized packet header parser and filter for FPGA ingress. One \
   Hardcaml source generates 32/64/128/256/512-bit datapath variants, each \
   verified against a pure-OCaml reference model and implemented in Vivado.")
 (depends
  (ocaml
   (>= 5.1))
  dune
  hardcaml
  ppx_hardcaml))
