open Protocols.Coda_transition_frontier
open Coda_base
module Inputs = Inputs
module Processor = Processor
module Catchup_scheduler = Catchup_scheduler
module Validator = Validator

module Make (Inputs : Inputs.S) :
  Transition_handler_intf
  with type time := Inputs.Time.t
   and type time_controller := Inputs.Time.Controller.t
   and type verifier := Inputs.Verifier.t
   and type external_transition_with_initial_validation :=
              Inputs.External_transition.with_initial_validation
   and type external_transition_validated :=
              Inputs.External_transition.Validated.t
   and type staged_ledger := Inputs.Staged_ledger.t
   and type state_hash := State_hash.t
   and type trust_system := Trust_system.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t = struct
  module Unprocessed_transition_cache =
    Unprocessed_transition_cache.Make (Inputs)

  module Full_inputs = struct
    include Inputs
    module Unprocessed_transition_cache = Unprocessed_transition_cache
  end

  module Breadcrumb_builder = Breadcrumb_builder.Make (Full_inputs)
  module Processor = Processor.Make (Full_inputs)
  module Validator = Validator.Make (Full_inputs)
end
