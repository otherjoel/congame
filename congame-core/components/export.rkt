#lang racket/base

(require racket/contract
         racket/format
         racket/generic
         gregor
         json
         web-server/http)

(provide
 gen:jsexprable
 jsexprable?

 (contract-out
  [->jsexpr (-> any/c jsexpr?)]))

(define-logger jsexprable)

(define (list->jsexpr xs)
  (map ->jsexpr xs))

(define (pair->jsexpr p)
  (list (->jsexpr (car p)) (->jsexpr (cdr p))))

;; WARN: Studies can store hashes with arbirtrary keys, which means
;; over here we may end up with collisions because we convert
;; non-symbol keys to symbols.  So, a hash that has an entry with key
;; "42" (string) and one with 42 (number) will collide, one of the
;; keys winning over the other (nondeterministically).
(define (hash->jsexpr xs)
  (for/hash ([(k v) (in-hash xs)])
    (define k-sym
      (cond
        [(symbol? k) k]
        [else
         (log-jsexprable-warning "key ~.s converted to JSON string!" k)
         (string->symbol (~a k))]))
    (values k-sym (->jsexpr v))))

(define (binding:file->jsexpr b)
  (format "<file:~a, size:~a>" (binding:file-filename b) (~MiB (bytes-length (binding:file-content b)))))

(define (~MiB b)
  (~a (~r #:precision '(= 2) (/ b 1024.0 1024.0)) "MB"))

(define (moment->jsexpr m)
  ; FIXME: Should we use moment->iso8601 instead?
  (moment->iso8601/tzid m))

(define (date->jsexpr d)
  (date->iso8601 d))

(define (datetime->jsexpr dt)
  ; FIXME: should we deal with timezones?
  (datetime->iso8601 dt))

(define-generics jsexprable
  [->jsexpr jsexprable]
  #:fast-defaults
  ([boolean?      (define ->jsexpr values)]
   [number?       (define ->jsexpr values)]
   [string?       (define ->jsexpr values)]
   [symbol?       (define ->jsexpr symbol->string)]
   [list?         (define ->jsexpr list->jsexpr)]
   [pair?         (define ->jsexpr pair->jsexpr)]
   [hash?         (define ->jsexpr hash->jsexpr)]
   [bytes?        (define ->jsexpr bytes->string/utf-8)]
   [binding:file? (define ->jsexpr binding:file->jsexpr)]
   [moment?       (define ->jsexpr moment->jsexpr)]
   [date?         (define ->jsexpr date->jsexpr)]
   [datetime?     (define ->jsexpr datetime->jsexpr)]))
