#!/usr/bin/ksh
# Crea un file con i dati di tutte lpar presi dal profilo
# $1 - (facoltativo) filtro sulle lpar da trattare

profile=profile/all_lpar
filter=$1
echo lpar_name:state:power:prof_name:oslevel:min_mem:desired_mem:max_mem:min_proc_units:desired_proc_units:max_proc_units:min_procs:desired_procs:max_procs:vlan > $profile
for hmc in $(cat hmc); do
  for power in $(ssh -n hscroot@$hmc "lssyscfg -r sys -Fname"); do
    echo $power
    if [[ -n ${filter} ]]; then
      lpars=$(ssh -n hscroot@$hmc "lssyscfg -r lpar -m $power -Fname | grep ${filter}")
    else
      lpars=$(ssh -n hscroot@$hmc "lssyscfg -r lpar -m $power -Fname")
    fi
    for lpar in ${lpars}; do
      echo "  $lpar"
      curr_profile=$(ssh -n hscroot@${hmc} lssyscfg -r lpar -m $power --filter "lpar_names=$lpar" -Fcurr_profile)
      tmp_profile=$(ssh -n hscroot@${hmc} "lssyscfg -r prof -m $power --filter \"profile_names=${curr_profile},lpar_names=$lpar\" -Flpar_name:name:lpar_env:min_mem:desired_mem:max_mem:min_proc_units:desired_proc_units:max_proc_units:min_procs:desired_procs:max_procs:virtual_eth_adapters")
      name=$(echo $tmp_profile | cut -f "1" -d ":")
      profile_name=$(echo $tmp_profile | cut -f "2" -d ":")
      lpar_env=$(echo $tmp_profile | cut -f "3" -d ":")
      min_mem=$(echo $tmp_profile | cut -f "4" -d ":")
      desired_mem=$(echo $tmp_profile | cut -f "5" -d ":")
      max_mem=$(echo $tmp_profile | cut -f "6" -d ":")
      min_proc_units=$(echo $tmp_profile | cut -f "7" -d ":")
      desired_proc_units=$(echo $tmp_profile | cut -f "8" -d ":")
      max_proc_units=$(echo $tmp_profile | cut -f "9" -d ":")
      min_procs=$(echo $tmp_profile | cut -f "10" -d ":")
      desired_procs=$(echo $tmp_profile | cut -f "11" -d ":")
      max_procs=$(echo $tmp_profile | cut -f "12" -d ":")
      virtual_eth_adapters=$(echo $tmp_profile | cut -f "13" -d ":")
      networks=$(echo $virtual_eth_adapters | sed "s/,/ /g")
      unset vlan
      for net in $networks; do
        if [[ -z $vlan ]]; then
          vlan=$(echo $net | cut -f "3" -d "/")
        else
          vlan=$vlan,$(echo $net | cut -f "3" -d "/")
        fi
      done
      lpar_info=$(ssh -n hscroot@${hmc} "lssyscfg -r lpar -m $power --osrefresh --filter "lpar_names=$lpar" -Fstate,os_version")
      state=$(echo ${lpar_info} | cut -d "," -f "1")
      oslevel=$(echo ${lpar_info} | cut -d "," -f "2")
      echo $name:${state}:$power:$profile_name:${oslevel}:$min_mem:$desired_mem:$max_mem:$min_proc_units:$desired_proc_units:$max_proc_units:$min_procs:$desired_procs:$max_procs:$vlan >> $profile
    done
  done
done
