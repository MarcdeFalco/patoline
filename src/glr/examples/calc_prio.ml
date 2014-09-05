open Glr

let blank = blank_regexp (Str.regexp "[ \t\n\r]*")

let float_re = "[0-9]+\\([.][0-9]+\\)?\\([eE][-]?[0-9]+\\)?"
let ident_re = "[a-zA-Z_'][a-zA-Z0-9_']*"

type calc_prio = Sum | Prod | Pow | Atom

let next_prio = function
    Sum -> Prod
  | Prod -> Pow
  | Pow -> Atom
  | Atom -> assert false

let prio_to_string = function
    Sum -> "Sum"
  | Prod -> "Prod"
  | Pow -> "Pow"
  | Atom -> "Atom"

let expression, set_expression = grammar_family ~param_to_string:prio_to_string "expression" 

let env = Hashtbl.create 101

let _ = set_expression
  (fun prio ->
   parser
  | f:RE(float_re) when prio = Atom -> float_of_string f
  | id:RE(ident_re) when prio = Atom ->
      (try Hashtbl.find env id
       with Not_found ->
	 Printf.eprintf "Unbound %s\n%!" id; raise Exit)
  | CHR('(') e:(expression Sum) CHR(')') when prio = Atom -> e
  | e:(expression Atom) e':{STR("**") e':(expression Pow)}? when prio = Pow ->
	 (match e' with None -> e | Some e' -> e ** e')
  | e:(expression Pow) l:{fn:{CHR('*') -> ( *. ) | CHR('/') -> ( /. )} e':(expression Pow)}* when prio = Prod ->
      List.fold_left ( fun acc (fn, e') -> fn acc e') e l
  | e:(expression Prod) l:{fn:{CHR('+') -> ( +. ) | CHR('-') -> ( -. )} e':(expression Prod)}* when prio = Sum ->
      List.fold_left ( fun acc (fn, e') -> fn acc e') e l
  | CHR('-') e:(expression prio) -> -. e
  | CHR('+') e:(expression prio) -> e
  )

let arith = 
  parser
  | id:RE(ident_re) CHR('=') e:(expression Sum) -> Hashtbl.add env id e; e
  | e:(expression Sum) -> e

let _ =
  if Unix.((fstat (descr_of_in_channel Pervasives.stdin)).st_kind = S_REG)
  then
      try
	let x = parse_channel arith blank "stdin" stdin in
	Printf.printf "=> %f\n" x
      with
	Parse_error (fname,l,n,msg) -> Printf.fprintf stderr "%s: Parse error %d:%d, '%s' expected\n%!" fname l n (String.concat "|" msg)
      | Ambiguity(fname,l,n,_,l',n') -> Printf.fprintf stderr "%s: Ambiguous expression from %d:%d to %d:%d\n%!" fname l n l' n'
  else
    try
      while true do
	try
	  Printf.printf ">> %!";
	  let x = parse_string arith blank "stdin" (input_line stdin) in
	  Printf.printf "=> %f\n%!" x
	with
	  Parse_error(fname,l,n,msg) -> Printf.fprintf stderr "Parse error after char %d, '%s' expected\n%!" n (String.concat "|" msg)
	| Ambiguity(fname,l,n,_,l',n') -> Printf.fprintf stderr "Ambiguous expression from %d to %d\n%!" n n'
	| Exit -> ()
      done
  with End_of_file -> ()
