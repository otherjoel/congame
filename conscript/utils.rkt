#lang racket/base

(require (for-syntax racket/base
                     syntax/parse/pre)
         (prefix-in congame: congame/components/formular)
         (prefix-in congame: (submod congame/components/formular tools))

         koyo/haml)

(provide
 make-sliders
 ;make-sliders-3
 ;make-sliders-4
 )

(define-syntax (make-sliders stx)
  (syntax-parse stx
    [(_ n:nat)
     (with-syntax ([(kwd ...)
                    (map
                     string->keyword
                     (build-list
                      (syntax-e #'n)
                      (lambda (i) (format "slider-~a" i))))])
       #`(congame:formular
          (haml
           (:div
            (:div
             (:div ([:class "slider"])
                   (kwd
                    (congame:input-range))
                   (:span "Value: " (:output ""))) ... )
            congame:submit-button))))]))
;                   (input-range "")
;                   (haml (:span "Value: " (:output ""))))) ...
;            ))))]))

;(make-sliders 2)

;(make-sliders 2 slider-builder)

#;(define-syntax (make-sliders-2 stx)
  (syntax-parse stx
    [(_ n:nat tmp)
     (with-syntax ([(kwd ...)
                    (map
                     string->keyword
                     (build-list
                      (syntax-e #'n)
                      (lambda (i) (format "slider-~a" i))))])
       #'(haml
          (:div
           tmp ... )))]))

#;(make-sliders-2
 2
 (:div ([:class "slider"])
       (list
        kwd
        (input-range "")
        (haml
         (:span "Value: " (:output ""))))))


#;(define-for-syntax (make-slider kwd)
  `(haml
    (:div ([:class "slider"])
          (list
           ,kwd
           (input-range "")
           (haml
            (:span "Value: " (:output "")))))))

#;(define-syntax (make-sliders-3 stx)
  (syntax-parse stx
    [(_ n:nat)
     (with-syntax ([(kwd ...)
                    (map
                     string->keyword
                     (build-list
                      (syntax-e #'n)
                      (lambda (i) (format "slider-~a" i))))])
       #`(haml
          (:div
           (#,make-slider 'kwd) ... )))]))

#;(define (make-sliders-4 n proc)
  (haml
   (:div
    ,@(for/list ([i n])
        (proc (string->keyword (format "slider-~a" i)))))))