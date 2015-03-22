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

  if [[ -z "$nickname" ]]; then
    return 1
  fi

  local userDir="$bufferDir/etc/users/$nickname"

  if [[ -s "$userDir/username" ]]; then
    if [[ -n "$username" ]]; then
      if ! grep -Fqx "$username" "$userDir/username"; then
        return 1
      fi
    else
      username="$(< "$userDir/username")"
    fi
  fi

  if [[ -s "$userDir/hostname" ]]; then
    if [[ -n "$hostname" ]]; then
      if ! grep -Fqx "$hostname" "$userDir/hostname"; then
        return 1
      fi
    else
      hostname="$(< "$userDir/hostname")"
    fi
  fi

  if [[ -s "$userDir/nickserv" ]]; then
    if [[ -n "$nickserv" ]]; then
      if ! grep -Fqx "$nickserv" "$userDir/nickserv"; then
        return 1
      fi
    else
      nickserv="$(< "$userDir/nickserv")"
    fi
  fi

  if [[ -f "$botConfig/etc/admins" ]]; then
    grep -q -i -f "$botConfig/etc/admins" <<< "$nickserv!$nickname!$username@$hostname"
    return $?
  else
    return 1
  fi
}

# Verify that a user is an op in a channel
#
# 1.nickname
# 2.channel
# 3.username
# 4.hostname
isOp() {
  local nickname="$1"
  local channel="$2"
  local username="$3"
  local hostname="$4"

  local userDir="$bufferDir/etc/users/$nickname"
  
  if [[ -n "$username" && -f "$userDir/username" ]]; then
    if ! grep -Fqx "$username" "$userDir/username"; then
      return 1
    fi
  fi

  if [[ -n "$hostname" && -f "$userDir/hostname" ]]; then
    if ! grep -Fqx "$hostname" "$userDir/hostname"; then
      return 1
    fi
  fi

  if [[ -s "$userDir/channels/$channel/op" ]]; then
    return 0
  else
    return 1
  fi
}
