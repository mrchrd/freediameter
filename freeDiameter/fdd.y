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

/* Yacc configuration parser.
 *
 * This file defines the grammar of the configuration file.
 * Note that each extension has a separate independant configuration file.
 *
 * Note : This module is NOT thread-safe. All processing must be done from one thread only.
 */

/* For development only : */
%debug 
%error-verbose

%parse-param {struct fd_config * conf}

/* Keep track of location */
%locations 
%pure-parser

%{
#include "fD.h"
#include "fdd.tab.h"	/* bug : bison does not define the YYLTYPE before including this bloc, so... */

/* The Lex parser prototype */
int fddlex(YYSTYPE *lvalp, YYLTYPE *llocp);

/* Function to report error */
void yyerror (YYLTYPE *ploc, struct fd_config * conf, char const *s)
{
	if (ploc->first_line != ploc->last_line)
		fprintf(stderr, "%s:%d.%d-%d.%d : %s\n", conf->cnf_file, ploc->first_line, ploc->first_column, ploc->last_line, ploc->last_column, s);
	else if (ploc->first_column != ploc->last_column)
		fprintf(stderr, "%s:%d.%d-%d : %s\n", conf->cnf_file, ploc->first_line, ploc->first_column, ploc->last_column, s);
	else
		fprintf(stderr, "%s:%d.%d : %s\n", conf->cnf_file, ploc->first_line, ploc->first_column, s);
}

int got_peer_noip = 0;
int got_peer_noipv6 = 0;
int got_peer_notcp = 0;
int got_peer_nosctp = 0;

struct peer_info fddpi;

%}

/* Values returned by lex for token */
%union {
	char 		 *string;	/* The string is allocated by strdup in lex.*/
	int		  integer;	/* Store integer values */
}

/* In case of error in the lexical analysis */
%token 		LEX_ERROR

%token <string>	QSTRING
%token <integer> INTEGER

%type <string> 	extconf

%token		IDENTITY
%token		REALM
%token		PORT
%token		SECPORT
%token		NOIP
%token		NOIP6
%token		NOTCP
%token		NOSCTP
%token		PREFERTCP
%token		OLDTLS
%token		NOTLS
%token		SCTPSTREAMS
%token		LISTENON
%token		TCTIMER
%token		TWTIMER
%token		NORELAY
%token		LOADEXT
%token		CONNPEER
%token		CONNTO
%token		TLS_CRED
%token		TLS_CA
%token		TLS_CRL
%token		TLS_PRIO
%token		TLS_DH_BITS


/* -------------------------------------- */
%%

	/* The grammar definition - Sections blocs. */
conffile:		/* Empty is OK -- for simplicity here, we reject in daemon later */
			| conffile identity
			| conffile realm
			| conffile tctimer
			| conffile twtimer
			| conffile port
			| conffile secport
			| conffile sctpstreams
			| conffile listenon
			| conffile norelay
			| conffile noip
			| conffile noip6
			| conffile notcp
			| conffile nosctp
			| conffile prefertcp
			| conffile oldtls
			| conffile loadext
			| conffile connpeer
			| conffile tls_cred
			| conffile tls_ca
			| conffile tls_crl
			| conffile tls_prio
			| conffile tls_dh
			| conffile errors
			{
				yyerror(&yylloc, conf, "An error occurred while parsing the configuration file");
				return EINVAL;
			}
			;

			/* Lexical or syntax error */
errors:			LEX_ERROR
			| error
			;

identity:		IDENTITY '=' QSTRING ';'
			{
				conf->cnf_diamid = $3;
			}
			;

realm:			REALM '=' QSTRING ';'
			{
				conf->cnf_diamrlm = $3;
			}
			;

tctimer:		TCTIMER '=' INTEGER ';'
			{
				CHECK_PARAMS_DO( ($3 > 0),
					{ yyerror (&yylloc, conf, "Invalid value"); YYERROR; } );
				conf->cnf_timer_tc = (unsigned int)$3;
			}
			;

twtimer:		TWTIMER '=' INTEGER ';'
			{
				CHECK_PARAMS_DO( ($3 > 5),
					{ yyerror (&yylloc, conf, "Invalid value"); YYERROR; } );
				conf->cnf_timer_tw = (unsigned int)$3;
			}
			;

port:			PORT '=' INTEGER ';'
			{
				CHECK_PARAMS_DO( ($3 > 0) && ($3 < 1<<16),
					{ yyerror (&yylloc, conf, "Invalid value"); YYERROR; } );
				conf->cnf_port = (uint16_t)$3;
			}
			;

secport:		SECPORT '=' INTEGER ';'
			{
				CHECK_PARAMS_DO( ($3 > 0) && ($3 < 1<<16),
					{ yyerror (&yylloc, conf, "Invalid value"); YYERROR; } );
				conf->cnf_port_tls = (uint16_t)$3;
			}
			;

sctpstreams:		SCTPSTREAMS '=' INTEGER ';'
			{
				CHECK_PARAMS_DO( ($3 > 0) && ($3 < 1<<16),
					{ yyerror (&yylloc, conf, "Invalid value"); YYERROR; } );
				conf->cnf_sctp_str = (uint16_t)$3;
			}
			;

listenon:		LISTENON '=' QSTRING ';'
			{
				struct fd_endpoint * ep;
				struct addrinfo hints, *ai;
				int ret;
				
				CHECK_MALLOC_DO( ep = malloc(sizeof(struct fd_endpoint)),
					{ yyerror (&yylloc, conf, "Out of memory"); YYERROR; } );
				memset(ep, 0, sizeof(struct fd_endpoint));
				fd_list_init(&ep->chain, NULL);
				ep->meta.conf = 1;
				
				memset(&hints, 0, sizeof(hints));
				hints.ai_flags = AI_PASSIVE | AI_NUMERICHOST;
				ret = getaddrinfo($3, NULL, &hints, &ai);
				if (ret) { yyerror (&yylloc, conf, gai_strerror(ret)); free(ep); YYERROR; }
				ASSERT( ai->ai_addrlen <= sizeof(sSS) );
				memcpy(&ep->ss, ai->ai_addr, ai->ai_addrlen);
				free($3);
				freeaddrinfo(ai);
				fd_list_insert_before(&conf->cnf_endpoints, &ep->chain);
			}
			;

norelay:		NORELAY ';'
			{
				conf->cnf_flags.no_fwd = 1;
			}
			;

noip:			NOIP ';'
			{
				if (got_peer_noipv6) { 
					yyerror (&yylloc, conf, "No_IP conflicts with a ConnectPeer directive No_IPv6."); 
					YYERROR; 
				}
				conf->cnf_flags.no_ip4 = 1;
			}
			;

noip6:			NOIP6 ';'
			{
				if (got_peer_noip) { 
					yyerror (&yylloc, conf, "No_IP conflicts with a ConnectPeer directive No_IP."); 
					YYERROR; 
				}
				conf->cnf_flags.no_ip6 = 1;
			}
			;

notcp:			NOTCP ';'
			{
				#ifdef DISABLE_SCTP
				yyerror (&yylloc, conf, "No_TCP cannot be specified for daemon compiled with DISABLE_SCTP option."); 
				YYERROR; 
				#endif
				if (conf->cnf_flags.no_sctp)
				{
					yyerror (&yylloc, conf, "No_TCP conflicts with No_SCTP directive." ); 
					YYERROR; 
				}
				if (got_peer_nosctp) { 
					yyerror (&yylloc, conf, "No_TCP conflicts with a ConnectPeer directive No_SCTP."); 
					YYERROR; 
				}
				conf->cnf_flags.no_tcp = 1;
			}
			;

nosctp:			NOSCTP ';'
			{
				if (conf->cnf_flags.no_tcp)
				{
					yyerror (&yylloc, conf, "No_SCTP conflicts with No_TCP directive." ); 
					YYERROR; 
				}
				if (got_peer_notcp) { 
					yyerror (&yylloc, conf, "No_SCTP conflicts with a ConnectPeer directive No_TCP.");
					YYERROR;
				}
				conf->cnf_flags.no_sctp = 1;
			}
			;

prefertcp:		PREFERTCP ';'
			{
				conf->cnf_flags.pr_tcp = 1;
			}
			;

oldtls:			OLDTLS ';'
			{
				conf->cnf_flags.tls_alg = 1;
			}
			;

loadext:		LOADEXT '=' QSTRING extconf ';'
			{
				CHECK_FCT_DO( fd_ext_add( $3, $4 ),
					{ yyerror (&yylloc, conf, "Error adding extension"); YYERROR; } );
			}
			;
			
extconf:		/* empty */
			{
				$$ = NULL;
			}
			| ':' QSTRING
			{
				$$ = $2;
			}
			;
			
connpeer:		{
				memset(&fddpi, 0, sizeof(fddpi));
				fd_list_init( &fddpi.pi_endpoints, NULL );
				fd_list_init( &fddpi.pi_apps, NULL );
			}
			CONNPEER '=' QSTRING peerinfo ';'
			{
				fddpi.pi_diamid = $4;
				CHECK_FCT_DO( fd_peer_add ( &fddpi, conf->cnf_file, NULL, NULL ),
					{ yyerror (&yylloc, conf, "Error adding ConnectPeer information"); YYERROR; } );
					
				/* Now destroy any content in the structure */
				free(fddpi.pi_diamid);
				while (!FD_IS_LIST_EMPTY(&fddpi.pi_endpoints)) {
					struct fd_list * li = fddpi.pi_endpoints.next;
					fd_list_unlink(li);
					free(li);
				}
			}
			;
			
peerinfo:		/* empty */
			| '{' peerparams '}'
			;
			
peerparams:		/* empty */
			| peerparams NOIP ';'
			{
				if ((conf->cnf_flags.no_ip6) || (fddpi.pi_flags.pro3 == PI_P3_IP)) { 
					yyerror (&yylloc, conf, "No_IP conflicts with a No_IPv6 directive.");
					YYERROR;
				}
				got_peer_noip++;
				fddpi.pi_flags.pro3 = PI_P3_IPv6;
			}
			| peerparams NOIP6 ';'
			{
				if ((conf->cnf_flags.no_ip4) || (fddpi.pi_flags.pro3 == PI_P3_IPv6)) { 
					yyerror (&yylloc, conf, "No_IPv6 conflicts with a No_IP directive.");
					YYERROR;
				}
				got_peer_noipv6++;
				fddpi.pi_flags.pro3 = PI_P3_IP;
			}
			| peerparams NOTCP ';'
			{
				#ifdef DISABLE_SCTP
					yyerror (&yylloc, conf, "No_TCP cannot be specified in daemon compiled with DISABLE_SCTP option.");
					YYERROR;
				#endif
				if ((conf->cnf_flags.no_sctp) || (fddpi.pi_flags.pro4 == PI_P4_TCP)) { 
					yyerror (&yylloc, conf, "No_TCP conflicts with a No_SCTP directive.");
					YYERROR;
				}
				got_peer_notcp++;
				fddpi.pi_flags.pro4 = PI_P4_SCTP;
			}
			| peerparams NOSCTP ';'
			{
				if ((conf->cnf_flags.no_tcp) || (fddpi.pi_flags.pro4 == PI_P4_SCTP)) { 
					yyerror (&yylloc, conf, "No_SCTP conflicts with a No_TCP directive.");
					YYERROR;
				}
				got_peer_nosctp++;
				fddpi.pi_flags.pro4 = PI_P4_TCP;
			}
			| peerparams PREFERTCP ';'
			{
				fddpi.pi_flags.alg = PI_ALGPREF_TCP;
			}
			| peerparams OLDTLS ';'
			{
				if (fddpi.pi_flags.sec == PI_SEC_NONE) { 
					yyerror (&yylloc, conf, "ConnectPeer: TLS_old_method conflicts with No_TLS.");
					YYERROR;
				}
				fddpi.pi_flags.sec = PI_SEC_TLS_OLD;
			}
			| peerparams NOTLS ';'
			{
				if (fddpi.pi_flags.sec == PI_SEC_TLS_OLD) { 
					yyerror (&yylloc, conf, "ConnectPeer: No_TLS conflicts with TLS_old_method.");
					YYERROR;
				}
				fddpi.pi_flags.sec = PI_SEC_NONE;
			}
			| peerparams PORT '=' INTEGER ';'
			{
				CHECK_PARAMS_DO( ($4 > 0) && ($4 < 1<<16),
					{ yyerror (&yylloc, conf, "Invalid value"); YYERROR; } );
				fddpi.pi_port = (uint16_t)$4;
			}
			| peerparams SCTPSTREAMS '=' INTEGER ';'
			{
				CHECK_PARAMS_DO( ($4 > 0) && ($4 < 1<<16),
					{ yyerror (&yylloc, conf, "Invalid value"); YYERROR; } );
				fddpi.pi_streams = (uint16_t)$4;
			}
			| peerparams TCTIMER '=' INTEGER ';'
			{
				fddpi.pi_tctimer = $4;
			}
			| peerparams TWTIMER '=' INTEGER ';'
			{
				fddpi.pi_twtimer = $4;
			}
			| peerparams CONNTO '=' QSTRING ';'
			{
				struct fd_endpoint * ep;
				struct addrinfo hints, *ai;
				int ret;
				
				CHECK_MALLOC_DO( ep = malloc(sizeof(struct fd_endpoint)),
					{ yyerror (&yylloc, conf, "Out of memory"); YYERROR; } );
				memset(ep, 0, sizeof(struct fd_endpoint));
				fd_list_init(&ep->chain, NULL);
				ep->meta.conf = 1;
				memset(&hints, 0, sizeof(hints));
				hints.ai_flags = AI_ADDRCONFIG | AI_NUMERICHOST;
				ret = getaddrinfo($4, NULL, &hints, &ai);
				if (ret == EAI_NONAME) {
					/* The name was maybe not numeric, try again */
					ep->meta.disc = 1;
					hints.ai_flags &= ~ AI_NUMERICHOST;
					ret = getaddrinfo($4, NULL, &hints, &ai);
				}
				if (ret) { yyerror (&yylloc, conf, gai_strerror(ret)); free(ep); YYERROR; }
				
				memcpy(&ep->ss, ai->ai_addr, ai->ai_addrlen);
				free($4);
				freeaddrinfo(ai);
				fd_list_insert_before(&fddpi.pi_endpoints, &ep->chain);
			}
			;

tls_cred:		TLS_CRED '=' QSTRING ',' QSTRING ';'
			{
				conf->cnf_sec_data.cert_file = $3;
				conf->cnf_sec_data.key_file = $5;
				
				CHECK_GNUTLS_DO( gnutls_certificate_set_x509_key_file( 
							conf->cnf_sec_data.credentials,
							conf->cnf_sec_data.cert_file,
							conf->cnf_sec_data.key_file,
							GNUTLS_X509_FMT_PEM),
						{ yyerror (&yylloc, conf, "Error opening certificate or private key file."); YYERROR; } );
			}
			;

tls_ca:			TLS_CA '=' QSTRING ';'
			{
				conf->cnf_sec_data.ca_file = $3;
				CHECK_GNUTLS_DO( gnutls_certificate_set_x509_trust_file( 
							conf->cnf_sec_data.credentials,
							conf->cnf_sec_data.ca_file,
							GNUTLS_X509_FMT_PEM),
						{ yyerror (&yylloc, conf, "Error setting CA parameters."); YYERROR; } );
			}
			;
			
tls_crl:		TLS_CRL '=' QSTRING ';'
			{
				conf->cnf_sec_data.crl_file = $3;
				CHECK_GNUTLS_DO( gnutls_certificate_set_x509_crl_file( 
							conf->cnf_sec_data.credentials,
							conf->cnf_sec_data.ca_file,
							GNUTLS_X509_FMT_PEM),
						{ yyerror (&yylloc, conf, "Error setting CRL parameters."); YYERROR; } );
			}
			;
			
tls_prio:		TLS_PRIO '=' QSTRING ';'
			{
				const char * err_pos = NULL;
				conf->cnf_sec_data.prio_string = $3;
				CHECK_GNUTLS_DO( gnutls_priority_init( 
							&conf->cnf_sec_data.prio_cache,
							conf->cnf_sec_data.prio_string,
							&err_pos),
						{ yyerror (&yylloc, conf, "Error setting Priority parameter.");
						  fprintf(stderr, "Error at position : %s\n", err_pos);
						  YYERROR; } );
			}
			;
			
tls_dh:			TLS_DH_BITS '=' INTEGER ';'
			{
				conf->cnf_sec_data.dh_bits = $3;
				TRACE_DEBUG(FULL, "Generating DH parameters...");
				CHECK_GNUTLS_DO( gnutls_dh_params_generate2( 
							conf->cnf_sec_data.dh_cache,
							conf->cnf_sec_data.dh_bits),
						{ yyerror (&yylloc, conf, "Error setting DH Bits parameters."); 
						 YYERROR; } );
				TRACE_DEBUG(FULL, "DH parameters generated.");
			}
			;
