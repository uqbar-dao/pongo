/-  *posse, s=social-graph
/+  verb, dbug, default-agent, io=agentio
|%
::
::  posse: contact management system built on top of %social-graph
::         - track ships and assign categories to them
::         - attach arbitrary information to each ship, stored here
::
::         long-term i'd like to jettison the arbitrary info and stick
::         purely to tag assignment.
::
::  agent state holds detailed info -- tags held in social-graph
::  posse provides a scry path to get detailed info
::  if you want to watch a tag, poke %social-graph directly
::
+$  state
  $:  contacts=(map @p details)
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
      |=  old=vase
      ^-  (quip card _this)
      `this(state !<(_state old))
    ::
    ++  on-poke
      |=  [=mark =vase]
      ^-  (quip card _this)
      ?>  =(our src):bowl
      =^  cards  state
        ?+  mark  (on-poke:def mark vase)
          %posse-action  (handle-action:hc !<(action vase))
        ==
      [cards this]
    ::
    ++  on-peek   handle-scry:hc
    ++  on-agent  on-agent:def
    ++  on-watch  on-watch:def
    ++  on-arvo   on-arvo:def
    ++  on-leave  on-leave:def
    ++  on-fail   on-fail:def
    --
::
|_  bowl=bowl:gall
  ++  handle-action
    |=  =action
    ^-  (quip card _state)
    ?-    -.action
        %add-tag
      :_  state  :_  ~
      %+  ~(poke pass:io /add-tag)
        [our.bowl %social-graph]
      :-  %social-graph-edit
      !>([%posse [%add-tag tag.action ship+our.bowl ship+who.action]])
    ::
        %del-tag
      :_  state  :_  ~
      %+  ~(poke pass:io /add-tag)
        [our.bowl %social-graph]
      :-  %social-graph-edit
      !>([%posse [%del-tag tag.action ship+our.bowl ship+who.action]])
    ::
        %edit-details
      `state(contacts (~(put by contacts.state) who.action details.action))
    ::
        %join-posse
      :_  state  :_  ~
      %+  ~(poke pass:io /join-posse)
        [our.bowl %social-graph]
      :-  %social-graph-edit
      !>([%posse [%start-tracking controller.action %posse tag.action]])
    ==
  ::
  ++  handle-scry
    |=  =path
    ^-  (unit (unit cage))
    ?+    path  [~ ~]
        [%x %contact @ ~]
      ::  return contact details for a given ship
      =/  who  (slav %p i.t.t.path)
      ``posse-update+!>(`update`[%details (~(gut by contacts.state) who ~)])
    ::
        [%x %tag @ ~]
      ::  return set of ships with given tag
      ::  you can also just get this direct from %social-graph
      =/  tag  `@t`i.t.t.path
      =/  nodes
        .^  graph-result:s  %gx
          %+  weld
            /(scot %p our.bowl)/social-graph/(scot %da now.bowl)
          /nodes/posse/ship/(scot %p our.bowl)/[tag]/noun
        ==
      ?>  ?=(%nodes -.nodes)
      ::  filter nodes for only ships
      =-  ``posse-update+!>(`update`[%tag -])
      %-  ~(gas in *(set @p))
      %+  murn  ~(tap in +.nodes)
      |=(=node:s ?:(?=(%ship -.node) `+.node ~))
    ==
--