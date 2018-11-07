#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <ctype.h>
#include <stdint.h>
#include <iconv.h>  

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#include "khash.h"

#define PHASE_SEARCH 0
#define PHASE_MATCH 1

struct word_tree;

KHASH_MAP_INIT_STR(word,struct word_tree*);

struct word_tree {
	khash_t(word)* hash;
	uint8_t tail;
};

static inline int
split_utf8(const char* word,size_t size,int offset) {
	int i;
	for(i = offset;i < size;i++) {
		char ch = word[i];
		if((ch & 0x80) == 0) {  
            return 1;
        } else if((ch & 0xFC) == 0xFC) {  
        	return 6;
        } else if((ch & 0xF8) == 0xF8) {  
            return 5;  
        } else if((ch & 0xF0) == 0xF0) {  
            return 4;  
        } else if((ch & 0xE0) == 0xE0) {  
            return 3;  
        } else if((ch & 0xC0) == 0xC0) {  
            return 2;  
        }  
	}
	assert(0);
}

void
word_add(struct word_tree* root_tree, const char* word,size_t size) {
	struct word_tree* tree = root_tree;
	int i;
	for(i = 0;i < size;) {
		char ch[8] = {0};
		int length = split_utf8(word,size,i);
		memcpy(ch,&word[i],length);
		i += length;

		khiter_t k = kh_get(word, tree->hash, ch);
		if (k == kh_end(tree->hash)) {
			struct word_tree* next_tree = NULL;
			int result;
			khiter_t k = kh_put(word, tree->hash, strdup(ch), &result);
			if (result == 1 || result == 2) {
				next_tree = malloc(sizeof(*next_tree));
				next_tree->tail = 0;
				next_tree->hash = kh_init(word);
				kh_value(tree->hash, k) = next_tree;
			}else {
				assert(0);
			}
			
			if (i == size)
				next_tree->tail = 1;
			tree = next_tree;
		} else {
			tree = kh_value(tree->hash, k);
			if (i == size)
				tree->tail = 1;
		}
	}
}

void
word_delete(struct word_tree* root_tree, const char* word,size_t size) {
	struct word_tree* tree = root_tree;
	int i;
	for(i = 0;i < size;) {
		char ch[8] = {0};
		int length = split_utf8(word,size,i);
		memcpy(ch,&word[i],length);
		i += length;

		khiter_t k = kh_get(word, tree->hash, ch);
		if (k != kh_end(tree->hash)) {
			tree = kh_value(tree->hash, k);
		} else {
			return;
		}
	}
	tree->tail = 0;
}

typedef struct replace_context {
	char* replace;
	int offset;
	int size;
} replace_ctx_t;

static inline int
replace_commit(replace_ctx_t* ctx, char* data, int size) {
	int left = ctx->size - ctx->offset;
	if (left <= 0) {
		return -1;
	}

	if ( left > size ) {
		memcpy(ctx->replace + ctx->offset, data, size);
		ctx->offset += size;
		return 0;
	}
	memcpy(ctx->replace + ctx->offset, data, left);
	ctx->offset += left;
	return -1;
}

static inline int
replace_star(replace_ctx_t* ctx, int size) {
	int left = ctx->size - ctx->offset;
	if ( left <= 0 ) {
		return -1;
	}

	if ( left > size ) {
		memset(ctx->replace + ctx->offset, '*', size);
		ctx->offset += size;
		return 0;
	}
	memset(ctx->replace + ctx->offset, '*', left);
	ctx->offset += left;
	return -1;
}

int
word_filter(struct word_tree* root_tree, const char* source, size_t size, char* replace, int replace_size, int* replace_offset) {
	
	replace_ctx_t* replace_ctx = NULL;
	if ( replace ) {
		replace_ctx_t ctx;
		ctx.replace = replace;
		ctx.offset = 0;
		ctx.size = replace_size;

		replace_ctx = &ctx;
	}
	
	struct word_tree* tree = root_tree;

	int filter_start = 0;
	int filter_over = 0;
	int filter_len = -1;
	int filter_offset = -1;
	int filter_back = -1;
	int founded = 0;

	int phase = PHASE_SEARCH;

	int i;
	for(i = 0;i < size;) {
		char word[8] = {0};
		
		int length = split_utf8(source,size,i);
		memcpy(word,&source[i],length);
		i += length;

		switch(phase) {
			case PHASE_SEARCH: {
				khiter_t k = kh_get(word, tree->hash, word);
				if (k != kh_end(tree->hash)) {
					tree = kh_value(tree->hash, k);
					phase = PHASE_MATCH;
					filter_start = i - length;
					filter_over = i;
					filter_len = 1;
					filter_offset = 1;
					filter_back = i;
					founded = 0;
					if (tree->tail) {
						if ( !replace_ctx ) {
							return -1;
						}
						founded = 1;
					}
				} else {
					if ( replace_ctx ) {
						if ( replace_commit(replace_ctx, word, length) < 0 ) {
							goto _replace_over;
						}
					}
				}
				break;
			}
			case PHASE_MATCH: {
				if (length == 1) {
					if (isspace(word[0]) || iscntrl(word[0]) || ispunct(word[0])) {
						++filter_offset;
						continue;
					}
				}
				khiter_t k = kh_get(word, tree->hash, word);
				if (k != kh_end(tree->hash)) {
					tree = kh_value(tree->hash, k);
					++filter_offset;
					if (tree->tail) {
						if ( !replace_ctx ) {
							return -1;
						}
						filter_len = filter_offset;
						filter_back = i;
						founded = 1;
					}
				} else {
					if (founded == 1) {
						//回滚
						i = filter_back;

						if ( !replace_ctx ) {
							return -1;
						}

						//匹配成功
						if ( replace_star(replace_ctx, filter_len) < 0 ) {
							goto _replace_over;
						}
					
					} else {
						//匹配失败
						if ( replace_ctx ) {
							if ( replace_commit(replace_ctx, source + filter_start, filter_over - filter_start) < 0 ) {
								goto _replace_over;
							}
						}
						i = filter_over;
					}
					
					tree = root_tree;
					phase = PHASE_SEARCH;
				}
				break;
			}
		}
	}

	if ( !replace_ctx ) {
		return 0;
	}
	
	if ( phase == PHASE_MATCH ) {
		if ( founded == 1 ) {
			if ( replace_star(replace_ctx, filter_len) < 0 ) {
				goto _replace_over;
			}

			if ( replace_commit(replace_ctx, source + filter_back, size - filter_back) < 0 ) {
				goto _replace_over;
			}
		}
		else {
			if ( replace_commit(replace_ctx, source + filter_start, i - filter_start) < 0 ) {
				goto _replace_over;
			}
		}
	}

_replace_over:

	*replace_offset = replace_ctx->offset;
	return 0;
}

static int
lcreate(lua_State* L) {
	struct word_tree* tree = lua_newuserdata(L,sizeof(*tree));
	tree->hash = kh_init(word);
	luaL_newmetatable(L,"meta_filter");
 	lua_setmetatable(L, -2);
	return 1;
}

void
release(char* word,struct word_tree* tree) {
	if (tree->hash) {
		struct word_tree* child = NULL;
		const char* word = NULL;
		kh_foreach(tree->hash, word, child, release((char*)word, child));
		kh_destroy(word,tree->hash);
	}
	free(tree);
	free(word);
}

static int
lrelease(lua_State* L) {
	struct word_tree* tree = lua_touserdata(L,1);

	struct word_tree* child = NULL;
	const char* word = NULL;
	kh_foreach(tree->hash, word, child, release((char*)word, child));
	kh_destroy(word,tree->hash);
	
	return 0;
}

static int
ladd(lua_State* L) {
	struct word_tree* tree = lua_touserdata(L,1);
	size_t size;
	const char* word = lua_tolstring(L,2,&size);
	word_add(tree,word,size);
	return 0;
}

static int
ldelete(lua_State* L) {
	struct word_tree* tree = lua_touserdata(L,1);
	size_t size;
	const char* word = lua_tolstring(L,2,&size);
	word_delete(tree,word,size);
	return 0;
}

static int
lfilter(lua_State* L) {
	struct word_tree* tree = lua_touserdata(L,1);
	size_t size;
	const char* word = lua_tolstring(L,2,&size);
	int replace = luaL_optinteger(L,3,1);

	int replace_offset = 0;
	char* replace_bk = NULL;
	if (replace) {
		replace_bk = malloc(size);
	}
	
	int ok = word_filter(tree, word, size, replace_bk, size, &replace_offset);
	if ( !replace_bk ) {
		lua_pushboolean(L, ok == 0);
		return 1;
	}
	lua_pushlstring(L, replace_bk, replace_offset);
	free(replace_bk);
	return 1;
}

static int
lconvert(lua_State* L) {
	size_t size;
	const char* word = lua_tolstring(L,1,&size);

	const char* from_charset = lua_tostring(L, 2);
	const char* to_charset = lua_tostring(L, 3);

	iconv_t conv = iconv_open(to_charset, from_charset);
	if (conv == (iconv_t)-1) {
		lua_pushboolean(L, 0);
		lua_pushstring(L, strerror(errno));
        return 2; 
	}

	char* from = strdup(word);
	size_t out_size = size * 4;
	char* out = malloc(out_size);
	memset(out, 0, out_size);

	char* tmp = out;
	
	if (iconv(conv, &from, &size, &tmp, &out_size) == -1)   {
		iconv_close(conv);
		lua_pushboolean(L, 0);
		lua_pushstring(L, strerror(errno));
        return 2; 
	}
	iconv_close(conv);
	lua_pushboolean(L, 1);
    lua_pushstring(L, out);
    return 2;
}

static int
lsplit(lua_State* L) {
	size_t size;
	const char* word = lua_tolstring(L,1,&size);

	lua_newtable(L);

	int index = 1;
	int i;
	for(i = 0;i < size;) {
		char ch[8] = {0};

		int length = split_utf8(word,size,i);
		memcpy(ch,&word[i],length);

		lua_pushlstring(L, ch, length);
		lua_seti(L, -2, index++);

		i += length;
	}

	return 1;
}

void
dump(const char* word,struct word_tree* tree,int depth) {
	int i;
	for(i=0;i<depth;i++)
		printf("  ");
	printf("%s\n",word);
	depth++;
	if (tree->hash) {
		struct word_tree* child = NULL;
		const char* word = NULL;
		kh_foreach(tree->hash, word, child, dump((char*)word, child,depth));
	}
}

static int
ldump(lua_State* L) {
	struct word_tree* tree = lua_touserdata(L,1);
	struct word_tree* child = NULL;
	const char* word = NULL;
	int depth = 0;
	kh_foreach(tree->hash, word, child, dump((char*)word, child, depth));
	return 0;
}

int 
luaopen_filter0_core(lua_State *L) {
	luaL_checkversion(L);

	luaL_newmetatable(L, "meta_filter");
	const luaL_Reg meta[] = {
		{ "add", ladd },
		{ "delete", ldelete },
		{ "filter", lfilter },
		{ "dump", ldump },
		{ NULL, NULL },
	};
	luaL_newlib(L,meta);
	lua_setfield(L, -2, "__index");

	lua_pushcfunction(L,lrelease);
	lua_setfield(L, -2, "__gc");
	lua_pop(L,1);


	const luaL_Reg l[] = {
		{ "create", lcreate },
		{ "split", lsplit },
		{ "convert", lconvert },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
