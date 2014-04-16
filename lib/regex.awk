#!/usr/bin/gawk -f

BEGIN {
  FPAT="(^:s)|((\\\\)*.)|([giI]+\\s*$)"
  illegalEscapes="[afnrvcdox]"
}

$1 == ":s" && length($2) == 1 {
  if($NF ~ /((gI?)|(Ig?))\s*/) {
    flags = ""
    if($NF ~ /[iI]/) {
      flags = flags "I"
    }
    if($NF ~ /g/) {
      flags = flags "g"
    }
    end = NF - 1
  }
  else if($NF == $2) {
    flags=""
    end = NF
  }
  else {
    next
  }
  search = ""
  searchDone = 0
  replace = ""
  replaceDone = 0


  for(i = 3; i <= end; i++) {
    if(length($i) > 1)
    {
      slashes = ""
      if(length($i) % 2 == 1) {
        slashes = substr($i,1,length($i) - 1)
        c = substr($i,length($i)) 
      }
      else
      {
        lastChar = substr($i,length($i)) 
        if(lastChar ~ illegalEscapes)
        {
          slashes = substr($i,1,length($i) - 1) "\\"
          c = lastChar
        }
        else {
         c = substr($i,length($i) - 1)
          if(length($i) > 2) {
            slashes = substr($i,1,length($i) - 2)
          }
        }
      }

      if(searchDone) {
        replace = replace slashes
      }
      else {
        search = search slashes
      }
    }
    else {
      c = $i
    }
    if(c == $2) {
      if(searchDone) {
        if(i == end) {
          replaceDone = 1
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
    else if(searchDone) {
      replace = replace c
    }
    else {
      search = search c
    }
  }

  if(replaceDone) {
    printf("s%s%s%s%s%s%s\n",$2,search,$2,replace,$2,flags)
  }
}
