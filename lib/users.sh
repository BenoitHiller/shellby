# Verify that a user is in the admin list
#
# 1.nickname
# 2.username
# 3.hostname
# 4.nickserv
verify() {
  local nick="$1"
  local user="$2"
  local host="$3"
  local serv="$4"

  if [[ -f "$botConfig/etc/admins" ]]; then
    grep -q -i -f "$botConfig/etc/admins" <<< "$serv!$nick!$user@$host"
    return $?
  else
    return 1
  fi
}
