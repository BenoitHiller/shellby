BEGIN {
  FPAT="(\\s:.*$)|(\\S+)"
  IGNORECASE = 1
}

function logLine(user,action,message,channel,type) {
  sub(/^:/,"",user)
  sub(/\r/,"",message)
  split(user, userParts, "[!@]")

  if(length(channel) == 0) {
    dir=logDir "/" strftime("%Y/%m")
  }
  else {
    dir=logDir "/" channel strftime("/%Y/%m")
  }

  system("mkdir -p " dir)
  file=dir "/" strftime("%d") "_" type
  printf("%d\r%s\r%s\r%s\r%s\r%s\n", systime(),userParts[1],userParts[2],userParts[3],action,message) >> file
  fflush(file)
}

/^PRIVMSG/ {
  message=substr($3,3)

  logLine(shellbyHostname, "message", message, $2, "message") 
}

/^\S+\s+privmsg\s/ {
  message=substr($4,3)
  if(message ~ /ACTION.*$/) {
    action = "action"
    sub(/^ACTION\s/,"",message)
    sub(/$/,"",message)
  }
  else {
    action = "message"
  }

  logLine($1,action,message,$3,"message")
}

/^\S+\s+notice\s/ {
  message=substr($4,3)

  logLine($1,"notice",message,$3,"message")
}

/^\S+\s+(part|join)\s/ {
  message=substr($4,3)
  logLine($1,tolower($2),message,$3, "user")
}

/^\S+\s+kick\s/ {
  message=substr($5,3)
  formattedMessage=$4 " reason: " message
  logLine($1,"kick",formattedMessage,$3, "user")
}

/^\S+\s+quit\s/ {
  message=substr($3,3)
  logLine($1,"quit",message,"","all")
}

/^\S+\s+nick\s/ {
  message=substr($3,3)
  user=$1
  sub(/^:/,"",user)
  nick=user
  sub(/!.*$/,"",nick)
  logLine($1,"nick",message,"","all")
}

/^\S+\s+kill\s/ {
  message=substr($4,3)
  formattedMessage=$3 "\r" message
  logLine($1,$2,formattedMessage,"","all")
}
