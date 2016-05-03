#lang racket/base
(require racket/set
         racket/unit
         "syntax.rkt"
         "scope.rkt"
         "binding.rkt"
         "namespace.rkt")

(provide core-stx
         
         add-core-form!
         add-core-primitive!
         
         declare-core-module!
         
         core-form-sym)

;; Accumulate all core bindings in `core-scope`, so we can
;; easily generate a reference to a core form using `core-stx`:
(define core-scope (new-multi-scope))
(define core-stx (add-scope empty-syntax core-scope))

;; Core forms are added by `expand-expr@`, etc., in "expand.rkt"

;; Accumulate added core forms and primitives:
(define core-forms #hasheq())
(define core-primitives #hasheq())

(define (add-core-form! sym proc)
  (add-core-binding! sym)
  (set! core-forms (hash-set core-forms
                             sym
                             proc)))

(define (add-core-primitive! sym val)
  (add-core-binding! sym)
  (set! core-primitives (hash-set core-primitives
                                  sym
                                  val)))

(define (add-core-binding! sym)
  (add-binding! (datum->syntax core-stx sym)
                (module-binding '#%core 0 sym
                                '#%core 0 sym
                                0)
                0))

;; Used only after filling in all core forms and primitives:
(define (declare-core-module! ns)
  (declare-module!
   ns
   '#%core
   (make-module #hasheq()
                (hasheqv 0 (for/hasheq ([sym (in-sequences
                                              (in-hash-keys core-primitives)
                                              (in-hash-keys core-forms))])
                             (values sym (module-binding '#%core 0 sym
                                                         '#%core 0 sym
                                                         0))))
                0 1
                (lambda (ns phase phase-level)
                  (case phase-level
                    [(0)
                     (for ([(sym val) (in-hash core-primitives)])
                       (namespace-set-variable! ns 0 sym val))]
                    [(1)
                     (for ([(sym proc) (in-hash core-forms)])
                       (namespace-set-transformer! ns 0 sym (core-form proc)))])))))

;; Helper for recognizing and dispatching on core forms:
(define (core-form-sym s phase)
  (and (pair? (syntax-e s))
       (let ()
         (define id (car (syntax-e s)))
         (and (identifier? id)
              (let ()
                (define b (resolve id phase))
                (and (module-binding? b)
                     (eq? '#%core (module-binding-module b))
                     (module-binding-sym b)))))))
