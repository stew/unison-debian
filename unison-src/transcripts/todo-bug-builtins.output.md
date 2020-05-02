# The `todo` and `bug` builtin

`todo` and `bug` have type `a -> b`. They take a message or a value of type `a` and crash during runtime displaying `a` in ucm.
```unison
> todo "implement me later"
```

```ucm

  ✅
  
  scratch.u changed.
  
  Now evaluating any watch expressions (lines starting with
  `>`)... Ctrl+C cancels.

  💔💥
  
  I've encountered a call to builtin.todo with the following
  value:
  
    "implement me later"
  
  I'm sorry this message doesn't have more detail about the
  location of the failure. My makers plan to fix this in a
  future release. 😢

```
```unison
> bug "there's a bug in my code"
```

```ucm

  ✅
  
  scratch.u changed.
  
  Now evaluating any watch expressions (lines starting with
  `>`)... Ctrl+C cancels.

  💔💥
  
  I've encountered a call to builtin.bug with the following
  value:
  
    "there's a bug in my code"
  
  I'm sorry this message doesn't have more detail about the
  location of the failure. My makers plan to fix this in a
  future release. 😢

```
## Todo
`todo` is useful if you want to come back to a piece of code later but you want your project to compile.
```unison
complicatedMathStuff x = todo "Come back and to something with x here"
```

```ucm

  I found and typechecked these definitions in scratch.u. If you
  do an `add` or `update`, here's how your codebase would
  change:
  
    ⍟ These new definitions are ok to `add`:
    
      complicatedMathStuff : x -> 𝕣

```
## Bug
`bug` is used to indicate that a particular branch is not expected to execute.
```unison
test = match true with
    true -> "Yay"
    false -> bug "Wow, that's unexpected"
```

```ucm

  I found and typechecked these definitions in scratch.u. If you
  do an `add` or `update`, here's how your codebase would
  change:
  
    ⍟ These new definitions are ok to `add`:
    
      test : Text

```
