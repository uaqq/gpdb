#include "postgres_fe.h"

#include "common/file_perm.h"
#include "common/logging.h"
#include "access/xlog_internal.h"
#include "getopt_long.h"

#include "receivelog.h"
#include "streamutil.h"


/* Global options */
static volatile bool time_to_stop = false;
static char *basedir = NULL;
static int	verbose = 0;
static int	compresslevel = 0;
static char *replication_slot = NULL;
static int	tid = 1;
static XLogRecPtr lsnpos = InvalidXLogRecPtr;
static int	standby_message_timeout = 10 * 1000;	/* 10 sec = default */

static void usage(void);
static void StreamLog(void);
static bool stop_streaming(XLogRecPtr segendpos, uint32 timeline,
						   bool segment_finished);


static void
disconnect_atexit(void)
{
	if (conn != NULL)
		PQfinish(conn);
}


static void
usage(void)
{
	printf(_("%s receives Greenplum instance streaming write-ahead logs.\n\n"),
		   progname);
	printf(_("Usage:\n"));
	printf(_("  %s [OPTION]...\n"), progname);
	printf(_("\nOptions:\n"));
	printf(_("  -D, --directory=DIR    receive write-ahead log files into this directory\n"));
	printf(_("  -L, --lsnpos=LSN       start position for streaming LSN\n"));
	printf(_("  -s, --status-interval=SECS\n"
			 "                         time between status packets sent to server (default: %d)\n"), (standby_message_timeout / 1000));
	printf(_("  -S, --slot=SLOTNAME    replication slot to use\n"));
	printf(_("  -T, --timeline=TID     timelineID for streaming LSN\n"));
	printf(_("  -v, --verbose          output verbose messages\n"));
	printf(_("  -V, --version          output version information, then exit\n"));
	printf(_("  -Z, --compress=0-9     compress logs with given compression level\n"));
	printf(_("  -?, --help             show this help, then exit\n"));
	printf(_("\nConnection options:\n"));
	printf(_("  -d, --dbname=CONNSTR   connection string\n"));
	printf(_("  -h, --host=HOSTNAME    database server host or socket directory\n"));
	printf(_("  -p, --port=PORT        database server port number\n"));
	printf(_("  -U, --username=NAME    connect as specified database user\n"));
	printf(_("  -w, --no-password      never prompt for password\n"));
	printf(_("  -W, --password         force password prompt (should happen automatically)\n"));
}

/*
 * When sigint is called, just tell the system to exit at the next possible
 * moment.
 */
#ifndef WIN32

static void
sigint_handler(int signum)
{
	time_to_stop = true;
}
#endif


static bool
stop_streaming(XLogRecPtr xlogpos, uint32 timeline, bool segment_finished)
{
	static uint32 prevtimeline = 0;
	static XLogRecPtr prevpos = InvalidXLogRecPtr;

	/* we assume that we get called once at the end of each segment */
	if (segment_finished)
		pg_log_info("finished segment at %X/%X (timeline %u)",
					(uint32) (xlogpos >> 32), (uint32) xlogpos,
					timeline);
	
	if (verbose && prevtimeline != 0 && prevtimeline != timeline)
		pg_log_info("switched to timeline %u at %X/%X",
					timeline,
					(uint32) (prevpos >> 32), (uint32) prevpos);

	prevtimeline = timeline;
	prevpos = xlogpos;

	if (time_to_stop)
	{
		if (verbose)
			pg_log_info("received interrupt signal, exiting");
		return true;
	}
	return false;
}


/*
 * Start the log streaming
 */
static void
StreamLog(void)
{
	StreamCtl stream;

	MemSet(&stream, 0, sizeof(stream));

	/*
	 * Connect in replication mode to the server
	 */
	if (conn == NULL)
		conn = GetConnection();
	if (!conn)
		/* Error message already written in GetConnection() */
		return;

	if (!CheckServerVersionForStreaming(conn))
	{
		/*
		 * Error message already written in CheckServerVersionForStreaming().
		 * There's no hope of recovering from a version mismatch, so don't
		 * retry.
		 */
		exit(1);
	}

	/* Always start streaming at the beginning of a segment */
	stream.startpos = lsnpos;
	stream.timeline = tid;


	pg_log_info("starting log streaming at %X/%X (timeline %u)",
			(uint32) (stream.startpos >> 32), (uint32) stream.startpos,
			stream.timeline);

	stream.stream_stop = stop_streaming;
	stream.stop_socket = PGINVALID_SOCKET;		/* TODO: add a valid socket to handle FTS packets */
	stream.standby_message_timeout = standby_message_timeout;
	stream.synchronous = true;
	stream.do_sync = true;
	stream.mark_done = false;
	stream.walmethod = CreateWalDirectoryMethod(basedir, compresslevel,
												stream.do_sync);
	stream.partial_suffix = ".partial";
	stream.replication_slot = replication_slot;

	ReceiveXlogStream(conn, &stream);

	if (!stream.walmethod->finish())
	{
		pg_log_info("could not finish writing WAL files: %m");
		return;
	}

	PQfinish(conn);
	conn = NULL;

	FreeWalDirectoryMethod();
	pg_free(stream.walmethod);

	conn = NULL;
}


int
main(int argc, char **argv)
{
	static struct option long_options[] = {
		{"help", no_argument, NULL, '?'},
		{"version", no_argument, NULL, 'V'},
		{"directory", required_argument, NULL, 'D'},
		{"dbname", required_argument, NULL, 'd'},
		{"timeline", required_argument, NULL, 'T'},
		{"lsnpos", required_argument, NULL, 'L'},
		{"host", required_argument, NULL, 'h'},
		{"port", required_argument, NULL, 'p'},
		{"username", required_argument, NULL, 'U'},
		{"no-password", no_argument, NULL, 'w'},
		{"password", no_argument, NULL, 'W'},
		{"status-interval", required_argument, NULL, 's'},
		{"slot", required_argument, NULL, 'S'},
		{"verbose", no_argument, NULL, 'v'},
		{"compress", required_argument, NULL, 'Z'},
		/* action */
		{NULL, 0, NULL, 0}
	};

	int	c;
	int	option_index;
	char	*db_name;
	uint32	hi;
	uint32	lo;


	pg_logging_init(argv[0]);
	progname = get_progname(argv[0]);
	set_pglocale_pgservice(argv[0], PG_TEXTDOMAIN("pg_basebackup"));

	if (argc > 1)
	{
		if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-?") == 0)
		{
			usage();
			exit(0);
		}
		else if (strcmp(argv[1], "-V") == 0 ||
				 strcmp(argv[1], "--version") == 0)
		{
			puts("gp_receivewal (Greenplum) " PACKAGE_VERSION);
			exit(0);
		}
	}

	while ((c = getopt_long(argc, argv, "D:d:T:L:h:p:U:s:S:wWvZ:",
							long_options, &option_index)) != -1)
	{
		switch (c)
		{
			case 'D':
				basedir = pg_strdup(optarg);
				if (basedir == NULL)
				{
					pg_log_error("no target directory specified");
					exit(1);
				}
				break;
			case 'd':
				connection_string = pg_strdup(optarg);
				break;
			case 'h':
				dbhost = pg_strdup(optarg);
				break;
			case 'p':
				if (atoi(optarg) <= 0)
				{
					pg_log_error("invalid port number \"%s\"", optarg);
					exit(1);
				}
				dbport = pg_strdup(optarg);
				break;
			case 'U':
				dbuser = pg_strdup(optarg);
				break;
			case 'w':
				dbgetpassword = -1;
				break;
			case 'W':
				dbgetpassword = 1;
				break;
			case 's':
				standby_message_timeout = atoi(optarg) * 1000;
				if (standby_message_timeout < 0)
				{
					pg_log_error("invalid status interval \"%s\"", optarg);
					exit(1);
				}
				break;
			case 'S':
				replication_slot = pg_strdup(optarg);
				break;
			case 'L':
				if (sscanf(optarg, "%X/%X", &hi, &lo) != 2)
				{
					pg_log_error("could not parse end position \"%s\"", optarg);
					exit(1);
				}
				lsnpos = ((uint64) hi) << 32 | lo;
				break;
			case 'T':
				tid = atoi(optarg);
				if (tid < 1)
				{
					pg_log_error("invalid timeline ID \"%s\"", optarg);
					exit(1);
				}
				break;
			case 'v':
				verbose++;
				break;
			case 'Z':
				compresslevel = atoi(optarg);
				if (compresslevel < 0 || compresslevel > 9)
				{
					pg_log_error("invalid compression level \"%s\"", optarg);
					exit(1);
				}
				break;
			default:
				/*
				 * getopt_long already emitted a complaint
				 */
				fprintf(stderr, _("Try \"%s --help\" for more information.\n"),
						progname);
				exit(1);
		}
	}

	/*
	 * Any non-option arguments?
	 */
	if (optind < argc)
	{
		pg_log_error("too many command-line arguments (first is \"%s\")",
					 argv[optind]);
		fprintf(stderr, _("Try \"%s --help\" for more information.\n"),
				progname);
		exit(1);
	}

#ifndef WIN32
	pqsignal(SIGINT, sigint_handler);
#endif

	/*
	 * Obtain a connection before doing anything.
	 */
	conn = GetConnection();
	if (!conn)
		/* error message already written in GetConnection() */
		exit(1);
	atexit(disconnect_atexit);

	/*
	 * Run IDENTIFY_SYSTEM to make sure we've successfully have established a
	 * replication connection and haven't connected using a database specific
	 * connection.
	 */
	if (!RunIdentifySystem(conn, NULL, NULL, NULL, &db_name))
		exit(1);

	/*
	 * Set umask so that directories/files are created with the same
	 * permissions as directories/files in the source data directory.
	 *
	 * pg_mode_mask is set to owner-only by default and then updated in
	 * GetConnection() where we get the mode from the server-side with
	 * RetrieveDataDirCreatePerm() and then call SetDataDirectoryCreatePerm().
	 */
	umask(pg_mode_mask);

	/* determine remote server's xlog segment size */
	if (!RetrieveWalSegSize(conn))
		exit(1);

	/*
	 * Check that there is a database associated with connection, none should
	 * be defined in this context.
	 */
	if (db_name)
	{
		pg_log_error("replication connection using slot \"%s\" is unexpectedly database specific",
					 replication_slot);
		exit(1);
	}

	/*
	 * Don't close the connection here so that subsequent StreamLog() can
	 * reuse it.
	 */

	while (true)
	{
		StreamLog();
		if (time_to_stop)
		{
			/*
			 * We've been Ctrl-C'ed or end of streaming position has been
			 * willingly reached, so exit without an error code.
			 */
			exit(0);
		}
		else
		{
			pg_log_error("disconnected");
			exit(1);
		}
	}
}
