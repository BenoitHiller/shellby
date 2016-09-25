source "$botLib/irc.sh"

testIRCInfo() {
  declare -a data
  data=( $(getIRCInfo "JOINshellby3!~Shellby@XXX-XXX.isp.com#shellbytest") )
  assertEquals "shellby3" "${data[0]}"
  assertEquals "#shellbytest" "${data[1]}"
  assertEquals "JOIN" "${data[2]}"
  assertEquals "~Shellby" "${data[3]}"
  assertEquals "XXX-XXX.isp.com" "${data[4]}"
}
addTest testIRCInfo
