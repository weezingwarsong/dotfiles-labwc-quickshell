/*
 * qs-toplevel-watcher
 *
 * Listens to zwlr_foreign_toplevel_manager_v1 and ext_workspace_manager_v1.
 * On any state change, emits one JSON line to stdout:
 *
 *   {"ws1":["app_id: title",...],"ws2":[...],"active":"app_id: title"}
 *
 * Workspace assignment: when a toplevel fires output_enter, it is assigned to
 * the current workspace. output_leave keeps the last-known workspace. This
 * means workspace 2 windows only appear once the user has visited workspace 2.
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "ext-workspace-v1-client-protocol.h"
#include "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"

#define MAX_TOPLEVELS 256
#define MAX_WS 64

/* ---------- state --------------------------------------------------------- */

struct toplevel {
    struct zwlr_foreign_toplevel_handle_v1 *handle;
    char *app_id;
    char *title;
    int   workspace;   /* 1-based; 0 = not yet seen on any output */
    bool  on_output;   /* currently visible on an output */
    bool  activated;   /* has the activated state bit */
};

struct workspace {
    struct ext_workspace_handle_v1 *handle;
    char    *name;
    uint32_t state;
};

static struct toplevel  toplevels[MAX_TOPLEVELS];
static struct workspace workspaces[MAX_WS];
static int  current_workspace = 0;
static bool initialized = false;
static bool dirty = false;

/* ---------- helpers ------------------------------------------------------- */

static struct toplevel *tl_slot(struct zwlr_foreign_toplevel_handle_v1 *h) {
    for (int i = 0; i < MAX_TOPLEVELS; i++)
        if (!toplevels[i].handle) {
            toplevels[i].handle = h;
            return &toplevels[i];
        }
    return NULL;
}

static struct workspace *ws_slot(struct ext_workspace_handle_v1 *h) {
    for (int i = 0; i < MAX_WS; i++)
        if (!workspaces[i].handle) {
            workspaces[i].handle = h;
            return &workspaces[i];
        }
    return NULL;
}

/* Emit a JSON-escaped string (including surrounding quotes) */
static void print_json_str(const char *s) {
    putchar('"');
    for (; s && *s; s++) {
        if (*s == '"' || *s == '\\') { putchar('\\'); putchar(*s); }
        else if (*s == '\n')          { putchar('\\'); putchar('n'); }
        else if (*s == '\r')          { putchar('\\'); putchar('r'); }
        else                           putchar(*s);
    }
    putchar('"');
}

/* Assign workspace to any toplevel currently on an output */
static void assign_workspaces(void) {
    if (current_workspace <= 0) return;
    for (int i = 0; i < MAX_TOPLEVELS; i++)
        if (toplevels[i].handle && toplevels[i].on_output)
            toplevels[i].workspace = current_workspace;
}

static void emit_state(void) {
    assign_workspaces();

    bool first;
    char buf[1024];

    printf("{\"ws1\":[");
    first = true;
    for (int i = 0; i < MAX_TOPLEVELS; i++) {
        struct toplevel *t = &toplevels[i];
        if (!t->handle || t->workspace != 1) continue;
        if (!first) putchar(',');
        first = false;
        snprintf(buf, sizeof(buf), "%s: %s",
                 t->app_id ? t->app_id : "",
                 t->title  ? t->title  : "");
        print_json_str(buf);
    }

    printf("],\"ws2\":[");
    first = true;
    for (int i = 0; i < MAX_TOPLEVELS; i++) {
        struct toplevel *t = &toplevels[i];
        if (!t->handle || t->workspace != 2) continue;
        if (!first) putchar(',');
        first = false;
        snprintf(buf, sizeof(buf), "%s: %s",
                 t->app_id ? t->app_id : "",
                 t->title  ? t->title  : "");
        print_json_str(buf);
    }

    printf("],\"active\":");
    bool found = false;
    for (int i = 0; i < MAX_TOPLEVELS; i++) {
        struct toplevel *t = &toplevels[i];
        if (!t->handle || !t->activated) continue;
        snprintf(buf, sizeof(buf), "%s: %s",
                 t->app_id ? t->app_id : "",
                 t->title  ? t->title  : "");
        print_json_str(buf);
        found = true;
        break;
    }
    if (!found) printf("\"\"");

    printf("}\n");
    fflush(stdout);
}

/* ---------- zwlr_foreign_toplevel_handle_v1 callbacks --------------------- */

static void tl_title(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
                     const char *title) {
    struct toplevel *t = data;
    free(t->title);
    t->title = strdup(title);
}

static void tl_app_id(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
                      const char *app_id) {
    struct toplevel *t = data;
    free(t->app_id);
    t->app_id = strdup(app_id);
}

static void tl_output_enter(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
                             struct wl_output *output) {
    ((struct toplevel *)data)->on_output = true;
    dirty = true;
}

static void tl_output_leave(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
                             struct wl_output *output) {
    ((struct toplevel *)data)->on_output = false;
    dirty = true;
}

static void tl_state(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
                     struct wl_array *state) {
    struct toplevel *t = data;
    t->activated = false;
    uint32_t *s;
    wl_array_for_each(s, state) {
        if (*s == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED) {
            t->activated = true;
            break;
        }
    }
}

static void tl_done(void *data, struct zwlr_foreign_toplevel_handle_v1 *h) {
    dirty = true;
}

static void tl_closed(void *data, struct zwlr_foreign_toplevel_handle_v1 *h) {
    struct toplevel *t = data;
    free(t->app_id);
    free(t->title);
    zwlr_foreign_toplevel_handle_v1_destroy(h);
    memset(t, 0, sizeof(*t));
    dirty = true;
}

static void tl_parent(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
                      struct zwlr_foreign_toplevel_handle_v1 *parent) {}

static const struct zwlr_foreign_toplevel_handle_v1_listener tl_listener = {
    .title        = tl_title,
    .app_id       = tl_app_id,
    .output_enter = tl_output_enter,
    .output_leave = tl_output_leave,
    .state        = tl_state,
    .done         = tl_done,
    .closed       = tl_closed,
    .parent       = tl_parent,
};

/* ---------- zwlr_foreign_toplevel_manager_v1 callbacks -------------------- */

static void ftmgr_toplevel(void *data, struct zwlr_foreign_toplevel_manager_v1 *mgr,
                            struct zwlr_foreign_toplevel_handle_v1 *handle) {
    struct toplevel *t = tl_slot(handle);
    if (t) zwlr_foreign_toplevel_handle_v1_add_listener(handle, &tl_listener, t);
}

static void ftmgr_finished(void *data, struct zwlr_foreign_toplevel_manager_v1 *mgr) {
    exit(0);
}

static const struct zwlr_foreign_toplevel_manager_v1_listener ftmgr_listener = {
    .toplevel = ftmgr_toplevel,
    .finished = ftmgr_finished,
};

/* ---------- ext_workspace_handle_v1 callbacks ----------------------------- */

static void ws_id(void *d, struct ext_workspace_handle_v1 *h, const char *id) {}
static void ws_coordinates(void *d, struct ext_workspace_handle_v1 *h, struct wl_array *a) {}
static void ws_capabilities(void *d, struct ext_workspace_handle_v1 *h, uint32_t c) {}

static void ws_name(void *d, struct ext_workspace_handle_v1 *h, const char *name) {
    struct workspace *w = d;
    free(w->name);
    w->name = strdup(name);
}

static void ws_state(void *d, struct ext_workspace_handle_v1 *h, uint32_t state) {
    ((struct workspace *)d)->state = state;
}

static void ws_removed(void *d, struct ext_workspace_handle_v1 *h) {
    struct workspace *w = d;
    free(w->name);
    ext_workspace_handle_v1_destroy(h);
    memset(w, 0, sizeof(*w));
}

static const struct ext_workspace_handle_v1_listener ws_listener = {
    .id           = ws_id,
    .name         = ws_name,
    .coordinates  = ws_coordinates,
    .state        = ws_state,
    .capabilities = ws_capabilities,
    .removed      = ws_removed,
};

/* ---------- ext_workspace_group_handle_v1 callbacks ----------------------- */

static void grp_capabilities(void *d, struct ext_workspace_group_handle_v1 *g, uint32_t c) {}
static void grp_output_enter(void *d, struct ext_workspace_group_handle_v1 *g, struct wl_output *o) {}
static void grp_output_leave(void *d, struct ext_workspace_group_handle_v1 *g, struct wl_output *o) {}
static void grp_workspace_enter(void *d, struct ext_workspace_group_handle_v1 *g, struct ext_workspace_handle_v1 *w) {}
static void grp_workspace_leave(void *d, struct ext_workspace_group_handle_v1 *g, struct ext_workspace_handle_v1 *w) {}
static void grp_removed(void *d, struct ext_workspace_group_handle_v1 *g) {
    ext_workspace_group_handle_v1_destroy(g);
}

static const struct ext_workspace_group_handle_v1_listener grp_listener = {
    .capabilities    = grp_capabilities,
    .output_enter    = grp_output_enter,
    .output_leave    = grp_output_leave,
    .workspace_enter = grp_workspace_enter,
    .workspace_leave = grp_workspace_leave,
    .removed         = grp_removed,
};

/* ---------- ext_workspace_manager_v1 callbacks ---------------------------- */

static void wsmgr_workspace_group(void *d, struct ext_workspace_manager_v1 *mgr,
                                   struct ext_workspace_group_handle_v1 *group) {
    ext_workspace_group_handle_v1_add_listener(group, &grp_listener, NULL);
}

static void wsmgr_workspace(void *d, struct ext_workspace_manager_v1 *mgr,
                             struct ext_workspace_handle_v1 *handle) {
    struct workspace *w = ws_slot(handle);
    if (w) ext_workspace_handle_v1_add_listener(handle, &ws_listener, w);
}

static void wsmgr_done(void *d, struct ext_workspace_manager_v1 *mgr) {
    for (int i = 0; i < MAX_WS; i++) {
        if (workspaces[i].handle && workspaces[i].name &&
            (workspaces[i].state & EXT_WORKSPACE_HANDLE_V1_STATE_ACTIVE)) {
            int ws = atoi(workspaces[i].name);
            if (ws != current_workspace) {
                current_workspace = ws;
                dirty = true;
            }
            break;
        }
    }
}

static void wsmgr_finished(void *d, struct ext_workspace_manager_v1 *mgr) {
    exit(0);
}

static const struct ext_workspace_manager_v1_listener wsmgr_listener = {
    .workspace_group = wsmgr_workspace_group,
    .workspace       = wsmgr_workspace,
    .done            = wsmgr_done,
    .finished        = wsmgr_finished,
};

/* ---------- wl_registry --------------------------------------------------- */

static struct zwlr_foreign_toplevel_manager_v1 *toplevel_manager = NULL;
static struct ext_workspace_manager_v1         *workspace_manager = NULL;

static void reg_global(void *d, struct wl_registry *reg, uint32_t name,
                        const char *interface, uint32_t version) {
    if (strcmp(interface, zwlr_foreign_toplevel_manager_v1_interface.name) == 0) {
        toplevel_manager = wl_registry_bind(reg, name,
            &zwlr_foreign_toplevel_manager_v1_interface,
            version < 3 ? version : 3);
        zwlr_foreign_toplevel_manager_v1_add_listener(
            toplevel_manager, &ftmgr_listener, NULL);
    } else if (strcmp(interface, ext_workspace_manager_v1_interface.name) == 0) {
        workspace_manager = wl_registry_bind(reg, name,
            &ext_workspace_manager_v1_interface, 1);
        ext_workspace_manager_v1_add_listener(
            workspace_manager, &wsmgr_listener, NULL);
    } else if (strcmp(interface, "wl_output") == 0) {
        /* Bind wl_output so the Wayland library can deserialize output_enter
           object references — we don't need events from it, just the binding. */
        wl_registry_bind(reg, name, &wl_output_interface,
                         version < 4 ? version : 4);
    }
}

static void reg_global_remove(void *d, struct wl_registry *reg, uint32_t name) {}

static const struct wl_registry_listener reg_listener = {
    .global        = reg_global,
    .global_remove = reg_global_remove,
};

/* ---------- main ---------------------------------------------------------- */

int main(void) {
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "qs-toplevel-watcher: failed to connect to Wayland display\n");
        return 1;
    }

    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &reg_listener, NULL);
    wl_display_roundtrip(display);

    if (!toplevel_manager) {
        fprintf(stderr, "qs-toplevel-watcher: zwlr_foreign_toplevel_manager_v1 not supported\n");
        return 1;
    }
    if (!workspace_manager) {
        fprintf(stderr, "qs-toplevel-watcher: ext_workspace_manager_v1 not supported\n");
        return 1;
    }

    /* Two roundtrips: first lets initial toplevel + workspace events arrive,
       second ensures output_enter events (which follow toplevel creation) are
       also processed before we emit the initial state. */
    wl_display_roundtrip(display);
    wl_display_roundtrip(display);

    initialized = true;
    emit_state();
    dirty = false;

    while (wl_display_dispatch(display) != -1) {
        if (dirty) {
            emit_state();
            dirty = false;
        }
    }

    wl_display_disconnect(display);
    return 0;
}
