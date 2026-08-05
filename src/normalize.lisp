(in-package #:cli-protocol)

(defvar *cli-option-styles* :auto
  ":auto | list of :posix :powershell :cmd")

(defun windows-p ()
  (uiop:os-windows-p))

(defun resolve-option-styles (&optional (styles *cli-option-styles*))
  "Expand STYLES to a list of dialect keywords."
  (cond
    ((eq styles :auto)
     (if (windows-p)
         '(:posix :powershell :cmd)
         '(:posix :powershell)))
    ((listp styles) styles)
    (t (error 'cli-usage-error
              :message (format nil "unknown option styles: ~s" styles)))))

(defun %option-takes-value-p (kind)
  (not (member kind '(:flag :counter :boolean/true :boolean/false) :test #'eq)))

(defun %canonical-long (long)
  (string-downcase (string long)))

(defun %build-option-index (options &key case-insensitive)
  "Map long/short strings → option meta plist (:long :short :kind :takes-value)."
  (let ((by-long (make-hash-table :test (if case-insensitive #'equalp #'equal)))
        (by-short (make-hash-table :test #'equal)))
    (dolist (opt options)
      (let* ((long (cli-option-long opt))
             (short (cli-option-short opt))
             (kind (cli-option-kind opt))
             (meta (list :long (when long (%canonical-long long))
                         :short short
                         :kind kind
                         :takes-value (%option-takes-value-p kind))))
        (when long
          (setf (gethash (%canonical-long long) by-long) meta)
          (when case-insensitive
            (setf (gethash (string long) by-long) meta)))
        (when short
          (setf (gethash (string short) by-short) meta))))
    (values by-long by-short)))

(defun %lookup-long (by-long name &key case-insensitive)
  (or (gethash (%canonical-long name) by-long)
      (when case-insensitive
        (gethash name by-long))))

(defun %split-inline-value (token separator)
  "Split TOKEN at first SEPARATOR char → (values name value-or-nil)."
  (let ((pos (position separator token :test #'char=)))
    (if pos
        (values (subseq token 0 pos) (subseq token (1+ pos)))
        (values token nil))))

(defun %powershell-bool-token (value)
  "Map PowerShell :$true / :$false / bare → :flag presence or boolean string."
  (cond
    ((null value) nil)
    ((member (string-downcase value) '("$true" "true" "1") :test #'string=) "true")
    ((member (string-downcase value) '("$false" "false" "0") :test #'string=) "false")
    (t value)))

(defun normalize-argv (argv &key (styles *cli-option-styles*) options)
  "Dialect → POSIX tokens for backends.
   OPTIONS = list of CLI-OPTION (optional but needed for value attachment)."
  (let* ((style-list (resolve-option-styles styles))
         (case-insensitive (windows-p))
         (allow-ps (member :powershell style-list))
         (allow-cmd (member :cmd style-list))
         (by-long nil)
         (by-short nil))
    (when options
      (multiple-value-setq (by-long by-short)
        (%build-option-index options :case-insensitive case-insensitive)))
    (labels ((emit-long (long value takes-value out)
               (let ((canon (%canonical-long long)))
                 (push (format nil "--~a" canon) out)
                 (when (and takes-value value)
                   (push value out))
                 out))
             (emit-short (ch value takes-value out)
               (push (format nil "-~c" ch) out)
               (when (and takes-value value)
                 (push value out))
               out)
             (long-meta (name)
               (when by-long (%lookup-long by-long name :case-insensitive case-insensitive)))
             (short-meta (ch)
               (when by-short (gethash (string ch) by-short)))
             (takes-p (meta default)
               (if meta (getf meta :takes-value) default)))
      (let ((out nil)
            (i 0)
            (n (length argv))
            (end-opts nil))
        (loop while (< i n) do
          (let ((tok (elt argv i)))
            (incf i)
            (cond
              (end-opts
               (push tok out))
              ((string= tok "--")
               (setf end-opts t)
               (push tok out))
              ;; CMD slash: /v /Verbose /Count:3 /Count 3
              ((and allow-cmd
                    (> (length tok) 1)
                    (char= (char tok 0) #\/)
                    (not (char= (char tok 1) #\/)))
               (multiple-value-bind (name inline)
                   (%split-inline-value (subseq tok 1) #\:)
                 (let ((next (when (< i n) (elt argv i))))
                   (cond
                     ((= (length name) 1)
                      (let* ((ch (char name 0))
                             (meta (short-meta ch))
                             (takes (takes-p meta t))
                             (val (or inline
                                      (when (and takes next
                                                 (not (and (> (length next) 0)
                                                           (member (char next 0) '(#\- #\/)))))
                                        (incf i)
                                        next))))
                        (setf out (emit-short ch val takes out))))
                     (t
                      (let* ((meta (long-meta name))
                             (takes (takes-p meta t))
                             (val (or inline
                                      (when (and takes next
                                                 (not (and (> (length next) 0)
                                                           (member (char next 0) '(#\- #\/)))))
                                        (incf i)
                                        next))))
                        (setf out (emit-long name val takes out))))))))
              ;; PowerShell / single-dash long: -Verbose -Count 3 -Count:3 -Flag:$true
              ((and allow-ps
                    (> (length tok) 2)
                    (char= (char tok 0) #\-)
                    (not (char= (char tok 1) #\-))
                    (alpha-char-p (char tok 1))
                    (some #'alpha-char-p (subseq tok 2)))
               (multiple-value-bind (name inline)
                   (%split-inline-value (subseq tok 1) #\:)
                 (let* ((meta (long-meta name))
                        (takes (takes-p meta t))
                        (next (when (< i n) (elt argv i)))
                        (val (or (%powershell-bool-token inline)
                                 (when (and takes (null inline) next
                                            (not (and (> (length next) 0)
                                                      (char= (char next 0) #\-))))
                                   (incf i)
                                   next))))
                   (cond
                     ;; flag with :$false → emit --no-NAME if we only have flag; keep as boolean value
                     ((and meta (not (getf meta :takes-value)) inline)
                      (setf out (emit-long name nil nil out))
                      (when (string= val "false")
                        ;; clingon flags are presence-only; drop false as no-op (don't emit)
                        (pop out)))
                     (t
                      (setf out (emit-long name val takes out)))))))
              (t
               ;; POSIX / everything else unchanged
               (push tok out)))))
        (nreverse out)))))
