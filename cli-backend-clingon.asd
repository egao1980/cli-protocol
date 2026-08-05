(defsystem "cli-backend-clingon"
  :version "0.1.0"
  :description "Default clingon backend for cli-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cli-protocol" "clingon")
  :pathname "src/backend-clingon"
  :serial t
  :components ((:file "package")
               (:file "backend")))
