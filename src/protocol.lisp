(in-package #:cli-protocol)

(defvar *cli-backend* nil
  "Current CLI backend object.")

(defclass cli-backend () ()
  (:documentation "Base class for cli-protocol backends."))

(defclass cli-option ()
  ((name :initarg :name :reader cli-option-name)
   (short :initarg :short :initform nil :reader cli-option-short)
   (long :initarg :long :initform nil :reader cli-option-long)
   (kind :initarg :kind :initform :string :reader cli-option-kind)
   (default :initarg :default :initform nil :reader cli-option-default)
   (required :initarg :required :initform nil :reader cli-option-required)
   (env :initarg :env :initform nil :reader cli-option-env)
   (help :initarg :help :initform "" :reader cli-option-help)
   (key :initarg :key :initform nil :reader cli-option-key)
   (backend :initarg :backend :initform nil :accessor cli-option-backend))
  (:documentation "Protocol-level option metadata (+ backend payload)."))

(defclass cli-command ()
  ((name :initarg :name :reader cli-command-name)
   (description :initarg :description :initform "" :reader cli-command-description)
   (version :initarg :version :initform nil :reader cli-command-version)
   (options :initarg :options :initform nil :reader cli-command-options)
   (subcommands :initarg :subcommands :initform nil :reader cli-command-subcommands)
   (handler :initarg :handler :initform nil :reader cli-command-handler)
   (backend :initarg :backend :initform nil :accessor cli-command-backend)
   (parse-result :initform nil :accessor cli-command-parse-result))
  (:documentation "Protocol-level command tree node."))

(defgeneric backend-make-option (backend &key name short long kind default required env help key)
  (:documentation "LONG = canonical name without -- or / prefix."))

(defgeneric backend-make-command (backend &key name description version options subcommands handler)
  (:documentation "Build backend command; OPTIONS/SUBCOMMANDS are protocol objects."))

(defgeneric backend-parse (backend command argv)
  (:documentation "Parse POSIX ARGV → (values options-plist free-args).
   OPTIONS-PLIST uses option :key keywords."))

(defgeneric backend-run (backend command argv)
  (:documentation "Parse + invoke handler. Return handler value."))

(defgeneric backend-format-usage (backend command &key stream styles)
  (:documentation "Write help to STREAM."))

(defun make-option (&rest keys &key (backend *cli-backend*) &allow-other-keys)
  "Create a CLI-OPTION via BACKEND."
  (unless backend
    (error 'cli-usage-error
           :message "*cli-backend* unbound — load cli-backend-clingon"))
  (apply #'backend-make-option backend keys))

(defun make-command (&rest keys &key (backend *cli-backend*) &allow-other-keys)
  "Create a CLI-COMMAND via BACKEND."
  (unless backend
    (error 'cli-usage-error
           :message "*cli-backend* unbound — load cli-backend-clingon"))
  (apply #'backend-make-command backend keys))

(defun %collect-options (command)
  "Flatten options from COMMAND and its subcommands (for dialect index)."
  (labels ((walk (cmd)
             (append (cli-command-options cmd)
                     (mapcan #'walk (cli-command-subcommands cmd)))))
    (walk command)))

(defun parse (command argv &key (styles *cli-option-styles*) (backend *cli-backend*))
  "Normalize then backend-parse → (values options free-args)."
  (unless backend
    (error 'cli-usage-error
           :message "*cli-backend* unbound — load cli-backend-clingon"))
  (let* ((opts (%collect-options command))
         (posix (normalize-argv argv :styles styles :options opts)))
    (handler-case
        (backend-parse backend command posix)
      (cli-error (e) (error e))
      (error (e)
        (error 'cli-parse-error :message (princ-to-string e))))))

(defun run (command &key (argv (uiop:command-line-arguments))
                      (styles *cli-option-styles*)
                      (backend *cli-backend*))
  "Normalize + run handler."
  (unless backend
    (error 'cli-usage-error
           :message "*cli-backend* unbound — load cli-backend-clingon"))
  (let* ((opts (%collect-options command))
         (posix (normalize-argv argv :styles styles :options opts)))
    (handler-case
        (backend-run backend command posix)
      (cli-exit (e) (error e))
      (cli-error (e) (error e))
      (error (e)
        (error 'cli-parse-error :message (princ-to-string e))))))

(defun main (command &key (argv (uiop:command-line-arguments))
                       (styles *cli-option-styles*)
                       (backend *cli-backend*))
  "Binary entry: map conditions to exit codes (0/1/2)."
  (handler-case
      (progn
        (run command :argv argv :styles styles :backend backend)
        (uiop:quit 0))
    (cli-exit (e)
      (uiop:quit (cli-exit-code e)))
    (cli-parse-error (e)
      (format *error-output* "~&~a~%" e)
      (uiop:quit 2))
    (cli-usage-error (e)
      (format *error-output* "~&~a~%" e)
      (uiop:quit 2))
    (error (e)
      (format *error-output* "~&~a~%" e)
      (uiop:quit 1))))

(defun format-usage (command &key (stream *standard-output*)
                               (styles *cli-option-styles*)
                               (backend *cli-backend*))
  (unless backend
    (error 'cli-usage-error
           :message "*cli-backend* unbound — load cli-backend-clingon"))
  (backend-format-usage backend command :stream stream :styles styles))

(defun get-option (options key &optional default)
  "Lookup KEY in options plist or hash-table from PARSE."
  (cond
    ((hash-table-p options)
     (gethash key options default))
    ((listp options)
     (getf options key default))
    (t default)))

(defun free-args (parse-values)
  "Second value convenience when PARSE result stored as list."
  (second parse-values))
