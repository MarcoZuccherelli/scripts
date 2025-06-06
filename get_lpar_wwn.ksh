#!/usr/bin/ksh
#per ogni lpar estrae i suoi WWN
# $1 - HMC
# $2 - Power
# $3 - LPAR

if [[ "$#" -eq 3 ]]; then
  hmc=$1
  power=$2
  lpar=$3

  profile_name=$(ssh -n hscroot@${hmc} lssyscfg -r lpar -m $power --filter "lpar_names=$lpar" -Fcurr_profile)
  virtual_fc_adapters=$(ssh -n hscroot@${hmc} lssyscfg -r prof -m $power --filter "lpar_names=$lpar,profile_names=$profile_name" -Flpar_id:virtual_fc_adapters)
  for vfc in $(echo ${virtual_fc_adapters} | cut -f "2" -d ":" | sed "s/\",/ /g" | sed "s/\"//g"); do
    #echo "vfc --> ${vfc}"
    vios_id=$(echo ${vfc} | cut -f 3 -d "/")
    vios_slot=$(echo ${vfc} | cut -f 5 -d "/")
    vios_name=$(echo ${vfc} | cut -f 4 -d "/")
    lpar_id=$(echo ${virtual_fc_adapters} | cut -f 1 -d ":")
    wwn=$(echo ${vfc} | cut -f 6 -d "/")
    vios_map=$(ssh -n hscroot@${hmc} viosvrcmd -m $power --id ${vios_id} -c \"lsmap -all -npiv -cpid ${lpar_id} -fmt :\" | grep "V${vios_id}-C${vios_slot}:")
    fc_server=$(echo ${vios_map} | cut -f "7" -d ":")
    fc_client=$(echo ${vios_map} | cut -f "11" -d ":")
    scsi_id=$(ssh -n hscroot@${hmc} viosvrcmd -m $power --id ${vios_id} -c \"fcstat ${fc_server}\" | grep "Port FC ID:" | cut -f "2" -d ":" | sed "s/ //g" | cut -c1-4)
    unset fabric
    case ${scsi_id} in
      "0x0A")
        fabric=1 ;;
      "0x14")
        fabric=2 ;;
      *)
        fabric=0 ;;
    esac
    echo "${fc_client}:${wwn}:${vios_name}:${fc_server}:${fabric}"
  done
  return 0
else
  echo "Numero argomenti errato"
  return 1
fi
