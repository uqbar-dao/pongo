::  ::                                         ::::::    ::::::    ::    ::::::
::  ::  smart.hoon: contract standard library  ::  ::    ::  ::  ::  ::  ::  ::
::  ::                                         ::  ::    ::::    ::::::  ::::
::  ::                                         ::  ::    ::  ::  ::  ::  ::  ::
::  ::  five: contract functions               ::  ::    ::  ::  ::  ::  ::  ::
::::::                                         ::::  ::  ::::::  ::  ::  ::  ::
=<
|%
::  merkle engine for chain-state
::  NEVER use this outside of a contract, it's "unjetted"
::  instead, use lib/merk.hoon
++  big  (bi id item)
::
::  +husk: check provenance and fit data to mold
::
::  this arm takes in an item, a mold, and optional source and holder
::  metadata. if source or holder given, the data is asserted to have
::  that property. the item is also asserted to *be* data, and we
::  return the data with the noun inside asserted into the mold given.
::
++  husk
  |*  [typ=mold =item source=(unit address) holder=(unit address)]
  ?>  ?&  ?~(source %.y =(source.p.item u.source))
          ?~(holder %.y =(holder.p.item u.holder))
          ?=(%& -.item)
      ==
  p.item(noun ;;(typ noun.p.item))
::
::  scry wrappers
::  +scry-state is used to grab an item from chain state
::  +scry-contract is used to call a contract's +read arm (for nouns)
::
++  scry-state
  |=  =id
  ;;  (unit item)
  .*  0
  [%12 [%0 1] [%1 `pith`[%state [%ux id] ~]]]
::
++  scry-contract
  |=  [=id pit=pith]
  ;;  (unit *)
  .*  0
  [%12 [%0 1] [%1 `pith`[%contract [%ux id] pit]]]
::
::  +hash-pact, +hash-data: standard hashing functions for items
::
++  hash-pact
  |=  [source=id holder=id town=id code=*]
  ^-  id
  ^-  @ux  %-  shag
  :((cury cat 3) town source holder (sham code))
::
++  hash-data
  |=  [source=id holder=id town=id salt=@]
  ^-  id
  ^-  @ux  %-  shag
  :((cury cat 3) town source holder salt)
::
::  +result: generate a diff
::
++  result
  |=  [changed=(list item) issued=(list item) burned=(list item) =events]
  ^-  diff
  :^    (gas:big *(merk id item) (turn changed |=(=item [id.p.item item])))
      (gas:big *(merk id item) (turn issued |=(=item [id.p.item item])))
    (gas:big *(merk id item) (turn burned |=(=item [id.p.item item])))
  events
--  =<
::  ::
::  ::  four: contract types
::::::
|%
+$  id       @ux            ::  hash pointing to some item
+$  address  @ux            ::  42-char hex address, ETH compatible
+$  sig      [v=@ r=@ s=@]  ::  ETH compatible ECDSA signature
::
::  hardcoded "native" token contract
++  zigs-contract-id  `@ux`'zigs-contract'
::  hardcoded contract for ETH deposited on Uqbar
++  ueth-contract-id  `@ux`'ueth-contract'
::
::  items populate the state.
::
::  they can only be modified by their source, which must be
::  a contract. the role of a holder is determined by the
::  specific rules of the contract, usually implying some
::  form of ownership.
::
::  an item holds either some data or a contract.
::
+$  item  (each data pact)
::
::  each piece of data includes a contract-defined salt and label
::  salt is for hashing, to be combined with source/holder/town for
::  a unique rice ID without needing to jam data. label matches
::  types defined in pact and allows apps to find a type
::  representation for the contained data.
::
+$  data
  $:  =id  source=id  holder=id  town=id
      salt=@  label=@tas
      noun=*
  ==
::
+$  pact
  $:  =id  source=id  holder=id  town=id
      code=[bat=* pay=*]
      ::  pith with last value equal to +sham of compiled core
      ::  if ~, developer did not provide an interface
      interface=pith
  ==
::
::  context: state context fed into contract
::
+$  context
  $:  this=id                 ::  ID of current contract
      caller=[=id nonce=@ud]  ::  information about caller
      batch=@ud
      eth-block=@ud
      town=id
  ==
::
::  smart contract definition
::
+$  contract
  $_  ^|
  |_  context
  ++  write
    |~  *
    (quip call diff)
  ::
  ++  read
    |~  pith
    *
  --
::
::  contract output types
::
+$  diff
  $:  changed=(merk id item)
      issued=(merk id item)
      burned=(merk id item)
      =events
  ==
+$  call  [contract=id town=id =calldata]
+$  event   (pair @tas *)
+$  events  (list event)
::
::  transaction types
::
+$  transaction  [=sig =calldata shell]
+$  caller  [=address nonce=@ud zigs=id]
+$  calldata  (pair @tas *)
+$  shell
  $:  =caller  ::  contains address, nonce, and zigs account
      eth-hash=(unit @)  ::  if signed with eth wallet, use verify signature
      contract=id
      gas=[rate=@ud bud=@ud]
      town=id
      status=@ud  ::  error code
  ==
::
::  transaction error codes
::
+$  errorcode
  $?  %0  ::  0: successfully performed
      %1  ::  1: bad signature
      %2  ::  2: incorrect nonce
      %3  ::  3: lack zigs to fulfill budget
      %4  ::  4: couldn't find contract
      %5  ::  5: data was under contract ID
      %6  ::  6: crash in contract execution
      %7  ::  7: validation of diff failed
      %8  ::  8: ran out of gas while executing
      %9  ::  9: dedicated burn/withdraw transaction failed
  ==
::
::  EIP-712 mold for offchain data signing
::  :domain pact that this message will modify
::  :type is the +shag of the message type jold
::  :message the noun being signed
+$  typed-message  [domain=id type=@ux message=*]
::
++  recover
  |=  [=typed-message =sig]
  ^-  id
  %-  address-from-pub
  %-  serialize-point:secp256k1:secp:crypto
  (ecdsa-raw-recover:secp256k1:secp:crypto (shag typed-message) sig)
::
::  typed paths inside contracts
::  taken from: https://github.com/urbit/urbit/pull/5887
::  can live here temporarily until these types/parsers
::  are merged into hoon.hoon
::
+$  pith  (list iota)                                  ::  typed urbit path
::                                                     ::
+$  iota                                               ::  typed path segment
  $~  [%n ~]
  $@  @tas
  $%  [%ub @ub]  [%uc @uc]  [%ud @ud]  [%ui @ui]
      [%ux @ux]  [%uv @uv]  [%uw @uw]
      [%sb @sb]  [%sc @sc]  [%sd @sd]  [%si @si]
      [%sx @sx]  [%sv @sv]  [%sw @sw]
      [%da @da]  [%dr @dr]
      [%f ?]     [%n ~]
      [%if @if]  [%is @is]
      [%t @t]    [%ta @ta]  ::  @tas
      [%p @p]    [%q @q]
      [%rs @rs]  [%rd @rd]  [%rh @rh]  [%rq @rq]
  ==
::
++  pout
  |=  =pith
  ^-  path
  %+  turn  pith
  |=  i=iota
  ?@(i i (scot i))
--  =<
::  ::
::  ::  three: formatting (json from zuse/lull)
::::::
|%
::
::  JSONification
::  allows read arm of contracts to generate JSON
::
+$  ship  @p
+$  json                                               ::  normal json value
  $@  ~                                                ::  null
  $%  [%a p=(list json)]                               ::  array
      [%b p=?]                                         ::  boolean
      [%o p=(map @t json)]                             ::  object
      [%n p=@ta]                                       ::  number
      [%s p=@t]                                        ::  string
  ==
++  format  ^?
  |%
  ++  enjs  ^?                                         ::  json encoders
    |%
    ::                                                 ::  ++frond:enjs:format
    ++  frond                                          ::  object from k-v pair
      |=  [p=@t q=json]
      ^-  json
      [%o [[p q] ~ ~]]
    ::                                                 ::  ++pairs:enjs:format
    ++  pairs                                          ::  object from k-v list
      |=  a=(list [p=@t q=json])
      ^-  json
      [%o (~(gas by *(map @t json)) a)]
    ::                                                 ::  ++tape:enjs:format
    ++  tape                                           ::  string from tape
      |=  a=^tape
      ^-  json
      [%s (crip a)]
    ::                                                 ::  ++ship:enjs:format
    ++  ship                                           ::  string from ship
      |=  a=^ship
      ^-  json
      [%n (rap 3 '"' (rsh [3 1] (scot %p a)) '"' ~)]
    ::                                                 ::  ++numb:enjs:format
    ++  numb                                           ::  number from unsigned
      |=  a=@u
      ^-  json
      :-  %n
      ?:  =(0 a)  '0'
      %-  crip
      %-  flop
      |-  ^-  ^tape
      ?:(=(0 a) ~ [(add '0' (mod a 10)) $(a (div a 10))])
    ::                                                  ::  ++path:enjs:format
    ++  path                                            ::  string from path
      |=  a=^path
      ^-  json
      [%s (spat a)]
    ::                                                  ::  ++tank:enjs:format
    ++  tank                                            ::  tank as string arr
      |=  a=^tank
      ^-  json
      [%a (turn (wash [0 80] a) tape)]
    --
  --
--  =<
::  ::
::  ::  two: data structures
::::::
|%
+$  hash  @ux
::
++  make-pmap                                           ::  pmap from list
  |*  a=(list)
  (polt `(list [p=_-<.a q=_->.a])`a)
::
++  polt                                                ::  pmap from pair list
  |*  a=(list (pair))
  (~(gas py *(pmap _p.i.-.a _q.i.-.a)) a)
::
++  make-pset                                           ::  pset from list
  |*  a=(list)
  (~(gas pn *(pset _?>(?=(^ a) i.a))) a)
::
::  +merk: merkle tree
::
++  merk
  |$  [key value]                                       ::  table
  $|  (tree (pair key (pair hash value)))
  |=  a=(tree (pair key (pair hash value)))
  ?:(=(~ a) & (apt:(bi key value) a))
::
::  +shag: the standard noun hashing function for uqbar. uses a special
::  form of RLP-encoding to make items discoverable in the state tree
::
++  shag
  |=  yux=*
  ^-  hash
  %-  keccak-256:keccak:crypto
  ?@  yux
    [(met 3 yux) yux]
  =+  (encode:rlp p+yux)
  [(met 3 -) -]
::
::  +sore: single hash in ascending order, uses +dor as fallback
::
++  sore
  |=  [a=* b=*]
  ^-  ?
  =+  [c=(shag a) d=(shag b)]
  ?:  =(c d)
    (dor a b)
  (lth c d)
::
::  +sure: double hash in ascending order, uses +dor as fallback
::
++  sure
  |=  [a=* b=*]
  ^-  ?
  =+  [c=(shag (shag a)) d=(shag (shag b))]
  ?:  =(c d)
    (dor a b)
  (lth c d)
::
::  merkle tree engine
::
++  bi                                                  ::  merk engine
  |*  [kee=mold val=mold]
  =>  |%
      +$  mert  (tree (pair kee (pair hash val)))
      --
  |%
  ++  bif                                               ::  splits a by b
    |=  [a=mert b=kee c=val]
    ^+  [l=a r=a]
    =<  +
    |-  ^+  a
    ?~  a
      [[b (mer a b c) c] ~ ~]
    ?:  =(b p.n.a)
      ?:  =(c q.q.n.a)
        a
      a(n [b (mer a b c) c])
    ?:  (sore b p.n.a)
      =/  d  $(a l.a)
      ?>  ?=(^ d)
      d(r a(l r.d, p.q.n (mer a(l r.d) [p q.q]:n.a)))
    =/  d  $(a r.a)
    ?>  ?=(^ d)
    d(l a(r l.d, p.q.n (mer a(r l.d) [p q.q]:n.a)))
  ::
  ++  del                                               ::  delete at key b
    |=  [a=mert b=kee]
    |-  ^+  a
    ?~  a
      ~
    ?.  =(b p.n.a)
      ?:  (sore b p.n.a)
        =.  l.a  $(a l.a)
        a(n [p.n.a (mer a [p q.q]:n.a) q.q.n.a])
      =.  r.a  $(a r.a)
      a(n [p.n.a (mer a [p q.q]:n.a) q.q.n.a])
    |-  ^-  [$?(~ _a)]
    ?~  l.a  r.a
    ?~  r.a  l.a
    ?:  (sure p.n.l.a p.n.r.a)
      =.  r.l.a  $(l.a r.l.a)
      l.a(n [p.n.l.a (mer l.a [p q.q]:n.l.a) q.q.n.l.a])
    =.  l.r.a  $(r.a l.r.a)
    r.a(n [p.n.r.a (mer r.a [p q.q]:n.r.a) q.q.n.r.a])
  ::
  ++  dif                                               ::  difference
    |=  [a=mert b=mert]
    |-  ^+  a
    ?~  b
      a
    =/  c  (bif a p.n.b q.q.n.b)
    ?>  ?=(^ c)
    =/  d  $(a l.c, b l.b)
    =/  e  $(a r.c, b r.b)
    |-  ^-  [$?(~ _a)]
    ?~  d  e
    ?~  e  d
    ?:  (sure p.n.d p.n.e)
      =/  dr  $(d r.d)
      d(r dr, p.q.n (mer d(r dr) [p q.q]:n.d))
    =/  el  $(e l.e)
    e(l el, p.q.n (mer e(l el) [p q.q]:n.e))
  ::
  ++  apt                                               ::  check correctness
    |=  a=mert
    =|  [l=(unit) r=(unit)]
    |-  ^-  ?
    ?~  a   &
    ?&  ?~(l & &((sore p.n.a u.l) !=(p.n.a u.l)))
        ?~(r & &((sore u.r p.n.a) !=(u.r p.n.a)))
        ?~  l.a   &
        &((sure p.n.a p.n.l.a) !=(p.n.a p.n.l.a) $(a l.a, l `p.n.a))
        ?~  r.a   &
        &((sure p.n.a p.n.r.a) !=(p.n.a p.n.r.a) $(a r.a, r `p.n.a))
        =(p.q.n.a (mer a [p q.q]:n.a))
    ==
  ::
  ++  gas                                               ::  concatenate
    |=  [a=mert b=(list [p=kee q=val])]
    ^+  a
    ?~  b  a
    $(b t.b, a (put a i.b))
  ::
  ++  get                                               ::  grab value by key
    |=  [a=mert b=kee]
    ^-  (unit val)
    ?~  a
      ~
    ?:  =(b p.n.a)
      (some q.q.n.a)
    ?:  (sore b p.n.a)
      $(a l.a)
    $(a r.a)
  ::
  ++  got                                               ::  need value by key
    |=  [a=mert b=kee]
    ^-  val
    (need (get a b))
  ::
  ++  gut                                               ::  fall value by key
    |=  [a=mert b=kee c=val]
    ^-  val
    (fall (get a b) c)
  ::
  ++  has                                               ::  key existence check
    |=  [a=mert b=kee]
    !=(~ (get a b))
  ::
  ++  int                                               ::  intersection
    |=  [a=mert b=mert]
    ^+  a
    ?~  b
      ~
    ?~  a
      ~
    ?:  (sure p.n.a p.n.b)
      ?:  =(p.n.b p.n.a)
        =:  l.b  $(a l.a, b l.b)
            r.b  $(a r.a, b r.b)
          ==
        b(p.q.n (mer b [p q.q]:n.b))
      ?:  (sore p.n.b p.n.a)
        %+  uni
          $(a l.a, r.b ~, p.q.n.b (mer b(r ~) [p q.q]:n.b))
        $(b r.b)
      %+  uni
        $(a r.a, l.b ~, p.q.n.b (mer b(l ~) [p q.q]:n.b))
      $(b l.b)
    ?:  =(p.n.a p.n.b)
      =:  l.b  $(a l.a, b l.b)
          r.b  $(a r.a, b r.b)
        ==
      b(p.q.n (mer b [p q.q]:n.b))
    ?:  (sore p.n.a p.n.b)
      %+  uni
        $(b l.b, r.a ~, p.q.n.a (mer a(r ~) [p q.q]:n.a))
      $(a r.a)
    %+  uni
      $(b r.b, l.a ~, p.q.n.a (mer a(l ~) [p q.q]:n.a))
    $(a l.a)
  ::
  ++  mek                                              ::  merkle hashes for key
    |=  [a=mert b=kee]
    ^-  (list hash)
    =|  =(list hash)
    |-
    ?~  a
      ~
    ?:  =(b p.n.a)
      (flop [p.q.n.a list])
    ?:  (sore b p.n.a)
      $(a l.a, list [p.q.n.a list])
    $(a r.a, list [p.q.n.a list])
  ::
  ++  mer                                               ::  generate merkle hash
    |=  [a=mert b=(pair kee val)]
    ^-  hash
    ?~  a  (shag [b ~ ~])
    %-  shag
    :+  b
      ?~(l.a ~ p.q.n.l.a)
    ?~(r.a ~ p.q.n.r.a)
  ::
  ++  put                                               ::  adds key-value pair
    |=  [a=mert b=kee c=val]
    ^+  a
    ?~  a
      [[b (mer a b c) c] ~ ~]
    ?:  =(b p.n.a)
      ?:  =(c q.q.n.a)
        a
      a(n [b (mer a b c) c])
    ?:  (sore b p.n.a)
      =/  d  $(a l.a)
      ?>  ?=(^ d)
      =.  a
        ?:  (sure p.n.a p.n.d)
          a(l d)
        d(r a(l r.d, p.q.n (mer a(l r.d) [p q.q]:n.a)))
      a(p.q.n (mer a [p q.q]:n.a))
    =/  d  $(a r.a)
    ?>  ?=(^ d)
    =.  a
      ?:  (sure p.n.a p.n.d)
        a(r d)
      d(l a(r l.d, p.q.n (mer a(r l.d) [p q.q]:n.a)))
    a(p.q.n (mer a [p q.q]:n.a))
  ::
  ++  uni
    |=  [a=mert b=mert]
    ?:  =(a b)  a
    |-  ^+  a
    ?~  b
      a
    ?~  a
      b
    ?:  =(p.n.b p.n.a)
      =:  l.b  $(a l.a, b l.b)
          r.b  $(a r.a, b r.b)
        ==
      b(p.q.n (mer b [p q.q]:n.b))
    ?:  (sure p.n.a p.n.b)
      ?:  (sore p.n.b p.n.a)
        =.  l.a  $(a l.a, r.b ~, p.q.n.b (mer b(r ~) [p q.q]:n.b))
        $(b r.b, p.q.n.a (mer a [p q.q]:n.a))
      =.  r.a  $(a r.a, l.b ~, p.q.n.b (mer b(l ~) [p q.q]:n.b))
      $(b l.b, p.q.n.a (mer a [p q.q]:n.a))
    ?:  (sore p.n.a p.n.b)
      =.  l.b  $(b l.b, r.a ~, p.q.n.a (mer a(r ~) [p q.q]:n.a))
      $(a r.a, p.q.n.b (mer b [p q.q]:n.b))
    =.  r.b  $(b r.b, l.a ~, p.q.n.a (mer a(l ~) [p q.q]:n.a))
    $(a l.a, p.q.n.b (mer b [p q.q]:n.b))
  ::
  ++  key
    |=  [a=mert]
    ^-  (set kee)
    =|  b=(set kee)
    |-  ^+  b
    ?~  a  b
    $(a r.a, b $(a l.a, b (~(put in b) p.n.a)))
  --
::                                                      ::
::  set, but using shag hash                            ::
::  TODO jet                                            ::
::
++  pset
  |$  [item]
  $|  (tree item)
  |=(a=(tree) ?:(=(~ a) & ~(apt pn a)))
::
++  pn                                                  ::  shag-set engine
  =|  a=(tree)  :: (set)
  |@
  ++  all                                               ::  logical AND
    |*  b=$-(* ?)
    |-  ^-  ?
    ?~  a
      &
    ?&((b n.a) $(a l.a) $(a r.a))
  ::
  ++  any                                               ::  logical OR
    |*  b=$-(* ?)
    |-  ^-  ?
    ?~  a
      |
    ?|((b n.a) $(a l.a) $(a r.a))
  ::
  ++  apt                                               ::  check correctness
    =<  $
    =|  [l=(unit) r=(unit)]
    |.  ^-  ?
    ?~  a   &
    ?&  ?~(l & &((sore n.a u.l) !=(n.a u.l)))
        ?~(r & &((sore u.r n.a) !=(u.r n.a)))
        ?~(l.a & ?&((sure n.a n.l.a) !=(n.a n.l.a) $(a l.a, l `n.a)))
        ?~(r.a & ?&((sure n.a n.r.a) !=(n.a n.r.a) $(a r.a, r `n.a)))
    ==
  ::
  ++  bif                                               ::  splits a by b
    |*  b=*
    ^+  [l=a r=a]
    =<  +
    |-  ^+  a
    ?~  a
      [b ~ ~]
    ?:  =(b n.a)
      a
    ?:  (sore b n.a)
      =+  c=$(a l.a)
      ?>  ?=(^ c)
      c(r a(l r.c))
    =+  c=$(a r.a)
    ?>  ?=(^ c)
    c(l a(r l.c))
  ::
  ++  del                                               ::  b without any a
    |*  b=*
    |-  ^+  a
    ?~  a
      ~
    ?.  =(b n.a)
      ?:  (sore b n.a)
        a(l $(a l.a))
      a(r $(a r.a))
    |-  ^-  [$?(~ _a)]
    ?~  l.a  r.a
    ?~  r.a  l.a
    ?:  (sure n.l.a n.r.a)
      l.a(r $(l.a r.l.a))
    r.a(l $(r.a l.r.a))
  ::
  ++  dif                                               ::  difference
    =+  b=a
    |@
    ++  $
      |-  ^+  a
      ?~  b
        a
      =+  c=(bif n.b)
      ?>  ?=(^ c)
      =+  d=$(a l.c, b l.b)
      =+  e=$(a r.c, b r.b)
      |-  ^-  [$?(~ _a)]
      ?~  d  e
      ?~  e  d
      ?:  (sure n.d n.e)
        d(r $(d r.d))
      e(l $(e l.e))
    --
  ::
  ++  dig                                               ::  axis of a in b
    |=  b=*
    =+  c=1
    |-  ^-  (unit @)
    ?~  a  ~
    ?:  =(b n.a)  [~ u=(peg c 2)]
    ?:  (sore b n.a)
      $(a l.a, c (peg c 6))
    $(a r.a, c (peg c 7))
  ::
  ++  gas                                               ::  concatenate
    |=  b=(list _?>(?=(^ a) n.a))
    |-  ^+  a
    ?~  b
      a
    $(b t.b, a (put i.b))
  ::  +has: does :b exist in :a?
  ::
  ++  has
    |*  b=*
    ^-  ?
    ::  wrap extracted item type in a unit because bunting fails
    ::
    ::    If we used the real item type of _?^(a n.a !!) as the sample type,
    ::    then hoon would bunt it to create the default sample for the gate.
    ::
    ::    However, bunting that expression fails if :a is ~. If we wrap it
    ::    in a unit, the bunted unit doesn't include the bunted item type.
    ::
    ::    This way we can ensure type safety of :b without needing to perform
    ::    this failing bunt. It's a hack.
    ::
    %.  [~ b]
    |=  b=(unit _?>(?=(^ a) n.a))
    =>  .(b ?>(?=(^ b) u.b))
    |-  ^-  ?
    ?~  a
      |
    ?:  =(b n.a)
      &
    ?:  (sore b n.a)
      $(a l.a)
    $(a r.a)
  ::
  ++  int                                               ::  intersection
    =+  b=a
    |@
    ++  $
      |-  ^+  a
      ?~  b
        ~
      ?~  a
        ~
      ?.  (sure n.a n.b)
        $(a b, b a)
      ?:  =(n.b n.a)
        a(l $(a l.a, b l.b), r $(a r.a, b r.b))
      ?:  (sore n.b n.a)
        %-  uni(a $(a l.a, r.b ~))  $(b r.b)
      %-  uni(a $(a r.a, l.b ~))  $(b l.b)
    --
  ::
  ++  put                                               ::  puts b in a, sorted
    |*  b=*
    |-  ^+  a
    ?~  a
      [b ~ ~]
    ?:  =(b n.a)
      a
    ?:  (sore b n.a)
      =+  c=$(a l.a)
      ?>  ?=(^ c)
      ?:  (sure n.a n.c)
        a(l c)
      c(r a(l r.c))
    =+  c=$(a r.a)
    ?>  ?=(^ c)
    ?:  (sure n.a n.c)
      a(r c)
    c(l a(r l.c))
  ::
  ++  rep                                               ::  reduce to product
    |*  b=_=>(~ |=([* *] +<+))
    |-
    ?~  a  +<+.b
    $(a r.a, +<+.b $(a l.a, +<+.b (b n.a +<+.b)))
  ::
  ++  run                                               ::  apply gate to values
    |*  b=gate
    =+  c=`(set _?>(?=(^ a) (b n.a)))`~
    |-  ?~  a  c
    =.  c  (~(put in c) (b n.a))
    =.  c  $(a l.a, c c)
    $(a r.a, c c)
  ::
  ++  tap                                               ::  convert to list
    =<  $
    =+  b=`(list _?>(?=(^ a) n.a))`~
    |.  ^+  b
    ?~  a
      b
    $(a r.a, b [n.a $(a l.a)])
  ::
  ++  uni                                               ::  union
    =+  b=a
    |@
    ++  $
      ?:  =(a b)  a
      |-  ^+  a
      ?~  b
        a
      ?~  a
        b
      ?:  =(n.b n.a)
        b(l $(a l.a, b l.b), r $(a r.a, b r.b))
      ?:  (sure n.a n.b)
        ?:  (sore n.b n.a)
          $(l.a $(a l.a, r.b ~), b r.b)
        $(r.a $(a r.a, l.b ~), b l.b)
      ?:  (sore n.a n.b)
        $(l.b $(b l.b, r.a ~), a r.a)
      $(r.b $(b r.b, l.a ~), a l.a)
    --
  ::
  ++  wyt                                               ::  size of set
    =<  $
    |.  ^-  @
    ?~(a 0 +((add $(a l.a) $(a r.a))))
  --
::                                                      ::
::  map logic, but with shag ordering                   ::
::  TODO jet                                            ::
::
++  pmap
  |$  [key value]                                       ::  table
  $|  (tree (pair key value))
  |=(a=(tree (pair)) ?:(=(~ a) & ~(apt py a)))
::
++  py                                                  ::  pmap engine
  =|  a=(tree (pair))  ::  (map)
  =*  node  ?>(?=(^ a) n.a)
  |@
  ++  all                                               ::  logical AND
    |*  b=$-(* ?)
    |-  ^-  ?
    ?~  a
      &
    ?&((b q.n.a) $(a l.a) $(a r.a))
  ::
  ++  any                                               ::  logical OR
    |*  b=$-(* ?)
    |-  ^-  ?
    ?~  a
      |
    ?|((b q.n.a) $(a l.a) $(a r.a))
  ::
  ++  bif                                               ::  splits a by b
    |*  [b=* c=*]
    ^+  [l=a r=a]
    =<  +
    |-  ^+  a
    ?~  a
      [[b c] ~ ~]
    ?:  =(b p.n.a)
      ?:  =(c q.n.a)
        a
      a(n [b c])
    ?:  (sore b p.n.a)
      =+  d=$(a l.a)
      ?>  ?=(^ d)
      d(r a(l r.d))
    =+  d=$(a r.a)
    ?>  ?=(^ d)
    d(l a(r l.d))
  ::
  ++  del                                               ::  delete at key b
    |*  b=*
    |-  ^+  a
    ?~  a
      ~
    ?.  =(b p.n.a)
      ?:  (sore b p.n.a)
        a(l $(a l.a))
      a(r $(a r.a))
    |-  ^-  [$?(~ _a)]
    ?~  l.a  r.a
    ?~  r.a  l.a
    ?:  (sure p.n.l.a p.n.r.a)
      l.a(r $(l.a r.l.a))
    r.a(l $(r.a l.r.a))
  ::
  ++  dif                                               ::  difference
    =+  b=a
    |@
    ++  $
      |-  ^+  a
      ?~  b
        a
      =+  c=(bif p.n.b q.n.b)
      ?>  ?=(^ c)
      =+  d=$(a l.c, b l.b)
      =+  e=$(a r.c, b r.b)
      |-  ^-  [$?(~ _a)]
      ?~  d  e
      ?~  e  d
      ?:  (sure p.n.d p.n.e)
        d(r $(d r.d))
      e(l $(e l.e))
    --
  ::
  ++  dig                                               ::  axis of b key
    |=  b=*
    =+  c=1
    |-  ^-  (unit @)
    ?~  a  ~
    ?:  =(b p.n.a)  [~ u=(peg c 2)]
    ?:  (sore b p.n.a)
      $(a l.a, c (peg c 6))
    $(a r.a, c (peg c 7))
  ::
  ++  apt                                               ::  check correctness
    =<  $
    =|  [l=(unit) r=(unit)]
    |.  ^-  ?
    ?~  a   &
    ?&  ?~(l & &((sore p.n.a u.l) !=(p.n.a u.l)))
        ?~(r & &((sore u.r p.n.a) !=(u.r p.n.a)))
        ?~  l.a   &
        &((sure p.n.a p.n.l.a) !=(p.n.a p.n.l.a) $(a l.a, l `p.n.a))
        ?~  r.a   &
        &((sure p.n.a p.n.r.a) !=(p.n.a p.n.r.a) $(a r.a, r `p.n.a))
    ==
  ::
  ++  gas                                               ::  concatenate
    |*  b=(list [p=* q=*])
    =>  .(b `(list _?>(?=(^ a) n.a))`b)
    |-  ^+  a
    ?~  b
      a
    $(b t.b, a (put p.i.b q.i.b))
  ::
  ++  get                                               ::  grab value by key
    |*  b=*
    =>  .(b `_?>(?=(^ a) p.n.a)`b)
    |-  ^-  (unit _?>(?=(^ a) q.n.a))
    ?~  a
      ~
    ?:  =(b p.n.a)
      (some q.n.a)
    ?:  (sore b p.n.a)
      $(a l.a)
    $(a r.a)
  ::
  ++  got                                               ::  need value by key
    |*  b=*
    (need (get b))
  ::
  ++  gut                                               ::  fall value by key
    |*  [b=* c=*]
    (fall (get b) c)
  ::
  ++  has                                               ::  key existence check
    |*  b=*
    !=(~ (get b))
  ::
  ++  int                                               ::  intersection
    =+  b=a
    |@
    ++  $
      |-  ^+  a
      ?~  b
        ~
      ?~  a
        ~
      ?:  (sure p.n.a p.n.b)
        ?:  =(p.n.b p.n.a)
          b(l $(a l.a, b l.b), r $(a r.a, b r.b))
        ?:  (sore p.n.b p.n.a)
          %-  uni(a $(a l.a, r.b ~))  $(b r.b)
        %-  uni(a $(a r.a, l.b ~))  $(b l.b)
      ?:  =(p.n.a p.n.b)
        b(l $(b l.b, a l.a), r $(b r.b, a r.a))
      ?:  (sore p.n.a p.n.b)
        %-  uni(a $(b l.b, r.a ~))  $(a r.a)
      %-  uni(a $(b r.b, l.a ~))  $(a l.a)
    --
  ::
  ++  jab
    |*  [key=_?>(?=(^ a) p.n.a) fun=$-(_?>(?=(^ a) q.n.a) _?>(?=(^ a) q.n.a))]
    ^+  a
    ::
    ?~  a  !!
    ::
    ?:  =(key p.n.a)
      a(q.n (fun q.n.a))
    ::
    ?:  (sore key p.n.a)
      a(l $(a l.a))
    ::
    a(r $(a r.a))
  ::
  ++  mar                                               ::  add with validation
    |*  [b=* c=(unit *)]
    ?~  c
      (del b)
    (put b u.c)
  ::
  ++  put                                               ::  adds key-value pair
    |*  [b=* c=*]
    |-  ^+  a
    ?~  a
      [[b c] ~ ~]
    ?:  =(b p.n.a)
      ?:  =(c q.n.a)
        a
      a(n [b c])
    ?:  (sore b p.n.a)
      =+  d=$(a l.a)
      ?>  ?=(^ d)
      ?:  (sure p.n.a p.n.d)
        a(l d)
      d(r a(l r.d))
    =+  d=$(a r.a)
    ?>  ?=(^ d)
    ?:  (sure p.n.a p.n.d)
      a(r d)
    d(l a(r l.d))
  ::
  ++  rep                                               ::  reduce to product
    |*  b=_=>(~ |=([* *] +<+))
    |-
    ?~  a  +<+.b
    $(a r.a, +<+.b $(a l.a, +<+.b (b n.a +<+.b)))
  ::
  ++  rib                                               ::  transform + product
    |*  [b=* c=gate]
    |-  ^+  [b a]
    ?~  a  [b ~]
    =+  d=(c n.a b)
    =.  n.a  +.d
    =+  e=$(a l.a, b -.d)
    =+  f=$(a r.a, b -.e)
    [-.f a(l +.e, r +.f)]
  ::
  ++  run                                               ::  apply gate to values
    |*  b=gate
    |-
    ?~  a  a
    [n=[p=p.n.a q=(b q.n.a)] l=$(a l.a) r=$(a r.a)]
  ::
  ++  rut                                               ::  apply gate to nodes
    |*  b=gate
    |-
    ?~  a  a
    [n=[p=p.n.a q=(b p.n.a q.n.a)] l=$(a l.a) r=$(a r.a)]
  ::
  ++  tap                                               ::  listify pairs
    =<  $
    =+  b=`(list _?>(?=(^ a) n.a))`~
    |.  ^+  b
    ?~  a
      b
    $(a r.a, b [n.a $(a l.a)])
  ::
  ++  uni                                               ::  union, merge
    =+  b=a
    |@
    ++  $
      |-  ^+  a
      ?~  b
        a
      ?~  a
        b
      ?:  =(p.n.b p.n.a)
        b(l $(a l.a, b l.b), r $(a r.a, b r.b))
      ?:  (sure p.n.a p.n.b)
        ?:  (sore p.n.b p.n.a)
          $(l.a $(a l.a, r.b ~), b r.b)
        $(r.a $(a r.a, l.b ~), b l.b)
      ?:  (sore p.n.a p.n.b)
        $(l.b $(b l.b, r.a ~), a r.a)
      $(r.b $(b r.b, l.a ~), a l.a)
    --
  ::
  ++  uno                                               ::  general union
    =+  b=a
    |@
    ++  $
      |=  meg=$-([_p:node _q:node _q:node] _q:node)
      |-  ^+  a
      ?~  b
        a
      ?~  a
        b
      ?:  =(p.n.b p.n.a)
        :+  [p.n.a (meg p.n.a q.n.a q.n.b)]
          $(b l.b, a l.a)
        $(b r.b, a r.a)
      ?:  (sure p.n.a p.n.b)
        ?:  (sore p.n.b p.n.a)
          $(l.a $(a l.a, r.b ~), b r.b)
        $(r.a $(a r.a, l.b ~), b l.b)
      ?:  (sore p.n.a p.n.b)
        $(l.b $(b l.b, r.a ~), a r.a)
      $(r.b $(b r.b, l.a ~), a l.a)
    --
  ::
  ++  urn                                               ::  apply gate to nodes
    |*  b=$-([* *] *)
    |-
    ?~  a  ~
    a(n n.a(q (b p.n.a q.n.a)), l $(a l.a), r $(a r.a))
  ::
  ++  wyt                                               ::  depth of map
    =<  $
    |.  ^-  @
    ?~(a 0 +((add $(a l.a) $(a r.a))))
  ::
  ++  key                                               ::  pset of keys
    =<  $
    =+  b=`(pset _?>(?=(^ a) p.n.a))`~
    |.  ^+  b
    ?~  a   b
    $(a r.a, b $(a l.a, b (~(put pn b) p.n.a)))
  ::
  ++  val                                               ::  list of vals
    =+  b=`(list _?>(?=(^ a) q.n.a))`~
    |-  ^+  b
    ?~  a   b
    $(a r.a, b [q.n.a $(a l.a)])
  --
--
::  ::
::  ::  one: crypto (from zuse + pedersen hash)
::::::
|%
++  pedersen
  |%
  ++  t
    ^-  domain:secp:crypto
    :*  :(add (bex 251) (mul 17 (bex 192)) 1)
        1
        3.141.592.653.589.793.238.462.643.383.279.
          502.884.197.169.399.375.105.820.974.944.
          592.307.816.406.665
        :-  874.739.451.078.007.766.457.464.989.
              774.322.083.649.278.607.533.249.481.
              151.382.481.072.868.806.602
            152.666.792.071.518.830.868.575.557.
              812.948.353.041.420.400.780.739.481.
              342.941.381.225.525.861.407
        3.618.502.788.666.131.213.697.322.783.095.
          070.105.526.743.751.716.087.489.154.079.
          457.884.512.865.583
    ==
  ::
  ++  curve             ~(. secp:secp:crypto 32 t)
  ++  add-points        add-points:curve
  ++  mul-point-scalar  mul-point-scalar:curve
  ++  p0
    :-  2.089.986.280.348.253.421.170.679.821.480.
          865.132.823.066.470.938.446.095.505.822.
          317.253.594.081.284
        1.713.931.329.540.660.377.023.406.109.199.
          410.414.810.705.867.260.802.078.187.082.
          345.529.207.694.986
  ++  p1
    :-  996.781.205.833.008.774.514.500.082.376.
          783.249.102.396.023.663.454.813.447.423.
          147.977.397.232.763
        1.668.503.676.786.377.725.805.489.344.771.
          023.921.079.126.552.019.160.156.920.634.
          619.255.970.485.781
  ++  p2
    :-  2.251.563.274.489.750.535.117.886.426.533.
          222.435.294.046.428.347.329.203.627.021.
          249.169.616.184.184
        1.798.716.007.562.728.905.295.480.679.789.
          526.322.175.868.328.062.420.237.419.143.
          593.021.674.992.973
  ++  p3
    :-  2.138.414.695.194.151.160.943.305.727.036.
          575.959.195.309.218.611.738.193.261.179.
          310.511.854.807.447
        113.410.276.730.064.486.255.102.093.846.
          540.133.784.865.286.929.052.426.931.474.
          106.396.135.072.156
  ++  p4
    :-  2.379.962.749.567.351.885.752.724.891.227.
          938.183.011.949.129.833.673.362.440.656.
          643.086.021.394.946
        776.496.453.633.298.175.483.985.398.648.
          758.586.525.933.812.536.653.089.401.905.
          292.063.708.816.422
  ++  hash
    |=  [a=@ b=@]
    ~>  %pedersen-hash.+<
    ^-  @
    |^
    =/  x  (has a)
    =/  y  (has b)
    +:(do-hash y x)
    ::
    ++  has
      |=  n=@
      ^-  @
      ?:  (lte (met 2 n) 63)  n
      =/  rips
        %^  spin  (tear [3 32] n)  0
        |=  [x=@ ext=@]
        ?:  (lth (met 3 x) 32)
           [x ext]
        :-  (zero-nib x)
        (cat 3 ext (first-nib x))
      =/  r
        ?:  =(q:rips 0)  p.rips
        (into p.rips (lent p.rips) q.rips)
      ?~  r  n
      =/  hed  (snag 0 `(list @)`r)
      =/  tal  (slag 1 `(list @)`r)
      q:(spin tal hed do-hash)
    ::
    ++  first-nib
      |=  n=@
      (end 2 (rev 2 (met 2 n) n))
    ::
    ++  zero-nib
      |=  n=@
      (rev 2 (dec (met 2 n)) (rsh [2 1] (rev 2 (met 2 n) n)))
    ::
    ++  tear
      |=  [s=[@ @] n=@]
      ^-  (list @)
      ?:  =(n 0)  ~[0]
      (rip s n)
    ::
    ++  do-hash
      |=  [b=@ a=@]
      ^-  [@ @]
      =+  alow=(mod a (bex 248))
      =+  ahig=(rsh [0 248] a)
      =+  blow=(mod b (bex 248))
      =+  bhig=(rsh [0 248] b)
      :-  0
      =-  x
      ;:  add-points
        p0
        (mul-point-scalar p1 alow)
        (mul-point-scalar p2 ahig)
        (mul-point-scalar p3 blow)
        (mul-point-scalar p4 bhig)
      ==
    --
  --
::
::  from ethereum.hoon
::
++  address-from-pub
  =,  keccak:crypto
  |=  pub=@
  %+  end  [3 20]
  %+  keccak-256  64
  (rev 3 64 pub)
::
::  *custom* RLP encoding/decoding
::  treats nouns as lists
::
++  rlp
  |%
  +$  item
    $@  @
    $%  [%p p=*]
        [%b b=byts]
    ==
  ::
  ++  encode
    |=  in=*
    ~>  %rlp-encode.+<
    |^  ^-  @
        ?+  in  !!
            @
          $(in [%b (met 3 in) in])
        ::
            [%b b=byts]
          ?:  &(=(1 wid.b.in) (lte dat.b.in 0x7f))
            dat.b.in
          =-  (can 3 ~[b.in [(met 3 -) -]])
          (encode-length wid.b.in 0x80)
        ::
            [%p p=*]
          ::  we +can because b+1^0x0 encodes to 0x00
          ::
          =/  l=(list byts)
            =|  l=(list byts)
            |-
            ?@  p.in
              =+  (encode p.in)
              [(met 3 -)^- l]
            ?@  -.p.in
              =+  (encode -.p.in)
              $(l [(met 3 -)^- l], p.in +.p.in)
            =+  (encode [%p -.p.in])
            $(l [(met 3 -)^- l], p.in +.p.in)
          %+  can  3
          =-  (snoc l (met 3 -)^-)
          (encode-length (roll (turn l head) add) 0xc0)
        ==
    ::
    ++  encode-length
      |=  [len=@ off=@]
      ?:  (lth len 56)  (add len off)
      =-  (cat 3 len -)
      :(add (met 3 len) off 55)
    --
  ::
  ++  decode
    |=  dat=@
    ^-  *
    =/  bytes=(list @)  (flop (rip 3 dat))
    =?  bytes  ?=(~ bytes)  ~[0]
    |^  noun:decode-head
    ::
    ++  decode-head
      ^-  [done=@ud =noun]
      ?~  bytes  !!
      =*  byt  i.bytes
      ::  byte in 0x00-0x79 range encodes itself
      ::
      ?:  (lte byt 0x79)
        1^byt
      ::  byte in 0x80-0xb7 range encodes string length
      ::
      ?:  (lte byt 0xb7)
        =+  len=(sub byt 0x80)
        :-  +(len)
        (get-value 1 len)
      ::  byte in 0xb8-0xbf range encodes string length length
      ::
      ?:  (lte byt 0xbf)
        =+  led=(sub byt 0xb7)
        =+  len=(get-value 1 led)
        :-  (add +(led) len)
        (get-value +(led) len)
      ::  byte in 0xc0-f7 range encodes list length
      ::
      ?:  (lte byt 0xf7)
        =+  len=(sub byt 0xc0)
        :-  +(len)
        %.  len
        decode-list(bytes (slag 1 `(list @)`bytes))
      ::  byte in 0xf8-ff range encodes list length length
      ::
      ?:  (lte byt 0xff)
        =+  led=(sub byt 0xf7)
        =+  len=(get-value 1 led)
        :-  (add +(led) len)
        %.  len
        decode-list(bytes (slag +(led) `(list @)`bytes))
      !!
    ::
    ++  decode-list
      |=  rem=@ud
      ^-  *
      ?:  =(1 rem)
        noun:decode-head
      =+  ^-  [don=@ud =noun]
        decode-head
      :-  noun
      %=  $
        rem    (sub rem don)
        bytes  (slag don bytes)
      ==
    ::
    ++  get-value
      |=  [at=@ud to=@ud]
      ^-  @
      (rep 3 (flop (swag [at to] bytes)))
    --
--
::
::  AMES from lull.hoon
::
++  ames  ^?
  |%
  ::
  ::::                                                  ::  (1a2)
    ::
  +$  pass  @
  +$  ring  @
  ++  acru  $_  ^?                                      ::  asym cryptosuite
    |%                                                  ::  opaque object
    ++  as  ^?                                          ::  asym ops
      |%  ++  seal  |~([a=pass b=@] *@)                 ::  encrypt to a
          ++  sign  |~(a=@ *@)                          ::  certify as us
          ++  sure  |~(a=@ *(unit @))                   ::  authenticate from us
          ++  tear  |~([a=pass b=@] *(unit @))          ::  accept from a
      --  ::as                                          ::
    ++  de  |~([a=@ b=@] *(unit @))                     ::  symmetric de, soft
    ++  dy  |~([a=@ b=@] *@)                            ::  symmetric de, hard
    ++  en  |~([a=@ b=@] *@)                            ::  symmetric en
    ++  ex  ^?                                          ::  export
      |%  ++  fig  *@uvH                                ::  fingerprint
          ++  pac  *@uvG                                ::  default passcode
          ++  pub  *pass                                ::  public key
          ++  sec  *ring                                ::  private key
      --  ::ex                                          ::
    ++  nu  ^?                                          ::  reconstructors
      |%  ++  pit  |~([a=@ b=@] ^?(..nu))               ::  from [width seed]
          ++  nol  |~(a=ring ^?(..nu))                  ::  from ring
          ++  com  |~(a=pass ^?(..nu))                  ::  from pass
      --  ::nu                                          ::
    --  ::acru                                          ::
  --  ::ames
::
::  MISC from lull.hoon
::
+$  octs  (pair @ud @)                                  ::  octet-stream
::
::  NUMBER from zuse.hoon
::
++  number  ^?
  |%
  ::                                                    ::  ++fu:number
  ++  fu                                                ::  modulo (mul p q)
    |=  a=[p=@ q=@]
    =+  b=?:(=([0 0] a) 0 (~(inv fo p.a) (~(sit fo p.a) q.a)))
    |%
    ::                                                  ::  ++dif:fu:number
    ++  dif                                             ::  subtract
      |=  [c=[@ @] d=[@ @]]
      [(~(dif fo p.a) -.c -.d) (~(dif fo q.a) +.c +.d)]
    ::                                                  ::  ++exp:fu:number
    ++  exp                                             ::  exponent
      |=  [c=@ d=[@ @]]
      :-  (~(exp fo p.a) (mod c (dec p.a)) -.d)
      (~(exp fo q.a) (mod c (dec q.a)) +.d)
    ::                                                  ::  ++out:fu:number
    ++  out                                             ::  garner's formula
      |=  c=[@ @]
      %+  add  +.c
      %+  mul  q.a
      %+  ~(pro fo p.a)  b
      (~(dif fo p.a) -.c (~(sit fo p.a) +.c))
    ::                                                  ::  ++pro:fu:number
    ++  pro                                             ::  multiply
      |=  [c=[@ @] d=[@ @]]
      [(~(pro fo p.a) -.c -.d) (~(pro fo q.a) +.c +.d)]
    ::                                                  ::  ++sum:fu:number
    ++  sum                                             ::  add
      |=  [c=[@ @] d=[@ @]]
      [(~(sum fo p.a) -.c -.d) (~(sum fo q.a) +.c +.d)]
    ::                                                  ::  ++sit:fu:number
    ++  sit                                             ::  represent
      |=  c=@
      [(mod c p.a) (mod c q.a)]
    --  ::fu
  ::                                                    ::  ++pram:number
  ++  pram                                              ::  rabin-miller
    |=  a=@  ^-  ?
    ?:  ?|  =(0 (end 0 a))
            =(1 a)
            =+  b=1
            |-  ^-  ?
            ?:  =(512 b)
              |
            ?|(=+(c=+((mul 2 b)) &(!=(a c) =(a (mul c (div a c))))) $(b +(b)))
        ==
      |
    =+  ^=  b
        =+  [s=(dec a) t=0]
        |-  ^-  [s=@ t=@]
        ?:  =(0 (end 0 s))
          $(s (rsh 0 s), t +(t))
        [s t]
    ?>  =((mul s.b (bex t.b)) (dec a))
    =+  c=0
    |-  ^-  ?
    ?:  =(c 64)
      &
    =+  d=(~(raw og (add c a)) (met 0 a))
    =+  e=(~(exp fo a) s.b d)
    ?&  ?|  =(1 e)
            =+  f=0
            |-  ^-  ?
            ?:  =(e (dec a))
              &
            ?:  =(f (dec t.b))
              |
            $(e (~(pro fo a) e e), f +(f))
        ==
        $(c +(c))
    ==
  ::                                                    ::  ++ramp:number
  ++  ramp                                              ::  make r-m prime
    |=  [a=@ b=(list @) c=@]  ^-  @ux                   ::  [bits snags seed]
    =>  .(c (shas %ramp c))
    =+  d=*@
    |-
    ?:  =((mul 100 a) d)
      !!
    =+  e=(~(raw og c) a)
    ?:  &((levy b |=(f=@ !=(1 (mod e f)))) (pram e))
      e
    $(c +(c), d (shax d))
  ::                                                    ::  ++curt:number
  ++  curt                                              ::  curve25519
    |=  [a=@ b=@]
    =>  %=    .
            +
          =>  +
          =+  =+  [p=486.662 q=(sub (bex 255) 19)]
              =+  fq=~(. fo q)
              [p=p q=q fq=fq]
          |%
          ::                                            ::  ++cla:curt:number
          ++  cla                                       ::
            |=  raw=@
            =+  low=(dis 248 (cut 3 [0 1] raw))
            =+  hih=(con 64 (dis 127 (cut 3 [31 1] raw)))
            =+  mid=(cut 3 [1 30] raw)
            (can 3 [[1 low] [30 mid] [1 hih] ~])
          ::                                            ::  ++sqr:curt:number
          ++  sqr                                       ::
            |=(a=@ (mul a a))
          ::                                            ::  ++inv:curt:number
          ++  inv                                       ::
            |=(a=@ (~(exp fo q) (sub q 2) a))
          ::                                            ::  ++cad:curt:number
          ++  cad                                       ::
            |=  [n=[x=@ z=@] m=[x=@ z=@] d=[x=@ z=@]]
            =+  ^=  xx
                ;:  mul  4  z.d
                  %-  sqr  %-  abs:si
                  %+  dif:si
                    (sun:si (mul x.m x.n))
                  (sun:si (mul z.m z.n))
                ==
            =+  ^=  zz
                ;:  mul  4  x.d
                  %-  sqr  %-  abs:si
                  %+  dif:si
                    (sun:si (mul x.m z.n))
                  (sun:si (mul z.m x.n))
                ==
            [(sit.fq xx) (sit.fq zz)]
          ::                                            ::  ++cub:curt:number
          ++  cub                                       ::
            |=  [x=@ z=@]
            =+  ^=  xx
                %+  mul
                  %-  sqr  %-  abs:si
                  (dif:si (sun:si x) (sun:si z))
                (sqr (add x z))
            =+  ^=  zz
                ;:  mul  4  x  z
                  :(add (sqr x) :(mul p x z) (sqr z))
                ==
            [(sit.fq xx) (sit.fq zz)]
          --  ::
        ==
    =+  one=[b 1]
    =+  i=253
    =+  r=one
    =+  s=(cub one)
    |-
    ?:  =(i 0)
      =+  x=(cub r)
      (sit.fq (mul -.x (inv +.x)))
    =+  m=(rsh [0 i] a)
    ?:  =(0 (mod m 2))
       $(i (dec i), s (cad r s one), r (cub r))
    $(i (dec i), r (cad r s one), s (cub s))
  ::                                                    ::  ++ga:number
  ++  ga                                                ::  GF (bex p.a)
    |=  a=[p=@ q=@ r=@]                                 ::  dim poly gen
    =+  si=(bex p.a)
    =+  ma=(dec si)
    =>  |%
        ::                                              ::  ++dif:ga:number
        ++  dif                                         ::  add and sub
          |=  [b=@ c=@]
          ?>  &((lth b si) (lth c si))
          (mix b c)
        ::                                              ::  ++dub:ga:number
        ++  dub                                         ::  mul by x
          |=  b=@
          ?>  (lth b si)
          ?:  =(1 (cut 0 [(dec p.a) 1] b))
            (dif (sit q.a) (sit (lsh 0 b)))
          (lsh 0 b)
        ::                                              ::  ++pro:ga:number
        ++  pro                                         ::  slow multiply
          |=  [b=@ c=@]
          ?:  =(0 b)
            0
          ?:  =(1 (dis 1 b))
            (dif c $(b (rsh 0 b), c (dub c)))
          $(b (rsh 0 b), c (dub c))
        ::                                              ::  ++toe:ga:number
        ++  toe                                         ::  exp+log tables
          =+  ^=  nu
              |=  [b=@ c=@]
              ^-  (map @ @)
              =+  d=*(map @ @)
              |-
              ?:  =(0 c)
                d
              %=  $
                c  (dec c)
                d  (~(put by d) c b)
              ==
          =+  [p=(nu 0 (bex p.a)) q=(nu ma ma)]
          =+  [b=1 c=0]
          |-  ^-  [p=(map @ @) q=(map @ @)]
          ?:  =(ma c)
            [(~(put by p) c b) q]
          %=  $
            b  (pro r.a b)
            c  +(c)
            p  (~(put by p) c b)
            q  (~(put by q) b c)
          ==
        ::                                              ::  ++sit:ga:number
        ++  sit                                         ::  reduce
          |=  b=@
          (mod b (bex p.a))
        --  ::
    =+  toe
    |%
    ::                                                  ::  ++fra:ga:number
    ++  fra                                             ::  divide
      |=  [b=@ c=@]
      (pro b (inv c))
    ::                                                  ::  ++inv:ga:number
    ++  inv                                             ::  invert
      |=  b=@
      =+  c=(~(get by q) b)
      ?~  c  !!
      =+  d=(~(get by p) (sub ma u.c))
      (need d)
    ::                                                  ::  ++pow:ga:number
    ++  pow                                             ::  exponent
      |=  [b=@ c=@]
      =+  [d=1 e=c f=0]
      |-
      ?:  =(p.a f)
        d
      ?:  =(1 (cut 0 [f 1] b))
        $(d (pro d e), e (pro e e), f +(f))
      $(e (pro e e), f +(f))
    ::                                                  ::  ++pro:ga:number
    ++  pro                                             ::  multiply
      |=  [b=@ c=@]
      =+  d=(~(get by q) b)
      ?~  d  0
      =+  e=(~(get by q) c)
      ?~  e  0
      =+  f=(~(get by p) (mod (add u.d u.e) ma))
      (need f)
    --  ::ga
  --  ::number
::
::  HTML from zuse.hoon
::
++  html  ^?
  |%
  ::                                                    ::
  ::::                    ++mimes:html                  ::  (2e1) MIME
    ::                                                  ::::
  ++  mimes  ^?
    |%
    ::                                                  ::  ++as-octs:mimes:html
    ++  as-octs                                         ::  atom to octstream
      |=  tam=@  ^-  octs
      [(met 3 tam) tam]
    ::                                                  ::  ++as-octt:mimes:html
    ++  as-octt                                         ::  tape to octstream
      |=  tep=tape  ^-  octs
      (as-octs (rap 3 tep))
    --
  --  ::  html
::
::  CRYPTO from zuse.hoon
::
++  crypto  ^?
  =,  ames
  =,  number
  |%
  ::                                                    ::
  ::::                    ++aes:crypto                  ::  (2b1) aes, all sizes
    ::                                                  ::::
  ++  aes
    |%
    ::                                                  ::  ++ahem:aes:crypto
    ++  ahem                                            ::  kernel state
      |=  [nnk=@ nnb=@ nnr=@]
      =>
        =+  =>  [gr=(ga 8 0x11b 3) few==>(fe .(a 5))]
            [pro=pro.gr dif=dif.gr pow=pow.gr ror=ror.few]
        =>  |%                                          ::
            ++  cipa  $_  ^?                            ::  AES params
              |%
              ++  co  *[p=@ q=@ r=@ s=@]                ::  column coefficients
              ++  ix  |~(a=@ *@)                        ::  key index
              ++  ro  *[p=@ q=@ r=@ s=@]                ::  row shifts
              ++  su  *@                                ::  s-box
              --  ::cipa
            --  ::
        |%
        ::                                              ::  ++pen:ahem:aes:
        ++  pen                                         ::  encrypt
          ^-  cipa
          |%
          ::                                            ::  ++co:pen:ahem:aes:
          ++  co                                        ::  column coefficients
            [0x2 0x3 1 1]
          ::                                            ::  ++ix:pen:ahem:aes:
          ++  ix                                        ::  key index
            |~(a=@ a)
          ::                                            ::  ++ro:pen:ahem:aes:
          ++  ro                                        ::  row shifts
            [0 1 2 3]
          ::                                            ::  ++su:pen:ahem:aes:
          ++  su                                        ::  s-box
            0x16bb.54b0.0f2d.9941.6842.e6bf.0d89.a18c.
              df28.55ce.e987.1e9b.948e.d969.1198.f8e1.
              9e1d.c186.b957.3561.0ef6.0348.66b5.3e70.
              8a8b.bd4b.1f74.dde8.c6b4.a61c.2e25.78ba.
              08ae.7a65.eaf4.566c.a94e.d58d.6d37.c8e7.
              79e4.9591.62ac.d3c2.5c24.0649.0a3a.32e0.
              db0b.5ede.14b8.ee46.8890.2a22.dc4f.8160.
              7319.5d64.3d7e.a7c4.1744.975f.ec13.0ccd.
              d2f3.ff10.21da.b6bc.f538.9d92.8f40.a351.
              a89f.3c50.7f02.f945.8533.4d43.fbaa.efd0.
              cf58.4c4a.39be.cb6a.5bb1.fc20.ed00.d153.
              842f.e329.b3d6.3b52.a05a.6e1b.1a2c.8309.
              75b2.27eb.e280.1207.9a05.9618.c323.c704.
              1531.d871.f1e5.a534.ccf7.3f36.2693.fdb7.
              c072.a49c.afa2.d4ad.f047.59fa.7dc9.82ca.
              76ab.d7fe.2b67.0130.c56f.6bf2.7b77.7c63
          --
        ::                                              ::  ++pin:ahem:aes:
        ++  pin                                         ::  decrypt
          ^-  cipa
          |%
          ::                                            ::  ++co:pin:ahem:aes:
          ++  co                                        ::  column coefficients
            [0xe 0xb 0xd 0x9]
          ::                                            ::  ++ix:pin:ahem:aes:
          ++  ix                                        ::  key index
            |~(a=@ (sub nnr a))
          ::                                            ::  ++ro:pin:ahem:aes:
          ++  ro                                        ::  row shifts
            [0 3 2 1]
          ::                                            ::  ++su:pin:ahem:aes:
          ++  su                                        ::  s-box
            0x7d0c.2155.6314.69e1.26d6.77ba.7e04.2b17.
              6199.5383.3cbb.ebc8.b0f5.2aae.4d3b.e0a0.
              ef9c.c993.9f7a.e52d.0d4a.b519.a97f.5160.
              5fec.8027.5910.12b1.31c7.0788.33a8.dd1f.
              f45a.cd78.fec0.db9a.2079.d2c6.4b3e.56fc.
              1bbe.18aa.0e62.b76f.89c5.291d.711a.f147.
              6edf.751c.e837.f9e2.8535.ade7.2274.ac96.
              73e6.b4f0.cecf.f297.eadc.674f.4111.913a.
              6b8a.1301.03bd.afc1.020f.3fca.8f1e.2cd0.
              0645.b3b8.0558.e4f7.0ad3.bc8c.00ab.d890.
              849d.8da7.5746.155e.dab9.edfd.5048.706c.
              92b6.655d.cc5c.a4d4.1698.6886.64f6.f872.
              25d1.8b6d.49a2.5b76.b224.d928.66a1.2e08.
              4ec3.fa42.0b95.4cee.3d23.c2a6.3294.7b54.
              cbe9.dec4.4443.8e34.87ff.2f9b.8239.e37c.
              fbd7.f381.9ea3.40bf.38a5.3630.d56a.0952
          --
        ::                                              ::  ++mcol:ahem:aes:
        ++  mcol                                        ::
          |=  [a=(list @) b=[p=@ q=@ r=@ s=@]]
          ^-  (list @)
          =+  c=[p=*@ q=*@ r=*@ s=*@]
          |-  ^-  (list @)
          ?~  a  ~
          =>  .(p.c (cut 3 [0 1] i.a))
          =>  .(q.c (cut 3 [1 1] i.a))
          =>  .(r.c (cut 3 [2 1] i.a))
          =>  .(s.c (cut 3 [3 1] i.a))
          :_  $(a t.a)
          %+  rep  3
          %+  turn
            %-  limo
            :~  [[p.c p.b] [q.c q.b] [r.c r.b] [s.c s.b]]
                [[p.c s.b] [q.c p.b] [r.c q.b] [s.c r.b]]
                [[p.c r.b] [q.c s.b] [r.c p.b] [s.c q.b]]
                [[p.c q.b] [q.c r.b] [r.c s.b] [s.c p.b]]
            ==
          |=  [a=[@ @] b=[@ @] c=[@ @] d=[@ @]]
          :(dif (pro a) (pro b) (pro c) (pro d))
        ::                                              ::  ++pode:ahem:aes:
        ++  pode                                        ::  explode to block
          |=  [a=bloq b=@ c=@]  ^-  (list @)
          =+  d=(rip a c)
          =+  m=(met a c)
          |-
          ?:  =(m b)
            d
          $(m +(m), d (weld d (limo [0 ~])))
        ::                                              ::  ++sube:ahem:aes:
        ++  sube                                        ::  s-box word
          |=  [a=@ b=@]  ^-  @
          (rep 3 (turn (pode 3 4 a) |=(c=@ (cut 3 [c 1] b))))
        --  ::
      |%
      ::                                                ::  ++be:ahem:aes:crypto
      ++  be                                            ::  block cipher
        |=  [a=? b=@ c=@H]  ^-  @uxH
        =>  %=    .
                +
              =>  +
              |%
              ::                                        ::  ++ankh:be:ahem:aes:
              ++  ankh                                  ::
                |=  [a=cipa b=@ c=@]
                (pode 5 nnb (cut 5 [(mul (ix.a b) nnb) nnb] c))
              ::                                        ::  ++sark:be:ahem:aes:
              ++  sark                                  ::
                |=  [c=(list @) d=(list @)]
                ^-  (list @)
                ?~  c  ~
                ?~  d  !!
                [(mix i.c i.d) $(c t.c, d t.d)]
              ::                                        ::  ++srow:be:ahem:aes:
              ++  srow                                  ::
                |=  [a=cipa b=(list @)]  ^-  (list @)
                =+  [c=0 d=~ e=ro.a]
                |-
                ?:  =(c nnb)
                  d
                :_  $(c +(c))
                %+  rep  3
                %+  turn
                  (limo [0 p.e] [1 q.e] [2 r.e] [3 s.e] ~)
                |=  [f=@ g=@]
                (cut 3 [f 1] (snag (mod (add g c) nnb) b))
              ::                                        ::  ++subs:be:ahem:aes:
              ++  subs                                  ::
                |=  [a=cipa b=(list @)]  ^-  (list @)
                ?~  b  ~
                [(sube i.b su.a) $(b t.b)]
              --
            ==
        =+  [d=?:(a pen pin) e=(pode 5 nnb c) f=1]
        =>  .(e (sark e (ankh d 0 b)))
        |-
        ?.  =(nnr f)
          =>  .(e (subs d e))
          =>  .(e (srow d e))
          =>  .(e (mcol e co.d))
          =>  .(e (sark e (ankh d f b)))
          $(f +(f))
        =>  .(e (subs d e))
        =>  .(e (srow d e))
        =>  .(e (sark e (ankh d nnr b)))
        (rep 5 e)
      ::                                                ::  ++ex:ahem:aes:crypto
      ++  ex                                            ::  key expand
        |=  a=@I  ^-  @
        =+  [b=a c=0 d=su:pen i=nnk]
        |-
        ?:  =(i (mul nnb +(nnr)))
          b
        =>  .(c (cut 5 [(dec i) 1] b))
        =>  ?:  =(0 (mod i nnk))
              =>  .(c (ror 3 1 c))
              =>  .(c (sube c d))
              .(c (mix c (pow (dec (div i nnk)) 2)))
            ?:  &((gth nnk 6) =(4 (mod i nnk)))
              .(c (sube c d))
            .
        =>  .(c (mix c (cut 5 [(sub i nnk) 1] b)))
        =>  .(b (can 5 [i b] [1 c] ~))
        $(i +(i))
      ::                                                ::  ++ix:ahem:aes:crypto
      ++  ix                                            ::  key expand, inv
        |=  a=@  ^-  @
        =+  [i=1 j=*@ b=*@ c=co:pin]
        |-
        ?:  =(nnr i)
          a
        =>  .(b (cut 7 [i 1] a))
        =>  .(b (rep 5 (mcol (pode 5 4 b) c)))
        =>  .(j (sub nnr i))
        %=    $
            i  +(i)
            a
          %+  can  7
          :~  [i (cut 7 [0 i] a)]
              [1 b]
              [j (cut 7 [+(i) j] a)]
          ==
        ==
      --
    ::                                                  ::  ++ecba:aes:crypto
    ++  ecba                                            ::  AES-128 ECB
      |_  key=@H
      ::                                                ::  ++en:ecba:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  blk=@H  ^-  @uxH
        =+  (ahem 4 4 10)
        =:
          key  (~(net fe 7) key)
          blk  (~(net fe 7) blk)
        ==
        %-  ~(net fe 7)
        (be & (ex key) blk)
      ::                                                ::  ++de:ecba:aes:crypto
      ++  de                                            ::  decrypt
        ~/  %de
        |=  blk=@H  ^-  @uxH
        =+  (ahem 4 4 10)
        =:
          key  (~(net fe 7) key)
          blk  (~(net fe 7) blk)
        ==
        %-  ~(net fe 7)
        (be | (ix (ex key)) blk)
      --  ::ecba
    ::                                                  ::  ++ecbb:aes:crypto
    ++  ecbb                                            ::  AES-192 ECB
      |_  key=@I
      ::                                                ::  ++en:ecbb:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  blk=@H  ^-  @uxH
        =+  (ahem 6 4 12)
        =:
          key  (rsh 6 (~(net fe 8) key))
          blk  (~(net fe 7) blk)
        ==
        %-  ~(net fe 7)
        (be & (ex key) blk)
      ::                                                ::  ++de:ecbb:aes:crypto
      ++  de                                            ::  decrypt
        ~/  %de
        |=  blk=@H  ^-  @uxH
        =+  (ahem 6 4 12)
        =:
          key  (rsh 6 (~(net fe 8) key))
          blk  (~(net fe 7) blk)
        ==
        %-  ~(net fe 7)
        (be | (ix (ex key)) blk)
      --  ::ecbb
    ::                                                  ::  ++ecbc:aes:crypto
    ++  ecbc                                            ::  AES-256 ECB
      ~%  %ecbc  +>  ~
      |_  key=@I
      ::                                                ::  ++en:ecbc:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  blk=@H  ^-  @uxH
        =+  (ahem 8 4 14)
        =:
          key  (~(net fe 8) key)
          blk  (~(net fe 7) blk)
        ==
        %-  ~(net fe 7)
        (be & (ex key) blk)
      ::                                                ::  ++de:ecbc:aes:crypto
      ++  de                                            ::  decrypt
        ~/  %de
        |=  blk=@H  ^-  @uxH
        =+  (ahem 8 4 14)
        =:
          key  (~(net fe 8) key)
          blk  (~(net fe 7) blk)
        ==
        %-  ~(net fe 7)
        (be | (ix (ex key)) blk)
      --  ::ecbc
    ::                                                  ::  ++cbca:aes:crypto
    ++  cbca                                            ::  AES-128 CBC
      ~%  %cbca  +>  ~
      |_  [key=@H prv=@H]
      ::                                                ::  ++en:cbca:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  txt=@  ^-  @ux
        =+  pts=?:(=(txt 0) `(list @)`~[0] (flop (rip 7 txt)))
        =|  cts=(list @)
        %+  rep  7
        ::  logically, flop twice here
        |-  ^-  (list @)
        ?~  pts
          cts
        =+  cph=(~(en ecba key) (mix prv i.pts))
        %=  $
          cts  [cph cts]
          pts  t.pts
          prv  cph
        ==
      ::                                                ::  ++de:cbca:aes:crypto
      ++  de                                            ::  decrypt
        ~/  %de
        |=  txt=@  ^-  @ux
        =+  cts=?:(=(txt 0) `(list @)`~[0] (flop (rip 7 txt)))
        =|  pts=(list @)
        %+  rep  7
        ::  logically, flop twice here
        |-  ^-  (list @)
        ?~  cts
          pts
        =+  pln=(mix prv (~(de ecba key) i.cts))
        %=  $
          pts  [pln pts]
          cts  t.cts
          prv  i.cts
        ==
      --  ::cbca
    ::                                                  ::  ++cbcb:aes:crypto
    ++  cbcb                                            ::  AES-192 CBC
      ~%  %cbcb  +>  ~
      |_  [key=@I prv=@H]
      ::                                                ::  ++en:cbcb:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  txt=@  ^-  @ux
        =+  pts=?:(=(txt 0) `(list @)`~[0] (flop (rip 7 txt)))
        =|  cts=(list @)
        %+  rep  7
        ::  logically, flop twice here
        |-  ^-  (list @)
        ?~  pts
          cts
        =+  cph=(~(en ecbb key) (mix prv i.pts))
        %=  $
          cts  [cph cts]
          pts  t.pts
          prv  cph
        ==
      ::                                                ::  ++de:cbcb:aes:crypto
      ++  de                                            ::  decrypt
        ~/  %de
        |=  txt=@  ^-  @ux
        =+  cts=?:(=(txt 0) `(list @)`~[0] (flop (rip 7 txt)))
        =|  pts=(list @)
        %+  rep  7
        ::  logically, flop twice here
        |-  ^-  (list @)
        ?~  cts
          pts
        =+  pln=(mix prv (~(de ecbb key) i.cts))
        %=  $
          pts  [pln pts]
          cts  t.cts
          prv  i.cts
        ==
      --  ::cbcb
    ::                                                  ::  ++cbcc:aes:crypto
    ++  cbcc                                            ::  AES-256 CBC
      ~%  %cbcc  +>  ~
      |_  [key=@I prv=@H]
      ::                                                ::  ++en:cbcc:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  txt=@  ^-  @ux
        =+  pts=?:(=(txt 0) `(list @)`~[0] (flop (rip 7 txt)))
        =|  cts=(list @)
        %+  rep  7
        ::  logically, flop twice here
        |-  ^-  (list @)
        ?~  pts
          cts
        =+  cph=(~(en ecbc key) (mix prv i.pts))
        %=  $
          cts  [cph cts]
          pts  t.pts
          prv  cph
        ==
      ::                                                ::  ++de:cbcc:aes:crypto
      ++  de                                            ::  decrypt
        ~/  %de
        |=  txt=@  ^-  @ux
        =+  cts=?:(=(txt 0) `(list @)`~[0] (flop (rip 7 txt)))
        =|  pts=(list @)
        %+  rep  7
        ::  logically, flop twice here
        |-  ^-  (list @)
        ?~  cts
          pts
        =+  pln=(mix prv (~(de ecbc key) i.cts))
        %=  $
          pts  [pln pts]
          cts  t.cts
          prv  i.cts
        ==
      --  ::cbcc
    ::                                                  ::  ++inc:aes:crypto
    ++  inc                                             ::  inc. low bloq
      |=  [mod=bloq ctr=@H]
      ^-  @uxH
      =+  bqs=(rip mod ctr)
      ?~  bqs  0x1
      %+  rep  mod
      [(~(sum fe mod) i.bqs 1) t.bqs]
    ::                                                  ::  ++ctra:aes:crypto
    ++  ctra                                            ::  AES-128 CTR
      ~%  %ctra  +>  ~
      |_  [key=@H mod=bloq len=@ ctr=@H]
      ::                                                ::  ++en:ctra:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  txt=@
        ^-  @ux
        =/  encrypt  ~(en ecba key)
        =/  blocks  (add (div len 16) ?:(=((^mod len 16) 0) 0 1))
        ?>  (gte len (met 3 txt))
        %+  mix  txt
        %+  rsh  [3 (sub (mul 16 blocks) len)]
        %+  rep  7
        =|  seed=(list @ux)
        |-  ^+  seed
        ?:  =(blocks 0)  seed
        %=  $
          seed    [(encrypt ctr) seed]
          ctr     (inc mod ctr)
          blocks  (dec blocks)
        ==
      ::                                                ::  ++de:ctra:aes:crypto
      ++  de                                            ::  decrypt
        en
      --  ::ctra
    ::                                                  ::  ++ctrb:aes:crypto
    ++  ctrb                                            ::  AES-192 CTR
      ~%  %ctrb  +>  ~
      |_  [key=@I mod=bloq len=@ ctr=@H]
      ::                                                ::  ++en:ctrb:aes:crypto
      ++  en
        ~/  %en
        |=  txt=@
        ^-  @ux
        =/  encrypt  ~(en ecbb key)
        =/  blocks  (add (div len 16) ?:(=((^mod len 16) 0) 0 1))
        ?>  (gte len (met 3 txt))
        %+  mix  txt
        %+  rsh  [3 (sub (mul 16 blocks) len)]
        %+  rep  7
        =|  seed=(list @ux)
        |-  ^+  seed
        ?:  =(blocks 0)  seed
        %=  $
          seed    [(encrypt ctr) seed]
          ctr     (inc mod ctr)
          blocks  (dec blocks)
        ==
      ::                                                ::  ++de:ctrb:aes:crypto
      ++  de                                            ::  decrypt
        en
      --  ::ctrb
    ::                                                  ::  ++ctrc:aes:crypto
    ++  ctrc                                            ::  AES-256 CTR
      ~%  %ctrc  +>  ~
      |_  [key=@I mod=bloq len=@ ctr=@H]
      ::                                                ::  ++en:ctrc:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  txt=@
        ^-  @ux
        =/  encrypt  ~(en ecbc key)
        =/  blocks  (add (div len 16) ?:(=((^mod len 16) 0) 0 1))
        ?>  (gte len (met 3 txt))
        %+  mix  txt
        %+  rsh  [3 (sub (mul 16 blocks) len)]
        %+  rep  7
        =|  seed=(list @ux)
        |-  ^+  seed
        ?:  =(blocks 0)  seed
        %=  $
          seed    [(encrypt ctr) seed]
          ctr     (inc mod ctr)
          blocks  (dec blocks)
        ==
      ::                                                ::  ++de:ctrc:aes:crypto
      ++  de                                            ::  decrypt
        en
      --  ::ctrc
    ::                                                  ::  ++doub:aes:crypto
    ++  doub                                            ::  double 128-bit
      |=  ::  string mod finite
          ::
          str=@H
      ::
      ::  field (see spec)
      ::
      ^-  @uxH
      %-  ~(sit fe 7)
      ?.  =((xeb str) 128)
        (lsh 0 str)
      (mix 0x87 (lsh 0 str))
    ::                                                  ::  ++mpad:aes:crypto
    ++  mpad                                            ::
      |=  [oct=@ txt=@]
      ::
      ::  pad message to multiple of 128 bits
      ::  by appending 1, then 0s
      ::  the spec is unclear, but it must be octet based
      ::  to match the test vectors
      ::
      ^-  @ux
      =+  pad=(mod oct 16)
      ?:  =(pad 0)  0x8000.0000.0000.0000.0000.0000.0000.0000
      (lsh [3 (sub 15 pad)] (mix 0x80 (lsh 3 txt)))
    ::                                                  ::  ++suba:aes:crypto
    ++  suba                                            ::  AES-128 subkeys
      |=  key=@H
      =+  l=(~(en ecba key) 0)
      =+  k1=(doub l)
      =+  k2=(doub k1)
      ^-  [@ux @ux]
      [k1 k2]
    ::                                                  ::  ++subb:aes:crypto
    ++  subb                                            ::  AES-192 subkeys
      |=  key=@I
      =+  l=(~(en ecbb key) 0)
      =+  k1=(doub l)
      =+  k2=(doub k1)
      ^-  [@ux @ux]
      [k1 k2]
    ::                                                  ::  ++subc:aes:crypto
    ++  subc                                            ::  AES-256 subkeys
      |=  key=@I
      =+  l=(~(en ecbc key) 0)
      =+  k1=(doub l)
      =+  k2=(doub k1)
      ^-  [@ux @ux]
      [k1 k2]
    ::                                                  ::  ++maca:aes:crypto
    ++  maca                                            ::  AES-128 CMAC
      ~/  %maca
      |=  [key=@H oct=(unit @) txt=@]
      ^-  @ux
      =+  [sub=(suba key) len=?~(oct (met 3 txt) u.oct)]
      =+  ^=  pdt
        ?:  &(=((mod len 16) 0) !=(len 0))
          [& txt]
        [| (mpad len txt)]
      =+  ^=  mac
        %-  ~(en cbca key 0)
        %+  mix  +.pdt
        ?-  -.pdt
          %&  -.sub
          %|  +.sub
        ==
      ::  spec says MSBs, LSBs match test vectors
      ::
      (~(sit fe 7) mac)
    ::                                                  ::  ++macb:aes:crypto
    ++  macb                                            ::  AES-192 CMAC
      ~/  %macb
      |=  [key=@I oct=(unit @) txt=@]
      ^-  @ux
      =+  [sub=(subb key) len=?~(oct (met 3 txt) u.oct)]
      =+  ^=  pdt
        ?:  &(=((mod len 16) 0) !=(len 0))
          [& txt]
        [| (mpad len txt)]
      =+  ^=  mac
        %-  ~(en cbcb key 0)
        %+  mix  +.pdt
        ?-  -.pdt
          %&  -.sub
          %|  +.sub
        ==
      ::  spec says MSBs, LSBs match test vectors
      ::
      (~(sit fe 7) mac)
    ::                                                  ::  ++macc:aes:crypto
    ++  macc                                            :: AES-256 CMAC
      ~/  %macc
      |=  [key=@I oct=(unit @) txt=@]
      ^-  @ux
      =+  [sub=(subc key) len=?~(oct (met 3 txt) u.oct)]
      =+  ^=  pdt
        ?:  &(=((mod len 16) 0) !=(len 0))
          [& txt]
        [| (mpad len txt)]
      =+  ^=  mac
        %-  ~(en cbcc key 0)
        %+  mix  +.pdt
        ?-  -.pdt
          %&  -.sub
          %|  +.sub
        ==
      ::  spec says MSBs, LSBs match test vectors
      ::
      (~(sit fe 7) mac)
    ::                                                  ::  ++s2va:aes:crypto
    ++  s2va                                            ::  AES-128 S2V
      ~/  %s2va
      |=  [key=@H ads=(list @)]
      ?~  ads  (maca key `16 0x1)
      =/  res  (maca key `16 0x0)
      %+  maca  key
      |-  ^-  [[~ @ud] @uxH]
      ?~  t.ads
        =/  wyt  (met 3 i.ads)
        ?:  (gte wyt 16)
          [`wyt (mix i.ads res)]
        [`16 (mix (doub res) (mpad wyt i.ads))]
      %=  $
        ads  t.ads
        res  (mix (doub res) (maca key ~ i.ads))
      ==
    ::                                                  ::  ++s2vb:aes:crypto
    ++  s2vb                                            ::  AES-192 S2V
      ~/  %s2vb
      |=  [key=@I ads=(list @)]
      ?~  ads  (macb key `16 0x1)
      =/  res  (macb key `16 0x0)
      %+  macb  key
      |-  ^-  [[~ @ud] @uxH]
      ?~  t.ads
        =/  wyt  (met 3 i.ads)
        ?:  (gte wyt 16)
          [`wyt (mix i.ads res)]
        [`16 (mix (doub res) (mpad wyt i.ads))]
      %=  $
        ads  t.ads
        res  (mix (doub res) (macb key ~ i.ads))
      ==
    ::                                                  ::  ++s2vc:aes:crypto
    ++  s2vc                                            ::  AES-256 S2V
      ~/  %s2vc
      |=  [key=@I ads=(list @)]
      ?~  ads  (macc key `16 0x1)
      =/  res  (macc key `16 0x0)
      %+  macc  key
      |-  ^-  [[~ @ud] @uxH]
      ?~  t.ads
        =/  wyt  (met 3 i.ads)
        ?:  (gte wyt 16)
          [`wyt (mix i.ads res)]
        [`16 (mix (doub res) (mpad wyt i.ads))]
      %=  $
        ads  t.ads
        res  (mix (doub res) (macc key ~ i.ads))
      ==
    ::                                                  ::  ++siva:aes:crypto
    ++  siva                                            ::  AES-128 SIV
      ~%  %siva  +>  ~
      |_  [key=@I vec=(list @)]
      ::                                                ::  ++en:siva:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  txt=@
        ^-  (trel @uxH @ud @ux)
        =+  [k1=(rsh 7 key) k2=(end 7 key)]
        =+  iv=(s2va k1 (weld vec (limo ~[txt])))
        =+  len=(met 3 txt)
        =*  hib  (dis iv 0xffff.ffff.ffff.ffff.7fff.ffff.7fff.ffff)
        :+
          iv
          len
        (~(en ctra k2 7 len hib) txt)
      ::                                                ::  ++de:siva:aes:crypto
      ++  de                                            ::  decrypt
        ~/  %de
        |=  [iv=@H len=@ txt=@]
        ^-  (unit @ux)
        =+  [k1=(rsh 7 key) k2=(end 7 key)]
        =*  hib  (dis iv 0xffff.ffff.ffff.ffff.7fff.ffff.7fff.ffff)
        =+  ^=  pln
          (~(de ctra k2 7 len hib) txt)
        ?.  =((s2va k1 (weld vec (limo ~[pln]))) iv)
          ~
        `pln
      --  ::siva
    ::                                                  ::  ++sivb:aes:crypto
    ++  sivb                                            ::  AES-192 SIV
      ~%  %sivb  +>  ~
      |_  [key=@J vec=(list @)]
      ::                                                ::  ++en:sivb:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  txt=@
        ^-  (trel @uxH @ud @ux)
        =+  [k1=(rsh [6 3] key) k2=(end [6 3] key)]
        =+  iv=(s2vb k1 (weld vec (limo ~[txt])))
        =*  hib  (dis iv 0xffff.ffff.ffff.ffff.7fff.ffff.7fff.ffff)
        =+  len=(met 3 txt)
        :+  iv
          len
        (~(en ctrb k2 7 len hib) txt)
      ::                                                ::  ++de:sivb:aes:crypto
      ++  de                                            ::  decrypt
        ~/  %de
        |=  [iv=@H len=@ txt=@]
        ^-  (unit @ux)
        =+  [k1=(rsh [6 3] key) k2=(end [6 3] key)]
        =*  hib  (dis iv 0xffff.ffff.ffff.ffff.7fff.ffff.7fff.ffff)
        =+  ^=  pln
          (~(de ctrb k2 7 len hib) txt)
        ?.  =((s2vb k1 (weld vec (limo ~[pln]))) iv)
          ~
        `pln
      --  ::sivb
    ::                                                  ::  ++sivc:aes:crypto
    ++  sivc                                            ::  AES-256 SIV
      ~%  %sivc  +>  ~
      |_  [key=@J vec=(list @)]
      ::                                                ::  ++en:sivc:aes:crypto
      ++  en                                            ::  encrypt
        ~/  %en
        |=  txt=@
        ^-  (trel @uxH @ud @ux)
        =+  [k1=(rsh 8 key) k2=(end 8 key)]
        =+  iv=(s2vc k1 (weld vec (limo ~[txt])))
        =*  hib  (dis iv 0xffff.ffff.ffff.ffff.7fff.ffff.7fff.ffff)
        =+  len=(met 3 txt)
        :+
          iv
          len
        (~(en ctrc k2 7 len hib) txt)
      ::                                                ::  ++de:sivc:aes:crypto
      ++  de                                            ::  decrypt
        ~/  %de
        |=  [iv=@H len=@ txt=@]
        ^-  (unit @ux)
        =+  [k1=(rsh 8 key) k2=(end 8 key)]
        =*  hib  (dis iv 0xffff.ffff.ffff.ffff.7fff.ffff.7fff.ffff)
        =+  ^=  pln
          (~(de ctrc k2 7 len hib) txt)
        ?.  =((s2vc k1 (weld vec (limo ~[pln]))) iv)
          ~
        `pln
      --  ::sivc
    --
  ::                                                    ::
  ::::                    ++ed:crypto                   ::  ed25519
    ::                                                  ::::
  ++  ed
    =>
      =+  =+  [b=256 q=(sub (bex 255) 19)]
          =+  fq=~(. fo q)
          =+  ^=  l
               %+  add
                 (bex 252)
               27.742.317.777.372.353.535.851.937.790.883.648.493
          =+  d=(dif.fq 0 (fra.fq 121.665 121.666))
          =+  ii=(exp.fq (div (dec q) 4) 2)
          [b=b q=q fq=fq l=l d=d ii=ii]
      |%
      ::                                                ::  ++norm:ed:crypto
      ++  norm                                          ::
        |=(x=@ ?:(=(0 (mod x 2)) x (sub q x)))
      ::                                                ::  ++xrec:ed:crypto
      ++  xrec                                          ::  recover x-coord
        |=  y=@  ^-  @
        =+  ^=  xx
            %+  mul  (dif.fq (mul y y) 1)
                     (inv.fq +(:(mul d y y)))
        =+  x=(exp.fq (div (add 3 q) 8) xx)
        ?:  !=(0 (dif.fq (mul x x) (sit.fq xx)))
          (norm (pro.fq x ii))
        (norm x)
      ::                                                ::  ++ward:ed:crypto
      ++  ward                                          ::  edwards multiply
        |=  [pp=[@ @] qq=[@ @]]  ^-  [@ @]
        =+  dp=:(pro.fq d -.pp -.qq +.pp +.qq)
        =+  ^=  xt
            %+  pro.fq
              %+  sum.fq
                (pro.fq -.pp +.qq)
              (pro.fq -.qq +.pp)
            (inv.fq (sum.fq 1 dp))
        =+  ^=  yt
            %+  pro.fq
              %+  sum.fq
                (pro.fq +.pp +.qq)
              (pro.fq -.pp -.qq)
            (inv.fq (dif.fq 1 dp))
        [xt yt]
      ::                                                ::  ++scam:ed:crypto
      ++  scam                                          ::  scalar multiply
        |=  [pp=[@ @] e=@]  ^-  [@ @]
        ?:  =(0 e)
          [0 1]
        =+  qq=$(e (div e 2))
        =>  .(qq (ward qq qq))
        ?:  =(1 (dis 1 e))
          (ward qq pp)
        qq
      ::                                                ::  ++etch:ed:crypto
      ++  etch                                          ::  encode point
        |=  pp=[@ @]  ^-  @
        (can 0 ~[[(sub b 1) +.pp] [1 (dis 1 -.pp)]])
      ::                                                ::  ++curv:ed:crypto
      ++  curv                                          ::  point on curve?
        |=  [x=@ y=@]  ^-  ?
        .=  0
            %+  dif.fq
              %+  sum.fq
                (pro.fq (sub q (sit.fq x)) x)
              (pro.fq y y)
            (sum.fq 1 :(pro.fq d x x y y))
      ::                                                ::  ++deco:ed:crypto
      ++  deco                                          ::  decode point
        |=  s=@  ^-  (unit [@ @])
        =+  y=(cut 0 [0 (dec b)] s)
        =+  si=(cut 0 [(dec b) 1] s)
        =+  x=(xrec y)
        =>  .(x ?:(!=(si (dis 1 x)) (sub q x) x))
        =+  pp=[x y]
        ?.  (curv pp)
          ~
        [~ pp]
      ::                                                ::  ++bb:ed:crypto
      ++  bb                                            ::
        =+  bby=(pro.fq 4 (inv.fq 5))
        [(xrec bby) bby]
      --  ::
    ~%  %ed  +  ~
    |%
    ::
    ++  point-add
      ~/  %point-add
      |=  [a-point=@udpoint b-point=@udpoint]
      ^-  @udpoint
      ::
      =/  a-point-decoded=[@ @]  (need (deco a-point))
      =/  b-point-decoded=[@ @]  (need (deco b-point))
      ::
      %-  etch
      (ward a-point-decoded b-point-decoded)
    ::
    ++  scalarmult
      ~/  %scalarmult
      |=  [a=@udscalar a-point=@udpoint]
      ^-  @udpoint
      ::
      =/  a-point-decoded=[@ @]  (need (deco a-point))
      ::
      %-  etch
      (scam a-point-decoded a)
    ::
    ++  scalarmult-base
      ~/  %scalarmult-base
      |=  scalar=@udscalar
      ^-  @udpoint
      %-  etch
      (scam bb scalar)
    ::
    ++  add-scalarmult-scalarmult-base
      ~/  %add-scalarmult-scalarmult-base
      |=  [a=@udscalar a-point=@udpoint b=@udscalar]
      ^-  @udpoint
      ::
      =/  a-point-decoded=[@ @]  (need (deco a-point))
      ::
      %-  etch
      %+  ward
        (scam bb b)
      (scam a-point-decoded a)
    ::
    ++  add-double-scalarmult
      ~/  %add-double-scalarmult
      |=  [a=@udscalar a-point=@udpoint b=@udscalar b-point=@udpoint]
      ^-  @udpoint
      ::
      =/  a-point-decoded=[@ @]  (need (deco a-point))
      =/  b-point-decoded=[@ @]  (need (deco b-point))
      ::
      %-  etch
      %+  ward
        (scam a-point-decoded a)
      (scam b-point-decoded b)
    ::                                                  ::  ++puck:ed:crypto
    ++  puck                                            ::  public key
      ~/  %puck
      |=  sk=@I  ^-  @
      ?:  (gth (met 3 sk) 32)  !!
      =+  h=(shal (rsh [0 3] b) sk)
      =+  ^=  a
          %+  add
            (bex (sub b 2))
          (lsh [0 3] (cut 0 [3 (sub b 5)] h))
      =+  aa=(scam bb a)
      (etch aa)
    ::                                                  ::  ++suck:ed:crypto
    ++  suck                                            ::  keypair from seed
      |=  se=@I  ^-  @uJ
      =+  pu=(puck se)
      (can 0 ~[[b se] [b pu]])
    ::                                                  ::  ++shar:ed:crypto
    ++  shar                                            ::  curve25519 secret
      ~/  %shar
      |=  [pub=@ sek=@]
      ^-  @ux
      =+  exp=(shal (rsh [0 3] b) (suck sek))
      =.  exp  (dis exp (can 0 ~[[3 0] [251 (fil 0 251 1)]]))
      =.  exp  (con exp (lsh [3 31] 0b100.0000))
      =+  prv=(end 8 exp)
      =+  crv=(fra.fq (sum.fq 1 pub) (dif.fq 1 pub))
      (curt prv crv)
    ::                                                  ::  ++sign:ed:crypto
    ++  sign                                            ::  certify
      ~/  %sign
      |=  [m=@ se=@]  ^-  @
      =+  sk=(suck se)
      =+  pk=(cut 0 [b b] sk)
      =+  h=(shal (rsh [0 3] b) sk)
      =+  ^=  a
          %+  add
            (bex (sub b 2))
          (lsh [0 3] (cut 0 [3 (sub b 5)] h))
      =+  ^=  r
          =+  hm=(cut 0 [b b] h)
          =+  ^=  i
              %+  can  0
              :~  [b hm]
                  [(met 0 m) m]
              ==
          (shaz i)
      =+  rr=(scam bb r)
      =+  ^=  ss
          =+  er=(etch rr)
          =+  ^=  ha
              %+  can  0
              :~  [b er]
                  [b pk]
                  [(met 0 m) m]
              ==
          (~(sit fo l) (add r (mul (shaz ha) a)))
      (can 0 ~[[b (etch rr)] [b ss]])
    ::                                                  ::  ++veri:ed:crypto
    ++  veri                                            ::  validate
      ~/  %veri
      |=  [s=@ m=@ pk=@]  ^-  ?
      ?:  (gth (div b 4) (met 3 s))  |
      ?:  (gth (div b 8) (met 3 pk))  |
      =+  cb=(rsh [0 3] b)
      =+  rr=(deco (cut 0 [0 b] s))
      ?~  rr  |
      =+  aa=(deco pk)
      ?~  aa  |
      =+  ss=(cut 0 [b b] s)
      =+  ha=(can 3 ~[[cb (etch u.rr)] [cb pk] [(met 3 m) m]])
      =+  h=(shaz ha)
      =((scam bb ss) (ward u.rr (scam u.aa h)))
    --  ::ed
  ::                                                    ::
  ::::                    ++scr:crypto                  ::  (2b3) scrypt
    ::                                                  ::::
  ++  scr
    |%
    ::                                                  ::  ++sal:scr:crypto
    ++  sal                                             ::  salsa20 hash
      |=  [x=@ r=@]                                     ::  with r rounds
      ?>  =((mod r 2) 0)                                ::
      =+  few==>(fe .(a 5))
      =+  ^=  rot
        |=  [a=@ b=@]
        (mix (end 5 (lsh [0 a] b)) (rsh [0 (sub 32 a)] b))
      =+  ^=  lea
        |=  [a=@ b=@]
        (net:few (sum:few (net:few a) (net:few b)))
      =>  |%
          ::                                            ::  ++qr:sal:scr:crypto
          ++  qr                                        ::  quarterround
            |=  y=[@ @ @ @ ~]
            =+  zb=(mix &2.y (rot 7 (sum:few &1.y &4.y)))
            =+  zc=(mix &3.y (rot 9 (sum:few zb &1.y)))
            =+  zd=(mix &4.y (rot 13 (sum:few zc zb)))
            =+  za=(mix &1.y (rot 18 (sum:few zd zc)))
            ~[za zb zc zd]
          ::                                            ::  ++rr:sal:scr:crypto
          ++  rr                                        ::  rowround
            |=  [y=(list @)]
            =+  za=(qr ~[&1.y &2.y &3.y &4.y])
            =+  zb=(qr ~[&6.y &7.y &8.y &5.y])
            =+  zc=(qr ~[&11.y &12.y &9.y &10.y])
            =+  zd=(qr ~[&16.y &13.y &14.y &15.y])
            ^-  (list @)  :~
              &1.za  &2.za  &3.za  &4.za
              &4.zb  &1.zb  &2.zb  &3.zb
              &3.zc  &4.zc  &1.zc  &2.zc
              &2.zd  &3.zd  &4.zd  &1.zd  ==
          ::                                            ::  ++cr:sal:scr:crypto
          ++  cr                                        ::  columnround
            |=  [x=(list @)]
            =+  ya=(qr ~[&1.x &5.x &9.x &13.x])
            =+  yb=(qr ~[&6.x &10.x &14.x &2.x])
            =+  yc=(qr ~[&11.x &15.x &3.x &7.x])
            =+  yd=(qr ~[&16.x &4.x &8.x &12.x])
            ^-  (list @)  :~
              &1.ya  &4.yb  &3.yc  &2.yd
              &2.ya  &1.yb  &4.yc  &3.yd
              &3.ya  &2.yb  &1.yc  &4.yd
              &4.ya  &3.yb  &2.yc  &1.yd  ==
          ::                                            ::  ++dr:sal:scr:crypto
          ++  dr                                        ::  doubleround
            |=  [x=(list @)]
            (rr (cr x))
          ::                                            ::  ++al:sal:scr:crypto
          ++  al                                        ::  add two lists
            |=  [a=(list @) b=(list @)]
            |-  ^-  (list @)
            ?~  a  ~  ?~  b  ~
            [i=(sum:few -.a -.b) t=$(a +.a, b +.b)]
          --  ::
      =+  xw=(rpp 5 16 x)
      =+  ^=  ow  |-  ^-  (list @)
                  ?~  r  xw
                  $(xw (dr xw), r (sub r 2))
      (rep 5 (al xw ow))
    ::                                                  ::  ++rpp:scr:crypto
    ++  rpp                                             ::  rip+filler blocks
      |=  [a=bloq b=@ c=@]
      =+  q=(rip a c)
      =+  w=(lent q)
      ?.  =(w b)
        ?.  (lth w b)  (slag (sub w b) q)
        ^+  q  (weld q (reap (sub b (lent q)) 0))
      q
    ::                                                  ::  ++bls:scr:crypto
    ++  bls                                             ::  split to sublists
      |=  [a=@ b=(list @)]
      ?>  =((mod (lent b) a) 0)
      |-  ^-  (list (list @))
      ?~  b  ~
      [i=(scag a `(list @)`b) t=$(b (slag a `(list @)`b))]
    ::                                                  ::  ++slb:scr:crypto
    ++  slb                                             ::
      |=  [a=(list (list @))]
      |-  ^-  (list @)
      ?~  a  ~
      (weld `(list @)`-.a $(a +.a))
    ::                                                  ::  ++sbm:scr:crypto
    ++  sbm                                             ::  scryptBlockMix
      |=  [r=@ b=(list @)]
      ?>  =((lent b) (mul 2 r))
      =+  [x=(snag (dec (mul 2 r)) b) c=0]
      =|  [ya=(list @) yb=(list @)]
      |-  ^-  (list @)
      ?~  b  (flop (weld yb ya))
      =.  x  (sal (mix x -.b) 8)
      ?~  (mod c 2)
        $(c +(c), b +.b, ya [i=x t=ya])
      $(c +(c), b +.b, yb [i=x t=yb])
    ::                                                  ::  ++srm:scr:crypto
    ++  srm                                             ::  scryptROMix
      |=  [r=@ b=(list @) n=@]
      ?>  ?&  =((lent b) (mul 2 r))
              =(n (bex (dec (xeb n))))
              (lth n (bex (mul r 16)))
          ==
      =+  [v=*(list (list @)) c=0]
      =.  v
        |-  ^-  (list (list @))
        =+  w=(sbm r b)
        ?:  =(c n)  (flop v)
        $(c +(c), v [i=[b] t=v], b w)
      =+  x=(sbm r (snag (dec n) v))
      |-  ^-  (list @)
      ?:  =(c n)  x
      =+  q=(snag (dec (mul r 2)) x)
      =+  z=`(list @)`(snag (mod q n) v)
      =+  ^=  w  |-  ^-  (list @)
                 ?~  x  ~  ?~  z  ~
                 [i=(mix -.x -.z) t=$(x +.x, z +.z)]
      $(x (sbm r w), c +(c))
    ::                                                  ::  ++hmc:scr:crypto
    ++  hmc                                             ::  HMAC-SHA-256
      |=  [k=@ t=@]
      (hml k (met 3 k) t (met 3 t))
    ::                                                  ::  ++hml:scr:crypto
    ++  hml                                             ::  w+length
      |=  [k=@ kl=@ t=@ tl=@]
      =>  .(k (end [3 kl] k), t (end [3 tl] t))
      =+  b=64
      =?  k  (gth kl b)  (shay kl k)
      =+  ^=  q  %+  shay  (add b tl)
       (add (lsh [3 b] t) (mix k (fil 3 b 0x36)))
      %+  shay  (add b 32)
      (add (lsh [3 b] q) (mix k (fil 3 b 0x5c)))
    ::                                                  ::  ++pbk:scr:crypto
    ++  pbk                                             :: PBKDF2-HMAC-SHA256
      ~/  %pbk
      |=  [p=@ s=@ c=@ d=@]
      (pbl p (met 3 p) s (met 3 s) c d)
    ::                                                  ::  ++pbl:scr:crypto
    ++  pbl                                             ::  w+length
      ~/  %pbl
      |=  [p=@ pl=@ s=@ sl=@ c=@ d=@]
      =>  .(p (end [3 pl] p), s (end [3 sl] s))
      =+  h=32
      ::
      ::  max key length 1GB
      ::  max iterations 2^28
      ::
      ?>  ?&  (lte d (bex 30))
              (lte c (bex 28))
              !=(c 0)
          ==
      =+  ^=  l  ?~  (mod d h)
          (div d h)
        +((div d h))
      =+  r=(sub d (mul h (dec l)))
      =+  [t=0 j=1 k=1]
      =.  t  |-  ^-  @
        ?:  (gth j l)  t
        =+  u=(add s (lsh [3 sl] (rep 3 (flop (rpp 3 4 j)))))
        =+  f=0  =.  f  |-  ^-  @
          ?:  (gth k c)  f
          =+  q=(hml p pl u ?:(=(k 1) (add sl 4) h))
          $(u q, f (mix f q), k +(k))
        $(t (add t (lsh [3 (mul (dec j) h)] f)), j +(j))
      (end [3 d] t)
    ::                                                  ::  ++hsh:scr:crypto
    ++  hsh                                             ::  scrypt
      ~/  %hsh
      |=  [p=@ s=@ n=@ r=@ z=@ d=@]
      (hsl p (met 3 p) s (met 3 s) n r z d)
    ::                                                  ::  ++hsl:scr:crypto
    ++  hsl                                             ::  w+length
      ~/  %hsl
      |=  [p=@ pl=@ s=@ sl=@ n=@ r=@ z=@ d=@]
      =|  v=(list (list @))
      =>  .(p (end [3 pl] p), s (end [3 sl] s))
      =+  u=(mul (mul 128 r) z)
      ::
      ::  n is power of 2; max 1GB memory
      ::
      ?>  ?&  =(n (bex (dec (xeb n))))
              !=(r 0)  !=(z 0)
              %+  lte
                  (mul (mul 128 r) (dec (add n z)))
                (bex 30)
              (lth pl (bex 31))
              (lth sl (bex 31))
          ==
      =+  ^=  b  =+  (rpp 3 u (pbl p pl s sl 1 u))
        %+  turn  (bls (mul 128 r) -)
        |=(a=(list @) (rpp 9 (mul 2 r) (rep 3 a)))
      ?>  =((lent b) z)
      =+  ^=  q
        =+  |-  ?~  b  (flop v)
            $(b +.b, v [i=(srm r -.b n) t=v])
        %+  turn  `(list (list @))`-
        |=(a=(list @) (rpp 3 (mul 128 r) (rep 9 a)))
      (pbl p pl (rep 3 (slb q)) u 1 d)
    ::                                                  ::  ++ypt:scr:crypto
    ++  ypt                                             ::  256bit {salt pass}
      |=  [s=@ p=@]
      ^-  @
      (hsh p s 16.384 8 1 256)
    --  ::scr
  ::                                                    ::
  ::::                    ++crub:crypto                 ::  (2b4) suite B, Ed
    ::                                                  ::::
  ++  crub  !:
    ^-  acru
    =|  [pub=[cry=@ sgn=@] sek=(unit [cry=@ sgn=@])]
    |%
    ::                                                  ::  ++as:crub:crypto
    ++  as                                              ::
      |%
      ::                                                ::  ++sign:as:crub:
      ++  sign                                          ::
        |=  msg=@
        ^-  @ux
        ?~  sek  !!
        (jam [(sign:ed msg sgn.u.sek) msg])
      ::                                                ::  ++sure:as:crub:
      ++  sure                                          ::
        |=  txt=@
        ^-  (unit @ux)
        =+  ;;([sig=@ msg=@] (cue txt))
        ?.  (veri:ed sig msg sgn.pub)  ~
        (some msg)
      ::                                                ::  ++seal:as:crub:
      ++  seal                                          ::
        |=  [bpk=pass msg=@]
        ^-  @ux
        ?~  sek  !!
        ?>  =('b' (end 3 bpk))
        =+  pk=(rsh 8 (rsh 3 bpk))
        =+  shar=(shax (shar:ed pk cry.u.sek))
        =+  smsg=(sign msg)
        (jam (~(en siva:aes shar ~) smsg))
      ::                                                ::  ++tear:as:crub:
      ++  tear                                          ::
        |=  [bpk=pass txt=@]
        ^-  (unit @ux)
        ?~  sek  !!
        ?>  =('b' (end 3 bpk))
        =+  pk=(rsh 8 (rsh 3 bpk))
        =+  shar=(shax (shar:ed pk cry.u.sek))
        =+  ;;([iv=@ len=@ cph=@] (cue txt))
        =+  try=(~(de siva:aes shar ~) iv len cph)
        ?~  try  ~
        (sure:as:(com:nu:crub bpk) u.try)
      --  ::as
    ::                                                  ::  ++de:crub:crypto
    ++  de                                              ::  decrypt
      |=  [key=@J txt=@]
      ^-  (unit @ux)
      =+  ;;([iv=@ len=@ cph=@] (cue txt))
      %^    ~(de sivc:aes (shaz key) ~)
          iv
        len
      cph
    ::                                                  ::  ++dy:crub:crypto
    ++  dy                                              ::  need decrypt
      |=  [key=@J cph=@]
      (need (de key cph))
    ::                                                  ::  ++en:crub:crypto
    ++  en                                              ::  encrypt
      |=  [key=@J msg=@]
      ^-  @ux
      (jam (~(en sivc:aes (shaz key) ~) msg))
    ::                                                  ::  ++ex:crub:crypto
    ++  ex                                              ::  extract
      |%
      ::                                                ::  ++fig:ex:crub:crypto
      ++  fig                                           ::  fingerprint
        ^-  @uvH
        (shaf %bfig pub)
      ::                                                ::  ++pac:ex:crub:crypto
      ++  pac                                           ::  private fingerprint
        ^-  @uvG
        ?~  sek  !!
        (end 6 (shaf %bcod sec))
      ::                                                ::  ++pub:ex:crub:crypto
      ++  pub                                           ::  public key
        ^-  pass
        (cat 3 'b' (cat 8 sgn.^pub cry.^pub))
      ::                                                ::  ++sec:ex:crub:crypto
      ++  sec                                           ::  private key
        ^-  ring
        ?~  sek  !!
        (cat 3 'B' (cat 8 sgn.u.sek cry.u.sek))
      --  ::ex
    ::                                                  ::  ++nu:crub:crypto
    ++  nu                                              ::
      |%
      ::                                                ::  ++pit:nu:crub:crypto
      ++  pit                                           ::  create keypair
        |=  [w=@ seed=@]
        =+  wid=(add (div w 8) ?:(=((mod w 8) 0) 0 1))
        =+  bits=(shal wid seed)
        =+  [c=(rsh 8 bits) s=(end 8 bits)]
        ..nu(pub [cry=(puck:ed c) sgn=(puck:ed s)], sek `[cry=c sgn=s])
      ::                                                ::  ++nol:nu:crub:crypto
      ++  nol                                           ::  activate secret
        |=  a=ring
        =+  [mag=(end 3 a) bod=(rsh 3 a)]
        ?>  =('B' mag)
        =+  [c=(rsh 8 bod) s=(end 8 bod)]
        ..nu(pub [cry=(puck:ed c) sgn=(puck:ed s)], sek `[cry=c sgn=s])
      ::                                                ::  ++com:nu:crub:crypto
      ++  com                                           ::  activate public
        |=  a=pass
        =+  [mag=(end 3 a) bod=(rsh 3 a)]
        ?>  =('b' mag)
        ..nu(pub [cry=(rsh 8 bod) sgn=(end 8 bod)], sek ~)
      --  ::nu
    --  ::crub
  ::                                                    ::
  ::                                                    ::
  ::::                    ++keccak:crypto               ::  (2b7) keccak family
    ::                                                  ::::
  ++  keccak
    |%
    ::
    ::  keccak
    ::
    ++  keccak-224
      |=  a=octs
      ~>  %k224.+<
      (keccak 1.152 448 224 a)
    ++  keccak-256
      |=  a=octs
      ~>  %k256.+<
      (keccak 1.088 512 256 a)
    ++  keccak-384
      |=  a=octs
      ~>  %k384.+<
      (keccak 832 768 384 a)
    ++  keccak-512
      |=  a=octs
      ~>  %k512.+<
      (keccak 576 1.024 512 a)
    ::
    ++  keccak
      ~>  %this-should-never-print
      (cury (cury hash keccak-f) padding-keccak)
    ::
    ++  padding-keccak  (multirate-padding 0x1)
    ::
    ::  sha3
    ::
    ++  sha3-224  |=(a=octs (sha3 1.152 448 224 a))
    ++  sha3-256  |=(a=octs (sha3 1.088 512 256 a))
    ++  sha3-384  |=(a=octs (sha3 832 768 384 a))
    ++  sha3-512  |=(a=octs (sha3 576 1.024 512 a))
    ::
    ++  sha3  (cury (cury hash keccak-f) padding-sha3)
    ::
    ++  padding-sha3  (multirate-padding 0x6)
    ::
    ::  shake
    ::
    ++  shake-128  |=([o=@ud i=octs] (shake 1.344 256 o i))
    ++  shake-256  |=([o=@ud i=octs] (shake 1.088 512 o i))
    ::
    ++  shake  (cury (cury hash keccak-f) padding-shake)
    ::
    ++  padding-shake  (multirate-padding 0x1f)
    ::
    ::  rawshake
    ::
    ++  rawshake-128  |=([o=@ud i=octs] (rawshake 1.344 256 o i))
    ++  rawshake-256  |=([o=@ud i=octs] (rawshake 1.088 512 o i))
    ::
    ++  rawshake  (cury (cury hash keccak-f) padding-rawshake)
    ::
    ++  padding-rawshake  (multirate-padding 0x7)
    ::
    ::  core
    ::
    ++  hash
      ::  per:  permutation function with configurable width.
      ::  pad:  padding function.
      ::  rat:  bitrate, size in bits of blocks to operate on.
      ::  cap:  capacity, bits of sponge padding.
      ::  out:  length of desired output, in bits.
      ::  inp:  input to hash.
      |=  $:  per=$-(@ud $-(@ @))
              pad=$-([octs @ud] octs)
              rat=@ud
              cap=@ud
              out=@ud
              inp=octs
          ==
      ^-  @
      ::  urbit's little-endian to keccak's big-endian.
      =.  q.inp  (rev 3 inp)
      %.  [inp out]
      (sponge per pad rat cap)
    ::
    ::NOTE  if ++keccak ever needs to be made to operate
    ::      on bits rather than bytes, all that needs to
    ::      be done is updating the way this padding
    ::      function works. (and also "octs" -> "bits")
    ++  multirate-padding
      ::  dsb:  domain separation byte, reverse bit order.
      |=  dsb=@ux
      ?>  (lte dsb 0xff)
      |=  [inp=octs mut=@ud]
      ^-  octs
      =.  mut  (div mut 8)
      =+  pal=(sub mut (mod p.inp mut))
      =?  pal  =(pal 0)  mut
      =.  pal  (dec pal)
      :-  (add p.inp +(pal))
      ::  padding is provided in lane bit ordering,
      ::  ie, LSB = left.
      (cat 3 (con (lsh [3 pal] dsb) 0x80) q.inp)
    ::
    ++  sponge
      ::  sponge construction
      ::
      ::  preperm:  permutation function with configurable width.
      ::  padding:  padding function.
      ::  bitrate:  size of blocks to operate on.
      ::  capacity:  sponge padding.
      |=  $:  preperm=$-(@ud $-(@ @))
              padding=$-([octs @ud] octs)
              bitrate=@ud
              capacity=@ud
          ==
      ::
      ::  preparing
      =+  bitrate-bytes=(div bitrate 8)
      =+  blockwidth=(add bitrate capacity)
      =+  permute=(preperm blockwidth)
      ::
      |=  [input=octs output=@ud]
      |^  ^-  @
        ::
        ::  padding
        =.  input  (padding input bitrate)
        ::
        ::  absorbing
        =/  pieces=(list @)
          ::  amount of bitrate-sized blocks.
          ?>  =(0 (mod p.input bitrate-bytes))
          =+  i=(div p.input bitrate-bytes)
          |-
          ?:  =(i 0)  ~
          :_  $(i (dec i))
          ::  get the bitrate-sized block of bytes
          ::  that ends with the byte at -.
          =-  (cut 3 [- bitrate-bytes] q.input)
          (mul (dec i) bitrate-bytes)
        =/  state=@
          ::  for every piece,
          %+  roll  pieces
          |=  [p=@ s=@]
          ::  pad with capacity,
          =.  p  (lsh [0 capacity] p)
          ::  xor it into the state and permute it.
          (permute (mix s (bytes-to-lanes p)))
        ::
        ::  squeezing
        =|  res=@
        =|  len=@ud
        |-
        ::  append a bitrate-sized head of state to the
        ::  result.
        =.  res
          %+  con  (lsh [0 bitrate] res)
          (rsh [0 capacity] (lanes-to-bytes state))
        =.  len  (add len bitrate)
        ?:  (gte len output)
          ::  produce the requested bits of output.
          (rsh [0 (sub len output)] res)
        $(res res, state (permute state))
      ::
      ++  bytes-to-lanes
        ::  flip byte order in blocks of 8 bytes.
        |=  a=@
        %^  run  6  a
        |=(b=@ (lsh [3 (sub 8 (met 3 b))] (swp 3 b)))
      ::
      ++  lanes-to-bytes
        ::  unflip byte order in blocks of 8 bytes.
        |=  a=@
        %+  can  6
        %+  turn
          =+  (rip 6 a)
          (weld - (reap (sub 25 (lent -)) 0x0))
        |=  a=@
        :-  1
        %+  can  3
        =-  (turn - |=(a=@ [1 a]))
        =+  (flop (rip 3 a))
        (weld (reap (sub 8 (lent -)) 0x0) -)
      --
    ::
    ++  keccak-f
      ::  keccak permutation function
      |=  [width=@ud]
      ::  assert valid blockwidth.
      ?>  =-  (~(has in -) width)
          (sy 25 50 100 200 400 800 1.600 ~)
      ::  assumes 5x5 lanes state, as is the keccak
      ::  standard.
      =+  size=5
      =+  lanes=(mul size size)
      =+  lane-bloq=(dec (xeb (div width lanes)))
      =+  lane-size=(bex lane-bloq)
      =+  rounds=(add 12 (mul 2 lane-bloq))
      |=  [input=@]
      ^-  @
      =*  a  input
      =+  round=0
      |^
        ?:  =(round rounds)  a
        ::
        ::  theta
        =/  c=@
          %+  roll  (gulf 0 (dec size))
          |=  [x=@ud c=@]
          %+  con  (lsh [lane-bloq 1] c)
          %+  roll  (gulf 0 (dec size))
          |=  [y=@ud c=@]
          (mix c (get-lane x y a))
        =/  d=@
          %+  roll  (gulf 0 (dec size))
          |=  [x=@ud d=@]
          %+  con  (lsh [lane-bloq 1] d)
          %+  mix
            =-  (get-word - size c)
            ?:(=(x 0) (dec size) (dec x))
          %^  ~(rol fe lane-bloq)  0  1
          (get-word (mod +(x) size) size c)
        =.  a
          %+  roll  (gulf 0 (dec lanes))
          |=  [i=@ud a=_a]
          %+  mix  a
          %+  lsh
            [lane-bloq (sub lanes +(i))]
          (get-word i size d)
        ::
        ::  rho and pi
        =/  b=@
          %+  roll  (gulf 0 (dec lanes))
          |=  [i=@ b=@]
          =+  x=(mod i 5)
          =+  y=(div i 5)
          %+  con  b
          %+  lsh
            :-  lane-bloq
            %+  sub  lanes
            %+  add  +(y)
            %+  mul  size
            (mod (add (mul 2 x) (mul 3 y)) size)
          %^  ~(rol fe lane-bloq)  0
            (rotation-offset i)
          (get-word i lanes a)
        ::
        ::  chi
        =.  a
          %+  roll  (gulf 0 (dec lanes))
          |=  [i=@ud a=@]
          %+  con  (lsh lane-bloq a)
          =+  x=(mod i 5)
          =+  y=(div i 5)
          %+  mix  (get-lane x y b)
          %+  dis
            =-  (get-lane - y b)
            (mod (add x 2) size)
          %^  not  lane-bloq  1
          (get-lane (mod +(x) size) y b)
        ::
        ::  iota
        =.  a
          =+  (round-constant round)
          (mix a (lsh [lane-bloq (dec lanes)] -))
        ::
        ::  next round
        $(round +(round))
      ::
      ++  get-lane
        ::  get the lane with coordinates
        |=  [x=@ud y=@ud a=@]
        =+  i=(add x (mul size y))
        (get-word i lanes a)
      ::
      ++  get-word
        ::  get word {n} from atom {a} of {m} words.
        |=  [n=@ud m=@ud a=@]
        (cut lane-bloq [(sub m +((mod n m))) 1] a)
      ::
      ++  round-constant
        |=  c=@ud
        =-  (snag (mod c 24) -)
        ^-  (list @ux)
        :~  0x1
            0x8082
            0x8000.0000.0000.808a
            0x8000.0000.8000.8000
            0x808b
            0x8000.0001
            0x8000.0000.8000.8081
            0x8000.0000.0000.8009
            0x8a
            0x88
            0x8000.8009
            0x8000.000a
            0x8000.808b
            0x8000.0000.0000.008b
            0x8000.0000.0000.8089
            0x8000.0000.0000.8003
            0x8000.0000.0000.8002
            0x8000.0000.0000.0080
            0x800a
            0x8000.0000.8000.000a
            0x8000.0000.8000.8081
            0x8000.0000.0000.8080
            0x8000.0001
            0x8000.0000.8000.8008
        ==
      ::
      ++  rotation-offset
        |=  x=@ud
        =-  (snag x -)
        ^-  (list @ud)
        :~   0   1  62  28  27
            36  44   6  55  20
             3  10  43  25  39
            41  45  15  21   8
            18   2  61  56  14
        ==
      --
    --  ::keccak
  ::                                                    ::
  ::::                    ++hmac:crypto                 ::  (2b8) hmac family
    ::                                                  ::::
  ++  hmac
    =,  sha
    =>  |%
        ++  meet  |=([k=@ m=@] [[(met 3 k) k] [(met 3 m) m]])
        ++  flip  |=([k=@ m=@] [(swp 3 k) (swp 3 m)])
        --
    |%
    ::
    ::  use with @
    ::
    ++  hmac-sha1     (cork meet hmac-sha1l)
    ++  hmac-sha256   (cork meet hmac-sha256l)
    ++  hmac-sha512   (cork meet hmac-sha512l)
    ::
    ::  use with @t
    ::
    ++  hmac-sha1t    (cork flip hmac-sha1)
    ++  hmac-sha256t  (cork flip hmac-sha256)
    ++  hmac-sha512t  (cork flip hmac-sha512)
    ::
    ::  use with byts
    ::
    ++  hmac-sha1l    (cury hmac sha-1l 64 20)
    ++  hmac-sha256l  (cury hmac sha-256l 64 32)
    ++  hmac-sha512l  (cury hmac sha-512l 128 64)
    ::
    ::  main logic
    ::
    ++  hmac
      ~/  %hmac
      ::  boq: block size in bytes used by haj
      ::  out: bytes output by haj
      |*  [[haj=$-([@u @] @) boq=@u out=@u] key=byts msg=byts]
      ::  ensure key and message fit signaled lengths
      =.  dat.key  (end [3 wid.key] dat.key)
      =.  dat.msg  (end [3 wid.msg] dat.msg)
      ::  keys longer than block size are shortened by hashing
      =?  dat.key  (gth wid.key boq)  (haj wid.key dat.key)
      =?  wid.key  (gth wid.key boq)  out
      ::  keys shorter than block size are right-padded
      =?  dat.key  (lth wid.key boq)  (lsh [3 (sub boq wid.key)] dat.key)
      ::  pad key, inner and outer
      =+  kip=(mix dat.key (fil 3 boq 0x36))
      =+  kop=(mix dat.key (fil 3 boq 0x5c))
      ::  append inner padding to message, then hash
      =+  (haj (add wid.msg boq) (add (lsh [3 wid.msg] kip) dat.msg))
      ::  prepend outer padding to result, hash again
      (haj (add out boq) (add (lsh [3 out] kop) -))
    --  ::  hmac
  ::                                                    ::
  ::::                    ++secp:crypto                 ::  (2b9) secp family
    ::                                                  ::::
  ++  secp  !.
    ::  TODO: as-octs and hmc are outside of jet parent
    |%
    :: as-octs from as-octs:mimes:html
    ++  as-octs                                         ::  atom to octstream
      |=  tam=@  ^-  octs
      [(met 3 tam) tam]
    :: end as-octs
    +$  jacobian   [x=@ y=@ z=@]                    ::  jacobian point
    +$  point      [x=@ y=@]                        ::  curve point
    +$  domain
      $:  p=@                                       ::  prime modulo
          a=@                                       ::  y^2=x^3+ax+b
          b=@                                       ::
          g=point                                   ::  base point
          n=@                                       ::  prime order of g
      ==
    ++  secp
      |_  [bytes=@ =domain]
      ++  field-p  ~(. fo p.domain)
      ++  field-n  ~(. fo n.domain)
      ++  compress-point
        |=  =point
        ^-  @
        %+  can  3
        :~  [bytes x.point]
            [1 (add 2 (cut 0 [0 1] y.point))]
        ==
      ::
      ++  serialize-point
        |=  =point
        ^-  @
        %+  can  3
        :~  [bytes y.point]
            [bytes x.point]
            [1 4]
        ==
      ::
      ++  decompress-point
        |=  compressed=@
        ^-  point
        =/  x=@  (end [3 bytes] compressed)
        ?>  =(3 (mod p.domain 4))
        =/  fop  field-p
        =+  [fadd fmul fpow]=[sum.fop pro.fop exp.fop]
        =/  y=@  %+  fpow  (rsh [0 2] +(p.domain))
                 %+  fadd  b.domain
                 %+  fadd  (fpow 3 x)
                (fmul a.domain x)
        =/  s=@  (rsh [3 bytes] compressed)
        ?>  |(=(2 s) =(3 s))
        ::  check parity
        ::
        =?  y  !=((sub s 2) (mod y 2))
          (sub p.domain y)
        [x y]
      ::
      ++  jc                                        ::  jacobian math
        |%
        ++  from
          |=  a=jacobian
          ^-  point
          =/  fop   field-p
          =+  [fmul fpow finv]=[pro.fop exp.fop inv.fop]
          =/  z  (finv z.a)
          :-  (fmul x.a (fpow 2 z))
          (fmul y.a (fpow 3 z))
        ::
        ++  into
          |=  point
          ^-  jacobian
          [x y 1]
        ::
        ++  double
          |=  jacobian
          ^-  jacobian
          ?:  =(0 y)  [0 0 0]
          =/  fop  field-p
          =+  [fadd fsub fmul fpow]=[sum.fop dif.fop pro.fop exp.fop]
          =/  s    :(fmul 4 x (fpow 2 y))
          =/  m    %+  fadd
                     (fmul 3 (fpow 2 x))
                   (fmul a.domain (fpow 4 z))
          =/  nx   %+  fsub
                     (fpow 2 m)
                   (fmul 2 s)
          =/  ny  %+  fsub
                    (fmul m (fsub s nx))
                  (fmul 8 (fpow 4 y))
          =/  nz  :(fmul 2 y z)
          [nx ny nz]
        ::
        ++  add
          |=  [a=jacobian b=jacobian]
          ^-  jacobian
          ?:  =(0 y.a)  b
          ?:  =(0 y.b)  a
          =/  fop  field-p
          =+  [fadd fsub fmul fpow]=[sum.fop dif.fop pro.fop exp.fop]
          =/  u1  :(fmul x.a z.b z.b)
          =/  u2  :(fmul x.b z.a z.a)
          =/  s1  :(fmul y.a z.b z.b z.b)
          =/  s2  :(fmul y.b z.a z.a z.a)
          ?:  =(u1 u2)
            ?.  =(s1 s2)
              [0 0 1]
            (double a)
          =/  h     (fsub u2 u1)
          =/  r     (fsub s2 s1)
          =/  h2    (fmul h h)
          =/  h3    (fmul h2 h)
          =/  u1h2  (fmul u1 h2)
          =/  nx    %+  fsub
                      (fmul r r)
                    :(fadd h3 u1h2 u1h2)
          =/  ny    %+  fsub
                      (fmul r (fsub u1h2 nx))
                    (fmul s1 h3)
          =/  nz    :(fmul h z.a z.b)
          [nx ny nz]
        ::
        ++  mul
          |=  [a=jacobian scalar=@]
          ^-  jacobian
          ?:  =(0 y.a)
            [0 0 1]
          ?:  =(0 scalar)
            [0 0 1]
          ?:  =(1 scalar)
            a
          ?:  (gte scalar n.domain)
            $(scalar (mod scalar n.domain))
          ?:  =(0 (mod scalar 2))
            (double $(scalar (rsh 0 scalar)))
          (add a (double $(scalar (rsh 0 scalar))))
        --
      ++  add-points
        |=  [a=point b=point]
        ^-  point
        =/  j  jc
        (from.j (add.j (into.j a) (into.j b)))
      ++  mul-point-scalar
        |=  [p=point scalar=@]
        ^-  point
        =/  j  jc
        %-  from.j
        %+  mul.j
          (into.j p)
        scalar
      ::
      ++  valid-hash
        |=  has=@
        (lte (met 3 has) bytes)
      ::
      ++  in-order
        |=  i=@
        ?&  (gth i 0)
            (lth i n.domain)
        ==
      ++  priv-to-pub
        |=  private-key=@
        ^-  point
        ?>  (in-order private-key)
        (mul-point-scalar g.domain private-key)
      ::
      ++  make-k
        |=  [hash=@ private-key=@]
        ^-  @
        ?>  (in-order private-key)
        ?>  (valid-hash hash)
        =/  v  (fil 3 bytes 1)
        =/  k  0
        =.  k  %+  hmac-sha256l:hmac  [bytes k]
               %-  as-octs
               %+  can  3
               :~  [bytes hash]
                   [bytes private-key]
                   [1 0]
                   [bytes v]
               ==
        =.  v  (hmac-sha256l:hmac bytes^k bytes^v)
        =.  k  %+  hmac-sha256l:hmac  [bytes k]
               %-  as-octs
               %+  can  3
               :~  [bytes hash]
                   [bytes private-key]
                   [1 1]
                   [bytes v]
               ==
        =.  v  (hmac-sha256l:hmac bytes^k bytes^v)
        (hmac-sha256l:hmac bytes^k bytes^v)
      ::
      ++  ecdsa-raw-sign
        |=  [hash=@ private-key=@]
        ^-  [r=@ s=@ y=@]
        ::  make-k and priv-to pub will validate inputs
        =/  k   (make-k hash private-key)
        =/  rp  (priv-to-pub k)
        =*  r   x.rp
        ?<  =(0 r)
        =/  fon  field-n
        =+  [fadd fmul finv]=[sum.fon pro.fon inv.fon]
        =/  s  %+  fmul  (finv k)
               %+  fadd  hash
               %+  fmul  r
               private-key
        ?<  =(0 s)
        [r s y.rp]
      ::  general recovery omitted, but possible
      --
    ++  secp256k1
      ~%  %secp256k1  +  ~
      |%
      ++  t  :: in the battery for jet matching
        ^-  domain
        :*  0xffff.ffff.ffff.ffff.ffff.ffff.ffff.ffff.
            ffff.ffff.ffff.ffff.ffff.fffe.ffff.fc2f
            0
            7
            :-  0x79be.667e.f9dc.bbac.55a0.6295.ce87.0b07.
                  029b.fcdb.2dce.28d9.59f2.815b.16f8.1798
                0x483a.da77.26a3.c465.5da4.fbfc.0e11.08a8.
                  fd17.b448.a685.5419.9c47.d08f.fb10.d4b8
            0xffff.ffff.ffff.ffff.ffff.ffff.ffff.fffe.
              baae.dce6.af48.a03b.bfd2.5e8c.d036.4141
        ==
      ::
      ++  curve             ~(. secp 32 t)
      ++  serialize-point   serialize-point:curve
      ++  compress-point    compress-point:curve
      ++  decompress-point  decompress-point:curve
      ++  add-points        add-points:curve
      ++  mul-point-scalar  mul-point-scalar:curve
      ++  make-k
        |=  [hash=@uvI private-key=@]
        ~>  %make.+<
        ::  checks sizes
        (make-k:curve hash private-key)
      ++  priv-to-pub
        |=  private-key=@
        ::  checks sizes
        (priv-to-pub:curve private-key)
      ::
      ++  ecdsa-raw-sign
        |=  [hash=@uvI private-key=@]
        ~>  %sign.+<
        ^-  [v=@ r=@ s=@]
        =/  c  curve
        ::  raw-sign checks sizes
        =+  (ecdsa-raw-sign.c hash private-key)
        =/  rp=point  [r y]
        =/  s-high  (gte (mul 2 s) n.domain.c)
        =?  s   s-high
          (sub n.domain.c s)
        =?  rp  s-high
          [x.rp (sub p.domain.c y.rp)]
        =/  v   (end 0 y.rp)
        =?  v   (gte x.rp n.domain.c)
          (add v 2)
        [v x.rp s]
      ::
      ++  ecdsa-raw-recover
        |=  [hash=@ sig=[v=@ r=@ s=@]]
        ~>  %reco.+<
        ^-  point
        ?>  (lte v.sig 3)
        =/  c   curve
        ?>  (valid-hash.c hash)
        ?>  (in-order.c r.sig)
        ?>  (in-order.c s.sig)
        =/  x  ?:  (gte v.sig 2)
                 (add r.sig n.domain.c)
               r.sig
        =/  fop  field-p.c
        =+  [fadd fmul fpow]=[sum.fop pro.fop exp.fop]
        =/  ysq   (fadd (fpow 3 x) b.domain.c)
        =/  beta  (fpow (rsh [0 2] +(p.domain.c)) ysq)
        =/  y  ?:  =((end 0 v.sig) (end 0 beta))
                 beta
               (sub p.domain.c beta)
        ?>  =(0 (dif.fop ysq (fmul y y)))
        =/  nz   (sub n.domain.c hash)
        =/  j    jc.c
        =/  gz   (mul.j (into.j g.domain.c) nz)
        =/  xy   (mul.j (into.j x y) s.sig)
        =/  qr   (add.j gz xy)
        =/  qj   (mul.j qr (inv:field-n.c x))
        =/  pub  (from.j qj)
        ?<  =([0 0] pub)
        pub
      --
    --
  --  ::crypto
--
