#lang racket/base

(require (except-in forms form)
         (prefix-in forms: (only-in forms form))
         racket/contract
         racket/format
         racket/random
         marionette
         koyo/haml
         (prefix-in config: congame/config)
         congame/components/study
         (prefix-in bot: (submod congame/components/bot actions)))

(provide
 make-completion-code
 pp-money
 render-consent-form
 consent/bot)

(define/contract (pp-money amount #:currency [currency "£"])
  (-> number? string?)
  (~a currency (~r amount #:precision '(= 2))))

(define alphabet "abcdefghijklmnopqrstuvwxyz")
(define numbers "0123456789")

(define (make-completion-code [n 8])
  (apply string (random-sample (string-append alphabet numbers) n)))

(define (render-consent-form)
  (define the-form
    (form* ([consent? (ensure binding/text (required) (one-of '(("yes" . #t)
                                                                ("no"  . #f))))])
           consent?))
  (haml
   (:div
    (:h2 "Consent Form")
    (:p "This study is conducted by Marc Kaufmann and financed by Central European University")
    (:p "You can choose whether to participate or not in this experiment. If you accept to participate, you may still change your mind and leave the study at any time. In that case, you will however forfeit the participation bonus.")

    (:h3 "Study Purpose")
    (:p "The purpose of the study is to examine how people make work decisions over time under different circumstances and measure changes in these decisions.")

    (:h3 "Further Information")
    (:p "Participation in this experiment is not associated with any foreseeable risk or benefit.")
    (:p "Your answers will be collected confidentially and anonymously -- the researchers will not be able to link decisions and participants' identity, beyond the MTurk/Prolific ID provided.")

    (:p "In case the results of the study are published, there will be no references to your identity. Data anonymity is guaranteed.")
    (:p "If you have any questions or concerns regarding this study, please " (:a ((:href (string-append "mailto:" config:support-email))) "email us")".")
    (form
     the-form
     (λ (consent?) (put 'consent? consent?))
     (λ (rw)
       `(div
         (h3 "Consent")
         (form ((action "")
                (method "POST"))
               (div ((class "group"))
                    (label ((class "radio-group"))
                     "I agree to participate in the study"
                     ,(rw "consent?" (widget-radio-group '(("yes" . "Yes, I agree to participate in the study")
                                                           ("no"  . "No, I do not want to participate in the study")))))
                    ,@(rw "consent?" (widget-errors)))
               (button ([type "Submit"] [class "button"]) "Submit"))))))))

(define (consent/bot)
  (define consent-radios (bot:find-all "input[name='consent?']"))
  ; FIXME: Brittle, relies on "Yes" being the first input
  (element-click! (car consent-radios))
  (element-click! (bot:find "button[type=submit]")))