/-  *pongo
/+  *pongo
=,  enjs:format
::
|_  upd=pongo-update
++  grab
  |%
  ++  noun  pongo-update
  --
::
++  grow
  |%
  ++  noun  upd
  ++  json
    ?-    -.upd
        %conversations
      %-  pairs
      %+  turn  +.upd
      |=  ci=conversation-info
      :-  (scot %ux id.ci)
      %-  pairs
      :~  [%name s+name.ci]
          [%unreads (numb unreads.ci)]
          [%'last_read' (numb last-read.ci)]
          :-  %'last_message'
          ?~(last-message.ci ~ (message-to-json:parsing u.last-message.ci))
      ==
    ::
        %message-list
      :-  %a
      %+  turn  +.upd
      |=  =message
      (message-to-json:parsing message)
    ==
  --
::
++  grad  %noun
--
