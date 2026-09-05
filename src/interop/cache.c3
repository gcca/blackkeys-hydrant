module cache;

import std::core::cinterop;

faultdef CONNECT_FAILED;

const CInt SUCCESS = 0;

typedef Client = void*;

extern fn Client _create(ZString nodes) @cname("cache_client_create");
extern fn void Client.destroy(self) @cname("cache_client_destroy");
extern fn CInt Client.node_count(self) @cname("cache_client_node_count");
extern fn CInt Client._set(
	self,
	char* key,
	usz key_length,
	char* value,
	usz value_length,
	CUInt expiration
) @cname("cache_client_set");
extern fn CInt Client._flush_buffers(self) @cname("cache_client_flush_buffers");
extern fn ZString Client._strerror(self, CInt code) @cname("cache_client_strerror");

fn bool Client.is_valid(self) => (void*)self != null;

fn Client? create(String nodes) => @pool()
{
	Client client = _create(nodes.zstr_tcopy());
	if (!client.is_valid()) return CONNECT_FAILED~;
	return client;
}

fn CInt Client.set(
	self,
	String key,
	char[] value,
	CUInt expiration = 0
) => self._set(key.ptr, key.len, value.ptr, value.len, expiration);

fn CInt Client.flush_buffers(self) => self._flush_buffers();

fn String Client.strerror(self, CInt code) => self._strerror(code).str_view();