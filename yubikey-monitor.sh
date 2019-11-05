#!/bin/bash -e

# Copyright 2019 Jonathan Kamens
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Set to pushover, ifttt, or both
MESSAGE_SERVICE=pushover
# Put your Pushover API token and user key on the first two lines of this file
# if using Pushover
PUSHOVER_KEY_FILE=/root/.pushover_keys
# Put your IFTTT maker key in this file if using IFTTT
IFTTT_KEY_FILE=/root/.ifttt_maker_key

FLAG=/var/run/yubikey-watcher
MIN_NOTIF_GAP=5
NUM_NOTIFICATIONS=2

exit_status=0

trap "rm -f \"$FLAG.lock\"" EXIT
lockfile -1 -l 15 "$FLAG.lock"

check_yubikey() {
    usb-devices 2>/dev/null | grep -q -s -i -w yubikey
}

next_state() {
    if [ "$ACTION" = "add" ]; then
        echo "plugged"
    else
        echo "unplugged"
    fi
}

notify_message() {
    if [ "$ACTION" = "add" ]; then
        echo "yubikey_plugged_in"
    else
        echo "yubikey_unplugged"
    fi
}

doit() {
    if check_yubikey; then
        ACTION="add"
    else
        ACTION="remove"
    fi

    set $(cat $FLAG 2>/dev/null || :)
    REMAINING_NOTIFICATIONS=$NUM_NOTIFICATIONS
    if [ "$1" ]; then
        STATE=$1; shift
        if [ "$1" ]; then
            LAST_TIME=$1; shift
            if [ "$1" ]; then
                REMAINING_NOTIFICATIONS=$1; shift
            fi
        fi
    fi

    NEXT_STATE=$(next_state)

    if [ "$NEXT_STATE" != "$STATE" ]; then
        REMAINING_NOTIFICATIONS=$NUM_NOTIFICATIONS
    elif (( REMAINING_NOTIFICATIONS == 0 )); then
        return 1
    fi

    ((REMAINING_NOTIFICATIONS--))

    if [ "$LAST_TIME" ]; then
        DELTA=$(($(date +%s) - LAST_TIME))
        REMAINING=$((MIN_NOTIF_GAP - DELTA))
        if [ $REMAINING -gt 0 ]; then
            echo Delaying notification for $REMAINING seconds
            sleep $REMAINING
            doit
            return $?
        fi
    fi

    if [ "$MESSAGE_SERVICE" = "ifttt" -o "$MESSAGE_SERVICE" = "both" ]; then
        if ! ifttt_key=$(cat $IFTTT_KEY_FILE); then
            echo IFTTT Maker key not installed in $IFTTT_KEY_FILE 1>&2
            exit_status=1
        else
            url=https://maker.ifttt.com/trigger/$(notify_message)/with/key
            # The echo ensures there is a final newline
            echo $(curl --silent "$url/$ifttt_key")
            echo Triggered "$url/[key-elided]"
        fi
    fi

    if [ "$MESSAGE_SERVICE" = "pushover" -o "$MESSAGE_SERVICE" = "both" ]; then
        set $(cat $PUSHOVER_KEY_FILE 2>/dev/null || :)

        if [ ! "$1" -o ! "$2" ]; then
            echo "Put your Pushover API and user keys on the first two" 1>&2
            echo "lines of $PUSHOVER_KEY_FILE" 1>&2
            exit_status=1
        else
            url=https://api.pushover.net/1/messages.json
            not=""
            if [ $NEXT_STATE = "unplugged" ]; then
                not=" not"
            fi
            message="YubiKey is$not plugged in"
            echo $(curl -s --form-string token="$1" --form-string user="$2" \
                 --form-string message="$message" $url)
            echo "Triggered $url"
        fi
    fi

    if [ "$MESSAGE_SERVICE" != "ifttt" -a "$MESSAGE_SERVICE" != "pushover" -a \
         "$MESSAGE_SERVICE" != "both" ]; then
        echo "Set \$MESSAGE_SERVICE to \"ifttt\", \"pushover\", or \"both\"" 1>&2
        exit_status=1
    fi

    if [ "$exit_status" != 0 ]; then
        REMAINING_NOTIFICATIONS=0
    fi

    echo "$NEXT_STATE $(date +%s) $REMAINING_NOTIFICATIONS" >| $FLAG
    return 0
}

while doit; do
    :
done

exit $exit_status
