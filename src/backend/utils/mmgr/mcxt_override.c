#include "utils/palloc_override_undef.h"

static void
MemoryContextWriteFuncAndLineToAllocedMemory(void *ptr, const char *parent_func,
		const char *exec_func, const char *file, int line)
{
	Assert(parent_func);
	Assert(exec_func);
	Assert(file);
	Assert(line);

	StandardChunkHeader *header = (StandardChunkHeader *)
		((char *) ptr - STANDARDCHUNKHEADERSIZE);

	header->info.key.parent_func = parent_func;
	header->info.key.line = line;
	header->info.exec_func = exec_func;
	header->info.file = file;
	header->info.init = DYNAMIC_MEMORY_DEBUG_INIT_MAGIC;
}

#define MEMORY_CONTEXT_ALLOC_FUNC(__func_name__)                                                 \
void *                                                                                           \
_##__func_name__(MemoryContext context, Size size, const char *func, const char *file, int LINE) \
{                                                                                                \
	void * ret = __func_name__(context, size);                                                   \
                                                                                                 \
	if (ret)                                                                                     \
		MemoryContextWriteFuncAndLineToAllocedMemory(ret, func, #__func_name__, file, LINE);     \
                                                                                                 \
	return ret;                                                                                  \
}

#define MEMORY_CONTEXT_PALLOC_FUNC(__func_name__)                                            \
void *                                                                                       \
_##__func_name__(Size size, const char *func, const char *file, int LINE)                    \
{                                                                                            \
	void * ret = __func_name__(size);                                                        \
                                                                                             \
	if (ret)                                                                                 \
		MemoryContextWriteFuncAndLineToAllocedMemory(ret, func, #__func_name__, file, LINE); \
                                                                                             \
	return ret;                                                                              \
}

#define MEMORY_CONTEXT_REPALLOC_FUNC(__func_name__)                                          \
void *                                                                                       \
_##__func_name__(void *pointer, Size size, const char *func, const char *file, int LINE)     \
{                                                                                            \
	void * ret = __func_name__(pointer, size);                                               \
                                                                                             \
	if (ret)                                                                                 \
		MemoryContextWriteFuncAndLineToAllocedMemory(ret, func, #__func_name__, file, LINE); \
                                                                                             \
	return ret;                                                                              \
}

MEMORY_CONTEXT_ALLOC_FUNC(MemoryContextAlloc)
MEMORY_CONTEXT_ALLOC_FUNC(MemoryContextAllocZero)
MEMORY_CONTEXT_ALLOC_FUNC(MemoryContextAllocZeroAligned)
MEMORY_CONTEXT_ALLOC_FUNC(MemoryContextAllocHuge)

MEMORY_CONTEXT_PALLOC_FUNC(palloc)
MEMORY_CONTEXT_PALLOC_FUNC(palloc0)

MEMORY_CONTEXT_REPALLOC_FUNC(repalloc)
MEMORY_CONTEXT_REPALLOC_FUNC(repalloc_huge)

char *
_MemoryContextStrdup(MemoryContext context, const char *string, const char *func, const char *file, int LINE)
{
	void * ret = MemoryContextStrdup(context, string);

	if (ret)
		MemoryContextWriteFuncAndLineToAllocedMemory(ret, func, __func__, file, LINE);

	return ret;
}

char *
_pstrdup(const char *in, const char *func, const char *file, int LINE)
{
	void * ret = pstrdup(in);

	if (ret)
		MemoryContextWriteFuncAndLineToAllocedMemory(ret, func, __func__, file, LINE);

	return ret;
}

char *
_pnstrdup(const char *in, Size len, const char *func, const char *file, int LINE)
{
	void * ret = pnstrdup(in, len);

	if (ret)
		MemoryContextWriteFuncAndLineToAllocedMemory(ret, func, __func__, file, LINE);

	return ret;
}

