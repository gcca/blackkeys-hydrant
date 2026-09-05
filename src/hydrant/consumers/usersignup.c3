module hydrant::consumers::usersignup;

import cache;
import fbufs;
import hydrant::conf;
import hydrant::populate;
import mq;
import std::io;

faultdef EMPTY_PASSWORD, EMPTY_USERNAME, UNKNOWN_IDENTIFIER;

struct Message
{
	String username;
	String password;
}

fn Message? decode(char[] body)
{
	if (!fbufs::user_signup_has_identifier(body)) return UNKNOWN_IDENTIFIER~;
	fbufs::UserSignup message = fbufs::decode_user_signup(body)!;

	if (!message.username.len) return EMPTY_USERNAME~;
	if (!message.password.len) return EMPTY_PASSWORD~;
	return { .username = message.username, .password = message.password };
}

fn void report(char[] body) @private
{
	Message? message = decode(body);
	if (catch excuse = message)
	{
		io::eprintfn("hydrant: unusable %d byte signup message: %s", body.len, excuse);
		return;
	}
	io::printfn("hydrant: signup username '%s', password '%s'", message.username, message.password);
}

fn bool publish(cache::Client cache, populate::Record[] records, conf::Settings settings) @private
{
	populate::Report report = populate::publish(cache, records, settings);
	io::printfn("hydrant: stored %d, failed %d", report.stored, report.failed);
	return !report.failed && !report.flush_failed;
}

fn int consume(cache::Client cache, populate::Record[] records, conf::Settings settings)
{
	mq::Consumer? consumer = mq::create(
		settings.mq_nodes,
		settings.mq_user,
		settings.mq_password,
		settings.mq_vhost,
		settings.mq_queue
	);
	if (catch excuse = consumer)
	{
		io::eprintfn("hydrant: could not create MQ consumer: %s", excuse);
		return 1;
	}
	defer consumer.destroy();

	if (!consumer.is_connected())
	{
		io::eprintfn("hydrant: could not connect to MQ: %s", consumer.error());
		return 1;
	}

	io::printfn("hydrant: consuming MQ queue '%s' on '%s'", settings.mq_queue, settings.mq_nodes);
	while (true)
	{
		if (!consumer.wait())
		{
			io::eprintfn("hydrant: MQ consume failed: %s", consumer.error());
			return 1;
		}

		report(consumer.body());

		if (!publish(cache, records, settings))
		{
			io::eprintfn("hydrant: publish cycle failed; leaving MQ delivery unacknowledged");
			return 1;
		}

		if (!consumer.ack())
		{
			io::eprintfn("hydrant: MQ acknowledgement failed: %s", consumer.error());
			return 1;
		}
	}
}