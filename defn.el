(require 'cl)
(require 'utils)

(defun v-last (v)
  (elt v (- (length v) 1)))
(defun v-next-to-last (v)
  (elt v (- (length v) 2)))

(defun binder->type (f)
  (cond ((symbolp f) :symbol)
		((and (vectorp f)
			  (not (eq ':: (elt f 0))))
		 :seq)
		((and (vectorp f)
			  (eq (elt f 0) '::))
		 :tbl)
		(t (error "Unrecognized form type"))))

(defun forms->binders (fs)
  (loop for i from 0 below (length fs) 
		when (evenp i)
		collect (elt fs i)))
(defun forms->expressions (fs)
  (loop for i from 0 below (length fs) 
		when (oddp i)
		collect (elt fs i)))

(defun has-as? (f)
  (cond
   ((symbolp f) nil)
   ((< (length f) 2) nil)
   ((and 
	 (symbolp (v-last f))
	 (eq :as (v-next-to-last f))))))

(defun get-as (f)
  (v-last f))

(defun get-or-produce-as-name (f)
  (if (has-as? f) (get-as f) (gensym)))

(defun get-seq-individuals (binder)
  (loop for item across binder while (not (or (eq '& item) (eq :as item)))
		collect item))

(defun get-seq-rest (binder)
  (let ((res (member '& (coerce binder 'list))))
	(if res (cadr res) nil)))

(defun handle-seq-binder (binder expr previous-lets)
  (let* ((as-name (get-or-produce-as-name binder))
		 (individuals (get-seq-individuals binder))
		 (rest-form (get-seq-rest binder))
		 (previous-lets (append previous-lets (list 
											   (vector as-name expr)))))
	(if rest-form 
		(setf previous-lets
			  (append previous-lets 
					  (handle-binding rest-form 
							  `(coerce (nthcdr ,(length individuals)
											   (coerce ,as-name 'list))
									   (if (listp ,as-name) 'list 'vector))))))
	(append 
	 previous-lets
	 (loop for i from 0 to (length individuals)
		   and ind in individuals 
		   append
		   (handle-binding ind `(elt ,as-name ,i))))))


; (handle-seq-binder [x y [a b :as ri] :as r] '(1 2 3) '())

(defun strip-as (binder)
  (if (has-as? binder)
	  (coerce (loop for i from 0 below (- (length binder) 2) collect (elt binder i)) 'vector)
	binder))

(defun vrest (v)
  (coerce (loop for i from 1 below (length v) collect (elt v i)) 'vector))

(defun tbl-bind-kws (binder)
  (let ((relevant (vrest (strip-as binder))))
	(loop for i from 1 below (length relevant) by 2
		  collect (elt relevant i))))

(defun tbl-bind-syms (binder)
  (let ((relevant (vrest (strip-as binder))))
	(loop for i from 0 below (length relevant) by 2
		  collect (elt relevant i))))

;(tbl-bind-kws [:: x :x y :y :as z])

(defun handle-tbl-binding (binder expr previous-lets)
  (let* ((as-name (get-or-produce-as-name binder))
		(kws (tbl-bind-kws binder))
		(syms (tbl-bind-syms binder))
		(previous-lets (append previous-lets (handle-binding as-name expr))))
	(append 
	 previous-lets
	 (loop for kw in kws
		   and sym in syms
		   append
		   (handle-binding sym `(tbl ,as-name ,kw))))))

; (handle-tbl-binding [:: [a b] :x y :y :as table] '(tbl 'x 10 'y 11) '())

(defun* handle-binding (binder expr &optional
								(previous-lets '()))
  (case (binder->type binder)
	(:symbol (append previous-lets (list (vector binder expr))))
	(:seq (handle-seq-binder binder expr previous-lets))
	(:tbl (handle-tbl-binding binder expr previous-lets))))

; (handle-binding [a [:: [a b :as lst] :s :as table] & rest] 10)

(defun package-dlet-binders (pairs)
  (let ((n (length pairs))
		(binders '())
		(exprs '()))
	(loop for i from 0 below n by 2 
		  and j from 1 below n by 2 do
		  (push (elt pairs i) binders)
		  (push (elt pairs j) exprs)
		  finally
		  return
		  (list (coerce (reverse binders) 'vector)
				(cons 'list (reverse exprs))))))
(defun pairs->dlet-binding-forms (pairs)
  (mapcar (lambda (x) (coerce x 'list))
		  (apply #'handle-binding (package-dlet-binders pairs))))

; (package-dlet-binders [x 10 y 11 [a b] '(1 2)])
; (cl-prettyprint (pairs->dlet-binding-forms [x 10 y 11 [a b] '(1 2)]))


; (apply #'append (mapcar #'handle-binding (package-dlet-binders [x 10 y 11])))

(defmacro* dlet (pairs &body body)
  `(lexical-let* ,(pairs->dlet-binding-forms pairs) ,@body))

; (dlet [[a b] (list 10 10) y 11] (+ a b y))

(defun generate-defn-exprs (arg-nam n)
  (loop for i from 0 below n collect
		`(elt ,arg-nam ,i)))

(defmacro* defn (name binders &body body)
  (let* ((n-args (length binders))
		 (args-sym (gensym))
		 (exprs (generate-defn-exprs args-sym n-args)))
	`(defun ,name (&rest ,args-sym)
	   (lexical-let* ,(mapcar (lambda (x) (coerce x 'list)) (handle-binding binders (cons 'list exprs)))
		 ,@body))))

; (defn test-f [a b [:: c :x d :y]] (list a b c d))
; (test-f 1 2 (tbl! :x 3 :y 4))
	



