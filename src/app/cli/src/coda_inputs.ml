[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Coda_state
open Coda_transition
open Signature_lib
open Blockchain_snark
open Coda_numbers
open Pipe_lib
open O1trace
module Fee = Protocols.Coda_pow.Fee

module Staged_ledger_aux_hash = struct
  include Staged_ledger_hash.Aux_hash.Stable.Latest

  let of_bytes = Staged_ledger_hash.Aux_hash.of_bytes

  let to_bytes = Staged_ledger_hash.Aux_hash.to_bytes
end

module Staged_ledger_hash = struct
  include Staged_ledger_hash

  let ledger_hash = Staged_ledger_hash.ledger_hash

  let aux_hash = Staged_ledger_hash.aux_hash

  let pending_coinbase_hash = Staged_ledger_hash.pending_coinbase_hash

  let of_aux_ledger_and_coinbase_hash =
    Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
end

module Ledger_hash = struct
  include Ledger_hash

  let of_digest, merge, to_bytes = Ledger_hash.(of_digest, merge, to_bytes)
end

module Frozen_ledger_hash = struct
  include Frozen_ledger_hash

  let to_bytes = Frozen_ledger_hash.to_bytes

  let of_ledger_hash = Frozen_ledger_hash.of_ledger_hash
end

module type Work_selector_F = functor
  (Inputs : Work_selector.Inputs.Inputs_intf)
  -> Protocols.Coda_pow.Work_selector_intf
     with type staged_ledger := Inputs.Staged_ledger.t
      and type work :=
                 ( Inputs.Ledger_proof_statement.t
                 , Inputs.Transaction.t
                 , Inputs.Transaction_witness.t
                 , Inputs.Ledger_proof.t )
                 Snark_work_lib.Work.Single.Spec.t
      and type snark_pool := Inputs.Snark_pool.t
      and type fee := Inputs.Fee.t

module type Config_intf = sig
  val logger : Logger.t

  val conf_dir : string

  val lbc_tree_max_depth : [`Infinity | `Finite of int]

  val propose_keypair : Keypair.t option

  val genesis_proof : Snark_params.Tock.Proof.t

  val commit_id : Daemon_rpcs.Types.Git_sha.t option

  val work_selection : Protocols.Coda_pow.Work_selection.t
end

module type Init_intf = sig
  include Config_intf

  module Make_work_selector : Work_selector_F

  val proposer_prover : [`Proposer of Prover.t | `Non_proposer]

  val verifier : Verifier.t

  val genesis_proof : Proof.t
end

module type Main_intf = sig
  module Inputs : sig
    module Time : Protocols.Coda_pow.Time_intf

    module Verifier : sig
      type t
    end

    module Ledger : sig
      type t [@@deriving sexp]

      val copy : t -> t

      val location_of_key :
        t -> Public_key.Compressed.t -> Ledger.Location.t option

      val get : t -> Ledger.Location.t -> Account.t option

      val merkle_path :
           t
        -> Ledger.Location.t
        -> [`Left of Ledger_hash.t | `Right of Ledger_hash.t] list

      val num_accounts : t -> int

      val depth : int

      val merkle_root : t -> Ledger_hash.t

      val to_list : t -> Account.t list

      val fold_until :
           t
        -> init:'accum
        -> f:('accum -> Account.t -> ('accum, 'stop) Base.Continue_or_stop.t)
        -> finish:('accum -> 'stop)
        -> 'stop
    end

    module Net : sig
      type t

      module Peer : sig
        type t =
          { host: Unix.Inet_addr.Blocking_sexp.t
          ; discovery_port: int (* UDP *)
          ; communication_port: int (* TCP *) }
        [@@deriving sexp, compare, hash]
      end

      module Gossip_net : sig
        module Config : Gossip_net.Config_intf
      end

      module Config :
        Coda_networking.Config_intf
        with type gossip_config := Gossip_net.Config.t
         and type time_controller := Time.Controller.t
    end

    module Sparse_ledger : sig
      type t
    end

    module Transaction_witness : sig
      type t
    end

    module Transaction : sig
      type t
    end

    module Snark_pool : sig
      type t

      val add_completed_work :
        t -> Snark_worker.Work.Result.t -> unit Deferred.t
    end

    module Transaction_pool : sig
      type t

      val add : t -> User_command.t -> unit Deferred.t
    end

    module Protocol_state_proof : sig
      type t

      val dummy : t
    end

    module Staged_ledger :
      Protocols.Coda_pow.Staged_ledger_intf
      with type diff := Staged_ledger_diff.t
       and type valid_diff :=
                  Staged_ledger_diff.With_valid_signatures_and_proofs.t
       and type staged_ledger_hash := Staged_ledger_hash.t
       and type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
       and type ledger_hash := Ledger_hash.t
       and type frozen_ledger_hash := Frozen_ledger_hash.t
       and type public_key := Public_key.Compressed.t
       and type ledger := Ledger.t
       and type ledger_proof := Ledger_proof.t
       and type user_command_with_valid_signature :=
                  User_command.With_valid_signature.t
       and type statement := Transaction_snark_work.Statement.t
       and type completed_work_checked := Transaction_snark_work.Checked.t
       and type sparse_ledger := Sparse_ledger.t
       and type ledger_proof_statement := Transaction_snark.Statement.t
       and type ledger_proof_statement_set := Transaction_snark.Statement.Set.t
       and type transaction := Transaction.t
       and type user_command := User_command.t
       and type transaction_witness := Transaction_witness.t
       and type pending_coinbase_collection := Pending_coinbase.t
       and type verifier := Verifier.t

    module Transition_frontier :
      Protocols.Coda_pow.Transition_frontier_intf
      with type state_hash := State_hash.t
       and type external_transition_validated :=
                  External_transition.Validated.t
       and type mostly_validated_external_transition :=
                  ( [`Time_received] * Truth.true_t
                  , [`Proof] * Truth.true_t
                  , [`Frontier_dependencies] * Truth.true_t
                  , [`Staged_ledger_diff] * Truth.false_t )
                  External_transition.Validation.with_transition
       and type ledger_database := Coda_base.Ledger.Db.t
       and type masked_ledger := Coda_base.Ledger.t
       and type staged_ledger := Staged_ledger.t
       and type staged_ledger_diff := Staged_ledger_diff.t
       and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
       and type consensus_local_state := Consensus.Data.Local_state.t
       and type user_command := User_command.t
       and type verifier := Verifier.t
       and type pending_coinbase := Pending_coinbase.t
       and type consensus_state := Consensus.Data.Consensus_state.Value.t
       and type Extensions.Work.t = Transaction_snark_work.Statement.t
  end

  module Config : sig
    (** If ledger_db_location is None, will auto-generate a db based on a UUID *)
    type t =
      { logger: Logger.t
      ; trust_system: Trust_system.t
      ; verifier: Verifier.t
      ; propose_keypair: Keypair.t option
      ; snark_worker_key: Public_key.Compressed.Stable.V1.t option
      ; net_config: Inputs.Net.Config.t
      ; transaction_pool_disk_location: string
      ; snark_pool_disk_location: string
      ; wallets_disk_location: string
      ; ledger_db_location: string option
      ; transition_frontier_location: string option
      ; staged_ledger_transition_backup_capacity: int [@default 10]
      ; time_controller: Inputs.Time.Controller.t
      ; receipt_chain_database: Receipt_chain_database.t
      ; transaction_database: Transaction_database.t
      ; snark_work_fee: Currency.Fee.t
      ; monitor: Async.Monitor.t option
      ; consensus_local_state: Consensus.Data.Local_state.t }
    [@@deriving make]
  end

  type t

  val propose_keypair : t -> Keypair.t option

  val snark_worker_key : t -> Public_key.Compressed.Stable.V1.t option

  val snark_work_fee : t -> Currency.Fee.t

  val request_work : t -> Snark_worker.Work.Spec.t option

  val best_staged_ledger : t -> Inputs.Staged_ledger.t Participating_state.t

  val best_ledger : t -> Inputs.Ledger.t Participating_state.t

  val root_length : t -> int Participating_state.t

  val best_protocol_state : t -> Protocol_state.Value.t Participating_state.t

  val best_tip :
    t -> Inputs.Transition_frontier.Breadcrumb.t Participating_state.t

  val sync_status :
    t -> [`Offline | `Synced | `Bootstrap] Coda_incremental.Status.Observer.t

  val visualize_frontier : filename:string -> t -> unit Participating_state.t

  val peers : t -> Network_peer.Peer.t list

  val initial_peers : t -> Host_and_port.t list

  val validated_transitions :
       t
    -> (External_transition.Validated.t, State_hash.t) With_hash.t
       Strict_pipe.Reader.t

  val root_diff :
       t
    -> User_command.t Protocols.Coda_transition_frontier.Root_diff_view.t
       Strict_pipe.Reader.t

  val transaction_pool : t -> Inputs.Transaction_pool.t

  val transaction_database : t -> Transaction_database.t

  val snark_pool : t -> Inputs.Snark_pool.t

  val create : Config.t -> t Deferred.t

  val staged_ledger_ledger_proof : t -> Ledger_proof.t option

  val transition_frontier :
    t -> Inputs.Transition_frontier.t option Broadcast_pipe.Reader.t

  val get_ledger :
    t -> Staged_ledger_hash.t -> Account.t list Deferred.Or_error.t

  val receipt_chain_database : t -> Receipt_chain_database.t

  val wallets : t -> Secrets.Wallets.t

  val top_level_logger : t -> Logger.t
end

module Pending_coinbase = struct
  module V1 = struct
    include Pending_coinbase.Stable.V1

    [%%define_locally
    Pending_coinbase.
      ( hash_extra
      , oldest_stack
      , latest_stack
      , create
      , remove_coinbase_stack
      , update_coinbase_stack
      , merkle_root )]

    module Stack = Pending_coinbase.Stack
    module Coinbase_data = Pending_coinbase.Coinbase_data
    module Hash = Pending_coinbase.Hash
  end
end

let make_init ~should_propose (module Config : Config_intf) :
    (module Init_intf) Deferred.t =
  let open Config in
  let%bind proposer_prover =
    if should_propose then
      let%map prover = Prover.create () in
      `Proposer prover
    else return `Non_proposer
  in
  let%map verifier = Verifier.create () in
  let (module Make_work_selector : Work_selector_F) =
    match work_selection with
    | Seq ->
        (module Work_selector.Sequence.Make : Work_selector_F)
    | Random ->
        (module Work_selector.Random.Make : Work_selector_F)
  in
  let module Init = struct
    module Make_work_selector = Make_work_selector
    include Config

    let proposer_prover = proposer_prover

    let verifier = verifier
  end in
  (module Init : Init_intf)

module Make_inputs0 (Init : Init_intf) = struct
  open Protocols.Coda_pow
  open Init

  let max_length = Consensus.Constants.k

  module Protocol_state = Protocol_state

  module Protocol_state_hash = struct
    include State_hash.Stable.Latest

    type var = State_hash.var
  end

  module Time :
    Time_intf
    with type t = Block_time.t
     and type Unpacked.var = Block_time.Unpacked.var
     and type Controller.t = Block_time.Controller.t =
    Block_time

  module Time_close_validator = struct
    let limit = Block_time.Span.of_time_span (Core.Time.Span.of_sec 15.)

    let validate t =
      let now = Block_time.now Block_time.Controller.basic in
      (* t should be at most [limit] greater than now *)
      Block_time.Span.( < ) (Block_time.diff t now) limit
  end

  module Masked_ledger = Ledger.Mask.Attached
  module Sok_message = Sok_message

  module Amount = struct
    module Signed = struct
      include Currency.Amount.Signed

      include (
        Currency.Amount.Signed.Stable.Latest :
          module type of Currency.Amount.Signed.Stable.Latest with type t := t )
    end
  end

  module Protocol_state_proof = struct
    include Proof.Stable.V1

    type input = Protocol_state.Value.t

    let dummy = Coda_base.Proof.dummy

    let verify state_proof state =
      match%map
        Verifier.verify_blockchain_snark Init.verifier
          {proof= state_proof; state}
      with
      | Ok b ->
          b
      | Error e ->
          Logger.error Init.logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:[("error", `String (Error.to_string_hum e))]
            "Could not connect to verifier: $error" ;
          false
  end

  module Coinbase = Coda_base.Coinbase
  module Fee_transfer = Fee_transfer
  module Account = Account

  module Transaction = struct
    include Coda_base.Transaction.Stable.V1

    let fee_excess, supply_increase =
      Coda_base.Transaction.(fee_excess, supply_increase)
  end

  module Ledger = Ledger
  module Ledger_db = Ledger.Db
  module Ledger_transfer = Ledger_transfer.Make (Ledger) (Ledger_db)
  module Proof = Coda_base.Proof.Stable.V1
  module Ledger_proof = Ledger_proof
  module Sparse_ledger = Coda_base.Sparse_ledger

  module Transaction_snark_work_proof = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = Ledger_proof.Stable.V1.t list
          [@@deriving sexp, bin_io, yojson, version]
        end

        include T
      end
    end
  end

  module Pending_coinbase_hash = Pending_coinbase.V1.Hash
  module Pending_coinbase = Pending_coinbase.V1
  module Pending_coinbase_stack_state =
    Transaction_snark.Pending_coinbase_stack_state
  module Transaction_witness = Coda_base.Transaction_witness

  module Staged_ledger = struct
    module Inputs = struct
      module Sok_message = Sok_message
      module Account = Account
      module Proof = Proof
      module Sparse_ledger = Sparse_ledger
      module Amount = Amount
      module Transaction_snark_work = Transaction_snark_work
      module Compressed_public_key = Public_key.Compressed
      module User_command = User_command
      module Fee_transfer = Fee_transfer
      module Coinbase = Coinbase
      module Transaction = Transaction
      module Ledger = Ledger
      module Ledger_proof = Ledger_proof
      module Ledger_proof_verifier = Verifier
      module Ledger_proof_statement = Transaction_snark.Statement
      module Ledger_hash = Ledger_hash
      module Frozen_ledger_hash = Frozen_ledger_hash
      module Staged_ledger_diff = Staged_ledger_diff
      module Staged_ledger_hash = Staged_ledger_hash
      module Staged_ledger_aux_hash = Staged_ledger_aux_hash
      module Transaction_validator = Transaction_validator
      module Config = Init
      module Pending_coinbase_hash = Pending_coinbase_hash
      module Pending_coinbase = Pending_coinbase
      module Pending_coinbase_stack_state =
        Transaction_snark.Pending_coinbase_stack_state
      module Transaction_witness = Transaction_witness

      let check (Transaction_snark_work.{fee; prover; proofs} as t) stmts =
        let message = Sok_message.create ~fee ~prover in
        match List.zip proofs stmts with
        | Unequal_lengths ->
            return None
        | Ok ps ->
            let%map good =
              Deferred.List.for_all ps
                ~f:(fun ((proof, stmt) :
                          Ledger_proof.t * Ledger_proof_statement.t)
                   ->
                  let statement_eq a b =
                    Int.(Ledger_proof_statement.compare a b = 0)
                  in
                  if not (statement_eq (Ledger_proof.statement proof) stmt)
                  then return false
                  else
                    let%map or_error =
                      Verifier.verify_transaction_snark Init.verifier proof
                        ~message
                    in
                    match or_error with
                    | Ok b ->
                        b
                    | Error err ->
                        Logger.error logger ~module_:__MODULE__
                          ~location:__LOC__ "verifier threw an error: %s"
                          (Error.to_string_hum err) ;
                        false )
            in
            Option.some_if good
              (Transaction_snark_work.Checked.create_unsafe t)
    end

    include Staged_ledger.Make (Inputs)
  end

  module Staged_ledger_aux = Staged_ledger.Scan_state

  module Staged_ledger_transition = struct
    type t = {old: Staged_ledger.t sexp_opaque; diff: Staged_ledger_diff.t}
    [@@deriving sexp]

    module With_valid_signatures_and_proofs = struct
      type t =
        { old: Staged_ledger.t sexp_opaque
        ; diff: Staged_ledger_diff.With_valid_signatures_and_proofs.t }
      [@@deriving sexp]
    end

    let forget {With_valid_signatures_and_proofs.old; diff} =
      {old; diff= Staged_ledger_diff.forget diff}
  end

  module Transition_frontier_inputs = struct
    module Pending_coinbase_hash = Pending_coinbase_hash
    module Transaction_witness = Transaction_witness
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Ledger_proof_statement = Transaction_snark.Statement
    module Ledger_proof = Ledger_proof
    module Transaction_snark_work = Transaction_snark_work
    module Staged_ledger_diff = Staged_ledger_diff
    module External_transition = External_transition
    module Staged_ledger = Staged_ledger
    module Pending_coinbase_stack_state = Pending_coinbase_stack_state
    module Pending_coinbase = Pending_coinbase
    module Verifier = Verifier

    let max_length = Consensus.Constants.k
  end

  module Transition_frontier =
    Transition_frontier.Make (Transition_frontier_inputs)
  module Transition_storage =
    Transition_frontier_persistence.Transition_storage.Make
      (Transition_frontier_inputs)

  module Transition_frontier_persistence =
  Transition_frontier_persistence.Make (struct
    include Transition_frontier_inputs
    module Transition_frontier = Transition_frontier
    module Make_worker = Transition_frontier_persistence.Worker.Make_async
    module Transition_storage = Transition_storage
  end)

  module Transaction_pool = struct
    module Pool = Transaction_pool.Make (Staged_ledger) (Transition_frontier)
    include Network_pool.Make (Transition_frontier) (Pool) (Pool.Diff)

    type pool_diff = Pool.Diff.t

    (* TODO *)
    let load ~logger ~trust_system ~disk_location:_ ~incoming_diffs
        ~frontier_broadcast_pipe =
      return
        (create ~logger ~trust_system ~incoming_diffs ~frontier_broadcast_pipe)

    let transactions t = Pool.transactions (pool t)

    (* TODO: This causes the signature to get checked twice as it is checked
       below before feeding it to add *)
    let add t txn = apply_and_broadcast t (Envelope.Incoming.local [txn])
  end

  module Transaction_pool_diff = Transaction_pool.Pool.Diff
end

module Make_inputs
    (Init : Init_intf)
    (Store : Storage.With_checksum_intf with type location = string) =
struct
  open Init
  module Inputs0 = Make_inputs0 (Init)
  include Inputs0
  module Staged_ledger_diff = Staged_ledger_diff
  module Transaction_snark_work = Transaction_snark_work
  module State_body_hash = State_body_hash
  module Staged_ledger_hash = Staged_ledger_hash
  module Staged_ledger_aux_hash = Staged_ledger_aux_hash
  module Ledger_proof_verifier = Verifier
  module Ledger_hash = Ledger_hash
  module Frozen_ledger_hash = Frozen_ledger_hash
  module User_command = User_command
  module Public_key = Public_key
  module Compressed_public_key = Public_key.Compressed
  module Private_key = Private_key
  module Keypair = Keypair

  module Genesis = struct
    let state = Genesis_protocol_state.t

    let ledger = Genesis_ledger.t

    let proof = Init.genesis_proof
  end

  module Snark_pool = struct
    module Work = Transaction_snark_work.Statement
    module Proof = Transaction_snark_work_proof.Stable.V1

    module Fee = struct
      module Stable = struct
        module V1 = struct
          module T = struct
            type t =
              {fee: Fee.Unsigned.t; prover: Public_key.Compressed.Stable.V1.t}
            [@@deriving bin_io, sexp, yojson, version]

            (* TODO: Compare in a better way than with public key, like in transaction pool *)
            let compare t1 t2 =
              let r = compare t1.fee t2.fee in
              if Int.( <> ) r 0 then r
              else Public_key.Compressed.compare t1.prover t2.prover

            let gen =
              (* This isn't really a valid public key, but good enough for testing *)
              let pk =
                let open Snark_params.Tick in
                let open Quickcheck.Generator.Let_syntax in
                let%map x = Bignum_bigint.(gen_incl zero (Field.size - one))
                and is_odd = Bool.quickcheck_generator in
                let x = Bigint.(to_field (of_bignum_bigint x)) in
                {Public_key.Compressed.Poly.x; is_odd}
              in
              Quickcheck.Generator.map2 Fee.Unsigned.gen pk
                ~f:(fun fee prover -> {fee; prover})
          end

          include T
          include Comparable.Make (T)
        end
      end
    end

    (* TODO : we're choosing versioned inputs, so the result should be versioned *)
    module Pool =
      Snark_pool.Make (Proof) (Fee.Stable.V1) (Work) (Transition_frontier)
    module Snark_pool_diff =
      Network_pool.Snark_pool_diff.Make (Proof) (Fee.Stable.V1) (Work)
        (Transition_frontier)
        (Pool)

    type pool_diff = Snark_pool_diff.t

    include Network_pool.Make (Transition_frontier) (Pool) (Snark_pool_diff)

    let get_completed_work t statement =
      Option.map
        (Pool.request_proof (pool t) statement)
        ~f:(fun {proof; fee= {fee; prover}} ->
          Transaction_snark_work.Checked.create_unsafe
            {Transaction_snark_work.fee; proofs= proof; prover} )

    let load ~logger ~trust_system ~disk_location ~incoming_diffs
        ~frontier_broadcast_pipe =
      match%map Reader.load_bin_prot disk_location Pool.bin_reader_t with
      | Ok pool ->
          let network_pool = of_pool_and_diffs pool ~logger ~incoming_diffs in
          Pool.listen_to_frontier_broadcast_pipe frontier_broadcast_pipe pool ;
          network_pool
      | Error _e ->
          create ~logger ~trust_system ~incoming_diffs ~frontier_broadcast_pipe

    open Snark_work_lib.Work
    open Network_pool.Snark_pool_diff

    let add_completed_work t
        (res :
          (('a, 'b, 'c, 'd) Single.Spec.t Spec.t, Ledger_proof.t) Result.t) =
      apply_and_broadcast t
        (Envelope.Incoming.wrap
           ~data:
             (Diff.Add_solved_work
                ( List.map res.spec.instances ~f:Single.Spec.statement
                , { Snark_pool_diff.Priced_proof.proof= res.proofs
                  ; fee= {fee= res.spec.fee; prover= res.prover} } ))
           ~sender:Envelope.Sender.Local)
  end

  module Root_sync_ledger = Sync_ledger.Db

  module Net = Coda_networking.Make (struct
    include Inputs0
    module External_transition = External_transition
    module Snark_pool = Snark_pool
    module Snark_pool_diff = Snark_pool.Snark_pool_diff
    module Sync_ledger = Sync_ledger
    module Staged_ledger_hash = Staged_ledger_hash
    module Ledger_hash = Ledger_hash
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Staged_ledger_diff = Staged_ledger_diff
    module Transaction_snark_work = Transaction_snark_work
    module Ledger_proof_statement = Transaction_snark.Statement
  end)

  module Sync_handler = Sync_handler.Make (struct
    include Inputs0
    module External_transition = External_transition
    module Staged_ledger_diff = Staged_ledger_diff
    module Transaction_snark_work = Transaction_snark_work
    module Syncable_ledger = Sync_ledger
    module Ledger_proof_statement = Transaction_snark.Statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Verifier = Verifier
  end)

  module Transition_handler = Transition_handler.Make (struct
    include Inputs0
    module External_transition = External_transition
    module State_proof = Protocol_state_proof
    module Transaction_snark_work = Transaction_snark_work
    module Staged_ledger_diff = Staged_ledger_diff
    module Ledger_proof_statement = Transaction_snark.Statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Verifier = Verifier
  end)

  module Ledger_catchup = Ledger_catchup.Make (struct
    include Inputs0
    module External_transition = External_transition
    module Staged_ledger_diff = Staged_ledger_diff
    module Transaction_snark_work = Transaction_snark_work
    module Transition_handler_validator = Transition_handler.Validator
    module Unprocessed_transition_cache =
      Transition_handler.Unprocessed_transition_cache
    module Ledger_proof_statement = Transaction_snark.Statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Network = Net
    module Breadcrumb_builder = Transition_handler.Breadcrumb_builder
    module Verifier = Verifier
  end)

  module Root_prover = Root_prover.Make (struct
    include Inputs0
    module External_transition = External_transition
    module Staged_ledger_diff = Staged_ledger_diff
    module Transaction_snark_work = Transaction_snark_work
    module Ledger_proof_statement = Transaction_snark.Statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Verifier = Verifier
  end)

  module Bootstrap_controller = Bootstrap_controller.Make (struct
    include Inputs0
    module External_transition = External_transition
    module Staged_ledger_diff = Staged_ledger_diff
    module Transaction_snark_work = Transaction_snark_work
    module Ledger_proof_statement = Transaction_snark.Statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Consensus_mechanism = Consensus
    module Root_sync_ledger = Root_sync_ledger
    module Network = Net
    module Sync_handler = Sync_handler
    module Root_prover = Root_prover
    module Verifier = Verifier
  end)

  module Transition_frontier_controller =
  Transition_frontier_controller.Make (struct
    include Inputs0
    module External_transition = External_transition
    module Transaction_snark_work = Transaction_snark_work
    module Syncable_ledger = Sync_ledger
    module Sync_handler = Sync_handler
    module Catchup = Ledger_catchup
    module Transition_handler = Transition_handler
    module Staged_ledger_diff = Staged_ledger_diff
    module Ledger_diff = Staged_ledger_diff
    module Consensus_mechanism = Consensus
    module Ledger_proof_statement = Transaction_snark.Statement
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Network = Net
    module Verifier = Verifier
  end)

  module Transition_router = Transition_router.Make (struct
    include Transition_frontier_inputs
    module Network = Net
    module Transition_frontier = Transition_frontier
    module Transition_frontier_controller = Transition_frontier_controller
    module Bootstrap_controller = Bootstrap_controller
  end)

  module Pending_coinbase_witness = Pending_coinbase_witness

  module Proposer = Proposer.Make (struct
    include Inputs0
    module External_transition = External_transition
    module Internal_transition = Internal_transition
    module Genesis_ledger = Genesis_ledger
    module State_hash = State_hash
    module Staged_ledger_diff = Staged_ledger_diff
    module Ledger_proof_verifier = Verifier
    module Transaction_snark_work = Transaction_snark_work
    module Staged_ledger_hash = Staged_ledger_hash
    module Staged_ledger_aux_hash = Staged_ledger_aux_hash
    module Ledger_proof_statement = Transaction_snark.Statement
    module Ledger_hash = Ledger_hash
    module Frozen_ledger_hash = Frozen_ledger_hash
    module User_command = User_command
    module Public_key = Public_key
    module Private_key = Private_key
    module Keypair = Keypair
    module Compressed_public_key = Public_key.Compressed
    module Transaction_validator = Transaction_validator
    module Pending_coinbase_witness = Pending_coinbase_witness

    module Prover = struct
      let prove ~prev_state ~prev_state_proof ~next_state
          (transition : Internal_transition.t) pending_coinbase =
        match Init.proposer_prover with
        | `Non_proposer ->
            failwith "prove: Coda not run as proposer"
        | `Proposer prover ->
            let open Deferred.Or_error.Let_syntax in
            Prover.extend_blockchain prover
              (Blockchain.create ~proof:prev_state_proof ~state:prev_state)
              next_state
              (Internal_transition.snark_transition transition)
              (Internal_transition.prover_state transition)
              pending_coinbase
            >>| fun {Blockchain.proof; _} -> proof
    end
  end)

  module Work_selector_inputs = struct
    module Transaction_witness = Transaction_witness
    module Ledger_proof_statement = Transaction_snark.Statement
    module Sparse_ledger = Sparse_ledger
    module Transaction = Transaction
    module Ledger_hash = Ledger_hash
    module Ledger_proof = Ledger_proof
    module Staged_ledger = Staged_ledger
    module Fee = Fee.Unsigned
    module Snark_pool = Snark_pool

    module Transaction_snark_work = struct
      type t = Transaction_snark_work.Checked.t

      let fee t =
        let {Transaction_snark_work.fee; _} =
          Transaction_snark_work.forget t
        in
        fee
    end
  end

  module Work_selector = Make_work_selector (Work_selector_inputs)

  let request_work ~logger ~best_staged_ledger
      ~(seen_jobs : 'a -> Work_selector.State.t)
      ~(set_seen_jobs : 'a -> Work_selector.State.t -> unit)
      ~(snark_pool : 'a -> Snark_pool.t) (t : 'a) (fee : Fee.Unsigned.t) =
    let best_staged_ledger t =
      match best_staged_ledger t with
      | `Active staged_ledger ->
          Some staged_ledger
      | `Bootstrapping ->
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            "Could not retrieve staged_ledger due to bootstrapping" ;
          None
    in
    let open Option.Let_syntax in
    let%bind sl = best_staged_ledger t in
    let instances, seen_jobs =
      Work_selector.work ~fee ~snark_pool:(snark_pool t) sl (seen_jobs t)
    in
    set_seen_jobs t seen_jobs ;
    if List.is_empty instances then None
    else Some {Snark_work_lib.Work.Spec.instances; fee}
end

module Make_coda (Init : Init_intf) = struct
  module Inputs = struct
    include Make_inputs (Init) (Storage.Disk)
    module Genesis_ledger = Genesis_ledger
    module Ledger_proof_statement = Transaction_snark.Statement
    module Transaction_validator = Transaction_validator
    module Genesis_protocol_state = Genesis_protocol_state
    module Snark_transition = Snark_transition
    module Consensus_transition = Consensus.Data.Consensus_transition
    module Consensus_state = Consensus.Data.Consensus_state
    module Blockchain_state = Blockchain_state
    module Prover_state = Consensus.Data.Prover_state
    module External_transition = External_transition
    module Internal_transition = Internal_transition
    module Verifier = Verifier
  end

  include Coda_lib.Make (Inputs)

  let request_work t =
    Inputs.request_work ~logger:t.logger ~best_staged_ledger ~seen_jobs
      ~set_seen_jobs ~snark_pool t (snark_work_fee t)
end
