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

(defun %quiet-parse (app argv)
  "PARSE APP with ARGV → (values opts free printed-text)."
  (let* ((out (make-string-output-stream))
         (vals (multiple-value-list
                (let ((*standard-output* out))
                  (parse app argv :styles '(:posix))))))
    (values (first vals) (second vals) (get-output-stream-string out))))

(deftest clingon-builtin-help-version-parse
  (let ((app (%greet-app)))
    (testing "--help on a subcommand → :help t, nothing printed, no exit"
      (multiple-value-bind (opts free printed) (%quiet-parse app '("greet" "--help"))
        (ok (eq t (get-option opts :help)))
        (ok (null (get-option opts :version)))
        (ok (null free))
        (ok (equal "" printed))))
    (testing "--help on the top command before a subcommand"
      (multiple-value-bind (opts) (%quiet-parse app '("--help" "greet" "ada"))
        (ok (eq t (get-option opts :help)))))
    (testing "--version → :version t"
      (multiple-value-bind (opts free printed) (%quiet-parse app '("--version"))
        (declare (ignore free))
        (ok (eq t (get-option opts :version)))
        (ok (equal "" printed))))
    (testing "neither given → no keys"
      (let ((opts (%quiet-parse app '("greet" "--count" "3"))))
        (ok (eql 3 (get-option opts :count)))
        (ok (eq :none (get-option opts :help :none)))
        (ok (eq :none (get-option opts :version :none)))))))

(deftest clingon-builtin-help-version-run
  (let ((app (%greet-app)))
    (testing "run --help prints usage and signals cli-help-requested (code 0)"
      (let* ((out (make-string-output-stream))
             (c (handler-case (let ((*standard-output* out))
                                (run app :argv '("greet" "--help") :styles '(:posix))
                                nil)
                  (cli-help-requested (e) e))))
        (ok c)
        (ok (typep c 'cli-exit))
        (ok (eql 0 (cli-exit-code c)))
        (ok (search "greet" (cli-exit-command-name c)))
        (ok (search "count" (get-output-stream-string out)))))
    (testing "run --version prints the version and signals cli-version-requested"
      (let* ((out (make-string-output-stream))
             (c (handler-case (let ((*standard-output* out))
                                (run app :argv '("--version") :styles '(:posix))
                                nil)
                  (cli-version-requested (e) e))))
        (ok c)
        (ok (search "0.1.0" (get-output-stream-string out)))))))

