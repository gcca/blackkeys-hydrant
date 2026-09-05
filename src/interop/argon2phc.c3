module argon2phc;

import std::core::cinterop;
import std::crypto::entropy;

faultdef HASH_FAILED;

const CInt OK      = 0;
const CInt TYPE_ID = 2;

struct Options
{
	uint memory_kib;
	uint iterations;
	uint lanes;
	usz salt_size;
	usz hash_size;
}

const Options DEFAULT_OPTIONS = { .memory_kib = 65536, .iterations = 3, .lanes = 4, .salt_size = 16, .hash_size = 32 };

extern fn CInt _id_hash_encoded(
	CUInt t_cost,
	CUInt m_cost,
	CUInt parallelism,
	void* pwd,
	usz pwdlen,
	void* salt,
	usz saltlen,
	usz hashlen,
	char* encoded,
	usz encodedlen
) @cname("argon2id_hash_encoded");
extern fn CInt _id_verify(ZString encoded, void* pwd, usz pwdlen) @cname("argon2id_verify");
extern fn usz _encodedlen(
	CUInt t_cost,
	CUInt m_cost,
	CUInt parallelism,
	CUInt saltlen,
	CUInt hashlen,
	CInt type
) @cname("argon2_encodedlen");
extern fn ZString _error_message(CInt code) @cname("argon2_error_message");

fn String error_message(CInt code) => _error_message(code).str_view();

fn String? hash_with_salt(
	Allocator allocator,
	String password,
	char[] salt,
	Options options = DEFAULT_OPTIONS
) => @pool()
{
	usz encoded_size = _encodedlen(
		options.iterations,
		options.memory_kib,
		options.lanes,
		(CUInt)salt.len,
		(CUInt)options.hash_size,
		TYPE_ID
	);
	char[] encoded = alloc::alloc_array(tmem, char, (sz)encoded_size);

	CInt code = _id_hash_encoded(
		options.iterations,
		options.memory_kib,
		options.lanes,
		password.ptr,
		password.len,
		salt.ptr,
		salt.len,
		options.hash_size,
		encoded.ptr,
		encoded.len
	);
	if (code != OK) return HASH_FAILED~;

	return ((ZString)encoded.ptr).copy(allocator);
}

fn String? hash(Allocator allocator, String password, Options options = DEFAULT_OPTIONS) => @pool()
{
	char[] salt = alloc::alloc_array(tmem, char, (sz)options.salt_size);
	entropy::fill(salt)!;
	return hash_with_salt(allocator, password, salt, options);
}

fn bool verify(String encoded, String password) => @pool()
{
	return _id_verify(encoded.zstr_tcopy(), password.ptr, password.len) == OK;
}