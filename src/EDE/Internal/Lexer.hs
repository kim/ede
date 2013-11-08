module EDE.Internal.Lexer where

import           Data.Functor.Identity
import           Data.Text.Lazy        (Text)
import           Text.Parsec
import           Text.Parsec.Language
import           Text.Parsec.Text.Lazy (Parser)
import           Text.Parsec.Token     (GenTokenParser)
import qualified Text.Parsec.Token     as Parsec

identifier :: Parser String
identifier = Parsec.identifier lexer

reserved :: String -> Parser ()
reserved = Parsec.reserved lexer

reservedOp :: String -> Parser ()
reservedOp = Parsec.reservedOp lexer

stringLiteral :: Parser String
stringLiteral = Parsec.stringLiteral lexer

integerLiteral :: Parser Integer
integerLiteral = Parsec.integer lexer

doubleLiteral :: Parser Double
doubleLiteral = Parsec.float lexer

symbol :: String -> Parser String
symbol = Parsec.symbol lexer

whiteSpace :: Parser ()
whiteSpace = Parsec.whiteSpace lexer

lexer :: GenTokenParser Text () Identity
lexer = Parsec.makeTokenParser rules

rules :: GenLanguageDef Text u Identity
rules = Parsec.LanguageDef
    { Parsec.commentStart    = "{#"
    , Parsec.commentEnd      = "#}"
    , Parsec.commentLine     = ""
    , Parsec.nestedComments  = False
    , Parsec.identStart      = letter <|> char '_'
    , Parsec.identLetter     = alphaNum <|> oneOf "_'"
    , Parsec.opStart         = Parsec.opLetter rules
    , Parsec.opLetter        = oneOf ":!#$%&*+./<=>?@\\^|-~"
    , Parsec.caseSensitive   = False
    , Parsec.reservedNames   = names
    , Parsec.reservedOpNames = operators
    }

names :: [String]
names = ["if", "endif", "for", "in", "endfor", "else", "true", "false"]

operators :: [String]
operators = [">", ">=", "<", "=<", "==", "/=", "!", "||", "&&"]