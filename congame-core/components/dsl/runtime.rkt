#lang racket/base

(require (for-syntax koyo/haml
                     racket/base)
         gregor
         gregor/period
         koyo/haml
         racket/format
         racket/list
         racket/match
         racket/vector
         "../study.rkt")

(provide
 make-put-all-keywords)

(define (make-put-all-keywords [action void])
  (make-keyword-procedure
   (lambda (kws kw-args)
     (for ([kw (in-list kws)]
           [arg (in-list kw-args)])
       (put (string->symbol (keyword->string kw)) arg))
     (action))))

(define (refresh-every n-seconds)
  (haml
   (:script
    (format #<<SCRIPT
setTimeout(function() {
  document.location.reload();
}, ~a*1000)
SCRIPT
            n-seconds))))


;; environment ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide
 make-environment
 make-initial-environment
 environment?
 environment-set!
 environment-ref)

(struct environment (parent bindings))

(define-syntax-rule (define-initial-env env-id id ...)
  (define env-id
    (make-hasheq
     (list (cons 'id id) ...))))

; FIXME: the next function should probably be removed after class 2023 It is
; helpful for students, but this version is probably misguided and hardcodes too
; much.
(define (assigning-treatments treatments
                              #:treatments-key [treatments-key 'treatments]
                              #:role-key [role-key 'role])
  (unless (get/global role-key #f)
    (with-study-transaction
      (when (empty? (get/instance/global treatments-key '()))
        (put/instance/global treatments-key (shuffle treatments)))
      (define remaining-treatments
        (get/instance/global treatments-key))
      (define role
        (first remaining-treatments))
      (put/global role-key role)
      (define updated-treatments
        (rest remaining-treatments))
      (put/instance/global treatments-key updated-treatments))))

(define (get/global k [default (lambda ()
                          (error 'get/global "value not found for key ~.s" k))])
  (parameterize ([current-study-stack '(*root*)])
    (get k default)))

(define (get/instance/global k [default (lambda ()
                          (error 'get/instance/global "value not found for key ~.s" k))])
  (parameterize ([current-study-stack '(*root*)])
    (get/instance k default)))

(define (put/global k v)
  (parameterize ([current-study-stack '(*root*)])
    (put k v)))

(define (put/instance/global k v)
  (parameterize ([current-study-stack '(*root*)])
    (put/instance k v)))

(define (put/moment k v)
  (put k (moment->iso8601 v)))

(define (put/instance/moment k v)
  (put/instance k (moment->iso8601 v)))

(define (put/global/moment k v)
  (put/global k (moment->iso8601 v)))

(define (get/moment k)
  (iso8601->moment (get k)))

(define (get/instance/moment k)
  (iso8601->moment (get/instance k)))

(define (get/global/moment k)
  (iso8601->moment (get/global k)))

(define-initial-env initial-env
  *
  +
  +period
  -
  /
  <
  <=
  =
  >
  >=
  add1
  append
  apply
  assigning-treatments
  build-list
  build-vector
  button
  cons
  current-participant-owner?
  date<=?
  date<?
  date=?
  date>=?
  date>?
  days
  done
  drop
  eighth
  empty?
  equal?
  error
  even?
  fifth
  first
  format
  fourth
  get
  get/global
  get/global/moment
  get/instance
  get/instance/global
  get/instance/moment
  get/moment
  hash
  hash-ref
  hash-set
  hash-set*
  hash-update
  hours
  iso8601->moment
  list
  list*
  list->vector
  list-ref
  make-list
  make-vector
  map
  max
  microseconds
  milliseconds
  min
  minutes
  modulo
  moment
  moment->iso8601
  moment<=?
  moment<?
  moment=?
  moment>=?
  moment>?
  moment?
  months
  nanoseconds
  next
  ninth
  not
  now
  now/moment
  number->string
  period
  put
  put/global
  put/global/moment
  put/instance
  put/instance/global
  put/instance/moment
  put/moment
  quotient
  random
  range
  refresh-every
  remainder
  rest
  round
  second
  seconds
  seventh
  shuffle
  sixth
  skip
  sort
  string->number
  string->symbol
  string=?
  sub1
  symbol->string
  take
  tenth
  third
  today
  vector
  vector->list
  vector-copy!
  vector-drop
  vector-empty?
  vector-length
  vector-map
  vector-ref
  vector-set!
  vector-take
  void
  weeks
  years
  zero?
  ~a
  ~r
  ~t)

(define (make-initial-environment)
  (define env (make-environment))
  (begin0 env
    (for ([(id v) (in-hash initial-env)])
      (environment-set! env id v))))

(define (make-environment [parent #f])
  (environment parent (make-hasheq)))

(define (environment-set! e id v)
  (hash-set! (environment-bindings e) id v))

(define (environment-ref e id)
  (hash-ref (environment-bindings e) id (λ ()
                                          (cond
                                            [(environment-parent e) => (λ (pe) (environment-ref pe id))]
                                            [else (error 'environment-ref "unbound variable ~a" id)]))))

(define (environment-has-binding? e id)
  (hash-has-key? (environment-bindings e) id))


;; interpreter ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide
 interpret)

(define-namespace-anchor ns-anchor)

(define (interpret e [env (make-initial-environment)])
  (let loop ([e e] [env env])
    (match e
      [`(#%app ,rator . ,rands)
       (loop (cons rator rands) env)]
      [`(#%top . ev)
       (λ (e) (loop e env))]
      [`(#%top . ,id)
       (loop id env)]

      [`(quote ,e) e]

      [`(lambda ,arg-ids . ,bodies)
       (lambda args
         (unless (equal? (length arg-ids) (length args))
           (error 'interpret "bad arity"))
         (define lambda-env (make-environment env))
         (for ([arg-id (in-list arg-ids)]
               [arg (in-list args)])
           (environment-set! lambda-env arg-id arg))
         (loop `(begin . ,bodies) lambda-env))]

      [`(begin . ,bodies)
       (define begin-env (make-environment env))
       (for/last ([body-e (in-list bodies)])
         (loop body-e begin-env))]

      [`(define ,id ,e)
       (unless (symbol? id)
         (error 'interpret "id must be a symbol"))
       (when (environment-has-binding? env id)
         (error 'interpret "cannot redefine variable ~a" id))
       (environment-set! env id (loop e env))
       (void)]

      [`(if ,test-e ,then-e ,else-e)
       (if (loop test-e env)
           (loop then-e (make-environment env))
           (loop else-e (make-environment env)))]

      [`(cond [,test-e . ,bodies] [else . ,else-bodies])
       (loop `(if ,test-e
                  (begin . ,bodies)
                  (begin . ,else-bodies))
             env)]

      [`(cond ,branch ,branches ... ,else-branch)
       (loop `(cond
                ,branch
                [else (cond
                        ,@branches
                        [else ,else-branch])])
             env)]

      [`(when ,test-e . ,bodies)
       (loop `(if ,test-e
                  (begin . ,bodies)
                  (void))
             env)]

      [`(unless ,test-e . ,bodies)
       (loop `(if ,test-e
                  (void)
                  (begin . ,bodies))
             env)]

      [`(or ,e1 ,e2)
       (or (loop e1 env)
           (loop e2 env))]

      [`(and ,e1 ,e2)
       (and (loop e1 env)
            (loop e2 env))]

      [`(for/list ([,id ,e]) . ,bodies)
       (loop `(map (lambda (,id) ,@bodies) ,e) env)]

      [`(with-transaction . ,bodies)
       (with-study-transaction
         (loop `(begin . ,bodies) env))]

      [`(goto ,id)
       (begin0 id
         (unless (symbol? id)
           (error 'interpret "goto: expected a symbol but received ~e" id)))]

      [`(haml . ,_rest)
       (parameterize ([current-namespace (namespace-anchor->namespace ns-anchor)])
         (loop (syntax->datum (expand (datum->syntax #f e))) env))]

      [(? boolean?) e]
      [(? number?) e]
      [(? string?) e]
      [(? symbol? id) (environment-ref env id)]

      [`(,rator . ,rands)
       (apply (loop rator env) (map (λ (rand) (loop rand env)) rands))]

      [_
       (error 'interpret "invalid expression: ~e" e)])))


;; randomization ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide
 make-randomized-study)

;; NOTE: Someone could provide a step named
;; `synthetic-randomizer-step`, in which case it will error.
(define (make-randomized-study steps)
  (define (randomize)
    (define shuffled-steps (shuffle (hash-keys steps)))
    (put 'steps shuffled-steps)
    (put 'remaining-steps shuffled-steps)
    (skip))
  (make-study
   "randomized-study"
   (cons
    (make-step 'synthetic-randomizer-step randomize randomizer-transition)
    (for/list ([(id step) (in-hash steps)])
      (make-step id step randomizer-transition)))))

(define (randomizer-transition)
  (let ([steps (get 'remaining-steps)])
    (cond
      [(null? steps)
       done]
      [else
       (put 'remaining-steps (cdr steps))
       (car steps)])))


;; help ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide
 ->step
 ->scripts
 ->styles)

(define (->step id v)
  (cond
    [(study? v) (make-step/study id v)]
    [(or (step/study? v) (step? v)) v]
    [else (make-step id v)]))

(define (->scripts strs)
  (for/list ([str (in-list strs)])
    (haml (:script str))))

(define (->styles strs)
  (for/list ([str (in-list strs)])
    (haml (:style ([:type "text/css"]) str))))
