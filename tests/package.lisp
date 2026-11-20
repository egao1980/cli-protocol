(defpackage #:cli-protocol/tests
  (:use #:cl #:rove)
  (:import-from #:cli-protocol
                #:cli-option
                #:make-option
                #:make-command
                #:normalize-argv
                #:parse
                #:get-option
                #:*cli-option-styles*
                #:cli-exit
                #:cli-exit-code
                #:cli-exit-command-name
                #:cli-help-requested
                #:cli-version-requested)
  (:shadowing-import-from #:cli-protocol #:run))

(in-package #:cli-protocol/tests)
