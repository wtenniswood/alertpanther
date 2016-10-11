#!/bin/bash
#set -x
#emptyvar=$'*( |\t)'
function alertpanther
{
cat << "EOF"



                                     Alert Panther
                           60% of the time it works every time
					

EOF
}

function alerttime
{
echo "Alert Panther will automatically search the logs 2 hours before and 1 hour after the alert starttime"
echo "Copy alert time(ex: 2016-09-30 00:56:32 UTC , 2016-10-05T16:10:05-0500 , 10/6/2016 3:47:52 PM)"
echo "Time:"
read thealerttime
#converts alert copy and paste to apache log format an hour before the alert started and an hour after it started
hourbeforeweb=$(date -d"$(echo "$thealerttime 2 hours ago")" +%d/%b/%Y:%H:%M:%S)
hourafterweb=$(date -d"$(echo "$thealerttime 1 hours")" +%d/%b/%Y:%H:%M:%S)
}

function alerttimesearch
{
	echo "Webserver logs found."
	echo "Calculating size..."
        logsize=$(du -csh $lsofalogs | tail -n 1 |awk '{print $1}')
	freemem=$(free -ght | grep Total |awk '{print $3}')
	echo "Total size of logs is $logsize"
	echo "Total free ram is $freemem"
	echo "Analyzing logs....."
        logconfirmed="$lsofalogs"
        
	#Kick out the noise and filter by date/time
	filtered="$(for i in $lsofalogs; do awk -v  hbw=$hourbeforeweb -v haw=$hourafterweb -v prefix="$i:" -F"[" '$2>hbw && $2<haw && !/Monitor|dummy connection|server-status|127.0.0.1|localhost|^ -/ && /POST|GET/ $0 {print prefix $0}' $i; done)"

        #grab the first IP column, works in most scenarios for the public IPs
        #changelog 06OCT...some people put commas in their logformat
	
	partone=$( awk '{print $1}' <<< "$filtered"| tr -d ,)
        
	#account for custom log configurations by setting POST and GET as the delimeter for awk
        parttwo=$(awk -F"POST|GET" '{print $2}' <<< "$filtered" | awk '{print $1}')

        #combine them back together and organize
        alloutput=$(paste -d " " <(echo "$partone") <(echo "$parttwo") | sort | uniq -c | sort -nr | head -40 | awk '{print $1,$2,$3}' | sed '/^$/d' )

        #Clear Previous Output and analyze location, remove spaces for awking
        ips=$(for i in $(echo "$alloutput" | awk '{print $2}'); do curl -s http://geoip.nekudo.com/api/$i 2>&1 | sed -e 's/.*name\"\:\"//g' | cut -d "\"" -f1 | sed '/^$/d;s/[[:blank:]]//g'; done)

        #Combine the output of the IPs and the log stats and organize
        phase3=$(paste <(echo "$alloutput") <(echo "$ips") --d ' ' | column -t -s $'\t ')

        #pull and clear out the filepath of the logs
        nopaths=$(awk '{print $2}' <(echo "$phase3") | awk -F ":" '{print $1}' | awk -F"/" '{print $NF}')

        #pull and clean up the full logpath for better output
        ipaddys=$(awk '{print $2}' <(echo "$phase3") | awk -F ":" '{print $2}')
        
	#Pull the numbers for reorg
        numbers=$(awk '{print $1}' <(echo "$phase3"))

        #pull and clean the location output
        fileloc=$(awk '{print $3, $4}' <(echo "$phase3"))

        #put it all back together
        clear
        echo "Top hits by target and ip address from $hourbeforeweb to $hourafterweb"
        paste -d " " <(echo "$numbers") <(echo "$nopaths") <(echo "$ipaddys") <(echo "$fileloc") | column -t -s $'\t '
}


function webserver
{
	#Determine the active webserver
	#some people name their logs unfortunately uncommon names, this seems to be the most accurate solution so far
	#perviously I grepped the log paths out of the conf and used lsof to verify, I may combine the two solutions in the future to account for the wayward naming scheme, this was a quick way to get around people using nginx
	#as a proxy and just grab all the logs at onces
	echo "Searching for logs..."
	lsofalogs=$(lsof | awk '/httpd|nginx|apache2/ && /access/ && /log/ && !a[$9]++ {print $9}')
}
###############################Program Begins Here###########################
alertpanther
webserver
alerttime
alerttimesearch



