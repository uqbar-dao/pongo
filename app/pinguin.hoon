/-  *pinguin
/+  verb, dbug, default-agent,
    miasma
|%
::
::  %pinguin agent state
::
+$  state
  $:  db=_database:miasma
      blocked=(set @p)
      invites-received=(list [from=@p =conversation])
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
    ++  on-init  `this(state *_state)
    ::
    ++  on-save  !>(state)
    ::
    ++  on-load
      |=  =vase
      ^-  (quip card _this)
      ::  if old state is incompatible, bunt state type
      ?~  old=((soft _state) q.vase)
        `this(state *_state)
      `this(state u.old)
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
    ++  on-peek  handle-scry:hc
    ++  on-agent  on-agent:def
    ++  on-watch  on-watch:def
    ++  on-arvo  on-arvo:def
    ++  on-leave  on-leave:def
    ++  on-fail   on-fail:def
    --
::
|_  bowl=bowl:gall
  ++  handle-ping
    |=  =ping
    ^-  (quip card _state)
    !!
  ::
  ++  handle-action
    |=  =action
    ^-  (quip card _state)
    !!
  ::
  ++  handle-scry
    |=  =path
    ^-  (unit (unit cage))
    !!
--