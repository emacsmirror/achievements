;;; achievements-functions.el --- achievements for emacs usage

;; Author: Ivan Andrus <darthandrus@gmail.com>
;; Maintainer: Ivan Andrus <darthandrus@gmail.com>
;; Created: 2012-10-07
;; Keywords: games

;;; Install:

;; A simple (require 'achievements).  However, currently it is also
;; highly recommended to install the keyfreq or command-frequency
;; package in order to get all the functionality.

;;; Commentary:

;; Running `achievements-list-achievements' will show a list of all
;; unlocked achievements.

;;; Code:

;; TODO: easy way to show a random unearned achievement, perhaps on an idle timer

(require 'cl)

(defconst achievements-file
  (expand-file-name ".achievements" user-emacs-directory)
  "File to store the achievements in.")

(defvar achievements-list nil
  "List of all possible achievements.")

(defvar achievements-post-command-list nil
  "List of achievements that need to be checked on `post-command-hook'.")

(defvar achievements-score 0
  "Score of all earned achievements.")

(defvar achievements-total 0
  "Highest possible score of all unlocked achievements.")

(defcustom achievements-debug nil
  "If non-nil, various debug messages will be printed regarding achievements activity."
  :type 'bool
  :group 'achievements)

;;{{{ Persistence & startup

(defun achievements-save-achievements ()
  "Saves achievements to a super secret file."
  (interactive)
  (let ((print-level nil)
        (print-length nil))
    (with-temp-file achievements-file
      (prin1 achievements-list (current-buffer)))))

(defun achievements-load-achievements ()
  "Load achievements from a super secret file.
This overwrites `achievements-list'."
  (interactive)
  (setq achievements-list
        (when (file-exists-p achievements-file)
          ;; Load sexp
          (let* ((l (condition-case nil
                        (with-temp-buffer
                          (insert-file-contents achievements-file)
                          (goto-char (point-min))
                          (read (current-buffer)))
                      ;; Catch empty file i.e., end of file during parsing
                      (error nil)))
                 (ll (and (listp l) l)))
            ;; Was it valid sexp?
            (and achievements-debug
                 (null ll)
                 (message "File %s does not contain valid data"
                          achievements-file))
            ll))))

;; Set up hooks and initialization
;;;###autoload
(defun achievements-init ()
  "Initialize achievements package."
  (when (null achievements-list)
    (achievements-load-achievements))
  (add-hook 'kill-emacs-hook #'achievements-save-achievements)
  ;; Load the basic achievements
  (require 'basic-achievements))

;;}}}
;;{{{ Defining achievements

(defstruct
    (emacs-achievement
     (:constructor nil)
     (:constructor make-achievement
                   (name description
                         ;; &optional (predicate t)
                         &key
                         ;; slots
                         points transient min-score predicate unlocks post-command
                         ;; convenience
                         package variable command
                         &aux (predicate
                               `(lambda ()
                                  ;; package
                                  (and
                                   ,@(when package
                                       (list (list 'featurep
                                                   (list 'quote package))))
                                   ,@(when variable
                                       (list (list 'achievements-variable-was-set
                                                   (list 'quote variable))))
                                   ,@(when command
                                       (list (list 'achievements-command-was-run
                                                   (list 'quote command))))
                                   ,@(when post-command
                                      (list nil))
                                   ;; TODO: allow functions here not just forms
                                   ,@(when predicate
                                       (list predicate))))))))

  (name nil :read-only t)
  description
  predicate ;; t if satisfied, nil if opted out, otherwise a function which should return non-nil on success
  transient ;; if non-nil then results won't be saved, but constantly re-evaluated.
  post-command ;; a predicate that needs to be run in post-command-hook
  (points 5)
  (min-score 0)
  unlocks
  )

(defmacro defachievement (name &rest body)
  `(add-to-list 'achievements-list
                ,(if (stringp (car-safe body))
                     `(make-achievement ,name ,@body)
                   `(make-achievement ,name nil ,@body)
                   )
                t
                ;; We compare by name only, since the predicate will often be different
                (lambda (a b)
                  (equal (emacs-achievement-name a)
                         (emacs-achievement-name b)))))

(defmacro defcommand-achievements (format-str body &rest arguments)
  (cons 'progn
        (loop for achiev in body
              collect (append
                       (list 'defachievement
                             (cadr achiev)
                             (format format-str
                                     (car achiev)
                                     (cddr achiev))
                             :command (list 'function (car achiev)))
                       arguments))))

(defmacro defvalue-achievements (var format-str body &rest arguments)
  (cons 'progn
        (loop for achiev in body
              collect (append
                       (list 'defachievement
                             (car achiev)
                             (format format-str
                                     (if (car-safe (cddr achiev))
                                         (car (cddr achiev))
                                       (cadr achiev))
                                     var)
                             :variable (list 'quote
                                             (list var (cadr achiev))))
                       arguments))))

;;}}}
;;{{{ Testing achievements

(defun achievements-variable-was-set (var)
  "If VAR is a cons, return non-nil if (car VAR) is equal to (cdr VAR).
If VAR is a symbol, return non-nil if VAR has been set in
customize or .emacs (not yet implemented)."
  (if (listp var)
      (equal (symbol-value (car var)) (cadr var))
    ;; it was set via customize etc.
    (or (and (symbol-value var)
             (string-match "\\(-hook\\|-function\\)\\'" (symbol-name var)))
        (and
         (get var 'custom-type) (get var 'standard-value)
         (not (equal (symbol-value var) (eval (car (get var 'standard-value)))))))))

(defun achievements-num-times-commands-were-run (command-list)
  "Return the number of times any one of the commands was run.
Right now this is checked it `command-frequency', but it is hoped
that in the future there will be other methods."
  (cond ((require 'keyfreq nil t)
         (let ((table (copy-hash-table keyfreq-table))
               (total 0))
           ;; Merge with the values in .emacs.keyfreq file
           (keyfreq-table-load table)
           (maphash
            (lambda (k v)
              (when (memq (cdr k) command-list)
                (setq total (+ total v))))
            table)
           total))
        ((require 'command-frequency nil t)
         (let ((command-freq (cdr (command-frequency-list)))
               (total 0))
           (loop for com in command-freq
                 if (member (car com) command-list)
                 do (setq total (+ total (cdr com))))
           total))
        (t (let ((total 0))
             (mapc
              (lambda (x)
                (when (memq (car x) command-list)
                  (setq total (+ total 1))))
              command-history)
             total))))

(defun achievements-command-was-run (command)
  "Return non-nil if COMMAND has been run.
It can be a single command form or list of command forms.
If it's a list of forms, then all must be run.
Each form has one of the forms
 COMMAND -- must be run once
 (CMD1 CMD2 ...) -- any can be run
 (COMMAND . COUNT) -- must be run COUNT times
 ((CMD1 CMD2 ...) . COUNT) -- must be run COUNT times
symbol for a command which must be."
  (let (command-list)
    (cond
     ;; A symbol
     ((symbolp command)
      (>= (achievements-num-times-commands-were-run (list command))
          1))
     ;; cdr is a number
     ((numberp (cdr command))
      (>= (achievements-num-times-commands-were-run
           (if (listp (car command)) (car command) (list (car command))))
          (cdr command)))
     ;; A list of commands that are AND-ed
     ((or (symbolp (car-safe command))
          (numberp (cdr-safe (car-safe command))))
      (every 'achievements-command-was-run command))
     ;; Otherwise it's a list of commands, any of which could be run
     (t
      (>= (achievements-num-times-commands-were-run
           (car command))
          1)))))

;;}}}
;;{{{ Display

(defun achievements-earned-message (achievement)
  "Display the message when an achievement is earned."
  (message "You earned the %s achievement!"
           (emacs-achievement-name achievement)))

(defun achievements-update-score ()
  (let ((score 0)
        (total 0))
    (dolist (achievement achievements-list)
      (let ((points (emacs-achievement-points achievement)))
        (incf total points)
        (when (achievements-earned-p achievement)
          (incf score points)
          (when (emacs-achievement-unlocks achievement)
            (require (emacs-achievement-unlocks achievement) nil t))
          (unless (emacs-achievement-transient achievement)
            (when (and achievements-display-when-earned
                       (not (equal (emacs-achievement-predicate achievement) t)))
              (achievements-earned-message achievement))
            (setf (emacs-achievement-predicate achievement) t)))))
    ;; Save the updated list of achievements
    (achievements-save-achievements)
    (setq achievements-total total)
    (setq achievements-score score)))

(defun achievements-earned-p (achievement)
  "Returns non-nil if the achievement is earned."
  (let ((pred (emacs-achievement-predicate achievement)))
    (or (eq pred t)
        (and (listp pred)
             (funcall pred)))))

;; TODO: Use `tabulated-list-mode' -- what package.el uses or ewoc
;;;###autoload
(defun achievements-list-achievements ()
  "Display all achievements including whether they have been achieved."
  (interactive)
  (pop-to-buffer "*Achievements*")
  (delete-region (point-min) (point-max))
  (achievements-update-score)
  (dolist (achievement achievements-list)
    (let ((pred (emacs-achievement-predicate achievement)))
      (when (>= achievements-score
                (emacs-achievement-min-score achievement))
        (insert (format "%s %20s | %s\n"
                        (cond ((eq pred nil) ":-|")
                              ((eq pred t) ":-)")
                              ((listp pred)
                               (if (funcall pred) ":-)" ":-("))
                              (t ":-?"))
                        (emacs-achievement-name achievement)
                        (emacs-achievement-description achievement)))))))

;;}}}
;;{{{ Achievements Mode

(defvar achievements-timer nil
  "Holds the idle timer.")

(defcustom achievements-display-when-earned t
  "If non-nil, various debug messages will be printed regarding achievements activity."
  :type 'bool
  :group 'achievements)

(defcustom achievements-idle-time 10
  "Number of seconds for Emacs to be idle before checking if achievements have been earned."
  :type 'numberp
  :group 'achievements)

(defun achievements-setup-post-command-hook ()
  "Add the appropriate achievements for the post-command-hook."
  (setq achievements-post-command-list nil)
  (dolist (achievement achievements-list)
    (when (and (emacs-achievement-post-command achievement)
               (not (eq t (emacs-achievement-predicate achievement))))
      (add-to-list 'achievements-post-command-list achievement))))

(defun achievements-post-command-function ()
  "Check achievements on `post-command-hook'."
  (flet ((remove (v) (setq achievements-post-command-list
                           (delete v achievements-post-command-list))))
    (dolist (achievement achievements-post-command-list)
      (let ((pred (emacs-achievement-post-command achievement)))
        (if (functionp pred)
            (when (funcall pred)
              (setf (emacs-achievement-predicate achievement) t)
              (achievements-earned-message achievement)
              (remove achievement))
          (remove achievement))))))

;;;###autoload
(define-minor-mode achievements-mode
  "Turns on automatic earning of achievements when idle."
  ;; The lighter is a trophy
  nil " 🏆" nil
  (if achievements-mode
      (progn
        (unless achievements-timer
          (setq achievements-timer
                (run-with-idle-timer achievements-idle-time
                                     t #'achievements-update-score)))
        (achievements-setup-post-command-hook)
        (add-hook 'post-command-hook #'achievements-post-command-function))
    (setq achievements-timer (cancel-timer achievements-timer))
    (remove-hook 'post-command-hook #'achievements-post-command-function)))

;;}}}

(provide 'achievements-functions)

;;; achievements-functions.el ends here
