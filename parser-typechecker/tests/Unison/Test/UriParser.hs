{-# LANGUAGE OverloadedStrings #-}

module Unison.Test.UriParser where

import EasyTest
import Unison.Codebase.Editor.RemoteRepo (RemoteRepo(..))
import Unison.Codebase.Path (Path(..))
import qualified Unison.Codebase.Path as Path
import qualified Text.Megaparsec as P
import qualified Unison.Codebase.Editor.UriParser as UriParser
import qualified Data.Sequence as Seq
import Unison.Codebase.ShortBranchHash (ShortBranchHash(..))
import Data.Text (Text)
import Unison.Codebase.NameSegment (NameSegment(..))
import qualified Data.Text as Text

test :: Test ()
test = scope "uriparser" . tests $ [ testAugmented ]

testAugmented:: Test ()
testAugmented = scope "augmented" . tests $
-- Local Protocol
-- $ git clone /srv/git/project.git
-- $ git clone /srv/git/project.git[:treeish][:[#hash][.path]]
  [ scope "local-protocol" . tests . map parseAugmented $
    [ ("/srv/git/project.git",
      (GitRepo "/srv/git/project.git" Nothing, Nothing, Path.empty))
    , ("/srv/git/project.git:abc:#def.hij.klm",
      (GitRepo "/srv/git/project.git" (Just "abc"), sbh "def", path ["hij", "klm"]))
    , ("srv/git/project.git",
      (GitRepo "srv/git/project.git" Nothing, Nothing, Path.empty))
    , ("srv/git/project.git:abc:#def.hij.klm",
      (GitRepo "srv/git/project.git" (Just "abc"), sbh "def", path ["hij", "klm"]))
    ],
-- File Protocol
-- $ git clone file:///srv/git/project.git[:treeish][:[#hash][.path]] <- imagined
    scope "file-protocol" . tests . map parseAugmented $
    [ ("file:///srv/git/project.git",
      (GitRepo "file:///srv/git/project.git" Nothing, Nothing, Path.empty))
    , ("file:///srv/git/project.git:abc:#def.hij.klm",
      (GitRepo "file:///srv/git/project.git" (Just "abc"), sbh "def", path ["hij", "klm"]))
    , ("file://srv/git/project.git",
      (GitRepo "file://srv/git/project.git" Nothing, Nothing, Path.empty))
    , ("file://srv/git/project.git:abc:#def.hij.klm",
      (GitRepo "file://srv/git/project.git" (Just "abc"), sbh "def", path ["hij", "klm"]))
    ],
-- Smart / Dumb HTTP protocol
-- $ git clone https://example.com/gitproject.git[:treeish][:[#hash][.path]] <- imagined
    scope "http-protocol" . tests . map parseAugmented $
    [ ("https://example.com/git/project.git",
      (GitRepo "https://example.com/git/project.git" Nothing, Nothing, Path.empty))
    , ("https://user@example.com/git/project.git:abc:#def.hij.klm]",
      (GitRepo "https://user@example.com/git/project.git" (Just "abc"), sbh "def", path ["hij", "klm"]))
    ],
-- SSH Protocol
-- $ git clone ssh://[user@]server/project.git[:treeish][:[#hash][.path]]
    scope "ssh-protocol" . tests . map parseAugmented $
    [ ("ssh://git@8.8.8.8:222/user/project.git",
      (GitRepo "ssh://git@8.8.8.8:222/user/project.git" Nothing, Nothing, Path.empty))
    , ("ssh://git@github.com/user/project.git:abc:#def.hij.klm",
      (GitRepo "ssh://git@github.com/user/project.git" (Just "abc"), sbh "def", path ["hij", "klm"]))
    ],
-- $ git clone [user@]server:project.git[:treeish][:[#hash][.path]]
    scope "scp-protocol" . tests . map parseAugmented $
    [ ("git@github.com:user/project.git",
      (GitRepo "git@github.com:user/project.git" Nothing, Nothing, Path.empty))
    , ("github.com:user/project.git",
      (GitRepo "github.com:user/project.git" Nothing, Nothing, Path.empty))
    , ("git@github.com:user/project.git:abc:#def.hij.klm",
      (GitRepo "git@github.com:user/project.git" (Just "abc"), sbh "def", path ["hij", "klm"]))
    ]
  ]

parseAugmented :: (Text, (RemoteRepo, Maybe ShortBranchHash, Path)) -> Test ()
parseAugmented (s, r) = scope (Text.unpack s) $
  case P.parse UriParser.repoPath "test case" s of
    Left x -> crash $ show x
    Right x -> expectEqual x r

path :: [Text] -> Path
path = Path . Seq.fromList . fmap NameSegment

sbh :: Text -> Maybe ShortBranchHash
sbh = Just . ShortBranchHash
