
testTrivial() {
  echo a | reloadable "$testDir/trivial.bash" > "$tmpDir/1.out" &
  local process="$!"
  for ((i=5; i > 0; i--)); do
    if cmp -s "$testDir/trivial.out" "$tmpDir/1.out"; then
      killtree "$process"
      return 0
    else
      sleep 1
    fi
  done
  killtree "$process"
  assertFail
}
addTest testTrivial

testSwitch() {
  cp "$testDir/switch1.bash" "$tmpDir/switch.bash"
  chmod +x "$tmpDir/switch.bash"
  for ((i=16; i > 0; i--)); do echo a; sleep 1; done | reloadable "$tmpDir/switch.bash" > "$tmpDir/2.out" &
  local process="$!"
  sleep 1
  cat <"$testDir/switch2.bash" >"$tmpDir/switch.bash"

  for ((i=15; i > 0; i--)); do
    if cmp -s "$testDir/switch.out" "$tmpDir/2.out"; then
      killtree "$process"
      return 0
    else
      sleep 1
    fi
  done
  killtree "$process"
  assertFail
}
addTest testSwitch
