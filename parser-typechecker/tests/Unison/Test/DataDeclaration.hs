{-# LANGUAGE OverloadedStrings, QuasiQuotes #-}

module Unison.Test.DataDeclaration where

import qualified Data.Map               as Map
import           Data.Map                ( Map, (!) )
import           EasyTest
import           Text.RawString.QQ
import qualified Unison.DataDeclaration as DD
import           Unison.DataDeclaration  ( DataDeclaration'(..), Decl, hashDecls )
import qualified Unison.Hash            as Hash
import           Unison.Parser           ( Ann )
import           Unison.Parsers          ( unsafeParseFile )
import qualified Unison.Reference       as R
import           Unison.Symbol           ( Symbol )
import qualified Unison.Test.Common     as Common
import qualified Unison.Type            as Type
import           Unison.UnisonFile       ( UnisonFile(..) )
import qualified Unison.Var             as Var

test :: Test ()
test = scope "datadeclaration" $
  let Right hashes = hashDecls . (snd <$>) . dataDeclarationsId $ file
      hashMap = Map.fromList $ fmap (\(a,b,_) -> (a,b)) hashes
      hashOf k = Map.lookup (Var.named k) hashMap
  in tests [
    scope "Bool == Bool'" . expect $ hashOf "Bool" == hashOf "Bool'",
    scope "Bool != Option'" . expect $ hashOf "Bool" /= hashOf "Option'",
    scope "Option == Option'" . expect $ hashOf "Option" == hashOf "Option'",
    scope "List == List'" . expect $ hashOf "List" == hashOf "List'",
    scope "List != SnocList" . expect $ hashOf "List" /= hashOf "SnocList",
    scope "Ping != Pong" . expect $ hashOf "Ping" /= hashOf "Pong",
    scope "Ping == Ling'" . expect $ hashOf "Ping" == hashOf "Ling'",
    scope "Pong == Long'" . expect $ hashOf "Pong" == hashOf "Long'",
    scope "unhashComponent" unhashComponentTest
  ]

file :: UnisonFile Symbol Ann
file = flip unsafeParseFile Common.parsingEnv $ [r|

type Bool = True | False
type Bool' = False | True

type Option a = Some a | None
type Option' b = Nothing | Just b

type List a = Nil | Cons a (List a)
type List' b = Prepend b (List' b) | Empty
type SnocList a = Snil | Snoc (List a) a

type ATree a = Tree a (List (ATree a)) | Leaf (Option a)

type Ping a = Ping a (Pong a)
type Pong a = Pnong | Pong (Ping a)

type Long' a = Long' (Ling' a) | Lnong
type Ling' a = Ling' a (Long' a)
|]


-- faketest = scope "termparser" . tests . map parses $
--   ["x"
--   , "match x with\n" ++
--     "  {Pair x y} -> 1\n" ++
--     "  {State.set 42 -> k} -> k 42\n"
--   ]
--
-- builtins = Map.fromList
--   [("Pair", (R.Builtin "Pair", 0)),
--    ("State.set", (R.Builtin "State", 0))]
--
-- parses s = scope s $ do
--   let p = unsafeParseTerm s builtins :: Term Symbol
--   noteScoped $ "parsing: " ++ s ++ "\n  " ++ show p
--   ok

unhashComponentTest :: Test ()
unhashComponentTest = tests
  [ scope "invented-vars-are-fresh" inventedVarsFreshnessTest
  ]
  where
    inventedVarsFreshnessTest =
      let
        var = Type.var ()
        app = Type.app ()
        forall = Type.forall ()
        (-->) = Type.arrow ()
        h = Hash.unsafeFromBase32Hex "abcd"
        ref = R.Derived h 0 1
        a = Var.refNamed ref
        b = Var.named "b"
        nil = Var.named "Nil"
        cons = Var.refNamed ref
        listRef = ref
        listType = Type.ref () listRef
        listDecl = DataDeclaration {
          modifier = DD.Structural,
          annotation = (),
          bound = [],
          constructors' =
           [ ((), nil, forall a (listType `app` var a))
           , ((), cons, forall b (var b --> listType `app` var b --> listType `app` var b))
           ]
        }
        component :: Map R.Reference (Decl Symbol ())
        component = Map.singleton listRef (Right listDecl)
        component' :: Map R.Reference (Symbol, Decl Symbol ())
        component' = DD.unhashComponent component
        (listVar, Right listDecl') = component' ! listRef
        listType' = var listVar
        constructors = Map.fromList $ DD.constructors listDecl'
        nilType' = constructors ! nil
        z = Var.named "z"
      in tests
        [ -- check that `nil` constructor's type did not collapse to `forall a. a a`,
          -- which would happen if the var invented for `listRef` was simply `Var.refNamed listRef`
          expectEqual (forall z (listType' `app` var z)) nilType'
        , -- check that the variable assigned to `listRef` is different from `cons`,
          -- which would happen if the var invented for `listRef` was simply `Var.refNamed listRef`
          expectNotEqual cons listVar
        ]
