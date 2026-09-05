module mq;

import std::core::cinterop;

faultdef CREATE_FAILED;

const CInt SUCCESS = 0;

typedef Consumer = void*;

extern fn CInt _nodes_valid(ZString nodes) @cname("mq_nodes_valid");
extern fn Consumer _create(
	ZString nodes,
	ZString user,
	ZString password,
	ZString vhost,
	ZString queue
) @cname("mq_consumer_create");
extern fn void Consumer.destroy(self) @cname("mq_consumer_destroy");
extern fn CInt Consumer._is_connected(self) @cname("mq_consumer_is_connected");
extern fn CInt Consumer._wait(self) @cname("mq_consumer_wait");
extern fn CInt Consumer._ack(self) @cname("mq_consumer_ack");
extern fn char* Consumer._body(self, usz* size) @cname("mq_consumer_body");
extern fn ZString Consumer._error(self) @cname("mq_consumer_error");

fn bool nodes_valid(String nodes) => @pool()
{
	return _nodes_valid(nodes.zstr_tcopy()) != 0;
}

fn Consumer? create(String nodes, String user, String password, String vhost, String queue) => @pool()
{
	Consumer consumer = _create(
		nodes.zstr_tcopy(),
		user.zstr_tcopy(),
		password.zstr_tcopy(),
		vhost.zstr_tcopy(),
		queue.zstr_tcopy()
	);
	if ((void*)consumer == null) return CREATE_FAILED~;
	return consumer;
}

fn bool Consumer.is_connected(self) => self._is_connected() != 0;

fn bool Consumer.wait(self) => self._wait() == SUCCESS;

fn bool Consumer.ack(self) => self._ack() == SUCCESS;

fn char[] Consumer.body(self)
{
	usz size;
	char* bytes = self._body(&size);
	if (bytes == null) return { };
	return bytes[:size];
}

fn String Consumer.error(self) => self._error().str_view();