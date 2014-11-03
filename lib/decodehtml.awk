#!/usr/bin/gawk -f
BEGIN {

  FPAT="[^\r]+"
  botDir = ENVIRON["botDir"]
  entityFile = botDir "/share/htmlentity.lst"

  entities["&NewLine;"]="\n"
  while (getline < entityFile) {
    entities[$1] = $2
  }

  close(entityFile)

  # change the RS and FS for the actual input processing
  RS="\0"
  FPAT="([^&;]*[&;])|([^&;]*$)"
}

{
  inEntity = 0
  for(i = 1; i <= NF ; i++ ) {
    if(length($i) > 0) {
      if(!inEntity && $i ~ /&$/) {
        inEntity = 1
        printf("%s", substr($i, 1, length($i) - 1))
      }
      else if(inEntity && $i ~ /;$/) {
        inEntity = 0
        entityString = "&" $i
        if(entityString in entities) {
          printf("%s", entities[entityString])
        }
      }
      else if(!inEntity) {
        printf("%s", $i)
      }
    }
  }
}
