open Typography
open Document
open Patodb
open Patoraw
open RawContent
open Color
open Box
open Patutil
open Util
open Extra
open Verbatim

module type ModDb = sig
  val db : db
  val base_dir : string
end

let strip s =
  let len = String.length s in
  let i = ref 0 in
  while !i < len && List.mem s.[!i] [' ';'\n';'\t';'\r'] do
    incr i
  done;
  let j = ref (len-1) in
  while !i < !j && List.mem s.[!j] [' ';'\n';'\t';'\r'] do
    decr j
  done;
  String.sub s !i (!j - !i + 1)

let group () = match !Patodb.sessid with
  | None -> "guest"
  | Some(_,g,_) -> g

let read_file file =
  let ch = open_in file in
  let len = in_channel_length ch in
  let str = Bytes.create len in
  let _ = input ch str 0 len in
  (*let res = strip str in*)
  close_in ch;
  Bytes.to_string str

let arrow = tT ">>>" :: hspace(1.0)

let file_table = Hashtbl.create 101

module Make(D:DocumentStructure)
 (Format:module type of DefaultFormat.Format(D)
   (* a strange way to remove Output from the
      signature to allow Format to change the
      Output functor *)
   with module Output := DefaultFormat.Format(D).Output)
 (MyDb:ModDb) = struct

  open Format
  open MyDb

type result =
| Ok
| FailTest
| DoNotCompile
| NotTried

let result_coding = {
  encode = (function
  | Ok -> "Ok"
  | FailTest -> "FailTest"
  | DoNotCompile -> "DoNotCompile"
  | NotTried -> "NotTried");
  decode = (function
  | "Ok" -> Ok
  | "FailTest" -> FailTest
  | "DoNotCompile" -> DoNotCompile
  | "NotTried" -> NotTried
  | _ -> DoNotCompile);
}

let scoreBar ?(vertical=false) (module Diagram:Diagrams.Diagram) height width data =
  let open Diagrams in
  let open Diagram in
  let total = max 1 (List.fold_left (fun acc ((_: color),x) -> acc + x) 0 data) in
  let cur_pos = ref 0.0 in
  let len = if vertical then height else width in
  let data = List.map (fun (color, x) ->
    let x1 = !cur_pos +. float x *. len /. float total in
    let res = (color, x, !cur_pos, x1) in
    cur_pos := x1;
    res) data
  in

  if vertical then
    let w2 = width /. 2. in
    List.iter (fun ((col:color), x, x0, x1) ->
      let text = [tT (string_of_int x)] in
      let text_box = Document.draw_boxes env (boxify_scoped env text) in
      let (x0',_,x1',_) = bounding_box_full text_box in
      if x1' -. x0' < 1.75 *. (x1 -. x0) then
        ignore (node Node.([at (w2, (x0 +. x1) /. 2.); outerSep 0.0; innerSep 0.0; setZ (1.0)]) text)
      else
        ignore (node Node.([at (w2, (x0 +. x1) /. 2.); outerSep 0.0; innerSep 0.0; setZ (1.0)])
                  (scale (1.75 *. (x1 -. x0) /. (x1' -. x0')) text));
      ignore (path Edge.([draw;fill (col:color);noStroke]) (0.0, x0)
        [[0.0, x1] ; [width, x1] ; [width, x0]]);
    ) data
  else
    let h2 = height /. 2. in
    List.iter (fun ((col:color), x, x0, x1) ->
      let text = [tT (string_of_int x)] in
      let text_box = Document.draw_boxes env (boxify_scoped env text) in
      let (x0',_,x1',_) = bounding_box_full text_box in
      if x1' -. x0' < 1.75 *. (x1 -. x0) then ignore (node Node.([at ((x0 +. x1) /. 2., h2); outerSep 0.0; innerSep 0.0; setZ (1.0)]) text);
      ignore (path Edge.([draw;fill (col:color);noStroke]) (x0, 0.0) [[x1, 0.0] ; [x1, height] ; [x0, height]]);
    ) data

let battonDiagram barHeight barWidth data ?group values =
  dynamic <<0123456789>> (fun () ->
    let _total, results =
      data.distribution ?group:(match group with None -> None | Some g -> Some (g ())) () in
    let res = List.map (fun (value,color,_) ->
                  (color, try List.assoc value results with Not_found -> 0)) values in
    let anchors = List.map (fun _ -> `Base) values in
    let m = List.fold_left (fun acc (_,n) -> max acc n) 1 res in
    let open Diagrams in
    <<\diagram(
     let _,_ = array  anchors (List.map (List.map DefaultMacros.mathsText) [
     List.map (fun (_, value as c) ->
     <<\diagram(
          let _ = scoreBar ~vertical:true (module Diagram : Diagram)
                           (barHeight *. float value /. float m) barWidth [c])>>)
          res;
     List.map (fun (_,_,txt) -> txt) values]))>>)

let scoreBarProg diagram height width data =
  let data = List.sort (fun (x,_) (x',_) -> compare x x') data in
  let data = List.map (fun
    (x,n) ->
      let color = match x with
          Ok -> green
        | FailTest -> yellow
        | DoNotCompile -> red
        | _ -> grey
      in (color, n)) data
  in
  scoreBar diagram height width data

(*===========================================================================*)
(*                      Check boxes                                          *)
(*===========================================================================*)

let drawCheckBox ?(scale=0.5) env checked =
  let open Diagrams in
  let module Fig = MakeDiagram (struct let env = env end) in
  let open Fig in
  let height = env.size *. scale in
  let _ = path Edge.([draw]) (0.0, 0.0)
      [[height, 0.0] ; [height, height] ; [0.0, height]; [0.0, 0.0]] in
  if checked then (
    ignore (path Edge.([draw]) (0.0, 0.0)
              [[height, height]]);
    ignore (path Edge.([draw]) (0.0, height)
              [[height, 0.0]])
  );
  [ Drawing (Fig.make ()) ]

let click f = Click (fun () -> record_write f ())

let _ = Diagrams.drag_hook := (fun f p r -> record_write (f p) r)

let checkBox ?(scale=0.75) data =
  button (click (fun () -> data.write (not (data.read ()))))
         (dynamic []
                  (fun () -> [bB (fun env -> drawCheckBox ~scale env (data.read ()))]))

let dataCheckBox ?(visibility=Private) ?(scale=0.75)
                 ?(init_value=false) ?(hook=fun _ -> ()) name =
  let data = db.create_data ~visibility bool_coding name init_value in
  hook data;
  checkBox ~scale data

module Env_checkBoxes(X:sig val arg1 : string val arg2 : bool data list ref end) =
  Enumerate(struct
             open X
             let _ = arg2 := []
             let from_counter x =
                 let name = arg1 ^ "_" ^ string_of_int (List.hd x) in
                 dataCheckBox ~hook:(fun d -> arg2 := d::!arg2) name @
                   [bB (fun env->let w=env.size/.phi in [glue w w w])]
           end)

(*===========================================================================*)
(*                      Radio buttons                                        *)
(*===========================================================================*)

let drawRadio ?(scale=0.5) env checked =
  let open Diagrams in
  let module Fig = MakeDiagram (struct let env = env end) in
  let open Fig in
  let height = env.size *. scale in
  let height2 = height /. 2. in
  let _ = Node.(node [ draw; circle; outerSep height2; innerSep height2
                     ; at (height2, height2)] []) in
  if checked then (
    ignore (Node.(node [ draw; fill black; circle; innerSep (height2 *. 0.66)
                       ; at (height2, height2)] []))
  );
  [ Drawing (Fig.make ()) ]


let radioButton ?(scale=0.5) data value =
  button (click(fun () -> data.write value))
         (dynamic []
                  (fun () ->
                    [bB (fun env -> drawRadio ~scale env (value = data.read ()))]))

let radioButtons ?(scale=0.5) data values =
  Array.map (fun value ->  radioButton ~scale data value) values

let dataRadioButtons ?(visibility=Private) ?(scale=0.5) name values =
  let data = db.create_data ~visibility default_coding name values.(0) in
  radioButtons ~scale data values

module Env_radioButtons(X:sig val arg1 : int data end) =
  Enumerate(struct
             open X
             let from_counter x =
               radioButton arg1 (List.hd x) @
                 [bB (fun env->let w=env.size/.phi in [glue w w w])]
           end)

module MkRadioButtons(X:sig type t val data : t data end) =
  struct
    open X
    let values = ref []
    module Enum =
      Enumerate(struct
                 let from_counter x =
                   let x = List.nth (List.rev !values) (List.hd x) in
                   radioButton data x @
                     [bB (fun env->let w=env.size/.phi in [glue w w w])]
               end)
    let do_begin_env = Enum.do_begin_env
    let do_end_env = Enum.do_end_env
    module Item(X:sig val arg1 : t end) = struct
      let _ = values := X.arg1 :: !values
      include Enum.Item
    end
  end

(*===========================================================================*)
(*                      Menu                                                 *)
(*===========================================================================*)

let menuCache = Hashtbl.create 101

let indexedMenus ?visibility:(_=Private) items0 values datas index  =
  if items0 = [] then failwith "Invalid menu";
  [C (fun env ->
       let key = datas.name ^ string_of_int index in
       let items, bname =
         try Hashtbl.find menuCache key
         with Not_found ->
           let items = List.mapi (fun i c ->
                           let act = record_write (fun () ->
                                         !values.(index) <- i;
                                         datas.write !values) in
                           (act, draw env c)) items0 in
           let res = (items, button_name ()) in
           Hashtbl.add menuCache key res; res
       in
       let b : content list = List.nth items0 !values.(index) in
       let btype = Menu(items) in
       bB (fun _ -> [Marker (BeginLink (Button(btype, bname)))])::
         b @ bB (fun _ -> [Marker EndLink]) :: [])]

let menu ?visibility:(_=Private) items0 data =
  if items0 = [] then failwith "Invalid menu";
  [C (fun env ->
       let items, bname =
         try Hashtbl.find menuCache data.name
         with Not_found ->
           let items = List.mapi (fun i c ->
                           let act = record_write (fun () -> data.write i) in
                           (act, draw env c)) items0 in
           let res = (items, button_name ()) in
           Hashtbl.add menuCache data.name res; res
       in
       let b : content list = List.nth items0 (data.read ()) in
       let btype = Menu(items) in
       bB (fun _ -> [Marker (BeginLink (Button(btype, bname)))])::
         b @ bB (fun _ -> [Marker EndLink]) :: [])]


let dataMenu ?(visibility=Private) items name =
  let data = db.create_data ~visibility default_coding name 0 in
  menu ~visibility items data

let mathIndexedMenus ?visibility:(_=Private) items0 values datas index =
  if items0 = [] then failwith "Invalid menu";
  [Maths.Ordinary (Maths.node (fun env _ ->
       let key = datas.name ^ string_of_int index in
       let items, bname =
         try Hashtbl.find menuCache key
         with Not_found ->
           let items = List.mapi (fun i c ->
                           let act = record_write (fun () ->
                                         !values.(index) <- i;
                                         datas.write !values) in
                           (act, draw env << $ \c $ >>)) items0 in
           let res = (items, button_name ()) in
           Hashtbl.add menuCache key res; res
       in
       let btype = Menu(items) in
       boxify_scoped env
         [C (fun _ -> env_accessed := true;
                        let b = List.nth items0 !values.(index) in
                        bB (fun _ -> [Marker (BeginLink (Button(btype, bname)))])::
                          << $ \b$ >> @ bB (fun _ -> [Marker EndLink]) :: [])]))]


let mathMenu ?visibility:(_=Private) (items0: Maths.math list list) data =
  if items0 = [] then failwith "Invalid menu";
  [Maths.Ordinary (Maths.node (fun env _ ->
     let items, bname =
       try Hashtbl.find menuCache data.name
       with Not_found ->
         let items = List.mapi (fun i c ->
                         let act = record_write (fun () ->
                                       data.write i) in
                         (act, draw env << $ \c $ >>)) items0 in
         let res = (items, button_name ()) in
         Hashtbl.add menuCache data.name res; res
     in
     let btype = Menu(items) in
     boxify_scoped env
       [C (fun _ -> env_accessed := true;
            let b = List.nth items0 (data.read ()) in
            bB (fun _ -> [Marker (BeginLink (Button(btype, bname)))])::
               << $ \b$ >> @ bB (fun _ -> [Marker EndLink]) :: [])]))]


(*===========================================================================*)
(*                      Editable text                                        *)
(*===========================================================================*)

(* read a file splitted in two or three parts, in which you usualy
   write programming exercises *)
let read_splited_file filename =
  let str = read_file filename in
  match Str.(split (regexp "[ \t]*#==========[^\n]*") str) with
  | [init; test]            -> init, test
  | [init; _solution; test] -> init, test
  | _                       -> invalid_arg "read_splited_file"

let ascii =
  let str = Bytes.make (2*(128-32)) ' ' in
  for i = 32 to 127 do
    Bytes.set str (2*(i-32)) (Char.chr i)
  done;
  let str = Bytes.to_string str in
  [Scoped(verbEnv, [tT str] @ bold [tT str])]

let strip_empty lines =
  let is_empty s =
    try
      for i = 0 to String.length s - 1 do
        if not (List.mem s.[i] [' ';'\t';'\n';'\r']) then raise Exit
      done;
      true
    with Exit -> false
  in
  let rec fn = function
    | s::l when is_empty s -> fn l
    | l -> l
  in
  List.rev (fn (List.rev (fn lines)))

let mk_length lines nb =
  match nb with
  | None -> [lines]
  | Some nb ->
    let nb0 = if nb <= 0 then List.length lines + nb else nb in
    let rec fn (acc:string list) (accs: string list list) lines nb =
      match nb,lines with
      | 0, [] -> List.rev (List.rev acc::accs)
      | 0, lines -> fn [] (List.rev acc::accs) lines nb0
      | n, [] -> fn (""::acc) accs [] (n-1)
      | n, l::lines -> fn (l::acc) accs lines (n-1)
    in
    fn [] [] (strip_empty lines) nb0

let interEnv x =
    { (envFamily x.fontMonoFamily x)
      with size = x.size *. x.fontMonoRatio; normalMeasure=infinity; par_indent = [];
        lead = x.lead *. x.fontMonoRatio *. 0.75;
        normalLead = x.normalLead *. x.fontMonoRatio *. 0.75;
        normalLeftMargin = 0.2;}

type eval_fun = string option -> (result -> unit) -> string -> string

let editableText ?(log=true) ?(visibility=Private) ?empty_case:(_="Type in here")
      ?nb_lines ?err_lines ?(init_text="") ?(lang=lang_Default) ?(lang_result=lang_Default)
      ?(extra:eval_fun option) ?resultData ?data ?filename ?influence:(_=[]) name =

    let data =
      match data with
        None -> db.create_data ~log ~visibility string_coding name init_text
      | Some d -> d
    in
    (match filename with
      Some name ->
        Printf.eprintf "recording filename: %S\n%!" name;
        Hashtbl.add file_table name data
    | None -> ());

    let dataR =
      match resultData with
        None -> db.create_data ~visibility result_coding (name^"_results") NotTried
      | Some d -> d
    in

    let init_res = match extra with
        None -> ""
      | Some f ->  f filename (fun _ -> ()) init_text
    in

    let dataO = db.create_data ~visibility string_coding (name^"_ouput") init_res in

    let eval t =
      match extra with
        None -> Private
      | Some f ->
        let writeR = if t <> init_text then
            dataR.write
          else
            fun _ -> dataR.write NotTried
        in
        let res = f filename writeR t in
        dataO.write res;
        Private
    in

    let update () =
      let s = data.read() in
      let s' = if s = init_text then init_text else s in
      s, String.split_on_char '\n' s'
    in

    let _, lines = update () in
    let pieces = mk_length lines nb_lines in
    let mk_states pieces f =
      match pieces with
      | [] | [_] -> f 0 []
      | _ -> altStates (List.mapi (fun i _ -> [i], f i [i] ) pieces)
    in

    mk_states pieces (fun index _states -> dynamic ascii
      (fun () ->
        let s, lines = update () in
        (button (Edit(s, init_text, fun t ->
                                    record_write (fun () ->
                                             data.write t;
                                             eval t) ()))
           [bB(fun env ->
             let env = interEnv env in
             List.map (fun x-> Drawing (snd x))
               (IntMap.bindings
                  (let d,_,_ = OutputDrawing.minipage' env
                     (let i = ref (match nb_lines with None -> 0 | Some n -> n * index)  in
                      let next () =
                        incr i;
                         let line = string_of_int !i in
                        let miss = 3 - String.length line in
                        [glue_space miss;tT line;glue_space 1]
                      in
                      let codeLines = try List.nth (mk_length lines nb_lines) index with _ ->
                        let rec fn acc = function 0 -> acc | n -> fn (""::acc) (n-1) in
                        fn [] (match nb_lines with None -> 1 | Some n -> n)
                      in
                      let acc = List.fold_left (fun acc line ->
                        let para=Paragraph
                          {par_contents=next () @ line;
                           par_env=(fun e -> e);
                           par_post_env=(fun env1 env2 ->
                             { env1 with names=names env2; counters=env2.counters; user_positions=user_positions env2 });
                            par_parameters=ragged_left;
                           par_badness=badness;
                           par_completeLine=Complete.normal; par_states=[]; par_paragraph=(-1) }
                        in up (newChildAfter acc para)) (Node empty, []) (lang codeLines)
                      in
                      let resultLines = match extra with None -> []
                        | Some _ ->
                          let str = dataO.read () in
                          List.nth (mk_length (String.split_on_char '\n' str) err_lines) 0
                      in
                             (List.fold_left (fun acc line ->
                        let para=Paragraph
                          {par_contents= arrow @ line ;
                           par_env=(fun env -> {env with
                             normalLead = env.normalLead *. 0.8;
                             lead = env.lead *. 0.9;
                             size = env.size *. 0.9});
                           par_post_env=(fun env1 env2 ->
                             { env1 with names=names env2; counters=env2.counters; user_positions=user_positions env2 });
                           par_parameters=ragged_left;
                           par_badness=badness;
                           par_completeLine=Complete.normal; par_states=[]; par_paragraph=(-1) }
                        in up (newChildAfter acc para)) (top acc) (lang_result resultLines))) in d)))])))

let ocaml_dir () =
  let sessid = match !Patodb.sessid with
    None -> "unknown"
  | Some(s,_,_) -> s
  in
  (* FIXME: use a subfolder per group ? *)
  let name = Filename.concat base_dir sessid in
  if not (Sys.file_exists  name) then
    Unix.mkdir name 0o755;
  name

let do_dep filename =
  try
    let dir = ocaml_dir () in
    Printf.eprintf "write dep:%S\n%!" (Filename.concat dir filename);
    let data = Hashtbl.find file_table filename in
    Printf.eprintf "dep found:%S\n%!" (Filename.concat dir filename);
    let prg = data.Patodb.read () in
    let ch = open_out (Filename.concat dir filename) in
    output_string ch prg;
    close_out ch
  with
    Not_found ->
      Printf.eprintf "Missing dependencies %S\n" filename

let test_ocaml ?(run=true) ?(deps=[]) ?preprocessor ?(prefix="") ?(suffix="") filename writeR prg =
  List.iter do_dep deps;
  let dir, filename, target, exec, run, delete_all =
    match filename with
      None ->
        let prefix = Filename.temp_file "demo" "" in
        Sys.remove prefix;
        Unix.mkdir prefix 0o700;
        prefix, "tmp.ml", "tmp.cmo", "tmp.byte", run, true
    | Some name ->
        let prefix = Filename.chop_extension name in
        if Filename.check_suffix name ".ml" then
          ocaml_dir (), name,
          prefix^".cmo",
          prefix ^ ".byte", run, false
        else
          ocaml_dir (), name,
          prefix^".cmi",
          "", false, false
  in
  let ch = open_out (Filename.concat dir filename) in
  output_string ch prefix;
  output_string ch "\n;;\n";
  output_string ch (Printf.sprintf "# 1 \"%s\"\n" (if delete_all then "" else filename));
  output_string ch prg;
  output_string ch "\n;;\n";
  output_string ch suffix;
  close_out ch;
  let tmpfile2 = Filename.temp_file "demo" ".txt" in
  let tmpfile3 = Filename.temp_file "demo" ".txt" in
  let prepro = match preprocessor with
      None -> ""
    | Some s -> "-pp "^s
  in
  let cmd = Printf.sprintf "cd %s; ocamlbuild -quiet %s %s >%s" dir prepro target tmpfile3 in
  Printf.eprintf "running: %s\n%!" cmd;
  let _ = Sys.command cmd in
  let err = read_file tmpfile3 in
  let err =
    try
      let n = 9 + Str.search_forward (Str.regexp_string "File \"\",") err 0 in
      String.sub err n (String.length err - n)
    with Not_found -> try
      let n = Str.search_forward (Str.regexp "File \"[^\"]*\",") err 0 in
      String.sub err n (String.length err - n)
    with Not_found -> err
  in
  let err, out =
    if err <> "" || not run then (
      if err <> "" then writeR DoNotCompile else if not run then writeR Ok;
      err, "" ) else (
    let cmd = Printf.sprintf "cd %s; ocamlbuild -quiet %s" dir exec in
    let _ = Sys.command cmd in
    (*    Printf.eprintf "running: %s\n%!" cmd;*)
    let cmd = Printf.sprintf "cd %s; ulimit -t 5; ./%s 2>%s >%s" dir exec tmpfile3 tmpfile2 in
    (*    Printf.eprintf "running: %s\n%!" cmd;*)
    let _ = Sys.command cmd in
    let err = read_file tmpfile3 in
    if err <> "" then writeR FailTest else writeR Ok;
    let out = read_file tmpfile2 in
    err,out)
  in
  (try Sys.remove tmpfile2 with _ -> ());
  (try Sys.remove tmpfile3 with _ -> ());
  if delete_all then (
    let _ = Sys.command (Printf.sprintf "cd %s; ocamlbuild -clean -quiet" dir) in
    if run then (try Sys.remove (Filename.concat dir exec) with _ -> ());
    (try Sys.remove (Filename.concat dir target) with _ -> ());
    (try Sys.remove (Filename.concat dir filename) with _ -> ());
    (try Unix.rmdir dir with _ -> ());
  );
  if err <> "" then err else
  if out <> "" then out else "No error and no output"

let test_python ?run:(_=true) ?deps:(_=[]) ?preprocessor:_ ?(prefix="") ?(suffix="") filename writeR prg =
  let namePrefix = match filename with
    | None -> "demo"
    | Some fname -> Filename.chop_extension fname
  in
  let tmpfile = Filename.temp_file namePrefix ".py" in
  let ch = open_out tmpfile in
  output_string ch prefix;
  output_string ch "\n\n";
  output_string ch "# 1 \"\"\n";
  output_string ch prg;
  output_string ch "\n\n";
  output_string ch suffix;
  close_out ch;
  let tmpfile2 = Filename.temp_file "demo" ".txt" in
  let tmpfile3 = Filename.temp_file "demo" ".txt" in
  let res_code = Sys.command (Printf.sprintf "python3 %s 2>%s >%s" tmpfile tmpfile3 tmpfile2) in
  let err = read_file tmpfile3 in
  let out = read_file tmpfile2 in
(*  (try Sys.remove tmpfile with _ -> ());
  (try Sys.remove tmpfile2 with _ -> ());
  (try Sys.remove tmpfile3 with _ -> ());*)
  if res_code = 1 then (writeR DoNotCompile; err) else
  if err <> "" then (writeR FailTest; err) else
  (writeR Ok; if out <> "" then out else "No error and no output")

let score ?group data sample display _exo =
  dynamic sample (fun () ->
    let total, scores = data.distribution ?group:(match group with None -> None | Some g -> Some (g ())) () in
    let total = max 1 total in
    let scores = List.filter (fun (x,_) -> x <> NotTried) scores in
    let total' = List.fold_left (fun acc (_,n) -> acc + n) 0 scores in
    let scores = (NotTried,total - total') :: scores in

    display scores)

(* to force some glyphs to be present,
   usefull with dynamics contents *)


let editable_math ?(visibility=Private) ?test ?(sample=[]) name init =
  let data = db.create_data ~visibility string_coding name init in
  let update () =
    let s = data.read() in
    let s = if s = init then init else s in
    s, Giac.gmath (Giac.parse_string s)
  in
  let test = match test with
    | None -> None
    | Some (good,rd) -> Some (Giac.parse_string good, rd)
  in

  let eval = match test with
    | None -> fun _ -> ()
    | Some (good, d) -> fun t ->
       if t = init then d.write NotTried else
         try
           let open Giac in
           let res = eval (App(Symbol("simplify"),[Sum(good,Opp(parse_string t))])) in
           Printf.eprintf "RESULT: %a => %a" Giac.print (Giac.Eq(good,Giac.parse_string t))
                          Giac.print res;
           if res = Giac.zero res
           then d.write Ok
           else d.write FailTest
         with _ -> d.write DoNotCompile
  in

  let correct () =
    match test with
    | None -> true
    | Some (_,d) -> d.read () = Ok
  in

  let gsample = match test with None -> [] | Some (g,_) -> Giac.gmath g in
  let open Maths in
  let default = <$123456 + 7 * 8 - 90 \times {\int}
                  \partial (abcdefghijklmnopqrstuvwxyz) [ABCDEFGHIJKLMNOPQRSTUVWXYZ]
                  a b c d e f g h i j k l m n o p q r s t u v w x y z
                  A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
                  X^{2^2}
                $> in
  let caml x = x in
  let sample = << $ \caml(Giac.gmath (Giac.parse_string init) @ gsample @ sample @ default) $ >> in
  [Maths.Ordinary (Maths.node (fun env _ ->
    boxify_scoped env
      (dynamic sample (fun () ->
                 let s, m = update () in
                 (button (Edit(s, init, fun t ->
                                        record_write (fun () ->
                                            data.write t; eval t) ()))
                         (if correct () then << $\m$ >>
                          else << $\mcolor(Color.red){\m} $ >> ))))))]

end
