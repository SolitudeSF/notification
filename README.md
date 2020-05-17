# notify
Easily send desktop notifications.

Supported OS

- [x] Linux/BSD (requires libdbus)

# Installation
`nimble install notify`

# Example
```nim
import notify

var n = initNotification(
  summary = "hello",
  body = "world",
  icon = "help-faq")

n.add Hint(kind: hkUrgency, urgency: Critical)

let handle = n.notify
```
