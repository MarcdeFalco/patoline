# Standard things which help keeping track of the current directory
# while include all Rules.mk.
d := $(if $(d),$(d)/,)$(mod)

CESURE_INCLUDES := -I $(d) $(PACK_CESURE)

$(d)/%.ml.depends $(d)/%.ml.depends: OCPP=pa_ocaml
$(d)/%.cmo $(d)/%.cmi $(d)/%.cmx $(d)/%.cma $(d)/%.cmxa $(d)/cesure: INCLUDES:=$(CESURE_INCLUDES)
$(d)/%.cmo $(d)/%.cmi $(d)/%.cmx: OCPP=pa_ocaml

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),distclean)
-include $(d)/cesure.ml.depends $(d)/hyphen.ml.depends
endif
endif

all: $(d)/cesure $(d)/cesure.cmxa $(d)/cesure.cma

$(d)/cesure.cma: $(d)/hyphen.cmo $(UNICODE_DIR)/unicodelib.cma
	$(ECHO) "[LNK] $@"
	$(Q)$(OCAMLC) $(OFLAGS) $(CESURE_INCLUDES) -a -o $@ \
		earley_core.cma earley_str.cma $<

$(d)/cesure.cmxa: $(d)/hyphen.cmx $(UNICODE_DIR)/unicodelib.cmxa
	$(ECHO) "[LNK] $@"
	$(Q)$(OCAMLOPT) $(OFLAGS) $(CESURE_INCLUDES) -a -o $@ $<

$(d)/cesure: $(UNICODE_DIR)/unicodelib.cmxa $(d)/hyphen.cmx $(d)/cesure.cmx
	$(ECHO) "[NAT] $@"
	$(Q)$(OCAMLOPT) $(OFLAGS) $(CESURE_INCLUDES) -o $@ \
		unix.cmxa str.cmxa sqlite3.cmxa earley_core.cmxa earley_str.cmxa $^

CLEAN += $(d)/*.cmx $(d)/*.o $(d)/*.cmi $(d)/*.cmo $(d)/*.a $(d)/*.cma $(d)/*.cmxa
DISTCLEAN += $(d)/*.depends $(d)/cesure

# Installing
install: install-cesure-bin install-cesure-lib
.PHONY: install-cesure-bin
install-cesure-bin: install-bindir $(d)/cesure
	install -m 755 $(wordlist 2,$(words $^),$^) $(DESTDIR)/$(INSTALL_BIN_DIR)

.PHONY: install-cesure-lib
install-cesure-lib: $(d)/cesure.cma $(d)/cesure.cmxa $(d)/META $(d)/cesure.o $(d)/cesure.a $(d)/hyphen.cmi $(d)/hyphen.cmx $(d)/hyphen.cmo
	install -m 755 -d $(DESTDIR)/$(INSTALL_CESURE_DIR)
	install -m 644 -p $^ $(DESTDIR)/$(INSTALL_CESURE_DIR)

# Rolling back changes made at the top
d := $(patsubst %/,%,$(dir $(d)))
