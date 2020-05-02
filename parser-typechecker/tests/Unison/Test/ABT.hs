{-# Language OverloadedStrings #-}

module Unison.Test.ABT where

import Data.Set as Set
import EasyTest
import Unison.ABT as ABT
import Unison.Symbol (Symbol(..))
import Unison.Var as Var
import           Unison.Codebase.Serialization    ( getFromBytes, putBytes )
import qualified Unison.Codebase.Serialization.V1 as V1

test :: Test ()
test = scope "abt" $ tests [
  scope "freshInBoth" $
    let
      t1 = var 1 "a"
      t2 = var 0 "a"
      fresh = ABT.freshInBoth t1 t2 $ symbol 0 "a"
    in tests
      [ scope "first"  $ expect (not $ Set.member fresh (ABT.freeVars t1))
      , scope "second" $ expect (not $ Set.member fresh (ABT.freeVars t2))
      ],
  scope "rename" $ do
    -- rename x to a in \a  -> [a, x] should yield
    --                  \a1 -> [a1, a]
    let t1 = ABT.abs (symbol 0 "a") (ABT.tm [var 0 "a", var 0 "x"])
        t2 = ABT.rename (symbol 0 "x") (symbol 0 "a") t1
        fvs = toList . ABT.freeVars $ t2
    -- make sure the variable wasn't captured
    expectEqual fvs [symbol 0 "a"]
    -- make sure the resulting term is alpha equiv to \a1 -> [a1, a]
    expectEqual t2 (ABT.abs (symbol 0 "b") (ABT.tm [var 0 "b", var 0 "a"])),

  -- confirmation of fix for https://github.com/unisonweb/unison/issues/1388
  -- where symbols with nonzero freshIds did not round trip
  scope "putSymbol" $ let
    v = Symbol 10 (User "hi")
    v' = getFromBytes V1.getSymbol (putBytes V1.putSymbol v)
    in expectEqual (Just v) v'
  ]
  where
    symbol i n = Symbol i (Var.User n)
    var i n = ABT.var $ symbol i n
