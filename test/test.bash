setUpTests() {
  declare -i testsRun=0
  declare -i testsSucceeded=0
}

runTest() {
  local -r command="$1"

  ((testsRun++))
  if ("$command"); then
    ((testsSucceeded++))
  fi
}

getTestResults() {
  printf "Tests run:\t%d\nTests passed:\t%d\nTests failed:\t%d\n" "$testsRun" "$testsSucceeded" "$((testsRun - testsSucceeded))"
}

fail() {
  echo test failed >&2
  caller 1 >&2
  exit 1
}

assertFail() {
  fail
}

assertEquals() {
  local -r expected="$1"
  local -r actual="$2"
  if [[ "$expected" != "$actual" ]]; then
    fail
  fi
}

assertDiff() {
  local -r expectedFile="$1"
  local -r actualFile="$2"
  if ! cmp -s "$expectedFile" "$actualFile"; then
    fail
  fi
}

assertSuccess() {
  if (($? != 0)); then
    fail
  fi
}

assertFailed() {
  if (($? == 0)); then
    fail
  fi
}
