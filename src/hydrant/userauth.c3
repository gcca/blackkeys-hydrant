module hydrant::userauth;

import fbufs;

faultdef EMPTY_PASSWORD, EMPTY_USERNAME, KEY_TOO_LONG, UNSUPPORTED_USERNAME;

const String KEY_PREFIX  = "auth:user:";
const usz MAX_KEY_LENGTH = 250;

fn void? validate(String username)
{
	if (!username.len) return EMPTY_USERNAME~;
	foreach (character : username)
	{
		if (character <= 32 || character == 127) return UNSUPPORTED_USERNAME~;
	}
	if (KEY_PREFIX.len + username.len > MAX_KEY_LENGTH) return KEY_TOO_LONG~;
}

fn String? key(Allocator allocator, String username)
{
	validate(username)!;
	return string::format(allocator, "%s%s", KEY_PREFIX, username);
}

fn char[]? encode(char[] buffer, String username, String password)
{
	validate(username)!;
	if (!password.len) return EMPTY_PASSWORD~;
	return fbufs::encode_user_auth(buffer, username, password);
}