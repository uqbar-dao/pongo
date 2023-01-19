/-  *pongo
/+  verb, dbug, default-agent, io=agentio,
    *pongo, nectar, sig
|%
::
::  %pongo agent state
::
+$  state
  $:  db=_database:nectar
      blocked=(set @p)
      invites=(map conversation-id [from=@p =conversation])
      invites-sent=(jug conversation-id @p)
  ==
+$  card  card:agent:gall
--
::
^-  agent:gall
%+  verb  |
%-  agent:dbug
=|  =state
=<  |_  =bowl:gall
    +*  this  .
        hc    ~(. +> bowl)
        def   ~(. (default-agent this %|) bowl)
    ::
    ++  on-init
      =-  `this(state -)
      ::  produce a conversations table with saved schema and indices
      :_  [~ ~ ~]
      %+  add-table:~(. database:nectar ~)
        %conversations
      ^-  table:nectar
      :^    (make-schema:nectar conversations-schema)
          primary-key=~[%id]
        (make-indices:nectar conversations-indices)
      ~
    ::
    ++  on-save  !>(state)
    ::
    ++  on-load
      |=  old=vase
      ^-  (quip card _this)
      `this(state !<(_state old))
    ::
    ++  on-poke
      |=  [=mark =vase]
      ^-  (quip card _this)
      =^  cards  state
        ?+    mark  (on-poke:def mark vase)
            %ping    (handle-ping:hc !<(ping vase))
            %action  (handle-action:hc !<(action vase))
        ==
      [cards this]
    ::
    ++  on-peek   handle-scry:hc
    ::
    ++  on-agent  on-agent:def
    ++  on-watch  on-watch:def
    ++  on-arvo   on-arvo:def
    ++  on-leave  on-leave:def
    ++  on-fail   on-fail:def
    --
::
|_  bowl=bowl:gall
  ++  handle-ping
    |=  =ping
    ^-  (quip card _state)
    ?:  (~(has in blocked.state) src.bowl)
      ::  if we block the router we start ignoring the whole
      ::  conversation. should probably fix that somehow.
      `state
    =/  cid=conversation-id
      ::  IRRITATING type refinement here
      ?-  -.ping
        %invite   id.conversation.ping
        %message  conversation-id.ping
        %react    conversation-id.ping
        ?(%accept-invite %reject-invite)  conversation-id.ping
      ==
    =/  convo=conversation
      ?:  ?=(%invite -.ping)
        conversation.ping
      ::  TODO clean this up
      !<  conversation
      :-  -:!>(*conversation)
      %-  head
      %-  q:db.state
      [%select %conversations where=[%s %id %& %eq cid]]
    ?-    -.ping
        %message
      ::  we've received a new message
      ::  if we are router, we now poke every member with this message
      ?:  &(!routed.ping =(our.bowl router.convo))
        ::  assign ordering to message here
        =.  id.message.ping
          =/  res
            %-  q:db.state
            [%select messages-table-id.convo where=[%s %id %& %bottom 1]]
          ?~  res  0
          +(id:!<(message [-:!>(*message) (head res)]))
        :_  state
        %+  turn  ~(tap in members.p.meta.convo)
        |=  to=@p
        %+  ~(poke pass:io /route-message)
          [to %pongo]
        ping+!>(`^ping`[%message cid routed=& message.ping])
      ::  if we are not router, we only receive messages from router
      ::  only accept the message if it's from a member of that conversation
      ::  add it to our messages table for that conversation
      ?>  =(src.bowl router.convo)
      ?.  =+  (make-message-hash [content timestamp]:message.ping)
          (validate:sig our.bowl p.signature.message.ping - now.bowl)
        ~&  >>>  "%pongo: rejecting message, invalid signature"  `state
      ?.  (~(has in members.p.meta.convo) author.message.ping)
        ~&  >>>  "%pongo: rejecting message"  `state
      ?.  (~(has by tables:db.state) messages-table-id.convo)
        ~&  >>>  "%pongo: rejecting message"  `state
      =:  timestamp.message.ping  now.bowl
          seen.message.ping       %.n
      ==
      ~?  &(?=(%text kind.message.ping) !=(author.message.ping our.bowl))
        (print-message message.ping)
      ::  if the message kind is a member or leader set edit,
      ::  we update our conversation to reflect it -- only
      ::  if message was sent by someone allowed to do it
      =.  db.state
        =-  %+  update:db.state
          %conversations
        ~[!<(row:nectar [-:!>(*row:nectar) -])]
        ^-  conversation
        =.  last-active.convo  now.bowl
        ?.  ?&  ?=  ?(%member-add %member-remove %leader-add %leader-remove)
                kind.message.ping
                ?-  -.p.meta.convo
                  %free-for-all  %.y
                    %single-leader
                  =(author.message.ping leader.p.meta.convo)
                    %many-leader
                  (~(has in leaders.p.meta.convo) author.message.ping)
            ==  ==
          convo
        =.  members.p.meta.convo
          ?+  kind.message.ping  members.p.meta.convo
              %member-add
            (~(put in members.p.meta.convo) (slav %p content.message.ping))
              %member-remove
            (~(del in members.p.meta.convo) (slav %p content.message.ping))
          ==
        ?+    -.p.meta.convo  convo
            %many-leader
          %=    convo
              leaders.p.meta
            ?+    kind.message.ping  leaders.p.meta.convo
                %leader-add
              (~(put in leaders.p.meta.convo) (slav %p content.message.ping))
                %leader-remove
              (~(del in leaders.p.meta.convo) (slav %p content.message.ping))
            ==
          ==
        ==
      =.  db.state
        %+  insert:db.state
          messages-table-id.convo
        ::  TODO fix this, no good
        ~[!<(row:nectar [-:!>(*row:nectar) message.ping])]
      `state
    ::
        %react
      ::  we've received a new message-reaction
      !!
    ::
        %invite
      ::  we've received an invite to a conversation
      =-  `state(invites -)
      %+  ~(put by invites.state)
        id.conversation.ping
      [src.bowl conversation.ping]
    ::
        %accept-invite
      ::  an invite we sent has been accepted
      ::  create a message in conversation with kind %member-add
      ?>  (~(has ju invites-sent.state) cid src.bowl)
      :_  state(invites-sent (~(del ju invites-sent.state) cid src.bowl))
      =/  hash  (make-message-hash (scot %p src.bowl) now.bowl)
      =/  member-add-message=message
        :*  *message-id
            our.bowl
            signature=[%blob (sign:sig our.bowl now.bowl hash)]
            now.bowl
            %.n
            %member-add
            (scot %p src.bowl)
            ~  ~  ~
        ==
      :_  ~
      %+  ~(poke pass:io /accept-invite)
        [router.convo %pongo]
      ping+!>(`^ping`[%message cid routed=| member-add-message])
    ::
        %reject-invite
      ::  an invite we sent has been rejected
      `state(invites-sent (~(del ju invites-sent.state) cid src.bowl))
    ==
  ::
  ++  handle-action
    |=  =action
    ^-  (quip card _state)
    ::
    ::  we receive actions from our own client app
    ::
    ?>  =(our src):bowl
    ?-    -.action
        %make-conversation
      ::  create a new conversation and possibly send invites
      ::  enforce that we're in conversation
      =/  convo=conversation
        :*  ::  generate unique ID, TODO check back on this
            id=`@ux`(sham (cat 3 our.bowl eny.bowl))
            messages-table-id=`@ux`(sham (sham (cat 3 our.bowl eny.bowl)))
            last-active=now.bowl
            router=our.bowl
            :-  %blob
            config.action(members (~(put in members.config.action) our.bowl))
            ~
        ==
      ::  add this conversation to our table
      ::  and create a messages table for it
      =.  db.state
        %+  insert:db.state
          %conversations
        ::  TODO fix this, no good
        ~[!<(row:nectar [-:!>(*row:nectar) convo])]
      =.  db.state
        %+  add-table:db.state
          messages-table-id.convo
        :^    (make-schema:nectar messages-schema)
            primary-key=~[%id]
          (make-indices:nectar messages-indices)
        ~
      ::  poke all indicated members in metadata with invites
      =/  mems  ~(tap in (~(del in members.config.action) our.bowl))
      :-  %+  turn  mems
          |=  to=@p
          %+  ~(poke pass:io /send-invite)
            [to %pongo]
          ping+!>(`ping`[%invite convo])
      %=    state
          invites-sent
        |-
        ?~  mems  invites-sent.state
        %=  $
          mems  t.mems
          invites-sent.state  (~(put ju invites-sent.state) id.convo i.mems)
        ==
      ==
    ::
        %leave-conversation
      ::  leave a conversation we're currently in
      !!
    ::
        %send-message
      ::  create a message and send to a conversation we're in
      =/  hash  (make-message-hash content.action now.bowl)
      =/  =message
        :*  id=0  ::  router will make this
            author=our.bowl
            signature=[%blob (sign:sig our.bowl now.bowl hash)]
            timestamp=now.bowl  ::  needed for verification
            seen=&
            message-kind.action
            content.action
            reference.action
            ~  ~
        ==
      =/  convo=conversation
        ::  TODO clean this up
        !<  conversation
        :-  -:!>(*conversation)
        %-  head
        %-  q:db.state
        [%select %conversations where=[%s %id %& %eq conversation-id.action]]
      :_  state
      :_  ~
      %+  ~(poke pass:io /send-message)
        [router.convo %pongo]
      ping+!>(`ping`[%message conversation-id.action routed=| message])
    ::
        %send-reaction
      ::  create a reaction and send to a conversation we're in
      !!
    ::
        %make-invite
      ::  create an invite and send to someone
      =/  convo=conversation
        ::  TODO clean this up
        !<  conversation
        :-  -:!>(*conversation)
        %-  head
        %-  q:db.state
        [%select %conversations where=[%s %id %& %eq conversation-id.action]]
      :_  state(invites-sent (~(put ju invites-sent.state) id.convo to.action))
      :_  ~
      %+  ~(poke pass:io /send-invite)
        [to.action %pongo]
      ping+!>(`ping`[%invite convo])
    ::
        %accept-invite
      ::  accept an invite we've been sent, join the conversation
      ::  add this convo to our conversations table and create
      ::  a messages table for it
      =/  [from=@p convo=conversation]
        (~(got by invites.state) conversation-id.action)
      ::  TODO: if we're *already in* this conversation,
      ::  skip all this
      =.  members.p.meta.convo
        (~(put in members.p.meta.convo) our.bowl)
      =.  db.state
        %+  insert:db.state
          %conversations
        ::  TODO fix this, no good
        ~[!<(row:nectar [-:!>(*row:nectar) convo])]
      =.  db.state
        %+  add-table:db.state
          messages-table-id.convo
        :^    (make-schema:nectar messages-schema)
            primary-key=~[%id]
          (make-indices:nectar messages-indices)
        ~
      :_  state(invites (~(del by invites.state) id.convo))
      :_  ~
      %+  ~(poke pass:io /accept-invite)
        [from %pongo]
      ping+!>(`ping`[%accept-invite id.convo])
    ::
        %reject-invite
      ::  reject an invite we've been sent
      ?~  invite=(~(get by invites.state) conversation-id.action)
        `state
      :_  state(invites (~(del by invites.state) conversation-id.action))
      :_  ~
      %+  ~(poke pass:io /accept-invite)
        [from.u.invite %pongo]
      ping+!>(`ping`[%reject-invite conversation-id.action])
    ::
        %block
      ::  add a ship to our block-list, they cannot message us or invite us
      !!
    ::
        %unblock
      ::  remove a ship from our block-list
      !!
    ==
  ::
  ++  handle-scry
    |=  =path
    ^-  (unit (unit cage))
    ?+    path
      ~|("unexpected scry into {<dap.bowl>} on path {<path>}" !!)
    ::
        [%x %all-conversations ~]
      ~&  >
      %+  turn
        %-  q:db.state
        [%select %conversations where=[%n ~]]
      |=  =row:nectar
      !<(conversation [-:!>(*conversation) row])
      ``noun+!>(~)
    ::
        [%x %all-messages @ ~]
      =/  convo-id  (slav %ux i.t.t.path)
      =/  convo=conversation
        ::  TODO clean this up
        !<  conversation
        :-  -:!>(*conversation)
        %-  head
        %-  q:db.state
        [%select %conversations where=[%s %id %& %eq convo-id]]
      =/  messages
        %+  turn
          %-  q:db.state
          [%select messages-table-id.convo where=[%n ~]]
        |=  =row:nectar
        !<(message [-:!>(*message) row])
      ~&  >  messages
      ``noun+!>(~)
    ==
--