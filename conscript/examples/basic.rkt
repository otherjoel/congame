#lang conscript

(provide
 example)

(defstep (info)
  @html{@h1{Hello!}
        Welcome to the study.
        @button[void]{Continue}})

(defstep (consent)
  @html{@h1{Consent}
        Do you consent to join the study?
        @button[void]{Give Consent}})

(defstudy (example)
  [info --> consent --> ,done])