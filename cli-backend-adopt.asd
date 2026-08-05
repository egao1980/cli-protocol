(defsystem "cli-backend-adopt"
  :version "0.1.0"
  :description "Alternate adopt backend for cli-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cli-protocol" "adopt")
  :pathname "src/backend-adopt"
  :serial t
  :components ((:file "package")
               (:file "backend")))
