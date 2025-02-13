#lang racket/base

(require (for-syntax racket/base)
         congame-web/components/auth
         congame-web/components/memory
         congame-web/components/prolific
         congame-web/components/replication
         congame-web/components/sentry
         congame-web/components/study-bot
         (prefix-in tpl: congame-web/components/template)
         congame-web/components/upload
         congame-web/components/user
         (prefix-in config: congame-web/config)
         congame-web/pages/all
         congame/components/resource
         congame/components/study
         koyo
         koyo/database/migrator
         koyo/error
         koyo/sentry
         net/url
         racket/contract
         racket/format
         racket/runtime-path
         racket/string
         sentry
         threading
         (only-in xml current-unescaped-tags html-unescaped-tags)
         web-server/dispatch
         (prefix-in files: web-server/dispatchers/dispatch-files)
         (prefix-in filter: web-server/dispatchers/dispatch-filter)
         (prefix-in sequencer: web-server/dispatchers/dispatch-sequencer)
         web-server/dispatchers/filesystem-map
         web-server/http
         (only-in web-server/http/response current-header-handler)
         web-server/managers/lru
         web-server/servlet-dispatch)

(provide
 make-app
 app?
 app-dispatcher)

(define-runtime-path static-path
  (build-path 'up 'up "static"))

(define url->path
  (make-url->path static-path))

(define (static-url->path u)
  (url->path (struct-copy url u [path (cdr (url-path u))])))

(define static-dispatcher
  (files:make
   #:url->path static-url->path
   #:path->mime-type path->mime-type))

(struct app (dispatcher))

(define-logger request)

(define ((make-logging-dispatcher disp) conn req)
  (define start-ms
    (current-inexact-monotonic-milliseconds))
  (parameterize ([current-header-handler
                  (λ (resp)
                    (begin0 resp
                      (log-request-debug
                       "~a /~a ~a [~a] [~a] [~ams]"
                       (request-method req)
                       (string-join (map path/param-path (url-path (request-uri req))) "/")
                       (response-code resp)
                       (request-client-ip req)
                       (and~>
                        (headers-assq* #"user-agent" (request-headers/raw req))
                        (header-value))
                       (~r #:precision '(= 2)
                           (- (current-inexact-monotonic-milliseconds) start-ms)))))])
    (disp conn req)))

(define/contract (make-app auth bot-manager broker broker-admin db flashes mailer _migrator _params reps sessions uploads users)
  (-> auth-manager? bot-manager? broker? broker-admin? database? flash-manager? mailer? migrator? void? replication-manager? session-manager? uploader? user-manager? app?)
  (define-values (dispatch reverse-uri req-roles)
    (dispatch-rules+roles
     [("")
      home-page]

     [("dashboard")
      #:roles (user)
      #:method (or "get" "post")
      (study-instances-page db)]

     [("admin")
      #:roles (admin)
      (admin:studies-page db)]

     [("admin" "replications" "new")
      #:roles (admin)
      (admin:create-replication-page db reps)]

     [("admin" "studies" "new")
      #:roles (admin)
      (admin:create-study-page db)]

     [("admin" "studies" "bulk-archive")
      #:roles (admin)
      (admin:bulk-archive-instances-page db)]

     [("admin" "studies" (integer-arg))
      #:roles (admin)
      (admin:view-study-page db)]

     [("admin" "studies" (integer-arg) "edit")
      #:roles (admin)
      (admin:edit-study-dsl-page db)]

     [("admin" "studies" (integer-arg) "instances" "new")
      #:roles (admin)
      (admin:create-study-instance-page db)]

     [("admin" "studies" (integer-arg) "instances" (integer-arg) "edit")
      #:roles (admin)
      (admin:edit-study-instance-page db)]

     [("admin" "studies" (integer-arg) "instances" (integer-arg))
      #:roles (admin)
      (admin:view-study-instance-page db)]

     [("admin" "studies" (integer-arg) "instances" (integer-arg) "links" "new")
      #:roles (admin)
      (admin:create-study-instance-link-page db)]

     [("admin" "studies" (integer-arg) "instances" (integer-arg) "participants" (integer-arg))
      #:roles (admin)
      (admin:view-study-participant-page auth db)]

     [("admin" "studies" (integer-arg) "instances" (integer-arg) "bot-sets" "new")
      #:roles (admin)
      (admin:create-study-instance-bot-sets-page db)]

     [("admin" "studies" (integer-arg) "instances" (integer-arg) "bot-sets" (integer-arg))
      #:roles (admin)
      (admin:view-study-instance-bot-set-page db users)]

     [("admin" "tags" "new")
      #:roles (admin)
      (admin:create-tag-page db)]

     [("admin" "tags" (integer-arg))
      #:roles (admin)
      (admin:view-tag-page db)]

     [("admin" "jobs" (string-arg) ...)
      #:roles (admin)
      (lambda (req . _args)
        ((broker-admin-handler broker-admin) req))]

     [("admin" "stop-impersonation")
      (admin:stop-impersonation-page auth)]

     [("api" "v1" "cli-studies")
      #:roles (api admin)
      #:method "post"
      (admin:upsert-cli-study-page db)]

     [("api" "v1" "studies.json")
      #:roles (api)
      (api:studies db)]

     [("api" "v1" "studies" (integer-arg) "instances.json")
      #:roles (api)
      (api:study-instances db)]

     [("api" "v1" "studies" (integer-arg) "instances" (integer-arg) "participants.json")
      #:roles (api admin)
      (api:study-participants db)]

     [("api" "v1" "study-participants-with-identity")
      #:roles (api)
      #:method "post"
      (api:enroll-participant-from-identity db users)]

     [("api" "v1" "tags.json")
      #:roles (api)
      (api:tags db)]

     [("errors" "file-too-large")
      (error-413-page)]

     [("study" (string-arg))
      #:roles (user)
      (study-page db)]

     [("study" (string-arg) "view" (string-arg) ...)
      #:roles (user)
      (study-view-page db)]

     [("_anon-login" (string-arg))
      (anon-login-page auth db users)]

     [("_cli-login")
      #:roles (user)
      (cli-login-page db)]

     [("_token-login" (string-arg))
      (token-login-page auth db)]

     [("login")
      (login-page auth)]

     [("logout")
      (logout-page auth)]

     [("password-reset")
      (request-password-reset-page flashes mailer users)]

     [("password-reset" (integer-arg) (string-arg))
      (password-reset-page flashes mailer users)]

     [("secret-signup")
      (signup-page auth mailer users)]

     [("verify" (integer-arg) (string-arg))
      (verify-page flashes users)]

     [("resource" (string-arg))
      serve-resource-page]

     [("resource" (string-arg) (string-arg))
      serve-resource-page]

     [("dsl-resource" (integer-arg) (string-arg) ...)
      (serve-dsl-resource-page db)]))

  ;; Requests go up (starting from the last wrapper) and respones go down!
  (define wrap-sentry
    (make-sentry-wrapper #:client (current-sentry)))

  (define (stack handler)
    (~> handler
        (wrap-protect-continuations)
        ((wrap-bot-manager bot-manager))
        ((wrap-uploads uploads))
        (wrap-current-sentry-user)
        ((wrap-auth-required auth req-roles))
        ((wrap-browser-locale sessions))
        (wrap-sentry)
        (wrap-prolific)
        ((wrap-memory-limit (* 64 1024 1024))) ;; memory leaks only guarded "up" from here
        ((wrap-errors config:debug))
        ((wrap-flash flashes))
        ((wrap-session sessions))
        (wrap-preload)
        (wrap-cors)
        (wrap-profiler)))

  (current-broker broker)
  (current-continuation-wrapper stack)
  (current-reverse-uri-fn reverse-uri)
  (current-resource-uri-fn
   (lambda (r subr)
     (if subr
         (reverse-uri 'serve-resource-page (resource-id r) subr)
         (reverse-uri 'serve-resource-page (resource-id r)))))
  (current-production-error-page production-error-page)
  (current-unescaped-tags html-unescaped-tags)
  (current-xexpr-wrapper tpl:page/xexpr)

  (define manager
    (make-threshold-LRU-manager (stack expired-page) (* 8 1024 1024 1024)))

  (app (make-logging-dispatcher
        (sequencer:make
         (filter:make #rx"^/static/.+$" static-dispatcher)
         (dispatch/servlet #:manager manager (stack dispatch))
         (dispatch/servlet #:manager manager (stack not-found-page))))))
