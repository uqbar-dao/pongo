/-  *pinguin
/+  verb, dbug, default-agent, io=agentio,
    miasma
|%
::
::  %pinguin agent state
::
+$  state
  $:  db=_database:miasma
      blocked=(set @p)
      invites=(map conversation-id [from=@p =conversation])
      invites-sent=(jar conversation-id @p)
  ==
+$  card  card:agent:gall
--
::
^-  agent:gall
%+  verb  &
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
      %+  add-table:~(. database:miasma ~)
        %conversations
      ^-  table:miasma
      :^    (make-schema:miasma conversations-schema)
          primary-key=~[%id]
        (make-indices:miasma conversations-indices)
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
    ?-    -.ping
        %message
      ::  we've received a new message
      ::  only accept the message if it's from a member of that conversation
      ::  TODO: verify message signature here
      ::  add it to our messages table for that conversation
      ::  first, query conversations table
      =/  convo=conversation
        !<  conversation
        :-  -:!>(*conversation)
        %-  head
        %-  q:db.state
        [%select %conversations where=[%s %id %& %eq conversation-id.ping]]
      ?>  =(src.bowl router.convo)
      ?.  (~(has in members.+.meta.convo) author.message.ping)
        ~&  "%pinguin: rejecting message"  `state
      ?.  (~(has by tables:db.state) id.convo)
        ~&  "%pinguin: rejecting message"  `state
      ~&  "%pinguin: {<author.message.ping>}: {<content.message.ping>}"
      =:
        timestamp.message.ping  now.bowl
        seen.message.ping       %.n
      ==
      =.  db.state
        %+  insert:db.state
          messages-table-id.convo
        ::  TODO fix this, no good
        ~[!<(row:miasma [-:!>(*row:miasma) message.ping])]
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
      !!
    ::
        %reject-invite
      ::  an invite we sent has been rejected
      !!
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
      !!
    ::
        %leave-conversation
      ::  leave a conversation we're currently in
      !!
    ::
        %send-message
      ::  create a message and send to a conversation we're in
      !!
    ::
        %send-reaction
      ::  create a reaction and send to a conversation we're in
      !!
    ::
        %make-invite
      ::  create an invite and send to someone
      !!
    ::
        %accept-invite
      ::  accept an invite we've been sent, join the conversation
      ::  add this convo to our conversations table and create
      ::  a messages table for it
      =/  [from=@p convo=conversation]
        (~(got by invites.state) conversation-id.action)
      =.  db.state
        %+  insert:db.state
          %conversations
        ::  TODO fix this, no good
        ~[!<(row:miasma [-:!>(*row:miasma) convo])]
      =.  db.state
        %+  add-table:db.state
          messages-table-id.convo
        :^    (make-schema:miasma messages-schema)
            primary-key=~[%id]
          (make-indices:miasma messages-indices)
        ~
      :_  state(invites (~(del by invites.state) id.convo))
      :_  ~
      %+  ~(poke pass:io /accept-invite)
        [from %pinguin]
      ping+!>(`ping`[%accept-invite id.convo])
    ::
        %reject-invite
      ::  reject an invite we've been sent
      !!
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
    !!
--