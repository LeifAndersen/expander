#lang racket/base
(require "syntax.rkt"
         "datum-map.rkt"
         (prefix-in host:
                    (only-in racket/base
                             syntax? syntax-e syntax-property
                             syntax-source syntax-line syntax-column
                             syntax-position syntax-span)))

(provide original-property-sym
         host-syntax->syntax)

(define (host-syntax->syntax v)
  (datum-map v
             (lambda (tail? v)
               (cond
                [(host:syntax? v)
                 (struct-copy syntax empty-syntax
                              [content (host-syntax->syntax (host:syntax-e v))]
                              [srcloc (srcloc (host:syntax-source v)
                                              (host:syntax-line v)
                                              (host:syntax-column v)
                                              (host:syntax-position v)
                                              (host:syntax-span v))]
                              [props (case (host:syntax-property v 'paren-shape)
                                       [(#\[) original-square-props]
                                       [(#\{) original-curly-props]
                                       [else original-props])])]
                [else v]))))

(define original-property-sym
  (gensym 'original))

(define original-props
  (syntax-props (syntax-property empty-syntax original-property-sym #t)))
(define original-square-props
  (syntax-props (syntax-property (syntax-property empty-syntax original-property-sym #t)
                                 'paren-shape #\[)))
(define original-curly-props
  (syntax-props (syntax-property (syntax-property empty-syntax original-property-sym #t)
                                 'paren-shape #\{)))
