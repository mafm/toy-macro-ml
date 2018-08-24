
exception UnidentifiedToken of Range.t * string
exception SeeEndOfFileInComment of Range.t


type identifier = string


let pp_identifier ppf s =
  Format.fprintf ppf "\"%s\"" s


type binder = Range.t * identifier


let pp_binder ppf (_, s) =
  Format.fprintf ppf "%a" pp_identifier s


type untyped_ast = Range.t * untyped_ast_main
  [@printer (fun ppf (_, utastmain) -> pp_untyped_ast_main ppf utastmain)]

and untyped_ast_main =
  | Bool     of bool
  | Int      of int
  | Var      of identifier
  | Lambda   of binder * untyped_ast
  | Apply    of untyped_ast * untyped_ast
  | If       of untyped_ast * untyped_ast * untyped_ast
  | LetIn    of binder * untyped_ast * untyped_ast
  | LetRecIn of binder * untyped_ast * untyped_ast
[@@deriving show { with_path = false; } ]


type base_type =
  | IntType
  | BoolType
[@@deriving show { with_path = false; } ]

type 'a typ = Range.t * 'a typ_main
(*
  [@printer (fun (pp_sub : Format.formatter -> 'a -> unit) (ppf : Format.formatter) ((_, tymain) : 'a typ) -> Format.fprintf ppf "%a" (pp_typ_main pp_sub) tymain)]
*)
and 'a typ_main =
  | BaseType of base_type
  | FuncType of 'a typ * 'a typ
  | TypeVar  of 'a
[@@deriving show { with_path = false; } ]

type mono_type_var =
  | Free of FreeID.t
  | Link of mono_type

and mono_type = (mono_type_var ref) typ

type poly_type_var =
  | Mono  of mono_type_var ref
  | Bound of BoundID.t

type poly_type = poly_type_var typ


module FreeIDHashTable = Hashtbl.Make(FreeID)


let generalize lev ty =

  let fidht = FreeIDHashTable.create 32 in

  let intern fid =
    match FreeIDHashTable.find_opt fidht fid with
    | Some(bid) ->
        bid

    | None ->
        let bid = BoundID.fresh () in
        FreeIDHashTable.add fidht fid bid;
        bid
  in

  let rec aux (rng, tymain) =
    match tymain with
    | BaseType(bty) ->
        (rng, BaseType(bty))

    | TypeVar({contents = Link(ty)}) ->
        aux ty

    | TypeVar({contents = Free(fidx)} as mtv) ->
        let levx = FreeID.get_level fidx in
        let ptv =
          if lev <= levx then
            Bound(intern fidx)
          else
            Mono(mtv)
        in
        (rng, TypeVar(ptv))

    | FuncType(ty1, ty2) ->
        let pty1 = aux ty1 in
        let pty2 = aux ty2 in
        (rng, FuncType(pty1, pty2))
  in
  aux ty


let show_mono_type ty =
  let rec aux isdom (_, tymain) =
    match tymain with
    | BaseType(IntType) -> "int"
    | BaseType(BoolType) -> "bool"
    | FuncType(ty1, ty2) ->
        let s1 = aux true ty1 in
        let s2 = aux false ty2 in
        let s = s1 ^ " -> " ^ s2 in
        if isdom then "(" ^ s ^ ")" else s

    | TypeVar(tvref) ->
        begin
          match !tvref with
          | Link(ty) -> aux isdom ty
          | Free(fid) -> Format.asprintf "%a" FreeID.pp fid
        end
  in
  aux false ty


let pp_mono_type ppf ty =
  Format.fprintf ppf "%s" (show_mono_type ty)
