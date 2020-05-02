Demonstrating `create.author`:

```unison
def1 = 1
def2 = 2
```

```ucm
  ☝️  The namespace .foo is empty.

.foo> add

  ⍟ I've added these definitions:
  
    def1 : Nat
    def2 : Nat

.foo> create.author alicecoder "Alice McGee"

  Added definitions:
  
    1. metadata.authors.alicecoder          : Author
    2. metadata.authors.alicecoder.guid     : GUID
    3. metadata.copyrightHolders.alicecoder : CopyrightHolder
  
  Tip: Add License values for alicecoder under metadata.

.foo> view 3

  metadata.copyrightHolders.alicecoder : CopyrightHolder
  metadata.copyrightHolders.alicecoder =
    CopyrightHolder alicecoder.guid "Alice McGee"

.foo> link metadata.authors.alicecoder def1 def2

  Updates:
  
    1. foo.def1 : Nat
       + 2. authors.alicecoder : Author
    
    3. foo.def2 : Nat
       + 4. authors.alicecoder : Author

```
