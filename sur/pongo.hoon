|%
::
::  schema: a table handles one conversation
::
++  messages-schema
  :~  [%id [0 | %ud]]
      [%author [1 | %p]]
      [%signature [2 | %blob]]
      [%timestamp [3 | %da]]
      [%seen [4 | %f]]
      [%kind [5 | %tas]]
      [%content [6 | %t]]
      [%reference [7 & %ud]]  ::  for replies
      [%reactions [8 | %list]]
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
      signature=[%blob p=[p=@ux q=ship r=life]]
      timestamp=@da
      seen=?
      kind=message-kind
      content=@t
      reference=(unit message-id)
      reactions=(list (pair @p reaction))
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
::
::  these are the only reactions you're allowed to have to something
::
+$  reaction
  $?  %love       %hate
      %like       %dislike
      %emphasize  %question
  ==
::
::  a conversation is a groupchat of 2-100 ships.
::  schema: we keep a table of all our conversations
::
++  conversations-schema
  :~  [%id [0 | %ux]]
      [%messages-table-id [[1 | %ux]]]
      [%name [2 | %t]]
      [%last-active [3 | %da]]
      [%router [4 | %p]]
      [%members [5 | %blob]]
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
      router=@p
      meta=[%blob p=conversation-metadata]
      ~
  ==
::
::  all messaging is done through pokes.
::  messages are sent to router, who then pokes all members
::
+$  ping
  $%  ::  these are sent to / received from router
      [%message =conversation-id routed=? =message]  ::  TODO add ship-sig so router can't spoof
      [%react =conversation-id on=message-id =reaction]
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
      [%send-reaction =conversation-id on=message-id =reaction]
      ::
      [%make-invite to=@p =conversation-id]
      [%accept-invite =conversation-id]
      [%reject-invite =conversation-id]
      ::
      [%block who=@p]
      [%unblock who=@p]
  ==
::
::  TODO: update type that our FE subscription gets
::
--