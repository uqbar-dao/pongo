/-  *pongo, se=settings
/+  sig, nectar
|%
++  give-push-notification
  |=  [=conversation =message =notif-setting our=ship now=@da]
  ^-  (unit card:agent:gall)
  ?:  ?=(%off notif-setting)  ~
  ::  read from settings-store
  ::
  =/  pre=path  /(scot %p our)/settings-store/(scot %da now)
  ::  TODO remove these first two if viable
  ?.  .^(? %gx (weld pre /has-bucket/landscape/ping-app/noun))  ~
  ?.  .^(? %gx (weld pre /has-entry/landscape/ping-app/expo-token/noun))  ~
  ::
  =/  =data:se
    .^(data:se %gx (weld pre /entry/landscape/ping-app/expo-token/noun))
  =/  ship-url=data:se
    .^(data:se %gx (weld pre /entry/landscape/ping-app/ship-url/noun))
  ?.  ?&  ?=(%entry -.data)
          ?=(%s -.val.data)
          ?=(%entry -.ship-url)
          ?=(%s -.val.ship-url)
      ==
    ~
  ::  send http request
  ::
  =|  =request:http
  =:  method.request       %'POST'
      url.request          'https://exp.host/--/api/v2/push/send'
      header-list.request  ~[['Content-Type' 'application/json']]
      body.request
    :-  ~
    %-  as-octt:mimes:html
    %-  en-json:html
    %-  pairs:enjs:format
    :~  to+s+p.val.data
        :-  %title
        ?-    notif-setting
            %high  s+''
            ?(%low %medium)
          s+(crip "Message in {<name.conversation>}")
        ==
        :-  %body
        ?-    notif-setting
            ?(%medium %high)  s+''
            %low
          s+(crip "{<author.message>}: {<content.message>}")
        ==
        :-  %data
        %-  pairs:enjs:format
        :~  ['ship' s+(scot %p our)]
            ['ship_url' s+p.val.ship-url]
            ['conversation_id' s+(scot %ux id.conversation)]
            ['message_id' s+(scot %ud id.message)]
        ==
    ==
  ==
  :-  ~
  :*  %pass  /push-notification/(scot %da now)
      %arvo  %i  %request
      request  *outbound-config:iris
  ==
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
    -:(q:db %pongo [%select %conversations where=[%s %id %& %eq (need only-in)]])
  %+  turn
    =-  -:(q:db %pongo [%select table-id where=-])
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
        |=  [r=reaction s=(set @p)]
        [`@t`r a+(turn ~(tap in s) ship)]
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
        ?-  -.p.meta.c
          %open     ~
          %managed  a+(turn ~(tap in leaders.p.meta.c) ship)
        ==
        ['muted' b+muted.c]
    ==
  ::
  ++  update-to-json
    |=  upd=pongo-update
    ^-  json
    ?-    -.upd
        %conversations
      %+  frond  'conversations'
      %-  pairs
      %+  turn  +.upd
      |=  ci=conversation-info
      :-  (scot %ux id.ci)
      %-  pairs
      :~  ['conversation' (conversation-to-json -.ci)]
          ['unreads' (numb unreads.ci)]
          :-  'last_message'
          ?~(last.ci ~ (message-to-json:parsing u.last.ci ~))
      ==
    ::
        %message-list
      %+  frond  'message_list'
      :-  %a
      %+  turn  +.upd
      |=  =message
      (message-to-json:parsing message ~)
    ::
        %message
      %+  frond  'message'
      %-  pairs
      :~  ['conversation_id' s+(scot %ux conversation-id.upd)]
          ['message' (message-to-json:parsing message.upd ~)]
      ==
    ::
        %invite
      %+  frond  'invite'
      (conversation-to-json:parsing +.upd)
    ::
        %sending
      %+  frond  'sending'
      %-  pairs
      :~  ['conversation_id' s+(scot %ux conversation-id.upd)]
          ['identifier' s+identifier.upd]
      ==
    ::
        %delivered
      %+  frond  'delivered'
      %-  pairs
      :~  ['conversation_id' s+(scot %ux conversation-id.upd)]
          ['identifier' s+identifier.upd]
      ==
    ::
        %search-result
      %+  frond  'search_result'
      :-  %a
      %+  turn  +.upd
      |=  [c=conversation-id =message]
      (message-to-json:parsing message `c)
    ::
        %invites
      %+  frond  'invites'
      %-  pairs
      :~  :-  'sent'
          ^-  json
          %-  pairs
          %+  turn  ~(tap by sent.upd)
          |=  [k=conversation-id s=(set @p)]
          [(scot %ux k) a+(turn ~(tap in s) ship)]
      ::
          :-  'received'
          ^-  json
          %-  pairs
          %+  turn  ~(tap by rec.upd)
          |=  [k=conversation-id v=[from=@p c=conversation]]
          :-  (scot %ux k)
          %-  pairs
          :~  ['from' (ship from.v)]
              ['conversation' (conversation-to-json c.v)]
          ==
      ==
    ::
        %blocklist
      %+  frond  'blocklist'
      a+(turn ~(tap in +.upd) ship)
    ::
        %notification
      %+  frond  'notification'
      %-  pairs
      :~  ['convo_name' s+convo-name.upd]
          ['author' (ship author.upd)]
          ['content' s+content.upd]
      ==
    ==
  --
--