/-  *pongo
/+  sig, nectar
|%
::
::  search thread stuff
::
::  type used for search threads
+$  search
  $:  db=_database:nectar
      only-in=(unit conversation-id)
      only-author=(unit @p)
      phrase=@t
  ==
::
++  do-search
  |=  search
  ^-  (list [conversation-id message])
  =/  table-id
    ~|  "%pongo: couldn't find conversation"
    =<  messages-table-id
    %-  need
    =-  ?~(- ~ `!<(conversation [-:!>(*conversation) (head -)]))
    -:(q:db [%select %conversations where=[%s %id %& %eq (need only-in)]])
  %+  turn
    =-  -:(q:db [%select table-id where=-])
    =+  [%s %content %& %text-find (trip phrase)]
    ?~  only-author  -
    [%and [%s %author %& %eq u.only-author] -]
  |=  =row:nectar
  [(need only-in) !<(message [-:!>(*message) row])]
::
::  utils
::
++  make-message-hash
  |=  [content=@t src=@p now=@da]
  ^-  @
  %-  sham
  %+  rap  3
  :~  'signed pongo message by '
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
  %+  rap  3
  :~  'signed-pongo-react: '
      reaction
      'on message '
      (scot %ud on)
  ==
::
++  print-message
  |=  =message
  ^-  @t
  ?+    kind.message
      %+  rap  3
      :~  'Message ('
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
::  json creation
::
++  parsing
  =,  enjs:format
  |%
  ++  message-to-json
    |=  [m=message c=(unit conversation-id)]
    ^-  json
    %-  pairs
    :*  ['id' s+(scot %ud id.m)]
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
        ?~  c  ~
        ['conversation_id' s+(scot %ux u.c)]^~
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
  ::
  ++  update-to-json
    |=  upd=pongo-update
    ^-  json
    ?-    -.upd
        %conversations
      %+  frond
        'conversations'
      %-  pairs
      %+  turn  +.upd
      |=  ci=conversation-info
      :-  (scot %ux id.ci)
      %-  pairs
      :~  ['conversation' (conversation-to-json -.ci)]
          ['unreads' (numb unreads.ci)]
          :-  'last_message'
          ?~(last-message.ci ~ (message-to-json:parsing u.last-message.ci ~))
      ==
    ::
        %message-list
      %+  frond
        'message_list'
      :-  %a
      %+  turn  +.upd
      |=  =message
      (message-to-json:parsing message ~)
    ::
        %message
      %+  frond
        'message'
      %-  pairs
      :~  ['conversation_id' s+(scot %ux conversation-id.upd)]
          ['message' (message-to-json:parsing message.upd ~)]
      ==
    ::
        %invite
      %+  frond
        'invite'
      (conversation-to-json:parsing +.upd)
    ::
        %sending
      %+  frond
        'sending'
      (sect +.upd)
    ::
        %delivered
      %+  frond
        'delivered'
      (sect +.upd)
    ::
        %search-result
      %+  frond
        'search_result'
      :-  %a
      %+  turn  +.upd
      |=  [c=conversation-id =message]
      (message-to-json:parsing message `c)
    ==
  --
--