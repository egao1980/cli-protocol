(defsystem "cli-backend-clingon"
  :version "0.2.1"
  :description "Default clingon backend for cli-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ((:version "cli-protocol" "0.2.1") "clingon")
  :pathname "src/backend-clingon"
  :serial t
  :components ((:file "package")
               (:file "backend")))
