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

open Patoraw
open Driver

let driver_options = []
let filter_options argv = argv    

let output  ?structure:(_=empty_structure) _ _ = ()
let output' ?structure:(_=empty_structure) _ _ = ()

let _ =
  Hashtbl.add DynDriver.drivers "None"
    (module struct
       let output  = output
       let output' = output'
     end : OutputDriver)
