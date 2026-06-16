#!/bin/bash

# THIS IS A PLACEHOLDER FILE WITH PSEUDOCODE TO CLARIFY SCRIPT BEHAVIOUR
#
#
# Set SHARD_COUNT variable from SHARD_ARGS exported one
#
# check if we have more than 1 shard
#
# run openshift-tests ${TEST_SUITE} --dry-run > /tmp/mco_tests.txt to get the entire MCO test list
#
# Query Sippy to get last test durations (i.e last 5 occurrencies), get the mean value and save it to a file "all_tests.txt"
# i.e. "https://sippy.dptools.openshift.org/api/tests/durations?release=${SIPPY_RELEASE}&test=${encoded_test_name}"
#
#
# mkdir /tmp/duration and for each test inside "all_tests.txt" file assign that test to an available shard
# (An idea to fulfill shards could be add tests to the first available shard with the capability in terms of time to accept that test)
# Use a file for each shard.
#
