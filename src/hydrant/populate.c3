module hydrant::populate;

import argon2phc;
import hydrant::conf;
import hydrant::simulation;
import hydrant::userauth;
import cache;
import std::core::cinterop;
import std::io;

const sz RECORD_SIZE = 512;

struct Record
{
	String key;
	char[] value;
}

struct Report
{
	sz stored;
	sz failed;
	bool flush_failed;
}

fn String? hash_password(Allocator allocator, String password, conf::Settings settings)
{
	argon2phc::Options options = {
		...argon2phc::DEFAULT_OPTIONS,
		.memory_kib = settings.memory_kib,
		.iterations = settings.iterations,
		.lanes = settings.lanes
	};
	return argon2phc::hash(allocator, password, options);
}

fn Record? build(Allocator allocator, simulation::Credential credential, conf::Settings settings) => @pool()
{
	char[RECORD_SIZE] buffer;

	String password = hash_password(tmem, credential.password, settings)!;
	char[] value    = userauth::encode(&buffer, credential.username, password)!;

	return { .key = userauth::key(allocator, credential.username)!, .value = alloc::clone_slice(allocator, value) };
}

fn Record[] prepare(Allocator allocator, conf::Settings settings) => @pool()
{
	simulation::Credential[] credentials = simulation::roster(tmem, settings.generated_users);
	Record[] records                     = alloc::alloc_array(allocator, Record, (sz)credentials.len);
	sz prepared                          = 0;

	foreach (credential : credentials)
	{
		Record? record = build(allocator, credential, settings);
		if (catch excuse = record)
		{
			io::eprintfn("hydrant: skipped '%s': %s", credential.username, excuse);
			continue;
		}
		records[prepared++] = record;
	}

	return records[:prepared];
}

fn Report publish(cache::Client client, Record[] records, conf::Settings settings)
{
	Report report;

	foreach (record : records)
	{
		CInt code = client.set(record.key, record.value, (CUInt)settings.expiration_seconds);
		if (code != cache::SUCCESS)
		{
			io::eprintfn("hydrant: store failed for '%s': %s", record.key, client.strerror(code));
			report.failed++;
			continue;
		}
		report.stored++;
	}

	CInt code = client.flush_buffers();
	if (code != cache::SUCCESS)
	{
		io::eprintfn("hydrant: flush failed: %s", client.strerror(code));
		report.flush_failed = true;
	}

	return report;
}