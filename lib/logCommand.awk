#!/usr/bin/awk -f
BEGIN {
  FPAT="(\\s:.*$)|(\\S+)"
  IGNORECASE = 1
}

function logLine(user,action,message,channel) {
  sub(/^:/,"",user)
  sub(/\r/,"",message)

  if(length(channel) == 0) {
    dir=logDir strftime("%Y/%m")
  }
  else {
    dir=logDir channel strftime("/%Y/%m")
  }

  system("mkdir -p " dir)
  file=dir "/" strftime("%d")
  printf("%s: %s %s: %s\n", strftime("%H:%M:%S%z"),user,action,message) >> file
  fflush(file)
}

/^\S+\s+privmsg\s/ {
  message=substr($4,3)
  if(message ~ /ACTION.*$/) {
    action = "ACTION"
    sub(/^ACTION\s/,"",message)
    sub(/$/,"",message)
  }
  else {
    action = ""
  }
  logLine($1,action,message,$3)
}

/^\S+\s+(part|join)\s/ {
  message=substr($4,3)
  logLine($1,$2,message,$3)
}

/^\S+\s+kick\s/ {
  message=substr($5,3)
  formattedMessage=$4 " reason: " message
  logLine($1,$2,formattedMessage,$3)
}

/^\S+\s+quit\s/ {
  message=substr($3,3)
  logLine($1,$2,message,"")
}

/^\S+\s+nick\s/ {
  message=substr($3,3)
  user=$1
  sub(/^:/,"",user)
  nick=user
  sub(/!.*$/,"",nick)
  formattedMessage=nick " -> " message
  logLine($1,$2,formattedMessage,"")
}

/^\S+\s+kill\s/ {
  message=substr($4,3)
  formattedMessage=$3 " reason: " message
  logLine($1,$2,formattedMessage,"")
}
