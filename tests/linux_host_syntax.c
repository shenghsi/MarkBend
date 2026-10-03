#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

typedef uint64_t u64;
typedef uint32_t u32;
typedef uint64_t Term;
typedef struct { Term* mem; } Env;
typedef struct { int unused; } IoWork;
typedef Term (*Effect)(Env, Term*, IoWork*);

#define CID(name) 1
#define MARKBEND_HOST_ALL_EFFECTS 1
#define Unit Unit

Term io_hand(intptr_t value);
intptr_t io_hand_v(Term value);
char* io_cstr(Env environment, Term value, u64* length);
Term io_box(Env environment, u64 constructor, Term value);
Term io_node(Env environment, u64 constructor, Term first, Term second);
Term io_str(Env environment, const char* text, u64 length);
Term io_tup(Env environment, Term first, Term second);
Term term_pak(u64 constructor, u64 location);
Term term_ctr(u64 constructor, u64 location);
u64 heap_alloc(Env environment, u64 size_class);
Term io_seal(Env environment, Term value, u64 constructor);
void io_eff(u64 effect, Effect run, int need);
void err_fail(const char* message);
u64 term_aux(Term value);
u64 cls_fit(u64 fields);
u64 ctr_take(Env environment, Term value, u32 fields, Term* output);
void spare_free(Env environment, u64 size_class, u64 location);
void term_sink(Env environment, Term value);

#include "../src/live_paragraph.c"
