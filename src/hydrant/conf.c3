module hydrant::conf;

import std::os::env;

const String DEFAULT_NODES              = "127.0.0.1:11211,127.0.0.1:11212";
const uint DEFAULT_INTERVAL_SECONDS     = 60;
const uint DEFAULT_EXPIRATION_SECONDS   = 0;
const uint DEFAULT_MEMORY_KIB           = 65536;
const uint DEFAULT_ITERATIONS           = 3;
const uint DEFAULT_LANES                = 4;
const uint DEFAULT_GENERATED_USERS      = 0;
const String DEFAULT_MQ_NODES           = "127.0.0.1:5672,127.0.0.1:5673,127.0.0.1:5674";
const String DEFAULT_MQ_USER            = "guest";
const String DEFAULT_MQ_PASSWORD        = "guest";
const String DEFAULT_MQ_VHOST           = "/";
const String DEFAULT_MQ_QUEUE           = "blackkeys-signup";
const String DEFAULT_MQ_HYDRATION_QUEUE = "blackkeys-hydration";

struct Settings
{
	String nodes;
	uint interval_seconds;
	uint expiration_seconds;
	uint memory_kib;
	uint iterations;
	uint lanes;
	uint generated_users;
	String mq_nodes;
	String mq_user;
	String mq_password;
	String mq_vhost;
	String mq_queue;
	String mq_hydration_queue;
}

fn String read_string(Allocator allocator, String name, String fallback) => @pool()
{
	String value = env::tget_var(name) ?? fallback;
	if (!value.len) value = fallback;
	return value.copy(allocator);
}

fn uint read_uint(String name, uint fallback) => @pool()
{
	String value = env::tget_var(name) ?? "";
	if (!value.len) return fallback;
	return value.to_uint() ?? fallback;
}

fn String read_nodes(Allocator allocator) @private => read_string(allocator, "CACHE_NODES", DEFAULT_NODES);

fn uint read_interval_seconds() @private
{
	uint value = read_uint("HYDRANT_INTERVAL_SECONDS", DEFAULT_INTERVAL_SECONDS);
	return value ? value : DEFAULT_INTERVAL_SECONDS;
}

fn uint read_expiration_seconds() @private => read_uint("HYDRANT_EXPIRATION_SECONDS", DEFAULT_EXPIRATION_SECONDS);

fn uint read_memory_kib() @private => read_uint("HYDRANT_ARGON2_MEMORY_KIB", DEFAULT_MEMORY_KIB);

fn uint read_iterations() @private
{
	uint value = read_uint("HYDRANT_ARGON2_ITERATIONS", DEFAULT_ITERATIONS);
	return value ? value : DEFAULT_ITERATIONS;
}

fn uint read_lanes() @private
{
	uint value = read_uint("HYDRANT_ARGON2_LANES", DEFAULT_LANES);
	return value ? value : DEFAULT_LANES;
}

fn uint read_generated_users() @private => read_uint("HYDRANT_GENERATED_USERS", DEFAULT_GENERATED_USERS);

fn String read_mq_nodes(Allocator allocator) @private => read_string(allocator, "MQ_NODES", DEFAULT_MQ_NODES);

fn String read_mq_user(Allocator allocator) @private => read_string(allocator, "MQ_USER", DEFAULT_MQ_USER);

fn String read_mq_password(Allocator allocator) @private => read_string(allocator, "MQ_PASSWORD", DEFAULT_MQ_PASSWORD);

fn String read_mq_vhost(Allocator allocator) @private => read_string(allocator, "MQ_VHOST", DEFAULT_MQ_VHOST);

fn String read_mq_queue(Allocator allocator) @private => read_string(allocator, "MQ_QUEUE", DEFAULT_MQ_QUEUE);

fn String read_mq_hydration_queue(
	Allocator allocator
) @private => read_string(allocator, "MQ_HYDRATION_QUEUE", DEFAULT_MQ_HYDRATION_QUEUE);

fn Settings from_env(Allocator allocator)
{
	Settings settings = {
		.nodes = read_nodes(allocator),
		.interval_seconds = read_interval_seconds(),
		.expiration_seconds = read_expiration_seconds(),
		.memory_kib = read_memory_kib(),
		.iterations = read_iterations(),
		.lanes = read_lanes(),
		.generated_users = read_generated_users(),
		.mq_nodes = read_mq_nodes(allocator),
		.mq_user = read_mq_user(allocator),
		.mq_password = read_mq_password(allocator),
		.mq_vhost = read_mq_vhost(allocator),
		.mq_queue = read_mq_queue(allocator),
		.mq_hydration_queue = read_mq_hydration_queue(allocator)
	};

	if (settings.memory_kib < 8 * settings.lanes) settings.memory_kib = DEFAULT_MEMORY_KIB;
	return settings;
}