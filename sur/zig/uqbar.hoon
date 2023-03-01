/-  eng=zig-engine
/+  smart=zig-sys-smart
|%
::
::  signed transaction result, from sequencer
::
+$  sequencer-receipt
  $:  ship-sig=[p=@ux q=ship r=life]
      uqbar-sig=sig:smart
      position=@ud
      =transaction:smart
      =output:eng
  ==
::
::  pokes
::
+$  action
  $%  [%set-sources towns=(list [town=id:smart dock])]
      [%remove-source town=id:smart source=dock]
      [%set-wallet-source app-name=term]  ::  to use third-party wallet app
      [%open-faucet town=id:smart send-to=address:smart]
  ==
::
+$  write
  $%  [%submit =transaction:smart]
      [%receipt tx-hash=hash:smart sequencer-receipt]  ::  from the sequencer
  ==
::
+$  share-address
  $%  [%request app=term]
      [%deny ~]
      [%share =address:smart]
  ==
::
::  responses from sending a %submit poke
::
+$  write-result
  %+  pair  hash:smart  ::  the hash of the submitted transaction
  $%  [%sent ~]
      [%delivered ~]
      [%rejected ~]
      [%receipt sequencer-receipt]
  ==
--
