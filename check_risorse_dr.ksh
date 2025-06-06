#!/usr/bin/ksh
# Calcola le risorse occupate da una lista di lpar passate come parametro.
# $1 -> lista lpar

hmc=172.28.161.50
lpar_list=$1

#Data una LPAR trova il power su cui e attestata
find_power(){
  powers=$(ssh -n hscroot@$hmc "lssyscfg -r sys -Fname")
  for power in $powers; do
    check=$(ssh -n hscroot@$hmc "lssyscfg -r lpar -m $power -Fname" | grep $lpar)
    if [[ -n $check ]]; then
      return 0
    fi
  done
  return 1
}

P880_mem_tot=0
P880_proc_unit_int_tot=0
P880_proc_unit_dec_tot=0
P880_proc_tot=0

tormenta_mem_tot=0
tormenta_proc_unit_int_tot=0
tormenta_proc_unit_dec_tot=0
tormenta_proc_tot=0

cerino_mem_tot=0
cerino_proc_unit_int_tot=0
cerino_proc_unit_dec_tot=0
cerino_proc_tot=0

saetta_mem_tot=0
saetta_proc_unit_int_tot=0
saetta_proc_unit_dec_tot=0
saetta_proc_tot=0

for lpar in $(cat ${lpar_list}); do
  find_power
  profile_name=$(ssh -n hscroot@${hmc} lssyscfg -r lpar -m $power --filter "lpar_names=$lpar" -Fcurr_profile)
  profile=$(ssh -n hscroot@${hmc} lssyscfg -r prof -m $power --filter "lpar_names=$lpar,profile_names=${profile_name}" -Fdesired_mem:desired_proc_units)

  desired_mem=$(echo ${profile} | cut -f 1 -d ":")
  desired_proc_units=$(echo ${profile} | cut -f 2 -d ":")
  #echo "desired_mem --> ${desired_mem}"
  #echo "desired_proc_unit --> ${desired_proc_unit}"

  case ${power} in
    "Server-9080-MHE-SN780F028")
      P880_mem_tot=$(( ${P880_mem_tot} + ${desired_mem} ))
      P880_proc_unit_int=$(echo ${desired_proc_units} | cut -f "1" -d ".")
      P880_proc_unit_dec=$(echo ${desired_proc_units} | cut -f "2" -d ".")
      #echo "P880_proc_unit_int --> ${P880_proc_unit_int}"
      #echo "P880_proc_unit_dec --> ${P880_proc_unit_dec}"
      P880_proc_unit_int_tot=$(( ${P880_proc_unit_int_tot} + ${P880_proc_unit_int} ))
      P880_proc_unit_dec_tot=$(( ${P880_proc_unit_dec_tot} + ${P880_proc_unit_dec} ))
      ;;
    "9009-42A-AxugPDTormenta")
      tormenta_mem_tot=$(( ${tormenta_mem_tot} + ${desired_mem} ))
      tormenta_proc_unit_int=$(echo ${desired_proc_units} | cut -f "1" -d ".")
      tormenta_proc_unit_dec=$(echo ${desired_proc_units} | cut -f "2" -d ".")
      tormenta_proc_unit_int_tot=$(( ${tormenta_proc_unit_int_tot} + ${tormenta_proc_unit_int} ))
      tormenta_proc_unit_dec_tot=$(( ${tormenta_proc_unit_dec_tot} + ${tormenta_proc_unit_dec} ))
      ;;
    "9009-42A-AxugPDSaetta")
      saetta_mem_tot=$(( ${saetta_mem_tot} + ${desired_mem} ))
      saetta_proc_unit_int=$(echo ${desired_proc_units} | cut -f "1" -d ".")
      saetta_proc_unit_dec=$(echo ${desired_proc_units} | cut -f "2" -d ".")
      saetta_proc_unit_int_tot=$(( ${saetta_proc_unit_int_tot} + ${saetta_proc_unit_int} ))
      saetta_proc_unit_dec_tot=$(( ${saetta_proc_unit_dec_tot} + ${saetta_proc_unit_dec} ))
      ;;
    "9009-42A-AxugPDCerino")
      cerino_mem_tot=$(( ${cerino_mem_tot} + ${desired_mem} ))
      cerino_proc_unit_int=$(echo ${desired_proc_units} | cut -f "1" -d ".")
      cerino_proc_unit_dec=$(echo ${desired_proc_units} | cut -f "2" -d ".")
      cerino_proc_unit_int_tot=$(( ${cerino_proc_unit_int_tot} + ${cerino_proc_unit_int} ))
      cerino_proc_unit_dec_tot=$(( ${cerino_proc_unit_dec_tot} + ${cerino_proc_unit_dec} ))
      ;;
  esac
done

P880_proc_unit_tot="$(( ${P880_proc_unit_int_tot} + $(( ${P880_proc_unit_dec_tot} / 10 )) )).$(( ${P880_proc_unit_dec_tot} % 10 ))"
tormenta_proc_unit_tot="$(( ${tormenta_proc_unit_int_tot} + $(( ${tormenta_proc_unit_dec_tot} / 10 )) )).$(( ${tormenta_proc_unit_dec_tot} % 10 ))"
saetta_proc_unit_tot="$(( ${saetta_proc_unit_int_tot} + $(( ${saetta_proc_unit_dec_tot} / 10 )) )).$(( ${saetta_proc_unit_dec_tot} %10 ))"
cerino_proc_unit_tot="$(( ${cerino_proc_unit_int_tot} + $(( ${cerino_proc_unit_dec_tot} / 10 )) )).$(( ${cerino_proc_unit_dec_tot} %10 ))"
echo "************************************************************"
echo "     Totale risorse P880"
echo "************************************************************"
echo "Memoria -> $(printf "%s\n" "scale=1; ${P880_mem_tot}/1024" | bc)"
echo "Processor unit -> ${P880_proc_unit_tot}"
echo "************************************************************"
echo "     Totale risorse Tormenta"
echo "************************************************************"
echo "Memoria -> $(printf "%s\n" "scale=1; ${tormenta_mem_tot}/1024" | bc)"
echo "Processor unit -> ${tormenta_proc_unit_tot}"
echo "************************************************************"
echo "     Totale risorse Saetta"
echo "************************************************************"
echo "Memoria -> $(printf "%s\n" "scale=1; ${saetta_mem_tot}/1024" | bc)"
echo "Processor unit -> ${saetta_proc_unit_tot}"
echo "************************************************************"
echo "     Totale risorse Cerino"
echo "************************************************************"
echo "Memoria -> $(printf "%s\n" "scale=1; ${cerino_mem_tot}/1024" | bc)"
echo "Processor unit -> ${cerino_proc_unit_tot}"
echo "************************************************************"
