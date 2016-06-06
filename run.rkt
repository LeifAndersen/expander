#lang racket/base
(require racket/cmdline
         "set.rkt"
         "main.rkt"
         "namespace.rkt"
         "binding.rkt"
         "read-syntax.rkt"
         "module-path.rkt"
         (only-in syntax/modread
                  with-module-reading-parameterization)
         (only-in racket/base
                  [dynamic-require base:dynamic-require])
         "kernel.rkt"
         "run-cache.rkt"
         "runtime-primitives.rkt"
         "linklet.rkt"
         "status.rkt"
         "extract.rkt")

(define extract? #f)
(define cache-dir #f)
(define cache-read-only? #f)
(define cache-save-only #f)
(define cache-skip-first? #f)
(define time-expand? #f)
(define boot-module (path->complete-path "main.rkt"))
(command-line
 #:once-each
 [("-x" "--extract") "Extract bootstrap linklets"
  (set! extract? #t)]
 [("-c" "--cache") dir "Save and load from <dir>"
  (set! cache-dir (path->complete-path dir))]
 [("-r" "--read-only") "Use cache in read-only mode"
  (set! cache-read-only? #t)]
 [("-y" "--cache-only") file "Cache only for sources listed in <file>"
  (set! cache-save-only (call-with-input-file* file read))]
 [("-i" "--skip-initial") "Don't use cache for the initial load"
  (set! cache-skip-first? #t)]
 [("-s" "--s-expr") "Compile to S-expression instead of bytecode"
  (linklet-compile-to-s-expr #t)]
 [("--time") "Time re-expansion"
  (set! time-expand? #t)]
 #:once-any
 [("-t") file "Load specified file"
  (set! boot-module (path->complete-path file))]
 [("-l") lib "Load specified library"
  (set! boot-module (string->symbol lib))])

(define cache (make-cache cache-dir))

;; The `#lang` reader doesn't use the reimplemented module system,
;; so make sure the reader is loaded for `racket/base` (before
;; `boot` sets handlers):
(base:dynamic-require 'racket/base/lang/reader #f)

;; Simplified variant of the function from `syntax/modread`
;; that uses the expander's `namespace-module-identifier`:
(define (check-module-form s)
  (unless (and (pair? (syntax-e s))
               (eq? 'module (syntax-e (car (syntax-e s)))))
    (error "not a module form:" s))
  (datum->syntax
   #f
   (cons (namespace-module-identifier)
         (cdr (syntax-e s)))))

;; Install handlers:
(boot)

;; Avoid use of ".zo" files:
(use-compiled-file-paths null)

;; Replace the load handler to stash compiled modules in the cache
;; and/or load them from the cache
(current-load (lambda (path expected-module)
                (let loop ()
                  (cond
                   [(and cache
                         (not cache-skip-first?)
                         (get-cached-compiled cache path
                                              (lambda ()
                                                (when cache-dir
                                                  (log-status "cached ~s" path)))))
                    => eval]
                   [else
                    (log-status "compile ~s" path)
                    (set! cache-skip-first? #f)
                    (with-handlers ([exn:fail? (lambda (exn)
                                                 (log-status "...during ~s..." path)
                                                 (raise exn))])
                      (define s
                        (call-with-input-file*
                         path
                         (lambda (i)
                           (port-count-lines! i)
                           (with-module-reading-parameterization
                               (lambda ()
                                 (check-module-form
                                  (read-syntax (object-name i) i)))))))
                      (define c (compile s))
                      (when time-expand?
                        ;; Re-expanding avoids timing load of required modules
                        (time (expand s)))
                      (cond
                       [(and cache
                             (not cache-read-only?)
                             (or (not cache-save-only)
                                 (hash-ref cache-save-only (path->string path) #f)))
                        (cache-compiled! cache path c)
                        (loop)]
                       [else (eval c)]))]))))

;; Load and run the requested module
(namespace-require boot-module)

(when extract?
  ;; Extract a bootstrapping slice of the requested module
  (extract boot-module cache))