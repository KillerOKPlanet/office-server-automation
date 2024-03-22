#!/bin/bash
	TOKEN="1766314763:AAFYvjd5c7sBWsWw0xXD-cLSB2UTpckxaPM"
	CHAT_ID="333250581"
    MESSAGE="${1:-Done!}"
	curl -s -X POST https://api.telegram.org/bot$TOKEN/sendMessage -d chat_id=$CHAT_ID -d text="$MESSAGE" > /dev/null

