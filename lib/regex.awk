#!/usr/bin/gawk -f

BEGIN {
  FPAT="(^:s)|((\\\\)*.)|([giI]+\\s*$)"
  illegalEscapes="[afnrvcdox]"
}


$1 == ":s" && length($2) == 1 {
  flags = ""
  if($NF ~ /((gI?)|(Ig?))\s*/) {
    if($NF ~ /[iI]/) {
      flags = flags "I"
    }
    if($NF ~ /g/) {
      flags = flags "g"
    }
    end = NF - 1
  }
  else if($NF == $2) {
    # we con't have any flags
    end = NF
  }
  else {
    # the command is not terminated correctly
    next
  }

  expression = "s"$2
  searchDone = 0


  for(i = 3; i <= end; i++) {
    # If this token has preceeding backslashes
    if(length($i) > 1)
    {
      # If there is an even number of backslashes
      if(length($i) % 2 == 1) {
        expression = expression substr($i,1,length($i) - 1)
        c = substr($i,length($i)) 
      }
      else
      {
        lastChar = substr($i,length($i)) 
        # if we want to double escape the sequence to prevent issues
        if(lastChar ~ illegalEscapes)
        {
          expression = expression substr($i,1,length($i) - 1) "\\"
          c = lastChar
        }
        # if we want to include the escape sequence
        else {
          c = substr($i,length($i) - 1)
          if(length($i) > 2) {
            expression = expression substr($i,1,length($i) - 2)
          }
        }
      }
    }
    else {
      c = $i
    }

    # on reading the delimiter character
    if(c == $2) {
      # check if we are in the search or the replacement
      if(searchDone) {
        # if we are in the replcaement check if we terminated correctly
        if(i == end) {
          print expression c flags
          break
        }
        else {
          next
        }
      }
      else {
        searchDone = 1
      }
    }

    expression = expression c
  }
}
