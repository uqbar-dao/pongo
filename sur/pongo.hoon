|%
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
      ::  experiment: can we add mentions *later*?
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
  $?  %text  %image
      %link  %code
      %reply
      ::  in these kinds, message content is a `@t`(scot %p @p)
      %member-add     ::  in FFA, anyone can send this, otherwise only leaders
      %member-remove  ::  in FFA, only member leaving can send
      %change-name
      %leader-add     ::  only for %many-leader
      %leader-remove  ::  only for %many-leader
      %change-router  ::  TBD
  ==
++  my-special-number  521.510.348.146
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
      [%messages-table-id [[1 | %ux]]]
      [%name [2 | %t]]
      [%last-active [3 | %da]]
      [%last-read [4 | %ud]]  ::  id of message we last saw
      [%router [5 | %p]]
      [%members [6 | %blob]]
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
  $%  [%single-leader members=(set @p) leader=@p]
      [%many-leader members=(set @p) leaders=(set @p)]
      [%free-for-all members=(set @p) ~]
  ==
::
::  a conversation id is constructed by hashing the concatenation
::  of the creator and some entropy grabbed by the creator
::
+$  conversation-id  @ux
::
::  can do this to turn a row into a conversation:
::  !<(conversation [-:!>(*conversation) row])
::
+$  conversation
  $:  id=conversation-id
      messages-table-id=@ux
      name=@t
      last-active=@da
      last-read=message-id
      router=@p
      meta=[%b p=conversation-metadata]
      ~
  ==
::
::  all messaging is done through pokes.
::  messages are sent to router, who then pokes all members
::
+$  ping
  $%  ::  these are sent to / received from router
      [%message routed=? =conversation-id =message]
      [%edit =conversation-id on=message-id edit=@t]
      [%react =conversation-id on=message-id =reaction]
      ::  these are only sent when conversation size is below cutoff
      [%delivered hash=@uvH]
      ::  these are sent to anyone
      [%invite =conversation]            ::  person creating the invite sends
      [%accept-invite =conversation-id]  ::  %member-add message upon accept
      [%reject-invite =conversation-id]
  ==
::
::  pokes that our frontend performs:
::
+$  action
  $%  [%make-conversation name=@t config=conversation-metadata]
      [%leave-conversation =conversation-id]
      ::
      [%send-message =conversation-id =message-kind content=@t reference=(unit message-id)]
      [%send-message-edit =conversation-id on=message-id edit=@t]
      [%send-reaction =conversation-id on=message-id =reaction]
      ::  frontend telling us we've seen up to message-id in convo
      [%read-message =conversation-id =message-id]
      ::
      [%make-invite to=@p =conversation-id]
      [%accept-invite =conversation-id]
      [%reject-invite =conversation-id]
      ::
      [%block who=@p]
      [%unblock who=@p]
  ==
::
::  update types from scries and subscriptions, used for interacting
::
+$  pongo-update
  $%  [%conversations (list conversation-info)]
      [%message-list (list message)]
  ==
::
+$  conversation-info
  $:  conversation
      last-message=(unit message)
      unreads=@ud
  ==
--