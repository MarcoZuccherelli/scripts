#!/usr/bin/ksh
# Legge da un file una lista di LPAR , estrae il profile della LPAR, modifica i campi per il DR  e scrive su un file i campi per la creazione della LPAR 
# da dare in pasto al comando mksyscfg (-r lpar -m server -f nome_file) con il quale ricreare la LPAR in DR con gli con gli stessi parametri
# $1 - lista LPAR 

#Data una LPAR trova ls HMC e il power su cui e attestata
find_hmc_power(){
  for hmc in $(cat hmc); do
    powers=$(ssh -n hscroot@$hmc "lssyscfg -r sys -Fname")
    for power in $powers; do
      check=$(ssh -n hscroot@$hmc "lssyscfg -r lpar -m $power -Fname" | grep $lpar)
      if [[ -n $check ]]; then
        return 0
      fi
    done
  done
  return 1
}

get_memory(){
  min_mem=$(cat $profile | cut -f "4" -d ":")
  desired_mem=$(cat $profile | cut -f "5" -d ":")
  max_mem=$(cat $profile | cut -f "6" -d ":")
}

get_processor(){
  #Minimum processing unit
  min_proc_units=$(cat $profile | cut -f "7" -d ":")
  min_proc_units_dr=$(printf "%s\n" "scale=1; ${min_proc_units}/4" | bc)
  if [[ ${min_proc_units_dr} == "0" ]]; then
    min_proc_units_dr=0.1
  fi

  #Desired processing unit
  desired_proc_units=$(cat $profile | cut -f "8" -d ":")
  cat ${profile}
  echo "desired_proc_units --> ${desired_proc_units}"
  desired_proc_units_dr=$(printf "%s\n" "scale=1; ${desired_proc_units}/4" | bc)
  echo "desired_proc_units_dr --> ${desired_proc_units_dr}"
  if [[ ${desired_proc_units_dr} == "0" ]]; then
    desired_proc_units_dr=0.1
  fi

  #Maximum processing unit
  max_proc_units=$(cat $profile | cut -f "9" -d ":")
  max_proc_units_dr=$(printf "%s\n" "scale=1; ${max_proc_units}/4" | bc)
  if [[ ${max_proc_units_dr} == "0" ]]; then
    max_proc_units_dr=0.1
  fi

  #Virtual processor
  min_procs=$(( ${min_proc_units_dr} / 1 + 1 ))
  desired_procs=$(( ${desired_proc_units_dr} / 1 + 1 ))
  max_procs=$(( ${max_proc_units_dr} / 1 + 1 ))
}

get_network(){
  #Virtual network
  #virtual_eth_adapters=$(cat $profile | cut -f "13" -d ":")
  unset virtual_eth_adapters
  networks=$(cat $profile | cut -f "13" -d ":" | sed "s/,/ /g")
  for net in $networks; do
    vlan=$(echo $net | cut -f "3" -d "/")
    vlandr=0
    cat vlan | while read vlanbo vlanpd; do
      if [[ $vlanbo == $vlan ]]; then
        vlandr=$vlanpd
      fi
    done
    if [[ $vlandr != "0" ]]; then
      if [[ -z ${virtual_eth_adapters} ]]; then
        virtual_eth_adapters=$(echo $net | sed "s/$vlan/$vlandr/g")
      else
        virtual_eth_adapters="${virtual_eth_adapters},$(echo $net | sed "s/$vlan/$vlandr/g")"
      fi
    else
      echo "vlan $vlan non trovata nella tabella delle vlan"
    fi
  done
}

#***************************************************************************************************************

list_lpar=lpar/$1
for lpar in $(cat ${list_lpar}); do

  find_hmc_power
  echo "********************************************"
  echo $lpar
  echo $power

  if [[ $? -eq 0 ]]; then
    profile="profile/"${lpar}_prof
    profile_check="profile/"${lpar}_check
    profile_name=$(ssh -n hscroot@${hmc} lssyscfg -r lpar -m $power --filter "lpar_names=$lpar" -Fcurr_profile)
    ssh -n hscroot@${hmc} lssyscfg -r prof -m $power --filter "lpar_names=$lpar,profile_names=$profile_name" -Flpar_name:name:lpar_env:min_mem:desired_mem:max_mem:min_proc_units:desired_proc_units:max_proc_units:min_procs:desired_procs:max_procs:virtual_eth_adapters > $profile
    if [[ -s $profile ]]; then
      name=$(cat $profile | cut -f "1" -d ":")
      lpar_env=$(cat $profile | cut -f "3" -d ":")

      get_memory

      get_processor

      echo "min_proc_units: ${min_proc_units} --> min_proc_units_dr: ${min_proc_units_dr}"
      echo "min_procs_dr: ${min_procs}" 
      echo "desired_proc_units: ${desired_proc_units} --> desired_proc_units_dr: ${desired_proc_units_dr}"
      echo "desired_procs_dr: ${desired_procs}"
      echo "max_proc_units: ${max_proc_units} --> max_proc_units_dr: ${max_proc_units_dr}"
      echo "max_procs_dr: ${max_procs}"

      get_network
      
      #Profile
      echo name=$name,profile_name=default,lpar_env=$lpar_env,min_mem=$min_mem,desired_mem=$desired_mem,max_mem=$max_mem,proc_mode=shared,sharing_mode=uncap,uncap_weight=128,min_proc_units=$min_proc_units_dr,desired_proc_units=$desired_proc_units_dr,max_proc_units=$max_proc_units_dr,min_procs=$min_procs,desired_procs=$desired_procs,max_procs=$max_procs,max_virtual_slots=1024,\"virtual_eth_adapters=$virtual_eth_adapters\" >${profile}
      #Profile
      echo $name:default:${lpar_env}:${min_mem}:${desired_mem}:${max_mem}:shared:uncap:128:${min_proc_units_dr}:${desired_proc_units_dr}:${max_proc_units_dr}:${min_procs}:${desired_procs}:${max_procs}:1024:${virtual_eth_adapters} >${profile_check}
    fi
  fi
done

