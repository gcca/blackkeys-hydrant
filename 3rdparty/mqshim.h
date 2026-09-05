#pragma once

#include <stddef.h>

typedef struct MqConsumer MqConsumer;

#ifdef __cplusplus
extern "C" {
#endif

int mq_nodes_valid(const char *nodes);

MqConsumer *mq_consumer_create(const char *nodes, const char *user,
                               const char *password, const char *vhost,
                               const char *queue);
void mq_consumer_destroy(MqConsumer *consumer);

int mq_consumer_is_connected(MqConsumer *consumer);
int mq_consumer_wait(MqConsumer *consumer);
int mq_consumer_ack(MqConsumer *consumer);
const char *mq_consumer_body(MqConsumer *consumer, size_t *size);
const char *mq_consumer_error(MqConsumer *consumer);

#ifdef __cplusplus
}
#endif
