#!/usr/bin/gawk -f

@include "join.awk"
BEGIN {
  true = 1
  false = 0
  RS="\0"
  FPAT="([\"'[:space:]\\\\])|([^\"'[:space:]\\\\]+)"
}

{
  escaped = false
  singleQuoted = false
  doubleQuoted = false
  currentIndex = 0
  items[0] = ""
  for(i = 1; i <= NF; i++) {
    if ($i == "\\") {
      if (escaped) {
        items[currentIndex] = items[currentIndex] $i
        escaped = false
      }
      else {
        escaped = true
      }
    }
    else if ($i == "'") {
      if (escaped) {
        if (doubleQuoted) {
          items[currentIndex] = items[currentIndex] "\\"
        }
        items[currentIndex] = items[currentIndex] $i
        escaped = false
      }
      else if (doubleQuoted) {
        items[currentIndex] = items[currentIndex] $i
      }
      else {
        singleQuoted = ! singleQuoted
      }
    }
    else if ($i == "\"") {
      if (escaped) {
        if (singleQuoted) {
          items[currentIndex] = items[currentIndex] "\\"
        }
        items[currentIndex] = items[currentIndex] $i
        escaped = false
      }
      else if (singleQuoted) {
        items[currentIndex] = items[currentIndex] $i
      }
      else {
        doubleQuoted = ! doubleQuoted
      }
    } else if ($i ~ /[[:space:]]/) {
      if (escaped) {
        items[currentIndex] = items[currentIndex] $i
        escaped = false
      }
      else if (singleQuoted || doubleQuoted) {
        items[currentIndex] = items[currentIndex] $i
      }
      else {
        currentIndex++
        while (i < NF && $(i+1) ~ /[[:space:]]/) {
          i++
        }
      }
    }
    else {
      if (escaped) {
        items[currentIndex] = items[currentIndex] "\\"
        escaped = false
      }
      items[currentIndex] = items[currentIndex] $i
    }
  }
  print join(items,0,length(items),"\0")
} 
