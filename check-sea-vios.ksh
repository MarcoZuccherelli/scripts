#!/usr/bin/ksh
# Check stato ha_mode delle SEA dei vios
# $1 -  nome macchina corto tutto minuscolo(Es. rogo)

#set -x
# Aggiorno la lista delle LPAR per la macchina passata come parametro
./crea-lista-lpar $1

infile=lpar/$1
if [[ -n $infile ]]
  then
    while read line; do
      macc=$(echo $line | awk '{print $1}')
      os=$(echo $line | awk '{print $2}')
      if [[ $os == vios ]]; then
        printf "%s \n" "$macc "
        ssh -T padmin@$macc < hamode-sea-vios
      fi
    done < $infile
  else
    echo "missing infile"
    exit 1
fi
