testAssertPass() {
  (assertEquals "a" "a")
  assertSuccess
  (assertEquals "" "") 
  assertSuccess

  (assertDiff <(echo a) <(echo a))
  assertSuccess
}
addTest testAssertPass

testAssertFail() {
  (assertEquals "a" "b") &>/dev/null
  assertFailed
  (assertEquals "a" "") &>/dev/null
  assertFailed

  (assertDiff <(echo a) <(echo b)) &>/dev/null
  assertFailed
}
addTest testAssertFail
