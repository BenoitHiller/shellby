#!/usr/bin/awk -f

BEGIN {
  i = 2
  lineNumber["{"] = 1
  lineNumber["}"] = 2
}

{
  if (last != "") {
    if (last == "{" && $0 == "}") {
      # empty entry. Skip this line and next.
      getline
      next
    }
    key = last " " $0
    transitions[key] += 1
  }

  totals[last] += 1
  last = $0
  if (!(last ~ /[{}]/) && !(last in lineNumber)) {
    i += 1
    lineNumber[last] = i
  }
}

END {
  for (word in lineNumber) {
    line = lineNumber[word]
    outputs[line][0] = word ":" totals[word]
  }

  for (transition in transitions) {
    split(transition, parts, " ")
    from = parts[1]
    to = parts[2]
    line = lineNumber[from]
    outputs[line][length(outputs[line])] = lineNumber[to] ":" transitions[transition]
  }

  for (i = 1; i < length(lineNumber); i+=1) {
    printf("%s", outputs[i][0])
    for (j = 1; j < length(outputs[i]); j+=1) {
      printf(" %s", outputs[i][j])
    }
    printf("\n")
  }
}
