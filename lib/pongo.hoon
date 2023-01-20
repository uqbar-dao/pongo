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
++  make-reaction-hash
  |=  [=reaction on=message-id]
  ^-  @
  %-  sham
  ;:  (cury cat 3)
    'signed-pongo-react: '
    reaction
    'on message '
    (scot %ud on)
  ==
::
++  print-message
  |=  =message
  ^-  @t
  ?+    kind.message
      ;:  (cury cat 3)
        'Message from '
        (scot %p author.message)
        ': '
        content.message
      ==
  ::
      %member-add
    %^  cat  3
      content.message
    ' joined the conversation.'
  ::
      %member-remove
    %^  cat  3
      content.message
    ' left the conversation.'
  ::
      %change-name
    %^  cat  3
      'Conversation name changed to '
    (cat 3 content.message '.')
  ::
      %leader-add
    %^  cat  3
      content.message
    ' is now managing the conversation.'
  ::
      %leader-remove
    %^  cat  3
      content.message
    ' is no longer managing the conversation.'
  ==
--