#!/bin/sh

CURL='/usr/bin/curl'
AWK='/usr/bin/awk'
SED='/bin/sed'
GREP='/bin/grep'
LOGIN_CONF='login.xml'

JOB_CONF='job.xml'
DATA_CONF='data.csv'
CLOSE_CONF='close_job.xml'
LOGINURL='https://test.salesforce.com/services/Soap/u/28.0'
HEADER_SESSION='X-SFDC-Session:'
HEADER_TEXT_XML='Content-Type: text/xml; charset=UTF-8'
HEADER_APP_XML='Content-Type: application/xml; charset=UTF-8'
HEADER_TEXT_CSV='Content-Type: text/csv; charset=UTF-8'


#1. Get sid
response=`$CURL -s $LOGINURL -H "$HEADER_TEXT_XML" -H "SOAPAction: login" -d @$LOGIN_CONF 2>&1`
if [ $? -eq 0 ] ; then
	sid=`echo $response | $AWK -F 'sessionId' '{print $2}' | $SED -e 's/>//g' | $SED -e 's/<\///g'`
	ENDPOINT=`echo $response | $AWK -F '<serverUrl>' '{print $2}' | $AWK -F '/services' '{print $1}'`"/services/async/28.0/job"
	if [ $sid ] ; then
		echo "sid: $sid"
	else
		echo "*** Failed to login with the following response."
		echo $response
		exit 1
	fi
else
	echo "Failed"
	exit 1
fi


#2. Create job
response=`$CURL -s $ENDPOINT -H "$HEADER_SESSION $sid" -H "$HEADER_APP_XML" -d @$JOB_CONF 2>&1`

if [ $? -eq 0 ] ; then
	jobid=`echo $response | $AWK -F 'id' '{print $2}' | $SED -e 's/>//g' | $SED -e 's/<\///g'`
	if [ $jobid ] ; then
		echo "jobid: $jobid"
	else
		echo "*** Failed to create a job with the following response."
		echo "$response"
		exit 1
	fi
else
	echo "Failed"
	exit 1
fi


#3. Create batch and execute
response=`$CURL -s $ENDPOINT/$jobid/batch -H "$HEADER_SESSION $sid" -H "$HEADER_TEXT_CSV" --data-binary @$DATA_CONF 2>&1`
if [ $? -eq 0 ] ; then
	batchid=`echo $response | $AWK -F 'id' '{print $2}' | $SED -e 's/>//g' | $SED -e 's/<\///g'`
	if [ $batchid ] ; then
		echo "batchid: $batchid"
	else
		echo "*** Failed to create batch and execute with the following response."
		echo "$response"
		exit 1
	fi
else
	echo "Failed"
	exit 1
fi


#4. Close job
response=`$CURL -s $ENDPOINT/$jobid -H "$HEADER_SESSION $sid" -H "$HEADER_APP_XML" -d @$CLOSE_CONF 2>&1`
if [ $? -eq 0 ] ; then
	state=`echo $response | $AWK -F 'state' '{print $2}' | $SED -e 's/>//g' | $SED -e 's/<\///g'`
	if [ $state ] ; then
		echo "state: $state"
	else
		echo "*** Failed to close a job with the following response."
		echo "$response"
		exit 1
	fi
else
	echo "Failed"
	exit 1
fi
