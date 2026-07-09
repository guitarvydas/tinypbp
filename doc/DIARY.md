1. drew diagrams of mevent, Leaf part template, Container part template
2. extended diagrams to include template-registry, Leaf ė and Container ė
3. Began writing `tpbp.st` ("tiny pbp in small text"), referring to diagrams, thiking in terms of bytes
- created deflink &name
deflink &wire
deflink &reg

def3bytes StringIndex
defbytesymbol Dir {down up across through}

defbyte SenderIX
defbyte SenderPortIX
defbyte ReceiverIX
defbyte ReceiverPortIX

- created defstruct where each field is defined by a type (as per defXXX above) and, maybe, synonyms for the field
- `deflink` is meant to be a `next` pointer for each struct, it can compile to a pointer or to nothing in the case of implementing these things as arrays

--- July 5, 2026 ---

began writing `tbpb.st`
- data structures
- defproc conditional-deliver
- defproc deliver-atomically
- stubbed in defproc register-container
- stubbed in defproc register-leaf
- defproc instantiate-part
- defproc instantiate-container
- defproc instantiate-leaf
- defproc container-reset
- deleted routngs (historical)
- stopped 
  - to consider visit-order queue
  - to remember prioritization for probes
```
def push_mevent (parent,receiver,inq,m):               #line 287
    inq.append ( m)                                    #line 288
    if ( receiver.special):                            #line 289
        parent.visit_ordering.appendleft ( receiver)   #line 290
    else:                                              #line 291
        parent.visit_ordering.append ( receiver)       #line 292#line 293#line 294#line 295#line 296
```
- need to understand `tick`
- add %with-container wrapper
- add %with-cause wrapper
- add high-priority
- add %fresh-ready-list
- documentation levels .xxx{..yyy{...zzz{}}}

--- JUly 8, 2026 ---

- decide to keep high level syntax more Python-like
- use `$with-container (self)` to mean to push `self` onto a pre-existing stack that contains only containers (which avoids needing to pass-through the self argument to functions to deeper functions)
