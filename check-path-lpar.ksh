#!/usr/bin/ksh
# Visualizza i path che non sono in stato Enable
# $1 - nome macchina corto tutto minuscolo(Es. rogo)

# Aggiorno la lista delle LPAR per la macchina passata come parametro
# ./crea-lista-lpar $1

infile=lpar/$1
if [[ -n $infile ]]
  then
    while read line; do
      macc=$(echo $line | awk '{print $1}')
      os=$(echo $line | awk '{print $2}')
      if [[ $os == aix ]]; then
        printf "%s \n" "$macc "
        ssh -T $macc < lista-path-aix
      else
        if [[ $os == 'linux' ]]; then
          printf "%s \n" "$macc "
          ssh -T $macc < lista-path-linux | grep -p 'dm-'
        fi
      fi
    done < $infile
  else
    echo "missing infile"
    exit 1
fi

