::  miasma:
::     relational
::            database
::
|%
::  TODO:  external indices
::  make index a separate object from table
::  store them alongside tables
::  be able to store indices for *other* tables
::  (do after solid-state-publications)
::  (use: find another table somewhere)
::
+$  table
  $:  =schema
      primary-key=(list column-name)
      =indices
      records=(map (list column-name) record)
  ==
::
+$  schema   (map term column-type)  ::  term is semantic label
+$  indices  (map (list column-name) key-type)
::
+$  key-type
  $:  cols=(list column-name)  ::  which columns included in key (at list position)
      primary=?                ::  only one primary key per table (must be unique!)
      unique=?                 ::  if not unique, store rows in list under key
      clustered=?              ::  uses col-ord -- if clustered,
  ==                           ::  must be *singular* column in key.
::
+$  column-name  term
+$  column-type
  $:  spot=@      ::  where column sits in row
      optional=?  ::  if optional, value is unit
      $=  typ
      $?  %ud  %ux  %da  %f  %p
          %t   %ta  %tas
          %rd  %rh  %rq  %rs  %s
          ::  more complex column types
          %list  %set  %map  %blob
      ==
  ==
::
+$  record
  %+  each
    (tree [key row])             ::  unique key
  (tree [key (tree [key row])])  ::  non-unique key
::
+$  key  (list value)
+$  row  (list value)
+$  value
  $@  @
  $?  (unit @)
  $%  [%l (list value)]       [%s (set value)]
      [%m (map value value)]  [%b *]
  ==  ==
::
+$  condition
  $~  [%n ~]
  $%  [%n ~]
      [%s c=term s=selector]
      [%d c1=term c=comparator c2=term]
      [%and a=condition b=condition]
      [%or a=condition b=condition]
  ==
::
+$  selector
  ::  concrete or dynamic
  %+  each
    $%  [%eq @]   [%not @]
        [%gte @]  [%lte @]
        [%gth @]  [%lth @]
        [%nul ~]
    ==
  $-(value ?)
::
+$  comparator
  ::  concrete or dynamic
  %+  each
    ?(%eq %not %gte %gth %lte %lth)
  $-([value value] ?)
::
+$  query
  $%  [%select table=?(term query) where=condition]
      [%project table=?(term query) cols=(list term)]
      [%theta-join table=?(term query) with=?(term query) where=condition]
      [%table table=term ~]  ::  to avoid type-loop
  ==
--