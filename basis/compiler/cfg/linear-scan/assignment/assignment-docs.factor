USING: assocs compiler.cfg compiler.cfg.instructions
compiler.cfg.linear-scan.live-intervals compiler.cfg.linear-scan.allocation
compiler.cfg.linear-scan.allocation.state compiler.cfg.liveness
compiler.cfg.registers heaps help.markup help.syntax math sequences ;
IN: compiler.cfg.linear-scan.assignment

HELP: add-pending
{ $values { "live-interval" live-interval-state } }
{ $description "Adds a live interval to the pending interval set." } ;

HELP: assign-derived-roots
{ $values { "gc-map" gc-map } }
{ $description "Assigns pairs of spill slots for all derived roots in a gc map." } ;
{ assign-gc-roots assign-derived-roots } related-words

HELP: assign-gc-roots
{ $values { "gc-map" gc-map } }
{ $description "Assigns spill slots for all gc roots in a gc map." } ;

HELP: assign-registers-in-block
{ $values { "bb" basic-block } }
{ $description "Assigns registers to vregs and also inserts " { $link ##reload } " and " { $link ##spill } " instructions." } ;

HELP: assign-registers
{ $values { "cfg" cfg } { "live-intervals" sequence } }
{ $description "Uses the live intervals in the sequence to assign physical registers to all instructions in the cfg. The live intervals must first have had their physical registers assigned by " { $link allocate-registers } "." } ;

HELP: assign-all-registers
{ $values { "insn" insn } }
{ $description "Assigns physical registers for the virtual registers used and defined by the instruction." } ;

HELP: compute-live-in
{ $values { "bb" basic-block } }
{ $description "Computes the live in registers for a basic block." }
{ $see-also machine-live-ins } ;

HELP: expire-old-intervals
{ $values { "n" integer } { "pending-heap" min-heap } }
{ $description "Expires all intervals older than the cutoff point." } ;

HELP: insert-reload
{ $values { "live-interval" live-interval-state } }
{ $description "Inserts a " { $link ##reload } " instruction for a live interval." }
{ $see-also handle-reload insert-spill } ;

HELP: machine-edge-live-ins
{ $var-description "Mapping from basic blocks to predecessors to values which are live on a particular incoming edge." } ;

HELP: machine-live-ins
{ $var-description "Mapping from basic blocks to values which are live at the start on all incoming CFG edges. Each value is a sequence of 2-tuples where the first element is the vreg and the second the register or " { $link spill-slot } " which contains its value. It's like " { $link live-ins } " except the registers are physical instead of virtual." } ;

HELP: machine-live-outs
{ $var-description "Mapping from " { $link basic-block } " to an " { $link assoc } " of pairs which are the values that are live at the end. The keys of the pairs are virtual registers and the values are either real registers or spill slots." } ;

HELP: remove-pending
{ $values { "live-interval" live-interval-state } }
{ $description "Removes a pending live interval." } ;

HELP: unhandled-intervals
{ $var-description { $link min-heap } " of live intervals which still need a register allocation." } ;

HELP: vreg>reg
{ $values { "vreg" "virtual register" } { "reg/spill-slot" "a register or a spill slot" } }
{ $description "Translates a virtual register to a physical one. If the vreg is not in the pending set, then it must have been spilled and its spill slot is returned." }
{ $errors "Can throw a " { $link bad-vreg } " error if the vreg is not in the " { $link pending-interval-assoc } " and also doesn't have a spill slot registered." }
{ $see-also lookup-spill-slot pending-interval-assoc } ;

HELP: vregs>regs
{ $values { "assoc" "an " { $link assoc } " (set) of virtual registers" } { "assoc" assoc } }
{ $description "Creates a mapping of virtual registers to registers." } ;

HELP: vreg>spill-slot
{ $values { "vreg" integer } { "spill-slot" spill-slot } }
{ $description "Converts a vreg number to a spill slot." } ;

ARTICLE: "compiler.cfg.linear-scan.assignment" "Assigning registers to live intervals"
"The " { $vocab-link "compiler.cfg.linear-scan.assignment" } " assigns registers to live intervals." $nl
"Pending intervals:"
{ $subsections
  activate-interval
  add-pending
  pending-interval-assoc
  remove-pending
}
"Vreg transformations:"
{ $subsections vreg>reg vreg>spill-slot vregs>regs } ;

ABOUT: "compiler.cfg.linear-scan.assignment"
