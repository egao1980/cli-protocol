(defpackage #:cli-protocol
  (:use #:cl)
  (:nicknames #:stack-cli)
  (:export #:cli-error
           #:cli-parse-error
           #:cli-usage-error
           #:cli-exit
           #:cli-error-message
           #:cli-exit-code

           #:*cli-backend*
           #:*cli-option-styles*
           #:cli-backend

           #:cli-option
           #:cli-option-name
           #:cli-option-short
           #:cli-option-long
           #:cli-option-kind
           #:cli-option-default
           #:cli-option-required
           #:cli-option-env
           #:cli-option-help
           #:cli-option-key
           #:cli-option-backend

           #:cli-command
           #:cli-command-name
           #:cli-command-description
           #:cli-command-version
           #:cli-command-options
           #:cli-command-subcommands
           #:cli-command-handler
           #:cli-command-backend

           #:backend-make-command
           #:backend-make-option
           #:backend-parse
           #:backend-run
           #:backend-format-usage

           #:normalize-argv
           #:resolve-option-styles
           #:make-option
           #:make-command
           #:parse
           #:run
           #:main
           #:format-usage
           #:get-option
           #:free-args))

(in-package #:cli-protocol)
