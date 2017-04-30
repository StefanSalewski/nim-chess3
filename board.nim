import gtk3, gdk3, glib, gobject, pango, cairo, pango_cairo

from engine import Board, getBoard, doMove, reply, tag, moveToStr, moveIsValid, Flag, SureCheckmate,
  StalemateMarker, StopGameMarker

from OS import sleep

const # unicode font chars
  Figures: array[-6..6, cstring] = ["\xe2\x99\x9A".cstring, "\xe2\x99\x9B", "\xe2\x99\x9C", "\xe2\x99\x9D", "\xe2\x99\x9E", "\xe2\x99\x9F", "",
    "\xe2\x99\x99", "\xe2\x99\x98", "\xe2\x99\x97", "\xe2\x99\x96", "\xe2\x99\x95", "\xe2\x99\x94"]

proc rot180(b: Board): Board {.inline, noinit.} =
  for i, f in b:
    result[63 - i] = f

var tagged {.noinit.}: Board
#var vismark: Board

proc drawIt(cr: cairo.Context; widget: Widget) {.cdecl.} =
  const
    Font = "Sans 64"

  var
    w, h: cint
    #width: cint = widget.parentWindow.width
    #height = widget.parentWindow.height
    width = getAllocatedWidth(widget)
    height = getAllocatedHeight(widget)
    w8 = width div 8
    h8 = height div 8
    board = rot180(getBoard())
    layout: pango.Layout
    desc: pango.FontDescription
  for i, t in tagged:
    #var h = if t > 0: 0.2 else: 0
    var h: float
    case t
      of 2:
        h = 0.1
      of 1:
        h = 0.2
      else:
        h = 0
    #if vismark[i] != 0:
    #  h += 0.1
    if i mod 2 != (i div 8) mod 2:
      cr.setSourceRgba(0.9, 0.9, 0.9 - h, 1)
    else:
      cr.setSourceRgba(1, 1, 1 - h, 1)
    cr.rectangle(cdouble((i mod 8) * w8), cdouble((i div 8) * h8), w8.cdouble, h8.cdouble)
    cr.fill
  layout = createLayout(cr)
  desc = pango.fontDescriptionFromString(Font)
  #desc.weight = Weight.BOLD
  desc.absoluteSize = min(width, height) / 8 * pango.Scale
  layout.setFontDescription(desc)
  pango.free(desc)
  for i, f in board:
    if tagged[i] < 0:
      cr.setSourceRgba(0, 0, 0, 0.5)
    else:
      cr.setSourceRgba(0, 0, 0, 1)
    layout.setText(Figures[f], -1)
    cr.updateLayout(layout)
    layout.getSize(w, h)
    cr.moveTo(cdouble((i mod 8) * w8 + w8 div 2 - w div 2 div pango.Scale), cdouble((i div 8) * h8 + h8 div 2 - h div 2 div pango.Scale))
    cr.showLayout(layout)
  objectUnref(layout)

proc onButtonPressEvent(widget: Widget; event: EventButton; userData: Gpointer): Gboolean {.cdecl.} =
  var
    p0 {.global.} = -1
    p1, x, y: int
    msg: string
  for i in mitems(tagged): i = 0
  #x =  int(event.x) div (widget.parentWindow.width div 8)
  #y = int(event.y) div (widget.parentWindow.height div 8)
  x =  int(event.x) div (widget.getAllocatedWidth div 8)
  y = int(event.y) div (widget.getAllocatedHeight div 8)
  if p0 < 0:
    p0 = 63 - (x + y * 8)
    for i in tag(p0):
      tagged[63 - i.di] = 1
    tagged[63 - p0] = -1
    widget.parentWindow.invalidateRect(gdk3.Rectangle(nil), false)
  else:
    p1 = 63 - (x + y * 8)
    if p0 == p1 or not moveIsValid(p0, p1):
      if p0 != p1: gtk3.window(widget.toplevel).title= "invalid move, ignored."
      p0 = -1
      widget.parentWindow.invalidateRect(gdk3.Rectangle(nil), false)
      return false
    var flag = doMove(p0, p1)
    tagged[63 - p0] = 2
    tagged[63 - p1] = 2
    #vismark[p1] = 1
    gtk3.window(widget.toplevel).title = moveToStr(p0, p1, flag)
 
    widget.parentWindow.invalidateRect(gdk3.Rectangle(nil), false)
    setCursor(widget.parentWindow, newCursor(displayGetDefault(), "wait"))
    while gtk3.eventsPending(): discard gtk3.mainIteration()
    var m = reply()
    tagged[63 - p0] = 0
    tagged[63 - p1] = 0
    p0 = -1
    #tagged[63 - m.src] = 1
    #tagged[63 - m.dst] = 1
    #gtk3.window(widget.toplevel).title = "xxx"#moveToStr(p0, p1, flag)
    #widget.parentWindow.invalidateRect(gdk3.Rectangle(nil), false)
    #setCursor(widget.parentWindow, newCursor(displayGetDefault(), "wait"))
    #usleep(2000000)
    #while gtk3.eventsPending(): discard gtk3.mainIteration()
    #discard gtk3.mainIteration()
    tagged[63 - m.src] = 2
    tagged[63 - m.dst] = 2
    if m.checkmateDepth != StalemateMarker and m.checkmateDepth != StopGameMarker:
      flag = doMove(m.src, m.dst)
      msg = moveToStr(m.src, m.dst, flag) & " (score: " & $m.score & ")"
    if m.checkmateDepth == StalemateMarker:
      msg = "Stalemate, game terminated!"
    elif m.checkmateDepth == StopGameMarker:
      msg = "Checkmate, game terminated!"
    elif m.score > SureCheckmate:
      msg &= " mate in " & $m.checkmateDepth
    elif m.score < -SureCheckmate:
      msg &= " computer is mate in " & $m.checkmateDepth
    gtk3.window(widget.toplevel).title = msg
    setCursor(widget.parentWindow, gdk3.Cursor(nil))
    widget.parentWindow.invalidateRect(gdk3.Rectangle(nil), false)
  return false

proc onDrawEvent(widget: Widget; cr: cairo.Context; userData: Gpointer): Gboolean {.cdecl.} =
  drawIt(cr, widget)
  return false

proc mainProc =
  var window = newWindow()
  var darea = newDrawingArea()
  darea.addEvents(EventMask.BUTTON_PRESS_MASK.cint)
  window.add(darea)
  discard gSignalConnect(darea, "draw", cast[GCallback](onDrawEvent), nil) # yes, we should fix that ugly cast!
  discard gSignalConnect(darea, "button-press-event", cast[GCallback](onButtonPressEvent), nil)
  discard gSignalConnect(window, "destroy", cast[GCallback](mainQuit), nil)
  window.position = WindowPosition.Center
  window.setDefaultSize(800, 800)
  window.title = "Plain toy chess game, GTK3 GUI with Unicode chess pieces, coded from scratch in Nim"
  window.showAll

gtk3.initWithArgv()
mainProc()
gtk3.main()

