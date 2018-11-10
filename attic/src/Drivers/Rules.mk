# Standard things which help keeping track of the current directory
# while include all Rules.mk.
d := $(if $(d),$(d)/,)$(mod)

DRIVERS_INCLUDES:=-I $(d) $(PACK_DRIVERS)

$(d)/%.cmo $(d)/%.cmi $(d)/%.cmx $(d)/%/%.cmo $(d)/%/%.cmi $(d)/%/%.cmx: INCLUDES += $(DRIVERS_INCLUDES)

DRIVERS_CMXA:=$(foreach drv,$(DRIVERS),src/Drivers/$(drv)/$(drv).cmxa)
DRIVERS_CMA:=$(foreach drv,$(DRIVERS),src/Drivers/$(drv)/$(drv).cma)
LIB_DRIVERS_A:=$(wildcard $(d)/*/lib*.a)
DRIVERS_CMX:=$(DRIVERS_CMXA:.cmxa=.cmx)
DRIVERS_CMXS:=$(DRIVERS_CMXA:.cmxa=.cmxs)

# Find dependencies
ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),distclean)
-include $(DRIVERS_CMXA:.cmxa=.ml.depends)
endif
endif

# Building stuff
all: $(DRIVERS_CMA) $(DRIVERS_CMXA) $(DRIVERS_CMXS)

# Find who has a Rules.mk, in which case we won't apply the generic
# %.cmxa: %.cmx rule from this file.
DRIVERS_WITH_RULES_MK := $(foreach drv,$(patsubst %/Rules.mk,%,$(wildcard $(d)/*/Rules.mk)),$(drv)/$(notdir $(drv)).cmxa)
DRIVERS_WITHOUT_RULES_MK := $(filter-out $(DRIVERS_WITH_RULES_MK),$(DRIVERS_CMXA))

$(DRIVERS_WITHOUT_RULES_MK:.cmxa=.cmo): %.cmo: %.ml
	$(ECHO) "[BYT] $@"
	$(Q)$(OCAMLC) $(OFLAGS) $(PACK_DRIVER_$(patsubst %.ml,%,$(notdir $(<)))) -I $(dir $(<)) $(INCLUDES) -o $@ -c $<

$(DRIVERS_WITHOUT_RULES_MK:.cmxa=.cmx): %.cmx: %.ml %.cmo
	$(ECHO) "[OPT] $@"
	$(Q)$(OCAMLOPT) $(OFLAGS) $(PACK_DRIVER_$(patsubst %.ml,%,$(notdir $(<)))) -I $(dir $(<)) $(INCLUDES) -o $@ -c $<

$(DRIVERS_WITHOUT_RULES_MK:.cmxa=.cma): %.cma: %.cmo
	$(ECHO) "[LNK] $@"
	$(Q)$(OCAMLC) $(PACK_DRIVER_$(patsubst %.cmo,%,$(notdir $(<)))) $(INCLUDES) -I $(dir $(<)) -a -o $@ $<

$(DRIVERS_WITHOUT_RULES_MK): %.cmxa: %.cmx
	$(ECHO) "[LNK] $@"
	$(Q)$(OCAMLOPT) $(PACK_DRIVER_$(patsubst %.cmx,%,$(notdir $(<)))) $(INCLUDES) -I $(dir $(<)) -a -o $@ $<

$(DRIVERS_WITHOUT_RULES_MK:.cmxa=.cmxs): %.cmxs: %.cmx
	$(ECHO) "[LNK] $@"
	$(Q)$(OCAMLOPT) $(PACK_DRIVER_$(patsubst %.cmx,%,$(notdir $(<)))) $(INCLUDES) -shared -o $@ $<

CLEAN+=$(DRIVERS_CMXA) $(DRIVERS_CMX) \
       $(d)/*.cmo $(d)/*.cmi $(d)/*.o $(d)/*.cmx $(d)/*.a $(d)/*.so $(d)/*.cmxa \
       $(d)/*/*.cmo $(d)/*/*.cmi $(d)/*/*.o $(d)/*/*.cmx $(d)/*/*.a $(d)/*/*.so \
			 $(d)/*/*.cmxs $(d)/*/*.cma $(d)/*/*.cmxa
DISTCLEAN+=$(d)/*/*.depends $(d)/*/*.META

# Installing drivers
install: install-drivers
.PHONY: install-drivers

# install-drivers depends on install-typography, since we first must wait
# for $(DESTDIR)/$(INSTALL_TYPOGRAPHY_DIR) directory to be created
# before putting drivers in it.
install-drivers: install-typography $(DRIVERS_CMXA) \
	$(DRIVERS_CMXA:.cmxa=.a) $(DRIVERS_CMXA:.cmxa=.cmi) \
	$(DRIVERS_CMXA:.cmxa=.cmxs) $(DRIVERS_CMXA:.cmxa=.cmx)
	install -d -m 755 $(DESTDIR)/$(INSTALL_DRIVERS_DIR)
	install -p -m 644 $(DRIVERS_CMXA) $(DRIVERS_CMXA:.cmxa=.a) \
		                $(LIB_DRIVERS_A) $(DRIVERS_CMXA:.cmxa=.cmi) \
		                $(DRIVERS_CMXA:.cmxa=.cmx) $(DRIVERS_CMXA:.cmxa=.cmxs) \
										$(DESTDIR)/$(INSTALL_DRIVERS_DIR)

# Visit subdirectories
$(foreach mod,$(DRIVERS),$(eval -include $(d)/$$(mod)/Rules.mk))

# Rolling back changes made at the top
d := $(patsubst %/,%,$(dir $(d)))
