{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module Unison.Codebase.Editor.AuthorInfo where

import Unison.Term (Term, hashComponents)

import qualified Unison.Reference as Reference
import Unison.Prelude (MonadIO, Word8)
import Unison.Var (Var)
import Data.ByteString (unpack)
import Crypto.Random (getRandomBytes)
import qualified Data.Map as Map
import qualified Unison.Var as Var
import Data.Foldable (toList)
import UnliftIO (liftIO)
import qualified Unison.Term as Term
import qualified Unison.Type as Type
import Unison.Type (Type)
import Data.Text (Text)

data AuthorInfo v a = AuthorInfo
  { guid, author, copyrightHolder :: (Reference.Id, Term v a, Type v a) }

createAuthorInfo :: forall m v a. MonadIO m => Var v => a -> Text -> m (AuthorInfo v a)
createAuthorInfo a t = createAuthorInfo' . unpack <$> liftIO (getRandomBytes 32)
  where
  createAuthorInfo' :: [Word8] -> AuthorInfo v a
  createAuthorInfo' bytes = let
    [(guidRef, guidTerm)] = hashAndWrangle "guid" $
      Term.app a
        (Term.constructor a guidTypeRef 0)
        (Term.app a
          (Term.builtin a "Bytes.fromList")
          (Term.seq a (map (Term.nat a . fromIntegral) bytes)))

    [(authorRef, authorTerm)] = hashAndWrangle "author" $
      Term.apps
        (Term.constructor a authorTypeRef 0)
        [(a, Term.ref a (Reference.DerivedId guidRef))
        ,(a, Term.text a t)]

    [(chRef, chTerm)] = hashAndWrangle "copyrightHolder" $
      Term.apps
        (Term.constructor a chTypeRef 0)
        [(a, Term.ref a (Reference.DerivedId guidRef))
        ,(a, Term.text a t)]

    in AuthorInfo
        (guidRef, guidTerm, guidType)
        (authorRef, authorTerm, authorType)
        (chRef, chTerm, chType)
  hashAndWrangle v tm = toList . hashComponents $ Map.fromList [(Var.named v, tm)]
  (chType, chTypeRef) = (Type.ref a chTypeRef, unsafeParse copyrightHolderHash)
  (authorType, authorTypeRef) = (Type.ref a authorTypeRef, unsafeParse authorHash)
  (guidType, guidTypeRef) = (Type.ref a guidTypeRef, unsafeParse guidHash)
  unsafeParse = either error id . Reference.fromText
  guidHash = "#rc29vdqe019p56kupcgkg07fkib86r3oooatbmsgfbdsgpmjhsh00l307iuts3r973q5etb61vbjkes42b6adb3mkorusvmudiuorno"
  copyrightHolderHash = "#aohndsu9bl844vspujp142j5aijv86rifmnrbnjvpv3h3f3aekn45rj5s1uf1ucrrtm5urbc5d1ajtm7lqq1tr8lkgv5fathp6arqug"
  authorHash = "#5hi1vvs5t1gmu6vn1kpqmgksou8ie872j31gc294lgqks71di6gm3d4ugnrr4mq8ov0ap1e20lq099d5g6jjf9c6cbp361m9r9n5g50"
