# Standard things which help keeping track of the current directory
# while include all Rules.mk.
d := $(if $(d),$(d)/,)$(mod)

GL_DRIVER_INCLUDES:=-I $(d) $(PACK_DRIVER_DriverGL)

$(d)/%.cmo $(d)/%.cmi $(d)/%.cmx $(d)/%.cma $(d)/%.cmxa $(d)/%.cmxs: INCLUDES += $(GL_DRIVER_INCLUDES)
$(d)/%.cmo $(d)/%.cmi $(d)/%.cmx $(d)/%.cma $(d)/%.cmxa $(d)/%.cmxs: OFLAGS += -thread

SRC_$(d):=$(wildcard $(d)/*.ml)
DEPENDS_$(d) := $(addsuffix .depends,$(SRC_$(d)))
ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),distclean)
-include $(DEPENDS_$(d))
endif
endif

$(d)/%.cmo $(d)/%.cmi $(d)/%.cmx: INCLUDES += $(GL_DRIVER_INCLUDES)

DRIVERGL_MODS:= GlFBO Vec3 DriverGL

DRIVERGL_ML:=$(addsuffix .ml,$(addprefix $(d)/,$(DRIVERGL_MODS)))
DRIVERGL_CMO:=$(DRIVERGL_ML:.ml=.cmo)
DRIVERGL_CMX:=$(DRIVERGL_ML:.ml=.cmx)

UNAME := $(shell uname)
ifeq ($(UNAME), Linux)
FPIC_FLAGS=-fPIC
endif
ifeq ($(UNAME), Darwin)
FPIC_FLAGS=-I$(shell ocamlc -where) -fPIC # -framework GLUT -framework OpenGL
endif

$(d)/FrameBuffer.o: $(d)/FrameBuffer.c
	$(ECHO) "[GCC] $@"
	$(Q)$(CC) $(FPIC_FLAGS) $(CFLAGS) -c $< -o $@

DRIVERGL_DIR:= $(d)

$(d)/DriverGL.cma: $(d)/FrameBuffer.o $(d)/GlFBO.cmo $(d)/Vec3.cmo $(d)/DriverGL.cmo
	$(ECHO) "[LNK] $@"
	$(Q)$(OCAMLMKLIB) $(INCLUDES) -dllpath $(INSTALL_DLLS_DIR) -o $(basename $@) $^

$(d)/DriverGL.cmxa: $(d)/FrameBuffer.o $(d)/GlFBO.cmx $(d)/Vec3.cmx $(d)/DriverGL.cmx
	$(ECHO) "[LNK] $@"
	$(Q)$(OCAMLMKLIB) $(INCLUDES) -dllpath $(INSTALL_DLLS_DIR) -o $(basename $@) $^

$(d)/DriverGL.cmxs: $(d)/FrameBuffer.o $(d)/GlFBO.cmx $(d)/Vec3.cmx $(d)/DriverGL.cmx $(TYPOGRAPHY_DIR)/DefaultFormat.cmxa $(CESURE_DIR)/cesure.cmxa $(LIBFONTS_DIR)/fonts.cmxa $(UNICODE_DIR)/unicodelib.cmxa
	$(ECHO) "[LNK] $@"
	$(Q)$(OCAMLOPT) $(INCLUDES) -shared -linkpkg -o $@ $(DRIVERGL_DIR)/FrameBuffer.o $(DRIVERGL_DIR)/GlFBO.cmx $(DRIVERGL_DIR)/Vec3.cmx $(DRIVERGL_DIR)/DriverGL.cmx


CLEAN += $(d)/DriverGL.cma

DISTCLEAN += $(DEPENDS_$(d))

install:install-dll-gl
install-dll-gl:
	install -m 755 src/Drivers/DriverGL/dllDriverGL.so $(DESTDIR)/$(INSTALL_DLLS_DIR)

# Rolling back changes made at the top
d := $(patsubst %/,%,$(dir $(d)))
