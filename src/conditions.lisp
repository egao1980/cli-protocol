(in-package #:cli-protocol)

(define-condition cli-error (error)
  ((message :initarg :message :reader cli-error-message
            :initform nil))
  (:report (lambda (c s)
             (format s "~@[~a~]" (cli-error-message c)))))

(define-condition cli-parse-error (cli-error) ())
(define-condition cli-usage-error (cli-error) ())

(define-condition cli-exit (cli-error)
  ((code :initarg :code :reader cli-exit-code :initform 0))
  (:report (lambda (c s)
             (format s "cli exit ~a~@[ — ~a~]"
                     (cli-exit-code c)
                     (cli-error-message c)))))

(define-condition cli-help-requested (cli-exit)
  ((command-name :initarg :command-name :initform nil
                 :reader cli-exit-command-name))
  (:default-initargs :code 0 :message "help requested")
  (:documentation "RUN was given the built-in --help: the backend wrote the
usage to *STANDARD-OUTPUT* and did not call the handler. Exit code 0.
PARSE does not signal it; it reports :HELP T in the options plist."))

(define-condition cli-version-requested (cli-exit)
  ((command-name :initarg :command-name :initform nil
                 :reader cli-exit-command-name))
  (:default-initargs :code 0 :message "version requested")
  (:documentation "RUN was given the built-in --version: the backend wrote
the version line to *STANDARD-OUTPUT* and did not call the handler. Exit code
0. PARSE does not signal it; it reports :VERSION T in the options plist."))
