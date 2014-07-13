# Standard things which help keeping track of the current directory
# while include all Rules.mk.
d := $(if $(d),$(d)/,)$(mod)

IMGLIB_INCLUDES := -I $(d)

# Compute ML files dependencies
SRC_$(d) := $(wildcard $(d)/*.ml) $(wildcard $(d)/*.mli)

$(d)/%.depends: INCLUDES:=$(IMGLIB_INCLUDES)

-include $(addsuffix .depends,$(SRC_$(d)))

# Building
IMGLIB_MODS:= imageUtil image imagePPM imagePNG imageXCF imageJPG imageGIF readImg

IMGLIB_ML:=$(addsuffix .ml,$(addprefix $(d)/,$(IMGLIB_MODS)))

IMGLIB_CMO:=$(IMGLIB_ML:.ml=.cmo)
IMGLIB_CMX:=$(IMGLIB_ML:.ml=.cmx)
IMGLIB_CMI:=$(IMGLIB_ML:.ml=.cmi)

# We cannot run ocamlc and ocamlopt simultaneously on the same input,
# since they both overwrite the .cmi file, which can get corrupted.
# That's why we arbitrarily force the following dependency.
$(IMGLIB_CMX): %.cmx: %.cmo

$(d)/readImg.cmo: $(d)/readImg.ml
	$(ECHO) "[OCAMLC] $< -> $@"
	$(Q)$(OCAMLC) $(OFLAGS) $(PACK) $(IMGLIB_INCLUDES) -o $@ -c $<

$(d)/readImg.cmx: $(d)/readImg.ml
	$(ECHO) "[OPT]    $< -> $@"
	$(Q)$(OCAMLOPT) $(OFLAGS) $(PACK) $(IMGLIB_INCLUDES) -o $@ -c $<

$(d)/imagelib.cma: $(IMGLIB_CMO)
	$(ECHO) "[LINK]   ... -> $@"
	$(Q)$(OCAMLC) -a -o $@ $^

$(d)/imagelib.cmxa: $(IMGLIB_CMX)
	$(ECHO) "[LINK]   ... -> $@"
	$(Q)$(OCAMLOPT) -a -o $@ $^

$(d)/imagelib.cmxs: $(IMGLIB_CMX)
	$(ECHO) "[LINK]   ... -> $@"
	$(Q)$(OCAMLOPT) -shared -o $@ $^


# Building everything
all: $(d)/imagelib.cmxa $(d)/imagelib.cma $(d)/imagelib.cmxs

# Cleaning
CLEAN += $(d)/*.cma $(d)/*.cmxa $(d)/*.cmxs $(d)/*.cmo $(d)/*.cmx $(d)/*.cmi $(d)/*.o $(d)/*.a

DISTCLEAN += $(wildcard $(d)/*.depends) $(d)/META

# Installing
install: install-imglib
.PHONY: install-imglib
install-imglib: $(d)/imagelib.cma $(d)/imagelib.cmxa $(d)/imagelib.a $(d)/META $(IMGLIB_CMI) $(IMGLIB_CMX) $(IMGLIB_CMO)
	install -m 755 -d $(DESTDIR)/$(INSTALL_IMGLIB_DIR)
	install -m 644 -p $^ $(DESTDIR)/$(INSTALL_IMGLIB_DIR)

# Rolling back changes made at the top
d := $(patsubst %/,%,$(dir $(d)))
