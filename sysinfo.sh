#!/bin/bash
# variabila hostname

if [[  $# -eq 0  ]]; then
	echo "sysinfo: usage: sysinfo [service_name]"
	exit
fi

HOSTNAME=$(hostname)
echo "1. Hostname: $HOSTNAME" > sysinfo.txt

INTERFACE="Ethernet" #Poate fi schimbata, Ethernet, Local Loopback etc.
IP=$(ifconfig | grep -A1 $INTERFACE | grep inet | cut -f2 -d":" | cut -c 1-13)
echo "2. IP: $IP" >> sysinfo.txt

#path lookup
LOOK=$(apache2ctl -V | grep HTTPD_ROOT | cut -f2 -d"=" | cut -d '"' -f2)
printf "3. " >> sysinfo.txt
cat $LOOK/sites-available/000-default.conf | grep ServerName | grep -v "#" | cut -f2 | sed 's/ /: /' >> sysinfo.txt

ALIASES=$(cat $LOOK/sites-available/000-default.conf | grep ServerAlias | grep -v "#" | cut -f2 | sed 's/ServerAlias //' | tr '\n' ' ')
echo "4. ServerAlias: $ALIASES" >> sysinfo.txt

FIND_MEMORY=$(free -h g | grep Mem)

echo "5. Memory" >> sysinfo.txt
printf "Total:\t" >> sysinfo.txt
echo $FIND_MEMORY | awk '{print $2}' >> sysinfo.txt
printf "Used:\t" >> sysinfo.txt
echo $FIND_MEMORY | awk '{print $3}' >> sysinfo.txt
printf "Free:\t" >> sysinfo.txt
echo $FIND_MEMORY | awk '{print $4}' >> sysinfo.txt

FIND_SWAP=$(free -h G| grep Swap)

printf "\n" >> sysinfo.txt
echo "Swap" >> sysinfo.txt
printf "Total:\t" >> sysinfo.txt
echo $FIND_SWAP	| awk '{print $2}' >> sysinfo.txt
printf "Used:\t" >> sysinfo.txt
echo $FIND_SWAP | awk '{print $3}' >> sysinfo.txt
printf "Free:\t" >> sysinfo.txt
echo $FIND_SWAP | awk '{print $4}' >> sysinfo.txt
printf "\n" >> sysinfo.txt

FIND_SPACE=$(df -h / | sed -n '2p')

echo "6. Disk Space in /root" >> sysinfo.txt
printf "Total:\t" >> sysinfo.txt
echo $FIND_SPACE | awk '{print $2}'>> sysinfo.txt
printf "Used:\t" >> sysinfo.txt
echo $FIND_SPACE | awk '{print $3}' >> sysinfo.txt
printf "Free:\t" >> sysinfo.txt
echo $FIND_SPACE | awk '{print $4}' >> sysinfo.txt
printf "Use:\t" >> sysinfo.txt
echo $FIND_SPACE | awk '{print $5}' >> sysinfo.txt
printf "\n" >> sysinfo.txt

echo "7. OS Version" >> sysinfo.txt
lsb_release -i | sed 's/	/ /g' >> sysinfo.txt
lsb_release -d | sed 's/	/ /g' >> sysinfo.txt
lsb_release -r | sed 's/	/ /g' >> sysinfo.txt
lsb_release -c | sed 's/	/ /g' >> sysinfo.txt
printf "\n" >> sysinfo.txt

#am dat suppress la un warning ce zicea ca trebuie root ca sa vezi unele nume de procese
SERVICE_NAME=$(netstat -lntp  2> /dev/null | awk '{print $7}' | sed 's/.*\///g' | tail -n+3 | tr '\n' ' ')
SERVICE_PORT=$(netstat -lntp  2> /dev/null | awk '{print $4}' | grep : | sed 's/.*://g' | tr '\n' ' ')
lista_servicii=( $SERVICE_NAME )
lista_porturi=( $SERVICE_PORT )

#elimina acelasi service, daca portul e la fel si pe IPv6
i=0
while [  $i -lt ${#lista_porturi[@]} ]; 
do
	j=0
	while [  $j -lt ${#lista_porturi[@]} ];
	do
		if [[ ${lista_porturi[j]} == ${lista_porturi[i]} ]] && [[ i -ne j ]]; then
      		lista_servicii[i]=''
      		lista_porturi[i]=''
		fi
		let j=j+1
	done
	let i=i+1
done

echo "8. Listening Services/Ports" >> sysinfo.txt
i=0
while [  $i -lt ${#lista_porturi[@]} ]; 
do
	if [[ ${lista_porturi[i]} != '' ]]; then
		if [[  ${lista_servicii[i]} == '-'  ]]; then
			printf "(needs root)" >> sysinfo.txt #trebuie dat cu sudo
		else
			printf "${lista_servicii[i]}" >> sysinfo.txt
		fi
		printf "\t\t${lista_porturi[i]}" >> sysinfo.txt
		printf "\n" >> sysinfo.txt
	fi
	let i=i+1
done
printf "\n" >> sysinfo.txt

echo "9. Apache/MySQL Services Status" >> sysinfo.txt
SERVICE_NAME="apache2"

if service --status-all | grep -Fq $SERVICE_NAME; then    
   service_name=$(service --status-all | grep $SERVICE_NAME | cut -f2 -d ']' | sed 's/ //g')
   if service --status-all | grep $SERVICE_NAME | grep -q +; then
  		printf "$service_name \trunning\n" >> sysinfo.txt
   elif service --status-all | grep $SERVICE_NAME | grep -q -; then
   		printf "$service_name \tstopped\n" >> sysinfo.txt
   else
   		printf "$service_name \tstatus unknown\n" >> sysinfo.txt
   fi
else
	>&2 printf "Error: The Service '$SERVICE_NAME' does not exist on this machine!\n" >> sysinfo.txt
fi

SERVICE_NAME="mysql"
if service --status-all | grep -Fq $SERVICE_NAME; then    
   service_name=$(service --status-all | grep $SERVICE_NAME | cut -f2 -d ']' | sed 's/ //g')
   if service --status-all | grep $SERVICE_NAME | grep -q +; then
  		printf "$service_name \t\trunning\n" >> sysinfo.txt
   elif service --status-all | grep $SERVICE_NAME | grep -q -; then
   		printf "$service_name \t\tstopped\n" >> sysinfo.txt
   else
   		printf "$service_name \t\tstatus unknown\n" >> sysinfo.txt
   fi
else
	>&2 printf "Error: The Service '$SERVICE_NAME' does not exist on this machine!\n" >> sysinfo.txt
fi


echo "10. Service Status" >> sysinfo.txt
P_ST=$(/etc/init.d/$1 status 2> /dev/null | sed -n '3p' | cut -f2 -d"(" | sed 's/).*//g')

if [[  $P_ST != ''  ]]; then
	if [[  $P_ST == "dead"  ]]; then
		printf "$1\t\tstopped\n" >> sysinfo.txt
	else
		printf "$1\t\t$P_ST\n" >> sysinfo.txt
	fi
else
	>&2 printf "Error: The service '$1' does not exist on this machine!\n" >> sysinfo.txt
fi

echo "11. Memory Use (KiB)" >> sysinfo.txt
TOTAL_MEM=$(ps aux | grep $1 | grep "/usr" | awk '{print $6}' | tr '\n' ' ')

if [[  $TOTAL_MEM == ''  ]]; then
	>&2 printf "Error: The Service '$1' does not exist on this machine!\n" >> sysinfo.txt
	exit
fi

LIST_MEM=( $TOTAL_MEM )

i=0
s=0
while [  $i -lt ${#LIST_MEM[@]} ]; 
do
	let s=s+${LIST_MEM[i]}
	let i=i+1
done

printf "$1\t\t$s (${TOTAL_MEM::-1})\n" >> sysinfo.txt