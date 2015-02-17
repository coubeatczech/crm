{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Crm.Component.Navigation where

import "fay-base" Data.Text (fromString)
import "fay-base" Prelude hiding (span, div, elem)
import "fay-base" FFI (Defined(Defined))

import HaskellReact
import HaskellReact.Bootstrap (navBar' , nav)
import qualified HaskellReact.Bootstrap.Glyphicon as G

import Crm.Router (link, defaultFrontPage, CrmRouter, plannedUpkeeps, machineTypesList, 
  employeePage)

navigation' :: CrmRouter 
            -> (DOMElement, Fay ())
            -> Fay ()
navigation' router (body, callbacks) = 
  simpleReactBody' ( div [
    navBar' (\attrs -> attrs { key = Defined "1" } ) $ nav [
      li' (row "1") $ link [G.home, text2DOM " Seznam firem"] defaultFrontPage router ,
      li' (row "2") $ link [G.tasks, text2DOM " Naplánované servisy"] plannedUpkeeps router ,
      li' (row "3") $ link [G.thList, text2DOM " Editace typů zařízení"] machineTypesList router ,
      li' (row "4") $ link [G.user, text2DOM " Servismani"] employeePage router ] ,
    div' (row "2") body ] ) callbacks 

navigation :: CrmRouter
           -> DOMElement
           -> Fay ()
navigation router body =
  navigation' router (body, return ())
