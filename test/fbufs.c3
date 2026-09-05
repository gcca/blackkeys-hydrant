module fbufs_test;

import fbufs;
import std::core::test;
import std::encoding::hex;

fn void test_user_auth_encoding_matches_the_reference_buffer() @test
{
	char[512] buffer;
	char[] encoded = fbufs::encode_user_auth(&buffer, "ada", "difference-engine")!!;
	test::eq(
		hex::tencode(encoded),
		"10000000424b554108000c000400080008000000200000000400000011000000646966666572656e63652d656e67696e650000000300000061646100"
	);
}

fn void test_user_auth_encoding_reports_a_small_buffer() @test
{
	char[8] buffer;
	test::@check(@catch(fbufs::encode_user_auth(&buffer, "ada", "difference-engine")) == fbufs::BUFFER_OVERFLOW);
}

fn void test_user_signup_decoding_uses_the_generated_schema() @test
{
	char[] encoded = hex::tdecode(
		(char[])"10000000424b555308000c000800040008000000080000000c00000001000000620000000100000061000000"
	)!!;
	fbufs::UserSignup message = fbufs::decode_user_signup(encoded)!!;
	test::eq(message.username, "a");
	test::eq(message.password, "b");
}

fn void test_user_signup_decoding_verifies_the_buffer() @test
{
	char[] encoded = hex::tdecode((char[])"10000000424b5553")!!;
	test::@check(@catch(fbufs::decode_user_signup(encoded)) == fbufs::INVALID_BUFFER);
}

fn void test_hydration_message_decoding_uses_the_generated_schema() @test
{
	char[] encoded = hex::tdecode((char[])"10000000424b484d000006000800040006000000040000000300000061646100")!!;
	fbufs::HydrationMessage message = fbufs::decode_hydration_message(encoded)!!;
	test::eq(message.name, "ada");
}

fn void test_hydration_message_decoding_verifies_the_buffer() @test
{
	char[] encoded = hex::tdecode((char[])"10000000424b484d")!!;
	test::@check(@catch(fbufs::decode_hydration_message(encoded)) == fbufs::INVALID_BUFFER);
}