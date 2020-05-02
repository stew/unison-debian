{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE Rank2Types #-}

module Unison.Result where

import Unison.Prelude

import           Control.Monad.Except           ( ExceptT(..) )
import           Data.Functor.Identity
import qualified Control.Monad.Fail            as Fail
import qualified Control.Monad.Morph           as Morph
import           Control.Monad.Writer           ( WriterT(..)
                                                , runWriterT
                                                , MonadWriter(..)
                                                )
import           Unison.Name                    ( Name )
import qualified Unison.Parser                 as Parser
import           Unison.Paths                   ( Path )
import           Unison.Term                    ( Term )
import qualified Unison.Typechecker.Context    as Context
import           Control.Error.Util             ( note)
import qualified Unison.Names3                 as Names

type Result notes = ResultT notes Identity

type ResultT notes f = MaybeT (WriterT notes f)

data Note v loc
  = Parsing (Parser.Err v)
  | NameResolutionFailures [Names.ResolutionFailure v loc]
  | InvalidPath Path (Term v loc) -- todo: move me!
  | UnknownSymbol v loc
  | TypeError (Context.ErrorNote v loc)
  | TypeInfo (Context.InfoNote v loc)
  | CompilerBug (CompilerBug v loc)
  deriving Show

data CompilerBug v loc
  = TopLevelComponentNotFound v (Term v loc)
  | ResolvedNameNotFound v loc Name
  | TypecheckerBug (Context.CompilerBug v loc)
  deriving Show

result :: Result notes a -> Maybe a
result (Result _ may) = may

pattern Result notes may = MaybeT (WriterT (Identity (may, notes)))
{-# COMPLETE Result #-}

isSuccess :: Functor f => ResultT note f a -> f Bool
isSuccess = (isJust . fst <$>) . runResultT

isFailure :: Functor f => ResultT note f a -> f Bool
isFailure = (isNothing . fst <$>) . runResultT

toMaybe :: Functor f => ResultT note f a -> f (Maybe a)
toMaybe = (fst <$>) . runResultT

runResultT :: ResultT notes f a -> f (Maybe a, notes)
runResultT = runWriterT . runMaybeT

-- Returns the `Result` in the `f` functor.
getResult :: Functor f => ResultT notes f a -> f (Result notes a)
getResult r = uncurry (flip Result) <$> runResultT r

toEither :: Functor f => ResultT notes f a -> ExceptT notes f a
toEither r = ExceptT (go <$> runResultT r)
  where go (may, notes) = note notes may

tell1 :: Monad f => note -> ResultT (Seq note) f ()
tell1 = tell . pure

fromParsing
  :: Monad f => Either (Parser.Err v) a -> ResultT (Seq (Note v loc)) f a
fromParsing (Left e) = do
  tell1 $ Parsing e
  Fail.fail ""
fromParsing (Right a) = pure a

tellAndFail :: Monad f => note -> ResultT (Seq note) f a
tellAndFail note = tell1 note *> Fail.fail "Elegantly and responsibly"

compilerBug :: Monad f => CompilerBug v loc -> ResultT (Seq (Note v loc)) f a
compilerBug = tellAndFail . CompilerBug

hoist
  :: (Monad f, Monoid notes)
  => (forall a. f a -> g a)
  -> ResultT notes f b -> ResultT notes g b
hoist morph = Morph.hoist (Morph.hoist morph)
