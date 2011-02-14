(require 'defn)
(require 'utils)
(require 'functional)
(provide 'multi-methods)

(defun mk-dispatch-table-name (method)
  "generates the symbol for a dispatch table for METHOD"
  (internf "--%s-dispatch-table" method))

(defun mk-dispatch-function-name (method)
  "generates the symbol for the dispatch function for METHOD"
  (internf "--%s-dispatcher" method))

(defun make-keyword-accessor (kw)
  "Creates an accessor for tables looking for KW"
  (lexical-let ((kw kw))
	(lambda (table &rest args) (table-like-get table kw))))

(defmacro defmulti (name dispatch)
  "Define a multi-method NAME with dispatch function DISPATCH.  DEFUNMULTI defines specific instances of the method."
  (let ((table-name (mk-dispatch-table-name name))
		(dispatch-name (mk-dispatch-function-name name))
		(args-name (gensymf "multi-%s-args" name))
		(internal-name (gensymf "multi-%s-holder" name))
		(dispatch (if (not (functionp dispatch)) (make-keyword-accessor dispatch) dispatch)))
	`(progn 
	   (defvar ,table-name (alist>>) ,(format "dispatch-table for %s" name))
	   (defvar ,dispatch-name ,dispatch ,(format "dispatch-function for %s" name))
	   (defun ,name (&rest ,args-name)
		 (let ((,internal-name (isa-dispatch (apply ,dispatch-name ,args-name) ,table-name (make-resolve-by-table (alist *preferred-dispatch-table* ',name) ',name))))
		   (if ,internal-name (apply ,internal-name ,args-name)
			 (error (format ,(format "No known method for args %%S for multimethod %s." name) ,args-name))))))))

(defmacro* defunmethod (name value arglist &body body)
  "Define a method using DEFUN syntax for the dispatch value VALUE."
  (let ((g (gensym))
		(table-name (mk-dispatch-table-name name)))
	`(let ((,g (lambda ,arglist ,@body)))
	   (setq ,table-name 
			 (alist>> ,table-name ,value ,g))
	   ',name)))

(defvar *preferred-dispatch-table* nil "Table of method dispatch resolution rules.")
(defun prefer-method-fun (name pref-val not-pref-val)
  "Indicate that the NAMEd multimethod should prefer PREF-VAL over NOT-PREF-VAL when dispatching ambiguous inputs."
  (let ((subtbl (alist *preferred-dispatch-table* name)))
	(alist! subtbl (vector pref-val not-pref-val) pref-val)
	(alist! subtbl (vector not-pref-val pref-val) prev-val)
	(setf (alist *preferred-dispatch-table* name) subtbl)))

(defmacro prefer-method (name pref-val not-pref-val)
  "Declare that a particular dispatch value PREF-VAL is preferred over NOT-PREF-VAL when dispatching the NAMEd method."
  `(prefer-method-fun ',name ,pref-val ,not-pref-val))




(defvar *multi-method-heirarchy* (alist>> :down nil
										  :up nil
										  :resolutions nil) "The default multimethod hierarchy used for isa? dispatch.")

(defun clear-mm-heirarchy ()
  "Clear the hierarchy in the dynamic scope. "
  (setq *multi-method-heirarchy* (alist>> :down nil
										  :up nil
										  :resolutions nil))
  *multi-method-heirarchy*)

(dont-do 
 (setq *multi-method-heirarchy* (alist>> :down nil
										 :up nil))
 (add-parent-relation :vector :thing)
 (add-child-relation :thing :vector))

(defun add-parent-relation (child parent)
  "Add a PARENT CHILD relationship to the hierarchy in the dynamic scope."
  (let ((parents (alist *multi-method-heirarchy* :up)))
	(setf (alist *multi-method-heirarchy* :up) (alist-add-to-set parents child parent)))
  *multi-method-heirarchy*)

(defun add-child-relation (parent child)
  "Add a CHILD PARENT relationship to the hierarchy in the dynamic scope."
  (let ((children (alist *multi-method-heirarchy* :down)))
	(setf (alist *multi-method-heirarchy* :down) (alist-add-to-set children parent child)))
  *multi-method-heirarchy*)

(defun mm-parents (child)
  "Get the PARENTS of CHILD from the hierachy in the dynamic scope."
  (let ((parents (alist *multi-method-heirarchy* :up)))
	(alist parents child)))

(defun mm-children (parent)
  "Get the CHILDREN of PARENT from the hierachy in the dynamic scope."
  (let ((children (alist *multi-method-heirarchy* :down)))
	(alist children parent)))

(defun mm-ancestors (child)
  "Get all the ancestors of CHILD."
  (let* ((parents (mm-parents child))
		 (ancestors parents)
		 (done
		  (if parents nil t)))
	(loop while (not done) do
		  (let ((above (unique (map&filter #'identity #'mm-parents parents) #'equal)))
			(if above 
				(progn 
				  (setq parents above)
				  (setq ancestors (apply #'append (cons ancestors above))))
			  (setq done t))))
	ancestors))

(defun mm-descendants (child)
  "Get all the descendants of CHILD."
  (let* ((children (mm-children child))
		 (descendants children)
		 (done
		  (if children nil t)))
	(loop while (not done) do
		  (let ((below (unique (map&filter #'identity #'mm-children children) #'equal)))
			(if below 
				(progn 
				  (setq children below)
				  (setq descendants (apply #'append (cons descendants below))))
			  (setq done t))))
	descendants))

										; declare some testing hierarchy
(derive :thing :parseable)
(derive :thing :number)
(derive :thing :collection)
(derive :collection :list)
(derive :collection :vector)
(derive :parseable :string)
(derive :parseable :buffer)

(defun isa_ (o1 o2)
  "Underlying implementation of isa on regular objects."
  (if (equal o1 o2) 0
	(let* ((parents (mm-parents o1))
		   (done (if parents nil t))
		   (rank (if parents 1 nil)))
	  (loop while (not done) do
			(if (any (mapcar (cr #'equal o2) parents))
				(setq done t)
			  (progn 
				(setq rank (+ rank 1))
				(setq parents 
					  (apply #'append (mapcar #'mm-parents parents)))
				(unless parents 
				  (setq done t)
				  (setq rank nil)))))
	  rank)))

(defmacro lazy-and2 (e1 e2)
  "A lazy and macro."
  (let ((e1- (gensym "lazy-and-e1-")))
	`(let ((,e1- ,e1))
	   (if (not ,e1-) nil (and ,e1- ,e2)))))

(defun count-equilength-vectors (list-of)
  "Return the number of objects in list-of which are equilength vectors."
  (reduce #'+ 
		  (let ((n nil))
			(mapcar 
			 (lambda (v?)
			   (if (vectorp v?)
				   (progn 
					 (if (not n) 
						 (progn 
						   (setq n (length v?))
						   1)
					   (if (= n (length v?)) 1 0)))
				 0))
			 list-of))))



(defun isa? (o1 o2)
  "ISA? test for equality using the default hierarchy.  Child ISA? Parent but not vice versa.  Isa? returns a number representing the distance to the nearest ancestor that matches.  For vectors of objects, these distances are summed.  If nil, o1 is not an o2."
  (case (count-equilength-vectors (list o1 o2))
	((0) (isa_ o1 o2))
	((1) nil)
	((2) (reduce (lambda (a b)
				   (cond 
					((and (numberp a)
						  (numberp b))
					 (+ a b))
					(t nil)))
				 (map 'vector #'isa_ o1 o2)))))

(defun resolve-by-first (o r p1 p2)
  "Default, dumb conflict resolver."
  (list r p1))

(defun make-resolve-by-table (resolution-table method-name)
  "Creates a conflict resolution function which checks to see if a method has a specific conflict resolution procedure defined."
  (lexical-let ((restbl resolution-table)
				(method-name method-name))
	(lambda (object rank p1 p2)
	  (print object) 
	  (print rank)
	  (print p1)
	  (print p2)
	  (let-if resolution (alist restbl (vector (car p1) (car p2)))
			  (list rank (alist (list p1 p2) resolution))
			  (error "Method dispatch ambiguity for %s unresolved (%S vs %S)." method-name (car p1) (car p2))))))

(defun isa-dispatch (object alist resolver)
  "Dispatch from an alist table based on ISA? matches.  More specific matches are preferred over less, and ambiguous matches will be resolved by the function resolver."
  (cadr (cadr (foldl 
			   (lambda (alist-pair best-so-far)
				 (let ((rank (isa? object (car alist-pair))))
				   (cond
					((not rank)  best-so-far)
					((not best-so-far) (list rank alist-pair))
					((< rank (car best-so-far))
					 (list rank alist-pair))
					((> rank (car best-so-far)) best-so-far)
					((= rank (car best-so-far))
					 (if rank
						 (funcall resolver object rank alist-pair (cadr best-so-far)) nil)))))
			   nil
			   alist))))

(dont-do
										;example
 (defmulti report :student-name)
 (defunmethod report :ricky-gervais (student) "I got an A+")
 (defunmethod report :karl-pilkington (student) "Maybe I forgot to sign up for exams.")
 (report (alist>> :student-name :ricky-gervais)) ;-> "I got an A+"
 (report (alist>> :student-name :karl-pilkington)) ;-> "Maybe I forgot to sign up for exams.")
 (report (alist>> :steven-merchant)) ;-> error, no method
)
