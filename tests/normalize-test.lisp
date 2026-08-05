(in-package #:cli-protocol/tests)

(defun %opts ()
  (list
   (make-instance 'cli-option :name "count" :short #\c :long "count" :kind :integer :key :count)
   (make-instance 'cli-option :name "verbose" :short #\v :long "verbose" :kind :flag :key :verbose)
   (make-instance 'cli-option :name "name" :short #\n :long "name" :kind :string :key :name)))

(deftest normalize-posix-passthrough
  (let ((opts (%opts)))
    (ok (equal '("greet" "--count" "2" "ada")
               (normalize-argv '("greet" "--count" "2" "ada")
                               :styles '(:posix) :options opts)))
    (ok (equal '("greet" "-c" "2" "ada")
               (normalize-argv '("greet" "-c" "2" "ada")
                               :styles '(:posix) :options opts)))))

(deftest normalize-powershell-long
  (let ((opts (%opts)))
    (ok (equal '("greet" "--count" "2" "ada")
               (normalize-argv '("greet" "-Count" "2" "ada")
                               :styles '(:posix :powershell) :options opts)))
    (ok (equal '("greet" "--count" "2" "ada")
               (normalize-argv '("greet" "-Count:2" "ada")
                               :styles '(:posix :powershell) :options opts)))
    (ok (equal '("greet" "--verbose" "ada")
               (normalize-argv '("greet" "-Verbose" "ada")
                               :styles '(:posix :powershell) :options opts)))))

(deftest normalize-cmd-slash
  (let ((opts (%opts)))
    (ok (equal '("greet" "--count" "2" "ada")
               (normalize-argv '("greet" "/Count:2" "ada")
                               :styles '(:posix :powershell :cmd) :options opts)))
    (ok (equal '("greet" "--count" "2" "ada")
               (normalize-argv '("greet" "/Count" "2" "ada")
                               :styles '(:posix :cmd) :options opts)))
    (ok (equal '("greet" "-c" "2" "ada")
               (normalize-argv '("greet" "/c" "2" "ada")
                               :styles '(:posix :cmd) :options opts)))))

(deftest normalize-end-of-options
  (let ((opts (%opts)))
    (ok (equal '("--" "-Count" "/foo")
               (normalize-argv '("--" "-Count" "/foo")
                               :styles '(:posix :powershell :cmd) :options opts)))))
