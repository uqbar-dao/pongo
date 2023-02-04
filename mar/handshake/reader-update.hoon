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
      %expired-sig  (frond ['expired_sig' [%s (scot %p s)]])
      %good-sig     (frond ['good_sig' [%s (scot %p s)]])
    ==
  --
++  grad  %noun
--
