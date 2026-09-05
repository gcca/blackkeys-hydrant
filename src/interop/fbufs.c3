module fbufs;

import std::core::cinterop;

faultdef BUFFER_OVERFLOW, ENCODE_FAILED, INVALID_BUFFER;

const CInt STATUS_OK @private               = 0;
const CInt STATUS_BUFFER_TOO_SMALL @private = 1;

struct UserSignup
{
	String username;
	String password;
}

struct UserSignupRaw @private
{
	char* username;
	usz username_size;
	char* password;
	usz password_size;
}

struct HydrationMessage
{
	String name;
}

struct HydrationMessageRaw @private
{
	char* name;
	usz name_size;
}

extern fn CInt _user_auth_encode(
	char* output,
	usz output_capacity,
	char* username,
	usz username_size,
	char* password,
	usz password_size,
	usz* output_size
) @cname("blackkeys_user_auth_encode") @private;
extern fn CInt _user_signup_has_identifier(
	char* buffer,
	usz size
) @cname("blackkeys_user_signup_has_identifier") @private;
extern fn CInt _user_signup_decode(
	char* buffer,
	usz size,
	UserSignupRaw* message
) @cname("blackkeys_user_signup_decode") @private;
extern fn CInt _hydration_message_has_identifier(
	char* buffer,
	usz size
) @cname("blackkeys_hydration_message_has_identifier") @private;
extern fn CInt _hydration_message_decode(
	char* buffer,
	usz size,
	HydrationMessageRaw* message
) @cname("blackkeys_hydration_message_decode") @private;

fn char[]? encode_user_auth(char[] buffer, String username, String password)
{
	usz output_size;
	CInt status = _user_auth_encode(
		buffer.ptr,
		buffer.len,
		username.ptr,
		username.len,
		password.ptr,
		password.len,
		&output_size
	);
	if (status == STATUS_BUFFER_TOO_SMALL) return BUFFER_OVERFLOW~;
	if (status != STATUS_OK) return ENCODE_FAILED~;
	return buffer[:output_size];
}

fn bool user_signup_has_identifier(char[] buffer) => _user_signup_has_identifier(buffer.ptr, buffer.len) != 0;

fn UserSignup? decode_user_signup(char[] buffer)
{
	UserSignupRaw message;
	if (_user_signup_decode(buffer.ptr, buffer.len, &message) != STATUS_OK) return INVALID_BUFFER~;
	return {
		.username = (String)message.username[:message.username_size],
		.password = (String)message.password[:message.password_size]
	};
}

fn bool hydration_message_has_identifier(
	char[] buffer
) => _hydration_message_has_identifier(buffer.ptr, buffer.len) != 0;

fn HydrationMessage? decode_hydration_message(char[] buffer)
{
	HydrationMessageRaw message;
	if (_hydration_message_decode(buffer.ptr, buffer.len, &message) != STATUS_OK) return INVALID_BUFFER~;
	return { .name = (String)message.name[:message.name_size] };
}