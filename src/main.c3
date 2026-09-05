module hydrant;

import hydrant::conf;
import hydrant::consumers::hydration;
import hydrant::consumers::usersignup;
import hydrant::populate;
import cache;
import std::io;
import std::thread;
import std::time;

fn bool publish(cache::Client cache, populate::Record[] records, conf::Settings settings)
{
	populate::Report report = populate::publish(cache, records, settings);
	io::printfn("hydrant: stored %d, failed %d", report.stored, report.failed);
	return !report.failed && !report.flush_failed;
}

fn int main(String[] args)
{
	bool once = false;

	foreach (argument : args[1..])
	{
		switch (argument)
		{
			case "--once":
				once = true;
			default:
				io::eprintfn("hydrant: unknown argument '%s'", argument);
				return 2;
		}
	}

	conf::Settings settings = conf::from_env(mem);

	cache::Client? cache = cache::create(settings.nodes);
	if (catch excuse = cache)
	{
		io::eprintfn("hydrant: unusable cache nodes '%s': %s", settings.nodes, excuse);
		return 1;
	}
	defer cache.destroy();

	io::printfn(
		"hydrant: %d node(s) on '%s', argon2id m=%d,t=%d,p=%d, expiration %ds, interval %ds",
		cache.node_count(),
		settings.nodes,
		settings.memory_kib,
		settings.iterations,
		settings.lanes,
		settings.expiration_seconds,
		settings.interval_seconds
	);

	populate::Record[] records = populate::prepare(mem, settings);
	if (!records.len)
	{
		io::eprintn("hydrant: no simulated records could be prepared");
		return 1;
	}
	io::printfn("hydrant: prepared %d record(s)", records.len);
	if (once) return publish(cache, records, settings) ? 0 : 1;
	if (settings.mq_nodes.len)
	{
		thread::Thread hydration_thread;
		if (catch excuse = hydration_thread.create(&hydration::consume, &settings))
		{
			io::eprintfn("hydrant: could not start hydration consumer thread: %s", excuse);
			return 1;
		}
		hydration_thread.detach();
		return usersignup::consume(cache, records, settings);
	}

	while (true)
	{
		publish(cache, records, settings);
		thread::sleep(time::sec(settings.interval_seconds));
	}
}