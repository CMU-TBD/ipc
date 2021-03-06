/*****************************************************************************
 * PROJECT: IPC (Interprocess Communication) Package
 *
 * (c) Copyright 2011 Reid Simmons.  All rights reserved.
 *
 * FILE:	IPC.i
 *
 * DESCRIPTION: SWIG interface file for Python interface
 *              Liberally adapted by Reid from initial work by 
 *              Trey Smith and Nathaniel Fairfield
 *
 *       $Id: IPC.i,v 1.1 2013/07/23 21:11:38 reids Exp $
 * $Revision: 1.1 $
 *     $Date: 2013/07/23 21:11:38 $
 *   $Author: reids $
 *    $State: Exp $
 *   $Locker:  $
 *
 * Copyright (c) 2011, Carnegie Mellon University
 *     This software is distributed under the terms of the 
 *     Simplified BSD License (see ipc/LICENSE.TXT)
 *
 * REVISION HISTORY
 * $Log: IPC.i,v $
 * Revision 1.1  2013/07/23 21:11:38  reids
 * Updated for using SWIG
 *
 * Revision 1.1  2011/08/16 16:00:36  reids
 * Adding Python interface to IPC
 *
 ****************************************************************/	

/**********************************************************************
 * INCLUDES
 **********************************************************************/

%module IPC

%pragma(java) modulebase="ipcJava"

%{
// The code here will appear in the wrapper generated by SWIG.  The
// wrapper creates C functions that accept python objects as arguments,
// translate those arguments as necessary, and then call the underlying
// C functions.  These directives need to be in the wrapper file so that
// the underlying C functions are available to the wrapper functions.

#include "ipc.h"
#include "IPC_wrap.h"
extern void SWIG_init(void); // To prevent compiler from complaining

#define NMP_IPC
#define NEED_DEBUGGING
#include "ipcFFI.c"
#include "ipcJava.c"

%}

/**********************************************************************
 * MAIN BODY
 **********************************************************************/

// Handling exceptions that occur within handlers (or exit proc)
/*
%exception {
  $action
  if (PyErr_Occurred() != NULL) SWIG_fail;
}
*/

%rename (BUFFER_TYPE) _BUFFER_TYPE;
%ignore _BUFFER_TYPE();
typedef struct _BUFFER_TYPE {};

%rename (FORMAT_TYPE) _FORMAT_TYPE;
typedef struct _FORMAT_TYPE {};

%rename (MSG_INSTANCE) _X_IPC_REF;
typedef struct _X_IPC_REF {};

%rename (IPC_CONTEXT) _X_IPC_CONTEXT;
typedef struct _X_IPC_CONTEXT {};

# Functions that are rewritten for the Python version of IPC (see ipcPython.py)
%rename(_IPC_connect) IPC_connect;
%rename(_IPC_connectModule) IPC_connectModule;
%rename(_IPC_connectNoListen) IPC_connectNoListen;
%rename(_IPC_connectModuleNoListen) IPC_connectModuleNoListen;
%rename(_IPC_isConnected) IPC_isConnected;
%rename(_IPC_isModuleConnected) IPC_isModuleConnected;
%rename(_IPC_isMsgDefined) IPC_isMsgDefined;
%rename(_IPC_initialize) IPC_initialize;
%rename(_IPC_removeTimerByRef) IPC_removeTimerByRef;

%ignore IPC_subscribe;
%ignore IPC_subscribeData;
%ignore IPC_unsubscribe;
%ignore IPC_subscribeFD;
%ignore IPC_unsubscribeFD;
%ignore IPC_subscribeConnect;
%ignore IPC_subscribeDisconnect;
%ignore IPC_unsubscribeConnect;
%ignore IPC_unsubscribeDisconnect;
%ignore IPC_subscribeHandlerChange;
%ignore IPC_unsubscribeHandlerChange;
%ignore IPC_queryNotify;
%ignore IPC_queryResponse;
%ignore IPC_queryNotifyVC;
%ignore IPC_queryResponseVC;
%ignore IPC_marshall;
%ignore IPC_unmarshall;
%ignore IPC_unmarshallData;
%ignore IPC_freeData;
%ignore IPC_freeDataElements;
%ignore IPC_publishData;
%ignore IPC_respondData;
%ignore IPC_queryNotifyData;
%ignore IPC_queryResponseData;
%ignore IPC_printData;
%ignore IPC_readData;
%ignore IPC_addTimer;
%ignore IPC_addTimerGetRef;
%ignore IPC_addOneShotTimer;
%ignore IPC_addPeriodicTimer;
%ignore IPC_removeTimer;
%ignore x_ipcRegisterExitProc;

%include "ipc.h"

#define DEFINE_FOR_SWIG
#define NEED_DEBUGGING
%include ipcFFI.h
%include ipcJava.h
