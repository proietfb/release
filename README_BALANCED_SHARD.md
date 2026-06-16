# Balanced Shard Assignment for MCO CI Tests

## Problem

The current test-to-shard assignment algorithm (`openshift-tests` in `openshift/origin`) uses SHA-256 hashing of the test name to distribute tests across shards. This approach is duration-blind: it does not account for how long each test takes to run. When the total execution time assigned to a shard exceeds its time budget, that shard's job fails with a timeout — even if other shards finish with time to spare.

## Proposed Solution

### Test Duration Data

Sippy exposes historical test durations through its API:

```
GET https://sippy.dptools.openshift.org/api/tests/durations?release={release}&test={test_name}
```

Where `release` is the OpenShift release the test ran against and `test` is the URL-encoded test name.

Example:

```
GET https://sippy.dptools.openshift.org/api/tests/durations?release=4.19&test=%5Bsig-mco%5D%5BSuite%3Aopenshift%2Fmachine-config-operator%2Fdisruptive%5D%5BOCPFeatureGate%3AOnClusterBuild%5D%5BSerial%5D%5BDisruptive%5D%20MCO%20ocb%20PolarionID%3A83140-A%20MachineOSConfig%20with%20custom%20containerfile%20definition%20can%20be%20successfully%20applied
```

Response (average duration in seconds per day, last 14 days):

```json
{
  "2026-06-06": 2278.5,
  "2026-06-07": 2241.67,
  "2026-06-13": 2085.25,
  "2026-06-14": 2214.67
}
```

### Balanced Sharding

Using this data, a pre-step can be introduced before the test execution step. This pre-step would:

1. Run `openshift-tests run --dry-run` to obtain the full test list for the suite
2. Query the Sippy API for each test's average duration
3. Apply a capacity-aware bin-packing algorithm: sort tests by duration (longest first), then assign each test to the first shard that still has enough remaining time budget. The time budget per shard is derived from the step timeout minus a setup/teardown overhead allowance
4. Write one test list file per shard to `SHARED_DIR` (e.g. `shard-1-tests.txt`, `shard-2-tests.txt`, ...)

The test execution step then reads the file for its shard and runs `openshift-tests run --file {test_list}` without passing `--shard-count` / `--shard-id`. When these flags are absent, the hash-based sharder in `openshift-tests` is bypassed and all tests in the file are executed.

If a test does not fit in any shard, it is placed in the shard with the most remaining capacity and a warning is emitted — signaling before execution that the test suite exceeds the available budget and the shard count or timeout may need adjustment.

### Integration

Both steps live in the `openshift/release` step registry. The job config replaces the current `openshift-e2e-test` ref with the two new steps:

```yaml
# before
test:
  - ref: openshift-e2e-test

# after
test:
  - ref: mco-compute-shard-balance
  - ref: mco-e2e-test-balanced
```

A longrun variant of the test step (with a higher timeout) follows the existing `openshift-e2e-test` / `openshift-e2e-test-longrun` pattern for longduration jobs.

No changes are required in `openshift/origin` or to test names.

## Limitations

- **Sippy availability**: if Sippy is unreachable, do we fallback to default hash-based assignement? Do we threat those tests as "new test to be estimated"? (see below)
- **New tests**: tests with no execution history, will receive a default estimate? What if it is inaccurate? Could be useful find a way where the data self-corrects after that run
- **Pre-step overhead**: the dry-run and Sippy queries add wall-clock time to the job, is it accepted?
- **Metal jobs**: `baremetalds-ipi-test` chain wraps the test step; integrating balanced sharding into metal jobs requires replacing or extending the chain
