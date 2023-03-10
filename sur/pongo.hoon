/-  uqbar=zig-uqbar
|%
+$  notif-settings
  $:  expo-token=@t
      ship-url=@t
      level=?(%off %low %medium %high)
  ==
::
::  schema: a table handles one conversation
::
++  messages-schema
  :~  [%id [0 | %ud]]  ::  ordering produced by message router
      [%author [1 | %p]]
      [%signature [2 | %blob]]  ::  we probably don't care about storing these
      [%timestamp [3 | %da]]  ::  time *we* received message at
      [%kind [4 | %tas]]
      [%content [5 | %t]]
      [%edited [6 | %f]]
      [%reference [7 & %ud]]  ::  for replies
      [%reactions [8 | %map]]
      [%mentions [9 | %set]]
  ==
::
::  indices: columns in table we keep an index of
::  compute time to handle a message guarantees unique timestamps :)
::
++  messages-indices
  :~  [~[%id] primary=& autoincrement=~ unique=& clustered=&]
      [~[%timestamp] primary=| autoincrement=~ unique=& clustered=&]
      ::  can add an author index if we want to add search by author
  ==
::
::  the type that goes into the database
::  we can trust the database, it's ours
::  so we can do this to turn a row into a message:
::  !<(message [-:!>(*message) row])
::
+$  message
  $:  id=message-id
      author=@p
      signature=[%b p=[p=@ux q=ship r=life]]
      timestamp=@da
      kind=message-kind
      content=@t
      edited=?
      reference=(unit message-id)
      reactions=[%m p=(map @p reaction)]
      mentions=[%s p=(set @p)]
      ~
  ==
::
::  a message id is an ordered integer starting at 0
::
+$  message-id  @ud
::
::  a message can be one of these things -- messages that want to
::  be many things can be broken into multiple messages.
::
+$  message-kind
  $?  %text  %code
      ::  in these kinds, message content is a `@t`(scot %p @p)
      %member-add     ::  in %open, anyone can send this, otherwise only leaders
      %member-remove  ::  in %open, only member leaving can send
      %change-name
      %leader-add     ::  only for %many-leader
      %leader-remove  ::  only for %many-leader
      %change-router  ::  TBD
      ::  special bespoke message types
      %poll         ::  content is question being asked \n
                    ::  first response \n second response \n ...
      %send-tokens  ::  content is a (scot %ux transaction-hash)
      %app-link     ::  content is @t link (everything after ship URL)
  ==
++  my-special-number  521.510.348.146  ::  `@`%reply, lol
::
::  emojees
::
+$  reaction  @t
::
::  a conversation is a groupchat of 2-100 ships.
::  schema: we keep a table of all our conversations
::
++  conversations-schema
  :~  [%id [0 | %ux]]
      [%name [1 | %t]]
      [%last-active [2 | %da]]
      [%last-message [3 | %ud]]
      [%last-read [4 | %ud]]  ::  id of message we last saw
      [%router [5 | %p]]
      [%members [6 | %blob]]
      [%deleted [7 | %f]]
      [%muted [8 | %f]]
  ==
::
++  conversations-indices
  :~  [~[%id] primary=& autoincrement=~ unique=& clustered=|]
      [~[%last-active] primary=| autoincrement=~ unique=| clustered=&]
  ==
::
::  used to mold the blob inside schema
::
+$  conversation-metadata
  $%  [%managed members=(set @p) leaders=(set @p)]
      [%open members=(set @p) ~]  ::  hate this ~
      [%dm members=(set @p) ~]
  ==
::
::  a conversation id is constructed by hashing the concatenation
::  of the two ships involved (if DM) or creator + some entropy if group
::
+$  conversation-id  @ux
::
::  can do this to turn a row into a conversation:
::  !<(conversation [-:!>(*conversation) row])
::
+$  conversation
  $:  id=conversation-id
      name=@t
      last-active=@da
      last-message=message-id
      last-read=message-id
      router=@p
      meta=[%b p=conversation-metadata]
      deleted=?
      muted=?
      ~
  ==
::
::  all messaging is done through pokes.
::  messages are sent to router, who then pokes all members
::
+$  ping
  $%  [%message routed=? =conversation-id =message]  ::  sent thru router
      [%edit =conversation-id on=message-id edit=@t]  ::  sent direct
      [%react =conversation-id on=message-id =reaction]  ::  sent direct
      ::  these are only sent when conversation size is below cutoff
      [%delivered =conversation-id hash=@uvH]
      ::  these are sent to anyone
      [%invite =conversation]            ::  person creating the invite sends
      [%accept-invite =conversation-id]  ::  %member-add message upon accept
      [%reject-invite =conversation-id]
      ::  this allows any ship to request to join *free-for-all* convos
      ::  if they know the convo ID and the @p of a member ship.
      ::  app is tuned to automatically accept these, can be turned off.
      [%invite-request =conversation-id]
  ==
::
+$  pending-ping
  $%  [%edit src=@p edit=@t]
      [%react src=@p =reaction]
  ==
::
::  pokes that our frontend performs:
::
+$  action
  $%  [%make-conversation name=@t config=conversation-metadata]
      ::  generate a member-set from a %posse tag
      [%make-conversation-from-posse name=@t tag=@t]
      [%leave-conversation =conversation-id]
      ::
      $:  %send-message
          identifier=@t
          =conversation-id
          =message-kind
          content=@t
          reference=(unit message-id)
          mentions=(set @p)
      ==
      [%send-message-edit =conversation-id on=message-id edit=@t]
      [%send-reaction =conversation-id on=message-id =reaction]
      ::
      $:  %send-tokens
          =conversation-id
          from=@ux
          contract=@ux
          town=@ux
          to=@p
          amount=@ud
          item=@ux
      ==
      ::  frontend telling us we've seen up to message-id in convo
      [%read-message =conversation-id =message-id]
      ::
      [%make-invite to=@p =conversation-id]
      [%accept-invite =conversation-id]
      [%reject-invite =conversation-id]
      [%make-invite-request to=@p =conversation-id]  ::  FFA convos only!
      ::
      $:  %search  uid=@ux
          only-in=(unit conversation-id)
          only-author=(unit @p)
          phrase=@t
      ==
      [%cancel-search uid=@ux]
      ::
      [%set-notifications =notif-settings]
      [%set-notif-token expo-token=@t ship-url=@t]
      [%set-notif-level level=?(%off %low %medium %high)]
      [%mute-conversation =conversation-id]
      [%unmute-conversation =conversation-id]
  ==
::
::  update types from scries and subscriptions, used for interacting
::
+$  pongo-update
  $%  [%conversations (list conversation-info)]
      [%message-list (list message)]
      [%message =conversation-id =message]  ::  tell frontend about new message
      [%invite conversation]                                    ::  new invite
      [%sending =conversation-id identifier=@t]
      [%delivered =conversation-id identifier=@t =message-id]
      [%search-result (list [=conversation-id =message])]
      $:  %invites
          sent=(jug conversation-id @p)
          rec=(map conversation-id [from=@p =conversation])
      ==
      [%blocklist (set @p)]
      [%notification convo-name=@t author=@p content=@t]
      [%notif-settings notif-settings]
  ==
::  updates we sent to token-send thread
+$  thread-update
  $%  [%denied from=@p]
      [%shared from=@p address=@ux]
      [%finished sequencer-receipt:uqbar]
  ==
::
+$  conversation-info
  $:  conversation
      last=(unit message)
      unreads=@ud
  ==
--