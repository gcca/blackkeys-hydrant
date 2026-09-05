module userauth_test;

import hydrant::userauth;
import std::core::test;
import std::encoding::hex;

fn void test_key_uses_the_blackkeys_namespace() @test
{
	test::eq(userauth::key(tmem, "ada")!!, "auth:user:ada");
}

fn void test_key_rejects_empty_usernames() @test
{
	test::@check(@catch(userauth::key(tmem, "")) == userauth::EMPTY_USERNAME);
}

fn void test_key_rejects_control_and_space_characters() @test
{
	test::@check(@catch(userauth::key(tmem, "ada lovelace")) == userauth::UNSUPPORTED_USERNAME);
	test::@check(@catch(userauth::key(tmem, "ada\nlovelace")) == userauth::UNSUPPORTED_USERNAME);
	test::@check(@catch(userauth::key(tmem, "ada\x7flovelace")) == userauth::UNSUPPORTED_USERNAME);
}

fn void test_key_rejects_oversized_usernames() @test
{
	String username = string::tformat(
		"%.*s",
		241,
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	);
	test::eq(username.len, 241);
	test::@check(@catch(userauth::key(tmem, username)) == userauth::KEY_TOO_LONG);
	test::eq(userauth::key(tmem, username[..239])!!.len, 250);
}

fn void test_encode_matches_the_reference_fbuf() @test
{
	char[512] buffer;
	char[] record = userauth::encode(&buffer, "ada", "difference-engine")!!;
	test::eq(
		hex::tencode(record),
		"10000000424b554108000c000400080008000000200000000400000011000000646966666572656e63652d656e67696e650000000300000061646100"
	);
}

fn void test_encode_rejects_an_empty_password() @test
{
	char[512] buffer;
	test::@check(@catch(userauth::encode(&buffer, "ada", "")) == userauth::EMPTY_PASSWORD);
}

fn void test_encode_rejects_an_invalid_username() @test
{
	char[512] buffer;
	test::@check(@catch(userauth::encode(&buffer, "ada lovelace", "hash")) == userauth::UNSUPPORTED_USERNAME);
}