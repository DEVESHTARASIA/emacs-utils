;;; utils.el 
;;; Some of Vincent's utils.

(defvar lb "
")

(defun list->vector (lst)
  (assert (listp lst) t "list->vector: input not a list.")
  (coerce lst 'vector))

(defun vector->list (vec)
  (assert (vectorp vec) t "vector->list input not a vector.")
  (coerce vec 'list))


(defun last-line? ()
  (save-excursion
	(eq (line-number-at-pos)
		(progn (forward-line 1) (line-number-at-pos)))))

(defun with-point-at-lines-start (fun)
  (save-excursion 
	(goto-char (point-min))
	(loop until (last-line?) do
		  (beginning-of-line)
		  (funcall fun (line-number-at-pos))		 
		  (forward-line 1))))

(defun line-numbers-of-region (startp endp)
  (loop for i from (line-number-at-pos startp) to (line-number-at-pos endp) collect i))

(defun betweeni? (it bel ab)
  (and (>= it bel) (<= it ab)))

(defun current-line-in-region? (startp endp)
  (betweeni? (line-number-at-pos) (line-number-at-pos startp) (line-number-at-pos endp)))

(defun comment-region-inv (startp endp)
  (interactive "r")
  (with-point-at-lines-start
   (lambda (ln)
	 (if (not (current-line-in-region? startp endp))
		 (insert comment-start)))))

(defun uncomment-region-inv (startp endp)
  (interactive "r")
  (with-point-at-lines-start
   (lambda (ln)
	 (if (not (current-line-in-region? startp endp))
		 (kill-forward-chars 1)))))

(defun jlet-bindings->let-bindings (bindings)
  (if (not (mod (length bindings) 2)) (error "jlet binding form needs an even number of items.")
	(let ((let-bindings '()))
	  (loop for i from 0 below (- (length bindings) 1) by 2 do
			(push (list (elt bindings i) (elt bindings (+ i 1))) let-bindings))
	  (reverse let-bindings))))

(defmacro jlet (bindings &rest body)
  `(let* ,(jlet-bindings->let-bindings bindings) ,@body))

(defmacro llet (&rest args)
  `(lexical-let ,@args))

(defmacro jllet (bindings &rest body)
  `(lexical-let* ,(jlet-bindings->let-bindings bindings) ,@body))

(defun* in (item lst &optional (pred #'eq))
  (cond ((hash? lst)
		 (in item (keyshash lst) pred))
		(t
		 (let* ((found nil))
		   (loop while (and lst (not found)) do
				 (if (funcall pred (car lst) item)
					 (progn (setq found t))
				   (progn
					 (setq lst (cdr lst)))))
		   found))))

(defun* unique (lst &optional (pred #'eq))
  (foldl
   (lambda (it ac)
	 (if (in it ac pred) ac
	   (cons it ac)))
   '()
   lst))

(defun insertf (&rest args)
  (insert (apply #'format  args)))

(defun make-keyword (name)
  (intern (format ":%s" name)))

(defun bang (sym)
  (intern (format "%s!" sym)))
(defun s-cat (sym1 sym2)
  (intern (format "%s-%s" sym1 sym2)))
(defun ques (sym)
  (intern (format "%s?" sym)))

(defun suffix (lst x)
  (append lst (list x)))

(defmacro defstruquine (name &rest slots)
  (let* ((n-fields (length slots))
		 (i 1)
		 (out `(progn
				 (defun ,(bang name) ,slots
				   (list ',(bang name) ,@slots)) 
				 (defun ,(ques name) (item)
				   (eq (car item) ',(bang name))))))
	(loop for slot in slots do
		  (setf out 
				(append out
						(list `(defun ,(s-cat name slot) (item) (elt item ,i)))))
		  (setf i (+ i 1)))
	(append out (list nil))))

(defun between-inc (low high val)
  (and (>= val low)
	   (<= val high)))

(defun between (low high val)
  (and (> val low)
	   (< val high)))

(defun foldl (fn init list)
  (let ((output init))
	(loop for item in list do
		  (setq output (funcall fn item output)))
	output))

(defun all-but-last (lst)
  (reverse (cdr (reverse lst))))

(defun foldla (fn init-and-list)
  (let ((lst (last init-and-list))
		(inits (all-but-last init-and-list)))
	(loop for item in lst do
		  (setq inits (apply fn (cons item inits))))
	inits))

(defun sum (&rest args)
  (foldl #'+ 0 args))

(defun mean (&rest args)
  (/ (apply #'sum args) (length args)))

(defun list? (&rest args)
  (apply #'listp args))

(defun flatten (lst)
  (reverse
   (foldl
	(lambda (item output)
	  (cond ((list? item)
			 (foldl #'cons output (flatten item)))
			(t
			 (cons item output)))) '() lst)))

(defmacro after-this-line (&rest body)
  `(progn (insert "\n\n")
		  ,@body))

(defmacro enclambda (what arglist &rest body)
  (let ((lexletarg
		 (foldl (lambda (cu ou) (cons (list cu cu) ou))
				'()
				what)))
	`(lexical-let ,lexletarg
	   (lambda ,arglist
		 ,@body))))

(defun null? (lst) (eq '() lst))

(defun any (list)
  (let ((b nil))
	(loop for item in list do
		  (setq b (or b item)))
	b))

(defun all (list)
  (let ((b t))
	(loop for item in list do
		  (setq b (and b item)))
	b))

(defun none (list)
  (not (any list)))

(defun fix (f a0 &rest args)
  (let ((max-it (if (null? args) 100 (car args))))
	(let* ((prev (funcall f a0))
		   (current (funcall f prev)))
	  (loop while (not (equal prev current)) do
			(setf prev current)
			(setf current (funcall f prev)))
	  current)))


(defun bunch-list (lst)
  (reverse (cadr (foldl
				  (lambda (it ac) 
					(let ((ls (car ac))
						  (ol (cadr ac)))
					  (cond (ls (list nil (cons (list ls it) ol)))
							(t 
							 (list it ol)))))
				  (list nil nil)
				  lst))))

(defun tbl! (&rest args)
  (cond 
   ((hash? (car args)) (foldl (lambda (pr tbl)
								(setf (cl-gethash (car pr) tbl)  (cadr pr))
								tbl)
							  (car args)
							  (bunch-list (cdr args))))
   (t
	(foldl (lambda (pr tbl)
			 (setf (cl-gethash (car pr) tbl)  (cadr pr))
			 tbl)
		   (cl-make-hash-table :test 'equal)
		   (bunch-list args)))))

(defun tbl (tbl &rest args)
  (let ((res
		 (loop for arg in args collect (cl-gethash arg tbl))))
	(if (= 1 (length res))
		(car res)
	  res)))

(defun* tbl-or (tbl key &optional (otherwise nil))
  (cl-gethash key tbl otherwise))

(defun string-contains? (str re)
  (let ((new (replace-regexp-in-string re "" str)))
	(not (string= new str))))

(defun keyshash (tbl)
  (let ((keys '()))
	(maphash (lambda (k v) (push k keys)) tbl)
	(reverse keys)))

(defun valshash (tbl)
  (mapcar (lambda (k) (gethash k tbl)) (keyshash tbl)))

(defun hash? (o)
  (hash-table-p o))

(defun lmaphash (lam tbl)
  (let* ((keys (keyshash tbl))
		 (vals
		  (loop for key in keys collect (gethash key tbl))))
	(mapcar* lam keys vals)))

(defun lmaphash-vals (lam tbl)
  (mapcar lam (valshash tbl)))

(defun* join (lst &optional (del " "))
  (foldl (lambda (it ac)
		   (concat ac it))
		 "" 
		 (cons (car lst) (mapcar (lambda (x) (concat del x)) (cdr lst)))))

(defun filter (f lst)
  (reverse (foldl (lambda (it ac)
					(if (funcall f it) 
						(cons it ac)
					  ac))
				  '() lst)))

(defun chomp (str)
  "Perl-like chomp function to return a version of STR with no whitespace."
  (let ((s (if (symbolp str)(symbol-name str) str)))
    (save-excursion
      (while (and
              (not (null (string-match "^\\( \\|\f\\|\t\\|\n\\)" s)))
              (> (length s) (string-match "^\\( \\|\f\\|\t\\|\n\\)" s)))
        (setq s (replace-match "" t nil s)))
      (while (and
              (not (null (string-match "\\( \\|\f\\|\t\\|\n\\)$" s)))
              (> (length s) (string-match "\\( \\|\f\\|\t\\|\n\\)$" s)))
        (setq s (replace-match "" t nil s))))
    s))

(defun build-on (machines body)
  `(if (any (mapcar (lambda (x)
					  (string= system-name (format "%s" x)))
					,machines))
	   (progn
		 ,@body)))

(defmacro on (machines &rest body)
  (build-on machines body))

(defmacro defvar-buf-loc (nm &optional vl do)
  `(progn (defvar ,nm ,vl ,do)
		  (make-variable-buffer-local ',nm)))

(defmacro defcustom-buf-loc (nm &optional vl do)
  `(progn (defcustom ,nm ,vl ,do)
		  (make-variable-buffer-local ',nm)))

(defun comp (&rest fs)
  (lexical-let
	  ((rfs (reverse fs)))
	(lambda (&rest args)
	  (foldl
	   (lambda (it ac)
		 (list (apply it ac)))
	   args
	   rfs))))

(defmacro* let-seq (symbols lst &body body)
  (let ((list-name (gensym "list-")))
	`(let ((,list-name ,lst))
	   (let ,(loop for i from 0 below (length symbols)
				   and s in symbols collect
				   (list s `(elt ,list-name ,i)))
		 ,@body))))

(defmacro* let-tbl (symbol-key-pairs tbl &body body)
  (let ((tbl-name (gensym "table-")))
	`(let ((,tbl-name ,tbl))
	   (let ,(loop for i from 0 below (length symbol-key-pairs)
				   and sk in symbol-key-pairs collect
				   (list (car sk) `(tbl ,tbl-name ,(cadr sk))))
		 ,@body))))

(defmacro* llet-seq (symbols lst &body body)
  (let ((list-name (gensym "list-")))
	`(let ((,list-name ,lst))
	   (lexical-let ,(loop for i from 0 below (length symbols)
						   and s in symbols collect
						   (list s `(elt ,list-name ,i)))
		 ,@body))))

(defmacro* llet-tbl (symbol-key-pairs tbl &body body)
  (let ((tbl-name (gensym "table-")))
	`(let ((,tbl-name ,tbl))
	   (lexical-let ,(loop for i from 0 below (length symbol-key-pairs)
						   and sk in symbol-key-pairs collect
						   (list (car sk) `(tbl ,tbl-name ,(cadr sk))))
		 ,@body))))


(defun elts (sq inds)
  (loop for i from 0 below (length inds) 
		collect (elt sq (elt inds i))))

(functionp (lambda (x) x))

(defun split-list-left (lst pred)
  (if (not (functionp pred))
	  (split-list-left lst (lexical-let ((p pred)) (lambda (x) (eq p x))))
	(loop with found = nil
		  for i from 0 below (length lst)
		  when (not found)
		  collect (elt lst i) into before
		  when found
		  collect (elt lst i) into after 
		  when (funcall pred (elt lst i))
		  do (setf found t)
		  finally (return (list before after)))))

(defun split-list-right (lst pred)
  (if (not (functionp pred))
	  (split-list-right lst (lexical-let ((p pred)) (lambda (x) (eq p x))))
	(loop with found = nil
		  for i from 0 below (length lst)
		  when (funcall pred (elt lst i))
		  do (setf found t)
		  when (not found)
		  collect (elt lst i) into before
		  when found
		  collect (elt lst i) into after 
		  finally (return (list before after)))))

(defun split-list-drop (lst pred)
  (if (not (functionp pred))
	  (split-list-drop lst (lexical-let ((p pred)) (lambda (x) (eq p x))))
	(loop with found = nil
		  for i from 0 below (length lst)
		  when (funcall pred (elt lst i))
		  do (setf found t)
		  when (not found)
		  collect (elt lst i) into before
		  when (and found
					(not (funcall pred (elt lst i))))
		  collect (elt lst i) into after 
		  finally (return (list before after)))))


(defun v-last (v)
  (elt v (- (length v) 1)))
(defun v-next-to-last (v)
  (elt v (- (length v) 2)))
(defun v-rest (v)
  (apply #'vector 
		 (loop for i from 1 below (length v)
			   collect (elt v i))))

(defun* elt-or (seq n &optional (otherwise nil))
  (if (< n (length seq)) (elt seq n) otherwise))

(defun* elts-or (seq ns &optional (otherwises nil))
  (loop for it in ns collect (elt-or seq it (elt-or otherwises it nil))))

;; (elts-or '(10 9 8 7 6) '(0 1 2 3 15 16 0) '(20 20 20 20 20 20 20 20 20 20 20 20 20 20 220 20 20 20 20 20 20))
;; (elt-or [a b c] 3 'd)
;; (elt [a b c] 1)

;; (split-list-left '(1 2 3 4 5) 4)
;; (split-list-right '(1 2 3 4 5) 3)
;; (split-list-drop '(1 2 3 4 5) 3)

(defmacro comment (&rest rest) 'nil)

(defun seq-type (sq)
  (cond
   ((listp sq) 'list)
   ((vectorp sq) 'vector)))

(defun nthcdr-preserve-type (n sq)
  (coerce 
   (nthcdr n (coerce sq 'list))
   (seq-type sq)))

										; (nthcdr-preserve-type 3 [0 1 2 3 4 5 6 7])

(defun transplant-tail (to from)
  (coerce 
   (loop for i from 0 below (max (length from) (length to)) collect
		 (elt-or to i (elt from i)))
   (seq-type to)))

										; (transplant-tail '(1 2 3 4) '(10 9))

(defun ff/line (filename line-number)
  (let ((buf (find-file filename)))
	(goto-line line-number)))

(defun ff/char (filename char-number)
  (let ((buf (find-file filename)))
	(goto-char char-number)))

(defun put-string-on-kill-ring (string)
  (setq kill-ring (cons string kill-ring))
  (if (> (length kill-ring) kill-ring-max)
      (setcdr (nthcdr (1- kill-ring-max) kill-ring) nil))
  (setq kill-ring-yank-pointer kill-ring))

(defun ff/line->clipboard ()
  (interactive)
  (let ((ln (line-number-at-pos))
		(filename
		 (buffer-file-name)))
    (put-string-on-kill-ring 
	 (format "(ff/line \"%s\" %d)" filename ln))))

(defun ff/char->clipboard ()
  (interactive)
  (let ((pt (point))
		(filename
		 (buffer-file-name)))
    (put-string-on-kill-ring 
	 (format "(ff/char \"%s\" %d)" filename pt))))

(defun ff/this-text->clipboard (s e)
  (interactive "r")
  (put-string-on-kill-ring 
   (format 
	"(ff/this-text %s \"%s\")" 
	(buffer-file-name) 
	(buffer-substring-no-properties s e))))

(defun ff/this-text (filename txt)
  (with-current-buffer (find-file filename)
	(word-search-forward txt)))

(defun pwd->kill-ring ()
  (interactive)
  (put-string-on-kill-ring (pwd)))

(let ((currently-defining-defn 'range))
  (fset 'range
		(function
		 (lambda (&rest G1590)
		   (let ((G1591 (length G1590)))
			 (cond ((arity-match G1591 '(3 exactly))
					(lexical-let* ((lambda-seq-as-sym1608 G1590)
								   (start (elt lambda-seq-as-sym1608 0))
								   (step (elt lambda-seq-as-sym1608 1))
								   (upto (elt lambda-seq-as-sym1608 2)))
					  (loop for i from start below upto by step collect i)))
				   ((arity-match G1591 '(2 exactly))
					(lexical-let* ((lambda-seq-as-sym1621 G1590)
								   (start (elt lambda-seq-as-sym1621 0))
								   (upto (elt lambda-seq-as-sym1621 1)))
					  e
					  (range start 1 upto)))
				   ((arity-match G1591 '(1 exactly))
					(lexical-let* ((lambda-seq-as-sym1630 G1590)
								   (upto (elt lambda-seq-as-sym1630 0)))
					  (range 0 1 upto)))
				   (t (error "Unable to find an arity match for %d args in fn %s."
							 G1591
							 'lambda))))))))

(defmacro* $ (first f &rest rest)
  `(,f ,first ,@rest))

(defun shell-to (dir)
  (let* ((buf (shell))
		 (pro (get-buffer-process buf)))
	(send-string pro (concat "\ncd " dir "\n"))
	(with-current-buffer buf (cd dir))
	(send-string pro "ls -t | head -n 10\n")))

(provide 'utils)
