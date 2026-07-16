/*
 * pillbox-copy-multi — offer image/png + text/plain (filepath) on Wayland clipboard
 *
 * Uses zwlr_data_control_manager_v1 (wlr-data-control) — no focused window needed.
 *
 * Usage: pillbox-copy-multi /path/to/file.png
 *
 * Exits when another client takes clipboard ownership.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>

#include <wayland-client.h>
#include "wlr-data-control-client-protocol.h"

/* ── state ────────────────────────────────────────────────────────────────── */

static struct wl_display                    *display;
static struct wl_registry                   *registry;
static struct wl_seat                       *seat;
static struct zwlr_data_control_manager_v1  *manager;
static struct zwlr_data_control_device_v1   *device;
static struct zwlr_data_control_source_v1   *source;

static const char    *image_path;
static unsigned char *image_data;
static size_t         image_size;

static int done = 0;  /* set to 1 on cancel */

/* ── helpers ──────────────────────────────────────────────────────────────── */

static int read_file(const char *path, unsigned char **out, size_t *size) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) { perror(path); return -1; }

    struct stat st;
    if (fstat(fd, &st) < 0) { perror("fstat"); close(fd); return -1; }

    *size = (size_t)st.st_size;
    if (*size == 0) { fprintf(stderr, "empty file\n"); close(fd); return -1; }

    *out = malloc(*size);
    if (!*out) { fprintf(stderr, "OOM\n"); close(fd); return -1; }

    size_t pos = 0;
    while (pos < *size) {
        ssize_t n = read(fd, *out + pos, *size - pos);
        if (n < 0) {
            if (errno == EINTR) continue;
            perror("read"); free(*out); close(fd); return -1;
        }
        if (n == 0) break;
        pos += n;
    }
    *size = pos;  /* actual bytes read */
    close(fd);
    return 0;
}

static void write_all(int fd, const void *buf, size_t len) {
    size_t pos = 0;
    while (pos < len) {
        ssize_t n = write(fd, (const char *)buf + pos, len - pos);
        if (n < 0) { if (errno == EINTR) continue; break; }
        pos += n;
    }
}

/* ── data source events ───────────────────────────────────────────────────── */

static void source_send(void *data,
                        struct zwlr_data_control_source_v1 *src,
                        const char *mime_type, int32_t fd)
{
    (void)data; (void)src;

    if (strcmp(mime_type, "image/png") == 0) {
        write_all(fd, image_data, image_size);
    } else if (strncmp(mime_type, "text/uri-list", 13) == 0) {
        char *uri;
        if (asprintf(&uri, "file://%s\r\n", image_path) >= 0) {
            write_all(fd, uri, strlen(uri));
            free(uri);
        }
    } else {
        /* text/plain, text/plain;charset=utf-8 */
        write_all(fd, image_path, strlen(image_path));
    }
    close(fd);
}

static void source_cancelled(void *data,
                             struct zwlr_data_control_source_v1 *src)
{
    (void)data; (void)src;
    done = 1;
}

static const struct zwlr_data_control_source_v1_listener source_listener = {
    .send      = source_send,
    .cancelled = source_cancelled,
};

/* ── registry ─────────────────────────────────────────────────────────────── */

static void registry_global(void *data, struct wl_registry *reg,
                             uint32_t name, const char *interface,
                             uint32_t version)
{
    (void)data;
    if (strcmp(interface, wl_seat_interface.name) == 0 && !seat) {
        seat = wl_registry_bind(reg, name, &wl_seat_interface, 1);
    } else if (strcmp(interface, zwlr_data_control_manager_v1_interface.name) == 0) {
        manager = wl_registry_bind(reg, name,
                                   &zwlr_data_control_manager_v1_interface,
                                   version < 2 ? version : 2);
    }
}

static void registry_global_remove(void *data, struct wl_registry *reg,
                                   uint32_t name)
{
    (void)data; (void)reg; (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global        = registry_global,
    .global_remove = registry_global_remove,
};

/* ── main ─────────────────────────────────────────────────────────────────── */

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "usage: pillbox-copy-multi <file.png>\n");
        return 1;
    }

    image_path = argv[1];

    if (read_file(image_path, &image_data, &image_size) < 0)
        return 1;

    int ret = 1;

    display = wl_display_connect(NULL);
    if (!display) { fprintf(stderr, "no wayland display\n"); goto out_free_image; }

    registry = wl_display_get_registry(display);
    if (!registry) { fprintf(stderr, "wl_display_get_registry failed\n"); goto out_disconnect; }

    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);

    if (!manager) {
        fprintf(stderr, "compositor missing zwlr_data_control_manager_v1\n");
        goto out_registry;
    }
    if (!seat) {
        fprintf(stderr, "no seat found\n");
        goto out_manager;
    }

    device = zwlr_data_control_manager_v1_get_data_device(manager, seat);
    if (!device) { fprintf(stderr, "failed to get data device\n"); goto out_seat; }

    source = zwlr_data_control_manager_v1_create_data_source(manager);
    if (!source) { fprintf(stderr, "failed to create data source\n"); goto out_device; }

    zwlr_data_control_source_v1_add_listener(source, &source_listener, NULL);

    zwlr_data_control_source_v1_offer(source, "image/png");
    zwlr_data_control_source_v1_offer(source, "text/plain;charset=utf-8");
    zwlr_data_control_source_v1_offer(source, "text/plain");
    zwlr_data_control_source_v1_offer(source, "text/uri-list");

    zwlr_data_control_device_v1_set_selection(device, source);
    wl_display_flush(display);

    while (!done && wl_display_dispatch(display) != -1)
        ;

    ret = 0;

    zwlr_data_control_source_v1_destroy(source);
out_device:
    zwlr_data_control_device_v1_destroy(device);
out_seat:
    wl_proxy_destroy((struct wl_proxy *)seat);
out_manager:
    zwlr_data_control_manager_v1_destroy(manager);
out_registry:
    wl_registry_destroy(registry);
out_disconnect:
    wl_display_disconnect(display);
out_free_image:
    free(image_data);
    return ret;
}
