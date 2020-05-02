{-# LANGUAGE DoAndIfThenElse     #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ViewPatterns        #-}


module Unison.CommandLine where

import Unison.Prelude

import           Control.Concurrent              (forkIO, killThread)
import           Control.Concurrent.STM          (atomically)
import           Data.Configurator               (autoReload, autoConfig)
import           Data.Configurator.Types         (Config, Worth (..))
import           Data.List                       (isSuffixOf, isPrefixOf)
import           Data.ListLike                   (ListLike)
import qualified Data.Map                        as Map
import qualified Data.Set                        as Set
import qualified Data.Text                       as Text
import           Prelude                         hiding (readFile, writeFile)
import qualified System.Console.Haskeline        as Line
import           System.FilePath                 ( takeFileName )
import           Unison.Codebase                 (Codebase)
import qualified Unison.Codebase                 as Codebase
import qualified Unison.Codebase.Branch          as Branch
import           Unison.Codebase.Editor.Input    (Event(..), Input(..))
import qualified Unison.Codebase.SearchResult    as SR
import qualified Unison.Codebase.Watch           as Watch
import           Unison.CommandLine.InputPattern (InputPattern (parse))
import qualified Unison.HashQualified'           as HQ
import           Unison.Names2 (Names0)
import qualified Unison.Util.ColorText           as CT
import qualified Unison.Util.Find                as Find
import qualified Unison.Util.Pretty              as P
import           Unison.Util.TQueue              (TQueue)
import qualified Unison.Util.TQueue              as Q

allow :: FilePath -> Bool
allow p =
  -- ignore Emacs .# prefixed files, see https://github.com/unisonweb/unison/issues/457
  not (".#" `isPrefixOf` takeFileName p) &&
  (isSuffixOf ".u" p || isSuffixOf ".uu" p)

watchConfig :: FilePath -> IO (Config, IO ())
watchConfig path = do
  (config, t) <- autoReload autoConfig [Optional path]
  pure (config, killThread t)

watchFileSystem :: TQueue Event -> FilePath -> IO (IO ())
watchFileSystem q dir = do
  (cancel, watcher) <- Watch.watchDirectory dir allow
  t <- forkIO . forever $ do
    (filePath, text) <- watcher
    atomically . Q.enqueue q $ UnisonFileChanged (Text.pack filePath) text
  pure (cancel >> killThread t)

watchBranchUpdates :: IO Branch.Hash -> TQueue Event -> Codebase IO v a -> IO (IO ())
watchBranchUpdates currentRoot q codebase = do
  (cancelExternalBranchUpdates, externalBranchUpdates) <-
    Codebase.rootBranchUpdates codebase
  thread <- forkIO . forever $ do
    updatedBranches <- externalBranchUpdates
    currentRoot <- currentRoot
    -- We only issue the event if the branch is different than what's already
    -- in memory. This skips over file events triggered by saving to disk what's
    -- already in memory.
    when (any (/= currentRoot) updatedBranches) $
      atomically . Q.enqueue q . IncomingRootBranch $ Set.delete currentRoot updatedBranches
  pure (cancelExternalBranchUpdates >> killThread thread)

warnNote :: String -> String
warnNote s = "⚠️  " <> s

backtick :: IsString s => P.Pretty s -> P.Pretty s
backtick s = P.group ("`" <> s <> "`")

backtickEOS :: IsString s => P.Pretty s -> P.Pretty s
backtickEOS s = P.group ("`" <> s <> "`.")

tip :: (ListLike s Char, IsString s) => P.Pretty s -> P.Pretty s
tip s = P.column2 [("Tip:", P.wrap s)]

note :: (ListLike s Char, IsString s) => P.Pretty s -> P.Pretty s
note s = P.column2 [("Note:", P.wrap s)]

aside :: (ListLike s Char, IsString s) => P.Pretty s -> P.Pretty s -> P.Pretty s
aside a b = P.column2 [(a <> ":", b)]

warn :: (ListLike s Char, IsString s) => P.Pretty s -> P.Pretty s
warn = emojiNote "⚠️"

problem :: (ListLike s Char, IsString s) => P.Pretty s -> P.Pretty s
problem = emojiNote "❗️"

bigproblem :: (ListLike s Char, IsString s) => P.Pretty s -> P.Pretty s
bigproblem = emojiNote "‼️"

emojiNote :: (ListLike s Char, IsString s) => String -> P.Pretty s -> P.Pretty s
emojiNote lead s = P.group (fromString lead) <> "\n" <> P.wrap s

nothingTodo :: (ListLike s Char, IsString s) => P.Pretty s -> P.Pretty s
nothingTodo = emojiNote "😶"

completion :: String -> Line.Completion
completion s = Line.Completion s s True

completion' :: String -> Line.Completion
completion' s = Line.Completion s s False

prettyCompletion :: (String, P.Pretty P.ColorText) -> Line.Completion
-- -- discards formatting in favor of better alignment
-- prettyCompletion (s, p) = Line.Completion s (P.toPlainUnbroken p) True
-- preserves formatting, but Haskeline doesn't know how to align
prettyCompletion (s, p) = Line.Completion s (P.toAnsiUnbroken p) True

-- avoids adding a space after successful completion
prettyCompletion' :: (String, P.Pretty P.ColorText) -> Line.Completion
prettyCompletion' (s, p) = Line.Completion s (P.toAnsiUnbroken p) False

prettyCompletion'' :: Bool -> (String, P.Pretty P.ColorText) -> Line.Completion
prettyCompletion'' spaceAtEnd (s, p) = Line.Completion s (P.toAnsiUnbroken p) spaceAtEnd

fuzzyCompleteHashQualified :: Names0 -> String -> [Line.Completion]
fuzzyCompleteHashQualified b q0@(HQ.fromString -> query) = case query of
  Nothing -> []
  Just query ->
    fixupCompletion q0 $
      makeCompletion <$> Find.fuzzyFindInBranch b query
  where
  makeCompletion (sr, p) =
    prettyCompletion' (HQ.toString . SR.name $ sr, p)

fuzzyComplete :: String -> [String] -> [Line.Completion]
fuzzyComplete q ss =
  fixupCompletion q (prettyCompletion' <$> Find.simpleFuzzyFinder q ss id)

exactComplete :: String -> [String] -> [Line.Completion]
exactComplete q ss = go <$> filter (isPrefixOf q) ss where
  go s = prettyCompletion'' (s == q)
           (s, P.hiBlack (P.string q) <> P.string (drop (length q) s))

prefixIncomplete :: String -> [String] -> [Line.Completion]
prefixIncomplete q ss = go <$> filter (isPrefixOf q) ss where
  go s = prettyCompletion'' False
           (s, P.hiBlack (P.string q) <> P.string (drop (length q) s))

-- workaround for https://github.com/judah/haskeline/issues/100
-- if the common prefix of all the completions is smaller than
-- the query, we make all the replacements equal to the query,
-- which will preserve what the user has typed
fixupCompletion :: String -> [Line.Completion] -> [Line.Completion]
fixupCompletion _q [] = []
fixupCompletion _q [c] = [c]
fixupCompletion q cs@(h:t) = let
  commonPrefix (h1:t1) (h2:t2) | h1 == h2 = h1 : commonPrefix t1 t2
  commonPrefix _ _             = ""
  overallCommonPrefix =
    foldl commonPrefix (Line.replacement h) (Line.replacement <$> t)
  in if not (q `isPrefixOf` overallCommonPrefix)
     then [ c { Line.replacement = q } | c <- cs ]
     else cs

parseInput
  :: Map String InputPattern -> [String] -> Either (P.Pretty CT.ColorText) Input
parseInput patterns ss = case ss of
  []             -> Left ""
  command : args -> case Map.lookup command patterns of
    Just pat -> parse pat args
    Nothing ->
      Left
        .  warn
        .  P.wrap
        $  "I don't know how to "
        <> P.group (fromString command <> ".")
        <> "Type `help` or `?` to get help."

prompt :: String
prompt = "> "

-- `plural [] "cat" "cats" = "cats"`
-- `plural ["meow"] "cat" "cats" = "cat"`
-- `plural ["meow", "meow"] "cat" "cats" = "cats"`
plural :: Foldable f => f a -> b -> b -> b
plural items one other = case toList items of
  [_] -> one
  _ -> other

plural' :: Integral a => a -> b -> b -> b
plural' 1 one _other = one
plural' _ _one other = other
