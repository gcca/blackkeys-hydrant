#include "cacheshim.h"

#include <libmemcached/memcached.h>
#include <stdlib.h>
#include <string.h>

#define DEFAULT_PORT 11211

struct CacheClient {
  memcached_st *handle;
};

static const char *skip_spaces(const char *cursor, const char *end) {
  while (cursor < end && (*cursor == ' ' || *cursor == '\t'))
    cursor++;
  return cursor;
}

static const char *trim_spaces(const char *cursor, const char *end) {
  while (end > cursor && (end[-1] == ' ' || end[-1] == '\t'))
    end--;
  return end;
}

static int add_node(memcached_st *handle, const char *begin, const char *end) {
  char hostname[256];
  const char *separator = NULL;
  size_t hostname_length;
  long port = DEFAULT_PORT;

  begin = skip_spaces(begin, end);
  end = trim_spaces(begin, end);
  if (begin == end)
    return 0;

  for (const char *cursor = end; cursor > begin; cursor--) {
    if (cursor[-1] == ':') {
      separator = cursor - 1;
      break;
    }
  }

  if (separator != NULL) {
    char digits[16];
    size_t digits_length = (size_t)(end - separator - 1);
    if (digits_length == 0 || digits_length >= sizeof(digits))
      return 0;
    memcpy(digits, separator + 1, digits_length);
    digits[digits_length] = '\0';
    char *unparsed = NULL;
    port = strtol(digits, &unparsed, 10);
    if (unparsed == digits || *unparsed != '\0')
      return 0;
    if (port <= 0 || port > 65535)
      return 0;
    end = separator;
  }

  hostname_length = (size_t)(end - begin);
  if (hostname_length == 0 || hostname_length >= sizeof(hostname))
    return 0;
  memcpy(hostname, begin, hostname_length);
  hostname[hostname_length] = '\0';

  return memcached_server_add(handle, hostname, (in_port_t)port) ==
         MEMCACHED_SUCCESS;
}

CacheClient *cache_client_create(const char *nodes) {
  CacheClient *client;
  memcached_st *handle;
  const char *cursor;
  const char *nodes_end;
  uint32_t node_count;

  if (nodes == NULL)
    return NULL;

  handle = memcached_create(NULL);
  if (handle == NULL)
    return NULL;

  cursor = nodes;
  nodes_end = nodes + strlen(nodes);
  while (cursor <= nodes_end) {
    const char *separator = strchr(cursor, ',');
    const char *item_end = separator != NULL ? separator : nodes_end;
    if (!add_node(handle, cursor, item_end)) {
      memcached_free(handle);
      return NULL;
    }
    if (separator == NULL)
      break;
    cursor = separator + 1;
  }

  node_count = memcached_server_count(handle);
  if (node_count == 0) {
    memcached_free(handle);
    return NULL;
  }

  if (memcached_behavior_set(handle, MEMCACHED_BEHAVIOR_BINARY_PROTOCOL, 1) !=
          MEMCACHED_SUCCESS ||
      memcached_behavior_set(handle, MEMCACHED_BEHAVIOR_KETAMA, 1) !=
          MEMCACHED_SUCCESS ||
      memcached_behavior_set(handle, MEMCACHED_BEHAVIOR_NUMBER_OF_REPLICAS,
                             node_count - 1) != MEMCACHED_SUCCESS) {
    memcached_free(handle);
    return NULL;
  }

  client = (CacheClient *)calloc(1, sizeof(CacheClient));
  if (client == NULL) {
    memcached_free(handle);
    return NULL;
  }
  client->handle = handle;
  return client;
}

void cache_client_destroy(CacheClient *client) {
  if (client == NULL)
    return;
  memcached_free(client->handle);
  free(client);
}

int cache_client_node_count(CacheClient *client) {
  return (int)memcached_server_count(client->handle);
}

int cache_client_set(CacheClient *client, const char *key, size_t key_length,
                     const char *value, size_t value_length,
                     unsigned int expiration) {
  return (int)memcached_set(client->handle, key, key_length, value,
                            value_length, (time_t)expiration, 0);
}

int cache_client_flush_buffers(CacheClient *client) {
  return (int)memcached_flush_buffers(client->handle);
}

const char *cache_client_strerror(CacheClient *client, int code) {
  return memcached_strerror(client->handle, (memcached_return_t)code);
}
