(* The unprocessed transition cache is a cache of transitions which have been
 * ingested from the network but have not yet been processed into the transition
 * frontier. This is used in order to drop duplicate transitions which are still
 * being handled by various threads in the transition frontier controller. *)

open Core_kernel
open Coda_base

module Name = struct
  let t = __MODULE__
end

module Transmuter = struct
  module Make (Inputs : Inputs.S) :
    Cache_lib.Intf.Transmuter.S
    with type Source.t =
                Inputs.External_transition.with_initial_validation
                Envelope.Incoming.t
     and type Target.t = State_hash.t = struct
    open Inputs

    module Source = struct
      type t = External_transition.with_initial_validation Envelope.Incoming.t
    end

    module Target = State_hash

    let transmute enveloped_transition =
      let {With_hash.hash; data= _}, _ =
        Envelope.Incoming.data enveloped_transition
      in
      hash
  end
end

module Make (Inputs : Inputs.S) :
  Cache_lib.Intf.Transmuter_cache.S
  with module Cached := Cache_lib.Cached
   and module Cache := Cache_lib.Cache
   and type source =
              Inputs.External_transition.with_initial_validation
              Envelope.Incoming.t
   and type target = State_hash.t =
  Cache_lib.Transmuter_cache.Make (Transmuter.Make (Inputs)) (Name)
