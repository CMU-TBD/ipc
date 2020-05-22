;;; Copyright (c) 2008, Carnegie Mellon University
;;;     This software is distributed under the terms of the 
;;;    Simplified BSD License (see ipc/LICENSE.TXT)

(eval-when (load eval)
  (load (make-pathname :directory (butlast (pathname-directory *load-truename*))
		     :name "lisp/IPC")))

;; A simple macro for converting from seconds to msecs.
(defmacro MSECS (seconds) `(* 1000 ,seconds))

(defconstant TASK_NAME "test1")

(defconstant MSG1 "msg1")
(defconstant MSG2 "msg2")
(defconstant MSG3 "msg3")
(defconstant MSG4 "msg4")
(defconstant MSG5 "msg5")

(defconstant QUERY_MSG "query1")

(defconstant QUERY2_MSG    "query2")
(defconstant RESPONSE2_MSG "response2")

(defconstant INT_FORMAT "int")
(defconstant STRING_FORMAT "string")

(IPC:IPC_defstruct (sample)
  (i1 1 :type integer)
  (str1 "" :type string)
  (d1 0.0 :type float))

(defconstant SAMPLE_FORMAT "{int, string, double}")

(IPC:IPC_defstruct (MATRIX_LIST)
  matrix;; [2][2]
  (matrixName "" :type string)
  (count 0 :type integer)
  (next nil :type MATRIX_LIST))

(defconstant MATRIX_LIST_FORMAT "{[float:2,2], string, int, *!}")

(defconstant MATRIX_FORMAT "[float:2,2]")

(defun msg1Handler (msgRef callData clientData)
  (format t "msg1Handler: Receiving message ~s of ~d bytes (~d) [~s]~%"
	  (IPC:IPC_msgInstanceName msgRef) (IPC:IPC_dataLength msgRef)
	  callData clientData)
  ;; Unmarshall the byte array and print it out.
  (let (lisp-data)
    (IPC:IPC_unmarshall (IPC:IPC_msgInstanceFormatter msgRef) callData lisp-data)
    (format t "   Lisp data: ~a~%" lisp-data))
  ;; Free up the byte array created when the message was receieved
  (IPC:IPC_freeByteArray callData))

(defun msg2Handler (msgRef callData clientData)
  (format t "msg2Handler: Receiving message ~s of ~d bytes (~d) [~s]~%"
	  (IPC:IPC_msgInstanceName msgRef) (IPC:IPC_dataLength msgRef)
	  callData clientData)
  ;; Unmarshall the byte array and print it out.
  (let (lisp-data)
    (IPC:IPC_unmarshall (IPC:IPC_msgInstanceFormatter msgRef) callData lisp-data)
    (format t "   Lisp data: ~a~%" lisp-data))
  ;; Free up the byte array created when the message was receieved
  (IPC:IPC_freeByteArray callData))

;;; Simpler form of message handlers that unmarshall data.
;;; Is essentially equivalent to the above two handlers
(defun msg3Handler (msgRef lispData clientData)
  (declare (ignore clientData))
  (format t "3: Receiving message ~s: Data: ~a~%"
	  (IPC:IPC_msgInstanceName msgRef) lispData))

(defun queryHandler (msgRef lispData clientData)
  (let ((publishStr "Published")
	(responseStr "Responded"))
    (format t "queryHandler: Receiving message ~s of ~d bytes (~s) [~a]~%" 
	    (IPC:IPC_msgInstanceName msgRef) (IPC:IPC_dataLength msgRef)
	    lispData clientData)
    ;; Publish this message -- all subscribers get it
    (format t "~%  (IPC:IPC_publishData ~s ~s)~%" MSG2 publishStr)
    (IPC:IPC_publishData MSG2 publishStr)
    ;; Respond with this message -- only the query handler gets it
    (let ((varcontent (IPC:new_IPC_VARCONTENT_TYPE)))
      (IPC:IPC_marshall (IPC:IPC_msgFormatter MSG2) responseStr varcontent)
      (format t "~%  IPC_respondVC(~a ~s ~a)~%" msgRef MSG2 varcontent)
      (IPC:IPC_respondVC msgRef MSG2 varcontent)
      (IPC:IPC_freeByteArray (IPC:IPC_VARCONTENT_TYPE_content varcontent)))))

;; Handles the response to QUERY_MSG messages
(defun replyHandler (msgRef callData clientData)
   (format t "replyHandler: Receiving message ~s (~a) [~a]~%"
	   (IPC:IPC_msgInstanceName msgRef) callData clientData))

;; Incoming message has a matrix_list format  The response is a
;;   message with the first matrix, but each element incremented by one.
(defun query2Handler (msgRef matrixList clientData)
  (format t "query2Handler: Receiving message ~s (~a) [~s]~%"
	  (IPC:IPC_msgInstanceName msgRef) matrixList clientData)

  ;;(IPC:IPC_printData (IPC:IPC_msgInstanceFormatter msgRef) t matrixList)

  (let ((matrix (MATRIX_LIST-matrix matrixList)))
    (dotimes (i 2) (dotimes (j 2) (incf (aref matrix i j))))
    (format t "~%  (IPC_respondData ~d ~s ~d)~%" 
	    msgRef RESPONSE2_MSG matrix)
    (IPC:IPC_respondData msgRef RESPONSE2_MSG matrix)))

;;; Echo the input.  In addition,
;;;  typing "q" will quit the program; 
;;;  typing "m" will send another message; 
;;;  typing "u" will unsubscribe the handler (the proram will no
;;;    longer listen to input)
(defun stdinHnd (fd clientData)
  (let ((inputLine (read-line)))
    (format t "[~s] Received: ~s~%" clientData inputLine)

    (when (= (length inputLine) 1)
      (cond ((eq (aref inputLine 0) #\q) 
	     (IPC:IPC_disconnect)
	     #+ALLEGRO (top-level:do-command "reset") #+LISPWORKS (abort)
	     )
	    ((eq (aref inputLine 0) #\m) (IPC:IPC_publishData MSG2 "Forwarding"))
	    ((eq (aref inputLine 0) #\u) (IPC:IPC_unsubscribeFD fd 'stdinHnd))))))

(defun ipcTest1 ()
  (let ((varcontent (IPC:new_IPC_VARCONTENT_TYPE)))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;                TESTS OF THE BASIC IPC INTERFACE
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;; Connect to the central server
    (format t "~%(IPC_connect ~s)~%" TASK_NAME)
    (IPC:IPC_connect TASK_NAME)

    ;; Default is to exit on error; Override default, because some of the
    ;; tests in this file explicitly induce errors.
    (format t "~%(IPC_setVerbosity IPC_Print_Errors)~%")
    (IPC:IPC_setVerbosity IPC:IPC_Print_Errors)

    ;; Does not make sense to define a fixed-length LISP message 
    ;; Define a variable length message (simple format string)
    (format t "~%(IPC_defineMsg ~s IPC_VARIABLE_LENGTH ~s)~%" MSG1 STRING_FORMAT)
    (IPC:IPC_defineMsg MSG1 IPC:IPC_VARIABLE_LENGTH STRING_FORMAT)
    ;; Define a variable length message (simple format string)
    (format t "~%(IPC_defineMsg ~s IPC_VARIABLE_LENGTH ~s)~%" MSG2 STRING_FORMAT)
    (IPC:IPC_defineMsg MSG2 IPC:IPC_VARIABLE_LENGTH STRING_FORMAT)
    (IPC:IPC_msgClass MSG2 'str)

    (format t "~%IPC_isMsgDefined(~s) => ~s~%" MSG1 (IPC:IPC_isMsgDefined MSG1))
    (format t "~%IPC_isMsgDefined(~s) => ~s~%" MSG3 (IPC:IPC_isMsgDefined MSG3))

    ;; Subscribe to the first message, with client data
    (format t "~%(IPC_subscribe ~s '~a ~s)~%" MSG1 'msg1Handler "client1a")
    (IPC:IPC_subscribe MSG1 'msg1Handler "client1a")
    ;; Subscribe to the second message, with client data
    (format t "~%(IPC_subscribe ~s '~a ~s)~%" MSG2 'msg1Handler "client2a")
    (IPC:IPC_subscribe MSG2 'msg1Handler "client2a")

    ;; Publish the first message and listen for it (in this simple 
    ;;   example program, both publisher and subscriber are in the same process
    ;; Here we explicitly marshall the data --
    ;;   later we'll just use IPC_publishData
    (IPC:IPC_marshall (IPC:IPC_msgFormatter MSG1) "abcde" varcontent) 
    (format t "~%(IPC_publishVC ~s ~a)~%" MSG1 varcontent)
    (cond ((eql (IPC::IPC_publishVC MSG1 varcontent) IPC:IPC_OK)
	   (IPC:IPC_listenClear (MSECS 1)))
	  (t (format t "failed")))
    (IPC:IPC_freeByteArray (IPC:IPC_VARCONTENT_TYPE_content varcontent))

    ;; Do the same thing, except spell it all out (and send more characters)
    (IPC:IPC_marshall (IPC:IPC_msgFormatter MSG1) "abcdefg" varcontent)
    (format t "~%(IPC_publish ~s ~d ~d)~%"
	    MSG1 (IPC:IPC_VARCONTENT_TYPE_length varcontent)
	    (IPC:IPC_VARCONTENT_TYPE_content varcontent))
    (when (eql (IPC::IPC_publish MSG1 (IPC:IPC_VARCONTENT_TYPE_length varcontent)
				 (IPC:IPC_VARCONTENT_TYPE_content varcontent))
	       IPC:IPC_OK) 
      (IPC:IPC_listenClear (MSECS 1)))
    (IPC:IPC_freeByteArray (IPC:IPC_VARCONTENT_TYPE_content varcontent))

    ;; Publish the same variable length message, this time using IPC_publishData
    ;; See how much easier it is!
    (format t "~%(IPC_publishData ~s ~s)~%" MSG2 "abcde")
    (when (eql (IPC:IPC_publishData MSG2 "abcde") IPC:IPC_OK) 
      (IPC:IPC_listenClear (MSECS 1)))

    ;; Produces an error: Cannot pass IPC_VARIABLE_LENGTH as an argument
    (format t "~%(IPC_publish ~s IPC_VARIABLE_LENGTH nil)~%" MSG2)
    (when (eql (IPC::IPC_publish MSG2 IPC:IPC_VARIABLE_LENGTH nil) IPC:IPC_Error)
      (format t "ERROR~%"))

    ;; Produces an error: "msg2" is a variable length message
    (format t "~%(IPC_publish ~s IPC_FIXED_LENGTH nil)~%" MSG2)
    (when (eql (IPC::IPC_publish MSG2 IPC:IPC_FIXED_LENGTH nil) IPC:IPC_Error)
      (format t "ERROR~%"))

    ;; Subscribe a second message handler for "msg2"
    (format t "~%(IPC_subscribe ~s '~a ~s)~%" MSG2 'msg2Handler "client2b")
    (IPC:IPC_subscribe MSG2 'msg2Handler "client2b")
    ;; If doing direct broadcasts, need to listen to get the direct info update
    (IPC:IPC_listen 250)

    ;; Publish the message -- receive two messages (one for msg1Handler, one
    ;;   for msg2Handler).
    (format t "~%(IPC_publishData ~s ~s)~%" MSG2 "abcdefg")
    (when (eql (IPC:IPC_publishData MSG2 "abcdefg") IPC:IPC_OK)
      ;; Make sure all the subscribers get invoked before continuing on
      ;;  (keep listening until a second has passed without any msgs)
      (do () ((eql (IPC:IPC_listen (MSECS 1)) IPC:IPC_Timeout))))

    ;; Remove this subscription
    (format t "~%(IPC_unsubscribe ~s '~a)~%" MSG2 'msg2Handler)
    (IPC:IPC_unsubscribe MSG2 'msg2Handler)
    ;; If doing direct broadcasts, need to listen to get the direct info update
    (IPC:IPC_listen 250)

    ;; Publish the message -- receive one message (for msg1Handler)
    (format t "~%(IPC_publishData ~s ~s)~%" MSG2 "abcdefg")
    (when (eql (IPC:IPC_publishData MSG2 "abcdefg") IPC:IPC_OK) (IPC:IPC_listen (MSECS 1)))

    ;; Subscription of the same message handler *replaces* the old client data
    (format t "~%(IPC_subscribe ~s '~a ~s)~%" MSG1 'msg1Handler "client1b")
    (IPC:IPC_subscribe MSG1 'msg1Handler "client1b")
    ;; Receive one message (for msg1Handler), but now with new client data.
    (format t "~%(IPC_publishData ~s ~s)~%" MSG1 "abcde")
    (when (eql (IPC:IPC_publishData MSG1 "abcde") IPC:IPC_OK) (IPC:IPC_listen (MSECS 1)))

    ;; Remove subscription to "msg1"
    (format t "~%(IPC_unsubscribe ~s '~a)~%" MSG1 'msg1Handler)
    (IPC:IPC_unsubscribe MSG1 'msg1Handler)
    ;; If doing direct broadcasts, need to listen to get the direct info update
    (IPC:IPC_listen 250)

    ;; Receive no messages -- IPC_listenClear times out
    (format t "~%(IPC_publishData ~s ~a)~%" MSG1 "abcde")
    (when (eql (IPC:IPC_publishData MSG1 "abcde") IPC:IPC_OK) 
      (when (eql (IPC:IPC_listen (MSECS 1)) IPC:IPC_Timeout) (format t "Timed out~%")))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;                TESTS OF THE QUERY/RESPONSE FUNCTIONS
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;; The handler of QUERY_MSG does two things: It *publishes* a message of
    ;;  type MSG2, and it *responds* to the query with a message of type MSG2.
    ;;  The published message gets handled only by the subscriber (msg1Handler),
    ;;  and the response gets handled only be replyHandler, since a response
    ;;  is a directed message.
    ;; NOTE: It is perfectly OK to subscribe to a message before it is defined!
    (format t "~%(IPC_subscribe ~s '~a ~s)~%" QUERY_MSG 'queryHandler "qtest")
    (IPC:IPC_subscribe QUERY_MSG 'queryHandler "qtest")
    (format t "~%(IPC_defineMsg ~s IPC_VARIABLE_LENGTH ~s)~%"
	    QUERY_MSG STRING_FORMAT)
    (IPC:IPC_defineMsg QUERY_MSG IPC:IPC_VARIABLE_LENGTH STRING_FORMAT)

    ;; This call allows IPC to send the process 2 messages at a time, rather 
    ;; than queueing them in the central server.
    ;; This is needed in this example program because the sender and receiver
    ;; of the query are the same process.  If this is taken out, the only 
    ;; difference is that the message that is published in queryHandler arrives
    ;; *after* the message responded to (even though it is sent first).  This 
    ;; function should not be needed when we switch to using point-to-point 
    ;; communications (rather than sending via the central server).
    (IPC:IPC_setCapacity 2)

    (IPC:IPC_marshall (IPC:IPC_msgFormatter QUERY_MSG) "abcdef" varcontent)
#-LISPWORKS_FFI_HACK
    (format t "~%(IPC_queryNotifyVC ~s ~a '~a ~s)~%" 
	    QUERY_MSG varcontent 'replyHandler "Notification")
#-LISPWORKS_FFI_HACK
    (IPC::IPC_queryNotifyVC QUERY_MSG varcontent 'replyHandler "Notification")
    ;; Make sure all the messages spawned by this query get handled before
    ;;   continuing (keep listening until a second has passed without any msgs)
    (do () ((eql (IPC:IPC_listen (MSECS 1)) IPC:IPC_Timeout)))

#-LISPWORKS_FFI_HACK
    (format t "~%(IPC_queryNotifyData ~s ~a '~a ~s)~%" 
	    QUERY_MSG "abcdef" 'replyHandler "Notification")
#-LISPWORKS_FFI_HACK
    (IPC:IPC_queryNotifyData QUERY_MSG "abcdef" 'replyHandler "Notification")
    ;; Make sure all the messages spawned by this query get handled before
    ;;   continuing (keep listening until a second has passed without any msgs)
    (do () ((eql (IPC:IPC_listen (MSECS 1)) IPC:IPC_Timeout)))

    ;; This essentially does the same thing as IPC_queryNotify above, except
    ;;  it is blocking, and sets the replyHandle to be the data responded to.
    ;;  Don't need to listen, since that is done within queryResponse, but
    ;;  could be dangerous to wait forever (if the response never comes ...)
#-LISPWORKS_FFI_HACK
    (IPC:IPC_marshall (IPC:IPC_msgFormatter QUERY_MSG) "abcdef" varcontent)
    (format t "~%(IPC_queryResponseVC ~s ~a '~a IPC_WAIT_FOREVER)~%" 
	    QUERY_MSG varcontent 'replyHandle)
    (multiple-value-bind (replyHandle ret)
	(IPC:IPC_queryResponseVC QUERY_MSG varcontent IPC:IPC_WAIT_FOREVER)
      (when (eql ret IPC:IPC_OK)
	;; We happen to know that the response is a message of type MSG2.
	;; We don't have to know this if we use IPC_queryResponseData
	(let (replyLispData)
	  (IPC:IPC_unmarshall (IPC:IPC_msgFormatter MSG2) replyHandle 
			      replyLispData)
	  (format t "Blocking Response: ~a~%" replyLispData))))

    ;; This one should time out before the response arrives
#-LISPWORKS_FFI_HACK
    (IPC:IPC_marshall (IPC:IPC_msgFormatter QUERY_MSG) "abcdef" varcontent)
    (format t "~%(IPC_queryResponseVC ~s ~a '~a ~d)~%" 
	    QUERY_MSG varcontent 'replyHandle 0)
    (multiple-value-bind (replyHandle ret)
	(IPC:IPC_queryResponseVC QUERY_MSG varcontent IPC:IPC_WAIT_FOREVER)
      (cond ((eql ret IPC:IPC_OK)
	     (format t "Blocking Response: ~a~%" replyHandle))
	    (t 
	     ;; NOTE: Since the function call times out before handling messages,
	     ;; (a) The *response* to the query is lost (for good)
	     ;; (b) The message *published* in queryHandler is waiting for the
	     ;;     next time the module listens for messages (which actually 
	     ;;     occurs in IPC_msgFormatter, below).
	     (format t "queryResponse timed out (replyHandle: ~a)~%"
		     replyHandle))))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;                TESTS OF THE MARSHALLING FUNCTIONS
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;; Test the marshalling/unmarshalling functions, independently of
    ;;  sending/receiving messages
    (let ((sample (make-sample :i1 666 :str1 "hello, world" :d1 pi))
	  sample2)
      (format t "~%(IPC_marshall ...)~%")
      (IPC:IPC_marshall (IPC:IPC_parseFormat SAMPLE_FORMAT) sample varcontent)
      (format t "~a~%" varcontent)
      (format t "~%(IPC_unmarshall ...)~%")
      (IPC:IPC_unmarshall (IPC:IPC_parseFormat SAMPLE_FORMAT)
		      (IPC:IPC_VARCONTENT_TYPE_content varcontent) sample2) 
      (format t "Orig: ~a~%Copy: ~a~%" sample sample2)
      (IPC:IPC_freeByteArray (IPC:IPC_VARCONTENT_TYPE_content varcontent)))

    ;; Define a variable-length message whose format is simply an integer
    (format t "~%(IPC_defineMsg ~s IPC_VARIABLE_LENGTH ~s)~%" MSG3 INT_FORMAT)
    (IPC:IPC_defineMsg MSG3 IPC:IPC_VARIABLE_LENGTH INT_FORMAT)
    ;; Define a variable-length message whose format is a string
    (format t "~%(IPC_defineMsg ~s IPC_VARIABLE_LENGTH ~s)~%" MSG4 STRING_FORMAT)
    (IPC:IPC_defineMsg MSG4 IPC:IPC_VARIABLE_LENGTH STRING_FORMAT)
    ;; Define a variable-length message whose format is a complex structure
    (format t "~%(IPC_defineMsg ~s IPC_VARIABLE_LENGTH ~s)~%" 
	    MSG5 MATRIX_LIST_FORMAT)
    (IPC:IPC_defineMsg MSG5 IPC:IPC_VARIABLE_LENGTH MATRIX_LIST_FORMAT)

    ;; Subscribe to each of the above messages, all using the same handler
    (format t "~%(IPC_subscribe ~s '~a nil)~%" MSG3 'msg3Handler)
    (IPC:IPC_subscribe MSG3 'msg3Handler nil)
    (format t "~%(IPC_subscribe ~s '~a nil)~%" MSG4 'msg3Handler)
    (IPC:IPC_subscribe MSG4 'msg3Handler nil)
    (format t "~%(IPC_subscribe ~s '~a nil)~%" MSG5 'msg3Handler)
    (IPC:IPC_subscribe MSG5 'msg3Handler nil)

    ;; Marshall the integer into a byte array (takes byte-order into account)
    ;; NOTE: Unlike the C version, you can give the value directly, rather
    ;;   than having to pass a pointer to a variable whose value is that int
    (format t "~%(IPC_marshall ...)~%")
    (IPC:IPC_marshall (IPC:IPC_msgFormatter MSG3) 42 varcontent)
    ;; Publish the marshalled byte array (message handler prints the data)
    (format t "~%(IPC_publishVC ~s ~a)~%" MSG3 varcontent)
    (IPC::IPC_publishVC MSG3 varcontent)
    (IPC:IPC_freeByteArray (IPC:IPC_VARCONTENT_TYPE_content varcontent))
    (IPC:IPC_listenClear (MSECS 1))

    ;; Marshall the string into a byte array.
    ;; It's much better (safer) to use IPC_msgFormatter, but this is included
    ;;  just to illustrate the use of IPC_parseFormat
    (format t "~%(IPC_marshall ...)~%")
    (IPC:IPC_marshall (IPC:IPC_parseFormat STRING_FORMAT) "Hello, world" varcontent)
    ;; Publish the marshalled byte array (message handler prints the data)
    (format t "~%(IPC_publishVC ~s ~a)~%" MSG4 varcontent)
    (IPC::IPC_publishVC MSG4 varcontent)
    (IPC:IPC_listenClear (MSECS 1))

    ;; Set up a sample MATRIX_LIST structure
    (let ((m1 (make-MATRIX_LIST
	       :matrix (make-array '(2 2) :initial-contents '((0 1)(1 2)))
	       :matrixName "TheFirst"
	       :count 1
	       :next (make-MATRIX_LIST
		      :matrix (make-array '(2 2) :initial-contents '((1 2)(2 3)))
		      :matrixName "TheSecond"
		      :count 2
		      :next (make-MATRIX_LIST
			     :matrix (make-array
				      '(2 2) :initial-contents '((2 3)(3 4)))
			     :matrixName "TheThird"
			     :count 3
			     :next nil)))))
      ;; IPC_publishData both marsalls and publishes the data structure
      ;; LISP users should try to use this exclusively, if posible.
      (format t "~%(IPC_publishData ~s ~a)~%" MSG5 m1)
      (IPC:IPC_publishData MSG5 m1)
      (IPC:IPC_listenClear (MSECS 1))
      )

    ;; Use of IPC_queryResponseData and IPC_respondData -- 
    ;;   Send out a message with a matrix_list format  The response is a
    ;;   message with the first matrix, but each element incremented by one.

    ;; Define the "query" message
    (format t "~%(IPC_defineMsg ~s IPC_VARIABLE_LENGTH ~s)~%" 
	    QUERY2_MSG MATRIX_LIST_FORMAT)
    (IPC:IPC_defineMsg QUERY2_MSG IPC:IPC_VARIABLE_LENGTH MATRIX_LIST_FORMAT)
    (IPC:IPC_msgClass QUERY2_MSG 'MATRIX_LIST)
    ;; Define the "response" message
    (format t "~%(IPC_defineMsg ~s IPC_VARIABLE_LENGTH ~s)~%" 
	    RESPONSE2_MSG MATRIX_FORMAT)
    (IPC:IPC_defineMsg RESPONSE2_MSG IPC:IPC_VARIABLE_LENGTH MATRIX_FORMAT)
    (IPC:IPC_msgClass RESPONSE2_MSG 'MATRIX)

    ;; Subscribe to query message with automatic unmarshalling
    (format t "~%(IPC_subscribeData ~s '~a nil)~%" QUERY2_MSG 'query2Handler)
    (IPC:IPC_subscribeData QUERY2_MSG 'query2Handler nil)
  
    ;; Set up a sample MATRIX_LIST structure
#-LISPWORKS_FFI_HACK
    (let ((m1 (make-MATRIX_LIST 
	       :matrix (make-array '(2 2) :initial-contents '((0 1)(1 2)))
	       :matrixName "TheFirst"
	       :count 1
	       :next nil)))
      ;; IPC_queryResponseData both marsalls and sends the data structure
      (format t "~%(IPC_queryResponseData ~s ~a '~a IPC_WAIT_FOREVER)~%" 
	      QUERY2_MSG m1 'matrixPtr)
      (multiple-value-bind (matrixPtr ret)
	  (IPC:IPC_queryResponseData QUERY2_MSG m1 IPC:IPC_WAIT_FOREVER)
	(cond ((eql ret IPC:IPC_OK)
	       (format t "Response data: ~a~%" matrixPtr))
	      (t (format t "IPC_queryResponseData failed~%")))))

    ;; Subscribe a handler for tty input.  Now, typing at the terminal will
    ;;  echo the input.  Typing "q" will quit the program; typing "m" will
    ;;  send a message; typing "u" will unsubscribe the handler (the program
    ;;  will no longer listen to input).
#-LISPWORKS_FFI_HACK
    (format t "~%(IPC_subscribeFD ~d '~a ~s)~%" 0 'stdinHnd "FD1")
#-LISPWORKS_FFI_HACK
    (IPC:IPC_subscribeFD 0 'stdinHnd "FD1")

#-LISPWORKS_FFI_HACK
    (format t "~%Entering dispatch loop (terminal input is echoed, type 'q' to quit,~%")
#-LISPWORKS_FFI_HACK
    (format t "  'm' to send a message, 'u' to stop listening to stdin).~%")
#-LISPWORKS_FFI_HACK
    (IPC:IPC_dispatch)

    ;; If ever reaches here, shut down gracefully
    (IPC:IPC_disconnect)
    ))
