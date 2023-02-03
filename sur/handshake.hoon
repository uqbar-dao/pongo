|%
++  expiration  ~m5
+$  signature   [p=@ux q=ship r=life]
+$  punch       [time=@ p=@ux r=life]
::
+$  action
  $%  [%create ~]
      [%verify code=@]
  ==
::
+$  signer-update
  $%  [%new-sig code=@ expires-at=time]
  ==
::
+$  reader-update
  $%  [%bad-sig ~]
      [%expired-sig who=ship]
      [%good-sig who=ship]
  ==
--
