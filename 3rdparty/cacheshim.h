#pragma once

#include <stddef.h>

typedef struct CacheClient CacheClient;

#ifdef __cplusplus
extern "C" {
#endif

CacheClient *cache_client_create(const char *nodes);
void cache_client_destroy(CacheClient *client);

int cache_client_node_count(CacheClient *client);

int cache_client_set(CacheClient *client, const char *key, size_t key_length,
                     const char *value, size_t value_length,
                     unsigned int expiration);
int cache_client_flush_buffers(CacheClient *client);

const char *cache_client_strerror(CacheClient *client, int code);

#ifdef __cplusplus
}
#endif
