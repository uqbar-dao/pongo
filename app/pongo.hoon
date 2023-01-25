/-  *pongo
/+  verb, dbug, default-agent, io=agentio,
    *pongo, nectar, sig
|%
::  if the conversation has this many members or less,
::  we'll track delivery to each recipient.
++  delivery-tracking-cutoff  5
::
::  %pongo agent state
::
+$  state
  $:  db=_database:nectar
      blocked=(set @p)
      invites=(map conversation-id [from=@p =conversation])
      invites-sent=(jug conversation-id @p)
      undelivered=(map @uvH [message want=(set @p)])  ::  keyed by hash
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
      :_  [~ ~ ~ ~]
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
            %pongo-action  (handle-action:hc !<(action vase))
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
            %poke-ack
          ?~  p.sign  `this
          %-  (slog leaf+"search thread failed to start" u.p.sign)
          `this
        ::
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
            ~&  >>  "giving fact to frontend on path {<~[/search-results/[tid]]>}: "
            ~&  >>  (crip (en-json:html (update-to-json:parsing upd)))
            :_  this
            (fact:io pongo-update+!>(upd) ~[/search-results/[tid]])^~
          ==
        ==
      ==
    ::
    ++  on-arvo   on-arvo:def
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
    ?~  want.u.has
      ~&  "message delivered."
      :-  (give-update [%delivered timestamp.u.has])^~
      state(undelivered (~(del by undelivered.state) hash.ping))
    `state(undelivered (~(put by undelivered.state) hash.ping u.has))
  =/  cid=conversation-id
    ::  IRRITATING type refinement here
    ?-  -.ping
      %invite   id.conversation.ping
      %message  conversation-id.ping
      ?(%edit %react)  conversation-id.ping
      ?(%accept-invite %reject-invite)  conversation-id.ping
    ==
  =/  conv=(unit conversation)
    ?:  ?=(%invite -.ping)
      `conversation.ping
    (fetch-conversation cid)
  ?~  conv
    ~&  >>>  "%pongo: couldn't find conversation"
    `state
  =*  convo  u.conv
  ?-    -.ping
      %message
    ::  we've received a new message
    ::  if we are router, we now poke every member with this message
    =*  message  message.ping
    ?:  &(!routed.ping =(our.bowl router.convo))
      ::  assign ordering to message here
      =.  id.message
        =/  res
          =<  -
          %-  q:db.state
          [%select messages-table-id.convo where=[%s %id %& %bottom 1]]
        ?~  res  0
        +(id:!<(^message [-:!>(*^message) (head res)]))
      :_  state
      %+  turn  ~(tap in members.p.meta.convo)
      |=  to=@p
      %+  ~(poke pass:io /route-message)
        [to %pongo]
      ping+!>(`^ping`[%message routed=& cid message])
    ::  if we are not router, we only receive messages from router
    ::  only accept the message if it's from a member of that conversation
    ::  add it to our messages table for that conversation
    ?>  =(src.bowl router.convo)
    =/  message-hash  (make-message-hash [content author timestamp]:message)
    ?.  (validate:sig our.bowl p.signature.message message-hash now.bowl)
      ~&  >>>  "%pongo: rejecting message, invalid signature"  `state
    ?.  (~(has in members.p.meta.convo) author.message)
      ~&  >>>  "%pongo: rejecting weird message"  `state
    ::  TODO this is a weird bug check really, can probs remove
    ?.  (~(has by tables:db.state) messages-table-id.convo)
      ~&  >>>  "%pongo: rejecting WEIRD message"  `state
    ?:  (~(has in blocked.state) author.message)
      ::  ignore any messages from blocked ships unless
      ::  it's them leaving the conversation!
      ::  we *do* send delivered receipts to those we have blocked.
      ?.  =(%member-remove kind.message)
        :_  state
        (delivered-card author.message message-hash)^~
      =.  db.state
        %+  update-rows:db.state
          %conversations
        :_  ~
        convo(members.p.meta (~(del in members.p.meta.convo) author.message))
      `state
    =.  timestamp.message  now.bowl
    ~?  ?|  !=(our.bowl author.message)
            ?=(?(%member-add %change-name) kind.message)
        ==
      (print-message message)
    ::  if the message kind is a member or leader set edit,
    ::  we update our conversation to reflect it -- only
    ::  if message was sent by someone allowed to do it
    =.  db.state
      =-  (update-rows:db.state %conversations -)
      :_  ~
      ^-  conversation
      =.  last-active.convo  now.bowl
      ?.  ?&  ?=  $?  %member-add  %member-remove
                      %leader-add  %leader-remove
                      %change-name
                  ==
              kind.message
              ?-  -.p.meta.convo
                %free-for-all  %.y
                  %single-leader
                =(author.message leader.p.meta.convo)
                  %many-leader
                (~(has in leaders.p.meta.convo) author.message)
          ==  ==
        convo
      =?    members.p.meta.convo
          ?=(?(%member-add %member-remove) kind.message)
        ?-  kind.message
            %member-add
          (~(put in members.p.meta.convo) (slav %p content.message))
            %member-remove
          (~(del in members.p.meta.convo) (slav %p content.message))
        ==
      =?    name.convo
          ?=(%change-name kind.message)
        content.message
      ?+    -.p.meta.convo  convo
          %many-leader
        %=    convo
            leaders.p.meta
          ?+    kind.message  leaders.p.meta.convo
              %leader-add
            (~(put in leaders.p.meta.convo) (slav %p content.message))
              %leader-remove
            (~(del in leaders.p.meta.convo) (slav %p content.message))
          ==
        ==
      ==
    =.  db.state
      (insert-rows:db.state messages-table-id.convo ~[message])
    ?.  (lte kind.message my-special-number)
      :_  state
      (give-update [%message id.convo message])^~
    :_  state
    :~  (delivered-card author.message message-hash)
        (give-update [%message id.convo message])
    ==
  ::
      %edit
    ::  we've received an edit of a message
    ?.  (~(has in members.p.meta.convo) src.bowl)
      ~&  >>>  "%pongo: rejecting reaction"  `state
    ?.  (~(has by tables:db.state) messages-table-id.convo)
      ~&  >>>  "%pongo: rejecting reaction"  `state
    ::
    ::  TODO: implement a waiting feature for edits to message IDs
    ::  which we haven't received yet!!!
    ::
    ~?  !=(our src):bowl
      (print-edit src.bowl ping)
    =.  db.state
      =+  |=  v=value:nectar
          ^-  value:nectar
          ?>  ?=(@t v)
          edit.ping
      =<  +
      %-  q:db.state
      :*  %update  messages-table-id.convo
          :+  %and
            [%s %id %& %eq on.ping]
          :+  %and
            [%s %author %& %eq src.bowl]
          ::  comically hacky way to enforce that edits can only be done
          ::  on kinds %text, %image, %link, %code, %reply
          ::  i just like doing it this way
          [%s %kind %& %lte my-special-number]
          :~  [%content -]
              [%edited |=(v=value:nectar `value:nectar`%.y)]
          ==
      ==
    `state
  ::
      %react
    ::  we've received a new message reaction
    ?.  (~(has in members.p.meta.convo) src.bowl)
      ~&  >>>  "%pongo: rejecting reaction"  `state
    ?.  (~(has by tables:db.state) messages-table-id.convo)
      ~&  >>>  "%pongo: rejecting reaction"  `state
    ::
    ::  TODO: implement a waiting feature for reacts to message IDs
    ::  which we haven't received yet!!!
    ::
    ~?  !=(our src):bowl
      (print-reaction src.bowl ping)
    =.  db.state
      =+  |=  v=value:nectar
          ^-  value:nectar
          ?>  ?=(^ v)
          ?>  ?=(%m -.v)
          [%m (~(put by p.v) src.bowl reaction.ping)]
      =<  +
      %-  q:db.state
      :^    %update
          messages-table-id.convo
        [%s %id %& %eq on.ping]
      ~[[%reactions -]]
    `state
  ::
      %invite
    ::  we've received an invite to a conversation
    ?:  (~(has in blocked.state) src.bowl)
      ::  ignore invites from blocked ships
      `state
    ~&  >>  "%pongo: {<src.bowl>} invited us to conversation {<cid>}"
    :-  (give-update [%invite conversation.ping])^~
    =-  state(invites -)
    %+  ~(put by invites.state)
      cid
    [src.bowl conversation.ping]
  ::
      %accept-invite
    ::  an invite we sent has been accepted
    ::  create a message in conversation with kind %member-add
    ?>  (~(has ju invites-sent.state) cid src.bowl)
    :_  state(invites-sent (~(del ju invites-sent.state) cid src.bowl))
    =/  hash  (make-message-hash (scot %p src.bowl) [our now]:bowl)
    =/  member-add-message=message
      :*  *message-id
          our.bowl
          signature=[%b (sign:sig our.bowl now.bowl hash)]
          now.bowl
          %member-add
          (scot %p src.bowl)
          %.n  ~  [%m ~]  ~
      ==
    :_  ~
    %+  ~(poke pass:io /accept-invite)
      [router.convo %pongo]
    ping+!>(`^ping`[%message routed=| cid member-add-message])
  ::
      %reject-invite
    ::  an invite we sent has been rejected
    ~&  >>  "%pongo: {<src.bowl>} rejected invite to conversation {<cid>}"
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
          name.action
          last-active=now.bowl
          last-read=0
          router=our.bowl
          :-  %b
          config.action(members (~(put in members.config.action) our.bowl))
          %.n
          ~
      ==
    ::  add this conversation to our table
    ::  and create a messages table for it
    =.  db.state
      (insert-rows:db.state %conversations ~[convo])
    =.  db.state
      %+  add-table:db.state
        messages-table-id.convo
      :^    (make-schema:nectar messages-schema)
          primary-key=~[%id]
        (make-indices:nectar messages-indices)
      ~
    ::  poke all indicated members in metadata with invites
    =/  mems  ~(tap in (~(del in members.config.action) our.bowl))
    ~&  >>  "%pongo: made conversation id: {<id.convo>} and invited {<mems>}"
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
    =.  db.state
      =<  +
      %-  q:db.state
      :^    %update
          %conversations
        [%s %id %& %eq conversation-id.action]
      ~[[%deleted |=(v=value:nectar %.y)]]
    =-  $(action `^action`[%send-message -])
    [conversation-id.action %member-remove (scot %p our.bowl) ~]
  ::
      %send-message
    ::  create a message and send to a conversation we're in
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
          [%m ~]  ~
      ==
    ?~  convo=(fetch-conversation conversation-id.action)
      ~|("%pongo: couldn't find that conversation id" !!)
    :_  ?:  (lte delivery-tracking-cutoff ~(wyt in members.p.meta.u.convo))
          state
        =-  state(undelivered (~(put by undelivered.state) hash -))
        [message (~(del in members.p.meta.u.convo) our.bowl)]
    :_  (give-update [%sending now.bowl])^~
    %+  ~(poke pass:io /send-message)
      [router.u.convo %pongo]
    ping+!>(`ping`[%message routed=| conversation-id.action message])
  ::
      %send-message-edit
    ::  edit a message we sent (must be of kind %text/%image/%link/%code)
    ::  as opposed to *new* messages, which must be sequenced by router,
    ::  we can poke edits out directly to all members
    ?~  convo=(fetch-conversation conversation-id.action)
      ~|("%pongo: couldn't find that conversation id" !!)
    :_  state
    %+  turn  ~(tap in members.p.meta.u.convo)
    |=  to=@p
    %+  ~(poke pass:io /send-edit)
      [to %pongo]
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
    %+  ~(poke pass:io /send-react)
      [to %pongo]
    ping+!>(`ping`[%react [conversation-id on reaction]:action])
  ::
      %read-message
    ::  if read id is newer than current saved read id, replace in convo
    ?~  convo=(fetch-conversation conversation-id.action)
      ~|("%pongo: couldn't find that conversation id" !!)
    ?.  (gth message-id.action last-read.u.convo)
      `state
    =-  `state(db -)
    %+  insert-rows:db.state
      %conversations
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
    =/  [from=@p convo=conversation]
      (~(got by invites.state) conversation-id.action)
    ::  TODO: if we're *already in* this conversation,
    ::  skip all this
    =.  members.p.meta.convo
      (~(put in members.p.meta.convo) our.bowl)
    =.  db.state
      %+  insert-rows:db.state
        %conversations
      ~[convo(last-active now.bowl, last-read 0)]
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
      [~ `tid byk.bowl(r da+now.bowl) %search !>(`search`[db.state +.+.action])]
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
  ==
::
++  handle-scry
  |=  =path
  ^-  (unit (unit cage))
  ?+    path
    ~|("unexpected scry into {<dap.bowl>} on path {<path>}" !!)
  ::
  ::  good scries:
  ::  -  get X most recently active conversations
  ::  -  get X most recent messages from conversation Y
  ::  -  get X most recent messages each from Y most recently active conversations
  ::  -  get all messages in conversation X between id Y and id Z
  ::  -  get all conversations
  ::  -  search conversation for keyword in message
  ::  -  search all conversations for keyword is any message
  ::  -  get all mentions between date X and now
  ::  -  get single message with id X in conversation Y
  ::
  ::
  ::  get all conversations and get unread count + most recent message
  ::
      [%x %conversations ~]
    ~&  >  "pongo: fetching all conversations"
    ~>  %bout
    =-  ``pongo-update+!>([%conversations -])
    ^-  (list conversation-info)
    %+  turn
      ::  only get undeleted conversation
      -:(q:db.state [%select %conversations where=[%s %deleted %& %eq %.n]])
    |=  =row:nectar
    =/  convo=conversation
      !<(conversation [-:!>(*conversation) row])
    =/  last-message=(unit message)
      =-  ?~(-.- ~ `!<(message [-:!>(*message) (head -.-)]))
      (q:db.state [%select messages-table-id.convo where=[%s %id %& %bottom 1]])
    :+  convo
      last-message
    ?~  last-message  0
    (sub id.u.last-message last-read.convo)
  ::
  ::  get all messages from a particular conversation
  ::  warning: could be slow for long conversations!
  ::
      [%x %all-messages @ ~]
    ~&  >  "pongo: fetching all messages"
    ~>  %bout
    =-  ``pongo-update+!>([%message-list -])
    ^-  (list message)
    =/  convo-id  (slav %ux i.t.t.path)
    ?~  convo=(fetch-conversation convo-id)
      ~
    %+  turn
      -:(q:db.state [%select messages-table-id.u.convo where=[%n ~]])
    |=  =row:nectar
    !<(message [-:!>(*message) row])
  ::
  ::  get all sent and received invites
  ::
      [%x %invites ~]
    ``pongo-update+!>([%invites invites-sent.state invites.state])
  ==
::
++  fetch-conversation
  |=  id=conversation-id
  ^-  (unit conversation)
  =-  ?~(- ~ `!<(conversation [-:!>(*conversation) (head -)]))
  -:(q:db.state [%select %conversations where=[%s %id %& %eq id]])
::
++  delivered-card
  |=  [author=@p hash=@uvH]
  ^-  card
  %+  ~(poke pass:io /delivered)
    [author %pongo]
  ping+!>(`ping`[%delivered hash])
::
++  give-update
  |=  upd=pongo-update
  ^-  card
  ~&  >>  "giving fact to frontend: "
  ~&  >>  (crip (en-json:html (update-to-json:parsing upd)))
  (fact:io pongo-update+!>(upd) ~[/updates])
--