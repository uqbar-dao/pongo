|%
+$  tag  @t
::
+$  details  (map @t @t)
::
+$  action
  $%  [%add-tag who=@p =tag]
      [%del-tag who=@p =tag]
      [%edit-details who=@p =details]
      ::  sync our graph with that of controller
      [%join-posse controller=@p =tag]
  ==
::
+$  update
  $%  [%details =details]
      [%tag (set @p)]
  ==
--