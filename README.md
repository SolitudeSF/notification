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
