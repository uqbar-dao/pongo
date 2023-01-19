/-  *pongo
/+  sig
|%
++  make-message-hash
  |=  [content=@t now=@da]
  ^-  @
  %-  sham
  ;:  (cury cat 3)
    'signed-pongo-message: '
    content
    ' at '
    (scot %da now)
  ==
::
++  print-message
  |=  =message
  ^-  @t
  ;:  (cury cat 3)
    'Message from '
    (scot %p author.message)
    ': '
    content.message
  ==
--