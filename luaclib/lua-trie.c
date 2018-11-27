#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <ctype.h>
#include <stdint.h>


#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#include "khash.h"

#include "common/utf8.h"

#define PHASE_SEARCH 0
#define PHASE_MATCH 1

struct word_tree;

KHASH_MAP_INIT_INT(word, struct word_tree*);

typedef khash_t(word) tree_hash_t;

typedef struct word_tree {
	tree_hash_t* hash;
	uint8_t tail;
} tree_t;

typedef struct utf8_node {
	utf8_int32_t utf8;
	struct utf8_node* next;
} utf8_node_t;

typedef struct utf8_link {
	utf8_node_t* head;
	utf8_node_t* tail;
} utf8_link_t;

typedef struct search_ud {
	lua_State* L;
	int index;
	const char* prefix;
	size_t size;
} search_ud_t;

typedef struct replace_context {
	char* replace;
	int offset;
	int size;
} replace_ctx_t;

void
tree_set(tree_hash_t* hash, utf8_int32_t utf8, tree_t* tree) {
	int ok;
	khiter_t k = kh_put(word, hash, utf8, &ok);
	assert(ok == 1 || ok == 2);
	kh_value(hash, k) = tree;
}

tree_t*
tree_get(tree_hash_t* hash, utf8_int32_t utf8) {
	khiter_t k = kh_get(word, hash, utf8);
	if ( k == kh_end(hash) ) {
		return NULL;
	}
	return kh_value(hash, k);
}

void
word_add(tree_t* root_tree, const char* word, size_t size) {
	tree_t* tree = root_tree;
	size_t i;
	for ( i = 0; i < size; ) {
		utf8_int32_t utf8 = 0;
		word = utf8codepoint(word, &utf8);
		int length = utf8codepointsize(utf8);
		i += length;

		tree_t* child_tree = tree_get(tree->hash, utf8);
		if ( !child_tree ) {
			child_tree = malloc(sizeof( *tree ));
			child_tree->tail = 0;
			child_tree->hash = kh_init(word);

			tree_set(tree->hash, utf8, child_tree);

			tree = child_tree;
		}
		else {
			tree = child_tree;
		}

		if ( i == size ) {
			tree->tail = 1;
		}
	}
}

void
word_delete(tree_t* root_tree, const char* word, size_t size) {
	tree_t* tree = root_tree;
	size_t i;
	for ( i = 0; i < size; ) {
		utf8_int32_t utf8 = 0;
		word = utf8codepoint(word, &utf8);
		int length = utf8codepointsize(utf8);
		i += length;

		tree = tree_get(tree->hash, utf8);
		if ( !tree ) {
			return;
		}
	}
	tree->tail = 0;
}

tree_t*
word_search(tree_t* root_tree, const char* word, size_t size) {
	tree_t* tree = root_tree;
	size_t i;
	for ( i = 0; i < size; ) {
		utf8_int32_t utf8 = 0;
		word = utf8codepoint(word, &utf8);
		int length = utf8codepointsize(utf8);
		i += length;

		tree = tree_get(tree->hash, utf8);
		if ( !tree ) {
			return NULL;
		}
	}
	return tree;
}

static inline int
replace_commit(replace_ctx_t* ctx, const char* data, int size) {
	int left = ctx->size - ctx->offset;
	if ( left <= 0 ) {
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
word_filter(tree_t* root_tree, const char* source, size_t size, char* replace, int replace_size, int* replace_offset) {
	replace_ctx_t replace_ctx;
	replace_ctx.replace = replace;
	replace_ctx.offset = 0;
	replace_ctx.size = replace_size;

	tree_t* tree = root_tree;

	int start = 0;
	int rollback = -1;
	int founded = 0;
	int filter_length = -1;
	int filter_slider = -1;

	int phase = PHASE_SEARCH;

	int position = 0;
	while ( position < size ) {
		utf8_int32_t utf8 = 0;
		utf8codepoint(source + position, &utf8);
		int length = utf8codepointsize(utf8);
		position += length;

		switch ( phase ) {
			case PHASE_SEARCH: {
			   tree = tree_get(tree->hash, utf8);
			   if ( tree ) {
				   phase = PHASE_MATCH;
				   start = position - length;
				   rollback = position;
				   filter_length = 1;
				   filter_slider = 1;
				   founded = 0;
				   if ( tree->tail ) {
					   if ( !replace ) {
						   return -1;
					   }
					   founded = 1;
				   }
			   }
			   else {
				   tree = root_tree;
				   if ( replace ) {
					   char word[8] = { 0 };
					   utf8catcodepoint(word, utf8, 8);
					   if ( replace_commit(&replace_ctx, word, length) < 0 ) {
						   goto _replace_over;
					   }
				   }
			   }
			   break;
			}
			case PHASE_MATCH: {
				  if ( length == 1 ) {
					  if ( isspace(utf8) || iscntrl(utf8) || ispunct(utf8) ) {
						  ++filter_slider;
						  continue;
					  }
				  }
				  tree = tree_get(tree->hash, utf8);
				  if ( tree ) {
					  ++filter_slider;
					  if ( tree->tail ) {
						  if ( !replace ) {
							  return -1;
						  }
						  filter_length = filter_slider;
						  rollback = position;
						  founded = 1;
					  }
				  }
				  else {
					  if ( founded == 1 ) {
						  //匹配成功
						  if ( replace ) {
							  if ( replace_star(&replace_ctx, filter_length) < 0 ) {
								  goto _replace_over;
							  }
						  }
						  else {
							  return -1;
						  }
					  }
					  else if ( replace ) {
						  //匹配失败
						  if ( replace_commit(&replace_ctx, source + start, rollback - start) < 0 ) {
							  goto _replace_over;
						  }
					  }
					  //回滚
					  position = rollback;
					  tree = root_tree;
					  phase = PHASE_SEARCH;
				  }
				  break;
			}
		}
	}

	if ( !replace ) {
		return 0;
	}

	if ( phase == PHASE_MATCH ) {
		if ( founded == 1 ) {
			if ( replace_star(&replace_ctx, filter_length) < 0 ) {
				goto _replace_over;
			}

			if ( replace_commit(&replace_ctx, source + rollback, size - rollback) < 0 ) {
				goto _replace_over;
			}
		}
		else {
			if ( replace_commit(&replace_ctx, source + start, position - start) < 0 ) {
				goto _replace_over;
			}
		}
	}

_replace_over:
	*replace_offset = replace_ctx.offset;
	return 0;
}

static int
lcreate(lua_State* L) {
	tree_t* tree = lua_newuserdata(L, sizeof( *tree ));
	tree->hash = kh_init(word);
	luaL_newmetatable(L, "meta_trie");
	lua_setmetatable(L, -2);
	return 1;
}

void
release(utf8_int32_t utf8, tree_t* tree) {
	if ( tree->hash ) {
		tree_t* child = NULL;
		kh_foreach(tree->hash, utf8, child, release(utf8, child));
		kh_destroy(word, tree->hash);
	}
	free(tree);
}

static int
lrelease(lua_State* L) {
	tree_t* tree = lua_touserdata(L, 1);

	tree_t* child = NULL;
	utf8_int32_t utf8;
	kh_foreach(tree->hash, utf8, child, release(utf8, child));
	kh_destroy(word, tree->hash);

	return 0;
}

static int
ladd(lua_State* L) {
	tree_t* tree = lua_touserdata(L, 1);
	size_t size;
	const char* word = lua_tolstring(L, 2, &size);
	word_add(tree, word, size);
	return 0;
}

static int
ldelete(lua_State* L) {
	tree_t* tree = lua_touserdata(L, 1);
	size_t size;
	const char* word = lua_tolstring(L, 2, &size);
	word_delete(tree, word, size);
	return 0;
}

static int
lfilter(lua_State* L) {
	tree_t* tree = lua_touserdata(L, 1);
	size_t size;
	const char* word = lua_tolstring(L, 2, &size);
	int replace = luaL_optinteger(L, 3, 1);

	int replace_offset = 0;
	char* replace_bk = NULL;
	if ( replace ) {
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

static void
merge_word(search_ud_t* ud, utf8_link_t* link, tree_t* tree) {
	if ( tree->tail == 1 ) {
		luaL_Buffer buffer;
		luaL_buffinit(ud->L, &buffer);

		luaL_addlstring(&buffer, ud->prefix, ud->size);

		utf8_node_t* cursor = link->head;
		while ( cursor ) {
			char word[8] = { 0 };
			utf8catcodepoint(word, cursor->utf8, 8);
			luaL_addlstring(&buffer, word, strlen(word));
			cursor = cursor->next;
		}
		luaL_pushresult(&buffer);
		lua_rawseti(ud->L, -2, ud->index++);
	}

	utf8_int32_t utf8;
	tree_t* child;

	kh_foreach(tree->hash, utf8, child, {
		utf8_node_t node;
		node.utf8 = utf8;
		node.next = NULL;

		link->tail->next = &node;
		link->tail = &node;

		merge_word(ud, link, child);
	});
}

static int
lsearch(lua_State* L) {
	tree_t* tree = lua_touserdata(L, 1);
	size_t size;
	const char* word = lua_tolstring(L, 2, &size);

	search_ud_t ud;
	ud.L = L;
	ud.index = 1;
	ud.prefix = word;
	ud.size = size;

	lua_newtable(L);

	tree = word_search(tree, word, size);
	if (!tree) {
		return 1;
	}
	
	utf8_int32_t utf8;
	tree_t* child;

	kh_foreach(tree->hash, utf8, child, {
		utf8_node_t node;
		node.utf8 = utf8;
		node.next = NULL;

		utf8_link_t link;
		link.head = &node;
		link.tail = &node;

		merge_word(&ud, &link, child);
	});
	return 1;
}

static int
lsplit(lua_State* L) {
	size_t size;
	const char* word = lua_tolstring(L, 1, &size);

	lua_newtable(L);

	int index = 1;
	size_t i;
	for ( i = 0; i < size; ) {
		utf8_int32_t utf8 = 0;
		char* next = utf8codepoint(word, &utf8);
		size_t length = utf8codepointsize(utf8);
		lua_pushlstring(L, word, length);
		lua_seti(L, -2, index++);
		word = next;
		i += length;
	}

	return 1;
}

void
dump(utf8_int32_t utf8, tree_t* tree, int depth, FILE* f) {
	int i;
	for ( i = 0; i < depth; i++ ) {
		const char* t = "  ";
		printf(t);
		if ( f ) {
			fwrite(t, strlen(t), 1, f);
		}
	}

	char word[8] = { 0 };
	utf8catcodepoint(word, utf8, 8);
	word[strlen(word)] = '\n';

	printf("%s", word);
	if ( f ) {
		fwrite(word, strlen(word), 1, f);
	}

	depth++;
	if ( tree->hash ) {
		tree_t* child = NULL;
		kh_foreach(tree->hash, utf8, child, dump(utf8, child, depth, f));
	}
}

static int
ldump(lua_State* L) {
	tree_t* tree = lua_touserdata(L, 1);
	const char* file = NULL;
	if ( lua_type(L, 2) == LUA_TSTRING ) {
		file = lua_tostring(L, 2);
	}

	tree_t* child = NULL;
	utf8_int32_t utf8;
	int depth = 0;

	FILE* f = NULL;
	if (file) {
		f = fopen(file, "w");
	}

	kh_foreach(tree->hash, utf8, child, dump(utf8, child, depth, f));
	
	if (file) {
		fclose(f);
	}
	
	return 0;
}

int 
luaopen_trie(lua_State *L) {
	luaL_checkversion(L);

	luaL_newmetatable(L, "meta_trie");
	const luaL_Reg meta[] = {
		{ "add", ladd },
		{ "delete", ldelete },
		{ "filter", lfilter },
		{ "search", lsearch },
		{ "dump", ldump },
		{ NULL, NULL },
	};
	luaL_newlib(L, meta);
	lua_setfield(L, -2, "__index");

	lua_pushcfunction(L, lrelease);
	lua_setfield(L, -2, "__gc");
	lua_pop(L, 1);


	const luaL_Reg l[] = {
		{ "create", lcreate },
		{ "split_utf8", lsplit },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
