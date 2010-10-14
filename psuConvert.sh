#!/bin/bash

# psuConvert.sh, a bash shell utility to convert html files downloaded off of PSU's webmail
# site into a useable maildir formatted mail box for easy migration to a new mail service.
# This code is released under the terms of the GNU General Public License v.3
# Copyright 2010 Joe Balough

# By default, the mail folder is 'mail', this can be changed by simply passing the folder
# name as the first parameter to this script.

foldername=$1
if [ "$foldername" = "" ]
then
	foldername="mail"
fi

# make sure input folder exists
if [ ! -d "$foldername" ]; then
    echo "The folder $foldername does not exist."
    echo "Usage: $0 [foldername]"
    echo "If foldername is omitted, it defaults to 'email'"
    echo "Converted emails are put in a folder named convd_[foldername]"
    exit 1;
fi

# make sure conversion folder exists
if [ ! -d "convd_$foldername" ]; then
    mkdir convd_$foldername
	if [ ! -d "convd_$foldername" ]; then
		echo "Error creating folder convd_$foldername"
		exit 1;
	fi
fi


# this function converts ONE file
function conv_file() {
	filename=$foldername/$1
	
	getfield_result=
	function getlinkfield() {
		sed_string="s/.*$1.*<\/div><a href.*>\(.*\)<\/a>&nbsp;<a.*/\1/p"
		getfield_result=`grep $1 $filename | sed -n "$sed_string" | sed "s/&lt;/</;s/&gt;/>/;s/&quot;/\"/g"`
	}
	function getfield() {
		sed_string="s/.*$1.*>\(.*\)<\/div>.*/\1/p"
		getfield_result=`grep $1 $filename | sed -n "$sed_string"`
	}
	
	swapped_month=1
	function swap_month() {
		case $1 in
			"Jan")
				swapped_month=1;;
			"Feb")
				swapped_month=2;;
			"Mar")
				swapped_month=3;;
			"Apr")
				swapped_month=4;;
			"May")
				swapped_month=5;;
			"Jun")
				swapped_month=6;;
			"Jul")
				swapped_month=7;;
			"Aug")
				swapped_month=8;;
			"Sep")
				swapped_month=9;;
			"Oct")
				swapped_month=10;;
			"Nov")
				swapped_month=11;;
			"Dec")
				swapped_month=12;;
				
		esac
	}

	getlinkfield retrievefrom
	from=$getfield_result
	fromaddr=`echo $from | sed -n 's/.*<\(.*\)>.*/\1/p'`
	if [ "$fromaddr" = "" ]
	then
		fromaddr=$from
	fi
	
	getlinkfield retrieveto
	to=$getfield_result

	getfield retrievesubject
	subject=$getfield_result

	getfield retrievedate
	date=$getfield_result
	fromdate=`echo $date | tr -d ','`
	# results in format like "Mon Aug 9 2010 01:19 PM"
	wordday=`echo $fromdate | awk '// {print $1}'`    # gets 'Mon'
	month=`echo $fromdate | awk '// {print $2}'`  #returns 'aug'
	swap_month $month
	nummonth=$swapped_month                                 #returns '8'
	day=`echo $fromdate | awk '// {print $3}'`    #returns '9'
	year=`echo $fromdate | awk '// {print $4}'`   #returns '2010'
	ampm=`echo $fromdate | awk '// {print $6}'`   #returns 'PM'
	# If $ampm is pm, we need to change the time
	fulltime=`echo $fromdate | awk '// {print $5}'`
	hours=`echo $fulltime | awk -F: '// {print $1}'`
	minutes=`echo $fulltime | awk -F: '// {print $2}'`
	if [ "$ampm" = "PM" ]
	then
		tmphrs=$hours
		hours=$((tmphours + 12))
	fi
	# needs to be like "Thu, 14 Oct 2010 11:37:16 +0900"
	fromdate=`echo "$wordday, $day $month $year $hours:$minutes:00 -0400"`
	
	bodylines=(`awk -F: '/retrievebody/ {print NR}' $filename`)
	body=`sed -n ${bodylines[0]},${bodylines[1]}p $filename`

	echo "From: $from"
	echo "Organization: foobar"
	echo "X-KMail-Transport: gmail.com"
	echo "X-KMail-Fcc: sent-mail"
	echo "To: $to"
	echo "Subject: $subject"
	echo "Date: $fromdate"
	echo "User-Agent: KMail/1.13.5 (Linux/2.6.35-ARCH; KDE/4.5.2; x86_64; ; )"
	echo "X-KMail-QuotePrefix: >"
	echo "X-KMail-Markup: true"
	echo "MIME-Version: 1.0"
	echo "X-KMail-Recipients: $to"
	message_id=`echo "$year$nummonth$day$hours$minutes.020321.$fromaddr"`
	echo "Message-Id: <$message_id>"
	echo "X-KMail-SignatureActionEnabled: false"
	echo "X-KMail-EncryptActionEnabled: false"
	echo "X-KMail-CryptoMessageFormat: 15"
	
	attachments=`awk -F: '/Part of this e-mail is in/ {print NR}' $filename`
	if [ "$attachments" = "" ]
	then
		echo "Status: R"
		echo "X-Status: N"
		echo "X-KMail-EncryptionState: N"
		echo "X-KMail-SignatureState: N"
		echo "X-KMail-MDN-Sent:  "
		echo "Content-type: text/html;"
		echo "  charset=\"utf8\""
		echo "Content-Transfer-Encoding: 8bit"
		echo ""
		echo "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0//EN\" \"http://www.w3.org/TR/REC-html40/strict.dtd\">"
		echo "<html><body>$body</body></html>"
		echo ""
	else
		echo "Status: RO"
		echo "X-Status: RQT"
		echo "Content-Type: multipart/mixed;"
		
		boundary="Boundary-00=_sozDaoiDnDs"
		echo "  boundary=\"$boundary\""
		echo "X-KMail-EncryptionState: N"
		echo "X-KMail-SignatureState: N"
		echo "X-KMail-MDN-Sent:  "
		
		echo ""
		echo "--$boundary"
		echo "Content-type: text/html;"
		echo "  charset=\"utf8\""
		echo "Content-Transfer-Encoding: 8bit"
		echo ""
		echo "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0//EN\" \"http://www.w3.org/TR/REC-html40/strict.dtd\">"
		echo "<html><body>$body</body></html>"
		echo ""
		
		echo "--$boundary"
		
		for line in $attachments
		do
			fulltype=`sed -n $((line)),$((line + 3))p $filename`
			type=`echo $fulltype | sed -n 's/.*Part of this e-mail is in \(.*\) format<br \/>.*/\1/p'`
			attr_file=`sed -n $((line + 2)),$((line + 3))p $filename`
			attr_file=`echo $attr_file | sed -n 's/\(.*\)<\/a>.*/\1/p'`
			
			# pdfs' filenames don't wind up on a new line. If the attr_file is empty, look for it elsewhere
			if [ "$attr_file" = "" ]
			then
				attr_file=`echo $fulltype | sed -n 's/.*<a href.*> *\(.*\)<\/a><br \/>.*/\1/p'`
			fi
			
			# Make sure that file has not been removed
			if [ -f "./attachments/$attr_file" ]
				then
					
					# Add the attachment to the message
					echo "Content-type: $type;"
					echo "  name=\"$attr_file\""
					echo "Content-Transfer-Encoding: base64"
					echo "Content-Disposition: attachment;"
					echo "  filename=\"$attr_file\""
					echo ""
					
					# Need to strip off the first and last line of uuencode's output
					uuencode -m "./attachments/$attr_file" "$attr_file" > tmpattr
					number_of_lines=`wc -l tmpattr | awk '// {print $1}'`
					processed_attr=`sed -n 2,$((number_of_lines - 1))p tmpattr`
					rm tmpattr
					
					# print that attachment
					echo "$processed_attr"
				
					#and the final boundary
					echo ""
					echo "--$boundary"
			fi
		done
	fi # attachments?
	
	echo ""
}

#conv_file retrieve.cgi_017.html
#exit 0

# convert all of the files
number=1
for file in `ls $foldername | grep .html`
do
	echo "Processing file $foldername/$file, saving conversion in file convd_$foldername/$number"
	conv_file $file > convd_$foldername/$number
	number=$((number + 1))
done
