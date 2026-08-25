(defsystem "cli-protocol"
  :version "0.1.0"
  :description "CLOS CLI parse/run protocol for cl-stack (POSIX ∪ PowerShell ∪ CMD argv)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("uiop")
  :properties (:cl-repo (:ci (:with ("cli-backend-clingon" "cli-backend-adopt") :sources (("clingon" :ql) ("adopt" :ql) ("bobbin" :ql) ("split-sequence" :ql) ("cl-reexport" :ql) ("with-user-abort" :ql) ("rove" :ql)))))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "normalize")
               (:file "protocol"))
  :in-order-to ((test-op (test-op "cli-protocol/tests"))))

(defsystem "cli-protocol/tests"
  :depends-on ("cli-protocol" "cli-backend-clingon" "cli-backend-adopt" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "normalize-test")
               (:file "clingon-test")
               (:file "adopt-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
