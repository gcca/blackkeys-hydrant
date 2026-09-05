module hydration_test;

import fbufs;
import hydrant::consumers::hydration;
import std::core::test;
import std::encoding::hex;

fn char[] decode_hex(String encoded) @private => hex::tdecode((char[])encoded)!!;

fn void test_decodes_a_blackkeys_hydration_message() @test
{
	char[] body = decode_hex("10000000424b484d000006000800040006000000040000000300000061646100");

	hydration::Message message = hydration::decode(body)!!;
	test::eq(message.name, "ada");
}

fn void test_decodes_single_character_fields() @test
{
	char[] body = decode_hex("10000000424b484d000006000800040006000000040000000100000061000000");

	hydration::Message message = hydration::decode(body)!!;
	test::eq(message.name, "a");
}

fn void test_user_signup_message_is_not_a_hydration_message() @test
{
	char[] body = decode_hex("10000000424b5553000006000800040006000000040000000300000061646100");

	test::@check(@catch(hydration::decode(body)) == hydration::UNKNOWN_IDENTIFIER);
}

fn void test_garbage_is_rejected() @test
{
	char[32] body;
	test::@check(@catch(hydration::decode(&body)) == hydration::UNKNOWN_IDENTIFIER);
	test::@check(@catch(hydration::decode(body[:2])) == hydration::UNKNOWN_IDENTIFIER);
	test::@check(@catch(hydration::decode({ })) == hydration::UNKNOWN_IDENTIFIER);
}

fn void test_truncated_message_is_rejected() @test
{
	char[] body = decode_hex("10000000424b484d000006000800040006000000040000000300000061646100");

	test::@check(@catch(hydration::decode(body[:24])) == fbufs::INVALID_BUFFER);
}

fn void test_missing_field_is_rejected() @test
{
	char[] body = decode_hex("0c000000424b484d0400040004000000");
	test::@check(@catch(hydration::decode(body)) == fbufs::INVALID_BUFFER);
}