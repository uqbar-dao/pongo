::
::  Produce signed timestamps to be used by a QR code reader and generator,
::  in order to instantly verify ship control in a physical setting.
::
/-  *handshake
/+  default-agent, dbug
|%
+$  card  card:agent:gall
+$  state
  $:  %0
      latest=(unit [code=@ expires-at=@da])
  ==
--
::
=|  =state
%-  agent:dbug
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init  `this(state [%0 ~])
++  on-save  !>(state)
++  on-load
  |=  =vase
  ^-  (quip card _this)
  =/  old=(unit ^state)
    (mole |.(!<(^state vase)))
  ?~  old  on-init
  `this(state u.old)
::
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-peek   on-peek:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ::
  ::  all subscriptions from frontend
  ::
  ?>  =(src.bowl our.bowl)
  ?+    -.path  !!
      %signer-updates
    ::  provide our most recent punch card
    ?~  latest.state  `this
    :_  this
    ~[[%give %fact ~ signer-update+!>([%new-sig u.latest.state])]]
  ::
      %reader-updates
    ::  provide updates on signatures we verify on this path
    `this
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  ?>  =(src.bowl our.bowl)
  ?.  ?=(%handshake-action mark)  !!
  =/  =action  !<(action vase)
  ?-    -.action
      %create
    ::  generate signature to be QR'd on frontend
    ::  signature is timestamped for 5 minutes in future,
    ::  which %verify uses as an expiration date.
    ::  currently always hashing same message, can customize this
    ::  in the future
    =/  =time  (add now.bowl expiration)
    =+  exp=(cut 3 [8 5] time)
    =+  msg=(rap 3 `(list @)`~[exp '%handshake verification'])
    =+  new=(jam `punch`[exp [`@ux`p r]:(sign msg [our now]:bowl)])
    ::  give subscriber notice of our new punch card, to be QR'd
    :_  this(latest.state `[new time])
    =-  [%give %fact ~[/signer-updates] -]^~
    handshake-signer-update+!>(`signer-update`[%new-sig new time])
  ::
      %verify
    ::  take in jammed signature and verify correctness
    =*  who  src.bowl
    =/  =punch  ;;(punch (cue code.action))
    =+  msg=(rap 3 ~[time.punch '%handshake verification'])
    ?.  (verify [p.punch who r.punch] msg [our now]:bowl)
      ~&  >>>  "%scan: received an invalid signature!"
      [(reader-card [%bad-sig ~]) this]
    =/  =time  (rap 3 ~[0x1000.0000.0000.0000 time.punch 0x80.0000])
    ?:  (gth now.bowl time)
      ~&  >>>  "%scan: received an expired signature!"
      [(reader-card [%expired-sig who]) this]
    ::  give subscriber notice of GOOD signature!
    ~&  >  "%scan: received signature from {<who>}"
    [(reader-card [%good-sig who]) this]
  ==
  ::
  ::  helpers
  ::
  ++  reader-card
    |=  upd=reader-update
    ^-  (list card)
    ~[[%give %fact ~[/reader-updates] handshake-reader-update+!>(upd)]]
  ::
  ++  sign
    |=  [hash=@ our=ship now=time]
    ^-  signature
    =+  (jael-scry ,=life our %life now /(scot %p our))
    =+  (jael-scry ,=ring our %vein now /(scot %ud life))
    (sign:as:(nol:nu:crub:crypto ring) hash)^our^life
  ::
  ++  verify
    |=  [=signature hash=@ our=ship now=time]
    ^-  ?
    =+  (jael-scry ,lyf=(unit @) our %lyfe now /(scot %p q.signature))
    ?~  lyf  %.n
    ?.  =(u.lyf r.signature)  %.n
    =+  %:  jael-scry
          ,deed=[a=life b=pass c=(unit @ux)]
          our  %deed  now  /(scot %p q.signature)/(scot %ud r.signature)
        ==
    ?.  =(a.deed r.signature)  %.n
    =(`hash (sure:as:(com:nu:crub:crypto b.deed) p.signature))
  ::
  ++  jael-scry
    |*  [=mold our=ship desk=term now=time =path]
    .^(mold %j (weld /(scot %p our)/[desk]/(scot %da now) path))
  --
--
