/-  *posse
/+  verb, dbug, default-agent,  io=agentio
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
::
::  TODO make a solid-state sub that apps can use to watch a tag
::
+$  state
  $:  contacts=(map @p detail)
      our-tags=(map tag @ud)    ::  count of how many of each tag we have
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
      =/  count=@ud  (~(gut by our-tags.state) tag.action 0)
      :_  state(our-tags (~(put by our-tags.state) tag.action +(count)))
      :_  ~
      %+  ~(poke pass:io /add-tag)
        [our.bowl %social-graph]
      edit+!>([%posse [%add-tag ship+our.bowl ship+who.action tag.action]])
    ::
        %del-tag
      =/  count=@ud  (~(gut by our-tags.state) tag.action 0)
      =.  our-tags.state
        ?:  =(count 0)
          our-tags.state
        ?:  =(count 1)
          (~(del by our-tags.state) tag.action)
        (~(put by our-tags.state) tag.action (dec count))
      :_  state  :_  ~
      %+  ~(poke pass:io /add-tag)
        [our.bowl %social-graph]
      edit+!>([%posse [%del-tag ship+our.bowl ship+who.action tag.action]])
    ::
        %edit-detail  !!
    ==
  ::
  ++  handle-scry
    |=  =path
    ^-  (unit (unit cage))
    !!
--