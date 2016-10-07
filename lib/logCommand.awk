BEGIN {
  FS="\r"
  IGNORECASE = 1
}

function logLine(user,action,message,channel,type) {
  sub(/^:/,"",user)
  sub(/\r/,"",message)
  split(user, userParts, "[!@]")

  if (length(channel) == 0) {
    dir=logDir "/" strftime("%Y/%m", systime(), 1)
  }
  else {
    dir=logDir "/" channel strftime("/%Y/%m", systime(), 1)
  }

  system("mkdir -p '" dir "'")
  file=dir "/" strftime("%d", systime(), 1) "_" type
  printf("%d\r%s\r%s\r%s\r%s\r%s\n", systime(), userParts[1], userParts[2], userParts[3], action, message) >> file
  fflush(file)
}

/^privmsg\r/ {
  message=$4
  if (message ~ /ACTION.*$/) {
    action = "action"
    sub(/^ACTION\s/,"",message)
    sub(/$/,"",message)
  }
  else {
    action = "message"
  }
  if (length($2) == 0) {
    prefix=shellbyHostname
  } else {
    prefix=$2
  }

  logLine(prefix, action, message, $3, "message")
}

/^notice\r/ {
  if (! $3 ~ /^[$*]+$/) {
    logLine($2, "notice", $4, $3, "message")
  }
}

/^(part|join)\r/ {
  logLine($2, tolower($1), $4, $3, "user")
}

/^kick\r/ {
  message=$5
  formattedMessage=$4 " reason: " message
  logLine($2, "kick", formattedMessage, $3, "user")
}

/^quit\r/ {
  logLine($2, "quit", $3, "", "all")
}

/^nick\r/ {
  message=substr($3,3)
  user=$2
  sub(/^:/,"",user)
  nick=user
  sub(/!.*$/,"",nick)
  # huh?
  logLine($2, "nick", $3, "", "all")
}

/^kill\r/ {
  message=$4
  formattedMessage=$3 "\r" message
  logLine($2, "kill", formattedMessage, "", "all")
}
