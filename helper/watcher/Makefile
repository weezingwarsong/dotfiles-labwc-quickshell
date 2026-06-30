WS_PROTO_XML  = /usr/share/wayland-protocols/staging/ext-workspace/ext-workspace-v1.xml
WLR_PROTO_XML = /usr/share/wlr-protocols/unstable/wlr-foreign-toplevel-management-unstable-v1.xml

CFLAGS  = -O2 $(shell pkg-config --cflags wayland-client)
LDFLAGS = $(shell pkg-config --libs wayland-client)
SRCS    = main.c \
          ext-workspace-v1-client-protocol.c \
          wlr-foreign-toplevel-management-unstable-v1-client-protocol.c

qs-watcher: $(SRCS) ext-workspace-v1-client-protocol.h \
            wlr-foreign-toplevel-management-unstable-v1-client-protocol.h
	gcc $(CFLAGS) -o $@ $(SRCS) $(LDFLAGS)

ext-workspace-v1-client-protocol.h:
	wayland-scanner client-header $(WS_PROTO_XML) $@

ext-workspace-v1-client-protocol.c:
	wayland-scanner private-code   $(WS_PROTO_XML) $@

wlr-foreign-toplevel-management-unstable-v1-client-protocol.h:
	wayland-scanner client-header $(WLR_PROTO_XML) $@

wlr-foreign-toplevel-management-unstable-v1-client-protocol.c:
	wayland-scanner private-code   $(WLR_PROTO_XML) $@

clean:
	rm -f qs-watcher \
	      ext-workspace-v1-client-protocol.c \
	      ext-workspace-v1-client-protocol.h \
	      wlr-foreign-toplevel-management-unstable-v1-client-protocol.c \
	      wlr-foreign-toplevel-management-unstable-v1-client-protocol.h

.PHONY: clean
