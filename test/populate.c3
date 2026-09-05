module populate_test;

import hydrant::conf;
import hydrant::populate;
import hydrant::simulation;
import cache;
import std::core::test;

fn conf::Settings test_settings() @private
{
	return {
		.nodes = "127.0.0.1:11211",
		.interval_seconds = 60,
		.expiration_seconds = 0,
		.memory_kib = 256,
		.iterations = 1,
		.lanes = 4,
		.generated_users = 0
	};
}

fn void test_prepare_covers_the_whole_roster() @test
{
	populate::Record[] records = populate::prepare(tmem, test_settings());
	test::eq(records.len, simulation::ROSTER.len);
	test::eq(records[0].key, "auth:user:ada");
}

fn void test_prepared_records_carry_the_file_identifier() @test
{
	populate::Record[] records = populate::prepare(tmem, test_settings());
	foreach (record : records)
	{
		test::@check(record.key.starts_with("auth:user:"));
		test::@check(record.value.len > 8);
		test::eq((String)record.value[4..7], "BKUA");
	}
}

fn void test_prepare_includes_generated_users() @test
{
	conf::Settings settings = test_settings();
	settings.generated_users = 4;

	populate::Record[] records = populate::prepare(tmem, settings);
	test::eq(records.len, simulation::ROSTER.len + 4);
	test::eq(records[simulation::ROSTER.len].key, "auth:user:sim-user-000000");
}

fn void test_publish_reports_failures_when_no_server_answers() @test
{
	cache::Client client = cache::create("127.0.0.1:1")!!;
	defer client.destroy();

	populate::Record[] records = populate::prepare(tmem, test_settings());
	populate::Report report    = populate::publish(client, records, test_settings());

	test::eq(report.stored, 0);
	test::eq(report.failed, records.len);
}