#include "mqshim.h"

#include <fcntl.h>
#include <rabbitmq-c/amqp.h>
#include <rabbitmq-c/tcp_socket.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DEFAULT_PORT 5672
#define CHANNEL 1
#define ERROR_SIZE 512

struct MqConsumer {
  amqp_connection_state_t connection;
  amqp_envelope_t envelope;
  int has_envelope;
  char host[256];
  int port;
  char error[ERROR_SIZE];
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

static int parse_node(const char *begin, const char *end, char *hostname,
                      size_t hostname_size, int *port) {
  const char *separator = NULL;
  size_t hostname_length;
  long parsed_port = DEFAULT_PORT;

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
    parsed_port = strtol(digits, &unparsed, 10);
    if (unparsed == digits || *unparsed != '\0')
      return 0;
    if (parsed_port <= 0 || parsed_port > UINT16_MAX)
      return 0;
    end = separator;
  }

  hostname_length = (size_t)(end - begin);
  if (hostname_length == 0 || hostname_length >= hostname_size)
    return 0;
  memcpy(hostname, begin, hostname_length);
  hostname[hostname_length] = '\0';
  *port = (int)parsed_port;
  return 1;
}

int mq_nodes_valid(const char *nodes) {
  const char *cursor;
  const char *nodes_end;

  if (nodes == NULL)
    return 0;

  cursor = nodes;
  nodes_end = nodes + strlen(nodes);
  while (cursor <= nodes_end) {
    char hostname[256];
    int port;
    const char *separator = strchr(cursor, ',');
    const char *item_end = separator != NULL ? separator : nodes_end;
    if (!parse_node(cursor, item_end, hostname, sizeof(hostname), &port))
      return 0;
    if (separator == NULL)
      return 1;
    cursor = separator + 1;
  }
  return 0;
}

static void set_status_error(MqConsumer *consumer, const char *action,
                             const char *host, int port, int status) {
  snprintf(consumer->error, sizeof(consumer->error), "%s on %s:%d: %s", action,
           host, port, amqp_error_string2(status));
}

static void set_rpc_error(MqConsumer *consumer, const char *action,
                          const char *host, int port, amqp_rpc_reply_t reply) {
  switch (reply.reply_type) {
  case AMQP_RESPONSE_NONE:
    snprintf(consumer->error, sizeof(consumer->error),
             "%s on %s:%d: missing reply", action, host, port);
    return;
  case AMQP_RESPONSE_LIBRARY_EXCEPTION:
    set_status_error(consumer, action, host, port, reply.library_error);
    return;
  case AMQP_RESPONSE_SERVER_EXCEPTION:
    if (reply.reply.id == AMQP_CONNECTION_CLOSE_METHOD) {
      amqp_connection_close_t *method = reply.reply.decoded;
      snprintf(consumer->error, sizeof(consumer->error),
               "%s on %s:%d: connection closed, %u %.*s", action, host, port,
               method->reply_code, (int)method->reply_text.len,
               (const char *)method->reply_text.bytes);
      return;
    }
    if (reply.reply.id == AMQP_CHANNEL_CLOSE_METHOD) {
      amqp_channel_close_t *method = reply.reply.decoded;
      snprintf(consumer->error, sizeof(consumer->error),
               "%s on %s:%d: channel closed, %u %.*s", action, host, port,
               method->reply_code, (int)method->reply_text.len,
               (const char *)method->reply_text.bytes);
      return;
    }
    snprintf(consumer->error, sizeof(consumer->error),
             "%s on %s:%d: server exception 0x%08x", action, host, port,
             reply.reply.id);
    return;
  case AMQP_RESPONSE_NORMAL:
    consumer->error[0] = '\0';
    return;
  }
}

static void reset_connection(MqConsumer *consumer) {
  if (consumer->has_envelope) {
    amqp_destroy_envelope(&consumer->envelope);
    consumer->has_envelope = 0;
  }
  if (consumer->connection != NULL) {
    amqp_destroy_connection(consumer->connection);
    consumer->connection = NULL;
  }
}

static int ignore_broken_pipe(MqConsumer *consumer) {
  if (signal(SIGPIPE, SIG_IGN) == SIG_ERR) {
    snprintf(consumer->error, sizeof(consumer->error),
             "ignoring broken-pipe signals failed");
    return 0;
  }
  return 1;
}

static int connect_node(MqConsumer *consumer, const char *host, int port,
                        const char *user, const char *password,
                        const char *vhost, const char *queue) {
  amqp_rpc_reply_t reply;
  amqp_socket_t *socket;
  int descriptor;
  int flags;
  int status;

  consumer->connection = amqp_new_connection();
  if (consumer->connection == NULL) {
    snprintf(consumer->error, sizeof(consumer->error),
             "creating client for %s:%d failed", host, port);
    return 0;
  }

  socket = amqp_tcp_socket_new(consumer->connection);
  if (socket == NULL) {
    snprintf(consumer->error, sizeof(consumer->error),
             "creating socket for %s:%d failed", host, port);
    reset_connection(consumer);
    return 0;
  }

  status = amqp_socket_open(socket, host, port);
  if (status != AMQP_STATUS_OK) {
    set_status_error(consumer, "connecting", host, port, status);
    reset_connection(consumer);
    return 0;
  }

  descriptor = amqp_get_sockfd(consumer->connection);
  flags = descriptor < 0 ? -1 : fcntl(descriptor, F_GETFD);
  if (flags < 0 || fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) != 0) {
    snprintf(consumer->error, sizeof(consumer->error),
             "marking socket close-on-exec for %s:%d failed", host, port);
    reset_connection(consumer);
    return 0;
  }

  reply = amqp_login(consumer->connection, vhost, AMQP_DEFAULT_MAX_CHANNELS,
                     AMQP_DEFAULT_FRAME_SIZE, AMQP_DEFAULT_HEARTBEAT,
                     AMQP_SASL_METHOD_PLAIN, user, password);
  if (reply.reply_type != AMQP_RESPONSE_NORMAL) {
    set_rpc_error(consumer, "logging in", host, port, reply);
    reset_connection(consumer);
    return 0;
  }

  amqp_channel_open(consumer->connection, CHANNEL);
  reply = amqp_get_rpc_reply(consumer->connection);
  if (reply.reply_type != AMQP_RESPONSE_NORMAL) {
    set_rpc_error(consumer, "opening channel", host, port, reply);
    reset_connection(consumer);
    return 0;
  }

  amqp_basic_qos(consumer->connection, CHANNEL, 0, 1, 0);
  reply = amqp_get_rpc_reply(consumer->connection);
  if (reply.reply_type != AMQP_RESPONSE_NORMAL) {
    set_rpc_error(consumer, "setting prefetch", host, port, reply);
    reset_connection(consumer);
    return 0;
  }

  amqp_queue_declare(consumer->connection, CHANNEL, amqp_cstring_bytes(queue),
                     0, 1, 0, 0, amqp_empty_table);
  reply = amqp_get_rpc_reply(consumer->connection);
  if (reply.reply_type != AMQP_RESPONSE_NORMAL) {
    set_rpc_error(consumer, "declaring queue", host, port, reply);
    reset_connection(consumer);
    return 0;
  }

  amqp_basic_consume(consumer->connection, CHANNEL, amqp_cstring_bytes(queue),
                     amqp_empty_bytes, 0, 0, 0, amqp_empty_table);
  reply = amqp_get_rpc_reply(consumer->connection);
  if (reply.reply_type != AMQP_RESPONSE_NORMAL) {
    set_rpc_error(consumer, "starting consumer", host, port, reply);
    reset_connection(consumer);
    return 0;
  }

  snprintf(consumer->host, sizeof(consumer->host), "%s", host);
  consumer->port = port;
  consumer->error[0] = '\0';
  return 1;
}

MqConsumer *mq_consumer_create(const char *nodes, const char *user,
                               const char *password, const char *vhost,
                               const char *queue) {
  MqConsumer *consumer = calloc(1, sizeof(MqConsumer));
  const char *cursor;
  const char *nodes_end;

  if (consumer == NULL)
    return NULL;
  if (!mq_nodes_valid(nodes) || user == NULL || password == NULL ||
      vhost == NULL || queue == NULL || queue[0] == '\0') {
    snprintf(consumer->error, sizeof(consumer->error),
             "invalid MQ configuration");
    return consumer;
  }
  if (!ignore_broken_pipe(consumer))
    return consumer;

  cursor = nodes;
  nodes_end = nodes + strlen(nodes);
  while (cursor <= nodes_end) {
    char hostname[256];
    int port;
    const char *separator = strchr(cursor, ',');
    const char *item_end = separator != NULL ? separator : nodes_end;
    parse_node(cursor, item_end, hostname, sizeof(hostname), &port);
    if (connect_node(consumer, hostname, port, user, password, vhost, queue))
      return consumer;
    if (separator == NULL)
      break;
    cursor = separator + 1;
  }

  return consumer;
}

void mq_consumer_destroy(MqConsumer *consumer) {
  if (consumer == NULL)
    return;
  reset_connection(consumer);
  free(consumer);
}

int mq_consumer_is_connected(MqConsumer *consumer) {
  return consumer != NULL && consumer->connection != NULL;
}

int mq_consumer_wait(MqConsumer *consumer) {
  if (!mq_consumer_is_connected(consumer))
    return -1;
  if (consumer->has_envelope) {
    snprintf(consumer->error, sizeof(consumer->error),
             "previous delivery is still unacknowledged");
    return -1;
  }

  for (;;) {
    amqp_rpc_reply_t reply;
    amqp_maybe_release_buffers(consumer->connection);
    reply = amqp_consume_message(consumer->connection, &consumer->envelope,
                                 NULL, 0);
    if (reply.reply_type == AMQP_RESPONSE_NORMAL) {
      consumer->has_envelope = 1;
      consumer->error[0] = '\0';
      return 0;
    }

    if (reply.reply_type == AMQP_RESPONSE_LIBRARY_EXCEPTION &&
        reply.library_error == AMQP_STATUS_UNEXPECTED_STATE) {
      amqp_frame_t frame;
      int status = amqp_simple_wait_frame(consumer->connection, &frame);
      if (status != AMQP_STATUS_OK) {
        set_status_error(consumer, "reading frame", consumer->host,
                         consumer->port, status);
        return status;
      }
      if (frame.frame_type != AMQP_FRAME_METHOD)
        continue;
      if (frame.payload.method.id == AMQP_CHANNEL_CLOSE_METHOD ||
          frame.payload.method.id == AMQP_CONNECTION_CLOSE_METHOD) {
        snprintf(consumer->error, sizeof(consumer->error),
                 "connection closed by the server");
        return -1;
      }
      continue;
    }

    set_rpc_error(consumer, "consuming", consumer->host, consumer->port, reply);
    return reply.reply_type == AMQP_RESPONSE_LIBRARY_EXCEPTION
               ? reply.library_error
               : -1;
  }
}

int mq_consumer_ack(MqConsumer *consumer) {
  int status;
  if (!mq_consumer_is_connected(consumer) || !consumer->has_envelope)
    return -1;

  status = amqp_basic_ack(consumer->connection, CHANNEL,
                          consumer->envelope.delivery_tag, 0);
  amqp_destroy_envelope(&consumer->envelope);
  consumer->has_envelope = 0;
  if (status != AMQP_STATUS_OK) {
    set_status_error(consumer, "acknowledging", consumer->host, consumer->port,
                     status);
    return status;
  }
  consumer->error[0] = '\0';
  return 0;
}

const char *mq_consumer_body(MqConsumer *consumer, size_t *size) {
  if (size != NULL)
    *size = 0;
  if (consumer == NULL || !consumer->has_envelope)
    return NULL;
  if (size != NULL)
    *size = consumer->envelope.message.body.len;
  return (const char *)consumer->envelope.message.body.bytes;
}

const char *mq_consumer_error(MqConsumer *consumer) {
  if (consumer == NULL)
    return "MQ consumer is null";
  return consumer->error;
}
