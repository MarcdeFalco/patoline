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
open Patutil
open Patfonts
open Document
open Box
open FTypes
open Extra
open RawContent

type page={mutable pageContents:raw list}

let output ?state paragraphs figures env (opt_pages:frame)=

  let positions=Array.make (Array.length paragraphs) (0,0.,0.) in

  let par=ref (-1) in
  let crosslinks=ref [] in (* (page, link, destination) *)
  let crosslink_opened=ref false in
  let destinations=ref [] in
  let urilinks=ref None in
  let continued_link=ref None in
  let draw_page i p=
    let y0=ref infinity in
    let y1=ref (-.infinity) in
    let x0=ref infinity in
    let x1=ref (-.infinity) in
    let top_y=ref (-.infinity) in

    let page={ pageContents=[] } in
    let footnotes=ref [] in
    let footnote_y=ref (-.infinity) in
    let pp=Array.of_list
      (List.fold_left (fun m x->match x with Placed_line p->p::m|_->m) [] p)
    in
    let states=ref [] in

    let endlink cont=
      continued_link:=None;
      if !crosslink_opened then (
        let rec link_contents u l=match l with
            []->[]
          | (Link h)::s->(
            let u = List.rev u in
            if cont then continued_link:=Some (Link h);
            let x0,y0,x1,y1=bounding_box u in
            Link { h with
              link_x0=x0;link_y0=y0;
              link_x1=x1;link_y1=y1;
              link_closed=true;
              link_contents=u
            }
          )::s
          | h::s->link_contents (h::u) s
        in
        page.pageContents<-link_contents [] page.pageContents;
        crosslink_opened:=false;
      )
    in

    (match !continued_link with
        None->()
      | Some l->(
        page.pageContents<-l::page.pageContents;
        crosslink_opened:=true;
        continued_link:=None
      )
    );

              (* Affichage des frames (demouchage) *)
    let h=Hashtbl.create 100 in

    for j=0 to Array.length pp-1 do
      let param=pp.(j).line_params
      and line=pp.(j).line in

                (* Affichage des frames (demouchage) *)
      let rec draw_frames (t,cxt)=
        if cxt<>[] then (
          let r=(t.frame_x0,t.frame_y0,t.frame_x1,t.frame_y1) in
          if not (Hashtbl.mem h r) then (
            Hashtbl.add h r ();
            if classify_float t.frame_x0=FP_infinite ||
              classify_float t.frame_x0=FP_nan ||
              classify_float t.frame_y0=FP_infinite ||
              classify_float t.frame_y0=FP_nan ||
              classify_float t.frame_x1=FP_infinite ||
              classify_float t.frame_y1=FP_nan ||
              classify_float t.frame_y1=FP_infinite ||
              classify_float t.frame_y1=FP_nan
            then () else
              page.pageContents<-Path (default_path_param,[rectangle (t.frame_x0,t.frame_y0) (t.frame_x1,t.frame_y1)])::page.pageContents;
          );
          draw_frames (Box.frame_up (t,cxt))
        )
      in
      if env.show_frames then draw_frames line.layout;
                (* * *)


      if pp.(j).line.isFigure then (
        let fig=figures.(pp.(j).line.lastFigure) in
        let y=
          if j>0 && j<Array.length pp-1 then
            let milieu=
              (pp.(j-1).line.height+.fst (line_height paragraphs figures pp.(j-1).line)
               +.(pp.(j+1).line.height+.snd (line_height paragraphs figures pp.(j+1).line)))/.2.
            in
            milieu-.(fig.drawing_y1+.fig.drawing_y0)/.2.
          else
            pp.(j).line.height
        in
        y1:=max !y1 y;
        y0:=min !y0 (fig.drawing_y1+.fig.drawing_y0);
        if env.show_boxes then
          page.pageContents<- Path ({RawContent.default_path_param with close=true },
                                    [rectangle (param.left_margin,y+.fig.drawing_y0)
                                        (param.left_margin+.fig.drawing_nominal_width,
                                         y+.fig.drawing_y1)]) :: page.pageContents;
        page.pageContents<- (List.map (translate ((fst pp.(j).line.layout).frame_x0+.param.left_margin) y)
                               (fig.drawing_contents fig.drawing_nominal_width))
        @ page.pageContents;

      ) else if line.paragraph<Array.length paragraphs then (
        let y=line.height in
        let (yy0,yy1)=line_height paragraphs figures line in
        y1:=max (y+.yy1) !y1;
        y0:=min (y+.yy0) !y0;
        if line.paragraph<> !par then (
          par:=line.paragraph;
          positions.(!par)<-
            (i, 0., line.height +. phi*.yy1)
        );

        let comp=compression paragraphs param line in
        let rec draw_box x y box=
          top_y:=max !top_y y;
          let lowy=y+.lower_y box in
          let uppy=y+.upper_y box in
          (match !urilinks with
              None->()
            | Some h->(
              h.link_y0<-min h.link_y0 lowy;
              h.link_y1<-max h.link_y1 uppy
            ));
          if !crosslink_opened then
            (match !crosslinks with
                []->()
              | (_,h,_)::_->(
                h.link_y0<-min h.link_y0 lowy;
                h.link_y1<-max h.link_y1 uppy
              ));
          match box with
              Kerning kbox ->(
                let w=draw_box (x+.kbox.kern_x0) (y+.kbox.kern_y0) kbox.kern_contents in
                w+.kbox.advance_width
              )
            | Hyphen h->(
              (Array.fold_left (fun x' box->
                let w=draw_box (x+.x') y box in
                x'+.w) 0. h.hyphen_normal)
            )
            | GlyphBox a->(
              page.pageContents<-translate x y (Glyph a):: page.pageContents;
              a.glyph_size*.Fonts.glyphWidth a.glyph/.1000.
            )
            | Glue g
            | Drawing g ->(
              states:=List.sort_uniq compare (g.drawing_states@ !states);
              let w=g.drawing_min_width+.comp*.(g.drawing_max_width-.g.drawing_min_width) in
              let cont = g.drawing_contents w in
              let cont = List.filter (fun x->match x,state with
                  States s, Some st when s.states_states<>[] &&
                      not (List.mem st s.states_states) -> false
                | _->true
              ) cont in
              page.pageContents<- (List.map (translate x y) cont) @ page.pageContents;
              if env.show_boxes
                && classify_float g.drawing_y1<>FP_infinite
                && classify_float g.drawing_y0<>FP_infinite
              then
                page.pageContents<- Path ({RawContent.default_path_param with close = true }, [rectangle (x,y+.g.drawing_y0) (x+.w,y+.g.drawing_y1)]) :: page.pageContents;
              w
            )
            | Marker (BeginLink l)->(
              let k = match l with
                  Box.Extern l -> RawContent.Extern l
                | Box.Intern l -> RawContent.Intern(l,Box.layout_page line,0.,0.);
                | Box.Button(t,n) -> RawContent.Button(t,n)
              in
              let link={ link_x0=x;link_y0=y;link_x1=x;link_y1=y;link_kind=k;
                         link_order=0;
                         link_closed=false;
                         link_contents=[] }
              in
              crosslinks:=(i, link, l) :: !crosslinks;
              crosslink_opened:=true;
              page.pageContents<-Link link::page.pageContents;
              0.
            )
            | Marker EndLink->(
              endlink false;
              0.
            )
            | Marker (Label _) as m ->(
              destinations:=m :: !destinations;
              0.
            )
                      (* | User (Footnote (_,g))->( *)
                      (*   footnotes:= g::(!footnotes); *)
                      (*   footnote_y:=max !footnote_y (h-.topMargin-.param.page_height); *)
                      (*   0. *)
                      (* ) *)
            | b->box_width comp b
        in

                  (* Si un lien est commencé sur la ligne précédente,
                     le reprendre *)
        if !crosslink_opened then
          crosslinks:=(match !crosslinks with
              []->[]
            | (a,h,c)::s->
              (a, { h with
                link_x0=(fst line.layout).frame_x0+.param.left_margin;
                link_x1=(fst line.layout).frame_x0+.param.left_margin;
                link_y0=line.height;link_y1=line.height }, c)::(a,h,c)::s);

                  (* Écrire la page *)
        x0:=min !x0 param.left_margin;
        x1:=max !x1 (fold_left_line paragraphs (fun x b->x+.draw_box x y b)
                       param.left_margin line);

                  (* Fermer les liens, et préparer la continuation sur
                     la prochaine ligne. *)
        endlink true;
        (match !continued_link with
            None->()
          | Some l->(
            page.pageContents<-l::page.pageContents;
            crosslink_opened:=true;
            continued_link:=None
          )
        );
      )
    done;

    endlink true;

    (match !urilinks with
        None->()
      | Some h->page.pageContents<-Link h::page.pageContents; urilinks:=None);
    ignore (
      List.fold_left (
        fun y footnote->
          page.pageContents<- (List.map (translate (env.normalLeftMargin) (y-.footnote.drawing_y1-.env.footnote_y))
                                 (footnote.drawing_contents footnote.drawing_nominal_width)) @ page.pageContents;
          y-.(footnote.drawing_y1-.footnote.drawing_y0)
      ) !footnote_y !footnotes
    );
    if !footnotes<>[] then (
      page.pageContents<- (Path ({RawContent.default_path_param with lineWidth=0.01 }, [ [| [| env.normalLeftMargin;
                                                                                      env.normalLeftMargin+.env.normalMeasure*.(2.-.phi) |],
                                                                                 [| !footnote_y-.env.footnote_y;
                                                                                    !footnote_y-.env.footnote_y |] |] ]))::page.pageContents
    );


    if !top_y=(-.infinity) then top_y:=0.;

    { drawing_min_width= !x1;
      drawing_nominal_width= !x1;
      drawing_max_width= !x1;
      drawing_width_fixed = true;
      drawing_adjust_before = false;
      drawing_y0= !y0 -. !top_y;
      drawing_y1= (!y1-. !top_y);
      drawing_badness=(fun _->0.);
      drawing_states= !states;
      drawing_break_badness=0.;
      drawing_contents=(fun _-> List.map (translate 0. (-. !top_y)) page.pageContents) }
  in

  let res = IntMap.mapi (fun i a->draw_page i (all_contents a)) opt_pages.frame_children in

  res, !destinations


let minipage ?state ?(env_mod=fun e -> e) str=
  [bB (fun env->
    let env = env_mod env in
    let env',fig_params,params,new_page_list,new_line_list,compl,bads,pars,_,figures,_,states=flatten env (fst str) in
    let (_,pages,_,_) = TS.typeset
      ~completeLine:compl
      ~figure_parameters:fig_params
      ~figures:figures
      ~parameters:params
      ~new_page:new_page_list
      ~new_line:new_line_list
      ~badness:bads
      ~states
      pars
    in
    let d,ms = output ?state pars figures env' pages in
    let pages=IntMap.bindings d in
    List.map (fun (_,x)->Drawing x) pages @ ms
          (* List.map (fun x->let c=x.drawing_contents x.drawing_nominal_width in Drawing (drawing c)) (List.map snd pages) *)
  )]

let minipage' ?state env str=
  let env',fig_params,params,new_page_list,new_line_list,compl,bads,pars,_,figures,_,states=flatten env (fst str) in
  let (_,pages,_,_) = TS.typeset
    ~completeLine:compl
    ~figure_parameters:fig_params
    ~figures:figures
    ~parameters:params
    ~new_page:new_page_list
    ~new_line:new_line_list
    ~badness:bads
    ~states
    pars
  in
  let d,ms = output ?state pars figures env' pages in
  d,env',ms
