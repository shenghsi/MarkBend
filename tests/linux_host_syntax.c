#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

typedef uint64_t u64;
typedef uint32_t u32;
typedef uint64_t Term;
typedef struct { void* memory; } Env;
typedef struct { int unused; } IoWork;
typedef Term (*Effect)(Env, Term*, IoWork*);

#define CID(name) 1
#define Unit Unit

Term io_hand(intptr_t value);
intptr_t io_hand_v(Term value);
char* io_cstr(Env environment, Term value, u64* length);
Term io_box(Env environment, u64 constructor, Term value);
Term io_str(Env environment, const char* text, u64 length);
Term io_tup(Env environment, Term first, Term second);
Term term_pak(u64 constructor, u64 location);
void io_eff(u64 effect, Effect run, int need);
void err_fail(const char* message);

#include "../live_paragraph.c"
