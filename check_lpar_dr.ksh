#!/usr/bin/ksh
# Per tutte le LPAR a bologna (o eventualmente quelle selezionate da un filtro), estrae il profile della LPAR, modifica i campi per il DR  e controlla che il 
# corrispettivo profile in DR corrisponda evidenziandone le ventuali differenze. 
# Con il parametro -c se il profilo non esiste in DR lo crea.
# $1 - filtro da applicare per la selezione delle LPAR

#Data una LPAR trova la HMC e il power su cui e attestata
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

get_profile_dr(){
  for power_dr in $(ssh -n hscroot@${hmc_dr} lssyscfg -r sys -Fname); do
    check=$(ssh -n hscroot@${hmc_dr} "lssyscfg -r lpar -m $power_dr -Fname" | grep $lpar)
    if [[ -n $check ]]; then
      profile_name_dr=$(ssh -n hscroot@${hmc_dr} lssyscfg -r lpar -m $power_dr --filter "lpar_names=$lpar" -Fcurr_profile)
      profile_dr=$(ssh -n hscroot@${hmc_dr} lssyscfg -r prof -m $power_dr --filter "lpar_names=$lpar,profile_names=$profile_name_dr" -Flpar_name:name:lpar_env:min_mem:desired_mem:max_mem:min_proc_units:desired_proc_units:max_proc_units:min_procs:desired_procs:max_procs:virtual_eth_adapters:virtual_fc_adapters)
      return 0
    fi
  done
  return 1
}

get_memory(){
  min_mem=$(echo $profile | cut -f "4" -d ":")
  desired_mem=$(echo $profile | cut -f "5" -d ":")
  max_mem=$(echo $profile | cut -f "6" -d ":")
}

get_processor(){
  #Minimum processing unit
  min_proc_units=$(echo $profile | cut -f "7" -d ":")
  min_proc_units=$(printf "%s\n" "scale=1; ${min_proc_units}/4" | bc)
  if [[ ${min_proc_units} == "0" ]]; then
    min_proc_units=0.1
  fi

  #Desired processing unit
  desired_proc_units=$(echo $profile | cut -f "8" -d ":")
  desired_proc_units=$(printf "%s\n" "scale=1; ${desired_proc_units}/4" | bc)
  if [[ ${desired_proc_units} == "0" ]]; then
    desired_proc_units=0.1
  fi

  #Maximum processing unit
  max_proc_units=$(echo $profile | cut -f "9" -d ":")
  max_proc_units=$(printf "%s\n" "scale=1; ${max_proc_units}/4" | bc)
  if [[ ${max_proc_units} == "0" ]]; then
    max_proc_units=0.1
  fi

  #Virtual processor
  min_procs=$(( ${min_proc_units} / 1 + 1 ))
  desired_procs=$(( ${desired_proc_units} / 1 + 1 ))
  max_procs=$(( ${max_proc_units} / 1 + 1 ))
}

get_network(){
  #Virtual network
  #virtual_eth_adapters=$(cat $profile | cut -f "13" -d ":")
  unset virtual_eth_adapters
  networks=$(echo $profile | cut -f "13" -d ":" | sed "s/,/ /g")
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

check_memory(){
  #Minumum memory
  min_mem=$(echo $profile | cut -f "4" -d ":")
  min_mem_dr=$(echo $profile_dr | cut -f "4" -d ":")
  if [[ ${min_mem} != ${min_mem_dr} ]]; then
    echo "min_mem = ${min_mem} -> min_mem_dr = ${min_mem_dr}"
  #else
    #echo "min_mem = ${min_mem} -> Ok"
  fi

  #Desired memory
  desired_mem=$(echo $profile | cut -f "5" -d ":")
  desired_mem_dr=$(echo $profile_dr | cut -f "5" -d ":")
  if [[ ${desired_mem} != ${desired_mem_dr} ]]; then
    echo "desired_mem = ${desired_mem} -> desired_mem_dr = ${desired_mem_dr}"
  #else
    #echo "desired_mem = ${desired_mem} -> Ok"
  fi

  #Maximum memory
  max_mem=$(echo $profile | cut -f "6" -d ":")
  max_mem_dr=$(echo $profile_dr | cut -f "6" -d ":")
  if [[ ${max_mem} != ${max_mem_dr} ]]; then
    echo "max_mem = ${max_mem} -> max_mem_dr = ${max_mem_dr}"
  #else
    #echo "max_mem = ${max_mem} -> Ok"
  fi
}

check_processor(){
  #Minimum processing unit
  min_proc_units=$(echo $profile | cut -f "7" -d ":")
  min_proc_units_dr=$(echo $profile_dr | cut -f "7" -d ":")
  if [[ ${min_proc_units} != ${min_proc_units_dr} ]]; then
    echo "min_proc_units = ${min_proc_units} -> min_proc_units_dr = ${min_proc_units_dr}"
  #else
    #echo "min_proc_units = ${min_proc_units} -> Ok"
  fi

  #Desired processing unit
  desired_proc_units=$(echo $profile | cut -f "8" -d ":")
  desired_proc_units_dr=$(echo $profile_dr | cut -f "8" -d ":")
  if [[ ${desired_proc_units} != ${desired_proc_units_dr} ]]; then
    echo "desired_proc_units = ${desired_proc_units} -> desired_proc_units_dr = ${desired_proc_units_dr}"
  #else
    #echo "desired_proc_units = ${desired_proc_units} -> Ok"
  fi

  #Maximum processing unit
  max_proc_units=$(echo $profile | cut -f "9" -d ":")
  max_proc_units_dr=$(echo $profile_dr | cut -f "9" -d ":")
  if [[ ${max_proc_units} != ${max_proc_units_dr} ]]; then
    echo "max_proc_units = ${max_proc_units} -> max_proc_units_dr = ${max_proc_units_dr}"
  #else
    #echo "max_proc_units = ${max_proc_units} -> Ok"
  fi

  #Minimum Virtual processor
  min_procs=$(echo $profile | cut -f "10" -d ":")
  min_procs_dr=$(echo $profile_dr | cut -f "10" -d ":")
  if [[ ${min_procs} != ${min_procs_dr} ]]; then
    echo "min_procs = ${min_procs} -> min_procs_dr = ${min_procs_dr}"
  #else
    #echo "min_procs = ${min_procs} -> Ok"
  fi

  #Desired Virtual processor
  desired_procs=$(echo $profile | cut -f "11" -d ":")
  desired_procs_dr=$(echo $profile_dr | cut -f "11" -d ":")
  if [[ ${desired_procs} != ${desired_procs_dr} ]]; then
    echo "desired_procs = ${desired_procs} -> desired_procs_dr = ${desired_procs_dr}"
  #else
    #echo "desired_procs = ${desired_procs} -> Ok"
  fi

  #Maximum Virtual processor
  max_procs=$(echo $profile | cut -f "12" -d ":")
  max_procs_dr=$(echo $profile_dr | cut -f "12" -d ":")
  if [[ ${max_procs} != ${max_procs_dr} ]]; then
    echo "max_procs = ${max_procs} -> max_procs_dr = ${max_procs_dr}"
  #else
    #echo "max_procs = ${max_procs} -> Ok"
  fi
}

check_network(){
  virtual_eth_adapters=$(echo $profile | cut -f "13" -d ":")
  networks=$(echo $virtual_eth_adapters | sed "s/,/ /g")

  virtual_eth_adapters_dr=$(echo $profile_dr | cut -f "13" -d ":")
  networks_dr=$(echo $virtual_eth_adapters_dr | sed "s/,/ /g")

  for net in $networks; do
    slot=$(echo $net | cut -f "1" -d "/")
    vlan=$(echo $net | cut -f "3" -d "/")
    check_vlan="0"
    for net_dr in ${networks_dr}; do
      vlan_dr=$(echo ${net_dr} | cut -f "3" -d "/")
      slot_dr=$(echo ${net_dr} | cut -f "1" -d "/")
      #echo "networks_dr = ${networks_dr}"
      #echo "net_dr = ${net_dr}"
      #echo "vlan = ${vlan} -> vlan_dr = ${vlan_dr}"
      #echo "slot = ${slot} -> slot_dr = ${slot_dr}"
      if [[ ${vlan} == ${vlan_dr} ]]; then
        if [[ ${slot} != ${slot_dr} ]]; then
          echo "vlan = ${vlan} slot = ${slot} -> vlan_dr = ${vlan_dr} slot_dr = ${slot_dr}"
        #else
          #echo "vlan = ${vlan} slot = ${slot} -> Ok"
        fi
        check_vlan="1"
      else
        if [[ ${slot} == ${slot_dr} ]]; then
          echo "vlan = ${vlan} slot = ${slot} -> vlan_dr = ${vlan_dr} slot_dr = ${slot_dr}"
          check_vlan="1"
        fi
      fi
    done
    if [[ ${check_vlan} == "0" ]]; then
      echo "vlan = ${vlan} slot = ${slot} -> Non trovata"
    fi
  done
  virtual_eth_adapters=$(echo $net | sed "s/$vlan/$vlandr/g")
}

check_fc(){
  fc_adapters_dr=$(echo $profile_dr | cut -f "14" -d ":" | sed "s/\"\",\"\"/ /g")
  for vfc_dr in ${fc_adapters_dr}; do
    vfc_dr=$(echo ${vfc_dr} | sed "s/\"//g")
    vios=$(echo ${vfc_dr} | cut -f "4" -d "/")
    lpar_slot_client=$(echo ${vfc_dr} | cut -f "1" -d "/")
    vios_slot_client=$(echo ${vfc_dr} | cut -f "5" -d "/")
    fc_adapters_vios=$(ssh -n hscroot@${hmc_dr} lssyscfg -r prof -m ${power_dr} --filter "lpar_names=${vios},profile_names=default_profile" -Fvirtual_fc_adapters | sed "s/\"//g" | sed "s/,/ /g")

    check_fc=0
    for vfc_vios in ${fc_adapters_vios}; do
      lpar_slot_server=$(echo ${vfc_vios} | cut -f "5" -d "/")
      vios_slot_server=$(echo ${vfc_vios} | cut -f "1" -d "/")
      if [[ ${vios_slot_client} == ${vios_slot_server} ]]; then
        if [[ ${lpar_slot_server} == ${lpar_slot_client} ]]; then
          echo ""
          #echo "lpar_slot_client = ${lpar_slot_client} vios_slot_client = ${vios_slot_client} -> Ok"
        else
          echo "lpar_slot_client = ${lpar_slot_client} vios_slot_client = ${vios_slot_client} -> vios_slot_server = ${vios_slot_server} lpar_slot_server = ${lpar_slot_server}"
        fi
        check_fc=1
      fi
    done
    if [[ ${check_fc} == "0" ]]; then
      echo "lpar_slot_client = ${lpar_slot_client} vios_slot_client = ${vios_slot_client} -> Non trovata"
    fi

  done
}

resource_count(){
  case ${power} in
    "Server-9080-MHE-SN780F028")
      P880_mem_tot=$(( ${P880_mem_tot} + ${desired_mem_dr} ))
      P880_proc_unit_int=$(echo ${desired_proc_units_dr} | cut -f "1" -d ".")
      P880_proc_unit_dec=$(echo ${desired_proc_units_dr} | cut -f "2" -d ".")
      P880_proc_unit_int_tot=$(( ${P880_proc_unit_int_tot} + ${P880_proc_unit_int} ))
      P880_proc_unit_dec_tot=$(( ${P880_proc_unit_dec_tot} + ${P880_proc_unit_dec} ))
      P880_proc_tot=$(( ${P880_proc_tot} + ${desired_procs_dr} ))
      ;;
    "9009-42A-AxugPDTormenta")
      tormenta_mem_tot=$(( ${tormenta_mem_tot} + ${desired_mem_dr} ))
      tormenta_proc_unit_int=$(echo ${desired_proc_units_dr} | cut -f "1" -d ".")
      tormenta_proc_unit_dec=$(echo ${desired_proc_units_dr} | cut -f "2" -d ".")
      tormenta_proc_unit_int_tot=$(( ${tormenta_proc_unit_int_tot} + ${tormenta_proc_unit_int} ))
      tormenta_proc_unit_dec_tot=$(( ${tormenta_proc_unit_dec_tot} + ${tormenta_proc_unit_dec} ))
      tormenta_proc_tot=$(( ${tormenta_proc_tot} + ${desired_procs_dr} ))
      ;;
    "9009-42A-AxugPDSaetta")
      saetta_mem_tot=$(( ${saetta_mem_tot} + ${desired_mem_dr} ))
      saetta_proc_unit_int=$(echo ${desired_proc_units_dr} | cut -f "1" -d ".")
      saetta_proc_unit_dec=$(echo ${desired_proc_units_dr} | cut -f "2" -d ".")
      saetta_proc_unit_int_tot=$(( ${saetta_proc_unit_int_tot} + ${saetta_proc_unit_int} ))
      saetta_proc_unit_dec_tot=$(( ${saetta_proc_unit_dec_tot} + ${saetta_proc_unit_dec} ))
      saetta_proc_tot=$(( ${saetta_proc_tot} + ${desired_procs_dr} ))
      ;;
    "9009-42A-AxugPDCerino")
      cerino_mem_tot=$(( ${cerino_mem_tot} + ${desired_mem_dr} ))
      cerino_proc_unit_int=$(echo ${desired_proc_units_dr} | cut -f "1" -d ".")
      cerino_proc_unit_dec=$(echo ${desired_proc_units_dr} | cut -f "2" -d ".")
      cerino_proc_unit_int_tot=$(( ${cerino_proc_unit_int_tot} + ${cerino_proc_unit_int} ))
      cerino_proc_unit_dec_tot=$(( ${cerino_proc_unit_dec_tot} + ${cerino_proc_unit_dec} ))
      cerino_proc_tot=$(( ${cerino_proc_tot} + ${desired_procs_dr} ))
      ;;
  esac
}

#***************************************************
#                  MAIN PROGRAM
#***************************************************

#Inizializzazione variabili
filter=$1
hmc_dr=172.28.161.50

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

tot_lpar_missing=0

for hmc in $(cat hmc); do
  for power in $(ssh -n hscroot@${hmc} lssyscfg -r sys -Fname); do
    for lpar in $(ssh -n hscroot@${hmc} lssyscfg -r lpar -m ${power} -Fname | grep ${filter}); do

      echo ""
      echo "********************************************"
      echo "              $lpar"
      echo "********************************************"

      if [[ $? -eq 0 ]]; then
        # Estrazione del profilo di produzione e modifica proc_unit per DR
        profile_name=$(ssh -n hscroot@${hmc} lssyscfg -r lpar -m $power --filter "lpar_names=$lpar" -Fcurr_profile)
        profile=$(ssh -n hscroot@${hmc} lssyscfg -r prof -m $power --filter "lpar_names=$lpar,profile_names=$profile_name" -Flpar_name:name:lpar_env:min_mem:desired_mem:max_mem:min_proc_units:desired_proc_units:max_proc_units:min_procs:desired_procs:max_procs:virtual_eth_adapters) 
        if [[ $? -eq 0 ]]; then
          name=$(echo ${profile} | cut -f "1" -d ":")
          lpar_env=$(echo ${profile} | cut -f "3" -d ":")

          get_memory

          get_processor

          get_network

          # Controllo corrispondenze con profilo in DR
          get_profile_dr
          echo "${power} --> ${power_dr}"

          if [[ $? -eq 0 ]]; then
            echo "********************************************"
            echo "Memoria"
            check_memory

            echo "********************************************"
            echo "Processore"
            check_processor

            echo "********************************************"
            echo "Rete"
            check_network

            echo "********************************************"
            echo "Fiber Channel"
            check_fc

            resource_count
          else #se non esiste in DR
            echo "PARTIZIONE NON TROVATA"
            tot_lpar_missing=$(( ${tot_lpar_missing} + 1 ))
          fi
        fi
      fi
    done
  done
done

