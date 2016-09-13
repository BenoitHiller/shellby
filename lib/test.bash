setUpTests() {
  declare -i testsRun=0
  declare -i testsSucceeded=0
  declare -a tests
}

runTest() {
  local -r command="$1"

  local tmpDir="$(mktemp -p "$TMPDIR" -d test.XXXXXX)"
  local tmpOut="$tmpDir/out"
  local tmpErr="$tmpDir/err"
  ((testsRun++))
  if ("$command"); then
    ((testsSucceeded++))
  else
    cat "$tmpErr" >&2
    if [[ -s "$tmpOut" ]]; then
      printf "Test output\n===========\n" >&2
      cat "$tmpOut" >&2
      printf "===========\n" >&2
    fi
    printf "\n" >&2
  fi
  rm -r "$tmpDir"
}

addTest() {
  tests+=( "$1" )
}

runTests() {
  for test in "${tests[@]}"; do
    runTest "$test"
  done
}

newSuite() {
  tests=( )
}

getTestResults() {
  printf "Tests run:\t%d\nTests passed:\t%d\nTests failed:\t%d\n" "$testsRun" "$testsSucceeded" "$((testsRun - testsSucceeded))" >&2
  return "$((testsRun - testsSucceeded != 0))"
}

fail() {
  printf "Failed to run test:\n\t" >>"$tmpErr"
  caller 1 >>"$tmpErr"
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
  if ! diff "$expectedFile" "$actualFile" >>"$tmpOut"; then
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
