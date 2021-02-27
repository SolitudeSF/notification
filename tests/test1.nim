import unittest
import ../src/notification
import imageman/[images, colors]

var id: uint32

test "get capabilities":
  echo getCapabilities()
  check true

test "notify":
  id = notify(n = initNotification(summary = "test"))
  check id != 0

test "close notification":
  closeNotification(id)
  check true

test "get server information":
  echo getServerInformation()
  check true

test "display image":
  var
    n = initNotification("text")
    i = initImage[ColorRGBU](1000, 1000)
  for n in 0..i.data.high:
    i[n] = rand[ColorRGBU]()
  n.add i.toHint
  n.add Hint(kind: hkUrgency, urgency: Critical)
  discard notify(n)
