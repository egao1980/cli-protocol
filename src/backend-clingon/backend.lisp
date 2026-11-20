(in-package #:cli-backend-clingon)

(defclass clingon-backend (cli-backend) ())

(defun make-clingon-backend ()
  (make-instance 'clingon-backend))

(defun use-clingon-backend ()
  "Bind *CLI-BACKEND* to clingon. Returns the backend."
  (setf *cli-backend* (make-clingon-backend)))

(defun %option-key (name key)
  (or key (intern (string-upcase (string name)) :keyword)))

(defmethod backend-make-option ((backend clingon-backend)
                                &key name short long kind default required env help key)
  (let* ((k (%option-key name key))
         (long-name (or long (when name (string-downcase (string name)))))
         (clingon-kind (case kind
                         ((:flag :boolean/true) :flag)
                         (:boolean/false :boolean/false)
                         (:boolean :boolean)
                         (:counter :counter)
                         (:integer :integer)
                         (:list :list)
                         (:enum :enum)
                         (otherwise :string)))
         (native (apply #'clingon:make-option
                        clingon-kind
                        :description (or help "")
                        :key k
                        (append
                         (when short (list :short-name short))
                         (when long-name (list :long-name long-name))
                         (when env (list :env-vars (if (listp env) env (list env))))
                         (when default (list :initial-value default))))))
    (make-instance 'cli-option
                   :name name
                   :short short
                   :long long-name
                   :kind kind
                   :default default
                   :required required
                   :env env
                   :help (or help "")
                   :key k
                   :backend native)))

(defclass %protocol-command (clingon:command)
  ((builtin :initform nil :accessor %builtin-flags
            :documentation "Plist (:help T / :version T) of the built-in
flags given to this command in the last parse."))
  (:documentation "clingon command whose built-in --help / --version are
reported to cli-protocol instead of printing and exiting during the parse."))

(defun %builtin-set-p (command key)
  "T when the built-in flag KEY was given to COMMAND (read before
FINALIZE-COMMAND: clingon's PRINT-USAGE re-initializes the command)."
  (let ((opt (clingon:find-option :by-key command key)))
    (and opt (clingon:option-is-set-p opt) t)))

(defmethod clingon:finalize-command :around ((command %protocol-command))
  (let ((out (make-string-output-stream))
        (flags (append
                (and (%builtin-set-p command :clingon.help.flag)
                     (list :help t))
                (and (%builtin-set-p command :clingon.version.flag)
                     (list :version t)))))
    (setf (%builtin-flags command) nil)
    (handler-case
        (let ((*standard-output* out))
          (call-next-method))
      (clingon:exit-error (e)
        (progn
          (cond
            ((and flags (zerop (clingon:exit-error-code e)))
             (setf (%builtin-flags command) flags)
             command)
            (t
             (write-string (get-output-stream-string out))
             (error e))))))))

(defun %builtin-request (matched)
  "→ (values FLAGS COMMAND): the built-in flags plist given on MATCHED or a
parent command, and the native command they were given to."
  (dolist (cmd (clingon:command-lineage matched) (values nil nil))
    (when (and (typep cmd '%protocol-command) (%builtin-flags cmd))
      (return (values (%builtin-flags cmd) cmd)))))

(defun %native-options (options)
  (mapcar #'cli-option-backend options))

(defun %native-subcommands (subcommands)
  (mapcar #'cli-command-backend subcommands))

(defmethod backend-make-command ((backend clingon-backend)
                                 &key name description version options subcommands handler)
  (let* ((cmd (make-instance 'cli-command
                             :name name
                             :description (or description "")
                             :version version
                             :options options
                             :subcommands subcommands
                             :handler handler))
         (native
           (make-instance '%protocol-command
            :name (string name)
            :description (or description "")
            :version (or version "0.0.0")
            :options (%native-options options)
            :sub-commands (%native-subcommands subcommands)
            :handler (lambda (c)
                       (when handler
                         (let ((opts nil)
                               (free (clingon:command-arguments c)))
                           (dolist (opt options)
                             (setf opts
                                   (list* (cli-option-key opt)
                                          (clingon:getopt c (cli-option-key opt))
                                          opts)))
                           (funcall handler opts free)))))))
    (setf (cli-command-backend cmd) native)
    cmd))

(defmethod backend-parse ((backend clingon-backend) (command cli-command) argv)
  (let* ((native (cli-command-backend command))
         (matched (clingon:parse-command-line native argv))
         (opts nil)
         (free (clingon:command-arguments matched)))
    ;; Collect opts from matched command's known option keys (walk tree)
    (labels ((collect (cmd)
               (dolist (opt (cli-command-options cmd))
                 (setf opts (list* (cli-option-key opt)
                                   (clingon:getopt matched (cli-option-key opt))
                                   opts)))
               (dolist (sub (cli-command-subcommands cmd))
                 (collect sub))))
      (collect command))
    ;; Built-in --help / --version: reported as :help / :version keys.
    (let ((flags (%builtin-request matched)))
      (loop for (k v) on flags by #'cddr
            do (setf opts (list* k v opts))))
    (values opts free)))

(defmethod backend-run ((backend clingon-backend) (command cli-command) argv)
  ;; Do not call clingon:run — it always EXIT/QUIT. Parse + invoke handler ourselves.
  (let* ((native (cli-command-backend command))
         (matched (clingon:parse-command-line native argv))
         (handler (clingon:command-handler matched)))
    (multiple-value-bind (flags cmd) (%builtin-request matched)
      (cond
        ((getf flags :help)
         (clingon:print-usage cmd *standard-output*)
         (error 'cli-help-requested :command-name (clingon:command-full-name cmd)))
        ((getf flags :version)
         (let ((v (find-if #'clingon:command-version (clingon:command-lineage cmd))))
           (when v (clingon:print-version v *standard-output*)))
         (error 'cli-version-requested
                :command-name (clingon:command-full-name cmd)))))
    (unless handler
      (error 'cli-usage-error
             :message (format nil "no handler for command ~a"
                              (clingon:command-name matched))))
    (funcall handler matched)))

(defmethod backend-format-usage ((backend clingon-backend) (command cli-command)
                                 &key (stream *standard-output*) styles)
  (clingon:print-usage (cli-command-backend command) stream)
  (terpri stream)
  ;; Platform-relevant spellings hint
  (format stream "~&Option dialects: --long / -s")
  (when (member :powershell (resolve-option-styles styles))
    (format stream "; -Long (PowerShell)"))
  (when (member :cmd (resolve-option-styles styles))
    (format stream "; /Long (CMD)"))
  (terpri stream))

(use-clingon-backend)
