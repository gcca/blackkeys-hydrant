module cache_test;

import cache;
import std::core::test;

fn void test_single_node_list() @test
{
	cache::Client client = cache::create("127.0.0.1:11211")!!;
	defer client.destroy();
	test::eq(client.node_count(), 1);
}

fn void test_ordered_node_list_with_spaces() @test
{
	cache::Client client = cache::create("127.0.0.1:11211, 127.0.0.1:11212 ,127.0.0.1:11213")!!;
	defer client.destroy();
	test::eq(client.node_count(), 3);
}

fn void test_node_without_a_port_uses_the_default() @test
{
	cache::Client client = cache::create("127.0.0.1")!!;
	defer client.destroy();
	test::eq(client.node_count(), 1);
}

fn void test_empty_node_list_is_rejected() @test
{
	test::@check(@catch(cache::create("")) == cache::CONNECT_FAILED);
}

fn void test_blank_node_in_the_list_is_rejected() @test
{
	test::@check(@catch(cache::create("127.0.0.1:11211,,127.0.0.1:11212")) == cache::CONNECT_FAILED);
}

fn void test_non_numeric_port_is_rejected() @test
{
	test::@check(@catch(cache::create("127.0.0.1:cache")) == cache::CONNECT_FAILED);
}

fn void test_out_of_range_port_is_rejected() @test
{
	test::@check(@catch(cache::create("127.0.0.1:70000")) == cache::CONNECT_FAILED);
}

fn void test_strerror_describes_success() @test
{
	cache::Client client = cache::create("127.0.0.1:11211")!!;
	defer client.destroy();
	test::eq(client.strerror(cache::SUCCESS), "SUCCESS");
}