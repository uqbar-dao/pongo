/-  p=pongo
::
|_  =action:p
++  grab
  |%
  ++  noun  action:p
  ++  json
    =,  dejs:format
    |=  jon=^json
    %-  action:p
    |^
    %-  of
    :~  ::  [%make-conversation (ot ~[[%mnemonic so] [%password so] [%nick so]])]
        ::  [%leave-conversation (ot ~[[%password so] [%nick so]])]
        ::  ::
        ::  [%send-message (ot ~[[%hdpath sa] [%nick so]])]
        [%send-reaction (ot ~[[%convo (se %ux)] [%on (se %ux)] [%react (se %ta)]])]
        [%read-message (ot ~[[%convo (se %ux)] [%message (se %ux)]])]
        ::
        [%make-invite (ot ~[[%to (se %p)] [%id (se %ux)]])]
        [%accept-invite (ot ~[[%id (se %ux)]])]
        [%reject-invite (ot ~[[%id (se %ux)]])]
        ::
        [%block (ot ~[[%who (se %p)]])]
        [%unblock (ot ~[[%who (se %p)]])]
    ==

    --
  --
::
++  grow
  |%
  ++  noun  action
  --
::
++  grad  %noun
--
