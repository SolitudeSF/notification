import sets, hashes
when defined(unix) and not defined(macos):
  import dbus
  import imageman/[images, colors]
else:
  {.error: "Target os is not supported".}

type
  Urgency* = enum
    Low = "low"
    Normal = "normal"
    Critical = "critical"

  HintKind* = enum
    hkActionIcons = "action-icons"
    hkCategory = "category"
    hkDesktopEntry = "desktop-entry"
    hkImageData = "image-data"
    hkImagePath = "image-path"
    hkResident = "resident"
    hkSoundFile = "sound-file"
    hkSoundName = "sound-name"
    hkSuppressSound = "suppress-sound"
    hkTransient = "transient"
    hkX = "x"
    hkY = "y"
    hkUrgency = "urgency"
    hkCustom

  ImageData* = object
    width*, height*: int32
    alpha*: bool
    data*: seq[byte]

  Hint* = object
    case kind*: HintKind
    of hkActionIcons:
      actionIcons*: bool
    of hkCategory:
      category*: string
    of hkDesktopEntry:
      desktopEntry*: string
    of hkImageData:
      imageData*: ImageData
    of hkImagePath:
      imagePath*: string
    of hkResident:
      resident*: bool
    of hkSoundFile:
      soundFile*: string
    of hkSoundName:
      soundName*: string
    of hkSuppressSound:
      suppressSound*: bool
    of hkTransient:
      transient*: bool
    of hkX:
      x*: int32
    of hkY:
      y*: int32
    of hkUrgency:
      urgency*: Urgency
    of hkCustom:
      customName*: string
      customValue*: DbusValue

  TimeoutKind* = enum
    tkDefault, tkNever, tkMilliseconds

  Timeout* = object
    case kind: TimeoutKind
    of tkDefault, tkNever: discard
    of tkMilliseconds: value*: int32

  Notification* = object
    appname*, summary*, body*, icon*: string
    hints*: HashSet[Hint]
    actions*: seq[string]
    timeout*: Timeout
    replaceId*: uint32

  NotificationHandle* = object
    id*: uint32
    bus*: Bus
    notification*: Notification

const
  dbusObjectPath = ObjectPath("/org/freedesktop/Notifications")
  dbusInterface = "org.freedesktop.Notifications"

func hash(h: Hint): Hash = h.kind.int
func `==`(a, b: Hint): bool = a.kind == b.kind

func toByteSeq[T: Color](i: Image[T]): seq[byte] =
  result = newSeq[byte](i.data.len * sizeof T)
  copyMem addr result[0], unsafeAddr i.data[0], result.len

func asDbusValue(h: Hint): DbusValue =
  result = DbusValue(kind: dtVariant)
  case h.kind
  of hkActionIcons:
    result.variantType = DbusType(kind: dtBool)
    result.variantValue = DbusValue(kind: dtBool, boolValue: h.actionIcons)
  of hkCategory:
    result.variantType = DbusType(kind: dtString)
    result.variantValue = DbusValue(kind: dtString, stringValue: h.category)
  of hkDesktopEntry:
    result.variantType = DbusType(kind: dtString)
    result.variantValue = DbusValue(kind: dtString, stringValue: h.desktopEntry)
  of hkImageData:
    result.variantType = DbusType(kind: dtStruct, itemTypes: @[
      DbusType(kind: dtInt32), DbusType(kind: dtInt32), DbusType(kind: dtInt32),
      DbusType(kind: dtBool), DbusType(kind: dtInt32), DbusType(kind: dtInt32),
      DbusType(kind: dtArray, itemType: DbusType(kind: dtByte))
    ])
    result.variantValue = DbusValue(kind: dtStruct, structValues: @[
      asDbusValue h.imageData.width,
      asDbusValue h.imageData.height,
      asDbusValue h.imageData.data.len.int32 div h.imageData.height,
      asDbusValue h.imageData.alpha,
      asDbusValue 8'i32,
      asDbusValue (if h.imageData.alpha: 4'i32 else: 3'i32),
      asDbusValue h.imageData.data
    ])
  of hkImagePath:
    result.variantType = DbusType(kind: dtString)
    result.variantValue = DbusValue(kind: dtString, stringValue: h.imagePath)
  of hkResident:
    result.variantType = DbusType(kind: dtBool)
    result.variantValue = DbusValue(kind: dtBool, boolValue: h.resident)
  of hkSoundFile:
    result.variantType = DbusType(kind: dtString)
    result.variantValue = DbusValue(kind: dtString, stringValue: h.soundFile)
  of hkSoundName:
    result.variantType = DbusType(kind: dtString)
    result.variantValue = DbusValue(kind: dtString, stringValue: h.soundName)
  of hkSuppressSound:
    result.variantType = DbusType(kind: dtBool)
    result.variantValue = DbusValue(kind: dtBool, boolValue: h.suppressSound)
  of hkTransient:
    result.variantType = DbusType(kind: dtBool)
    result.variantValue = DbusValue(kind: dtBool, boolValue: h.transient)
  of hkX:
    result.variantType = DbusType(kind: dtInt32)
    result.variantValue = DbusValue(kind: dtInt32, int32Value: h.x)
  of hkY:
    result.variantType = DbusType(kind: dtInt32)
    result.variantValue = DbusValue(kind: dtInt32, int32Value: h.y)
  of hkUrgency:
    result.variantType = DbusType(kind: dtByte)
    result.variantValue = DbusValue(kind: dtByte, byteValue: h.urgency.uint8)
  of hkCustom:
    result.variantType = DbusType(kind: h.customValue.kind)
    result.variantValue = h.customValue

template withContainer(iter: ptr DBusMessageIter, kind: DbusTypeChar, sig: cstring, subIter, body): untyped =
  var subIterObj: DBusMessageIter
  let subIter = addr subIterObj
  if dbus_message_iter_open_container(iter, kind.cint, sig, subIter) == 0:
    raise newException(DbusException, "open_container")
  body
  if dbus_message_iter_close_container(iter, subIter) == 0:
    raise newException(DbusException, "close_container")

proc appendArray(iter: ptr DBusMessageIter, sig: cstring, s: seq[byte]) =
  iter.withContainer dtArray, sig, subIter:
    for item in s:
      if dbus_message_iter_append_basic(subIter, dtByte.cint, unsafeAddr item) == 0:
        raise newException(DbusException, "append_basic")

proc appendStruct(iter: ptr DBusMessageIter, i: ImageData) =
  iter.withContainer dtStruct, nil, subIter:
    subIter.append i.width
    subIter.append i.height
    subIter.append i.data.len.int32 div i.height
    subIter.append i.alpha
    subIter.append 8'i32
    subIter.append (if i.alpha: 4'i32 else: 3'i32)
    subIter.appendArray "y", i.data

proc appendVariant(iter: ptr DBusMessageIter, sig: cstring, val: ImageData) =
  iter.withContainer dtVariant, sig, subIter:
    subIter.appendStruct val

proc appendDictEntry(iter: ptr DBusMessageIter, h: Hint) =
  iter.withContainer dtDictEntry, nil, subIter:
    assert h.kind == hkImageData
    subIter.append $h.kind
    subIter.appendVariant "(iiibiiay)", h.imageData

proc appendArray(iter: ptr DBusMessageIter, sig: cstring, h: HashSet[Hint]) =
  iter.withContainer dtArray, sig, subIter:
    for item in h:
      case item.kind
      of hkImageData:
        subIter.appendDictEntry item
      of hkCustom:
        subIter.append(DbusValue(
          kind: dtDictEntry,
          dictKey: item.customName.asDbusValue,
          dictValue: item.asDbusValue))
      else:
        subIter.append(DbusValue(
          kind: dtDictEntry,
          dictKey: asDbusValue $item.kind,
          dictValue: item.asDbusValue))

proc append(msg: Message, h: HashSet[Hint]) =
  var iter = msg.initIter
  iter.addr.appendArray "{sv}", h

func add*(n: var Notification, h: Hint) =
  n.hints.incl h

func addAction*(n: var Notification, identifier, label: string) =
  n.actions.add identifier
  n.actions.add label

func toHint*[T: Color](i: Image[T]): Hint =
  Hint(kind: hkImageData, imageData:
    ImageData(width: i.width.int32, height: i.height.int32, alpha: T is ColorA,
    data: i.converted(when T is ColorA: ColorRGBAU else: ColorRGBU).toByteSeq))

func duration*(t: Timeout): int32 =
  case t.kind
  of tkDefault: -1'i32
  of tkNever: 0'i32
  of tkMilliseconds: t.value

func initTimeout*(duration = -1'i32): Timeout =
  case duration
  of -1: Timeout(kind: tkDefault)
  of 0: Timeout(kind: tkNever)
  else: Timeout(kind: tkMilliseconds, value: duration)

func initNotification*(summary: string, body = "", appname = "", icon = "",
  hints = initHashSet[Hint](), actions: openArray[(string, string)] = [],
  timeout = Timeout(kind: tkDefault), replaceId = 0'u32): Notification =
  result = Notification(summary: summary, body: body, appname: appname,
    icon: icon, hints: hints, timeout: timeout, replaceId: replaceId)
  for (id, label) in actions:
    result.addAction id, label

proc getCapabilities*(b = getBus(DBUS_BUS_SESSION)): seq[string] =
  var msg = makeCall(dbusInterface, dbusObjectPath, dbusInterface, "GetCapabilities")
  let reply = waitForReply b.sendMessageWithReply msg
  var iter = iterate reply
  let res = iter.unpackCurrent(DbusValue)
  result = newSeq[string](res.arrayValue.len)
  for i, v in res.arrayValue:
    result[i] = v.stringValue

proc notify*(b: Bus, n: Notification): NotificationHandle =
  var msg = makeCall(dbusInterface, dbusObjectPath, dbusInterface, "Notify")
  msg.append n.appname
  msg.append n.replaceId
  msg.append n.icon
  msg.append n.summary
  msg.append n.body
  msg.append n.actions
  msg.append n.hints
  msg.append n.timeout.duration

  NotificationHandle(
    id: block:
      if n.replaceId == 0:
        let reply = waitForReply b.sendMessageWithReply msg
        var iter = iterate reply
        iter.unpackCurrent(DbusValue).uint32Value
      else:
        discard b.sendMessage msg
        n.replaceId,
    bus: b,
    notification: n)

proc notify*(n: Notification): NotificationHandle =
  getBus(DBUS_BUS_SESSION).notify n

proc closeNotification*(b = getBus(DBUS_BUS_SESSION), id: uint32) =
  var msg = makeCall(dbusInterface, dbusObjectPath, dbusInterface, "CloseNotification")
  msg.append id
  b.sendMessage msg

proc closeNotification*(n: NotificationHandle) =
  n.bus.closeNotification n.id

proc getServerInformation*(b = getBus(DBUS_BUS_SESSION)): tuple[name, vendor, version, specVersion: string] =
  var msg = makeCall(dbusInterface, dbusObjectPath, dbusInterface, "GetServerInformation")
  let reply = waitForReply b.sendMessageWithReply msg
  var iter = iterate reply
  result.name = iter.unpackCurrent(DbusValue).stringValue
  iter.advanceIter
  result.vendor = iter.unpackCurrent(DbusValue).stringValue
  iter.advanceIter
  result.version = iter.unpackCurrent(DbusValue).stringValue
  iter.advanceIter
  result.specVersion = iter.unpackCurrent(DbusValue).stringValue
