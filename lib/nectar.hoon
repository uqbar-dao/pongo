/-  *nectar
/+  *mip
|%
::
::  helpers
::
++  make-schema
  |=  lis=(list [term column-type])
  ^-  schema
  (~(gas by *schema) lis)
::
++  make-indices
  |=  lis=(list key-type)
  ^-  indices
  %-  ~(gas by *indices)
  %+  turn  lis
  |=  =key-type
  [cols.key-type key-type]
::
::  database engine
::
++  database
  =>  |%
      +$  table-name  @
      +$  tables  (map table-name _tab)
      ::  stored procedures, computed views here
      --
  =|  =tables
  |%
  ++  add-table
    |=  [name=table-name =table]
    ?:  (~(has by tables) name)
      ~|("nectar: table with that id already exists" !!)
    =+  (~(create tab table) ~)
    +>.$(tables (~(put by tables) name -))
  ::
  ++  insert
    |=  [name=table-name rows=(list row)]
    =/  tab  (~(got by tables) name)
    (add-tab name (insert:tab rows update=%.n))
  ::
  ++  update
    |=  [name=table-name rows=(list row)]
    =/  tab  (~(got by tables) name)
    (add-tab name (insert:tab rows update=%.y))
  ::
  ++  delete
    |=  [name=table-name where=condition]
    =/  tab  (~(got by tables) name)
    =/  query-key  primary-key.table:tab
    (add-tab name (delete:tab query-key where))
  ::
  ++  rename
    !!  ::  TODO add to +tab
  ::
  ++  add-tab
    |=  [name=table-name tab=_tab]
    ::  asdf
    +>.$(tables (~(put by tables) name tab))
  ::
  ++  q
    |=  =query
    ^-  (list row)
    (get-rows:- +):(run-query query ~)
  ::
  ++  run-query
    |=  [=query query-cols=(list column-name)]
    ^-  [_tab (list column-name)]
    ::  here we make smart choices
    =/  [left-tab=_tab query-cols=(list column-name)]
      ?@  table.query
        [(~(got by tables) table.query) query-cols]
      $(query table.query)
    ?+    -.query  ~|("unsupported query!" !!)
        %select
      =?    query-cols
          ?=(~ query-cols)
        ::  not smart yet..
        primary-key.table:left-tab
      :-  (select:left-tab query-cols where.query)
      query-cols
    ::
        %project
      =?    query-cols
          ?=(~ query-cols)
        ::  not smart yet..
        primary-key.table:left-tab
      :-  (project:left-tab query-cols cols.query)
      query-cols
    ::
        %theta-join
      =?    query-cols
          ?=(~ query-cols)
        ::  not smart yet..
        primary-key.table:left-tab
      =/  right-tab=_tab
        ?@  with.query
          (~(got by tables) with.query)
        -:$(query with.query)
      =/  with=(pair schema (list row))
        :-  schema.table:right-tab
        (get-rows:right-tab primary-key.table:right-tab)
      =/  new-key=key-type
        :*  %+  weld
              %+  turn  primary-key.table:left-tab
              |=(name=term (cat 3 'l-' name))
            %+  turn  primary-key.table:right-tab
            |=(name=term (cat 3 'r-' name))
            %.y  ~  %.n  %.n  ::  important
        ==
      =.  left-tab  (cross:left-tab query-cols new-key with)
      :-  (select:left-tab cols.new-key where.query)
      cols.new-key
    ==
  --
::
::  table edit engine
::
++  tab
  =|  =table
  |%
  ++  col
    |%
    ++  ord
      |=  at-key=(list column-name)
      ^-  $-([key key] ?)
      ::  clustered indices must be keyed on single col
      =/  =column-name  (head at-key)
      =/  col=column-type
        (~(got by schema.table) column-name)
      |=  [a=key b=key]
      ?>  &(?=([p=@ ~] a) ?=([p=@ ~] b))
      ?+  typ.col  (lte i.a i.b)
        %rd  (lte:rd i.a i.b)
        %rh  (lte:rh i.a i.b)
        %rq  (lte:rq i.a i.b)
        %rs  (lte:rs i.a i.b)
        %s   !=(--1 (cmp:si i.a i.b))
        ?(%t %ta %tas)  (aor i.a i.b)
      ==
    --
  ::
  ++  create
    |=  rows=(list row)
    ::  ~&  >  "%nectar: making table"
    ::  ~>  %bout
    ::
    ::  build a new table
    ::  destroys any existing records
    ::
    ::  can only have 1 primary key, must be the indicated one
    ::
    ?>  .=  1
        %-  lent
        %+  skim  ~(tap by indices.table)
        |=  [(list term) key-type]
        primary
    ?>  &(primary unique):(~(got by indices.table) primary-key.table)
    ::
    ::  columns must be contiguous from 0
    ::  and have no overlap
    ::
    =/  col-list  ~(tap by schema.table)
    ?>  .=  (gulf 0 (dec (lent col-list)))
        %+  sort
          %+  turn  col-list
          |=  [term column-type]
          spot
        lth
    ::
    ::  clustered and/or autoincremented indices must have singular key column
    ::
    ?>  %-  ~(all by indices.table)
        |=  key-type
        ?.  |(clustered ?=(^ autoincrement))
          %.y
        =(1 (lent cols))
    ::
    ::  make a record for each key
    ::
    =.  records.table
      %-  ~(gas by *(map (list column-name) record))
      %+  turn  ~(tap by indices.table)
      |=  [name=(list column-name) key-type]
      =/  lis=(list [=key =row])
        %+  turn  rows
        |=  =row
        :_  row  ^-  key
        %+  turn  cols
        |=  col=term
        (snag spot:(~(got by schema.table) col) row)
      name^(list-to-record name lis)
    ::  return modified tab core
    +>.$
  ::
  ::  produces a list of rows from a record
  ::
  ++  get-rows
    |=  at-key=(list term)
    ^-  (list row)
    =?    at-key
        ?=(~ at-key)
      primary-key.table
    =/  rec=record  (~(got by records.table) at-key)
    ?:  ?=(%& -.rec)
      ~(val by p.rec)
    %-  zing
    %+  turn  ~(val by p.rec)
    |=  m=(tree [key row])
    ~(val by m)
  ::
  ++  record-to-list
    |=  rec=record
    ^-  (list [key row])
    ?:  ?=(%& -.rec)
      ~(tap by p.rec)
    %-  zing
    %+  turn  ~(tap by p.rec)
    |=  [k=key m=(tree [key row])]
    (turn ~(val by m) |=(v=row [k v]))
  ::
  ++  list-to-record
    |=  [at-key=(list term) lis=(list [=key =row])]
    ^-  record
    =/  =key-type
      ?~  at-key
        (~(got by indices.table) primary-key.table)
      (~(got by indices.table) at-key)
    ?:  unique.key-type
      :-  %&
      ?.  clustered.key-type
        ::  map
        (~(gas by *(map key row)) lis)
      ::  mop
      =/  cmp  (ord:col at-key)
      %+  gas:((on key row) cmp)
      *((mop key row) cmp)  lis
    :-  %|
    =/  spots=(list @)
      %+  turn  primary-key.table
      |=  col=term
      spot:(~(got by schema.table) col)
    ?.  clustered.key-type
      ::  mip
      =/  mi   *(mip key key row)
      |-
      ?~  lis  mi
      =/  pri=key
        %+  turn  spots
        |=(i=@ (snag i row.i.lis))
      $(lis t.lis, mi (~(put bi mi) key.i.lis pri row.i.lis))
    ::  mop-map
    =/  cmp  (ord:col at-key)
    =/  mm  ((on key (map key row)) cmp)
    =/  mop-map  *((mop key (map key row)) cmp)
    |-
    ?~  lis  mop-map
    =/  pri=key
      %+  turn  spots
      |=(i=@ (snag i row.i.lis))
    %=    $
        lis  t.lis
        mop-map
      %^  put:mm  mop-map  key.i.lis
      =+  (get:mm mop-map key.i.lis)
      (~(put by (fall - ~)) pri row.i.lis)
    ==
  ::
  ::
  ::  select using a condition
  ::  accepts a key as hint towards which index to use
  ::  produces this core with only the hinted index modified
  ::
  ++  select
    |=  [at-key=(list term) where=condition]
    ::  ~&  >  "%nectar: performing select"
    ::  ~>  %bout
    =?    at-key
        ?=(~ at-key)
      primary-key.table
    =/  rec=record  (~(got by records.table) at-key)
    =/  =key-type   (~(got by indices.table) at-key)
    ::  if we have a keyed record for our selector,
    ::  we can use map operations directly
    =-  +>.$(records.table (~(put by records.table) at-key -))
    |-
    ^-  record
    ?-    -.where
        %s
      ::  single: apply selector on that col
      =/  c  (~(got by schema.table) c.where)
      =/  lis
        |.
        =/  listed  (record-to-list rec)
        =/  skimmed=(list [=key =row])
          %+  skim  listed
          |=  [=key =row]
          (apply-selector s.where (snag spot.c row))
        (list-to-record at-key skimmed)
      ::  if that col is key:
      ::    - %eq we can just get from map
      ::    - %not we can del from map
      ::    if record is clustered:
      ::      - %gte, %lte, %gth, %lth
      ::        can be lotted from mop
      ?.  =(~[c.where] at-key)  (lis)
      ?.  clustered.key-type
        ?.  ?=(%& -.s.where)  (lis)
        ?+    -.p.s.where
            (lis)
        ::
            %eq
          ?:  ?=(%& -.rec)
            ::  map
            ?~  res=(~(get by p.rec) ~[+.p.s.where])
              %&^~
            %&^[[~[+.p.s.where] u.res] ~ ~]
          ::  mip -- retain structure
          %|^[[~[+.p.s.where] (~(gut by p.rec) ~[+.p.s.where] ~)] ~ ~]
        ::
            %not
          ?:  ?=(%& -.rec)
            ::  map
            %&^(~(del by `(map key row)`p.rec) ~[+.p.s.where])
          ::  mip -- but unique key, can del whole inner
          %|^(~(del by `(map key (map key row))`p.rec) ~[+.p.s.where])
        ==
      =/  cmp  (ord:col at-key)
      ?.  ?=(%& -.s.where)  (lis)
      ?+    -.p.s.where
          (lis)
      ::
          %eq
        ?:  ?=(%& -.rec)
          ::  mop
          =/  m  ((on key row) cmp)
          ?~  res=(get:m p.rec ~[+.p.s.where])
            %&^~
          %&^[[~[+.p.s.where] u.res] ~ ~]
        ::  mop-map
        =/  mm  ((on key (map key row)) cmp)
        =+  (get:mm p.rec ~[+.p.s.where])
        %|^[[~[+.p.s.where] (fall - ~)] ~ ~]
      ::
          %not
        ?:  ?=(%& -.rec)
          ::  mop
          =/  m  ((on key row) cmp)
          %&^+:(del:m p.rec ~[+.p.s.where])
        ::  mop-map
        =/  mm  ((on key (map key row)) cmp)
        %|^+:(del:mm p.rec ~[+.p.s.where])
      ::
          ?(%gte %lte %gth %lth)
        ::  mop lot
        ::  mop ordered small -> large
        =/  lot-params
          ?-  -.p.s.where
            %gte  [`~[(dec +.p.s.where)] ~]
            %gth  [`~[+.p.s.where] ~]
            %lte  [~ `~[+(+.p.s.where)]]
            %lth  [~ `~[+.p.s.where]]
          ==
        ?:  ?=(%& -.rec)
          ::  mop
          =/  m   ((on key row) cmp)
          %&^(lot:m p.rec lot-params)
        ::  mop-map
        =/  mm  ((on key (map key row)) cmp)
        %|^(lot:mm p.rec lot-params)
      ::
          %top
        ::  get top n items in clustered index
        ?:  ?=(%& -.rec)
          ::  mop
          =/  m   ((on key row) cmp)
          =+  i=0
          =|  res=(list [key row])
          |-
          ?:  |((gth i n.p.s.where) =(~ p.rec))
            %&^(gas:m *((mop key row) cmp) res)
          =+  pried=(pry:m p.rec)
          $(i +(i), res [+.pried res], p.rec -.pried)
        ::  mop-map
        !!
      ::
          %bottom
        ::  get bottom n items in clustered index
        ?:  ?=(%& -.rec)
          ::  mop
          =/  m   ((on key row) cmp)
          =+  i=0
          =|  res=(list [key row])
          |-
          ?:  |((gth i n.p.s.where) =(~ p.rec))
            %&^(gas:m *((mop key row) cmp) res)
          =+  rammed=(ram:m p.rec)
          $(i +(i), res [+.rammed res], p.rec -.rammed)
        ::  mop-map
        !!
      ==
    ::
        %d
      ::  dual: apply comparator across two cols
      ::  if both cols are keys, can fix one and
      ::  then transform comparator into selector
      ::  such that we get to use map operations
      ::  all the way. (TODO implement)
      ::
      ::  if one or both cols is *not* a key, need
      ::  to traverse all rows.
      =/  c1  (~(got by schema.table) c1.where)
      =/  c2  (~(got by schema.table) c2.where)
      =/  listed  (record-to-list rec)
      =/  skimmed=(list [=key =row])
        %+  skim  listed
        |=  [=key =row]
        %^  apply-comparator  c.where
        (snag spot.c1 row)  (snag spot.c2 row)
      (list-to-record at-key skimmed)
    ::
        %n
      ::  no where clause means get everything
      rec
    ::
        %or
      ::  both clauses applied to full record
      =/  rec1=record  $(where a.where)
      =/  rec2=record  $(where b.where)
      ::  merge two results
      ::  records will share clustered/unique status
      ?.  clustered.key-type
        ?:  ?=(%& -.rec1)
          ?>  ?=(%& -.rec2)
          ::  map
          %&^(~(uni by p.rec1) p.rec2)
        ?>  ?=(%| -.rec2)
        ::  mip  TODO
        ::  %|^(uni-mip p.rec1 p.rec2)
        !!
      =/  cmp  (ord:col at-key)
      ?:  ?=(%& -.rec1)
        ?>  ?=(%& -.rec2)
        ::  mop
        =/  m  ((on key row) cmp)
        %&^(uni:m p.rec1 p.rec2)
      ?>  ?=(%| -.rec2)
      ::  mop-map  TODO
      ::  %|^(uni-mop-map p.rec1 p.rec2 cmp)
      !!
    ::
        %and
      ::  clauses applied sequentially to one record
      =.  rec  $(where a.where)
      $(where b.where)
    ==
  ::
  ::  produces a new table with rows inserted across all records
  ::
  ++  insert
    |=  [rows=(list row) update=?]
    ::  ~&  >  "%nectar: performing insert/update"
    ::  ~>  %bout
    =.  records.table
      %-  ~(rut by records.table)
      |=  [name=(list term) =record]
      =/  =key-type  (~(got by indices.table) name)
      =/  lis=(list [=key =row])
        %+  turn  rows
        |=  =row
        :_  row  ^-  key
        %+  turn  cols.key-type
        |=  col=term
        (snag spot:(~(got by schema.table) col) row)
      ?:  unique.key-type
        ?>  ?=(%& -.record)
        ?.  clustered.key-type
          ::  map
          |-
          ?~  lis  record
          ?:  (~(has by p.record) key.i.lis)
            ?.  update
              ~|("non-unique key on insert" !!)
            $(lis t.lis, p.record (~(put by p.record) i.lis))
          $(lis t.lis, p.record (~(put by p.record) i.lis))
        ::  mop
        ?>  ?=(%& -.record)
        =/  cmp  (ord:col name)
        =/  m    ((on key row) cmp)
        |-
        ?~  lis  record
        ~|  "non-unique key on insert"
        ?:  (has:m p.record key.i.lis)
          ?.  update
            ~|("non-unique key on insert" !!)
          $(lis t.lis, p.record (put:m p.record i.lis))
        $(lis t.lis, p.record (put:m p.record i.lis))
      ?>  ?=(%| -.record)
      ::  for non-unique records, primary key
      ::  uniqueness is enforced by inserting to
      ::  guaranteed-unique map/mop elsewhere
      =/  spots=(list @)
        %+  turn  primary-key.table
        |=  col=term
        spot:(~(got by schema.table) col)
      ?.  clustered.key-type
        ::  mip
        |-
        ?~  lis  record
        =/  pri=key
          %+  turn  spots
          |=(i=@ (snag i row.i.lis))
        $(lis t.lis, p.record (~(put bi p.record) key.i.lis pri row.i.lis))
      ::  mop-map
      =/  cmp  (ord:col name)
      =/  mm   ((on key (map key row)) cmp)
      |-
      ?~  lis  record
      =/  pri=key
        %+  turn  spots
        |=(i=@ (snag i row.i.lis))
      %=    $
          lis  t.lis
          p.record
        %^  put:mm  p.record  key.i.lis
        =+  (get:mm p.record key.i.lis)
        (~(put by (fall - ~)) pri row.i.lis)
      ==
    +>.$
  ::
  ::  produces a new table with rows meeting the condition
  ::  deleted across all records. after deleting records,
  ::  needs to rebuild all secondary indices, so deletes
  ::  take a pretty long time...  TODO optimize?
  ::
  ++  delete
    |=  [at-key=(list term) where=condition]
    ::  ~&  >  "%nectar: performing delete"
    ::  ~>  %bout
    =?    at-key
        ?=(~ at-key)
      primary-key.table
    =/  =key-type  (~(got by indices.table) at-key)
    =/  rec        (~(got by records.table) at-key)
    ?.  clustered.key-type
      =/  del  (~(got by records.table:(select at-key where)) at-key)
      ?:  ?=(%& -.rec)
        ?>  ?=(%& -.del)
        ::  map
        (create ~(val by (~(dif by p.rec) p.del)))
      ?>  ?=(%| -.del)
      ::  jar
      ::  %|^(dif-jar p.rec p.del)
      !!
    ::  for mop, rather than defer to select,
    ::  need to perform logical comparison by key and delete
    ::  or if an un-indexed column, must skim list
    ::  TODO implement key optimization
    =/  listed  (record-to-list rec)
    =/  skipped=(list row)
      %+  murn  listed
      |=  [=key =row]
      ?:  (apply-condition schema.table where row)
        ~
      `row
    (create skipped)
  ::
  ::  produces a list of rows along with a schema for interpreting
  ::  those rows, since projection creates a new row-ordering
  ::
  ++  project
    |=  [at-key=(list term) cols=(list term)]
    ::  ~&  >  "%nectar: performing projection"
    ::  ~>  %bout
    ::  need to iterate through all rows, so no need
    ::  to determine optimal record to pull from?
    =/  new-schema
      %-  ~(gas by *(map term column-type))
      =<  p
      %^  spin  cols  0
      |=  [=term i=@]
      =/  col  (~(got by schema.table) term)
      [[term col(spot i)] +(i)]
    ~|  "primary key columns must be retained in projection"
    ?>  %+  levy  primary-key.table
        |=  col=term
        (~(has by new-schema) col)
    =/  is=(list @)
      %+  turn  cols
      |=  =term
      spot:(~(got by schema.table) term)
    =/  lis=(list [key row])
      %+  turn
        (record-to-list (~(got by records.table) at-key))
      |=  [=key =row]
      :-  key
      %+  turn  is
      |=(i=@ (snag i row))
    =.  schema.table  new-schema
    =.  records.table
      [at-key^(list-to-record at-key lis) ~ ~]
    +>.$
  ::
  ::  cross-product: combinatorily join two records
  ::  places the result as a record -- you choose the key
  ::
  ++  cross
    |=  [at-key=(list term) new-key=key-type with=(pair schema (list row))]
    ::  ~&  >  "%nectar: performing cross-product"
    ::  ~>  %bout
    =/  l  ~(wyt by schema.table)
    =.  schema.table
      %-  ~(gas by *(map term column-type))
      %+  weld
        %+  turn  ~(tap by schema.table)
        |=  [=term c=column-type]
        [(cat 3 'l-' term) c]
      %+  turn  ~(tap by p.with)
      |=  [=term c=column-type]
      [(cat 3 'r-' term) c(spot (add spot.c l))]
    =/  lis=(list [key row])
      %-  zing
      %+  turn  (get-rows at-key)
      |=  l=row
      %+  turn  q.with
      |=  r=row
      =/  grow=row  (weld l r)
      :_  grow  ^-  key
      %+  turn  cols.new-key
      |=  col=column-name
      (snag spot:(~(got by schema.table) col) grow)
    =.  indices.table
      [cols.new-key^new-key ~ ~]
    =.  primary-key.table  cols.new-key
    =.  records.table
      [cols.new-key^(list-to-record cols.new-key lis) ~ ~]
    +>.$
  ::
  ::  union: concatenate two records
  ::
  ++  union
    |=  [at-key=(list term) with=(pair schema (list row))]
    ::  ~&  >  "%nectar: performing union"
    ::  ~>  %bout
    ^-  (pair schema (list row))
    =/  l  ~(wyt by schema.table)
    ::  unlike cross-product, if two columns in schemae
    ::  share the same name, they become the same column
    ::  TODO adjust to get correct spot values
    :-  %-  (~(uno by schema.table) p.with)
        |=  [term c1=column-type c2=column-type]
        ::  if overlap, take type from our table
        [0 |(optional.c1 optional.c2) typ.c1]
    ::  TODO pad rows to get proper alignment
    %+  weld
      (get-rows at-key)
    q.with
  --
::
++  apply-condition
  |=  [=schema cond=condition =row]
  ^-  ?
  ?-    -.cond
    %n  %.y
  ::
      %s
    =-  (apply-selector s.cond -)
    (snag spot:(~(got by schema) c.cond) row)
  ::
      %d
    =-  (apply-comparator c.cond -)
    :-  (snag spot:(~(got by schema) c1.cond) row)
    (snag spot:(~(got by schema) c2.cond) row)
  ::
      %and
    ?:  $(cond a.cond)
      $(cond b.cond)
    %.n
  ::
      %or
    |($(cond a.cond) $(cond b.cond))
  ==
::
++  apply-selector
  |=  [=selector a=value]
  ^-  ?
  ?.  ?=(%& -.selector)
    (p.selector a)
  ?>  ?=(@ a)
  ?-  -.p.selector
    %eq    =(a +.p.selector)
    %not   !=(a +.p.selector)
    %gte   (gte a +.p.selector)
    %lte   (lte a +.p.selector)
    %gth   (gth a +.p.selector)
    %lth   (lth a +.p.selector)
    %nul   =(~ a)
    ?(%top %bottom)  ~|("%nectar: applied invalid selector" !!)
  ==
::
++  apply-comparator
  |=  [=comparator a=value b=value]
  ^-  ?
  ?.  ?=(%& -.comparator)
    (p.comparator a b)
  ?>  &(?=(@ a) ?=(@ b))
  ?-  p.comparator
    %eq    =(a b)
    %not   !=(a b)
    %gte   (gte a b)
    %lte   (lte a b)
    %gth   (gth a b)
    %lth   (lth a b)
  ==
::
::  missing jar utils
::
++  tap-jar
  |=  j=(tree [key (list row)])
  ^-  (list [key row])
  %-  zing
  %+  turn  ~(tap by j)
  |=  [k=key l=(list row)]
  (turn l |=(r=row [k r]))
::
++  uni-jar
  |=  [a=(tree [=key rows=(list row)]) b=(tree [=key rows=(list row)])]
  ^+  a
  ?~  b  a
  ?~  a  b
  ?:  =(key.n.a key.n.b)
    ::  if keys match, instead of overriding item in a,
    ::  weld together two lists and remove duplicates
    ::  this is likely very slow. so, simply don't make
    ::  %or queries that overlap!
    :_  [l=$(a l.a, b l.b) r=$(a r.a, b r.b)]
    n=[key.n.a ~(tap in (silt (weld rows.n.a rows.n.b)))]
  ?:  (mor key.n.a key.n.b)
    ?:  (gor key.n.b key.n.a)
      $(l.a $(a l.a, r.b ~), b r.b)
    $(r.a $(a r.a, l.b ~), b l.b)
  ?:  (gor key.n.a key.n.b)
    $(l.b $(b l.b, r.a ~), a r.a)
  $(r.b $(b r.b, l.a ~), a l.a)
::
::  mop-jar utils
::
++  uni-mop-jar
  |=  $:  a=(tree [=key rows=(list row)])
          b=(tree [=key rows=(list row)])
          cmp=$-([key key] ?)
      ==
  ^+  a
  ?~  b  a
  ?~  a  b
  ?:  =(key.n.a key.n.b)
    :_  [l=$(a l.a, b l.b) r=$(a r.a, b r.b)]
    n=[key.n.a ~(tap in (silt (weld rows.n.a rows.n.b)))]
  ?:  (mor key.n.a key.n.b)
    ?:  (cmp key.n.b key.n.a)
      $(l.a $(a l.a, r.b ~), b r.b)
    $(r.a $(a r.a, l.b ~), b l.b)
  ?:  (cmp key.n.a key.n.b)
    $(l.b $(b l.b, r.a ~), a r.a)
  $(r.b $(b r.b, l.a ~), a l.a)
--