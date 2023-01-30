/-  p=posse
::
|_  =action:p
++  grab
  |%
  ++  noun  action:p
  ++  json
    |=  jon=^json
    =,  dejs:format
    %-  action:p
    %.  jon
    %-  of
    :~  [%add-tag (ot ~[[%who (se %p)] [%tag so]])]
        [%del-tag (ot ~[[%who (se %p)] [%tag so]])]
        [%edit-details (ot ~[[%who (se %p)] [%details (om so)]])]
        [%join-posse (ot ~[[%controller (se %p)] [%tag so]])]
    ==
  --
::
++  grow
  |%
  ++  noun  action
  --
::
++  grad  %noun
--
