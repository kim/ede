{-# LANGUAGE GADTs             #-}
{-# LANGUAGE OverloadedStrings #-}

-- Module      : Text.EDE.Internal.TypeChecker
-- Copyright   : (c) 2013 Brendan Hay <brendan.g.hay@gmail.com>
-- License     : This Source Code Form is subject to the terms of
--               the Mozilla Public License, v. 2.0.
--               A copy of the MPL can be found in the LICENSE file or
--               you can obtain it at http://mozilla.org/MPL/2.0/.
-- Maintainer  : Brendan Hay <brendan.g.hay@gmail.com>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)

module Text.EDE.Internal.TypeChecker (typeCheck) where

import Control.Applicative
import Control.Monad
import Data.Aeson                    (Value(..))
import Data.Attoparsec.Number        (Number(..))
import Text.EDE.Internal.Environment
import Text.EDE.Internal.Types

typeCheck :: Type a => UExp -> Env (TExp a)
typeCheck = cast typeof <=< check

check :: UExp -> Env AExp
check (UText m t) = return $ TText m t ::: TTText
check (UBool m b) = return $ TBool m b ::: TTBool
check (UInt  m i) = return $ TInt  m i ::: TTInt
check (UDbl  m d) = return $ TDbl  m d ::: TTDbl
check (UFrag m b) = return $ TFrag m b ::: TTFrag

check (UVar m i) = f <$> require m i
  where
    f (String _)     = TVar m i TTText ::: TTText
    f (Bool   _)     = TVar m i TTBool ::: TTBool
    f (Number (I _)) = TVar m i TTInt  ::: TTInt
    f (Number (D _)) = TVar m i TTDbl  ::: TTDbl
    f (Object _)     = TVar m i TTMap  ::: TTMap
    f (Array  _)     = TVar m i TTList ::: TTList
    f Null           = TVar m i TTBool ::: TTBool

check (UCons m a b) = do
    a' ::: TTFrag <- check a
    b' ::: TTFrag <- check b
    return $ TCons m a' b' ::: TTFrag

check (UNeg m e) = do
    e' ::: TTBool <- predicate e
    return $ TNeg m e' ::: TTBool

check (UBin m op x y) = do
    x' ::: TTBool <- predicate x
    y' ::: TTBool <- predicate y
    return $ TBin m op x' y' ::: TTBool

check (URel m op x y) = do
    x' ::: xt <- check x
    y' ::: yt <- check y
    Eq  <- equal m xt yt
    Ord <- order m xt
    return $ TRel m op x' y' ::: TTBool

check (UCond m p l r) = do
    p' ::: TTBool <- predicate p
    l' ::: TTFrag <- check l
    r' ::: TTFrag <- check r
    return $ TCond m p' l' r' ::: TTFrag

check (ULoop m b i l r) = do
    c  ::: _      <- collection
    l' ::: TTFrag <- check l
    r' ::: TTFrag <- check r
    return $ TLoop m b c l' r' ::: TTFrag
  where
    collection = do
        u@(_ ::: t) <- check $ UVar m i
        case t of
            TTMap  -> return u
            TTList -> return u
            _ -> typeError m "unsupported collection type {} in loop." [show t]

cast :: TType a -> AExp -> Env (TExp a)
cast t (e ::: t') = do
    Eq <- equal (tmeta e) t t'
    return e

predicate :: UExp -> Env AExp
predicate x@(UVar m i) = do
    p <- bound i
    y@(_ ::: ut) <- if p then check x else return $ TBool m False ::: TTBool
    return $ case ut of
        TTBool -> y
        _      -> TBool m True ::: TTBool
predicate u = check u

data Equal a b where
    Eq :: Equal a a

equal :: Meta -> TType a -> TType b -> Env (Equal a b)
equal _ TTText TTText = return Eq
equal _ TTBool TTBool = return Eq
equal _ TTInt  TTInt  = return Eq
equal _ TTDbl  TTDbl  = return Eq
equal _ TTFrag TTFrag = return Eq
equal m a b = typeError m "type equality check of {} ~ {} failed." [show a, show b]

data Order a where
    Ord :: Ord a => Order a

order :: Meta -> TType a -> Env (Order a)
order _ TTText = return Ord
order _ TTBool = return Ord
order _ TTInt  = return Ord
order _ TTDbl  = return Ord
order m t = typeError m "constraint check of Ord a => a ~ {} failed." [show t]