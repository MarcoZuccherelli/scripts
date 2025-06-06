#!/usr/bin/ksh
# Crea un file con la lista delle lpar per power
# Se viene passato un parametro viene interpretato come nome power da cui
# generare la lista delle lpar, se vuoto crea i file per tutti i power
# $1 - nome macchina corto tutto minuscolo(Es. rogo) oppure vuoto (tutte le macchine)

hmc_list=$(cat hmc)
power=$1
for hmc in $hmc_list; do
  if [[ -z $power ]]; then
    machine_names=$( ssh hscroot@${hmc} 'lssyscfg -r sys -F name' )
  else
    machine_names=$( ssh hscroot@${hmc} 'lssyscfg -r sys -F name' | grep -i $power)
  fi
  for p in $machine_names; do
    file=$( echo $p | sed "s/^.*bo[12]//" | tr "[A-Z]" "[a-z]" )
    ssh hscroot@${hmc} "lssyscfg -r lpar -m $p -F name os" > lpar/${file}
  done
done
