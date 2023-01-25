|%
+$  tag  @t
::
+$  detail
  $:  nickname=(unit @t)
      name=(unit @t)
      email=(unit @t)
      phone=(unit @t)
      notes=(unit @t)
  ==
::
+$  action
  $%  [%add-tag who=@p =tag]
      [%del-tag who=@p =tag]
      [%edit-detail who=@p =detail]
  ==
--