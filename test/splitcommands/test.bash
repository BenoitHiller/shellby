testAdd() {
  bufferDir="$tmpDir"
  export bufferDir
  mkdir "$tmpDir/listeners"
  cp "$testDir/add1" "$tmpDir/listeners"

  mkfifo "$tmpDir/input"
  splitcommands "$tmpDir/listeners" <"$tmpDir/input" >"$tmpDir/output" &
  local -i pid="$!"
  exec 3>"$tmpDir/input"
  echo 3 >&3
  local -i count=0
  while ! diff "$testDir/before1" "$tmpDir/output"; do
    if ((count++ > 5)); then
      kill -TERM "$pid"
      fail
    else
      sleep 0.5
    fi
  done

  cp "$testDir/add2" "$tmpDir/listeners"

  count=0
  while ! diff -u "$testDir/after1" "$tmpDir/output"; do
    if ((count++ > 11)); then
      kill -TERM "$pid"
      fail
    else
      sleep 0.5
    fi
  done
  echo 1 >&3

  count=0
  while ! diff "$testDir/after2" "$tmpDir/output"; do
    if ((count++ > 5)); then
      kill -TERM "$pid"
      fail
    else
      sleep 0.5
    fi
  done

  kill -TERM "$pid"
  exec 3>&-
}

addTest testAdd
