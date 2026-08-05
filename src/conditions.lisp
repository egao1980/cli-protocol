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
