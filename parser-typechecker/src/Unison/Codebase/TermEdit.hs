module Unison.Codebase.TermEdit where

import Unison.Hashable (Hashable)
import qualified Unison.Hashable as H
import Unison.Reference (Reference)
import qualified Unison.Typechecker as Typechecker
import Unison.Type (Type)
import Unison.Var (Var)

data TermEdit = Replace Reference Typing | Deprecate
  deriving (Eq, Ord, Show)

references :: TermEdit -> [Reference]
references (Replace r _) = [r]
references Deprecate = []

-- Replacements with the Same type can be automatically propagated.
-- Replacements with a Subtype can be automatically propagated but may result in dependents getting more general types, so requires re-inference.
-- Replacements of a Different type need to be manually propagated by the programmer.
data Typing = Same | Subtype | Different
  deriving (Eq, Ord, Show)

instance Hashable Typing where
  tokens Same = [H.Tag 0]
  tokens Subtype = [H.Tag 1]
  tokens Different = [H.Tag 2]

instance Hashable TermEdit where
  tokens (Replace r t) = [H.Tag 0] ++ H.tokens r ++ H.tokens t
  tokens Deprecate = [H.Tag 1]

toReference :: TermEdit -> Maybe Reference
toReference (Replace r _) = Just r
toReference Deprecate     = Nothing

isTypePreserving :: TermEdit -> Bool
isTypePreserving e = case e of
  Replace _ Same -> True
  Replace _ Subtype -> True
  _ -> False

isSame :: TermEdit -> Bool
isSame e = case e of
  Replace _ Same -> True
  _              -> False

typing :: Var v => Type v loc -> Type v loc -> Typing
typing newType oldType | Typechecker.isEqual newType oldType = Same
                       | Typechecker.isSubtype newType oldType = Subtype
                       | otherwise = Different

