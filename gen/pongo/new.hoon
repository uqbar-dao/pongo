:-  %say
|=  [[now=@da eny=@uvJ bek=beak] [name=@t members=(list @p) ~] ~]
:-  %pongo-action
=.  members
  ?~  found=(find ~[p.bek] members)
    members
  (oust [u.found 1] members)
?:  (lth (lent members) 2)
  [%make-conversation name [%dm (silt members) ~]]
[%make-conversation name [%open (silt members) ~]]
