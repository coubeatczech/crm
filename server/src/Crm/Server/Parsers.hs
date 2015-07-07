module Crm.Server.Parsers (
  parseList ,
  parseDate ) where

import           Text.Parsec
import           Data.Text hiding        (foldr)
import qualified Data.Text as            T

import           Control.Applicative     ((<*), (<$>), (*>))
import           Control.Monad           (liftM3)

import           Crm.Shared.ServerRender (Markup(..))

import           Safe                        (readMay)

parseDate' :: MyParsec (Int, Int, Int)
parseDate' = parser where
  parser = 
    liftM3 (,,)
      (intParser <* dotParser)
      (intParser <* dotParser)
      intParser
  dotParser = char '.'
  intParser = maybe (fail "not an int") return . readMay =<< many1 digit

parseDate :: String -> Either ParseError (Int, Int, Int)
parseDate = parse parseDate' ""

type MyParsec a = Parsec String () a

parseList :: Text -> Either ParseError [Markup]
parseList t = fmap joinListElements $ parse listParser "" (unpack t')
  where
  t' = if T.null t || (('\n' /=) . T.last $ t)
    then t `T.snoc` '\n'
    else t
  joinListElements = foldr foldStep []
  foldStep (UnorderedList ul') (UnorderedList ul : rest) = (UnorderedList $ ul' ++ ul) : rest
  foldStep (element) (acc) = element : acc

listParser :: MyParsec [Markup]
listParser = do
  result <- many $ try listElementParser <|> plainLineParser 
  eof
  return result

listElementParser :: MyParsec Markup
listElementParser = UnorderedList <$> ((:[]) . pack <$> (string "- " *> line))

plainLineParser :: MyParsec Markup
plainLineParser = PlainText . pack <$> line

line :: MyParsec String
line = (many . noneOf $ "\r\n") <* eol
 
eol :: MyParsec ()
eol = do
  _ <- try (string "\n\r")
    <|> try (string "\r\n")
    <|> string "\n"
    <|> string "\r"
  return ()
