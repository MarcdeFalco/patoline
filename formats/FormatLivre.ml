(*
  Copyright Florian Hatat, Tom Hirschowitz, Pierre Hyvernat,
  Pierre-Etienne Meunier, Christophe Raffalli, Guillaume Theyssier 2012.

  This file is part of Patoline.

  Patoline is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Patoline is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Patoline.  If not, see <http://www.gnu.org/licenses/>.
*)
open Typography
open Patfonts
open Patutil
open Patoraw
open Unicodelib
open Fonts
open FTypes
(* open Typography.Constants *)
open Typography.Document
open Box
(* open Binary *)
open Extra

let boxes_width env contents =
  let boxes = boxify_scoped env contents in
  let w = List.fold_left
    (fun w x -> let _,a,_ = Box.box_interval x in w +. a)
    0.
    boxes
  in
  boxes, w

let boxes_y0 boxes =
  List.fold_left
    (fun res box -> min res (Box.lower_y box))
    0.
    boxes

let boxes_y1 boxes =
  List.fold_left
    (fun res box -> max res (Box.upper_y box))
    0.
    boxes


module Euler=DefaultFormat.Euler

module MakeFormat (D:DocumentStructure)
  (Default : module type of DefaultFormat.Format(D)) = struct

  module Default = Default
  include Default

  let caml x = x
  let displayedFormula=Default.displayedFormula


module Env_definition=Default.Make_theorem
  (struct
    let refType="definition"
    let counter="definition"
    let counterLevel=0
    let display num=alternative Bold [tT ("Définition "^num^"."); (tT " ")]
   end)
module Env_theoreme=Default.Make_theorem
  (struct
    let refType="theoreme"
    let counter="theoreme"
    let counterLevel=0
    let display num=alternative Bold [tT ("Théorème "^num^"."); (tT " ")]
   end)
module Env_lemme=Default.Make_theorem
  (struct
    let refType="lemme"
    let counter="lemme"
    let counterLevel=0
    let display num=alternative Bold [tT ("Lemme "^num^"."); (tT " ")]
   end)
module Env_proposition=Default.Make_theorem
  (struct
    let refType="proposition"
    let counter="proposition"
    let counterLevel=0
    let display num=alternative Bold [tT ("Proposition "^num^"."); (tT " ")]
   end)
module Env_corollaire=Default.Make_theorem
  (struct
    let refType="corollaire"
    let counter="corollaire"
    let counterLevel=0
    let display num=alternative Bold [tT ("Corollaire "^num^"."); (tT " ")]
   end)
module Env_exemple=Default.Make_theorem
  (struct
    let refType="exemple"
    let counter="exemple"
    let counterLevel=0
    let display num=alternative Bold [tT ("Exemple "^num^"."); (tT " ")]
   end)
module Env_hypothese=Default.Make_theorem
  (struct
    let refType="hypothese"
    let counter="hypothese"
    let counterLevel=0
    let display num=alternative Bold [tT ("Hypothèse "^num^"."); (tT " ")]
   end)
module Env_remarque=Default.Make_theorem
  (struct
    let refType="remarque"
    let counter="remarque"
    let counterLevel=0
    let display num=alternative Bold [tT ("Remarque "^num^"."); (tT " ")]
   end)
module Env_exercice=Default.Make_theorem
  (struct
    let refType="exercice"
    let counter="exercice"
    let counterLevel=0
    let display num=alternative Bold [tT ("Exercice "^num^"."); (tT " ")]
   end)
    module Env_preuve = Env_gproof (struct
      let arg1 = italic [tT "Preuve.";bB (fun env->let w=env.size in [glue w w w])]
    end)

(* module Env_proof=Default.Proof *)

  let equation contents =
    let pars a b c d e f g line={(parameters a b c d e f g line) with
                              min_height_before=
        if line.lineStart=0 then a.lead else 0.;
                              min_height_after=
        if line.lineEnd>=Array.length b.(line.paragraph) then a.lead else 0.
                           }
    in
    D.structure := newPar ~environment:(fun env -> { env with par_indent = [] })
      !D.structure Complete.normal pars
      [ Env (fun env ->Document.incr_counter "equation" env) ;
        C (fun env ->
             let _,w = boxes_width env contents in
             let _,x = StrMap.find "equation" env.counters in
             let num,w' = boxes_width env
               (italic [tT "(";
                        tT (string_of_int (1 + List.hd x));
                        tT ")" ]) in
             let w0=(env.normalMeasure -. w)/.2. in
             let w1=env.normalMeasure -. w'-.w0-.w in
             bB(fun _->[glue w0 w0 w0])::
               contents@
               [bB (fun _->glue w1 w1 w1 :: num)]
          )];
    []

(* Default.Make_theorem *)
(*   (struct *)
(*     let refType="equation" *)
(*     let counter="equation" *)
(*     let counterLevel=0 *)
(*     let display num=toggleItalic [T ("("^num^")"); (T " ")] *)
(*    end) *)


  let utf8Char x=[tT (UTF8.init 1 (fun _->UChar.chr x))]
  let glyph x=
    bB (fun env->
         let code={glyph_utf8=""; glyph_index=x } in
           [Box.glyphCache env.font code env.fontColor env.size]
      )
  let q _=utf8Char 8220
  let qq _=utf8Char 8221

end

module Format (D : DocumentStructure) =
  MakeFormat (D) (DefaultFormat.Format(D))
