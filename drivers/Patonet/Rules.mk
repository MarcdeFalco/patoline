# Standard things which help keeping track of the current directory
# while include all Rules.mk.
d := $(if $(d),$(d)/,)$(mod)

PATONET_DRIVER_INCLUDES:= -I $(d) -I $(DRIVERS_DIR)/SVG $(PACK_DRIVER_Patonet)


SRC_$(d):=$(wildcard $(d)/*.ml)
DEPENDS_$(d) := $(addsuffix .depends,$(SRC_$(d)))

$(DEPENDS_$(d)) $(d)/%.cmo $(d)/%.cmi $(d)/%.cmx: INCLUDES += $(PATONET_DRIVER_INCLUDES)
ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),distclean)
-include $(DEPENDS_$(d))
endif
endif

$(d)/Patonet.cma: $(d)/Patonet.cmo
	$(ECHO) "[MKL] $@"
	$(Q)$(OCAMLC) $(INCLUDES) $(OFLAGS) -a -o $@ $^

$(d)/Patonet.cmxa: $(d)/Patonet.cmx
	$(ECHO) "[MKL] $@"
	$(Q)$(OCAMLOPT) $(INCLUDES) $(OFLAGS) -a -o $@ $^

$(d)/Patonet.cmxs: $(d)/Patonet.cmx
	$(ECHO) "[SHR] $@"
	$(Q)$(OCAMLOPT) $(INCLUDES) $(OFLAGS) -linkpkg -shared -o $@ $^


CLEAN +=

DISTCLEAN += $(DEPENDS_$(d))

# Rolling back changes made at the top
d := $(patsubst %/,%,$(dir $(d)))
