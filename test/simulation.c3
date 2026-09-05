module simulation_test;

import hydrant::simulation;
import hydrant::userauth;
import std::core::test;

fn void test_roster_is_stable_without_generated_users() @test
{
	simulation::Credential[] credentials = simulation::roster(tmem, 0);
	test::eq(credentials.len, simulation::ROSTER.len);
	test::eq(credentials[0].username, "ada");
	test::eq(credentials[0].password, "difference-engine");
}

fn void test_generated_users_extend_the_roster() @test
{
	simulation::Credential[] credentials = simulation::roster(tmem, 3);
	test::eq(credentials.len, simulation::ROSTER.len + 3);
	test::eq(credentials[simulation::ROSTER.len].username, "sim-user-000000");
	test::eq(credentials[simulation::ROSTER.len].password, "sim-secret-000000");
	test::eq(credentials[simulation::ROSTER.len + 2].username, "sim-user-000002");
}

fn void test_every_credential_yields_a_valid_cache_key() @test
{
	foreach (credential : simulation::roster(tmem, 8))
	{
		test::@check(userauth::key(tmem, credential.username)!!.starts_with("auth:user:"));
		test::@check(credential.password.len > 0);
	}
}