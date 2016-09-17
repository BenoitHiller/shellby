testTrivial() {
  assertDiff <( printf "TEST\r\n") <( printf "TEST\n" | delim2irc ) 
  assertDiff <( printf "\r\n") <( printf "\n" | delim2irc ) 
}

testSimple() {
  assertDiff <( printf "TEST test :test test\r\n") <( printf "TEST\r\rtest\rtest test\n" | delim2irc ) 
  assertDiff <( printf "TEST :test test\r\n" ) <( printf "TEST\r\rtest test\n" | delim2irc )
  assertDiff <( printf "TEST test test :test\r\n"  ) <( printf "TEST\r\rtest\rtest\rtest\n"| delim2irc )
}
addTest testTrivial
addTest testSimple
