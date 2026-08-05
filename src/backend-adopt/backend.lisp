(in-package #:cli-backend-adopt)

(defclass adopt-backend (cli-backend) ())

(defun make-adopt-backend ()
  (make-instance 'adopt-backend))

(defun use-adopt-backend ()
  "Bind *CLI-BACKEND* to adopt. Returns the backend."
  (setf *cli-backend* (make-adopt-backend)))

(defun %option-key (name key)
  (or key (intern (string-upcase (string name)) :keyword)))

(defun %takes-value-p (kind)
  (cli-protocol::%option-takes-value-p kind))

(defun %adopt-reduce (kind)
  (case kind
    ((:flag :boolean/true) (lambda (old) (declare (ignore old)) t))
    (:counter (lambda (old) (1+ (or old 0))))
    ((:list) #'adopt:collect)
    (otherwise #'adopt:last)))

(defmethod backend-make-option ((backend adopt-backend)
                                &key name short long kind default required env help key)
  (let* ((k (%option-key name key))
         (long-name (or long (when name (string-downcase (string name)))))
         (takes (%takes-value-p kind))
         (native (apply #'adopt:make-option
                        k
                        :help (or help "")
                        :result-key k
                        :reduce (%adopt-reduce kind)
                        (append
                         (when short (list :short short))
                         (when long-name (list :long long-name))
                         (when takes (list :parameter "VALUE"))
                         (when (and takes (eq kind :integer))
                           (list :key #'parse-integer))
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

(defmethod backend-make-command ((backend adopt-backend)
                                 &key name description version options subcommands handler)
  (when subcommands
    (error 'cli-usage-error
           :message "cli-backend-adopt does not support subcommands — use clingon"))
  (let* ((cmd (make-instance 'cli-command
                             :name name
                             :description (or description "")
                             :version version
                             :options options
                             :subcommands nil
                             :handler handler))
         (iface (adopt:make-interface
                 :name (string name)
                 :summary (or description "")
                 :usage "[options]"
                 :help (or description "")
                 :contents (mapcar #'cli-option-backend options))))
    (setf (cli-command-backend cmd) iface)
    cmd))

(defmethod backend-parse ((backend adopt-backend) (command cli-command) argv)
  ;; adopt:parse-options → (values free-args results-hash) — opposite of our DX.
  (multiple-value-bind (free results)
      (adopt:parse-options (cli-command-backend command) argv)
    (let ((opts nil))
      (maphash (lambda (k v) (setf opts (list* k v opts))) results)
      (values opts free))))

(defmethod backend-run ((backend adopt-backend) (command cli-command) argv)
  (multiple-value-bind (opts free)
      (backend-parse backend command argv)
    (let ((handler (cli-command-handler command)))
      (if handler
          (funcall handler opts free)
          (values opts free)))))

(defmethod backend-format-usage ((backend adopt-backend) (command cli-command)
                                 &key (stream *standard-output*) styles)
  (adopt:print-help (cli-command-backend command) :stream stream)
  (terpri stream)
  (format stream "~&Option dialects: --long / -s")
  (when (member :powershell (resolve-option-styles styles))
    (format stream "; -Long (PowerShell)"))
  (when (member :cmd (resolve-option-styles styles))
    (format stream "; /Long (CMD)"))
  (terpri stream))
