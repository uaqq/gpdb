#ifndef PALLOC_OVERRIDE_UNDEF_H
#define PALLOC_OVERRIDE_UNDEF_H

#undef MemoryContextAlloc
#undef MemoryContextAllocZero
#undef MemoryContextAllocZeroAligned

#undef palloc
#undef palloc0
#undef repalloc

#undef MemoryContextAllocHuge
#undef repalloc_huge

#undef MemoryContextStrdup
#undef pstrdup
#undef pnstrdup

#undef psprintf

#endif
