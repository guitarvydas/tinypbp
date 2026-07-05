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
