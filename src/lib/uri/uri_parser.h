/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright 2010-2021, Tarantool AUTHORS, please see AUTHORS file.
 */
#pragma once

#include <stddef.h>
#include <stdbool.h>
#include <netdb.h> /* NI_MAXHOST, NI_MAXSERV */
#include <limits.h> /* _POSIX_PATH_MAX */

#if defined(__cplusplus)
extern "C" {
#endif /* defined(__cplusplus) */

struct uri {
	const char *scheme;
	size_t scheme_len;
	const char *login;
	size_t login_len;
	const char *password;
	size_t password_len;
	const char *host;
	size_t host_len;
	const char *service;
	size_t service_len;
	const char *path;
	size_t path_len;
	const char *query;
	size_t query_len;
	const char *fragment;
	size_t fragment_len;
	int host_hint;
};

#define URI_HOST_UNIX "unix/"
#define URI_MAXHOST NI_MAXHOST
#define URI_MAXSERVICE _POSIX_PATH_MAX /* _POSIX_PATH_MAX always > NI_MAXSERV */

int
uri_parse(struct uri *uri, const char *str);

int
uri_format(char *str, int len, const struct uri *uri, bool write_password);

#if defined(__cplusplus)
} /* extern "C" */
#endif /* defined(__cplusplus) */
