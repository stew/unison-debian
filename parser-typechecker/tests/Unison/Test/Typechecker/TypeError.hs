{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Unison.Test.Typechecker.TypeError where

import           Data.Foldable                (toList)
import           Data.Maybe                   (isJust)
import           EasyTest
import           Unison.Parser                (Ann)
import           Unison.Result                (pattern Result)
import qualified Unison.Result                as Result
import           Unison.Symbol                (Symbol)
import qualified Unison.Typechecker.Context   as C
import           Unison.Typechecker.Extractor (ErrorExtractor)
import qualified Unison.Typechecker.Extractor as Ex
import qualified Unison.Typechecker.TypeError as Err
import           Unison.Var                   (Var)
import qualified Unison.Test.Common as Common

test :: Test ()
test = scope "> extractor" . tests $
  [ y "> true && 3" Err.and
  , y "> true || 3" Err.or
  , y "> if 3 then 1 else 2" Err.cond
  , y "> if true then 1 else \"surprise\"" Err.ifBody
  , y "> match 3 with 3 | 3 -> 3" Err.matchGuard
  , y "> match 3 with\n 3 -> 3\n 4 -> \"surprise\"" Err.matchBody
  -- , y "> match 3 with true -> true" Err.
  , y "> [1, +1]" Err.vectorBody
  , n "> true && ((x -> x + 1) true)" Err.and
  , n "> true || ((x -> x + 1) true)" Err.or
  , n "> if ((x -> x + 1) true) then 1 else 2" Err.cond
  , n "> match 3 with 3 | 3 -> 3" Err.matchBody
  , y "> 1 1" Err.applyingNonFunction
  , y "> 1 Int.+ 1" Err.applyingFunction
  , y ( "ability Abort where\n" ++
        "  abort : {Abort} a\n" ++
        "\n" ++
        "xyz : t -> Request Abort t -> t\n" ++
        "xyz default abort = match abort with\n" ++
        "  {a} -> 3\n" ++
        "  {Abort.abort -> k} ->\n" ++
        "    handle k 100 with xyz default\n"
      ) Err.matchBody
  ]
  where y, n :: String -> ErrorExtractor Symbol Ann a -> Test ()
        y s ex = scope s $ expect $ yieldsError s ex
        n s ex = scope s $ expect $ noYieldsError s ex

noYieldsError :: Var v => String -> ErrorExtractor v Ann a -> Bool
noYieldsError s ex = not $ yieldsError s ex

yieldsError :: forall v a. Var v => String -> ErrorExtractor v Ann a -> Bool
yieldsError s ex = let
  Result notes (Just _) = Common.parseAndSynthesizeAsFile [] "> test" s
  notes' :: [C.ErrorNote v Ann]
  notes' = [ n | Result.TypeError n <- toList notes ]
  in any (isJust . Ex.extract ex) notes'
