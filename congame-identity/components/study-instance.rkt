#lang racket/base

(require db
         db/util/postgresql
         deta
         gregor
         json
         koyo/database
         racket/contract
         racket/sequence
         threading)

(provide
 (schema-out study-instance-data)
 list-all-study-instance-data/admin
 put-study-instance-data)

(define-schema study-instance-data
  #:table "study_instance_data"
  ([user-id id/f]
   [server-id id/f]
   [instance-id id/f]
   [study-stack (array/f symbol/f)]
   [key symbol/f]
   [value jsonb/f]
   [(last-put-at (now/moment)) datetime-tz/f]
   [(first-put-at (now/moment)) datetime-tz/f])
  #:pre-persist-hook
  (lambda (e)
    (set-study-instance-data-last-put-at e (now/moment))))

(define/contract (put-study-instance-data db
                                          #:user-id user-id
                                          #:server-id server-id
                                          #:instance-id instance-id
                                          #:study-stack study-stack
                                          #:key key
                                          #:value value)
  (-> database?
      #:user-id id/c
      #:server-id id/c
      #:instance-id id/c
      #:study-stack (listof symbol?)
      #:key symbol?
      #:value jsexpr?
      void?)
  (with-database-connection [conn db]
    (query-exec conn #<<SQL
INSERT INTO study_instance_data (
  user_id, server_id, instance_id, study_stack, key, value
) VALUES (
  $1, $2, $3, $4, $5, $6
) ON CONFLICT (
  user_id, server_id, instance_id, study_stack, key
) DO UPDATE SET
  value = EXCLUDED.value,
  last_put_at = CURRENT_TIMESTAMP
SQL
                user-id
                server-id
                instance-id
                (list->pg-array (map symbol->string study-stack))
                (symbol->string key)
                value)))

(define/contract (list-all-study-instance-data/admin db)
  (-> database? (listof study-instance-data?))
  (with-database-connection [conn db]
    (sequence->list
     (in-entities conn (~> (from study-instance-data #:as i)
                           (order-by ([i.instance-id #:desc]
                                      [i.user-id]
                                      [i.key #:asc])))))))
