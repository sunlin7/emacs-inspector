;;; emacs-inspector.el --- Inspector for Emacs Lisp objects  -*- lexical-binding: t -*-

;;; Commentary:

;; Emacs Lisp objects inspector.

;;; Code:

(require 'eieio)

(defun princ-to-string (object)
  "Print OBJECT to string using `princ'."
  (with-output-to-string
    (princ object)))

(defun plistp (list)
  "Return T if LIST is a property list."
  (let ((expected t))
    (and (evenp (length list))
         (every (lambda (x)
                  (setq expected (if (eql expected t) 'symbol t))
                  (typep x expected))
                list))))

(defun alistp (list)
  "Return T if LIST is an association list."
  (every (lambda (x)
           (and (consp x)
                (symbolp (car x))))
         list))

(cl-defgeneric inspect-object (object))

(cl-defmethod inspect-object ((class (subclass eieio-default-superclass)))
  (insert (format "Class: %s" (eioio-class-name class)))
  (newline 2)
  (insert "Direct superclasses: ")
  (dolist (superclass (eieio-class-parents class))
    (inspector--insert-inspect-button
     (eioio-class-name superclass) (eieio-class-name superclass))
    (insert " "))
  (newline)
  (insert "Class slots: ")
  (dolist (slot (eieio-class-slots class))
    (insert (format "%s " (cl--slot-descriptor-name slot))))
  (newline)
  (insert "Direct subclasses:")
  (dolist (subclass (eieio-class-children class))
    (inspector--insert-inspect-button
     (eieio-class-name subclass) (eieio-class-name subclass))
    (insert " ")))

(cl-defmethod inspect-object ((object (eql t)))
  (debug "True"))

(cl-defmethod inspect-object ((object (eql nil)))
  (debug "Null"))

(cl-defmethod inspect-object ((object symbol))
  (debug "Symbol"))

(cl-defmethod inspect-object ((object t))
  (cond
   ((eieio-object-p object)
    (insert "Instance of ")
    (inspector--insert-inspect-button
     (eieio-object-class object)
     (eieio-class-name (eieio-object-class object)))
    (newline 2)
    (insert "Slot values:")
    (newline)
    (dolist (slot (eieio-class-slots (eieio-object-class object)))
      (insert (format "%s: " (cl--slot-descriptor-name slot)))
      (inspector--insert-inspect-button
       (slot-value object (cl--slot-descriptor-name slot)))
      (newline)))
   (t (error "Cannot inspect object: %s" object))))

(defun inspector--insert-inspect-button (object &optional label)
  "Insert button for inspecting OBJECT.
If LABEL has a value, then it is used as button label.  Otherwise, button label is the printed representation of OBJECT."
  (insert-button (or (and label (princ-to-string label))
                     (prin1-to-string object))
                 'action (lambda (btn)
			   (inspector-inspect object))
                 'follow-link t))

(cl-defmethod inspect-object ((cons cons))
  (cond
   ((and (listp cons) (plistp cons))
    (insert "Property list: ")
    (newline)
    (let ((plist (copy-list cons)))
      (while plist
        (let ((key (pop plist)))
          (inspector--insert-inspect-button key))
        (insert ": ")
        (let ((value (pop plist)))
          (inspector--insert-inspect-button value))
        (newline))))
   ((listp cons)
    (insert "Proper list:")
    (newline)
    (let ((i 0))
      (dolist (elem cons)
        (insert (format "%d: " i))
        (inspector--insert-inspect-button elem)
        (newline)
        (incf i))))))

(cl-defmethod inspect-object ((string string))
  (insert "String: ")
  (prin1 string (current-buffer)))

(cl-defmethod inspect-object ((array array))
  (debug "Inspect array"))

(cl-defmethod inspect-object ((sequence sequence))
  (debug "Inspect sequence"))

(cl-defmethod inspect-object ((list list))
  (debug "Inspect list"))

(cl-defmethod inspect-object ((buffer buffer))
  (debug "Inspect buffer"))

(cl-defmethod inspect-object ((number number))
  (debug "Inspect number"))

(cl-defmethod inspect-object ((integer integer))
  (insert "Integer: ")
  (princ integer (current-buffer))
  (newline)
  (insert "Char: ")
  (princ (char-to-string integer) (current-buffer)))

(cl-defmethod inspect-object ((hash-table hash-table))
  (debug "Inspect hash-table"))

(defun inspector-make-inspector-buffer ()
  "Create an inspector buffer."
  (let ((buffer (get-buffer-create "*inspector*")))
    (with-current-buffer buffer
      (inspector-mode)
      (setq buffer-read-only nil)
      (erase-buffer))
    buffer))

(defun inspect-expression (exp)
  "Evaluate and inspect EXP expression."
  (interactive (list (read--expression "Eval and inspect: ")))

  (inspector-inspect (eval exp)))

(defun inspector-inspect (object)
  "Top-level function for inspecting OBJECTs."
  (let ((buffer (inspector-make-inspector-buffer)))
    (with-current-buffer buffer
      (inspect-object object)
      (setq buffer-read-only t)
      (display-buffer buffer))))

(defgroup inspector nil
  "Emacs Lisp inspector customizations."
  :group 'lisp)

(defcustom inspector-use-one-buffer t
  "Inspect objects in one buffer."
  :type 'boolean
  :group 'inspector)

(defvar inspector-mode-map
  (let ((map (make-keymap)))
    (define-key map (kbd "q") 'inspector-quit)))

(define-minor-mode inspector-mode
  "Minor mode for inspector buffers."
  :init-value nil
  :lighter " inspector"
  :keymap inspector-mode-map
  :group 'inspector)

;; Better define and use a major mode?:
;; (define-derived-mode inspector-mode fundamental-mode
;;   "Inspector"
;;   "
;; \\{inspector-mode-map}"
;;   (set-syntax-table lisp-mode-syntax-table)
;;   ;;(slime-set-truncate-lines)
;;   (setq buffer-read-only t))

(provide 'inspector)

;;; inspector.el ends here