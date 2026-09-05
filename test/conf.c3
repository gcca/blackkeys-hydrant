module conf_test;

import hydrant::conf;
import std::core::test;
import std::os::env;

const String[] VARIABLES = {
	"CACHE_NODES",
	"HYDRANT_INTERVAL_SECONDS",
	"HYDRANT_EXPIRATION_SECONDS",
	"HYDRANT_ARGON2_MEMORY_KIB",
	"HYDRANT_ARGON2_ITERATIONS",
	"HYDRANT_ARGON2_LANES",
	"HYDRANT_GENERATED_USERS",
	"MQ_NODES",
	"MQ_USER",
	"MQ_PASSWORD",
	"MQ_VHOST",
	"MQ_QUEUE",
	"MQ_HYDRATION_QUEUE"
};

fn void clear() @private
{
	foreach (variable : VARIABLES) env::clear_var(variable);
}

fn void test_defaults_target_a_local_cache() @test
{
	clear();
	conf::Settings settings = conf::from_env(tmem);

	test::eq(settings.nodes, "127.0.0.1:11211,127.0.0.1:11212");
	test::@check(settings.interval_seconds == 60);
	test::@check(settings.expiration_seconds == 0);
	test::@check(settings.memory_kib == 65536);
	test::@check(settings.iterations == 3);
	test::@check(settings.lanes == 4);
	test::@check(settings.generated_users == 0);
	test::eq(settings.mq_nodes, "127.0.0.1:5672,127.0.0.1:5673,127.0.0.1:5674");
	test::eq(settings.mq_user, "guest");
	test::eq(settings.mq_password, "guest");
	test::eq(settings.mq_vhost, "/");
	test::eq(settings.mq_queue, "blackkeys-signup");
	test::eq(settings.mq_hydration_queue, "blackkeys-hydration");
}

fn void test_environment_overrides_every_field() @test
{
	clear();
	env::set_var("CACHE_NODES", "cache-a:11211,cache-b:11211");
	env::set_var("HYDRANT_INTERVAL_SECONDS", "15");
	env::set_var("HYDRANT_EXPIRATION_SECONDS", "300");
	env::set_var("HYDRANT_ARGON2_MEMORY_KIB", "4096");
	env::set_var("HYDRANT_ARGON2_ITERATIONS", "2");
	env::set_var("HYDRANT_ARGON2_LANES", "2");
	env::set_var("HYDRANT_GENERATED_USERS", "128");
	env::set_var("MQ_NODES", "mq-a:5672,mq-b:5672");
	env::set_var("MQ_USER", "hydrant");
	env::set_var("MQ_PASSWORD", "secret");
	env::set_var("MQ_VHOST", "/blackkeys");
	env::set_var("MQ_QUEUE", "refresh-users");
	env::set_var("MQ_HYDRATION_QUEUE", "refresh-hydration");
	defer clear();

	conf::Settings settings = conf::from_env(tmem);
	test::eq(settings.nodes, "cache-a:11211,cache-b:11211");
	test::@check(settings.interval_seconds == 15);
	test::@check(settings.expiration_seconds == 300);
	test::@check(settings.memory_kib == 4096);
	test::@check(settings.iterations == 2);
	test::@check(settings.lanes == 2);
	test::@check(settings.generated_users == 128);
	test::eq(settings.mq_nodes, "mq-a:5672,mq-b:5672");
	test::eq(settings.mq_user, "hydrant");
	test::eq(settings.mq_password, "secret");
	test::eq(settings.mq_vhost, "/blackkeys");
	test::eq(settings.mq_queue, "refresh-users");
	test::eq(settings.mq_hydration_queue, "refresh-hydration");
}

fn void test_unusable_values_fall_back_to_defaults() @test
{
	clear();
	env::set_var("CACHE_NODES", "");
	env::set_var("HYDRANT_INTERVAL_SECONDS", "0");
	env::set_var("HYDRANT_ARGON2_ITERATIONS", "not-a-number");
	env::set_var("HYDRANT_ARGON2_LANES", "0");
	env::set_var("MQ_NODES", "");
	defer clear();

	conf::Settings settings = conf::from_env(tmem);
	test::eq(settings.nodes, "127.0.0.1:11211,127.0.0.1:11212");
	test::eq(settings.mq_nodes, "127.0.0.1:5672,127.0.0.1:5673,127.0.0.1:5674");
	test::@check(settings.interval_seconds == 60);
	test::@check(settings.iterations == 3);
	test::@check(settings.lanes == 4);
}

fn void test_memory_below_the_argon2_minimum_falls_back() @test
{
	clear();
	env::set_var("HYDRANT_ARGON2_MEMORY_KIB", "8");
	env::set_var("HYDRANT_ARGON2_LANES", "4");
	defer clear();

	conf::Settings settings = conf::from_env(tmem);
	test::@check(settings.memory_kib == 65536);
}