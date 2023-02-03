/-  *handshake
=,  enjs:format
|_  upd=reader-update
++  grab
  |%
  ++  noun  reader-update
  --
++  grow
  |%
  ++  noun  upd
  ++  json
    ?-  -.upd
      %bad-sig      ~
      %expired-sig  (who who.upd)
      %good-sig     (who who.upd)
    ==
  ++  who
    |=  s=@p
    (frond ['who' [%s (scot %p s)]])
  --
++  grad  %noun
--
