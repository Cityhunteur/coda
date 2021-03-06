(* Points on elliptic curves over finite fields by M. SKALBA
 * https://www.impan.pl/pl/wydawnictwa/czasopisma-i-serie-wydawnicze/acta-arithmetica/all/117/3/82159/points-on-elliptic-curves-over-finite-fields
 *
 * Thm 1.
 * have f(X1)f(X2)f(X3) = U^2 => at least one of f(X1), f(X2) or f(X3) 
 * is square. Take that Xi as the x coordinate and solve for y to 
 * find a point on the curve.
 *
 * Thm 2.
 * if we take map(t) = (Xj(t^2), sqrt(f(Xj(t^2)),
 * with j = min{1 <= i <= 3 | f(Xi(t^2)) in F_q^2}, then map(t)
 * is well defined for at least |T| - 25 values of t and |Im(map| > (|T|-25)/26
 *)

open Core_kernel
module Field_intf = Field_intf

module Intf (F : sig
  type t
end) =
struct
  module type S = sig
    val to_group : F.t -> F.t * F.t
  end
end

module AB_pair = struct
  module T = struct
    type t = int * int [@@deriving compare, hash, sexp]
  end

  include T
  include Hashable.Make (T)
end

let interval x y = Sequence.range ~start:`inclusive ~stop:`inclusive x y

(* for v, k, powers produces v^0, v^1, ... v^k *)
let powers ~mul ~one v k =
  let len = k + 1 in
  let arr = Array.create ~len one in
  let rec go acc i =
    arr.(i) <- acc ;
    let i = i + 1 in
    if i < len then go (mul acc v) i
  in
  go v 1 ; arr

module Params = struct
  type 'f coefficients =
    {n1: 'f; d1: 'f; n2: 'f; d2: 'f; n3: 'f; d31: 'f; d32: 'f}

  let map {n1; d1; n2; d2; n3; d31; d32} ~f =
    {n1= f n1; d1= f d1; n2= f n2; d2= f d2; n3= f n3; d31= f d31; d32= f d32}

  let t =
    { n1=
        AB_pair.Table.of_alist_exn
          [ ((0, 0), "212")
          ; ((0, 1), "-208")
          ; ((3, 0), "-161568")
          ; ((0, 2), "-264")
          ; ((3, 1), "441408")
          ; ((0, 3), "304")
          ; ((6, 0), "-92765376")
          ; ((3, 2), "-127776")
          ; ((0, 4), "-44") ]
    ; d1=
        AB_pair.Table.of_alist_exn
          [ ((0, 0), "-1")
          ; ((0, 1), "5")
          ; ((3, 0), "10536")
          ; ((0, 2), "-10")
          ; ((3, 1), "9480")
          ; ((0, 3), "10")
          ; ((6, 0), "4024944")
          ; ((3, 2), "-4488")
          ; ((0, 4), "-5")
          ; ((6, 1), "2108304")
          ; ((3, 3), "2904")
          ; ((0, 5), "1") ]
    ; n2=
        AB_pair.Table.of_alist_exn
          [ ((0, 0), "-1")
          ; ((0, 1), "6")
          ; ((3, 0), "-4356")
          ; ((0, 2), "-15")
          ; ((3, 1), "-424944")
          ; ((0, 3), "20")
          ; ((6, 0), "-6324912")
          ; ((3, 2), "-26136")
          ; ((0, 4), "-15")
          ; ((6, 1), "12649824")
          ; ((3, 3), "17424")
          ; ((0, 5), "6")
          ; ((9, 0), "-3061257408")
          ; ((6, 2), "-6324912")
          ; ((3, 4), "-4356")
          ; ((0, 6), "-6") ]
    ; d2=
        AB_pair.Table.of_alist_exn
          [ ((0, 0), "1")
          ; ((0, 1), "-4")
          ; ((3, 0), "5976")
          ; ((0, 2), "6")
          ; ((3, 1), "-5808")
          ; ((0, 3), "-4")
          ; ((6, 0), "2108304")
          ; ((3, 2), "2904")
          ; ((0, 4), "1") ]
    ; n3=
        AB_pair.Table.of_alist_exn
          [ ((0, 1), "1")
          ; ((3, 0), "0")
          ; ((0, 2), "-15")
          ; ((3, 1), "-31608")
          ; ((0, 3), "105")
          ; ((6, 0), "-2382032")
          ; ((3, 2), "287640")
          ; ((0, 4), "-455")
          ; ((6, 1), "327958320")
          ; ((3, 3), "-1124496")
          ; ((0, 5), "1365")
          ; ((9, 0), "5446134144")
          ; ((6, 2), "-949378416")
          ; ((3, 4), "2369808")
          ; ((0, 6), "-3003")
          ; ((9, 1), "-940697745408")
          ; ((6, 3), "-185899568")
          ; ((3, 5), "-2531880")
          ; ((0, 7), "5005")
          ; ((12, 0), "-1023635467008")
          ; ((9, 2), "-4041852271488")
          ; ((6, 4), "3844905120")
          ; ((3, 6), "-14904")
          ; ((0, 8), "6435")
          ; ((12, 1), "-1271178606627072")
          ; ((9, 3), "-557953136640")
          ; ((6, 5), "-5637798432")
          ; ((3, 7), "4402080")
          ; ((0, 9), "6435")
          ; ((15, 0), "-3711755775062016")
          ; ((12, 2), "-3365703371771136")
          ; ((9, 4), "1809225932544")
          ; ((6, 6), "2558454048")
          ; ((3, 8), "-7401888")
          ; ((0, 10), "-5005")
          ; ((15, 1), "-502999567986972672")
          ; ((12, 3), "-924766944152832")
          ; ((9, 5), "-3401013749760")
          ; ((6, 7), "1784103840")
          ; ((3, 9), "7013304")
          ; ((0, 11), "3003")
          ; ((18, 0), "447914759358173184")
          ; ((15, 2), "-981669643253544960")
          ; ((12, 4), "329477012308224")
          ; ((9, 6), "913161021696")
          ; ((6, 8), "-3372070032")
          ; ((3, 10), "-4408920")
          ; ((0, 12), "-1365")
          ; ((18, 1), "-73786028437373497344")
          ; ((15, 3), "-459570852044992512")
          ; ((12, 5), "-977913669655296")
          ; ((9, 7), "439245379584")
          ; ((6, 9), "2438317040")
          ; ((3, 11), "1904112")
          ; ((0, 13), "455")
          ; ((21, 0), "1042769766152244658176")
          ; ((18, 2), "-84332284536876355584")
          ; ((15, 4), "5961076345331712")
          ; ((12, 6), "-43484326592256")
          ; ((9, 8), "-707241693312")
          ; ((6, 10), "-1030036656")
          ; ((3, 12), "-555120")
          ; ((0, 14), "-105")
          ; ((21, 1), "-2848874263082603053056")
          ; ((18, 3), "-63482146340076490752")
          ; ((15, 5), "-101522561076541440")
          ; ((12, 7), "69490543161600")
          ; ((9, 9), "280657428480")
          ; ((6, 11), "255430032")
          ; ((3, 13), "100584")
          ; ((0, 15), "15")
          ; ((24, 0), "199571139166470771769344")
          ; ((21, 2), "824674128787069304832")
          ; ((18, 4), "-7951403445605351424")
          ; ((15, 6), "-37420516674680832")
          ; ((12, 8), "-66000709716480")
          ; ((9, 10), "-61039617408")
          ; ((6, 12), "-31603264")
          ; ((3, 14), "-8712")
          ; ((0, 16), "-1") ]
    ; d31=
        AB_pair.Table.of_alist_exn
          [ ((0, 0), "-1")
          ; ((0, 1), "5")
          ; ((3, 0), "10536")
          ; ((0, 2), "-10")
          ; ((3, 1), "9480")
          ; ((0, 3), "10")
          ; ((6, 0), "4024944")
          ; ((3, 2), "-4488")
          ; ((0, 4), "-5")
          ; ((6, 1), "2108304")
          ; ((3, 3), "2904")
          ; ((0, 5), "1") ]
    ; d32=
        AB_pair.Table.of_alist_exn
          [ ((0, 0), "1")
          ; ((0, 1), "-10")
          ; ((3, 0), "12636")
          ; ((0, 2), "45")
          ; ((3, 1), "20256")
          ; ((0, 3), "-120")
          ; ((6, 0), "51578784")
          ; ((3, 2), "-158448")
          ; ((0, 4), "210")
          ; ((6, 1), "426572352")
          ; ((3, 3), "149472")
          ; ((0, 5), "-252")
          ; ((9, 0), "74892394368")
          ; ((6, 2), "-178487712")
          ; ((3, 4), "146472")
          ; ((0, 6), "210")
          ; ((9, 1), "42705805824")
          ; ((6, 3), "-194173056")
          ; ((3, 5), "-328224")
          ; ((0, 7), "-120")
          ; ((12, 0), "38682048607488")
          ; ((9, 2), "217678171392")
          ; ((6, 4), "339663456")
          ; ((3, 6), "208656")
          ; ((0, 8), "45")
          ; ((12, 1), "-44449457564160")
          ; ((9, 3), "-122450296320")
          ; ((6, 5), "-126498240")
          ; ((3, 7), "-58080")
          ; ((0, 9), "10")
          ; ((15, 0), "6454061238316032")
          ; ((12, 2), "22224728782080")
          ; ((9, 4), "30612574080")
          ; ((6, 6), "21083040")
          ; ((3, 8), "7260")
          ; ((0, 10), "1") ] }

  let%test_unit "sanity check" =
    let {n1; d1; n2; d2; n3; d31; d32} = t in
    List.iter [n1; d1; n2; d2; n3; d31; d32] ~f:(fun t ->
        Hashtbl.iter_keys t ~f:(fun (a, b) ->
            let three_j = (2 * a) + (3 * b) in
            if three_j mod 3 <> 0 then
              failwithf "2 * %d + 3 * %d = %d = %d mod 3" a b three_j
                (three_j mod 3) ()
            else () ) )

  module Magic_numbers = struct
    type nonrec 'f t = 'f AB_pair.Table.t coefficients

    let create ~negate ~of_string : _ t =
      map t
        ~f:
          (Hashtbl.map ~f:(fun s ->
               if s.[0] = '-' then
                 let s' = String.sub s ~pos:1 ~len:(String.length s - 1) in
                 negate (of_string s')
               else of_string s ))
  end

  let ( @! ) tbl (a, b) =
    match Hashtbl.find tbl (a, b) with
    | None ->
        failwithf "group_map: coefficient for (%d, %d) not found" a b ()
    | Some c ->
        c

  let abs j =
    (* Find all integers a, b >= 0 such that 2 a + 3 b = 3 j.
        Note that this implies 
        3 b <= 3 j so 0 <= b <= j.
    *)
    let open Sequence in
    let open Let_syntax in
    let%bind b = interval 0 j in
    let two_a = (3 * j) - (3 * b) in
    if two_a mod 2 = 0 then return (two_a / 2, b) else empty

  module Intermediate = struct
    type 'f t = {ab_products: 'f AB_pair.Table.t}

    let max_j = 16

    let max_a = 3 * max_j / 2

    let max_b = max_j

    let create (type t) (module F : Field_intf.S with type t = t) ~a:coeff_a
        ~b:coeff_b =
      let mul = F.( * ) in
      let one = F.one in
      let a_powers = powers ~mul ~one coeff_a max_a in
      let b_powers = powers ~mul ~one coeff_b max_b in
      let ab_products =
        let res = AB_pair.Table.create () in
        let open Sequence in
        iter
          (concat_map (interval 0 max_j) ~f:abs)
          ~f:(fun (a, b) ->
            Hashtbl.find_or_add res (a, b) ~default:(fun () ->
                F.(a_powers.(a) * b_powers.(b)) )
            |> ignore ) ;
        res
      in
      {ab_products}
  end

  let init_range x y ~f = Array.init (y - x + 1) ~f:(fun i -> f (x + i))

  type 'f t = {coefficients: 'f array coefficients; a: 'f; b: 'f; a2: 'f}
  [@@deriving fields]

  (* Compute the coefficients for all the magic polynomials *)
  let create (type t) ((module F : Field_intf.S with type t = t) as m) ~a ~b =
    let open F in
    let {Intermediate.ab_products} = Intermediate.create m ~a ~b in
    let {n1; d1; n2; d2; n3; d31; d32} =
      Magic_numbers.create ~negate
        ~of_string:(Fn.flip Sexp.of_string_conv_exn t_of_sexp)
    in
    let sum seq f = Sequence.fold seq ~init:zero ~f:(fun acc x -> f x + acc) in
    let absum tbl j =
      sum (abs j) (fun ab -> (tbl @! ab) * (ab_products @! ab))
    in
    { coefficients=
        { n1= init_range 0 4 ~f:(absum n1)
        ; d1= init_range 0 5 ~f:(absum d1)
        ; n2= init_range 0 6 ~f:(absum n2)
        ; d2= init_range 0 4 ~f:(absum d2)
        ; n3= init_range 0 15 ~f:(fun j -> absum n3 Int.(j + 1))
        ; d31= init_range 0 5 ~f:(absum d31)
        ; d32= init_range 0 10 ~f:(absum d32) }
    ; a
    ; a2= a * a
    ; b }
end

module Make
    (Constant : Field_intf.S) (F : sig
        include Field_intf.S

        val constant : Constant.t -> t
    end) (P : sig
      val params : Constant.t Params.t
    end) =
struct
  open P

  let eval_polynomial coefficients t_powers =
    Array.foldi coefficients ~init:F.zero ~f:(fun i acc c ->
        F.((constant c * t_powers.(i)) + acc) )

  (* Xi(t) = Ni(t)/Di(t)  for i = 1, 2, 3 *)
  (*
   * N1(t) = A^2 . t . sum from j = 0 to j = 4 of [
   *    sum for 2a+3b=3j of ( n1_(a,b) A^a . B^b ) . t^j ]
   * D1(t) = sum from j = 0 to j = 5 of [
   *    sum for 2a+3b=3j of ( d1_(a,b) A^a . B^b ) . t^j ]
   *)
  let make_x1 t_powers =
    let open F in
    let n1 =
      constant params.a2 * t_powers.(1)
      * eval_polynomial params.coefficients.n1 t_powers
    in
    let d1 = eval_polynomial params.coefficients.d1 t_powers in
    n1 / d1

  (* N2(t) = sum from j = 0 to j = 6 of [
   *    sum for 2a+3b=3j of ( n2_(a,b) A^a . B^b ) . t^j ]
   * D2(t) = 144At . sum from j = 0 to j = 4 of [
   *    sum for 2a+3b=3j of ( d2_(a,b) A^a . B^b ) . t^j ]
   *)
  let make_x2 t_powers =
    let open F in
    let n2 = eval_polynomial params.coefficients.n2 t_powers in
    let d2 =
      constant Constant.(of_int 144 * params.a)
      * t_powers.(1)
      * eval_polynomial params.coefficients.d2 t_powers
    in
    n2 / d2

  (* N3(t) = sum from j = 0 to j = 15 of [
   *    sum for 2a+3b=3(j+1) of ( n3_(a,b) A^a . B^b ) . t^j ]
   * D3(t) = A . sum from j = 0 to j = 5 of [
   *    sum for 2a+3b=3j of ( d31_(a,b) a^a . b^b ) . t^j ]
   *    .
   *    sum from j = 0 to j = 10 of [
   *    sum for 2a+3b=3j of ( d32_(a,b) a^a . b^b ) . t^j ]
   *)
  let make_x3 t_powers =
    let open F in
    let n3 = eval_polynomial params.coefficients.n3 t_powers in
    let d3 =
      let d31 = eval_polynomial params.coefficients.d31 t_powers in
      let d32 = eval_polynomial params.coefficients.d32 t_powers in
      constant params.a * d31 * d32
    in
    n3 / d3

  let potential_xs t =
    let ts = powers ~mul:F.( * ) ~one:F.one t 15 in
    (make_x1 ts, make_x2 ts, make_x3 ts)
end

let to_group (type t) (module F : Field_intf.S_unchecked with type t = t)
    ~params t =
  let module M =
    Make
      (F)
      (struct
        include F

        let constant = Fn.id
      end)
      (struct
        let params = params
      end)
  in
  let a = Params.a params in
  let b = Params.b params in
  let try_decode x =
    let f x = F.((x * x * x) + (a * x) + b) in
    let y = f x in
    if F.is_square y then Some (x, F.sqrt y) else None
  in
  let x1, x2, x3 = M.potential_xs t in
  List.find_map [x1; x2; x3] ~f:try_decode |> Option.value_exn
