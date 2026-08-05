(in-package #:cli-protocol/tests)

(defun %adopt-app ()
  (cli-backend-adopt:use-adopt-backend)
  (let* ((count (make-option :name "count" :short #\c :long "count"
                             :kind :integer :default 1 :help "times" :key :count))
         (app (make-command
               :name "greet"
               :description "greet"
               :options (list count)
               :handler (lambda (opts free)
                          (list :count (get-option opts :count)
                                :args free)))))
    app))

(deftest adopt-dialects
  (let ((app (%adopt-app)))
    (ok (equal '(:count 3 :args ("bob"))
               (run app :argv '("--count" "3" "bob") :styles '(:posix))))
    (ok (equal '(:count 3 :args ("bob"))
               (run app :argv '("-Count" "3" "bob")
                    :styles '(:posix :powershell))))
    (ok (equal '(:count 3 :args ("bob"))
               (run app :argv '("/Count:3" "bob")
                    :styles '(:posix :cmd))))))
