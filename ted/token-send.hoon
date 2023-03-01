/-  spider, pongo, uqbar=zig-uqbar
/+  *strandio, pongo
=,  strand=strand:spider
=>
|%
++  take-update
  =/  m  (strand ,@ux)
  ^-  form:m
  ;<  =cage  bind:m  (take-fact /thread-watch)
  =/  upd=thread-update:pongo  !<(thread-update:pongo q.cage)
  ?.  ?=(%shared -.upd)
    ::  failed  ! surface this somehow
    !!
  (pure:m address.upd)
::
++  take-receipt
  =/  m  (strand ,sequencer-receipt:uqbar)
  ^-  form:m
  ;<  =cage  bind:m  (take-fact /thread-watch)
  =/  upd=thread-update:pongo  !<(thread-update:pongo q.cage)
  ?.  ?=(%finished -.upd)
    ::  failed  ! surface this somehow
    !!
  (pure:m +.upd)
--
::
^-  thread:spider
|=  arg=vase
=/  m  (strand ,vase)
=/  act  !<(action:pongo arg)
?.  ?=(%send-tokens -.act)  (pure:m !>(~))
^-  form:m
::  first, watch updates from pongo
::
;<  ~  bind:m  (watch-our /thread-watch %pongo /token-send-updates)
::  next, poke wallet of ship we want address for
::
;<  ~  bind:m
  %-  send-raw-card
  :*  %pass   /uqbar-address-from-ship
      %agent  [to.act %wallet]
      %poke   uqbar-share-address+!>([%request %pongo])
  ==
::  take fact from pongo with result of poke
::
;<  address=@ux  bind:m  take-update
;<  our=@p       bind:m  get-our
::  poke wallet to approve origin so we don't have to sign
::
;<  ~  bind:m
  %-  send-raw-card
  :*  %pass   /approve-pongo-origin
      %agent  [our %wallet]
      %poke   %wallet-poke
      !>([%approve-origin [%pongo /token-send] [rate=1 bud=1.000.000]])
  ==
::  poke wallet with transaction
::
;<  ~  bind:m
  %-  send-raw-card
  :*  %pass   /uqbar-address-from-ship
      %agent  [our %wallet]
      %poke   %wallet-poke
      !>
      :*  %transaction
          `[%pongo /token-send]
          from.act
          contract.act
          town.act
          [%give address amount.act item.act]
      ==
  ==
::  take receipt fact once txn is completed
::
;<  =sequencer-receipt:uqbar  bind:m  take-receipt
::  finally, produce message poke!
::
;<  ~  bind:m
  %-  send-raw-card
  :*  %pass   /send-message
      %agent  [our %pongo]
      %poke   %pongo-action
      !>  ^-  action:pongo
      :*  %send-message
          ''
          conversation-id.act
          %send-tokens
          (crip "I just sent {<amount.act>} tokens to {<to.act>}")
          ~
          (silt ~[to.act])
      ==
  ==
::
(pure:m !>(~))