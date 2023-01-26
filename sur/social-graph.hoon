|%
+$  app   term        ::  TODO: is this enough??
+$  tag   ?(@t path)  ::  fully qualified scry path
::
+$  node
  $%  [%ship @p]
      [%address @ux]
      [%entity term]    ::  TODO
  ==
::
+$  edge     (jug app tag)
+$  nodeset  (jug node node)
::
::  permissions are app-level: the app uses %set-perms to say whether
::  - %private: only our ship can track tags in our app's graph
::  - %public: anyone can track tags in our app's graph
::  - %only-tagged: only ships that *have* the tag can track it.
::
+$  permission-level
  $~  %private
  ?(%private %public %only-tagged)
::
::  !! need USERSPACE PERMS to make this right !!
::
+$  edit
  %+  pair  term  ::  the app poking us, for now -- not used for start/stop tracking
  $%  [%add-tag =tag from=node to=node]
      [%del-tag =tag from=node to=node]
      [%nuke-tag =tag]
      ::  if not set, defaults to %private
      [%set-perms level=permission-level]
      ::  sync a tag from someone else
      [%start-tracking source=@p =app =tag]
      [%stop-tracking source=@p =app =tag]
  ==
::
::  poke with this to indicate that you want to get pushed updates
::
+$  track
  %+  pair  term  ::  the app poking us, for now
  $%  [%fetch =app =tag]  ::  retrieve current state of graph (use scry instead)
      [%track =app =tag]  ::  sign up to get poked updates
      [%leave =app =tag]  ::  stop getting poked updates
  ==
::
+$  update
  %+  pair  [=app =tag]
  $%  [%all =nodeset]                ::  from a %fetch
      [%new-tag from=node to=node]   ::  from a %track poke
      [%gone-tag from=node to=node]  ::  from a %track poke
  ==
::
+$  graph-result  ::  comes out of scries
  $%  [%controller @p]
      [%nodes (set node)]
      [%edge (unit edge)]
  ==
--
