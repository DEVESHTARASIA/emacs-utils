;;; Monadic Parser Combinators
;;; A Ground up Introduction

;; The best way, I think, to understand how these things works is to
;; consider the question of what a monadic parser combinator is in
;; the following order:

;;     1) What is our representation of a parse?
;;     2) How do we combine them?
;;     3) How does this combination strategy form a monad?

;; Depending on your temperament, you might not even care about 3,
;; which is fine.  The parser monad is useful without worrying too
;; hard about how monads work in general, but we will try to make
;; that clear in the course of the presentation.

(require 'el-pres)
(rebuild-control-panels)
   
;;;Controls Home    . >>>
