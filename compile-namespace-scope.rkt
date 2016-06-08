#lang racket/base
(require "set.rkt"
         "syntax.rkt"
         "scope.rkt"
         "phase.rkt"
         "namespace.rkt"
         "root-expand-context.rkt")
         
(provide swap-top-level-scopes
         encode-namespace-scopes)

;; In case a syntax object in compiled top-level code is from a
;; different namespace or deserialized, swap the current namespace's
;; scope for the original namespace's scope.
;;
;; To swap a namespace scopes, we partition the namespace scopes into
;; two groups: the scope that's added after every expansion (and
;; therefore appears on every binding form), and the other scopes that
;; indicate being original to the namespace. We swap those groups
;; separately.

;; Swapping function, used at run time:
(define (swap-top-level-scopes s original-scopes-s new-ns)
  (define-values (old-scs-post old-scs-other) (decode-namespace-scopes original-scopes-s))
  (define-values (new-scs-post new-scs-other) (extract-namespace-scopes new-ns))
  (syntax-swap-scopes (syntax-swap-scopes s old-scs-post new-scs-post)
                      old-scs-other new-scs-other))

(define (extract-namespace-scopes ns)
  (define root-ctx (namespace-root-expand-ctx ns))
  (define post-expansion-sc (root-expand-context-post-expansion-scope root-ctx))
  (values (set post-expansion-sc)
          (set-remove (list->set (root-expand-context-module-scopes root-ctx))
                      post-expansion-sc)))

;; Extract namespace scopes to a syntax object, used at compile time:
(define (encode-namespace-scopes ns)
  (define-values (post-expansion-scs other-scs) (extract-namespace-scopes ns))
  (define post-expansion-s (add-scopes (datum->syntax #f 'post)
                                       (set->list post-expansion-scs)))
  (define other-s (add-scopes (datum->syntax #f 'other)
                              (set->list other-scs)))
  (datum->syntax #f (vector post-expansion-s other-s)))

;; Decoding, used at run time:
(define (decode-namespace-scopes stx)
  (define vec (syntax-e stx))
  (values (syntax-scope-set (vector-ref vec 0) 0)
          (syntax-scope-set (vector-ref vec 1) 0)))