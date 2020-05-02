 Example uses of the `names` command and output
```unison
type IntTriple = IntTriple (Int, Int, Int)
intTriple = IntTriple(+1, +1, +1)
```

```ucm
.> alias.type IntTriple namespc.another.TripleInt

  Done.

.> alias.term intTriple namespc.another.tripleInt

  Done.

.> names IntTriple

  Type
  Hash:  #170h4ackk7
  Names: IntTriple namespc.another.TripleInt
  
  Term
  Hash:   #170h4ackk7#0
  Names:  IntTriple.IntTriple

.> names intTriple

  Term
  Hash:   #uif14vd2oj
  Names:  intTriple namespc.another.tripleInt

```
