(in-package #:cli-protocol/tests)

(defun %greet-app ()
  (cli-backend-clingon:use-clingon-backend)
  (let* ((count (make-option :name "count" :short #\c :long "count"
                             :kind :integer :default 1 :help "times" :key :count))
         (greet (make-command
                 :name "greet"
                 :description "greet someone"
                 :options (list count)
                 :handler (lambda (opts free)
                            (list :count (get-option opts :count)
                                  :args free))))
         (top (make-command
               :name "demo"
               :description "demo app"
               :version "0.1.0"
               :subcommands (list greet)
               :handler (lambda (opts free)
                          (declare (ignore opts))
                          (list :top free)))))
    top))

(deftest clingon-posix-parse
  (let ((app (%greet-app)))
    (multiple-value-bind (opts free)
        (parse app '("greet" "--count" "2" "ada") :styles '(:posix))
      (ok (eql 2 (get-option opts :count)))
      (ok (equal '("ada") free)))))

(deftest clingon-powershell-run
  (let ((app (%greet-app)))
    (ok (equal '(:count 2 :args ("ada"))
               (run app :argv '("greet" "-Count" "2" "ada")
                    :styles '(:posix :powershell))))))

(deftest clingon-cmd-run
  (let ((app (%greet-app)))
    (ok (equal '(:count 2 :args ("ada"))
               (run app :argv '("greet" "/Count:2" "ada")
                    :styles '(:posix :powershell :cmd))))))
