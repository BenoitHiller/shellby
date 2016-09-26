testWrap() {
  bufferDir="$tmpDir"
  export bufferDir
  mkdir "$bufferDir/etc"
  echo "test" | tee "$bufferDir/etc/"{nickname,username,hostname}
  wrap <"$testDir/input1" >"$tmpDir/output1"
  assertDiff "$testDir/expected1" "$tmpDir/output1"
}

addTest testWrap
