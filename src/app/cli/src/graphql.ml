open Core
open Async
open Graphql_async
open Schema
open Pipe_lib
open Coda_base
open Signature_lib

module Make
    (Config_in : Coda_inputs.Config_intf)
    (Program : Coda_inputs.Main_intf) =
struct
  open Program
  open Inputs

  module Types = struct
    module Stringable = struct
      (** 64-bit respresentation of public key that is compressed to make snark computation efficent *)
      let public_key = Public_key.Compressed.to_base64

      (** Unix form of time, which is the number of milliseconds that elapsed from January 1, 1970 *)
      let date time =
        Time.to_span_since_epoch time |> Time.Span.to_ms |> Int64.to_string

      (** Javascript only has 53-bit integers so we need to make them into strings  *)
      let uint64 uint64 = Unsigned.UInt64.to_string uint64
    end

    (* TODO: include submitted_at (date) and included_at (date). These two fields are not exposed in the user_command *)
    let payment : (t, User_command.t option) typ =
      obj "payment" ~fields:(fun _ ->
          [ field "nonce" ~typ:(non_null int) ~doc:"Nonce of the transaction"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command_payload.nonce @@ User_command.payload payment
                |> Account.Nonce.to_int )
          ; field "sender" ~typ:(non_null string)
              ~doc:"Public key of the sender"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command.sender payment |> Stringable.public_key )
          ; field "receiver" ~typ:(non_null string)
              ~doc:"Public key of the receiver"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                match
                  User_command_payload.body (User_command.payload payment)
                with
                | Payment {Payment_payload.Poly.receiver; _} ->
                    receiver |> Stringable.public_key
                | Stake_delegation _ ->
                    failwith "Payment should not consist of a stake delegation"
                )
          ; field "amount" ~typ:(non_null string)
              ~doc:
                "Amount that sender send to receiver (amount is uint64 and is \
                 coerced as a string)"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                match
                  User_command_payload.body (User_command.payload payment)
                with
                | Payment {Payment_payload.Poly.amount; _} ->
                    amount |> Currency.Amount.to_uint64 |> Stringable.uint64
                | Stake_delegation _ ->
                    failwith "Payment should not consist of a stake delegation"
                )
          ; field "fee" ~typ:(non_null string)
              ~doc:
                "Fee that sender is willing to pay for making the transaction \
                 (fee is uint64 and is coerced as a string)"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command.fee payment |> Currency.Fee.to_uint64
                |> Stringable.uint64 )
          ; field "memo" ~typ:(non_null string) ~doc:"Note of the transaction"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command_payload.memo @@ User_command.payload payment
                |> User_command_memo.to_string ) ] )

    let sync_status : ('context, [`Offline | `Synced | `Bootstrap]) typ =
      non_null
        (enum "sync_status" ~doc:"Sync status as daemon node"
           ~values:
             [ enum_value "BOOTSTRAP" ~value:`Bootstrap
             ; enum_value "SYNCED" ~value:`Synced
             ; enum_value "OFFLINE" ~value:`Offline ])
  end

  module Queries = struct
    open Types

    let sync_state =
      io_field "sync_status" ~typ:sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} () ->
          Deferred.return
            (Inputs.Incr_status.Observer.value @@ Program.sync_status coda)
          >>| Result.map_error ~f:Error.to_string_hum )

    let version =
      field "version" ~typ:string
        ~args:Arg.[]
        ~doc:"The version of the node (git commit hash)"
        ~resolve:(fun _ _ -> Config_in.commit_id)

    let commands = [sync_state; version]
  end

  module Subscriptions = struct
    let to_pipe observer =
      let reader, writer =
        Strict_pipe.(create (Buffered (`Capacity 1, `Overflow Drop_head)))
      in
      Incr_status.Observer.on_update_exn observer ~f:(function
        | Initialized value ->
            Strict_pipe.Writer.write writer value
        | Changed (_, value) ->
            Strict_pipe.Writer.write writer value
        | Invalidated ->
            () ) ;
      (Strict_pipe.Reader.to_linear_pipe reader).Linear_pipe.Reader.pipe

    let new_sync_update =
      subscription_field "new_sync_update"
        ~doc:"Subscripts on sync update from Coda" ~deprecated:NotDeprecated
        ~typ:Types.sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} ->
          Program.sync_status coda |> to_pipe |> Deferred.Result.return )

    let commands = [new_sync_update]
  end

  let schema =
    Graphql_async.Schema.(
      schema Queries.commands ~subscriptions:Subscriptions.commands)
end