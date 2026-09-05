module hydrant::simulation;

struct Credential
{
	String username;
	String password;
}

const Credential[] ROSTER = {
	{ "jill.valentine", "stars" },
	{ "chris.redfield", "stars" },
	{ "barry.burton", "stars" },
	{ "rebecca.chambers", "stars" },
	{ "albert.wesker", "stars" },
	{ "enrico.marini", "stars" },
	{ "forest.speyer", "stars" }
};

fn Credential[] roster(Allocator allocator, uint generated)
{
	Credential[] credentials = alloc::alloc_array(allocator, Credential, ROSTER.len + generated);
	foreach (index, credential : ROSTER) credentials[index] = credential;
	for (uint index = 0; index < generated; index++)
	{
		credentials[ROSTER.len
			+ index] = {
				.username = string::format(allocator, "sim-user-%06d", index),
				.password = string::format(allocator, "sim-secret-%06d", index)
			};
	}
	return credentials;
}