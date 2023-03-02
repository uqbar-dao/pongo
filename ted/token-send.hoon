/-  spider, pongo, uqbar=zig-uqbar, wallet=zig-wallet
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
::
++  take-asset-metadata
  |=  [from=@ux item=@ux]
  =/  m  (strand ,@ux)
  ^-  form:m
  ;<  wu=wallet-update:wallet  bind:m
    %+  scry  wallet-update:wallet
    /gx/wallet/asset/(scot %ux from)/(scot %ux item)/noun
  ?>  ?=(%asset -.wu)
  %-  pure:m
  ?-  -.+.wu
    %token    metadata.wu
    %nft      metadata.wu
    %unknown  0x0
  ==
::
++  take-metadata-symbol
  |=  [metadata=@ux]
  =/  m  (strand ,@t)
  ^-  form:m
  ;<  wu=wallet-update:wallet  bind:m
    %+  scry  wallet-update:wallet
    /gx/wallet/metadata/(scot %ux metadata)/noun
  ?>  ?=(%metadata -.wu)
  %-  pure:m
  ?-  -.+.wu
    %token    symbol.wu
    %nft      symbol.wu
  ==
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
::  get wallet metadata to show what token we sent
::
;<  metadata=@ux  bind:m  (take-asset-metadata [from item]:act)
::  get token symbol from metadata
::
;<  symbol=@t  bind:m  (take-metadata-symbol metadata)
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
          (rap 3 ~[(scot %ud amount.act) ' ' symbol ' ' (scot %p to.act)])
          ~
          (silt ~[to.act])
      ==
  ==
::
(pure:m !>(~))