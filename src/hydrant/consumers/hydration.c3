module hydrant::consumers::hydration;

import fbufs;
import hydrant::conf;
import mq;
import std::io;

faultdef EMPTY_NAME, UNKNOWN_IDENTIFIER;

struct Message
{
	String name;
}

fn Message? decode(char[] body)
{
	if (!fbufs::hydration_message_has_identifier(body)) return UNKNOWN_IDENTIFIER~;
	fbufs::HydrationMessage message = fbufs::decode_hydration_message(body)!;

	if (!message.name.len) return EMPTY_NAME~;
	return { .name = message.name };
}

fn void report(char[] body) @private
{
	Message? message = decode(body);
	if (catch excuse = message)
	{
		io::eprintfn("hydrant: unusable %d byte hydration message: %s", body.len, excuse);
		return;
	}
	io::printfn("hydrant: hydration event '%s'", message.name);
}

fn int consume(void* arg)
{
	conf::Settings* settings = (conf::Settings*)arg;
	mq::Consumer? consumer = mq::create(
		settings.mq_nodes,
		settings.mq_user,
		settings.mq_password,
		settings.mq_vhost,
		settings.mq_hydration_queue
	);
	if (catch excuse = consumer)
	{
		io::eprintfn("hydrant: could not create hydration MQ consumer: %s", excuse);
		return 1;
	}
	defer consumer.destroy();

	if (!consumer.is_connected())
	{
		io::eprintfn("hydrant: could not connect to hydration MQ: %s", consumer.error());
		return 1;
	}

	io::printfn("hydrant: consuming MQ queue '%s' on '%s'", settings.mq_hydration_queue, settings.mq_nodes);
	while (true)
	{
		if (!consumer.wait())
		{
			io::eprintfn("hydrant: hydration MQ consume failed: %s", consumer.error());
			return 1;
		}

		report(consumer.body());

		if (!consumer.ack())
		{
			io::eprintfn("hydrant: hydration MQ acknowledgement failed: %s", consumer.error());
			return 1;
		}
	}
}