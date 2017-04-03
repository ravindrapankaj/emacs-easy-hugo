;;; easy-hugo.el --- Write blogs made with hugo by markdown or org-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2017 by Masashı Mıyaura

;; Author: Masashı Mıyaura
;; URL: https://github.com/masasam/emacs-easy-hugo
;; Version: 0.5.1
;; Package-Requires: ((emacs "24.4"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Package for writing blogs made with hugo by markdown or org-mode

;;; Code:

(defgroup easy-hugo nil
  "Writing blogs made with hugo."
  :group 'tools)

(defcustom easy-hugo-basedir nil
  "Directory where hugo html source code is placed."
  :group 'easy-hugo
  :type 'string)

(defcustom easy-hugo-url nil
  "Url of the site operated by hugo."
  :group 'easy-hugo
  :type 'string)

(defcustom easy-hugo-sshdomain nil
  "Domain of hugo at your ~/.ssh/config."
  :group 'easy-hugo
  :type 'string)

(defcustom easy-hugo-root nil
  "Root directory of hugo at your server."
  :group 'easy-hugo
  :type 'string)

(defcustom easy-hugo-previewtime 300
  "Preview display time."
  :group 'easy-hugo
  :type 'integer)

(defcustom easy-hugo-default-ext ".md"
  "Default extension when posting new articles."
  :group 'easy-hugo
  :type 'string)

(defvar easy-hugo--server-process nil)

(defconst easy-hugo--buffer-name "*Hugo Server*")

(defconst easy-hugo--formats '("md" "org"))

;;;###autoload
(defun easy-hugo-article ()
  "Open a list of articles written in hugo."
  (interactive)
  (unless easy-hugo-basedir
    (error "Please set easy-hugo-basedir variable"))
  (find-file (expand-file-name "content/post" easy-hugo-basedir)))

(defmacro easy-hugo-with-env (&rest body)
  "Evaluate BODY with `default-directory' set to `easy-hugo-basedir'.
Report an error if hugo is not installed, or if `easy-hugo-basedir' is unset."
  `(progn
     (unless easy-hugo-basedir
       (error "Please set easy-hugo-basedir variable"))
     (unless (executable-find "hugo")
       (error "'hugo' is not installed"))
     (let ((default-directory easy-hugo-basedir))
       ,@body)))

;;;###autoload
(defun easy-hugo-publish ()
  "Adapt local change to the server with hugo."
  (interactive)
  (unless easy-hugo-sshdomain
    (error "Please set easy-hugo-sshdomain variable"))
  (unless easy-hugo-root
    (error "Please set easy-hugo-root variable"))
  (unless (executable-find "rsync")
    (error "'rsync' is not installed"))
  (unless (file-exists-p "~/.ssh/config")
    (error "There is no ~/.ssh/config"))
  (easy-hugo-with-env
   (delete-directory "public" t nil)
   (shell-command-to-string "hugo --destination public")
   (shell-command-to-string (concat "rsync -rtpl --delete public/ " easy-hugo-sshdomain ":" (shell-quote-argument easy-hugo-root)))
   (message "Blog published")
   (when easy-hugo-url
     (browse-url easy-hugo-url))))

(defun easy-hugo--org-headers (file)
  "Return a draft org mode header string for a new article as FILE."
  (let ((datetimezone
         (concat
          (format-time-string "%Y-%m-%dT%T")
          (easy-hugo--orgtime-format (format-time-string "%z")))))
    (concat
     "#+TITLE: " file
     "\n#+DATE: " datetimezone
     "\n#+PUBLISHDATE: " datetimezone
     "\n#+DRAFT: nil"
     "\n#+TAGS: nil, nil"
     "\n#+DESCRIPTION: Short description"
     "\n\n")))

;;;###autoload
(defun easy-hugo-newpost (post-file)
  "Create a new post with hugo.
POST-FILE needs to have and extension '.md' or '.org'."
  (interactive (list (read-from-minibuffer "Filename: " `(,easy-hugo-default-ext . 1) nil nil nil)))
  (let ((filename (concat "post/" post-file))
        (file-ext (file-name-extension post-file)))
    (when (not (member file-ext easy-hugo--formats))
      (error "Please enter .md or .org file name"))
    (easy-hugo-with-env
     (when (file-exists-p (file-truename (concat "content/" filename)))
       (error "%s already exists!" (concat easy-hugo-basedir "content/" filename)))
     (if (string-equal file-ext "md")
         (call-process "hugo" nil "*hugo*" t "new" filename))
     (find-file (concat "content/" filename))
     (if (string-equal file-ext "org")
         (insert (easy-hugo--org-headers (file-name-base post-file))))
     (goto-char (point-max))
     (save-buffer))))

;;;###autoload
(defun easy-hugo-preview ()
  "Preview hugo at localhost."
  (interactive)
  (easy-hugo-with-env
   (if (process-live-p easy-hugo--server-process)
       (browse-url "http://localhost:1313/")
     (progn
       (setq easy-hugo--server-process
             (start-process "hugo-server" easy-hugo--buffer-name "hugo" "server"))
       (browse-url "http://localhost:1313/")
       (run-at-time easy-hugo-previewtime nil 'easy-hugo--preview-end)))))

(defun easy-hugo--preview-end ()
  "Finish previewing hugo at localhost."
  (unless (null easy-hugo--server-process)
    (delete-process easy-hugo--server-process)))

(defun easy-hugo--orgtime-format (x)
  "Format orgtime as X."
  (concat (substring x 0 3) ":" (substring x 3 5)))

;;;###autoload
(defun easy-hugo-deploy ()
  "Execute deploy.sh script locate at 'easy-hugo-basedir'."
  (interactive)
  (easy-hugo-with-env
   (let ((deployscript (file-truename (concat easy-hugo-basedir "deploy.sh"))))
     (unless (executable-find deployscript)
       (error "%s do not execute" deployscript))
     (shell-command-to-string (shell-quote-argument deployscript))
     (message "Blog deployed")
     (when easy-hugo-url
       (browse-url easy-hugo-url)))))

(defconst easy-hugo-help
  "Easy-hugo

n   ... Write new post
p   ... Preview
l   ... List of article with dired
P   ... Publish to server
D   ... Deploy at github-pages etc
d   ... Delete current post
RET ... Open current post
r   ... Refresh
q   ... quit easy-hugo

"
  "Help of easy-hugo.")

(defvar easy-hugo-mode-map
  (let ((map (make-keymap)))
    (define-key map "n" #'easy-hugo-newpost)
    (define-key map "l" #'easy-hugo-article)
    (define-key map "p" #'easy-hugo-preview)
    (define-key map "P" #'easy-hugo-publish)
    (define-key map "RET" #'easy-hugo-open)
    (define-key map "D" #'easy-hugo-deploy)
    (define-key map "q" #'easy-hugo-quit)
    map)
  "Keymap for easy-hugo major mode.")

(defvar easy-hugo-mode-buffer nil
  "Main buffer of easy-hugo.")

(define-derived-mode easy-hugo-mode special-mode "Easyhugo"
  "Major mode for easy hugo."
  )

(defun easy-hugo-quit ()
  "Quit easy hugo."
  (interactive)
  (buffer-live-p easy-hugo-mode-buffer)
  (kill-buffer easy-hugo-mode-buffer))

(defun easy-hugo-open ()
  "Open file."
  (interactive))

;;;###autoload
(defun easy-hugo ()
  "Easy hugo."
  (interactive)
  (setq easy-hugo-mode-buffer (get-buffer-create "*Easy-hugo*"))
  (switch-to-buffer easy-hugo-mode-buffer)
  (setq-local default-directory easy-hugo-basedir)
  (setq buffer-read-only nil)
  (erase-buffer)
  (insert easy-hugo-help)
  (let ((dir (directory-files (expand-file-name "content/post" easy-hugo-basedir))))
    (while dir
      (unless (or (string= (car dir) ".") (string= (car dir) ".."))
	(insert (concat (car dir) "\n")))
      (setq dir (cdr dir)))
    (easy-hugo-mode)
    )
  )

(provide 'easy-hugo)

;;; easy-hugo.el ends here
