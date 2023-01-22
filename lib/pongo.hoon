/-  *pongo
/+  sig
|%
++  make-message-hash
  |=  [content=@t src=@p now=@da]
  ^-  @
  %-  sham
  ;:  (cury cat 3)
    'signed pongo message by '
    (scot %p src)
    ' at '
    (scot %da now)
    ': '
    content
  ==
::
++  make-reaction-hash
  |=  [=reaction on=message-id]
  ^-  @
  %-  sham
  ;:  (cury cat 3)
    'signed-pongo-react: '
    reaction
    'on message '
    (scot %ud on)
  ==
::
++  print-message
  |=  =message
  ^-  @t
  ?+    kind.message
      ;:  (cury cat 3)
        'Message ('
        (scot %ud id.message)
        ') from '
        (scot %p author.message)
        ': '
        content.message
      ==
  ::
      %member-add
    %^  cat  3
      content.message
    ' joined the conversation.'
  ::
      %member-remove
    %^  cat  3
      content.message
    ' left the conversation.'
  ::
      %change-name
    %^  cat  3
      'Conversation name changed to '
    (cat 3 content.message '.')
  ::
      %leader-add
    %^  cat  3
      content.message
    ' is now managing the conversation.'
  ::
      %leader-remove
    %^  cat  3
      content.message
    ' is no longer managing the conversation.'
  ==
::
++  print-reaction
  |=  [src=ship =ping]
  ^-  @t
  ?>  ?=(%react -.ping)
  %-  crip
  "{<src>} reacted {<reaction.ping>} to message {<on.ping>}"
::
++  print-edit
  |=  [src=ship =ping]
  ^-  @t
  ?>  ?=(%edit -.ping)
  %-  crip
  "{<src>} edited message {<on.ping>} to {<edit.ping>}"
::
++  parsing
  =,  enjs:format
  |%
  ++  message-to-json
    |=  m=message
    ^-  json
    %-  pairs
    :~  ['id' s+(scot %ud id.m)]
        ['author' s+(scot %p author.m)]
        ::  don't share signatures
        ['timestamp' (sect timestamp.m)]
        ['kind' s+(scot %tas kind.m)]
        ['content' s+content.m]
        ['edited' b+edited.m]
        ['reference' ?~(reference.m ~ s+(scot %ud u.reference.m))]
        :-  'reactions'
        %-  pairs
        %+  turn  ~(tap by p.reactions.m)
        |=  [p=@p r=reaction]
        [(scot %p p) s+(scot %tas r)]
    ==
  ::
  ++  conversation-to-json
    |=  c=conversation
    ^-  json
    %-  pairs
    :~  ['id' s+(scot %ux id.c)]
        ::  don't share messages table id
        ['name' s+name.c]
        ['last_active' (sect last-active.c)]
        ['last_read' s+(scot %ud last-read.c)]
        ::  don't share router node
        ['members' a+(turn ~(tap in members.p.meta.c) ship)]
        :-  'leaders'
        ?-    -.p.meta.c
            %free-for-all   ~
            %single-leader  (ship leader.p.meta.c)
            %many-leader
          :-  %a
          (turn ~(tap in leaders.p.meta.c) ship)
        ==
    ==
  --
--