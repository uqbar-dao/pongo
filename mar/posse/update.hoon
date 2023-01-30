/-  *posse
=,  enjs:format
::
|_  upd=update
++  grab
  |%
  ++  noun  update
  --
::
++  grow
  |%
  ++  noun  upd
  ++  json
    |=  upd=update
    ^-  ^json
    ?-    -.upd
        %details
      %+  frond  'details'
      %-  pairs
      %+  turn  ~(tap by details.upd)
      |=  [label=@t content=@t]
      [label s+content]
    ::
        %tag
      %+  frond  'tag'
      :-  %a
      %+  turn  ~(tap in +.upd)
      |=  p=@p
      (ship p)
    ==
  --
::
++  grad  %noun
--
