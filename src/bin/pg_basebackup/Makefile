#-------------------------------------------------------------------------
#
# Makefile for src/bin/pg_basebackup
#
# Portions Copyright (c) 1996-2019, PostgreSQL Global Development Group
# Portions Copyright (c) 1994, Regents of the University of California
#
# src/bin/pg_basebackup/Makefile
#
#-------------------------------------------------------------------------

PGFILEDESC = "pg_basebackup/pg_receivewal/pg_recvlogical - streaming WAL and backup receivers"
PGAPPICON=win32

EXTRA_INSTALL=contrib/test_decoding

subdir = src/bin/pg_basebackup
top_builddir = ../../..
include $(top_builddir)/src/Makefile.global

override CPPFLAGS := -I$(libpq_srcdir) $(CPPFLAGS)
LDFLAGS_INTERNAL += -L$(top_builddir)/src/fe_utils -lpgfeutils $(libpq_pgport)

OBJS=receivelog.o streamutil.o walmethods.o $(WIN32RES)

all: gp_receivewal pg_basebackup pg_receivewal pg_recvlogical

gp_receivewal: gp_receivewal.o $(OBJS) | submake-libpq submake-libpgport submake-libpgfeutils
	$(CC) $(CFLAGS) gp_receivewal.o $(OBJS) $(LDFLAGS) $(LDFLAGS_EX) $(LIBS) -o $@$(X)

pg_basebackup: pg_basebackup.o $(OBJS) | submake-libpq submake-libpgport submake-libpgfeutils
	$(CC) $(CFLAGS) pg_basebackup.o $(OBJS) $(LDFLAGS) $(LDFLAGS_EX) $(LIBS) -o $@$(X)

pg_receivewal: pg_receivewal.o $(OBJS) | submake-libpq submake-libpgport submake-libpgfeutils
	$(CC) $(CFLAGS) pg_receivewal.o $(OBJS) $(LDFLAGS) $(LDFLAGS_EX) $(LIBS) -o $@$(X)

pg_recvlogical: pg_recvlogical.o $(OBJS) | submake-libpq submake-libpgport submake-libpgfeutils
	$(CC) $(CFLAGS) pg_recvlogical.o $(OBJS) $(LDFLAGS) $(LDFLAGS_EX) $(LIBS) -o $@$(X)

install: all installdirs
	$(INSTALL_PROGRAM) gp_receivewal$(X) '$(DESTDIR)$(bindir)/gp_receivewal$(X)'
	$(INSTALL_PROGRAM) pg_basebackup$(X) '$(DESTDIR)$(bindir)/pg_basebackup$(X)'
	$(INSTALL_PROGRAM) pg_receivewal$(X) '$(DESTDIR)$(bindir)/pg_receivewal$(X)'
	$(INSTALL_PROGRAM) pg_recvlogical$(X) '$(DESTDIR)$(bindir)/pg_recvlogical$(X)'

installdirs:
	$(MKDIR_P) '$(DESTDIR)$(bindir)'

uninstall:
	rm -f '$(DESTDIR)$(bindir)/gp_receivewal$(X)'
	rm -f '$(DESTDIR)$(bindir)/pg_basebackup$(X)'
	rm -f '$(DESTDIR)$(bindir)/pg_receivewal$(X)'
	rm -f '$(DESTDIR)$(bindir)/pg_recvlogical$(X)'

clean distclean maintainer-clean:
	rm -f gp_receivewal$(X) pg_basebackup$(X) pg_receivewal$(X) pg_recvlogical$(X) \
		gp_receivewal.o pg_basebackup.o pg_receivewal.o pg_recvlogical.o \
		$(OBJS)
	rm -rf tmp_check

check:
	$(prove_check)

installcheck:
	$(prove_installcheck)

