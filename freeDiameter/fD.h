/*********************************************************************************************************
* Software License Agreement (BSD License)                                                               *
* Author: Sebastien Decugis <sdecugis@nict.go.jp>							 *
*													 *
* Copyright (c) 2009, WIDE Project and NICT								 *
* All rights reserved.											 *
* 													 *
* Redistribution and use of this software in source and binary forms, with or without modification, are  *
* permitted provided that the following conditions are met:						 *
* 													 *
* * Redistributions of source code must retain the above 						 *
*   copyright notice, this list of conditions and the 							 *
*   following disclaimer.										 *
*    													 *
* * Redistributions in binary form must reproduce the above 						 *
*   copyright notice, this list of conditions and the 							 *
*   following disclaimer in the documentation and/or other						 *
*   materials provided with the distribution.								 *
* 													 *
* * Neither the name of the WIDE Project or NICT nor the 						 *
*   names of its contributors may be used to endorse or 						 *
*   promote products derived from this software without 						 *
*   specific prior written permission of WIDE Project and 						 *
*   NICT.												 *
* 													 *
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED *
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A *
* PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR *
* ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 	 *
* LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 	 *
* INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR *
* TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF   *
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.								 *
*********************************************************************************************************/

/* This file contains the definitions for internal use in the freeDiameter daemon */

#ifndef _FD_H
#define _FD_H

#include <freeDiameter/freeDiameter-host.h>
#include <freeDiameter/freeDiameter.h>

#ifdef DISABLE_SCTP
#undef IPPROTO_SCTP
#define IPPROTO_SCTP	(2 = 4) /* some compilation error to spot the references */
#endif /* DISABLE_SCTP */

/* Timeout for establishing a connection */
#ifndef CNX_TIMEOUT
#define  CNX_TIMEOUT	10	/* in seconds */
#endif /* CNX_TIMEOUT */

/* Timeout for receiving a CER after incoming connection is established */
#ifndef INCNX_TIMEOUT
#define  INCNX_TIMEOUT	 20	/* in seconds */
#endif /* INCNX_TIMEOUT */

/* Timeout for receiving a CEA after CER is sent */
#ifndef CEA_TIMEOUT
#define  CEA_TIMEOUT	10	/* in seconds */
#endif /* CEA_TIMEOUT */

/* The timeout value to wait for answer to a DPR */
#ifndef DPR_TIMEOUT
#define DPR_TIMEOUT 	15	/* in seconds */
#endif /* DPR_TIMEOUT */

/* Configuration */
int fd_conf_init();
void fd_conf_dump();
int fd_conf_parse();
int fddparse(struct fd_config * conf); /* yacc generated */

/* Extensions */
int fd_ext_add( char * filename, char * conffile );
int fd_ext_load();
void fd_ext_dump(void);
int fd_ext_fini(void);

/* Messages */
int fd_msg_init(void);

/* Global message queues */
extern struct fifo * fd_g_incoming; /* all messages received from other peers, except local messages (CER, ...) */
extern struct fifo * fd_g_outgoing; /* messages to be sent to other peers on the network following routing procedure */
extern struct fifo * fd_g_local; /* messages to be handled to local extensions */
/* Message queues */
int fd_queues_init(void);
int fd_queues_fini(void);

/* Create all the dictionary objects defined in the Diameter base RFC. */
int fd_dict_base_protocol(struct dictionary * dict);

/* Sentinel for the sent requests list */
struct sr_list {
	struct fd_list 	srs;
	pthread_mutex_t	mtx;
};

/* Peers */
struct fd_peer { /* The "real" definition of the peer structure */
	
	/* The public data */
	struct peer_hdr	 p_hdr;
	
	/* Eye catcher, EYEC_PEER */
	int		 p_eyec;
	#define EYEC_PEER	0x373C9336
	
	/* Origin of this peer object, for debug */
	char		*p_dbgorig;
	
	/* Chaining in peers sublists */
	struct fd_list	 p_actives;	/* list of peers in the STATE_OPEN state -- used by routing */
	struct fd_list	 p_expiry; 	/* list of expiring peers, ordered by their timeout value */
	struct timespec	 p_exp_timer;	/* Timestamp where the peer will expire; updated each time activity is seen on the peer (except DW) */
	
	/* Some flags influencing the peer state machine */
	struct {
		unsigned pf_responder	: 1;	/* The local peer is responder on the connection */
		
		unsigned pf_dw_pending 	: 1;	/* A DWR message was sent and not answered yet */
		
		unsigned pf_cnx_pb	: 1;	/* The peer was disconnected because of watchdogs; must exchange 3 watchdogs before putting back to normal */
		unsigned pf_reopen_cnt	: 2;	/* remaining DW to be exchanged after re-established connection */
		
		/* to be completed */
		
	}		 p_flags;
	
	/* The events queue, peer state machine thread, timer for states timeouts */
	struct fifo	*p_events;	/* The mutex of this FIFO list protects also the state and timer information */
	pthread_t	 p_psm;
	struct timespec	 p_psm_timer;
	
	/* Outgoing message queue, and thread managing sending the messages */
	struct fifo	*p_tosend;
	pthread_t	 p_outthr;
	
	/* The next hop-by-hop id value for the link, only read & modified by p_outthr */
	uint32_t	 p_hbh;
	
	/* Sent requests (for fallback), list of struct sentreq ordered by hbh */
	struct sr_list	 p_sr;
	
	/* connection context: socket and related information */
	struct cnxctx	*p_cnxctx;
	
	/* Callback for peer validation after the handshake */
	int		(*p_cb2)(struct peer_info *);
	
	/* Callback on initial connection success / failure after the peer was added */
	void 		(*p_cb)(struct peer_info *, void *);
	void 		*p_cb_data;
	
};
#define CHECK_PEER( _p ) \
	(((_p) != NULL) && (((struct fd_peer *)(_p))->p_eyec == EYEC_PEER))

/* Events codespace for struct fd_peer->p_events */
enum {
	/* Dump all info about this peer in the debug log */
	 FDEVP_DUMP_ALL = 1500
	
	/* request to terminate this peer : disconnect, requeue all messages */
	,FDEVP_TERMINATE
	
	/* A connection object has received a message. (data contains the buffer) */
	,FDEVP_CNX_MSG_RECV
			 
	/* A connection object has encountered an error (disconnected). */
	,FDEVP_CNX_ERROR
	
	/* Endpoints of a connection have been changed (multihomed SCTP). */
	,FDEVP_CNX_EP_CHANGE
	
	/* A new connection has been established (data contains the appropriate info) */
	,FDEVP_CNX_INCOMING
	
	/* The PSM state is expired */
	,FDEVP_PSM_TIMEOUT
	
};
#define CHECK_PEVENT( _e ) \
	(((int)(_e) >= FDEVP_DUMP_ALL) && ((int)(_e) <= FDEVP_PSM_TIMEOUT))
/* The following macro is actually called in p_psm.c -- another solution would be to declare it static inline */
#define DECLARE_PEV_STR()				\
const char * fd_pev_str(int event)			\
{							\
	switch (event) {				\
		case_str(FDEVP_DUMP_ALL);		\
		case_str(FDEVP_TERMINATE);		\
		case_str(FDEVP_CNX_MSG_RECV);		\
		case_str(FDEVP_CNX_ERROR);		\
		case_str(FDEVP_CNX_EP_CHANGE);		\
		case_str(FDEVP_CNX_INCOMING);		\
		case_str(FDEVP_PSM_TIMEOUT);		\
	}						\
	TRACE_DEBUG(FULL, "Unknown event : %d", event);	\
	return "Unknown event";				\
}
const char * fd_pev_str(int event);

/* The data structure for FDEVP_CNX_INCOMING events */
struct cnx_incoming {
	struct msg	* cer;		/* the CER message received on this connection */
	struct cnxctx	* cnx;		/* The connection context */
	int  		  validate;	/* The peer is new, it must be validated (by an extension) or error CEA to be sent */
};


/* Functions */
int  fd_peer_fini();
void fd_peer_dump_list(int details);
void fd_peer_dump(struct fd_peer * peer, int details);
int  fd_peer_alloc(struct fd_peer ** ptr);
int  fd_peer_free(struct fd_peer ** ptr);
int fd_peer_handle_newCER( struct msg ** cer, struct cnxctx ** cnx );
/* fd_peer_add declared in freeDiameter.h */
int fd_peer_validate( struct fd_peer * peer );
void fd_peer_failover_msg(struct fd_peer * peer);

/* Peer expiry */
int fd_p_expi_init(void);
int fd_p_expi_fini(void);
int fd_p_expi_update(struct fd_peer * peer );

/* Peer state machine */
int  fd_psm_start();
int  fd_psm_begin(struct fd_peer * peer );
int  fd_psm_terminate(struct fd_peer * peer );
void fd_psm_abord(struct fd_peer * peer );

/* Peer out */
int fd_out_send(struct msg ** msg, struct cnxctx * cnx, struct fd_peer * peer);
int fd_out_start(struct fd_peer * peer);
int fd_out_stop(struct fd_peer * peer);

/* Peer sent requests cache */
int fd_p_sr_store(struct sr_list * srlist, struct msg **req, uint32_t *hbhloc);
int fd_p_sr_fetch(struct sr_list * srlist, uint32_t hbh, struct msg **req);
void fd_p_sr_failover(struct sr_list * srlist);

/* Capabilities Exchange */
int fd_p_ce_merge(struct fd_peer * peer, struct msg * cer);

/* Active peers -- routing process should only ever take the read lock, the write lock is managed by PSMs */
extern struct fd_list fd_g_activ_peers;
extern pthread_rwlock_t fd_g_activ_peers_rw; /* protect the list */


/* Server sockets */
void fd_servers_dump();
int  fd_servers_start();
int  fd_servers_stop();

/* Connection contexts -- there are also definitions in cnxctx.h for the relevant files */
struct cnxctx * fd_cnx_serv_tcp(uint16_t port, int family, struct fd_endpoint * ep);
struct cnxctx * fd_cnx_serv_sctp(uint16_t port, struct fd_list * ep_list);
int             fd_cnx_serv_listen(struct cnxctx * conn);
struct cnxctx * fd_cnx_serv_accept(struct cnxctx * serv);
struct cnxctx * fd_cnx_cli_connect_tcp(sSA * sa, socklen_t addrlen);
struct cnxctx * fd_cnx_cli_connect_sctp(int no_ip6, uint16_t port, struct fd_list * list);
int             fd_cnx_start_clear(struct cnxctx * conn, int loop);
void		fd_cnx_sethostname(struct cnxctx * conn, char * hn);
int             fd_cnx_handshake(struct cnxctx * conn, int mode, char * priority, void * alt_creds);
char *          fd_cnx_getid(struct cnxctx * conn);
int		fd_cnx_getproto(struct cnxctx * conn);
int		fd_cnx_getTLS(struct cnxctx * conn);
int             fd_cnx_getcred(struct cnxctx * conn, const gnutls_datum_t **cert_list, unsigned int *cert_list_size);
int             fd_cnx_getendpoints(struct cnxctx * conn, struct fd_list * local, struct fd_list * remote);
char *          fd_cnx_getremoteid(struct cnxctx * conn);
int             fd_cnx_receive(struct cnxctx * conn, struct timespec * timeout, unsigned char **buf, size_t * len);
int             fd_cnx_recv_setaltfifo(struct cnxctx * conn, struct fifo * alt_fifo); /* send FDEVP_CNX_MSG_RECV event to the fifo list */
int             fd_cnx_send(struct cnxctx * conn, unsigned char * buf, size_t len);
void            fd_cnx_destroy(struct cnxctx * conn);


#endif /* _FD_H */
