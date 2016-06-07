#lang racket/base
(require "set.rkt")

;; A reference record keeps tarck of which bindings in a frame are
;; being referenced and which have been already bound so that a
;; reference doesn't count as a forward reference. This information
;; is needed for expanding internal definitions to break them into
;; suitable `let` and `letrec` sets.

(provide make-reference-record
         reference-record?
         reference-record-used!
         reference-record-bound!
         reference-record-forward-references?)

(struct reference-record ([already-bound #:mutable]
                          [reference-before-bound #:mutable])
        #:transparent)

(define (make-reference-record)
  (reference-record (seteq) (seteq)))

(define (reference-record-used! rr key)
  (unless (set-member? (reference-record-already-bound rr) key)
    (set-reference-record-reference-before-bound!
     rr
     (set-add (reference-record-reference-before-bound rr) key))))

(define (reference-record-bound! rr keys)
  (set-reference-record-already-bound!
   rr
   (for/fold ([ab (reference-record-already-bound rr)]) ([key (in-list keys)])
     (set-add ab key )))
  (set-reference-record-reference-before-bound!
   rr
   (for/fold ([rbb (reference-record-reference-before-bound rr)]) ([key (in-list keys)])
     (set-remove rbb key))))

(define (reference-record-forward-references? rr)
  (positive? (set-count (reference-record-reference-before-bound rr))))