{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs                     #-}
{-# LANGUAGE OverloadedStrings         #-}
{-# LANGUAGE StandaloneDeriving        #-}
{-# LANGUAGE TypeSynonymInstances      #-}

-- Module      : Text.EDE.Internal.Types
-- Copyright   : (c) 2013 Brendan Hay <brendan.g.hay@gmail.com>
-- License     : This Source Code Form is subject to the terms of
--               the Mozilla Public License, v. 2.0.
--               A copy of the MPL can be found in the LICENSE file or
--               you can obtain it at http://mozilla.org/MPL/2.0/.
-- Maintainer  : Brendan Hay <brendan.g.hay@gmail.com>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)

module Text.EDE.Internal.Types where

import           Data.Aeson             (Array, Object)
import           Data.Monoid
import           Data.Text              (Text)
import           Data.Text.Buildable
import qualified Data.Text.Lazy         as LText
import           Data.Text.Lazy.Builder
import qualified Text.Parsec            as Parsec

-- FIXME:
-- type expression metadata extraction function
-- unsound monoid instance for untyped expressions
--   should probably propagate left expression's metadata
-- correctly handle comments

type LazyText = LText.Text

data Meta = Meta !String !Int !Int
    deriving (Eq)

instance Show Meta where
    show (Meta s r c) = concat [s, ":(", show r, ",", show c, ")"]

data Result a
    = Success      a
    | ParseError   !Parsec.ParseError
    | TypeError    !Meta !String
    | CompileError !Meta !String

instance Show a => Show (Result a) where
    show (Success a) = "Success: " ++ show a

    show (ParseError     e) = "ParseError: " ++ show e
    show (TypeError    m e) = concat ["TypeError: ", show m, " - ", e]
    show (CompileError m e) = concat ["CompileError: ", show m, " - ", e]

instance Functor Result where
    fmap f (Success a) = Success $ f a

    fmap _ (ParseError     e) = ParseError     e
    fmap _ (TypeError    m e) = TypeError    m e
    fmap _ (CompileError m e) = CompileError m e

instance Monad Result where
    return          = Success
    Success a >>= k = k a

    ParseError     e >>= _ = ParseError     e
    TypeError    m e >>= _ = TypeError    m e
    CompileError m e >>= _ = CompileError m e

newtype Ident = Ident { ident :: Text }
    deriving (Show)

instance Buildable Ident where
    build = build . ident

data Bind = Bind
    { bindMeta :: !Meta
    , bindPrim :: !Ident
    , bindSec  :: Maybe Ident
    } deriving (Show)

data AExp = forall a. TExp a ::: TType a

deriving instance Show AExp

data TType a where
    TTText :: TType Text
    TTBool :: TType Bool
    TTInt  :: TType Integer
    TTDbl  :: TType Double
    TTFrag :: TType Frag
    TTMap  :: TType Object
    TTList :: TType Array

deriving instance Show (TType a)

class Type a where
    typeof :: TType a

instance Type Text    where typeof = TTText
instance Type Bool    where typeof = TTBool
instance Type Integer where typeof = TTInt
instance Type Double  where typeof = TTDbl
instance Type Frag    where typeof = TTFrag

data Frag
    = FBld Builder
    | FVar !Meta !Ident
      deriving (Show)

data TExp a where
    TText ::          Meta -> Text      -> TExp Text
    TBool ::          Meta -> Bool      -> TExp Bool
    TInt  ::          Meta -> Integer   -> TExp Integer
    TDbl  ::          Meta -> Double    -> TExp Double
    TVar  ::          Meta -> Ident     -> TType a   -> TExp a
    TFrag ::          Meta -> Frag      -> TExp Frag
    TCons ::          Meta -> TExp Frag -> TExp Frag -> TExp Frag
    TNeg  ::          Meta -> TExp Bool -> TExp Bool
    TBin  ::          Meta -> BinOp     -> TExp Bool -> TExp Bool -> TExp Bool
    TRel  :: Ord a => Meta -> RelOp     -> TExp a    -> TExp a    -> TExp Bool
    TCond ::          Meta -> TExp Bool -> TExp Frag -> TExp Frag -> TExp Frag
    TLoop ::          Meta -> Bind      -> TExp a    -> TExp Frag -> TExp Frag -> TExp Frag

tmeta :: TExp a -> Meta
tmeta _ = (Meta "tmeta" 0 0)

deriving instance Show (TExp a)

data UExp
    = UText !Meta !Text
    | UBool !Meta !Bool
    | UInt  !Meta !Integer
    | UDbl  !Meta !Double
    | UVar  !Meta !Ident
    | UFrag !Meta !Frag
    | UCons !Meta !UExp  !UExp
    | UNeg  !Meta !UExp
    | UBin  !Meta !BinOp !UExp  !UExp
    | URel  !Meta !RelOp !UExp  !UExp
    | UCond !Meta !UExp  !UExp  !UExp
    | ULoop !Meta !Bind  !Ident !UExp !UExp
      deriving (Show)

instance Monoid UExp where
    mempty      = UFrag (Meta "mempty" 0 0) (FBld mempty)
    mappend a b = UCons (umeta a) a b

umeta :: UExp -> Meta
umeta _ = (Meta "meta" 0 0)

data BinOp
    = And
    | Or
      deriving (Show)

data RelOp
    = Equal
    | NotEqual
    | Greater
    | GreaterEqual
    | Less
    | LessEqual
      deriving (Show)