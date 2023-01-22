/-  p=pongo
::
|_  =action:p
++  grab
  |%
  ++  noun  action:p
  ++  json
    |=  jon=^json
    =,  dejs:format
    |^
    %-  action:p
    %.  jon
    %-  of
    :~  [%make-conversation (ot ~[[%name so] [%config parse-config]])]
        [%leave-conversation (ot ~[[%convo (se %ux)]])]
        ::
        :-  %send-message
        %-  ot
        :~  [%convo (se %ux)]
            [%kind (se %tas)]
            [%content so]
            ::  doesn't want dots
            [%reference (su dem):dejs-soft:format]
        ==
        ::
        :-  %send-reaction
        (ot ~[[%convo (se %ux)] [%on (se %ux)] [%reaction (se %ta)]])
        ::
        [%read-message (ot ~[[%convo (se %ux)] [%message (se %ux)]])]
        [%make-invite (ot ~[[%to (se %p)] [%id (se %ux)]])]
        [%accept-invite (ot ~[[%id (se %ux)]])]
        [%reject-invite (ot ~[[%id (se %ux)]])]
        [%block (ot ~[[%who (se %p)]])]
        [%unblock (ot ~[[%who (se %p)]])]
    ==
    ++  parse-config
      |=  j=json
      %-  conversation-metadata:p
      %-  of
      :~  [%single-leader (ot ~[[%members (as (se %p))] [%leader (se %p)]])]
          [%many-leader (ot ~[[%members (as (se %p))] [%leaders (as (se %p))]])]
          [%free-for-all (ot ~[[%members (as (se %p))]]) ~]
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
