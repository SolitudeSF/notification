# notification
Easily send desktop notifications.

Supported OS

- [x] Linux/BSD (requires libdbus)

# Installation
`nimble install notification`

# Example
```nim
import notification

var n = initNotification(
  summary = "hello",
  body = "world",
  icon = "help-faq")

n.add Hint(kind: hkUrgency, urgency: Critical)

let handle = n.notify
```

# Extended example using custom hint type 
```nim
# Example of sending a custom Hint type that replaces an 
# existing notification as outlined here: 
# https://wiki.archlinux.org/index.php/Desktop_notifications#Replace_previous_notification 
#
# Note that unlike replaceId, which works only when replacing a notification within a 
# running application, this approach works across different processes, as it uses 
# libnotify's in-built mechanism for this.  

import notification
import dbus
import os

let hint = Hint(
    kind: hkCustom, 
    customName:"x-canonical-private-synchronous", 
    customValue: "some-identifier".asDbusValue)

var n = initNotification(
  appname = "someapp",
  summary = "hello",
  body = "I'm gonna be here a real long time...",
  icon = "help-faq", 
  timeout = initTimeout(30 * 1000), 
)
n.add(hint)

discard n.notify

n = initNotification(
  appname = "someapp",
  summary = "hello again",
  body = "Think again!",
  icon = "help-faq", 
  timeout = initTimeout(5 * 1000), 
)

n.add(hint)

sleep(2000)
discard n.notify
```
