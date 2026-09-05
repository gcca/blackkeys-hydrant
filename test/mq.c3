module mq_test;

import mq;
import std::core::test;

fn void test_single_node() @test
{
	test::@check(mq::nodes_valid("127.0.0.1:5672"));
}

fn void test_ordered_node_list_with_spaces() @test
{
	test::@check(mq::nodes_valid("mq-a:5672, mq-b:5673 ,mq-c:5674"));
}

fn void test_node_without_a_port_uses_the_default() @test
{
	test::@check(mq::nodes_valid("mq-a"));
}

fn void test_empty_node_list_is_rejected() @test
{
	test::@check(!mq::nodes_valid(""));
}

fn void test_blank_node_in_the_list_is_rejected() @test
{
	test::@check(!mq::nodes_valid("mq-a:5672,,mq-b:5672"));
}

fn void test_non_numeric_port_is_rejected() @test
{
	test::@check(!mq::nodes_valid("mq-a:port"));
}

fn void test_out_of_range_port_is_rejected() @test
{
	test::@check(!mq::nodes_valid("mq-a:70000"));
}

fn void test_invalid_configuration_has_an_error() @test
{
	mq::Consumer consumer = mq::create("mq-a:70000", "guest", "guest", "/", "queue")!!;
	defer consumer.destroy();
	test::@check(!consumer.is_connected());
	test::eq(consumer.error(), "invalid MQ configuration");
}