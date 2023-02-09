/-  *pongo, s=social-graph
/+  verb, dbug, default-agent, io=agentio,
    *pongo, nec=nectar, sig
|%
::
::  pongo is currently tuned to auto-accept invites to new conversations.
::  it's also set up to automatically allow ships to join an *open*
::  conversation if they have the ID.
::  these can be turned off with a few small changes.
::
::  if the conversation has this many members or less,
::  we'll track delivery to each recipient.
++  delivery-tracking-cutoff  5
::  arbitrary limits for some measure of performance guarantees
++  message-length-limit      1.024
::  ++  member-count-limit        100  ::  maybe in future.
::
::  %pongo agent state
::
+$  state-0
  $:  %0  ::  "deep state" (TODO get rid of)
      =database:nec
      tagged=(map tag:s conversation-id)  ::  conversations linked to %posse
      ::  "configuration state"
      blocked=(set @p)
      =notif-settings
      invites=(map conversation-id [from=@p =conversation])
      invites-sent=(jug conversation-id @p)
      ::  "ephemeral state"
      total-unread=@ud
      undelivered=(map @uvH [message fe-id=@t want=(set @p)])
      pending-pings=(jar [conversation-id message-id] pending-ping)
  ==
+$  card  card:agent:gall
--
::
^-  agent:gall
%+  verb  |
%-  agent:dbug
=|  state=state-0
=<  |_  =bowl:gall
    +*  this  .
        hc    ~(. +> bowl)
        def   ~(. (default-agent this %|) bowl)
    ::
    ++  on-init
      =-  `this(state -)
      ::  produce a conversations table with saved schema and indices
      =/  initial-db=database:nec
        %+  ~(add-table db:nec *database:nec)
          %pongo^%conversations
        ^-  table:nec
        :^    (make-schema:nec conversations-schema)
            primary-key=~[%id]
          (make-indices:nec conversations-indices)
        ~
      [%0 initial-db ~ ~ ['' '' %low] ~ ~ 0 ~ ~]
    ::
    ++  on-save  !>(state)
    ::
    ++  on-load
      |=  old=vase
      ^-  (quip card _this)
      ::  nuke our state if it's of an unsupported version
      ::  note that table schemas can change without causing a state change
      ?+  -.q.old  on-init
        %0  `this(state !<(state-0 old))
      ==
    ::
    ++  on-poke
      |=  [=mark =vase]
      ^-  (quip card _this)
      =^  cards  state
        ?+  mark  (on-poke:def mark vase)
          %ping                 (handle-ping:hc !<(ping vase))
          %pongo-action         (handle-action:hc !<(action vase))
          %social-graph-update  (handle-graph-update:hc !<(update:s vase))
        ==
      [cards this]
    ::
    ++  on-peek   handle-scry:hc
    ::
    ++  on-watch
      |=  =path
      ^-  (quip card _this)
      ?>  =(src.bowl our.bowl)
      ?+    path
          ~|("watch to erroneous path" !!)
      ::  path for frontend to connect to and receive
      ::  all actively-flowing information. does not provide anything
      ::  upon watch, only as it happens.
        [%updates ~]  `this
      ::  path for frontend to receive search results.
      ::  subscribe before poking %search with matching uid
        [%search-results @ ~]  `this
      ==
    ::
    ++  on-agent
      |=  [=wire =sign:agent:gall]
      ^-  (quip card _this)
      ?+    -.wire  (on-agent:def wire sign)
          %thread
        ?+    -.sign  (on-agent:def wire sign)
            %fact
          ?+    p.cage.sign  (on-agent:def wire sign)
              %thread-fail
            =/  err  !<((pair term tang) q.cage.sign)
            %-  (slog leaf+"search thread failed: {(trip p.err)}" q.err)
            `this
              %update
            ::  forward updates along search results path
            =/  tid  -.+.+.wire
            =/  upd  !<(pongo-update q.cage.sign)
            :_  this
            (fact:io pongo-update+!>(upd) ~[/search-results/[tid]])^~
          ==
        ==
      ==
    ::
    ++  on-arvo
      |=  [=wire =sign-arvo]
      ^-  (quip card _this)
      ?.  ?=([%push-notification @ ~] wire)
        (on-arvo:def wire sign-arvo)
      `this
    ++  on-leave  on-leave:def
    ++  on-fail   on-fail:def
    --
::
|_  bowl=bowl:gall
++  handle-ping
  |=  =ping
  ^-  (quip card _state)
  ?:  ?=(%delivered -.ping)
    ?~  has=(~(get by undelivered.state) hash.ping)
      `state
    =.  want.u.has  (~(del in want.u.has) src.bowl)
    ?^  want.u.has
      `state(undelivered (~(put by undelivered.state) hash.ping u.has))
    :_  state(undelivered (~(del by undelivered.state) hash.ping))
    ?:  =('' fe-id.u.has)  ~
    (give-update [%delivered conversation-id.ping fe-id.u.has])^~
  ?:  ?=(%invite -.ping)
    ::  we've received an invite to a conversation
    ::  ignore invites from blocked ships
    ?:  (~(has in blocked.state) src.bowl)  `state
    =+  [src.bowl conversation.ping]
    :_  state(invites (~(put by invites.state) id.conversation.ping -))
    :~  ::  remove this to turn off auto-accept
        %+  ~(poke pass:io /accept-invite)  [our.bowl %pongo]
        pongo-action+!>(`action`[%accept-invite id.conversation.ping])
      ::
        (give-update [%invite conversation.ping])
    ==
  =/  =conversation-id
    ::  this is infuriating but necessary because type unions can't refine
    ?-  -.ping
      %message         conversation-id.ping
      ?(%edit %react)  conversation-id.ping
      ?(%accept-invite %reject-invite %invite-request)  conversation-id.ping
    ==
  ?~  conv=(fetch-conversation conversation-id)
    ::  we got pinged for a conversation we don't know about
    ::  be optimistic and request an invite!
    ?<  =(our src):bowl
    ?<  ?=(%invite-request -.ping)
    ~&  >>  "%pongo: trying to re-join missing convo..."
    :_  state  :_  ~
    %+  ~(poke pass:io /request-invite-for-missing-convo)
      [src.bowl %pongo]
    ping+!>(`^ping`[%invite-request conversation-id])
  =*  convo  u.conv
  ?-    -.ping
      %message
    ::  we've received a new message
    =*  message  message.ping
    ::  enforce character length limit
    ?>  (lte (met 3 content.message) message-length-limit)
    ?:  &(!routed.ping =(our.bowl router.convo))
      ::  if we are router, we now poke every member with this message
      [(route-message convo message) state]
    ::  if we are not router, we only receive messages from router
    ::  only accept the message if it's from a member of that conversation
    ::  add it to our messages table for that conversation
    ?>  =(src.bowl router.convo)
    =/  message-hash  (make-message-hash [content author timestamp]:message)
    ?.  (validate:sig our.bowl p.signature.message message-hash now.bowl)
      ~&  >>>  "%pongo: rejecting message, invalid signature"  `state
    ?.  (~(has in members.p.meta.convo) author.message)
      ~&  >>>  "%pongo: rejecting message from non-member"  `state
    ?:  (~(has in blocked.state) author.message)
      ::  ignore any messages from blocked ships unless
      ::  it's them leaving the conversation!
      ::  we *do* send delivered receipts to those we have blocked.
      ?.  =(%member-remove kind.message)
        [(delivered-card author.message id.convo message-hash)^~ state]
      =.  database.state
        %+  ~(update-rows db:nec database.state)  %pongo^%conversations
        ~[convo(members.p.meta (~(del in members.p.meta.convo) author.message))]
      [(graph-del-tag author.message name.convo)^~ state]
    ::
    ::  enforce that convo name changes, member adds/removes, and leader
    ::  adds/removes follow the rules of this conversation (open/managed)
    ::
    ?.  (valid-message-contents message convo)
      ~&  >>>  "%pongo: rejecting message {<message>}"
      `state  ::  TODO crash here?
    =.  timestamp.message   now.bowl
    =.  last-active.convo   now.bowl
    =.  last-message.convo  id.message
    =.  total-unread.state  +(total-unread.state)
    =^  cards  convo
      ?-    kind.message
          ?(%text %code)
        ::  normal message
        ?:  muted.convo  `convo
        =-  ?~  -  `convo  [u.-^~ convo]
        %:  give-push-notification
            total-unread.state
            convo  message
            notif-settings.state
            [our now]:bowl
        ==
      ::
          %member-add
        =.  members.p.meta.convo
          (~(put in members.p.meta.convo) (slav %p content.message))
        :_  convo
        (graph-add-tag (slav %p content.message) name.convo)^~
      ::
          %member-remove
        =+  them=(slav %p content.message)
        =.  members.p.meta.convo
          (~(del in members.p.meta.convo) them)
        ?:  =(our.bowl them)
          [(graph-nuke-tag name.convo)^~ convo(deleted %.y)]
        [(graph-del-tag them name.convo)^~ convo]
      ::
          %change-name
        `convo(name content.message)
      ::
          %leader-add
        ?>  ?=(%managed -.p.meta.convo)
        =.  leaders.p.meta.convo
          (~(put in leaders.p.meta.convo) (slav %p content.message))
        `convo
      ::
          %leader-remove
        ?>  ?=(%managed -.p.meta.convo)
        =.  leaders.p.meta.convo
          (~(del in leaders.p.meta.convo) (slav %p content.message))
        `convo
      ::
          %change-router  !!  ::  TBD
      ==
    ::  if we have pending edits/reactions to message, apply them now
    =.  message  (apply-pending-pings message id.convo)
    =.  database.state
      %+  ~(update-rows db:nec database.state)
        %pongo^%conversations
      ~[convo]
    =.  database.state
      %+  ~(insert-rows db:nec database.state)
        %pongo^id.convo
      ~[message]
    :_  state
    %+  weld  cards
    :~  (delivered-card author.message id.convo message-hash)
        (give-update [%message id.convo message])
    ==
  ::
      %edit
    ::  we've received an edit of a message
    ?.  (~(has in members.p.meta.convo) src.bowl)
      ~&  >>>  "%pongo: rejecting edit"  `state
    ?:  (gth on.ping last-message.convo)
      =+  [[id.convo on.ping] [%edit src.bowl edit.ping]]
      `state(pending-pings (~(add ja pending-pings.state) -))
    ::
    =^  edited  database.state
      =*  v  value:nec
      %+  ~(q db:nec database.state)  %pongo
      :^  %update  id.convo
        :+  %and  [%s %id %& %eq on.ping]
        :+  %and  [%s %author %& %eq src.bowl]
        ::  i just like doing it this way
        [%s %kind %& %lte my-special-number]
      :~  [%content |=(=v edit.ping)]
          [%edited |=(=v %.y)]
      ==
    ?~  edited  `state
    :_  state  :_  ~
    %-  give-update
    [%message id.convo !<(message [-:!>(*message) (head edited)])]
  ::
      %react
    ::  we've received a new message reaction
    ?.  (~(has in members.p.meta.convo) src.bowl)
      ~&  >>>  "%pongo: rejecting reaction"  `state
    ?:  (gth on.ping last-message.convo)
      =+  [[id.convo on.ping] [%react src.bowl reaction.ping]]
      `state(pending-pings (~(add ja pending-pings.state) -))
    =^  reacted  database.state
      %+  ~(q db:nec database.state)  %pongo
      :^  %update  id.convo
        [%s %id %& %eq on.ping]
      :_  ~  :-  %reactions
      |=  v=value:nec
      ^-  value:nec
      ?>  &(?=(^ v) ?=(%m -.v))
      m+(~(put by p.v) src.bowl reaction.ping)
    ?~  reacted  `state
    :_  state  :_  ~
    %-  give-update
    [%message id.convo !<(message [-:!>(*message) (head reacted)])]
  ::
      %accept-invite
    ::  an invite we sent has been accepted
    ::  create a message in conversation with kind %member-add
    ?>  (~(has ju invites-sent.state) id.convo src.bowl)
    :_  state(invites-sent (~(del ju invites-sent.state) id.convo src.bowl))
    =/  hash  (make-message-hash (scot %p src.bowl) [our now]:bowl)
    :_  ~
    %+  ~(poke pass:io /accept-invite)  [router.convo %pongo]
    =-  ping+!>(`^ping`[%message routed=| id.convo -])
    :*  *message-id
        our.bowl
        signature=[%b (sign:sig our.bowl now.bowl hash)]
        now.bowl
        %member-add
        (scot %p src.bowl)
        %.n  ~  [%m ~]  [%s ~]  ~
    ==
  ::
      %reject-invite
    ::  an invite we sent has been rejected
    ~&  >>  "%pongo: {<src.bowl>} rejected invite to conversation {<id.convo>}"
    `state(invites-sent (~(del ju invites-sent.state) id.convo src.bowl))
  ::
      %invite-request
    ::  someone wants to join one of our conversations
    ::  if we don't have ID, or convo is not FFA, reject
    ::  otherwise send them an invite! (can remove this)
    ::  ignore requests from blocked ships
    ?:  (~(has in blocked.state) src.bowl)  `state
    ?>  ?=(?(%open %dm) -.p.meta.convo)
    :_  state(invites-sent (~(put ju invites-sent.state) id.convo src.bowl))
    :_  ~
    %+  ~(poke pass:io /send-invite)  [src.bowl %pongo]
    ping+!>(`^ping`[%invite convo])
  ==
::
++  route-message
  |=  [convo=conversation m=message]
  ^-  (list card)
  ::  assign ordering to message here by getting id of most recent message
  =.  id.m  +(last-message.convo)
  %+  turn  ~(tap in members.p.meta.convo)
  |=  to=@p
  %+  ~(poke pass:io /route-message)  [to %pongo]
  ping+!>(`ping`[%message routed=& id.convo m])
::
++  apply-pending-pings
  |=  [=message cid=conversation-id]
  ^+  message
  =/  pending=(list pending-ping)
    %-  flop  ::  want to apply newest last
    (~(get ju pending-pings.state) [cid id.message])
  |-
  ?~  pending  message
  =.  message
    ?-    -.i.pending
        %edit
      ?.  =(src.i.pending author.message)  message
      message(edited %.y, content edit.i.pending)
        %react
      =+  [src.i.pending reaction.i.pending]
      message(p.reactions (~(put by p.reactions.message) -))
    ==
  $(pending t.pending)
::
++  valid-message-contents
  |=  [=message convo=conversation]
  ^-  ?
  ?.  (gth id.message last-message.convo)  %.n
  ?-    kind.message
    ?(%text %code)  %.y
  ::
      %member-remove
    ?:  =(author.message (slav %p content.message))  %.y
    ?-  -.p.meta.convo
      ?(%open %dm)  %.n
      %managed      (~(has in leaders.p.meta.convo) author.message)
    ==
  ::
      ?(%member-add %change-name)
    ?-  -.p.meta.convo
      ?(%open %dm)  %.y  ::  this is right, sadly
      %managed      (~(has in leaders.p.meta.convo) author.message)
    ==
  ::
      %leader-add
    ?-  -.p.meta.convo
      ?(%open %dm)  %.n
      %managed      (~(has in leaders.p.meta.convo) author.message)
    ==
  ::
      %leader-remove
    ?-  -.p.meta.convo
      ?(%open %dm)  %.n
        %managed
      ?&  (gte ~(wyt in leaders.p.meta.convo) 2)
          (~(has in leaders.p.meta.convo) author.message)
      ==
    ==
  ::
      %change-router
    !!  ::  TBD
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
    ::  create a new conversation and possibly send invites.
    ::  whereas conversation IDs are meant to be *globally* unique,
    ::  conversation names must only be *locally* unique, so if we
    ::  already have a conversation with this name, we append
    ::  a number to the end of the name.
    ::
    ::  if a conversation is a DM (1:1 convo) we assign unique ID based
    ::  on the two ship names. DMs cannot be duplicated this way.
    ::
    =.  members.config.action
      (~(put in members.config.action) our.bowl)
    =/  member-count  ~(wyt in members.config.action)
    ::  generate unique ID
    =/  id
      ?:  ?=(%dm -.config.action)
        ::  enforce that we don't already have a DM of this nature
        ::  and that DMs have exactly 2 members
        ?.  =(member-count 2)
          ~|("pongo: error: tried to make multiparty DM" !!)
        `@ux`(sham (rap 3 ~(tap in members.config.action)))
      ::  enforce group chats have at least 3 members
      ?.  (gth member-count 2)
        ~|("pongo: error: tried to make group with <3 members" !!)
      `@ux`(sham (cat 3 our.bowl eny.bowl))
    ::  TODO: fix this in a more permanent way?
    =^  old-last-message  database.state
      ?~  have=(fetch-conversation id)
        [0 database.state]
      ?.  deleted.u.have
        ~|("pongo: error: duplicate conversation ID" !!)
      ::  drop an old messages-table if replacing deleted convo
      ::  BUT save the last-message index!
      :-  last-message.u.have
      (~(drop-table db:nec database.state) %pongo^id)
    ::
    =/  convo=conversation
      :*  `@ux`id
          name=(make-unique-name name.action)
          last-active=now.bowl
          last-message=old-last-message
          last-read=0
          router=our.bowl
          [%b config.action(members members.config.action)]
          deleted=%.n
          muted=%.n
          ~
      ==
    ::  add this conversation to our table and create a messages table for it
    =.  database.state
      (~(update-rows db:nec database.state) %pongo^%conversations ~[convo])
    =.  database.state
      %+  ~(add-table db:nec database.state)
        %pongo^id.convo
      :^    (make-schema:nec messages-schema)
          primary-key=~[%id]
        (make-indices:nec messages-indices)
      ~
    ::  poke all indicated members in metadata with invites
    =/  mems  ~(tap in (~(del in members.config.action) our.bowl))
    ~&  >>  "%pongo: made conversation id: {<id.convo>} and invited {<mems>}"
    :-  %+  weld
          %+  turn  mems
          |=  to=@p
          %+  ~(poke pass:io /send-invite)  [to %pongo]
          ping+!>(`ping`[%invite convo(name name.action)])
        %+  turn  [our.bowl mems]
        |=  to=@p
        (graph-add-tag to name.convo)
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
      %make-conversation-from-posse
    ::  make-conversation, but track a %posse tag
    ::  if we are the controller of the tag, make ourselves leader
    ::  if we are not, make it a free-for-all
    =/  tag-owner=@p      (scry-tag-controller tag.action)
    =/  members=(set @p)  (get-ships-from-tag tag-owner tag.action)
    ::  we must ourselves have the tag
    ?>  (~(has in members) our.bowl)
    ?>  (gth ~(wyt in members) 1)
    =/  config
      ?:  =(our.bowl tag-owner)
        [%managed members [our.bowl ~ ~]]
      [%open members ~]
    =^  cards  state
      $(action [%make-conversation name.action config])
    ::  start tracking the tag and automatically
    ::  adding/removing members on changes.
    :_  state
    %+  snoc  cards
    %+  ~(poke pass:io /watch-tag)  [our.bowl %social-graph]
    social-graph-track+!>(`track:s`[%pongo %track %posse tag.action])
  ::
      %leave-conversation
    ::  leave a conversation we're currently in
    =.  database.state
      =<  +
      %+  ~(q db:nec database.state)  %pongo
      :^  %update  %conversations
        [%s %id %& %eq conversation-id.action]
      ~[[%deleted |=(v=value:nec %.y)]]
    =-  $(action [%send-message -])
    ['' conversation-id.action %member-remove (scot %p our.bowl) ~ ~]
  ::
      %send-message
    ::  create a message and send to a conversation we're in
    ?>  (lte (met 3 content.action) message-length-limit)
    =/  hash  (make-message-hash content.action [our now]:bowl)
    =/  =message
      :*  id=0  ::  router will make this
          author=our.bowl
          signature=[%b (sign:sig our.bowl now.bowl hash)]
          timestamp=now.bowl  ::  needed for verification
          message-kind.action
          content.action
          edited=%.n
          reference.action
          [%m ~]  [%s mentions.action]  ~
      ==
    ?~  convo=(fetch-conversation conversation-id.action)
      ~|("%pongo: couldn't find that conversation id" !!)
    ::  update last-read message in convo, since if we are sending a
    ::  message, we've definitely read all previous messages
    =.  total-unread.state
      =/  just-read  (sub [last-message last-read]:u.convo)
      ?:  (gth just-read total-unread.state)  0
      (sub total-unread.state just-read)
    =.  database.state
      %+  ~(update-rows db:nec database.state)
        %pongo^%conversations
      ~[u.convo(last-read last-message.u.convo)]
    :_  ?:  (lth delivery-tracking-cutoff ~(wyt in members.p.meta.u.convo))
          state
        =-  state(undelivered (~(put by undelivered.state) hash -))
        [message identifier.action (~(del in members.p.meta.u.convo) our.bowl)]
    :+  (give-update [%sending id.u.convo identifier.action])
      %+  ~(poke pass:io /send-message)  [router.u.convo %pongo]
      ping+!>(`ping`[%message routed=| conversation-id.action message])
    ?.  ?&  ?=(%member-remove kind.message)
            =(our.bowl (slav %p content.message))
        ==
      ~
    ::  if we are leaving the conversation, destroy the tag in our social graph
    (graph-nuke-tag name.u.convo)^~
  ::
      %send-message-edit
    ::  edit a message we sent (must be of kind %text/%code)
    ::  as opposed to *new* messages, which must be sequenced by router,
    ::  we can poke edits out directly to all members
    ?~  convo=(fetch-conversation conversation-id.action)
      ~|("%pongo: couldn't find that conversation id" !!)
    :_  state
    %+  turn  ~(tap in members.p.meta.u.convo)
    |=  to=@p
    %+  ~(poke pass:io /send-edit)  [to %pongo]
    ping+!>(`ping`[%edit [conversation-id on edit]:action])
  ::
      %send-reaction
    ::  create a reaction and send to a conversation we're in
    ::  as opposed to messages, which must be sequenced by router,
    ::  we can poke reactions out directly to all members
    ?~  convo=(fetch-conversation conversation-id.action)
      ~|("%pongo: couldn't find that conversation id" !!)
    :_  state
    %+  turn  ~(tap in members.p.meta.u.convo)
    |=  to=@p
    %+  ~(poke pass:io /send-react)  [to %pongo]
    ping+!>(`ping`[%react [conversation-id on reaction]:action])
  ::
      %read-message
    ::  if read id is newer than current saved read id, replace in convo
    ::  send out a new badge notif for app to update unread count
    ?~  convo=(fetch-conversation conversation-id.action)
      ~|("%pongo: couldn't find that conversation id" !!)
    ?.  (gth message-id.action last-read.u.convo)  `state
    =.  total-unread.state
      =/  just-read  (sub message-id.action last-read.u.convo)
      ?:  (gth just-read total-unread.state)  0
      (sub total-unread.state just-read)
    =-  `state(database -)
    %+  ~(update-rows db:nec database.state)
      %pongo^%conversations
    ~[u.convo(last-read message-id.action)]
  ::
      %make-invite
    ::  create an invite and send to someone
    ?~  convo=(fetch-conversation conversation-id.action)
      ~|("%pongo: couldn't find that conversation id" !!)
    :_  state(invites-sent (~(put ju invites-sent.state) id.u.convo to.action))
    :_  ~
    %+  ~(poke pass:io /send-invite)
      [to.action %pongo]
    ping+!>(`ping`[%invite u.convo])
  ::
      %accept-invite
    ::  accept an invite we've been sent, join the conversation
    ::  add this convo to our conversations table and create
    ::  a messages table for it
    ::
    ::  conversation names must be locally unique, so if we
    ::  already have a conversation with this name, we append
    ::  a number to the end of the name.
    ::
    =/  [from=@p convo=conversation]
      (~(got by invites.state) conversation-id.action)
    =.  members.p.meta.convo
      (~(put in members.p.meta.convo) our.bowl)
    =^  convo  database.state
      ?~  hav=(fetch-conversation id.convo)
        ::  we've never been in this conversation before
        =.  name.convo  (make-unique-name name.convo)
        =.  database.state
          =+  %+  ~(insert-rows db:nec database.state)
                %pongo^%conversations
              ~[convo(last-active now.bowl, last-read 0)]
          %+  ~(add-table db:nec -)
            %pongo^id.convo
          :^    (make-schema:nec messages-schema)
              primary-key=~[%id]
            (make-indices:nec messages-indices)
          ~
        [convo database.state]
      ::  we've been here before, revive "deleted" convo
      ?.  deleted.u.hav
        ::  we've been here before and we never really left!
        ::  if this is a DM, it means that they deleted and now want
        ::  to start anew, but we never deleted the old DMs. treat
        ::  it as them re-joining.
        ?:  ?=(%dm -.p.meta.convo)
          =.  members.p.meta.convo
            (~(put in members.p.meta.convo) from)
          :-  convo
          %+  ~(update-rows db:nec database.state)
          %pongo^%conversations  ~[convo]
        [convo database.state]
      :-  convo
      ::  delete old messages table
      =+  (~(drop-table db:nec database.state) %pongo^id.convo)
      ::  update entry for this convo
      =+  %+  ~(update-rows db:nec -)
            %pongo^%conversations
          ~[convo(last-active now.bowl, last-read 0)]
      ::  add new messages table
      %+  ~(add-table db:nec -)
        %pongo^id.convo
      :^    (make-schema:nec messages-schema)
          primary-key=~[%id]
        (make-indices:nec messages-indices)
      ~
    :_  state(invites (~(del by invites.state) id.convo))
    %+  snoc
      %+  turn  ~(tap in members.p.meta.convo)
      |=  mem=@p
      (graph-add-tag mem name.convo)
    %+  ~(poke pass:io /accept-invite)
      [from %pongo]
    ping+!>(`ping`[%accept-invite id.convo])
  ::
      %reject-invite
    ::  reject an invite we've been sent
    ?~  invite=(~(get by invites.state) conversation-id.action)  `state
    :_  state(invites (~(del by invites.state) conversation-id.action))
    :_  ~
    %+  ~(poke pass:io /accept-invite)
      [from.u.invite %pongo]
    ping+!>(`ping`[%reject-invite conversation-id.action])
  ::
      %make-invite-request
    ::  try to join a public conversation off id and existing member
    :_  state  :_  ~
    %+  ~(poke pass:io /request-invite)  [to.action %pongo]
    ping+!>(`ping`[%invite-request conversation-id.action])
  ::
      %block
    ::  add a ship to our block-list, they cannot message us or invite us
    `state(blocked (~(put in blocked.state) who.action))
  ::
      %unblock
    ::  remove a ship from our block-list
    `state(blocked (~(del in blocked.state) who.action))
  ::
      %search
    ::  search in messages for a phrase. can filter by conversation
    ::  or author. to get results, first subscribe to /search-results
    ::  batch results in groupings of 1.000 messages in order of
    ::  recency to get fast initial returns
    =/  tid  `@ta`(cat 3 'search_' (scot %ux uid.action))
    =/  ta-now  `@ta`(scot %da now.bowl)
    =/  start-args
      :^  ~  `tid  byk.bowl(r da+now.bowl)
      search+!>(`search`[database.state +.+.action])
    :_  state
    :~  %+  ~(poke pass:io /thread/[ta-now])
          [our.bowl %spider]
        spider-start+!>(start-args)
        %+  ~(watch pass:io /thread/updates/(scot %ux uid.action))
          [our.bowl %spider]
        /thread/[tid]/updates
    ==
  ::
      %cancel-search
    =/  tid  `@ta`(cat 3 'search_' (scot %ux uid.action))
    =/  ta-now  `@ta`(scot %da now.bowl)
    :_  state  :_  ~
    %+  ~(poke pass:io /thread-stop/[ta-now])
      [our.bowl %spider]
    spider-stop+!>([tid %.y])
  ::
      %set-notifications
    `state(notif-settings notif-settings.action)
  ::
      %mute-conversation
    =.  database.state
      =<  +
      %+  ~(q db:nec database.state)  %pongo
      :^  %update  %conversations
        [%s %id %& %eq conversation-id.action]
      ~[[%muted |=(v=value:nec %.y)]]
    `state
  ::
      %unmute-conversation
    =.  database.state
      =<  +
      %+  ~(q db:nec database.state)  %pongo
      :^  %update  %conversations
        [%s %id %& %eq conversation-id.action]
      ~[[%muted |=(v=value:nec %.n)]]
    `state
  ==
::
++  handle-graph-update
  |=  =update:s
  ^-  (quip card _state)
  ?-    -.q.update
      %all  !!  ::  we don't like these
      %new-tag
    ::  if a ship-node, add a member to chat
    =/  cid  (~(got by tagged.state) tag.p.update)
    =/  convo  (need (fetch-conversation cid))
    ?.  ?=(%ship -.to.q.update)  `state
    ?:  (~(has in members.p.meta.convo) +.to.q.update)  `state
    :_  =-  state(invites-sent -)
        (~(put ju invites-sent.state) id.convo +.to.q.update)
    :_  ~
    %+  ~(poke pass:io /send-invite)
      [+.to.q.update %pongo]
    ping+!>(`ping`[%invite convo])
  ::
      %gone-tag
    ::  if a ship-node, remove a member from chat
    ::  send a member-remove message to kick, only if we are leader
    =/  cid  (~(got by tagged.state) tag.p.update)
    =/  convo  (need (fetch-conversation cid))
    ?.  ?=(%ship -.to.q.update)                         `state
    ?.  (~(has in members.p.meta.convo) +.to.q.update)  `state
    ?.  ?=(%managed -.p.meta.convo)                     `state
    ?.  (~(has in leaders.p.meta.convo) our.bowl)       `state
    :_  state  :_  ~
    %+  ~(poke pass:io /send-kick-message)
      [our.bowl %pongo]
    :-  %pongo-action
    !>  ^-  action
    [%send-message '' id.convo %member-remove (scot %p +.to.q.update) ~ ~]
  ==
::
++  handle-scry
  |=  =path
  ^-  (unit (unit cage))
  ?+    path  ~|("unexpected scry into {<dap.bowl>} on path {<path>}" !!)
  ::
  ::  see our blocklist
  ::
      [%x %blocklist ~]
    ``pongo-update+!>(`pongo-update`[%blocklist blocked.state])
  ::
  ::  get all conversations and get unread count + most recent message
  ::
      [%x %conversations ~]
    =-  ``pongo-update+!>(`pongo-update`[%conversations -])
    ^-  (list conversation-info)
    %+  turn
      ::  only get undeleted conversations
      =<  -
      %+  ~(q db:nec database.state)  %pongo
      [%select %conversations where=[%s %deleted %& %eq %.n]]
    |=  =row:nec
    =/  convo=conversation
      !<(conversation [-:!>(*conversation) row])
    =/  last-message=(unit message)
      =-  ?~(-.- ~ `!<(message [-:!>(*message) (head -.-)]))
      %+  ~(q db:nec database.state)  %pongo
      [%select id.convo where=[%s %id %& %eq last-message.convo]]
    :+  convo
      last-message
    ?~  last-message  0
    ?:  (gth last-read.convo id.u.last-message)  0
    (sub id.u.last-message last-read.convo)
  ::
  ::  get all messages from a particular conversation
  ::  warning: could be slow for long conversations!
  ::
      [%x %all-messages @ ~]
    =-  ``pongo-update+!>(`pongo-update`[%message-list -])
    ^-  (list message)
    =/  convo-id  (slav %ux i.t.t.path)
    ?~  convo=(fetch-conversation convo-id)
      ~
    %+  turn
      -:(~(q db:nec database.state) %pongo [%select id.u.convo where=[%n ~]])
    |=  =row:nec
    !<(message [-:!>(*message) row])
  ::
  ::  /messages/[convo-id]/[msg-id]/[num-before]/[num-after]
  ::
      [%x %messages @ @ @ @ ~]
    =/  convo-id    (slav %ux i.t.t.path)
    =/  message-id  (slav %ud i.t.t.t.path)
    =/  num-before  (slav %ud i.t.t.t.t.path)
    =/  num-after   (slav %ud i.t.t.t.t.t.path)
    =/  start=@ud
      ?:  (gth num-before message-id)  0
        (sub message-id num-before)
    =/  end=@ud
      (add message-id num-after)
    =-  ``pongo-update+!>(`pongo-update`[%message-list -])
    ^-  (list message)
    ?~  convo=(fetch-conversation convo-id)  ~
    %+  turn
      =<  -
      %+  ~(q db:nec database.state)  %pongo
      :+  %select  id.u.convo
      :+  %and
        [%s %id %& %gte start]
      [%s %id %& %lte end]
    |=  =row:nec
    !<(message [-:!>(*message) row])
  ::
  ::
  ::
      [%x %notification @ @ ~]
    =/  convo-id    (slav %ux i.t.t.path)
    =/  message-id  (slav %ud i.t.t.t.path)
    ?~  convo=(fetch-conversation convo-id)  [~ ~]
    =-  ``pongo-update+!>(`pongo-update`[%notification -])
    :-  name.u.convo
    =<  [author content]
    !<  message
    :-  -:!>(*message)
    %-  head
    =<  -
    %+  ~(q db:nec database.state)  %pongo
    :+  %select  id.u.convo
    [%s %id %& %eq message-id]
  ::
  ::  get all sent and received invites
  ::
      [%x %invites ~]
    ``pongo-update+!>(`pongo-update`[%invites invites-sent.state invites.state])
  ::
  ::  get current notification level
  ::
      [%x %notif-settings ~]
    ``pongo-update+!>(`pongo-update`[%notif-settings notif-settings.state])
  ==
::
++  fetch-conversation
  |=  id=conversation-id
  ^-  (unit conversation)
  =-  ?~(- ~ `!<(conversation [-:!>(*conversation) (head -)]))
  -:(~(q db:nec database.state) %pongo [%select %conversations where=[%s %id %& %eq id]])
::
++  message-poke
  |=  [to=@p =ping]
  ^-  card
  (~(poke pass:io /send-message) [to %pongo] ping+!>(ping))
::
++  make-unique-name
  |=  given=@t
  ^-  @t
  =+  =<  -
      %+  ~(q db:nec database.state)  %pongo
      [%select %conversations [%s %name %& %eq given]]
  ?:  ?=(~ -)  given
  (rap 3 ~[given '-' (scot %ud `@`(end [3 1] eny.bowl))])
::
++  delivered-card
  |=  [author=@p convo=@ux hash=@uvH]
  ^-  card
  %+  ~(poke pass:io /delivered)
    [author %pongo]
  ping+!>(`ping`[%delivered convo hash])
::
++  give-update
  |=  upd=pongo-update
  ^-  card
  ::  ~&  >>  "giving fact to frontend: "
  ::  ~&  >>  (crip (en-json:html (update-to-json:parsing upd)))
  (fact:io pongo-update+!>(upd) ~[/updates])
::
++  graph-add-tag
  |=  [who=@p convo-name=@t]
  ^-  card
  %+  ~(poke pass:io /add-tag)
    [our.bowl %social-graph]
  :-  %social-graph-edit
  !>([%pongo [%add-tag convo-name ship+our.bowl ship+who]])
::
++  graph-del-tag
  |=  [who=@p convo-name=@t]
  ^-  card
  %+  ~(poke pass:io /del-tag)
    [our.bowl %social-graph]
  :-  %social-graph-edit
  !>([%pongo [%del-tag convo-name ship+our.bowl ship+who]])
::
::  nuke tag of certain convo -- used when we leave conversation
++  graph-nuke-tag
  |=  name=@t
  ^-  card
  %+  ~(poke pass:io /nuke-tag)
    [our.bowl %social-graph]
  social-graph-edit+!>([%pongo [%nuke-tag name]])
::
++  scry-tag-controller
  |=  tag=@t
  ^-  @p
  =/  res
    .^  graph-result:s  %gx
      %+  weld
        /(scot %p our.bowl)/social-graph/(scot %da now.bowl)
      /controller/posse/[tag]/noun
    ==
  ?>  ?=(%controller -.res)
  +.res
::
++  get-ships-from-tag
  |=  [center=@p tag=@t]
  ^-  (set @p)
  =/  nodes
    .^  graph-result:s  %gx
      %+  weld
        /(scot %p our.bowl)/social-graph/(scot %da now.bowl)
      /nodes/posse/ship/(scot %p center)/[tag]/noun
    ==
  ?>  ?=(%nodes -.nodes)
  ::  filter nodes for only ships
  %-  ~(gas in *(set @p))
  %+  murn  ~(tap in +.nodes)
  |=(=node:s ?:(?=(%ship -.node) `+.node ~))
--