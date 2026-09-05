module usersignup_test;

import fbufs;
import hydrant::consumers::usersignup;
import std::core::test;
import std::encoding::hex;

fn char[] decode_hex(String encoded) @private => hex::tdecode((char[])encoded)!!;

fn void test_decodes_a_blackkeys_signup_message() @test
{
	char[] body = decode_hex(
		"10000000424b555308000c00080004000800000008000000180000000d000000636f727265637420686f7273650000000300000061646100"
	);

	usersignup::Message message = usersignup::decode(body)!!;
	test::eq(message.username, "ada");
	test::eq(message.password, "correct horse");
}

fn void test_decodes_single_character_fields() @test
{
	char[] body = decode_hex(
		"10000000424b555308000c000800040008000000080000000c00000001000000620000000100000061000000"
	);

	usersignup::Message message = usersignup::decode(body)!!;
	test::eq(message.username, "a");
	test::eq(message.password, "b");
}

fn void test_decodes_across_the_alignment_boundary() @test
{
	char[] body = decode_hex(
		"10000000424b555308000c00080004000800000008000000480000003d0000007070707070707070707070707070707070707070707070" "70707070707070707070707070707070707070707070707070707070707070707070707070700000000300000061646100"
	);

	usersignup::Message message = usersignup::decode(body)!!;
	test::eq(message.username, "ada");
	test::@check(message.password.len == 61);
}

fn void test_user_auth_record_is_not_a_signup_message() @test
{
	char[] body = decode_hex(
		"10000000424b554108000c000800040008000000080000000c00000001000000620000000100000061000000"
	);

	test::@check(@catch(usersignup::decode(body)) == usersignup::UNKNOWN_IDENTIFIER);
}

fn void test_garbage_is_rejected() @test
{
	char[32] body;
	test::@check(@catch(usersignup::decode(&body)) == usersignup::UNKNOWN_IDENTIFIER);
	test::@check(@catch(usersignup::decode(body[:2])) == usersignup::UNKNOWN_IDENTIFIER);
	test::@check(@catch(usersignup::decode({ })) == usersignup::UNKNOWN_IDENTIFIER);
}

fn void test_truncated_message_is_rejected() @test
{
	char[] body = decode_hex(
		"10000000424b555308000c000800040008000000080000000c00000001000000620000000100000061000000"
	);

	test::@check(@catch(usersignup::decode(body[:24])) == fbufs::INVALID_BUFFER);
}

fn void test_missing_field_is_rejected() @test
{
	char[] body = decode_hex("10000000424b5553000006000800040006000000040000000100000061000000");
	test::@check(@catch(usersignup::decode(body)) == fbufs::INVALID_BUFFER);
}