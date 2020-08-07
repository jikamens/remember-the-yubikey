# Making your (Android) phone remind you when you've forgotten your YubiKey

## The problem

I use my [YubiKey](https://www.yubico.com/products/yubikey-hardware/)
multiple times every day to authenticate to various web sites, so I
tend to leave it plugged in. When I use it with a desktop computer I
don't carry with me, I run the risk of forgetting it's plugged in and
leaving it behind. If I forget it at work and then need it later at
home, it's a pain, and _vice versa_. This project prevents that from
happening by warning me if I walk away from my computer with the
YubiKey still plugged into it.

The goal is _not_ to prevent me from leaving my YubiKey plugged into
some random computer that's not mind that I happen to be using. On
computers like that, I only plug in my YubiKey for long enough to
authenticate, then put it away. The solution here is for computers you
use regularly that you can install software on, since you need to
install the software that generates the notifications that make this
work.

A different approach to be considered is one of the products, such as
[this one](http://www.owithme.com/), that would let you attach a tag
to your YubiKey and then detect and warn you when you walk away from
it. Personally, I didn't like that option, for a few reasons: the tags
are bigger and bulkier than the YubiKey; they use batteries which need
to be periodically replaced; and I [experimented with using Bluetooth
for this purpose][1] and [found it to be unreliable][2]. Also, to be
honest, this seemed like the kind of problem I could solve myself, so
I wanted to try that before paying somebody else to solve it for me.

## The solution

* The computers I use regularly send push notifications to my phone
  whenever I plug in or unplug my YubiKey.

* My phone uses the push notifications to keep track of whether my
  YubiKey is plugged in.

* My phone notices if I start walking around when my YubiKey is
  plugged in, and warns me quietly.

* If I miss the quiet notification and walk a little farther, my phone
  generates a more urgent warning that's much harder to miss.

## The moving parts

* A [shell script](yubikey-monitor.sh) deployed to my computers sends
  the push notifications.

* The push notifications are sent via [IFTTT](https://ifttt.com/) or
  [Pushover](https://pushover.net/).

* The shell script is triggered by a [udev rule](50-yubikey.rules)
  that fires when the YubiKey is plugged in or unplugged, and also by
  a [systemd timer](yubikey-monitor.timer) that runs a [systemd
  service](yubikey-monitor.service) every 60 seconds as a backstop in
  the unlikely event the udev rule doesn't work.

* [Tasker](https://tasker.joaoapps.com/) with the [AutoNotification][3]
  plug-in intercepts the push notifications, keeps track of state,
  detects when I am walking away from my computer, and generates
  warnings when needed.

## IFTTT vs. Pushover

IFTTT is free, whereas Pushover will cost you $4.99 for the Android
app after a 7-day free trial.

Pushover is slightly easier to set up than IFTTT, but both are equally
easy to use once they're set up.

Pushover is _much_ more reliable than IFTTT. Pushover almost always
delivers notifications in just a few seconds, whereas IFTTT
notifications can take several minutes to arrive (For the curious:
this is because Pushover uses Google's [FCM][4] to reliably push
notifications, whereas the IFTTT app uses periodic polling to check
for notifications, and the polling is especially unreliable when
Android decides to doze your phone.)

I started out using IFTTT, but I eventually decided that the frequent
notification delays were intolerable, so I've switched to using
Pushover. The code here supports either.

You can use _both_ IFTTT and Pushover for notifications if you want
redundancy to protect against one of the services being in the midst
of an outage when you plug in or unplug your YubiKey.

## Setting up IFTTT

1. Register for an [IFTTT](https://ifttt.com) account if you don't
   already have one.

2. Install the IFTTT app on your phone and log in.

3. On the IFTTT web site, set up a new applet as follows:

    1. For "this", select "Webhooks" and then "Receive a web request".
    2. Enter "yubikey\_plugged\_in" as the event name.
    3. For "that", select "Notifications" and then "Send a
       notification from the IFTTT app". 
    4. For the message, enter "YubiKey is plugged in".

4. Set up another applet as described above, but this time use
   "yubikey\_unplugged" as the event name and "YubiKey is not plugged
   in" as the message.

5. Go to your [Webhooks settings][5] and copy your maker key (the
   random string at the end of your Webhooks URL); you'll need it
   later.

## Setting up Pushover

1. Register for a [Pushover](https://pushover.net/) account if you
   don't already have one.

2. Install the Pushover app on your phone and log in.

3. Save your user key, which is prominently displayed on the Pushover
   home page after you log in, for later.

4. Create a new [Pushover Application](https://pushover.net/apps) and
   save its API token for later.

## How to deploy on your computer

1. Edit `yubikey-monitor.sh` and set the `MESSAGE_SERVICE` variable to
   `ifttt`, `pushover`, or `both`. The default is `pushover` since
   that's what I use.

2. Copy the script to `/usr/local/bin` and make sure it's executable.

3. If you're using IFTTT, then create the file `/root/.ifttt_maker_key`
   (Linux) or `~/.ifttt_maker_key` (Mac) and put the maker key which
   you saved above into it.

4. If you're using Pushover, then create the file
   `/root/.pushover_keys` (Linux) or `~/.pushover_keys` (Mac) and put
   your API token and user key (in that order) on the first two lines
   of the file.

5. Plug in your YubiKey and then run
   `/usr/local/bin/yubikey-monitor.sh` (as root on Linux, or as
   yourself on Mac). You should get two "YubiKey is plugged in"
   notifications on your phone if you're using just IFTTT or just
   Pushover, or four notification if you're using both. The
   notifications should come within ten seconds or so if you're using
   Pushover; they could take several minutes with IFTTT. On Mac, the
   script will continue running until you unplug the YubiKey in the
   next step.

6. Unplug your YubiKey (and on Linux run the script again) and you
   should get either two or four "YubiKey is not plugged in"
   notifications.

7. (Linux) Copy `linux/50-yubikey.rules` to `/etc/udev/rules.d` and
   run `udevadm control --reload`.

8. (Mac) Copy `mac/com.jik.RememberTheYubikey.plist` into
   `~/Library/LaunchAgents` and run `launchctl load
   ~/Library/LaunchAgents/com.jik.RememberTheYubikey.plist`.

9. Plug in your YubiKey and you should get the notifications without
   running the script by hand, since the udev / launchd rule should
   run it automatically.

10. Ditto when you unplug the YubiKey.

11. (Linux) Copy `linux/yubikey-monitor.service` and
   `linux/yubikey-monitor.timer` to `/etc/systemd/system` and run
   `systemctl daemon-reload`.

You can deploy the tool as described above on as many computers as you
would like. You won't get notified about walking away from a computer
with your YubiKey plugged into it unless you've deployed the tool on
that computer!

## How to deploy on your phone

1. Install [Tasker][6].

2. Install [AutoNotification][7]. You'll have to pay a couple of bucks
   for it after the 7-day free trial, but you can try it out first to
   make sure it's doing what you want and expect.

3. Copy [YubiKey\_Plugged\_In.prf.xml](tasker/YubiKey_Plugged_In.prf.xml),
   [YubiKey\_Unplugged.prf.xml](tasker/YubiKey_Unplugged.prf.xml),
   [YubiKey\_Soft\_Reminder.prf.xml](tasker/YubiKey_Soft_Reminder.prf.xml),
   and [YubiKey\_Loud\_Reminder.prf.xml](tasker/YubiKey_Loud_Reminder.prf.xml)
   to your phone and import them into Tasker by tapping "Profiles" and
   selecting "Import Profile" for each one.

4. Enable the four profiles and tap the checkmark at the top to put
   the changes into effect.

5. Plug in your YubiKey and confirm that either you don't see the
   notification on your phone, or it disappears shortly after it
   appears, indicating that AutoNotification intercepted and removed
   it.

6. In Tasker, tap "Vars" and confirm that the `YUBIKEY` variable is
   set to `1`.

7. Get up and walk around, and within 10-20 steps you should get a
   notification on your phone telling you not to forget your YubiKey.

8. Keep walking, and within 10-20 more steps your phone should vibrate
   and beep loudly.

9. Unplug your YubiKey, and confirm that the "Don't Forget Your
   YubiKey" notification is dismissed automatically.

At this point you can tweak the Tasker profiles and tasks as desired
to behave differently, if you wish.

## Can I use this for something other than a YubiKey?

With minimal modifications, you should be able to use this code for
any removable device, USB or otherwise, that generates `udev` events
when it is connected to and disconnected from your computer. You could
even get away without the `udev` events and rely exclusively on the
`systemd` timer if you can figure out code to put in the shell script
in place of `usb-devices | grep -q -s -i -w yubikey` to determine
whether the device is currently plugged in.

The things you would need to modify to generalize this to another
device are:

1. as noted above, the code in the shell script that determines
   whether the device is plugged in;

2. in the shell script and in your IFTTT applet, the names of the plug
   and unplug events used in IFTTT;

3. in the shell script and in your IFTTT applet, the text of the
   notification that gets sent when the device is plugged in or
   unplugged;

4. the `systemd service and timer names and descriptions;

5. the name of the shell script, though it doesn't have any functional
   relevance so if you don't want to bother you can just leave it; and

6. if you're going to still use `udev`, the vendor ID in the rules
   file, and you may want to add additional attributes to the rule to
   make it more selective. 

I am happy to accept pull requests to make the code more generalized
and extensible.

## Copyright

Copyright 2019 [Jonathan Kamens](mailto:jik@kamens.us)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.

[1]: https://blog.kamens.us/2018/08/15/how-i-remember-my-yubikey/
[2]: https://blog.kamens.us/2019/02/18/how-i-remember-my-yubikey-take-two/#unreliable
[3]: https://joaoapps.com/autonotification/
[4]: https://firebase.google.com/docs/cloud-messaging
[5]: https://ifttt.com/maker_webhooks/settings
[6]: https://play.google.com/store/apps/details?id=net.dinglisch.android.taskerm
[7]: https://play.google.com/store/apps/details?id=com.joaomgcd.autonotification
