
exception UnidentifiedToken of Range.t * string
exception SeeEndOfFileInComment of Range.t
exception UnknownBaseType of Range.t * string


type identifier = string


let pp_identifier ppf s =
  Format.fprintf ppf "\"%s\"" s


let pp_binder ppf (_, s) =
  Format.fprintf ppf "%a" pp_identifier s


type base_type =
  | IntType
  | BoolType
[@@deriving show { with_path = false; } ]

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

and binder = (Range.t * identifier) * mono_type

and mono_type = Range.t * mono_type_main

and mono_type_main =
  | BaseType of base_type
  | CodeType of mono_type
  | FuncType of mono_type * mono_type
[@@deriving show { with_path = false; } ]


let show_mono_type ty =
  let rec aux isdom (_, tymain) =
    match tymain with
    | BaseType(IntType) -> "int"
    | BaseType(BoolType) -> "bool"

    | CodeType(ty1) ->
        let s = aux true ty1 in
        "@" ^ s

    | FuncType(ty1, ty2) ->
        let s1 = aux true ty1 in
        let s2 = aux false ty2 in
        let s = s1 ^ " -> " ^ s2 in
        if isdom then "(" ^ s ^ ")" else s
  in
  aux false ty


let pp_mono_type ppf ty =
  Format.fprintf ppf "%s" (show_mono_type ty)
