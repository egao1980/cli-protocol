(defpackage #:cli-protocol/tests
  (:use #:cl #:rove)
  (:import-from #:cli-protocol
                #:cli-option
                #:make-option
                #:make-command
                #:normalize-argv
                #:parse
                #:get-option
                #:*cli-option-styles*)
  (:shadowing-import-from #:cli-protocol #:run))

(in-package #:cli-protocol/tests)
