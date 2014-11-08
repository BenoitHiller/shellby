# Verify that a user is in the admin list
#
# 1.nickname
# 2.username
# 3.hostname
# 4.nickserv
verify() {
  local nickname="$1"
  local username="$2"
  local hostname="$3"
  local nickserv="$4"

  if [[ -f "$botConfig/etc/admins" ]]; then
    grep -q -i -f "$botConfig/etc/admins" <<< "$nickserv!$nickname!$username@$hostname"
    return $?
  else
    return 1
  fi
}
