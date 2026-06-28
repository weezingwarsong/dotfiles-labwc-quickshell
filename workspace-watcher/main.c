#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "ext-workspace-v1-client-protocol.h"

#define MAX_WS 64

struct workspace {
    struct ext_workspace_handle_v1 *handle;
    char *name;
    uint32_t state;
};

static struct workspace workspaces[MAX_WS];

static struct workspace *ws_slot(struct ext_workspace_handle_v1 *h) {
    for (int i = 0; i < MAX_WS; i++)
        if (!workspaces[i].handle) {
            workspaces[i].handle = h;
            return &workspaces[i];
        }
    return NULL;
}

/* --- ext_workspace_handle_v1 -------------------------------------------- */

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
    ext_workspace_handle_v1_destroy(w->handle);
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

/* --- ext_workspace_group_handle_v1 -------------------------------------- */

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

/* --- ext_workspace_manager_v1 ------------------------------------------- */

static bool initialized = false;
static char last_active[64] = "";

static void mgr_workspace_group(void *d, struct ext_workspace_manager_v1 *mgr,
                                 struct ext_workspace_group_handle_v1 *group) {
    ext_workspace_group_handle_v1_add_listener(group, &grp_listener, NULL);
}

static void mgr_workspace(void *d, struct ext_workspace_manager_v1 *mgr,
                           struct ext_workspace_handle_v1 *handle) {
    struct workspace *w = ws_slot(handle);
    if (w) ext_workspace_handle_v1_add_listener(handle, &ws_listener, w);
}

static void mgr_done(void *d, struct ext_workspace_manager_v1 *mgr) {
    for (int i = 0; i < MAX_WS; i++) {
        if (workspaces[i].handle && workspaces[i].name &&
            (workspaces[i].state & EXT_WORKSPACE_HANDLE_V1_STATE_ACTIVE)) {
            if (initialized && strcmp(workspaces[i].name, last_active) != 0) {
                printf("%s\n", workspaces[i].name);
                fflush(stdout);
            }
            strncpy(last_active, workspaces[i].name, sizeof(last_active) - 1);
            last_active[sizeof(last_active) - 1] = '\0';
            initialized = true;
            return;
        }
    }
}

static void mgr_finished(void *d, struct ext_workspace_manager_v1 *mgr) {
    exit(0);
}

static const struct ext_workspace_manager_v1_listener mgr_listener = {
    .workspace_group = mgr_workspace_group,
    .workspace       = mgr_workspace,
    .done            = mgr_done,
    .finished        = mgr_finished,
};

/* --- wl_registry -------------------------------------------------------- */

static struct ext_workspace_manager_v1 *manager = NULL;

static void reg_global(void *d, struct wl_registry *reg, uint32_t name,
                        const char *interface, uint32_t version) {
    if (strcmp(interface, ext_workspace_manager_v1_interface.name) == 0) {
        manager = wl_registry_bind(reg, name, &ext_workspace_manager_v1_interface, 1);
        ext_workspace_manager_v1_add_listener(manager, &mgr_listener, NULL);
    }
}

static void reg_global_remove(void *d, struct wl_registry *reg, uint32_t name) {}

static const struct wl_registry_listener reg_listener = {
    .global        = reg_global,
    .global_remove = reg_global_remove,
};

/* --- main --------------------------------------------------------------- */

int main(void) {
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "qs-workspace-watcher: failed to connect to Wayland display\n");
        return 1;
    }

    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &reg_listener, NULL);
    wl_display_roundtrip(display);

    if (!manager) {
        fprintf(stderr, "qs-workspace-watcher: ext_workspace_manager_v1 not supported by compositor\n");
        return 1;
    }

    while (wl_display_dispatch(display) != -1) {}

    wl_display_disconnect(display);
    return 0;
}
