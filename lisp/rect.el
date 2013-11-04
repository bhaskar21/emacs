;;; rect.el --- rectangle functions for GNU Emacs  -*- lexical-binding:t -*-

;; Copyright (C) 1985, 1999-2013 Free Software Foundation, Inc.

;; Maintainer: Didier Verna <didier@xemacs.org>
;; Keywords: internal
;; Package: emacs

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides the operations on rectangles that are documented
;; in the Emacs manual.

;; ### NOTE: this file was almost completely rewritten by Didier Verna
;; <didier@xemacs.org> in July 1999.

;;; Code:

;; FIXME: this function should be replaced by `apply-on-rectangle'
(defun operate-on-rectangle (function start end coerce-tabs)
  "Call FUNCTION for each line of rectangle with corners at START, END.
If COERCE-TABS is non-nil, convert multi-column characters
that span the starting or ending columns on any line
to multiple spaces before calling FUNCTION.
FUNCTION is called with three arguments:
 position of start of segment of this line within the rectangle,
 number of columns that belong to rectangle but are before that position,
 number of columns that belong to rectangle but are after point.
Point is at the end of the segment of this line within the rectangle."
  (let (startcol startlinepos endcol endlinepos)
    (save-excursion
     (goto-char start)
     (setq startcol (current-column))
     (beginning-of-line)
     (setq startlinepos (point)))
    (save-excursion
     (goto-char end)
     (setq endcol (current-column))
     (forward-line 1)
     (setq endlinepos (point-marker)))
    (if (< endcol startcol)
	(setq startcol (prog1 endcol (setq endcol startcol))))
    (save-excursion
     (goto-char startlinepos)
     (while (< (point) endlinepos)
       (let (startpos begextra endextra)
	 (if coerce-tabs
	     (move-to-column startcol t)
	   (move-to-column startcol))
	 (setq begextra (- (current-column) startcol))
	 (setq startpos (point))
	 (if coerce-tabs
	     (move-to-column endcol t)
	   (move-to-column endcol))
	 ;; If we overshot, move back one character
	 ;; so that endextra will be positive.
	 (if (and (not coerce-tabs) (> (current-column) endcol))
	     (backward-char 1))
	 (setq endextra (- endcol (current-column)))
	 (if (< begextra 0)
	     (setq endextra (+ endextra begextra)
		   begextra 0))
	 (funcall function startpos begextra endextra))
       (forward-line 1)))
    (- endcol startcol)))

(defun apply-on-rectangle (function start end &rest args)
  "Call FUNCTION for each line of rectangle with corners at START, END.
FUNCTION is called with two arguments: the start and end columns of the
rectangle, plus ARGS extra arguments.  Point is at the beginning of line when
the function is called.
The final point after the last operation will be returned."
  (let (startcol startpt endcol endpt final-point)
    (save-excursion
      (goto-char start)
      (setq startcol (current-column))
      (beginning-of-line)
      (setq startpt (point))
      (goto-char end)
      (setq endcol (current-column))
      (forward-line 1)
      (setq endpt (point-marker))
      ;; ensure the start column is the left one.
      (if (< endcol startcol)
	  (let ((col startcol))
	    (setq startcol endcol endcol col)))
      ;; start looping over lines
      (goto-char startpt)
      (while (< (point) endpt)
	(apply function startcol endcol args)
	(setq final-point (point))
	(forward-line 1)))
    final-point))

(defun delete-rectangle-line (startcol endcol fill)
  (when (= (move-to-column startcol (if fill t 'coerce)) startcol)
    (delete-region (point)
		   (progn (move-to-column endcol 'coerce)
			  (point)))))

(defun delete-extract-rectangle-line (startcol endcol lines fill)
  (let ((pt (point-at-eol)))
    (if (< (move-to-column startcol (if fill t 'coerce)) startcol)
	(setcdr lines (cons (spaces-string (- endcol startcol))
			    (cdr lines)))
      ;; else
      (setq pt (point))
      (move-to-column endcol t)
      (setcdr lines (cons (filter-buffer-substring pt (point) t) (cdr lines))))
    ))

;; This is actually the only function that needs to do complicated
;; stuff like what's happening in `operate-on-rectangle', because the
;; buffer might be read-only.
(defun extract-rectangle-line (startcol endcol lines)
  (let (start end begextra endextra line)
    (move-to-column startcol)
    (setq start (point)
	  begextra (- (current-column) startcol))
    (move-to-column endcol)
    (setq end (point)
	  endextra (- endcol (current-column)))
    (setq line (buffer-substring start (point)))
    (if (< begextra 0)
	(setq endextra (+ endextra begextra)
	      begextra 0))
    (if (< endextra 0)
	(setq endextra 0))
    (goto-char start)
    (while (search-forward "\t" end t)
      (let ((width (- (current-column)
		      (save-excursion (forward-char -1)
				      (current-column)))))
	(setq line (concat (substring line 0 (- (point) end 1))
			   (spaces-string width)
			   (substring line (+ (length line)
					      (- (point) end)))))))
    (if (or (> begextra 0) (> endextra 0))
	(setq line (concat (spaces-string begextra)
			   line
			   (spaces-string endextra))))
    (setcdr lines (cons line (cdr lines)))))

(defconst spaces-strings
  '["" " " "  " "   " "    " "     " "      " "       " "        "])

(defun spaces-string (n)
  "Return a string with N spaces."
  (if (<= n 8) (aref spaces-strings n)
    (make-string n ?\s)))

;;;###autoload
(defun delete-rectangle (start end &optional fill)
  "Delete (don't save) text in the region-rectangle.
The same range of columns is deleted in each line starting with the
line where the region begins and ending with the line where the region
ends.

When called from a program the rectangle's corners are START and END.
With a prefix (or a FILL) argument, also fill lines where nothing has
to be deleted."
  (interactive "*r\nP")
  (apply-on-rectangle 'delete-rectangle-line start end fill))

;;;###autoload
(defun delete-extract-rectangle (start end &optional fill)
  "Delete the contents of the rectangle with corners at START and END.
Return it as a list of strings, one for each line of the rectangle.

When called from a program the rectangle's corners are START and END.
With an optional FILL argument, also fill lines where nothing has to be
deleted."
  (let ((lines (list nil)))
    (apply-on-rectangle 'delete-extract-rectangle-line start end lines fill)
    (nreverse (cdr lines))))

;;;###autoload
(defun extract-rectangle (start end)
  "Return the contents of the rectangle with corners at START and END.
Return it as a list of strings, one for each line of the rectangle."
  (let ((lines (list nil)))
    (apply-on-rectangle 'extract-rectangle-line start end lines)
    (nreverse (cdr lines))))

(defvar killed-rectangle nil
  "Rectangle for `yank-rectangle' to insert.")

;;;###autoload
(defun kill-rectangle (start end &optional fill)
  "Delete the region-rectangle and save it as the last killed one.

When called from a program the rectangle's corners are START and END.
You might prefer to use `delete-extract-rectangle' from a program.

With a prefix (or a FILL) argument, also fill lines where nothing has to be
deleted.

If the buffer is read-only, Emacs will beep and refrain from deleting
the rectangle, but put it in the kill ring anyway.  This means that
you can use this command to copy text from a read-only buffer.
\(If the variable `kill-read-only-ok' is non-nil, then this won't
even beep.)"
  (interactive "r\nP")
  (condition-case nil
      (setq killed-rectangle (delete-extract-rectangle start end fill))
    ((buffer-read-only text-read-only)
     (setq deactivate-mark t)
     (setq killed-rectangle (extract-rectangle start end))
     (if kill-read-only-ok
	 (progn (message "Read only text copied to kill ring") nil)
       (barf-if-buffer-read-only)
       (signal 'text-read-only (list (current-buffer)))))))

;;;###autoload
(defun copy-rectangle-as-kill (start end)
  "Copy the region-rectangle and save it as the last killed one."
  (interactive "r")
  (setq killed-rectangle (extract-rectangle start end))
  (setq deactivate-mark t)
  (if (called-interactively-p 'interactive)
      (indicate-copied-region (length (car killed-rectangle)))))

;;;###autoload
(defun yank-rectangle ()
  "Yank the last killed rectangle with upper left corner at point."
  (interactive "*")
  (insert-rectangle killed-rectangle))

;;;###autoload
(defun insert-rectangle (rectangle)
  "Insert text of RECTANGLE with upper left corner at point.
RECTANGLE's first line is inserted at point, its second
line is inserted at a point vertically under point, etc.
RECTANGLE should be a list of strings.
After this command, the mark is at the upper left corner
and point is at the lower right corner."
  (let ((lines rectangle)
	(insertcolumn (current-column))
	(first t))
    (push-mark)
    (while lines
      (or first
	  (progn
	   (forward-line 1)
	   (or (bolp) (insert ?\n))
	   (move-to-column insertcolumn t)))
      (setq first nil)
      (insert-for-yank (car lines))
      (setq lines (cdr lines)))))

;;;###autoload
(defun open-rectangle (start end &optional fill)
  "Blank out the region-rectangle, shifting text right.

The text previously in the region is not overwritten by the blanks,
but instead winds up to the right of the rectangle.

When called from a program the rectangle's corners are START and END.
With a prefix (or a FILL) argument, fill with blanks even if there is
no text on the right side of the rectangle."
  (interactive "*r\nP")
  (apply-on-rectangle 'open-rectangle-line start end fill)
  (goto-char start))

(defun open-rectangle-line (startcol endcol fill)
  (when (= (move-to-column startcol (if fill t 'coerce)) startcol)
    (unless (and (not fill)
		 (= (point) (point-at-eol)))
      (indent-to endcol))))

(defun delete-whitespace-rectangle-line (startcol _endcol fill)
  (when (= (move-to-column startcol (if fill t 'coerce)) startcol)
    (unless (= (point) (point-at-eol))
      (delete-region (point) (progn (skip-syntax-forward " ") (point))))))

;;;###autoload
(defalias 'close-rectangle 'delete-whitespace-rectangle) ;; Old name

;;;###autoload
(defun delete-whitespace-rectangle (start end &optional fill)
  "Delete all whitespace following a specified column in each line.
The left edge of the rectangle specifies the position in each line
at which whitespace deletion should begin.  On each line in the
rectangle, all continuous whitespace starting at that column is deleted.

When called from a program the rectangle's corners are START and END.
With a prefix (or a FILL) argument, also fill too short lines."
  (interactive "*r\nP")
  (apply-on-rectangle 'delete-whitespace-rectangle-line start end fill))

(defvar string-rectangle-history nil)
(defun string-rectangle-line (startcol endcol string delete)
  (move-to-column startcol t)
  (if delete
      (delete-rectangle-line startcol endcol nil))
  (insert string))

;;;###autoload
(defun string-rectangle (start end string)
  "Replace rectangle contents with STRING on each line.
The length of STRING need not be the same as the rectangle width.

Called from a program, takes three args; START, END and STRING."
  (interactive
   (progn (barf-if-buffer-read-only)
	  (list
	   (region-beginning)
	   (region-end)
	   (read-string (format "String rectangle (default %s): "
				(or (car string-rectangle-history) ""))
			nil 'string-rectangle-history
			(car string-rectangle-history)))))
  (goto-char
   (apply-on-rectangle 'string-rectangle-line start end string t)))

;;;###autoload
(defalias 'replace-rectangle 'string-rectangle)

;;;###autoload
(defun string-insert-rectangle (start end string)
  "Insert STRING on each line of region-rectangle, shifting text right.

When called from a program, the rectangle's corners are START and END.
The left edge of the rectangle specifies the column for insertion.
This command does not delete or overwrite any existing text."
  (interactive
   (progn (barf-if-buffer-read-only)
	  (list
	   (region-beginning)
	   (region-end)
	   (read-string (format "String insert rectangle (default %s): "
				(or (car string-rectangle-history) ""))
			nil 'string-rectangle-history
			(car string-rectangle-history)))))
  (apply-on-rectangle 'string-rectangle-line start end string nil))

;;;###autoload
(defun clear-rectangle (start end &optional fill)
  "Blank out the region-rectangle.
The text previously in the region is overwritten with blanks.

When called from a program the rectangle's corners are START and END.
With a prefix (or a FILL) argument, also fill with blanks the parts of the
rectangle which were empty."
  (interactive "*r\nP")
  (apply-on-rectangle 'clear-rectangle-line start end fill))

(defun clear-rectangle-line (startcol endcol fill)
  (let ((pt (point-at-eol)))
    (when (= (move-to-column startcol (if fill t 'coerce)) startcol)
      (if (and (not fill)
	       (<= (save-excursion (goto-char pt) (current-column)) endcol))
	  (delete-region (point) pt)
	;; else
	(setq pt (point))
	(move-to-column endcol t)
	(setq endcol (current-column))
	(delete-region pt (point))
	(indent-to endcol)))))

;; Line numbers for `rectangle-number-line-callback'.
(defvar rectangle-number-line-counter)

(defun rectangle-number-line-callback (start _end format-string)
  (move-to-column start t)
  (insert (format format-string rectangle-number-line-counter))
  (setq rectangle-number-line-counter
	(1+ rectangle-number-line-counter)))

(defun rectange--default-line-number-format (start end start-at)
  (concat "%"
	  (int-to-string (length (int-to-string (+ (count-lines start end)
						   start-at))))
	  "d "))

;;;###autoload
(defun rectangle-number-lines (start end start-at &optional format)
  "Insert numbers in front of the region-rectangle.

START-AT, if non-nil, should be a number from which to begin
counting.  FORMAT, if non-nil, should be a format string to pass
to `format' along with the line count.  When called interactively
with a prefix argument, prompt for START-AT and FORMAT."
  (interactive
   (if current-prefix-arg
       (let* ((start (region-beginning))
	      (end   (region-end))
	      (start-at (read-number "Number to count from: " 1)))
	 (list start end start-at
	       (read-string "Format string: "
			    (rectange--default-line-number-format
			     start end start-at))))
     (list (region-beginning) (region-end) 1 nil)))
  (unless format
    (setq format (rectange--default-line-number-format start end start-at)))
  (let ((rectangle-number-line-counter start-at))
    (apply-on-rectangle 'rectangle-number-line-callback
			start end format)))

;;; New rectangle integration with kill-ring.

;; FIXME: lots of known problems with the new rectangle support:
;; - no key binding for mark-rectangle.
;; - no access to the `string-rectangle' functionality.
;; - lots of commands handle the region without paying attention to its
;;   rectangular shape.

(add-hook 'deactivate-mark-hook
          (lambda () (rectangle-mark-mode -1)))

(add-function :around redisplay-highlight-region-function
              #'rectangle--highlight-for-redisplay)
(add-function :around redisplay-unhighlight-region-function
              #'rectangle--unhighlight-for-redisplay)
(add-function :around region-extract-function
              #'rectangle--extract-region)

(defvar rectangle-mark-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [?\C-o] 'open-rectangle)
    (define-key map [?\C-t] 'string-rectangle)
    ;; (define-key map [remap open-line] 'open-rectangle)
    ;; (define-key map [remap transpose-chars] 'string-rectangle)
    map)
  "Keymap used while marking a rectangular region.")

;;;###autoload
(define-minor-mode rectangle-mark-mode
  "Toggle the region as rectangular.
Activates the region if needed.  Only lasts until the region is deactivated."
  nil nil nil
  (when rectangle-mark-mode
    (unless (region-active-p) (push-mark-command t))))

(defun rectangle--extract-region (orig &optional delete)
  (if (not rectangle-mark-mode)
      (funcall orig delete)
    (let* ((strs (funcall (if delete
                              #'delete-extract-rectangle
                            #'extract-rectangle)
                          (region-beginning) (region-end)))
           (str (mapconcat #'identity strs "\n")))
      (when (eq last-command 'kill-region)
        ;; Try to prevent kill-region from appending this to some
        ;; earlier element.
        (setq last-command 'kill-region-dont-append))
      (when strs
        (put-text-property 0 (length str) 'yank-handler
                           `(rectangle--insert-for-yank ,strs t)
                           str)
        str))))

(defun rectangle--insert-for-yank (strs)
  (push (point) buffer-undo-list)
  (let ((undo-at-start buffer-undo-list))
    (insert-rectangle strs)
    (setq yank-undo-function
          (lambda (_start _end)
            (undo-start)
            (setcar undo-at-start nil)  ;Turn it into a boundary.
            (while (not (eq pending-undo-list (cdr undo-at-start)))
              (undo-more 1))))))

(defun rectangle--highlight-for-redisplay (orig start end window rol)
  (cond
   ((not rectangle-mark-mode)
    (funcall orig start end window rol))
   ((and (eq 'rectangle (car-safe rol))
         (eq (nth 1 rol) (buffer-chars-modified-tick))
         (eq start (nth 2 rol))
         (eq end (nth 3 rol)))
    rol)
   (t
    (save-excursion
      (let* ((nrol nil)
             (old (if (eq 'rectangle (car-safe rol))
                      (nthcdr 4 rol)
                    (funcall redisplay-unhighlight-region-function rol)
                    nil))
             (ptcol (progn (goto-char start) (current-column)))
             (markcol (progn (goto-char end) (current-column)))
             (leftcol  (min ptcol markcol))
             (rightcol (max ptcol markcol)))
        (goto-char start)
        (while (< (point) end)
          (let* ((mleft (move-to-column leftcol))
                 (left (point))
                 (mright (move-to-column rightcol))
                 (right (point))
                 (ol
                  (if (not old)
                      (let ((ol (make-overlay left right)))
                        (overlay-put ol 'window window)
                        (overlay-put ol 'face 'region)
                        ol)
                    (let ((ol (pop old)))
                      (move-overlay ol left right (current-buffer))
                      ol))))
            ;; `move-to-column' may stop before the column (if bumping into
            ;; EOL) or overshoot it a little, when column is in the middle
            ;; of a char.
            (cond
             ((< mleft leftcol)         ;`leftcol' is past EOL.
              (overlay-put ol 'before-string
                           (spaces-string (- leftcol mleft)))
              (setq mright (max mright leftcol)))
             ((and (> mleft leftcol)    ;`leftcol' is in the middle of a char.
                   (eq (char-before left) ?\t))
              (setq left (1- left))
              (move-overlay ol left right)
              (goto-char left)
              (overlay-put ol 'before-string
                           (spaces-string (- leftcol (current-column)))))
             ((overlay-get ol 'before-string)
              (overlay-put ol 'before-string nil)))
            (cond
             ((< mright rightcol)       ;`rightcol' is past EOL.
              (let ((str (make-string (- rightcol mright) ?\s)))
                (put-text-property 0 (length str) 'face 'region str)
                ;; If cursor happens to be here, draw it *before* rather than
                ;; after this highlighted pseudo-text.
                (put-text-property 0 1 'cursor t str)
                (overlay-put ol 'after-string str)))
             ((and (> mright rightcol)  ;`rightcol' is in the middle of a char.
                   (eq (char-before right) ?\t))
              (setq right (1- right))
              (move-overlay ol left right)
	      (if (= rightcol leftcol)
		  (overlay-put ol 'after-string nil)
		(goto-char right)
		(let ((str (make-string
			    (- rightcol (max leftcol (current-column))) ?\s)))
		  (put-text-property 0 (length str) 'face 'region str)
		  (when (= left right)
		    ;; If cursor happens to be here, draw it *before* rather
		    ;; than after this highlighted pseudo-text.
		    (put-text-property 0 1 'cursor 1 str))
		  (overlay-put ol 'after-string str))))
             ((overlay-get ol 'after-string)
              (overlay-put ol 'after-string nil)))
            (when (= leftcol rightcol)
              ;; Make zero-width rectangles visible!
              (overlay-put ol 'after-string
                           (concat (propertize " "
                                               'face '(region (:height 0.2)))
                                   (overlay-get ol 'after-string))))
            (push ol nrol))
          (forward-line 1))
        (mapc #'delete-overlay old)
        `(rectangle ,(buffer-chars-modified-tick) ,start ,end ,@nrol))))))

(defun rectangle--unhighlight-for-redisplay (orig rol)
  (if (not (eq 'rectangle (car-safe rol)))
      (funcall orig rol)
    (mapc #'delete-overlay (nthcdr 4 rol))
    (setcar (cdr rol) nil)))

(provide 'rect)

;;; rect.el ends here
