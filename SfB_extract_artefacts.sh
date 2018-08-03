#!/bin/bash
# version 0.2
# Arjan Sturkenboom 6 July 2018: 
# It should be noted that this script is a raw version and requires improvement and will be rebuild to a python script
# Requirements:
# 1. Git Bash for Windows https://git-for-windows.github.io/
# 2. The application RegFileExport (http://www.nirsoft.net/) to extract information from registry
# 3. tracerpt, Microsoft Windows 10 built-in (https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/tracerpt_1)
# TODO:
# * insert hash verification of source files
# * etc.


# Read Variables
read -p 'Insert the target username: ' user_name
read -p 'Insert your report folder: ' report_folder
read -p 'Insert full path of the ntuserdat file, including filename: ' ntuserdat_file
read -p 'Insert full folder path of Trace and UccApiLog: ' log_folder
read -p 'Path to the RegFileExport application: ' regfileexport_folder

# Create Report folder and verify folder existense 
if [[ ! -e $report_folder ]]; then
    mkdir $report_folder
	echo "Report folder created" 1>&2
elif [[ ! -d $report_folder ]]; then
    echo "Report folder already exists" 1>&2
fi 

# read SfB user registry settings 
$regfileexport_folder/RegFileExport.exe $ntuserdat_file $report_folder/$user_name.LyncRegistrySettings.info "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Office\16.0\Lync"

	# extract LastDialed info
echo ==== Start of LastDialed User ==== >> $report_folder/1.$user_name.SfB_LastDialedNumber.log
echo SfB LastDialedNumber found in the user registry is >> $report_folder/1.$user_name.SfB_LastDialedNumber.log
strings $report_folder/$user_name.LyncRegistrySettings.info >> $report_folder/$user_name.LastDialedNumber_strings.info
grep -i "lastdialednumber" $report_folder/$user_name.LastDialedNumber_strings.info >> $report_folder/1.$user_name.SfB_LastDialedNumber.log
echo ==== End of LastDialedNumber ==== $'\n' >> $report_folder/1.$user_name.SfB_LastDialedNumber.log

# extract keywords from Tracelogs
echo ==== Extract of keyword from Trace logs ==== >> $report_folder/2.$user_name.SfB_keywords.log
tracerpt $log_folder/Lync-*.etl -of CSV -o $report_folder/$user_name.etl_output.csv ; sleep 30 ; grep -i 'CPeopleSearch::Search.*wzText' $report_folder/$user_name.etl_output.csv | awk '{print $18, $20, $22}' | 
sed 's/,$//' >> $report_folder/2.$user_name.SfB_keywords.log

echo ==== END OF keywords  ==== $'\n' >> $report_folder/2.$user_name.SfB_keywords.log 

# extract IM info from UccApiLog
echo ==== Extract IM from UccApiLog files ==== >> $report_folder/3.$user_name.SfB_chat.log
grep -i -B 13 -A 9 "cseq.*message" $log_folder/*.UccApilog | sed -n '/MESSAGE sip:/,/INFO  :: End of/p' | sed -e 's/\(\(.* \)\{2\}\(MESSAGE sip:\)\)/\n************Instant Message***********\n\1/g' | awk  '!/Content-|Supported:|Proxy-Autho|Route: |Authentication-Info: /' >> $report_folder/3.$user_name.SfB_chat.log 
echo ==== END OF Instand messaging ==== $'\n' >> $report_folder/3.$user_name.SfB_chat.log 

# extract call info from from UccApiLog files
echo ==== Extract calls from UccApiLog files ==== >> $report_folder/4.$user_name.SfB_call.log
grep -E -i -B 10 -A 10 "(SIP/2.0 180 Ringing|Cseq: 3 ACK|Cseq: 7 BYE)" $log_folder/*.UccApilog | sed -e 's/\(\(.* \)\{2\}\(INFO  :: SIP\)\)/\n************Call Session***********\n\1/g' |  sed -e 's/\(\(.* \)\{2\}\(INFO  :: ACK \)\)/\n************Call Session***********\n\1/g' | sed -n '/Call Session/,/CSeq:/p' >> $report_folder/4.$user_name.SfB_call.log
echo ==== END OF Calls ==== $'\n' >>$report_folder/4.$user_name.SfB_call.log 

# extract webcam sharing info from from UccApiLog files
echo ==== Start of extract screen sharing ==== >> $report_folder/5.$user_name.SfB_screensharing.log  
grep -i -B 80 "m=video" $log_folder/*.UccApilog | grep -E 'INFO  :: SIP|INFO  :: Sending Packet -|From:|To:|Call-ID:' | sed -e 's/\(\(.* \)\{2\}\(INFO  :: S\)\)/\n************Video Session***********\n\1/g' >> $report_folder/5.$user_name.SfB_screensharing.log
echo ==== END OF screen Sharing ==== $'\n' >> $report_folder/5.$user_name.SfB_screensharing.log  

# extract Application sharing info from from UccApiLog files
echo ==== Start of extract Application sharing ==== >> $report_folder/6.$user_name.SfB_Application_sharing.log  
grep -i -B 80 "m=applicationsharing" $log_folder/*.UccApilog | grep -E 'INFO  :: SIP|INFO  :: Sending Packet -|From:|To:|Call-ID:' | sed -e 's/\(\(.* \)\{2\}\(INFO  :: S\)\)/\n************Application Session***********\n\1/g' >> $report_folder/6.$user_name.SfB_Application_sharing.log
echo ==== END OF Application Sharing ==== $'\n' >> $report_folder/6.$user_name.SfB_Application_sharing.log 

# Combine log file to complete report
cat $report_folder/*.log >> $report_folder/$user_name.SfB_Artefacts_Report.info
	# remove full path from report
	sed 's/^.*DCol\/scripts//' $report_folder/$user_name.SfB_Artefacts_Report.info >> $report_folder/0.$user_name.SfB_Artefacts_Report.rpt
	
