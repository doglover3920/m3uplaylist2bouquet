#!/bin/bash
#usage: m3u2bouquet.sh m3ufile Provider TID ServiceType

if [ "$1" = "" ]
    then
    echo "Usage: m3u2bouquet.sh m3ufile Name TID ServiceType"
    echo "m3ufile: Name of the m3u file indluding path"
    echo "Provider: Provider Name, to identfy the entries in the bouquet and channels file"
    echo "TID: Up to 4 digit hexadecimal number, to disguish the services from different providers"
    echo "Servicetype: 1, 4097, 5001 or 5002.  If omitted 4097 is used"
    echo "Version 1.1"  
fi
m3ufile=$1
dos2unix ${m3ufile}
Provider=$2
Channelsfile=custom.channels.xml
TID=$3
Lead=$4
if [ Lead = "" ] 
    then
    Lead=4097
fi

rm /etc/enigma2/userbouquet.IP_$Provider*.*
# clean the bouquets.tv file
Clean=userbouquet.IP_$Provider
#echo $Clean
grep -v "$Clean" /etc/enigma2/bouquets.tv > /etc/enigma2/bouquets.new
mv -f /etc/enigma2/bouquets.new /etc/enigma2/bouquets.tv
# clean the custom.channels.xml file
rm /tmp/$Channelsfile
grep -v "IP_$Provider\|channels\|encoding" /etc/epgimport/$Channelsfile > /tmp/$Channelsfile
 
j=0
while read line;do
    if [[ "$line" == "#EXTM3"* ]] 
    then
        read line
    fi
    SID=""
    ChannelName=""
    ChannelID=""
    group_title=""
    group_title1=""
    j=$((j + 1))

    if [[ "$line" == *"tvg-chno"* ]]; then
            SID=${line##*tvg-chno=\"}
            SID=${SID%%\"*}
        else
            SID=$j
    fi
    if [[ "$line" == *"tvg-id"* ]]; then   
            ChannelID=${line##*tvg-id=\"}
            ChannelID=${ChannelID%%\"*}
        else
            ChannelID="nodata"
    fi
    if [[ "$line" == *"tvg-ID"* ]]; then   
            ChannelID=${line##*tvg-ID=\"}
            ChannelID=${ChannelID%%\"*}
        else
            ChannelID="nodata"
    fi    
    if [[ "$line" == *"tvg-name"* ]]; then
            ChannelName=${line##*tvg-name=\"}
            ChannelName=${ChannelName%%\"*}
        else
            ChannelName=${line#*,}
            ChannelName=${ChannelName//$'\r'}
    fi
    if [ "$ChannelName" = "" ]; then
            ChannelName=${line#*,}
            ChannelName=${ChannelName//$'\r'}
    fi
    if [[ "$line" == *"group-title"* ]]; then
            Group=${line##*group-title=\"}
            group_title=${Group%%\"*}
        elif [[ "$Group" == *"group-title"* ]]; then
            group_title1=${Group##*group-title=\"}
            group_title1=${group_title1%%\"*}
    fi

    Category="$group_title"" ""$group_title1"
    Category=${Category// | /-}    
    Cat1=${Category// /_}
    Cat1=${Cat1//+/}    
    Cat="$Provider"_"$Cat1"
    printf -v HexSID "%x" "$SID"

    read url
    url=${url//:/%3a}
    url=${url//$'\r'}

    if [[ ! -f /etc/enigma2/userbouquet.IP_$Cat.tv ]]
    then
         echo "#NAME $Provider $Category" > /etc/enigma2/userbouquet.IP_$Cat.tv
         echo '#SERVICE 1:7:1:0:0:0:0:0:0:0:FROM BOUQUET "userbouquet.IP_'$Cat'.tv" ORDER BY bouquet' >> /etc/enigma2/bouquets.tv 
    fi

    if [ "$ChannelID" != "" ] 
    then
        ChannelID=${ChannelID//&/and}
        if [ "$ChannelID" != "nodata" ] 
            then
            echo '<!-- IP_'$Cat' --><channel id="'$ChannelID'">'$Lead':0:1:'$HexSID:$TID':0:0:0:0:3:http%3a//example.com</channel><!-- '$ChannelName' -->' >> /tmp/$Channelsfile 
        fi
    fi
                  
    echo "#SERVICE $Lead:0:1:$HexSID:$TID:0:0:0:0:3:$url:$ChannelName" >> /etc/enigma2/userbouquet.IP_$Cat.tv

done < $m3ufile

#reconstruct the custom.channels.xml file
rm /etc/epgimport/$Channelsfile
echo '<?xml version="1.0" encoding="utf-8"?>' > /etc/epgimport/Header.xml
echo '<channels>' >> /etc/epgimport/Header.xml
cat /etc/epgimport/Header.xml /tmp/$Channelsfile > /etc/epgimport/$Channelsfile
echo '</channels>' >> /etc/epgimport/$Channelsfile
rm /etc/epgimport/Header.xml
wget -qO - "http://127.0.0.1/web/servicelistreload?mode=0"

EPGsource=/etc/epgimport/plutotv.sources.xml
echo '<?xml version="1.0" encoding="utf-8"?>' > $EPGsource
echo '<sources>' >> $EPGsource
echo '<sourcecat sourcecatname="Pluto TV">' >> $EPGsource
echo '<source type="gen_xmltv" nocheck="1" channels="custom.channels.xml">' >> $EPGsource
echo '<description>Pluto TV USA</description>' >> $EPGsource
echo '<url>http://i.mjh.nz/PlutoTV/epg.xml.gz</url>' >> $EPGsource
echo '</source>' >> $EPGsource
echo '<source type="gen_xmltv" nocheck="1" channels="custom.channels.xml">' >> $EPGsource
echo '<description>STIRR TV USA</description>' >> $EPGsource
echo '<url>http://i.mjh.nz/Stirr/epg.xml.gz</url>' >> $EPGsource
echo '</source>' >> $EPGsource
echo '</sourcecat>' >> $EPGsource
echo '</sources>' >> $EPGsource
