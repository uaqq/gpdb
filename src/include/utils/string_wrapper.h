/*-----------------------------------------------------------------------
 *
 * string_wrapper.h
 *	  Wrappers around string.h functions
 *
 * Portions Copyright (c) 2009, Greenplum Inc.
 * Portions Copyright (c) 2012-Present Pivotal Software, Inc.
 *
 * IDENTIFICATION
 *	  src/include/utils/string_wrapper.h
 *
 *-----------------------------------------------------------------------
 */

#ifndef _UTILS___STRING_WRAPPER_H
#define _UTILS___STRING_WRAPPER_H

#include <string.h>
#include <errno.h>
#include <utils/elog.h>

#define NULL_TO_DUMMY_STR(s) ((s) == NULL ? "<<null>>" : (s))
#define SAFE_STR_LENGTH(s) ((s) == NULL ? 0 : strlen(s))

static inline
int gp_strcoll(const char *left, const char *right)
{
	int result;

	errno = 0;
	result = strcoll(left, right);

	if ( errno != 0 )
	{
		if ( errno == EINVAL || errno == EILSEQ)
		{
			ereport(ERROR,
					(errcode(ERRCODE_UNTRANSLATABLE_CHARACTER),
							errmsg("Unable to compare strings because one or both contained data that is not valid "
							       "for the collation specified by LC_COLLATE ('%s').  First string has length %lu "
							       "and value (limited to 100 characters): '%.100s'.  Second string has length %lu "
							       "and value (limited to 100 characters): '%.100s'",
									GetConfigOption("lc_collate"),
									(unsigned long) SAFE_STR_LENGTH(left),
									NULL_TO_DUMMY_STR(left),
									(unsigned long) SAFE_STR_LENGTH(left),
									NULL_TO_DUMMY_STR(right))));
		}
		else
		{
			ereport(ERROR,
					(errcode(ERRCODE_GP_INTERNAL_ERROR),
							errmsg("Unable to compare strings.  "
							       "Error: %s.  "
							       "First string has length %lu and value (limited to 100 characters): '%.100s'.  "
							       "Second string has length %lu and value (limited to 100 characters): '%.100s'",
									strerror(errno),
									(unsigned long) SAFE_STR_LENGTH(left),
									NULL_TO_DUMMY_STR(left),
									(unsigned long) SAFE_STR_LENGTH(left),
									NULL_TO_DUMMY_STR(right))));
		}
	}

	return result;
}

#endif   /* _UTILS___STRING_WRAPPER_H */
