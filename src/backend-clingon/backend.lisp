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
           (clingon:make-command
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
    (values opts free)))

(defmethod backend-run ((backend clingon-backend) (command cli-command) argv)
  ;; Do not call clingon:run — it always EXIT/QUIT. Parse + invoke handler ourselves.
  (let* ((native (cli-command-backend command))
         (matched (clingon:parse-command-line native argv))
         (handler (clingon:command-handler matched)))
    (unless handler
      (error 'cli-usage-error
             :message (format nil "no handler for command ~a"
                              (clingon:command-name matched))))
    (funcall handler matched)))

(defmethod backend-format-usage ((backend clingon-backend) (command cli-command)
                                 &key (stream *standard-output*) styles)
  (declare (ignore styles))
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
