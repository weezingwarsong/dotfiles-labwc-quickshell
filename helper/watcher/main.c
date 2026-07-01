/*
 * qs-watcher
 *
 * Unified Wayland client for labwc that tracks open windows and the active
 * workspace. Uses zwlr_foreign_toplevel_manager_v1 for window state and
 * ext_workspace_manager_v1 for workspace state.
 *
 * NOTE: labwc does not fire output_enter/output_leave during workspace switches,
 * so per-window workspace assignment is not possible. All windows are emitted in
 * a flat list regardless of which workspace they reside on.
 *
 * OUTPUT (one compact JSON line per state change):
 * {
 *   "windows": [
 *     {"app_id": "kitty", "title": "~", "states": {"maximized":false,
 *      "minimized":false, "activated":true, "fullscreen":false}}
 *   ],
 *   "active_ws_name": "2",
 *   "workspaces": ["1", "2"]   -- all workspace names, sorted by coordinate
 * }
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "ext-workspace-v1-client-protocol.h"
#include "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"

#define MAX_TOPLEVELS 256
#define MAX_WS        16
#define MAX_COORDS    8

struct toplevel {
    struct zwlr_foreign_toplevel_handle_v1 *handle;
    char *app_id;
    char *title;
    bool maximized, minimized, activated, fullscreen;
};

struct workspace {
    struct ext_workspace_handle_v1 *handle;
    char *id;
    char *name;
    uint32_t coords[MAX_COORDS];
    int coords_len;
    bool is_active;
};

static struct toplevel toplevels[MAX_TOPLEVELS];
static struct workspace workspaces[MAX_WS];
static char *active_ws_name = NULL;
static bool dirty = false;

/* ---------- Helpers ---------- */
static char *xstrdup(const char *s) {
    char *r = strdup(s);
    if (!r) { perror("qs-watcher: strdup"); exit(1); }
    return r;
}

/* ---------- JSON helpers ---------- */
static void json_str(const char *s) {
    putchar('"');
    for (; s && *s; s++) {
        if (*s == '"' || *s == '\\') { putchar('\\'); putchar(*s); }
        else if (*s == '\n')          { putchar('\\'); putchar('n'); }
        else if (*s == '\r')          { putchar('\\'); putchar('r'); }
        else                           putchar(*s);
    }
    putchar('"');
}

static void emit_state(void) {
    printf("{\"windows\":[");
    bool first = true;
    for (int i = 0; i < MAX_TOPLEVELS; i++) {
        struct toplevel *t = &toplevels[i];
        if (!t->handle) continue;
        if (!first) putchar(',');
        first = false;
        printf("{\"app_id\":"); json_str(t->app_id);
        printf(",\"title\":");  json_str(t->title);
        printf(",\"states\":{\"maximized\":%s,\"minimized\":%s,\"activated\":%s,\"fullscreen\":%s}}",
               t->maximized  ? "true" : "false",
               t->minimized  ? "true" : "false",
               t->activated  ? "true" : "false",
               t->fullscreen ? "true" : "false");
    }
    printf("],\"active_ws_name\":");
    json_str(active_ws_name ? active_ws_name : "");

    /* Workspace list sorted by first coordinate — name is the labwc workspace
       label ("1", "2", …); coords give the canonical ordering. */
    int order[MAX_WS], n = 0;
    for (int i = 0; i < MAX_WS; i++)
        if (workspaces[i].handle && workspaces[i].name) order[n++] = i;
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++) {
            uint32_t ca = workspaces[order[i]].coords_len ? workspaces[order[i]].coords[0] : 0;
            uint32_t cb = workspaces[order[j]].coords_len ? workspaces[order[j]].coords[0] : 0;
            if (ca > cb) { int tmp = order[i]; order[i] = order[j]; order[j] = tmp; }
        }
    printf(",\"workspaces\":[");
    for (int i = 0; i < n; i++) {
        if (i) putchar(',');
        json_str(workspaces[order[i]].name);
    }
    printf("]}\n");
    fflush(stdout);
}

/* ---------- Toplevel listeners ---------- */
static void tl_title(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, const char *v) {
    struct toplevel *t = d; free(t->title); t->title = xstrdup(v); dirty = true;
}
static void tl_app_id(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, const char *v) {
    struct toplevel *t = d; free(t->app_id); t->app_id = xstrdup(v); dirty = true;
}
static void tl_output_enter(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, struct wl_output *o) {
    dirty = true;
}
static void tl_output_leave(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, struct wl_output *o) {}
static void tl_state(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, struct wl_array *state) {
    struct toplevel *t = d;
    t->maximized = t->minimized = t->activated = t->fullscreen = false;
    uint32_t *s;
    wl_array_for_each(s, state) {
        switch (*s) {
            case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MAXIMIZED:  t->maximized  = true; break;
            case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED:  t->minimized  = true; break;
            case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED:  t->activated  = true; break;
            case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_FULLSCREEN: t->fullscreen = true; break;
        }
    }
    dirty = true;
}
static void tl_done(void *d, struct zwlr_foreign_toplevel_handle_v1 *h)   { dirty = true; }
static void tl_closed(void *d, struct zwlr_foreign_toplevel_handle_v1 *h) {
    struct toplevel *t = d;
    free(t->app_id); free(t->title);
    zwlr_foreign_toplevel_handle_v1_destroy(h);
    memset(t, 0, sizeof(*t));
    dirty = true;
}
static void tl_parent(void *d, struct zwlr_foreign_toplevel_handle_v1 *h,
                       struct zwlr_foreign_toplevel_handle_v1 *p) {}

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

static void ftmgr_toplevel(void *d, struct zwlr_foreign_toplevel_manager_v1 *m,
                            struct zwlr_foreign_toplevel_handle_v1 *h) {
    for (int i = 0; i < MAX_TOPLEVELS; i++) {
        if (!toplevels[i].handle) {
            toplevels[i].handle = h;
            zwlr_foreign_toplevel_handle_v1_add_listener(h, &tl_listener, &toplevels[i]);
            return;
        }
    }
    zwlr_foreign_toplevel_handle_v1_destroy(h); /* table full — release proxy */
}
static void ftmgr_finished(void *d, struct zwlr_foreign_toplevel_manager_v1 *m) { exit(0); }

static const struct zwlr_foreign_toplevel_manager_v1_listener ftmgr_listener = {
    .toplevel = ftmgr_toplevel,
    .finished = ftmgr_finished,
};

/* ---------- Workspace listeners ---------- */
static void ws_id(void *d, struct ext_workspace_handle_v1 *h, const char *v) {
    struct workspace *ws = d; free(ws->id); ws->id = xstrdup(v);
}
static void ws_name(void *d, struct ext_workspace_handle_v1 *h, const char *v) {
    struct workspace *ws = d; free(ws->name); ws->name = xstrdup(v);
}
static void ws_coordinates(void *d, struct ext_workspace_handle_v1 *h, struct wl_array *arr) {
    struct workspace *ws = d; ws->coords_len = 0;
    uint32_t *c; wl_array_for_each(c, arr)
        if (ws->coords_len < MAX_COORDS) ws->coords[ws->coords_len++] = *c;
}
static void ws_state(void *d, struct ext_workspace_handle_v1 *h, uint32_t state) {
    ((struct workspace *)d)->is_active = (state & EXT_WORKSPACE_HANDLE_V1_STATE_ACTIVE);
}
static void ws_capabilities(void *d, struct ext_workspace_handle_v1 *h, uint32_t c) {}
static void ws_removed(void *d, struct ext_workspace_handle_v1 *h) {
    struct workspace *ws = d;
    free(ws->id); free(ws->name);
    ext_workspace_handle_v1_destroy(h);
    memset(ws, 0, sizeof(*ws));
    dirty = true;
}

static const struct ext_workspace_handle_v1_listener ws_listener = {
    .id           = ws_id,
    .name         = ws_name,
    .coordinates  = ws_coordinates,
    .state        = ws_state,
    .capabilities = ws_capabilities,
    .removed      = ws_removed,
};

static void wsmgr_workspace(void *d, struct ext_workspace_manager_v1 *m,
                             struct ext_workspace_handle_v1 *h) {
    for (int i = 0; i < MAX_WS; i++) {
        if (!workspaces[i].handle) {
            workspaces[i].handle = h;
            ext_workspace_handle_v1_add_listener(h, &ws_listener, &workspaces[i]);
            return;
        }
    }
    ext_workspace_handle_v1_destroy(h); /* table full — release proxy */
}

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

static void wsmgr_workspace_group(void *d, struct ext_workspace_manager_v1 *m,
                                   struct ext_workspace_group_handle_v1 *g) {
    ext_workspace_group_handle_v1_add_listener(g, &grp_listener, NULL);
}
static void wsmgr_finished(void *d, struct ext_workspace_manager_v1 *m) { exit(0); }

static void wsmgr_done(void *d, struct ext_workspace_manager_v1 *m) {
    for (int i = 0; i < MAX_WS; i++) {
        if (!workspaces[i].handle || !workspaces[i].is_active) continue;
        const char *name = workspaces[i].name
                         ? workspaces[i].name
                         : (workspaces[i].id ? workspaces[i].id : "");
        if (!active_ws_name || strcmp(active_ws_name, name) != 0) {
            free(active_ws_name);
            active_ws_name = xstrdup(name);
            dirty = true;
        }
        break;
    }
}

static const struct ext_workspace_manager_v1_listener wsmgr_listener = {
    .workspace_group = wsmgr_workspace_group,
    .workspace       = wsmgr_workspace,
    .done            = wsmgr_done,
    .finished        = wsmgr_finished,
};

/* ---------- Registry ---------- */
static struct zwlr_foreign_toplevel_manager_v1 *tl_mgr = NULL;
static struct ext_workspace_manager_v1          *ws_mgr = NULL;

static void reg_global(void *d, struct wl_registry *r, uint32_t n,
                        const char *iface, uint32_t v) {
    if (strcmp(iface, zwlr_foreign_toplevel_manager_v1_interface.name) == 0) {
        tl_mgr = wl_registry_bind(r, n, &zwlr_foreign_toplevel_manager_v1_interface, v < 3 ? v : 3);
        zwlr_foreign_toplevel_manager_v1_add_listener(tl_mgr, &ftmgr_listener, NULL);
    } else if (strcmp(iface, ext_workspace_manager_v1_interface.name) == 0) {
        ws_mgr = wl_registry_bind(r, n, &ext_workspace_manager_v1_interface, 1);
        ext_workspace_manager_v1_add_listener(ws_mgr, &wsmgr_listener, NULL);
    } else if (strcmp(iface, "wl_output") == 0) {
        wl_registry_bind(r, n, &wl_output_interface, v < 4 ? v : 4);
    }
}
static const struct wl_registry_listener reg_listener = { .global = reg_global };

int main(void) {
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return 1;

    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &reg_listener, NULL);

    wl_display_roundtrip(display); /* bind globals */
    wl_display_roundtrip(display); /* receive handles */
    wl_display_roundtrip(display); /* receive initial state */

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
