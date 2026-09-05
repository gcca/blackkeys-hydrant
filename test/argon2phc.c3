module argon2phc_test;

import argon2phc;
import std::core::test;

const String SALT = "0123456789abcdef";

fn void test_matches_the_reference_vector_at_test_cost() @test
{
	argon2phc::Options options = { ...argon2phc::DEFAULT_OPTIONS, .memory_kib = 256, .iterations = 1, .lanes = 4 };
	test::eq(
		argon2phc::hash_with_salt(tmem, "difference-engine", SALT, options)!!,
		"$argon2id$v=19$m=256,t=1,p=4$MDEyMzQ1Njc4OWFiY2RlZg$SHI3NOaAiH4EL61vOh4e6SQlUZWLWcg74mK+Sn6O02A"
	);
}

fn void test_matches_the_reference_vector_at_production_cost() @test
{
	test::eq(
		argon2phc::hash_with_salt(tmem, "difference-engine", SALT)!!,
		"$argon2id$v=19$m=65536,t=3,p=4$MDEyMzQ1Njc4OWFiY2RlZg$cbMojt9R5QSqBdXl698XiWT+RGNMwRAJDmtmwRxn+Jo"
	);
}

fn void test_matches_the_reference_vector_for_a_single_lane() @test
{
	argon2phc::Options options = { ...argon2phc::DEFAULT_OPTIONS, .memory_kib = 256, .iterations = 1, .lanes = 1 };
	test::eq(
		argon2phc::hash_with_salt(tmem, "", SALT, options)!!,
		"$argon2id$v=19$m=256,t=1,p=1$MDEyMzQ1Njc4OWFiY2RlZg$0spKoRwG1GGDb8xuZLs8MnHeKCbHf5lkJ0BgGzB0gfE"
	);
}

fn void test_production_defaults_match_blackkeys() @test
{
	test::@check(argon2phc::DEFAULT_OPTIONS.memory_kib == 65536);
	test::@check(argon2phc::DEFAULT_OPTIONS.iterations == 3);
	test::@check(argon2phc::DEFAULT_OPTIONS.lanes == 4);
	test::@check(argon2phc::DEFAULT_OPTIONS.salt_size == 16);
	test::@check(argon2phc::DEFAULT_OPTIONS.hash_size == 32);
}

fn void test_random_salts_differ_between_hashes() @test
{
	argon2phc::Options options = { ...argon2phc::DEFAULT_OPTIONS, .memory_kib = 256, .iterations = 1 };
	String first               = argon2phc::hash(tmem, "difference-engine", options)!!;
	String second              = argon2phc::hash(tmem, "difference-engine", options)!!;

	test::@check(first.starts_with("$argon2id$v=19$m=256,t=1,p=4$"));
	test::@check(first != second);
	test::@check(argon2phc::verify(first, "difference-engine"));
	test::@check(argon2phc::verify(second, "difference-engine"));
	test::@check(!argon2phc::verify(first, "wrong-password"));
}

fn void test_hash_reports_invalid_parameters() @test
{
	argon2phc::Options options = { ...argon2phc::DEFAULT_OPTIONS, .memory_kib = 1 };
	test::@check(@catch(argon2phc::hash_with_salt(tmem, "difference-engine", SALT, options)) == argon2phc::HASH_FAILED);
}