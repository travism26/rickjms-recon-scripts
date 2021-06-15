#!/bin/bash

INPUT_FILE=$1
USER_OUT="$2"
if test -z $USER_OUT; then
	OUTPUT_FILE="alive_hosts.out"
else
	OUTPUT_FILE="$USER_OUT"
fi

echo "" > $OUTPUT_FILE
# TMP_FILE="clean-tmp"
TMP_FILE=$(mktemp /tmp/clean-tmp.XXXXXX)
cat $INPUT_FILE | xargs -n1 -I{} sh -c "echo {} | sed 's/https\?:\/\///'" >> $TMP_FILE

function isHttps(){
	[ "$1" == "https*" ]
}

while IFS= read -r line
do
	echo "$line"

	if grep -q "https://$line" $INPUT_FILE; then
		if grep -q "https://$line" $OUTPUT_FILE; then
			# echo "already exists skipping"
			echo "exists"
		else
			# echo "Found https adding to $OUTPUT_FILE"
			grep "https://$line" $INPUT_FILE >> $OUTPUT_FILE
		fi
	else
		if grep -q "http://$line" $OUTPUT_FILE; then
			# echo "$line already exists skipping"
			echo "exists"
		else
			# echo "Default http adding to $OUTPUT_FILE"
			grep "http://$line" $INPUT_FILE >> $OUTPUT_FILE
		fi
	fi
	# if isHttps $line; then
	# 	echo "$line true is https"
	# else
	# 	echo "$line False not https"
	# fi
done < "$TMP_FILE"

# RAW_VALUE=$line
# CLEANED_VALUE=$(echo "$line" | sed 's/https\?:\/\///')
# grep $CLEANED_VALUE