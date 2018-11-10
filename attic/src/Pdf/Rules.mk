# Standard things which help keeping track of the current directory
# while include all Rules.mk.
d := $(if $(d),$(d)/,)$(mod)

# Compute ML files dependencies
SRC_$(d):=$(wildcard $(d)/*.ml) $(d)/obj_parser.ml $(d)/obj_lexer.ml $(d)/obj_parser.mli

$(d)/obj_lexer.ml.depends: $(d)/obj_lexer.ml $(d)/obj_parser.ml.depends $(d)/pdf_parser.ml.depends
$(d)/obj_parser.ml.depends: $(d)/obj_parser.ml
$(d)/pdf_parser.ml.depends: $(d)/pdf_parser.ml
$(d)/%.cmx $(d)/%.cmo: INCLUDES:=-I $(d) -package $(CAMLZIP),rawlib,bytes

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),distclean)
-include $(addsuffix .depends,$(SRC_$(d)))
endif
endif

# Building stuff
all: $(d)/pdf_parser.cmxa $(d)/pdf_parser.a

PDF_PARSER_SOURCES := $(d)/pdfutil.ml $(d)/obj_lexer.ml $(d)/obj_parser.ml $(d)/pdf_parser.ml

$(d)/pdf_parser.a: $(d)/pdf_parser.cmxa ;
$(d)/pdf_parser.cmxa: $(PDF_PARSER_SOURCES:.ml=.cmx) $(RAWLIB_DIR)/rawlib.cmxa
	$(ECHO) "[LNK] $@"
	$(Q)$(OCAMLOPT) -a -o $@ $(filter-out $(RAWLIB_DIR)/rawlib.cmxa,$^)

$(d)/pdf_parser.cma: $(PDF_PARSER_SOURCES:.ml=.cmo) $(RAWLIB_DIR)/rawlib.cma
	$(ECHO) "[LNK] $@"
	$(Q)$(OCAMLC) -a -o $@ $(filter-out $(RAWLIB_DIR)/rawlib.cma,$^)

# Installing
install: install-pdf
.PHONY: install-pdf
install-pdf: install-typography $(d)/pdf_parser.cmxa $(d)/pdf_parser.a $(d)/pdf_parser.cmi
	install -m 644 $(wordlist 2,$(words $^),$^) $(DESTDIR)/$(INSTALL_RAWLIB_DIR)

# Cleaning
CLEAN += $(d)/*.cmo $(d)/*.cmx $(d)/*.cmi \
	 $(d)/*.cmxa $(d)/*.cma \
	 $(d)/*.p.cmx $(d)/*.p.cmxa \
	 $(d)/*.o $(d)/*.a

DISTCLEAN += $(d)/*.depends $(d)/obj_parser.ml $(d)/obj_parser.mli $(d)/obj_lexer.ml


# Rolling back changes made at the top
d := $(patsubst %/,%,$(dir $(d)))
