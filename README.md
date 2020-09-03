**DISCLAIMER**: I AM NOT RESPONSIBLE OF THE MISUSE OF THIS TOOL. YOU RUN IT AT YOUR OWN RISK. Before running it, make sure you are in a controlled environment, and where you are allowed to perform this kind of exercise. PLEASE BE KIND :)

# SMB AutoRelay
  SMB AutoRelay provides the automation of SMB/NTLM Relay technique for pentesting and red teaming exercises in active directory environments.

  ![alt text](https://github.com/chesire-cat/smbAutoRelay/blob/master/images/help.png?raw=true)
  
## Usage
  Syntax: `./smbAutoRelay.sh -i <interface> -t <file> [-q] [-d]`. 
  
  Example: `./smbAutoRelay.sh -i eth0 -t ./targets.txt`.
  
  > Notice that the targets file should contain just the IP addresses of each target, one per line, to which you want to try the SMB/NTLM Relay technique.
  
  Run `./smbAutoRelay.sh [-h]` to see other options.
  
##

  **Software which installs in the current directory [*needed to run properly*]**
  - [responder] (https://github.com/lgandx/Responder) 
  - [impacket] (https://github.com/SecureAuthCorp/impacket) 
  
  **Software which installs through `apt`, if not installed [*needed to run properly*]**
  - tmux
  - rlwrap
  - python3
  - netcat
  - wget 
  - xterm 
  - net-tools
  
## TODOs
  - [ ] Add the possibility to capture and crack the NetNTLM hashes.
  - [ ] Addapt it to use terminal profiles
