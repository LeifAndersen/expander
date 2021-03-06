#lang racket/base
(require "syntax.rkt"
         "binding.rkt")

(provide free-id-set
         empty-free-id-set
         free-id-set-member?)

;; A free-id-set is a hash: sym -> list of id

(define (free-id-set phase ids)
  (for/fold ([ht (hasheq)]) ([id (in-list ids)])
    (hash-update ht
                 (identifier-binding-symbol id phase)
                 (lambda (l) (cons id l))
                 null)))

(define empty-free-id-set (free-id-set 0 null))

(define (free-id-set-member? fs phase given-id)
  (for/or ([id (in-list (hash-ref fs
                                  (identifier-binding-symbol given-id phase)
                                  null))])
    (free-identifier=? id given-id phase phase)))
