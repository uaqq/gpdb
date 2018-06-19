#include <stdarg.h>
#include <stddef.h>
#include <setjmp.h>
#include "cmockery.h"
#include "port/pg_crc32c.h"


void
test__crc32_correctness(void **state)
{
    const char data[] = {(char)0x6, (char)0x7, (char)0x9, (char)0x3, (char)0x2};
    const unsigned data_length = 5;
    const unsigned long correct_result = 0x84d9dbc2;

    pg_crc32c result = 0;

    INIT_CRC32C(result);
    COMP_CRC32C(result, data, data_length);
    FIN_CRC32C(result);

    assert_true(EQ_CRC32C(result, correct_result));
}

int
main(int argc, char* argv[])
{
	cmockery_parse_arguments(argc, argv);

	const UnitTest tests[] =
	{
		unit_test(test__crc32_correctness)
	};

	return run_tests(tests);
}
