/-  *notify, ha=hark, settings
/+  default-agent, dbug, agentio
|%
+$  card  card:agent:gall
::
++  clear-interval  ~d7
::
+$  provider-state  (map term provider-entry)
+$  provider-entry
  $:  notify-endpoint=@t
      binding-endpoint=@t
      auth-token=@t
      clients=(map ship binding=(unit @t))
      =whitelist
  ==
+$  client-state
  $:  providers=(jug @p term)
  ==
::
+$  versioned-state
  $%  state-0
  ==
+$  state-0
  $:  %0
      =provider-state
      =client-state
      notifications=(map uid notification)
  ==
--
::
=|  state-0
=*  state  -
::
%-  agent:dbug
%+  verb  |
^-  agent:gall
::
=<
  |_  =bowl:gall
  +*  this  .
      def   ~(. (default-agent this %|) bowl)
      do    ~(. +> bowl)
      io    ~(. agentio bowl)
  ::
  ++  on-init
    :_  this
    :~  (~(watch-our pass:io /hark) %hark /ui)
        (~(wait pass:io /clear) (add now.bowl clear-interval))
    ==
  ::
  ++  on-save   !>(state)
  ++  on-load
    |=  =vase
    ^-  (quip card _this)
    :_  this(state !<(_state-0 old))
    ?:  (~(has by wex.bowl) [/hark our.bowl %hark])
      ~
    ~[(~(watch-our pass:io /hark) %hark /ui)]
  ::
  ++  on-poke   on-poke:def
  ++  on-watch  on-watch:def
  ++  on-leave  on-leave:def
  ++  on-peek   on-peek:def
  ++  on-fail   on-fail:def
  ::
  ++  on-agent
    |=  [=wire =sign:agent:gall]
    ^-  (quip card _this)
    ?+  wire  (on-agent:def wire sign)
    ::
    ::  subscription from client to their own hark-store
    ::
        [%hark ~]
      ?+  -.sign  (on-agent:def wire sign)
          %fact
        ?.  ?=(%hark-action p.cage.sign)
          `this
        =+  !<(=action:ha q.cage.sign)
        =^  cards  state
          (filter-notifications:do action)
        [cards this]
      ::
          %kick
        ::  attempt to resub on kick
        [[%pass wire %agent [our.bowl %hark] %watch /ui]~ this]
      ==
    ==
  ::
  ++  on-arvo
    |=  [=wire =sign-arvo]
    ^-  (quip card _this)
    ?+  wire  (on-arvo:def wire sign-arvo)
        [%push-notification *]
      `this
    ==
  --
|_  bowl=bowl:gall
::
++  filter-notifications
  |=  =action:ha
  ^-  (quip card _state)
  ?+    -.action  `state
      %add-yarn
    ::  read from settings-store
    ::
    =/  pre=path  /(scot %p our.bowl)/settings-store/(scot %da now.bowl)
    ::  TODO remove these first two if viable
    ?.  .^(? %gx (weld pre /has-bucket/landscape/ping-app/noun))
      `state
    ?.  .^(? %gx (weld pre /has-entry/landscape/ping-app/expo-token/noun))
      `state
    =/  =data:settings
      .^(data:settings %gx (weld pre /entry/landscape/ping-app/expo-token/noun))
    ?.  ?=(%entry -.data)
      `state
    ?.  ?=(%s -.val.data)
      `state
    ::  send http request
    ::
    =|  =request:http
    =:  method.request       %'POST'
        url.request          'https://exp.host/--/api/v2/push/send'
        header-list.request  ~[['Content-Type' 'application/json']]
        body.request
      :-  ~
      %-  as-octt:mimes:html
      %-  en-json:html
      %-  pairs:enjs:format
      :~  to+s+p.val.data
          title+s+''
          body+s+''
          data+(frond 'ship' s+(scot %p our.bowl))
      ==
    ==
    [~[[%pass /push-notification/(scot %da now.bowl) %arvo %i %request request *outbound-config:iris]] state]
  ==
::
++  contents-to-cord
  |=  contents=(list content:ha)
  ^-  @t
  %+  rap  3
  %+  turn  contents
  |=  c=content:ha
  ^-  @t
  ?@  c  c
  ?-  -.c
    %ship  (scot %p p.c)
    %emph  p.c
  ==
--