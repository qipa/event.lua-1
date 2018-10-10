#include <lua.h>
#include <lauxlib.h>
#include <luaconf.h>
#include <lobject.h>
#include <lstate.h>
#include <lstring.h>
#include <ltable.h>
#include <lfunc.h>

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <errno.h>

#include <openssl/evp.h>  
#include <openssl/bio.h>  
#include <openssl/buffer.h> 
#include <openssl/rc4.h>  
#include <openssl/md5.h>  
#include <openssl/sha.h> 
#include <openssl/err.h>
#include <openssl/rsa.h>
#include <openssl/pem.h>

#include <unistd.h>
#include <sys/prctl.h> 
#include <sys/types.h>
#include <sys/syscall.h>
#include <sys/time.h>
#include <sys/un.h>
#include <sys/socket.h>

#include <netinet/tcp.h>
#include <netinet/in.h>
#include <arpa/inet.h>     
#include <netdb.h>

#include "convert.h"
#include "linenoise.h"
#include "common/common.h"



#define LOG_ERROR   "\033[40;31m%s\033[0m"
#define LOG_WARN    "\033[40;33m%s\033[0m"
#define LOG_INFO    "\033[40;36m%s\033[0m"
#define LOG_DEBUG   "\033[40;37m%s\033[0m"

static const char* LOG_COLOR[] = { LOG_ERROR, LOG_WARN, LOG_INFO, LOG_DEBUG};


#define SMALL_CHUNK 256
#define HEX(v,c) { char tmp = (char) c; if (tmp >= '0' && tmp <= '9') { v = tmp-'0'; } else { v = tmp - 'a' + 10; } }

static int
lhex_encode(lua_State *L) {
    static char hex[] = "0123456789abcdef";
    size_t sz = 0;
    const uint8_t * text = (const uint8_t *)luaL_checklstring(L, 1, &sz);
    char tmp[SMALL_CHUNK];
    char *buffer = tmp;
    if (sz > SMALL_CHUNK/2) {
        buffer = lua_newuserdata(L, sz * 2);
    }
    int i;
    for (i=0;i<sz;i++) {
        buffer[i*2] = hex[text[i] >> 4];
        buffer[i*2+1] = hex[text[i] & 0xf];
    }
    lua_pushlstring(L, buffer, sz * 2);
    return 1;
}

static int
lhex_decode(lua_State *L) {
    size_t sz = 0;
    const char * text = luaL_checklstring(L, 1, &sz);
    if (sz & 1) {
        return luaL_error(L, "Invalid hex text size %d", (int)sz);
    }
    char tmp[SMALL_CHUNK];
    char *buffer = tmp;
    if (sz > SMALL_CHUNK*2) {
        buffer = lua_newuserdata(L, sz / 2);
    }
    int i;
    for (i=0;i<sz;i+=2) {
        uint8_t hi,low;
        HEX(hi, text[i]);
        HEX(low, text[i+1]);
        if (hi > 16 || low > 16) {
            return luaL_error(L, "Invalid hex text", text);
        }
        buffer[i/2] = hi<<4 | low;
    }
    lua_pushlstring(L, buffer, i/2);
    return 1;
}

int
lbase64_encode(lua_State* L) {
    size_t size;
    const char* source = lua_tolstring(L,1,&size);

    BIO* b64 = BIO_new(BIO_f_base64());
    BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL); 
    
    BIO* bio = BIO_new(BIO_s_mem());
    b64 = BIO_push(b64,bio);
    BIO_write(b64,source,size);
    BIO_flush(b64);

    BUF_MEM* buf = NULL;
    BIO_get_mem_ptr(b64,&buf);

    char* result = malloc(buf->length + 1);
    memcpy(result,buf->data,buf->length);
    result[buf->length] = 0;

    lua_pushlstring(L,result,buf->length + 1);
    BIO_free_all(b64); 
    free(result);
    return 1;
}

int
lbase64_decode(lua_State* L) {
    size_t size;
    const char* source = lua_tolstring(L,1,&size);

    char * buffer = (char *)malloc(size);  
    memset(buffer, 0, size);  
  
    BIO* b64 = BIO_new(BIO_f_base64());  
    BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);  
    
    BIO* bio = BIO_new_mem_buf((void*)source, size);  
    bio = BIO_push(b64, bio);  
    int rsize = BIO_read(bio, buffer, size);  
    buffer[rsize] = '\0';

    lua_pushlstring(L,buffer,size);

    BIO_free_all(bio);
    free(buffer);
    return 1;
}

int
lmd5(lua_State* L) {
    size_t size;
    const unsigned char* source = (const unsigned char*)lua_tolstring(L,1,&size);
    unsigned char md5[16] = {0};
    MD5(source,size,md5); 
    lua_pushlstring(L,(const char*)md5,16);
    return 1;
}

int
lsha1(lua_State* L) {
    size_t size;
    const unsigned char* source = (const unsigned char*)lua_tolstring(L,1,&size);
    unsigned char digest[SHA_DIGEST_LENGTH];
    SHA1(source,size,digest);
    lua_pushlstring(L,(const char*)digest,SHA_DIGEST_LENGTH);
    return 1;
}

int
lrc4(lua_State* L) {
    size_t source_size;
    size_t key_size;
    const char* source = lua_tolstring(L,1,&source_size);
    const char* key = lua_tolstring(L,2,&key_size);

    RC4_KEY rc4_key;
    RC4_set_key(&rc4_key,key_size,(unsigned char*)key);

    char out[512] = {0};
    char* result = out;
    if (source_size > 512)
        result = malloc(source_size);

    RC4(&rc4_key,source_size,(unsigned char*)source,(unsigned char*)result);
    lua_pushlstring(L,result,source_size);
    if (result != out)
        free(result);

    return 1;
}

RSA*
_rsa_load_prikey(const char* prikeyname) {
    FILE *fp = fopen(prikeyname, "rb");
    if (!fp) {
        fprintf(stderr, "fopen error(%s)", strerror(errno));
        return NULL;
    }

    RSA* rsa_private = PEM_read_RSAPrivateKey(fp, NULL, NULL, NULL);
    if(NULL == rsa_private) {
        ERR_load_crypto_strings();
        char err[1024];
        char* errret = ERR_error_string(ERR_get_error(), err);
        fprintf(stderr, "PEM_read_RSAPrivateKey error(%s:%s)", errret, err);

        fclose(fp);
        return NULL;
    }
    fclose(fp);
    return rsa_private;
}

RSA*
_rsa_load_pubkey(const char* pubkeyname) {
    FILE *fp = fopen(pubkeyname, "rb");
    if (!fp) {
        fprintf(stderr, "fopen error(%s)", strerror(errno));
        return NULL;
    }

    RSA* rsa_public = PEM_read_RSAPublicKey(fp, NULL, NULL, NULL);
    if(NULL == rsa_public) {
        ERR_load_crypto_strings();
        char err[1024];
        char* errret = ERR_error_string(ERR_get_error(), err);
        fprintf(stderr, "PEM_read_RSAPublicKey error(%s:%s)", errret, err);

        fclose(fp);
        return NULL;
    }
    fclose(fp);
    return rsa_public;
}


int
lrsa_generate_key(lua_State* L) {
    const char* pubkeyname = luaL_checkstring(L, 1);
    const char* prikeyname = luaL_checkstring(L, 2);
    int keysize = luaL_optinteger(L, 3, 1024);

    RSA* rsa = NULL;
    FILE *fp = NULL;

    if ((rsa = RSA_generate_key(keysize, 0x10001, NULL, NULL)) == NULL) {
        ERR_load_crypto_strings();
        char err[1024];
        char* errret = ERR_error_string(ERR_get_error(), err);
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "RSA_generate_key error(%s:%s)", errret, err);
        return 2;
    }

    if (!RSA_check_key(rsa)) {
        RSA_free(rsa);
        lua_pushboolean(L, 0);
        lua_pushstring(L, "invalid RSA Key");
        return 2;
    }

    fp = fopen(prikeyname, "w");
    if (!fp) {
        RSA_free(rsa);
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "fopen prikeyname error(%s)", strerror(errno));
        return 2;
    }

    if (!PEM_write_RSAPrivateKey(fp, rsa, NULL, NULL, 0, 0, NULL)) {
        ERR_load_crypto_strings();
        char err[1024];
        char* errret = ERR_error_string(ERR_get_error(), err);
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "PEM_write_RSAPrivateKey error(%s:%s)", errret, err);
        fclose(fp);
        RSA_free(rsa);
        return 2;
    }

    fclose(fp);
    fp = fopen(pubkeyname, "w");
    if (!fp) {
        RSA_free(rsa);
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "fopen pubkeyname error(%s)", strerror(errno));
        return 2;
    }

    if (!PEM_write_RSAPublicKey(fp, rsa)) {
        ERR_load_crypto_strings();
        char err[1024];
        char* errret = ERR_error_string(ERR_get_error(), err);
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "PEM_write_RSAPublicKey error(%s:%s)", errret, err);
        fclose(fp);
        RSA_free(rsa);
        return 2;
    }

    RSA_free(rsa);
    fclose(fp);

    lua_pushboolean(L, 1);
    return 1;
}

int
lrsa_encrypt(lua_State* L) {
    size_t insize;
    const char* instr = lua_tolstring(L, 1, &insize);
    const char* pubkeyname = lua_tostring(L, 2);

    RSA* rsa_pubic = _rsa_load_pubkey(pubkeyname);
    if (NULL == rsa_pubic) {
        RSA_free(rsa_pubic);
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "load public key error(%s)", pubkeyname);
        return 2;
    }

    unsigned char* outstr = calloc(RSA_size(rsa_pubic) + 1, sizeof(unsigned char*));
    int outsize = RSA_public_encrypt(insize, (unsigned char*)instr, outstr, rsa_pubic, RSA_PKCS1_OAEP_PADDING);
    if (outsize < 0) {
        ERR_load_crypto_strings();
        char err[1024];
        char* errret = ERR_error_string(ERR_get_error(), err);
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "RSA_public_encrypt error(%s:%s)", errret, err);
        free(outstr);
        RSA_free(rsa_pubic);
        return 2;
    }

    lua_pushlstring(L, (char*)outstr, outsize);
    RSA_free(rsa_pubic);
    free(outstr);
    return 1;
}

int
lrsa_decrypt(lua_State* L) {
    size_t insize;
    const char* instr = lua_tolstring(L, 1, &insize);
    const char* prikeyname = lua_tostring(L, 2);

    RSA* rsa_private = _rsa_load_prikey(prikeyname);
    if (NULL == rsa_private) {
        RSA_free(rsa_private);
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "load private key error(%s)", rsa_private);
        return 2;
    }

    unsigned char* outstr = calloc(RSA_size(rsa_private) + 1, sizeof(unsigned char*));
    int outsize = RSA_private_decrypt(insize, (unsigned char*)instr, outstr, rsa_private, RSA_PKCS1_OAEP_PADDING);
    if (outsize < 0) {
        ERR_load_crypto_strings();
        char err[1024];
        char* errret = ERR_error_string(ERR_get_error(), err);
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "RSA_private_decrypt error(%s:%s)", errret, err);
        free(outstr);
        RSA_free(rsa_private);
        return 2;
    }

    lua_pushlstring(L, (char*)outstr, outsize);
    RSA_free(rsa_private);
    free(outstr);
    return 1;
}

static int
lauthcode(lua_State* L) {
    size_t insize;
    const char* instr = luaL_checklstring(L, 1, &insize);

    size_t keysize;
    const char* key = luaL_checklstring(L, 2, &keysize);

    int timestamp = luaL_checkinteger(L, 3);

    int encode = luaL_checkinteger(L, 4);

    RC4_KEY rc4_key;
    RC4_set_key(&rc4_key,keysize,(unsigned char*)key);

    if (encode) {
        size_t length = insize + sizeof(int) + 16;
        unsigned char* block = malloc(length * 2);
        memcpy(block, instr, insize);
        memcpy(block + insize, &timestamp, sizeof(int));

        unsigned char source_md5[16] = {0};
        MD5((const unsigned char*)block,insize + sizeof(int),source_md5);

        memcpy(block + insize + sizeof(int), source_md5, 16);
 

        RC4(&rc4_key,length,(unsigned char*)block,(unsigned char*)block + length);

        lua_pushlstring(L, (const char*)block + length,length);
        free(block);
        return 1;
    }
    char* block = malloc(insize);
    RC4(&rc4_key,insize,(unsigned char*)instr,(unsigned char*)block);
    unsigned char omd5[16] = {0};
    memcpy(omd5,block + (insize - 16),16);

    unsigned char cmd5[16] = {0};
    MD5((const unsigned char*)block,insize-16,cmd5);

    if (memcmp(omd5,cmd5,16) != 0) {
        free(block);
        lua_pushboolean(L, 0);
        lua_pushstring(L, "authcode decode error");
        return 2;
    }

    int lasttimestamp = 0;
    memcpy(&lasttimestamp, block + (insize - 16 - sizeof(int)), sizeof(int));
    if (lasttimestamp < timestamp) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, "authcode timeout");
        return 2;
    }
    lua_pushlstring(L, block, insize - 16 - sizeof(int));
    free(block);
    return 1;
}

int
lload_script(lua_State* L) {
    size_t size;
    const char* buffer = lua_tolstring(L,1,&size);
    const char* name = lua_tostring(L,2);
    luaL_checktype(L,3,LUA_TTABLE);
    int status = luaL_loadbuffer(L,buffer,size,name);
    if (status != LUA_OK)
        luaL_error(L,"%s",lua_tostring(L,-1));

    lua_pushvalue(L, 3);
    lua_setupvalue(L, -2, 1);

    const Proto* f = getproto(L->top - 1);

    lua_newtable(L);
    int i;
    for (i=0; i<f->sizelocvars; i++) {
        lua_pushstring(L,getstr(f->locvars[i].varname));
        lua_pushinteger(L,f->lineinfo[f->locvars[i].startpc+1]);
        lua_settable(L,-3);
    }

    return 2;
}

static int
lthread_name(lua_State* L) {
    const char* name = lua_tostring(L,1);
    prctl(PR_SET_NAME, name); 
    return 0;
}

int
lthread_id(lua_State* L) {
    lua_pushinteger(L,syscall(SYS_gettid));
    return 1;
}

int
ltime(lua_State* L) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t now = (tv.tv_sec + tv.tv_usec * 1e-6) * 100;
    lua_pushinteger(L,now);
    return 1;
}

int
lprint(lua_State* L) {
    int log_lv = lua_tointeger(L,1);
    const char* log = lua_tostring(L,2);
    printf(LOG_COLOR[log_lv],log);
    return 0;
}

int
ltostring(lua_State* L) {
    if (lua_type(L, 1) != LUA_TNUMBER) {
        lua_pushvalue(L, lua_upvalueindex(1));
        lua_pushvalue(L, 1);
        if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
            luaL_error(L,lua_tostring(L, -1));
        }
        return 1;
    }

   if (lua_isinteger(L, 1)) {
        LUAI_UACINT integer = (LUAI_UACINT)lua_tointeger(L, 1);
        int32_t i32 = (int32_t)integer;
        int64_t i64 = (int64_t)integer;
        char buff[64] = {0};
        size_t len;
        if ((LUAI_UACINT)i32 == integer) {
            char* end = i32toa_fast(i32, buff);
            *end = 0;
            len = end - buff;
            lua_pushlstring(L,buff,len);
        } else if ((LUAI_UACINT)i64 == integer) {
            char* end = i64toa_fast(i64, buff);
            *end = 0;
            len = end - buff;
            lua_pushlstring(L,buff,len);
        } else {
            lua_pushfstring(L, "%I", integer);
        }
    }  else {
        LUAI_UACNUMBER number = (LUAI_UACNUMBER)lua_tonumber(L, 1);
        double d = (double)number;
        if (!isnan(d) && !isinf(d) && (LUAI_UACNUMBER)d == number) {
            char buff[64] = {0};
            dtoa_fast(d, buff);
            lua_pushstring(L,buff);
        } else {
            lua_pushfstring(L, "%f", number);
        }
    }
    return 1;
}

int
ltype(lua_State* L) {
    int t = lua_type(L, 1);
    luaL_argcheck(L, t != LUA_TNONE, 1, "value expected");
    lua_pushinteger(L, t);
    return 1;
}

static lua_State* gL = NULL;

void completion(const char* str,linenoiseCompletions* lc) {
    lua_pushvalue(gL,2);
    lua_pushstring(gL,str);
    int r = lua_pcall(gL,1,1,0);
    if (r != LUA_OK)  {
        fprintf(stderr,"%s\n",lua_tostring(gL,-1));
        lua_pop(gL,1);
        return;
    }

    if (!lua_isnil(gL,-1)) {
        lua_pushnil(gL);
        while (lua_next(gL, -2) != 0) {
            const char* result = lua_tostring(gL,-1);
            linenoiseAddCompletion(lc,result);
            lua_pop(gL, 1);
        }
    }
    lua_pop(gL,1);
}

static int
lreadline(lua_State* L) {
    linenoiseSetCompletionCallback(completion);
    const char* prompt = lua_tostring(L,1);
    gL = L;
    char* line = linenoise(prompt);
    if (line) {
        linenoiseHistoryAdd(line);
        gL = NULL;
        lua_pushstring(L,line);
        free(line);
        return 1;
    }
    gL = NULL;
    return 0;
}

static int
lgetaddrinfo(lua_State* L) {
    const char* nodename = lua_tostring(L,1);
    const char* servname = lua_tostring(L,2);
    
    struct addrinfo hints;
    struct addrinfo* ai_list = NULL;
    struct addrinfo* ai_ptr = NULL;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = AI_PASSIVE;

    int status = getaddrinfo(nodename, servname, &hints, &ai_list);
    if (status != 0) {
        free(ai_list);
        lua_pushboolean(L,0);
        lua_pushstring(L,gai_strerror(status));
        return 2;
    }

    lua_newtable(L);
    int index = 1;
    
    for (ai_ptr = ai_list; ai_ptr != NULL; ai_ptr = ai_ptr->ai_next ) {
        lua_newtable(L);

        lua_pushinteger(L,ai_ptr->ai_family);
        lua_setfield(L,-2,"ai_family");

        lua_pushinteger(L,ai_ptr->ai_socktype);
        lua_setfield(L,-2,"ai_socktype");

        lua_pushinteger(L,ai_ptr->ai_protocol);
        lua_setfield(L,-2,"ai_protocol");

        struct sockaddr* addr = ai_ptr->ai_addr;
        void* sin_addr;
        void* sin_port;
        if (ai_ptr->ai_family == AF_INET) {
            sin_port = (void*)&((struct sockaddr_in*)addr)->sin_port;
            sin_addr = (void*)&((struct sockaddr_in*)addr)->sin_addr;
        } else {
            sin_port = (void*)&((struct sockaddr_in6*)addr)->sin6_port;
            sin_addr = (void*)&((struct sockaddr_in6*)addr)->sin6_addr;
        }

        lua_pushinteger(L,ntohs((uint16_t)(uintptr_t)sin_port));
        lua_setfield(L,-2,"port");

        char host_buffer[128] = {0};

        if (inet_ntop(ai_ptr->ai_family, sin_addr, host_buffer, sizeof(host_buffer))) {
            lua_pushstring(L,host_buffer);
            lua_setfield(L,-2,"ip");
        }

        lua_seti(L,-2,index++);
    }
    return 1;
}

static int
labort(lua_State* L) {
    abort();
    return 0;
}

static int
lclone_string(lua_State* L) {
    void* data = lua_touserdata(L, 1);
    size_t size = lua_tointeger(L, 2);
    lua_pushlstring(L,data,size);
    return 1;
}

struct packet {
    uint16_t wseed;
    uint16_t rseed;
};

static int
lpacket_pack(lua_State* L) {
    struct packet* packet = lua_touserdata(L, 1);
    uint16_t id = lua_tointeger(L, 2);
    size_t size;
    const char* data = NULL;
    switch(lua_type(L,3)) {
        case LUA_TSTRING: {
            data = lua_tolstring(L, 3, &size);
            break;
        }
        case LUA_TLIGHTUSERDATA:{
            data = lua_touserdata(L, 3);
            size = lua_tointeger(L, 4);
            break;
        }
        default:
            luaL_error(L,"unkown type:%s",lua_typename(L,lua_type(L,3)));
    }

    uint16_t* mb = message_encrypt(&packet->wseed,id,(const uint8_t*)data,size);
    lua_pushlightuserdata(L, mb);
    lua_pushinteger(L, size + 6);
    return 2;
}

static int
lpacket_unpack(lua_State* L) {
    struct packet* packet = lua_touserdata(L, 1);
    uint8_t* data = lua_touserdata(L, 2);
    int size = lua_tointeger(L, 3);
 
    uint16_t id = data[0] | data[1] << 8;

    lua_pushinteger(L, id);
    lua_pushlightuserdata(L, &data[2]);
    lua_pushinteger(L, size - 2);
    return 3;
}

static int
lpacket_new(lua_State* L) {
    struct packet* packet = lua_newuserdata(L, sizeof(*packet));
    memset(packet,0,sizeof(*packet));

    if (luaL_newmetatable(L, "meta_packte")) {
        const luaL_Reg meta_packte[] = {
            { "pack", lpacket_pack },
            { "unpack", lpacket_unpack },
            { NULL, NULL },
        };
        luaL_newlib(L,meta_packte);
        lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
    return 1;
}

static int
lrpc_pack(lua_State* L) {
    size_t size;
    void* data = NULL;
    int need_free = 0;
    switch(lua_type(L,1)) {
        case LUA_TSTRING: {
            data = (void*)lua_tolstring(L, 1, &size);
            break;
        }
        case LUA_TLIGHTUSERDATA:{
            need_free = 1;
            data = lua_touserdata(L, 1);
            size = lua_tointeger(L, 2);
            break;
        }
        default:
            luaL_error(L,"unkown type:%s",lua_typename(L,lua_type(L,1)));
    }

    int total = size + 4;
    char* buffer = malloc(total);
    memcpy(buffer,&total,4);
    memcpy(buffer+4,data,size);
    if (need_free)
        free(data);

    lua_pushlightuserdata(L,buffer);
    lua_pushinteger(L,total);
    return 2;
}

static inline void 
swap(lua_State* L, int from, int to) {
    lua_geti(L, 1, from);
    lua_geti(L, 1, to);
    lua_seti(L, 1, from);
    lua_seti(L, 1, to);
}

static inline int 
sort_comp(lua_State *L, int a, int b) {
    if ( lua_isnil(L, 2) )
        return lua_compare(L, a, b, LUA_OPLT);
    else {
        int res;
        lua_pushvalue(L, 3);
        lua_pushvalue(L, a - 1);
        lua_pushvalue(L, b - 2);
        lua_call(L, 2, 1);
        res = lua_toboolean(L, -1);
        lua_pop(L, 1);
        return res;
    }
}

static int 
partition(lua_State *L, int lo, int up) {
    lua_geti(L, 1, lo - 1);

    int i = lo;
    int j = up;

    while ( i != j ) {
        while ( i < j ) {
            lua_geti(L, 1, j);
            if ( sort_comp(L, -1, -2) ) {
                lua_pop(L, 1);
                break;
            }
            j--;
            lua_pop(L, 1);
        }
    
        while ( i < j ) {
            lua_geti(L, 1, i);
            if ( !sort_comp(L, -1, -2) ) {
                lua_pop(L, 1);
                break;
            }
            i++;
            lua_pop(L, 1);
        }

        if (i < j)
            swap(L, i, j);
    }

    lua_geti(L, 1, i);
    if ( sort_comp(L, -1, -2) ) {
        swap(L, i, lo - 1);
    }
    lua_pop(L, 1);
    // printf("j:%d,lo:%d,up:%d\n",i,lo,up);
    return i;
}


static int 
ltopK(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    size_t narr = lua_rawlen(L, 1);
    if ( narr < 2 )
        return 0;

    size_t K = luaL_checkinteger(L, 2);

    luaL_checktype(L, 3, LUA_TFUNCTION);
    if ( K >= narr ) {
        return 0;
    }

    K++;

    int low = 2;
    int high = narr;

    int j = partition(L, low, high);
    while (j != K) {
        if (K > j)
            low = j + 1;
        else 
            high = j - 1;
        j = partition(L, low, high);
    }
    return 0;
}

static int
lcapsule_intersect(lua_State* L) {
    float x0 = lua_tonumber(L, 1);
    float z0 = lua_tonumber(L, 2);

    float x1 = lua_tonumber(L, 3);
    float z1 = lua_tonumber(L, 4);

    float cr = lua_tonumber(L, 5);

    float x = lua_tonumber(L, 6);
    float z = lua_tonumber(L, 7);

    float r = lua_tonumber(L, 8);

    vector2_t dot = {x0, z0};
    vector2_t u = {x1 - x0, z1 - z0};
    vector2_t center = {x, z};

    int ok = capsule_intersect(&dot, &u, cr, &center, r);
    lua_pushboolean(L, ok);
    return 1;
} 

static int
lrectangle_intersect(lua_State* L) {
    float x0 = lua_tonumber(L, 1);
    float z0 = lua_tonumber(L, 2);
    float length = lua_tonumber(L, 3);
    float width = lua_tonumber(L, 4);
    float angle = lua_tonumber(L, 5);

    float x = lua_tonumber(L, 6);
    float z = lua_tonumber(L, 7);

    float r = lua_tonumber(L, 8);

    vector2_t dot = {x0, z0};
    vector2_t center = {x, z};

    int ok = rectangle_intersect(&dot, length, width, angle, &center, r);
    lua_pushboolean(L, ok);
    return 1;
} 

static int
lsector_intersect(lua_State* L) {
    float x0 = lua_tonumber(L, 1);
    float z0 = lua_tonumber(L, 2);
    float angle = lua_tonumber(L, 3);
    float degree = lua_tonumber(L, 4);
    float l = lua_tonumber(L, 5);

    float x = lua_tonumber(L, 6);
    float z = lua_tonumber(L, 7);

    float r = lua_tonumber(L, 8);

    vector2_t dot = {x0, z0};
    vector2_t center = {x, z};

    int ok = sector_intersect(&dot, angle, degree, l, &center, r);
    lua_pushboolean(L, ok);
    return 1;
}

static int
ldot2dot(lua_State* L) {
    float x0 = lua_tonumber(L, 1);
    float z0 = lua_tonumber(L, 2);
    float x1 = lua_tonumber(L, 3);
    float z1 = lua_tonumber(L, 4);

    vector2_t from = {x0, z0};
    vector2_t to = {x1, z1};

    float dt = dot2dot(&from, &to);

    lua_pushnumber(L, dt);
    return 1;
}

static int
lrotation(lua_State* L) {
    float x = lua_tonumber(L, 1);
    float z = lua_tonumber(L, 2);
    float cx = lua_tonumber(L, 3);
    float cz = lua_tonumber(L, 4);
    float angle = lua_tonumber(L, 5);

    vector2_t dot = {x, z};
    vector2_t center = {cx, cz};

    rotation(&dot, &center, angle);

    lua_pushnumber(L, dot.x);
    lua_pushnumber(L, dot.z);
    return 2;
}

static int
lmove_torward(lua_State* L) {
    float x = lua_tonumber(L, 1);
    float z = lua_tonumber(L, 2);
    float radian = lua_tonumber(L, 3);
    float distance = lua_tonumber(L, 4);

    vector2_t result;
    vector2_t dot = {x, z};
    vector2_t u;
    u.x = cos(radian);
    u.z = sin(radian);

    move_torward(&result, &dot, &u, distance);

    lua_pushnumber(L, result.x);
    lua_pushnumber(L, result.z);
    return 2;
}

static int
lmove_forward(lua_State* L) {
    float x0 = lua_tonumber(L, 1);
    float z0 = lua_tonumber(L, 2);
    float x1 = lua_tonumber(L, 3);
    float z1 = lua_tonumber(L, 4);
    float pass = lua_tonumber(L, 5);

    vector2_t result;
    vector2_t from = {x0, z0};
    vector2_t to = {x1, z1};

    move_forward(&result, &from, &to, pass);

    lua_pushnumber(L, result.x);
    lua_pushnumber(L, result.z);
    return 2;
}

extern int lsize_of(lua_State* L);
extern int lprofiler_start(lua_State* L);
extern int lprofiler_stack_start(lua_State *L);

int
luaopen_util_core(lua_State* L){
    luaL_Reg l[] = {
        { "hex_encode", lhex_encode },
        { "hex_decode", lhex_decode },
        { "base64_encode", lbase64_encode },
        { "base64_decode", lbase64_decode },
        { "md5", lmd5 },
        { "sha1", lsha1 },
        { "rc4", lrc4 },
        { "rsa_generate_key", lrsa_generate_key },
        { "rsa_encrypt", lrsa_encrypt },
        { "rsa_decrypt", lrsa_decrypt },
        { "authcode", lauthcode },
        { "load_script", lload_script },
        { "thread_name", lthread_name },
        { "thread_id", lthread_id },
        { "time", ltime },
        { "print", lprint },
        { "type", ltype },
        { "readline", lreadline },
        { "getaddrinfo", lgetaddrinfo },
        { "abort", labort },
        { "clone_string", lclone_string },
        { "packet_new", lpacket_new },
        { "rpc_pack", lrpc_pack },
        { "topK", ltopK },
        { "capsule_intersect", lcapsule_intersect },
        { "rectangle_intersect", lrectangle_intersect },
        { "sector_intersect", lsector_intersect },
        { "dot2dot", ldot2dot },
        { "rotation", lrotation },
        { "move_torward", lmove_torward },
        { "move_forward", lmove_forward },
        { "size_of", lsize_of },
        { "profiler_start", lprofiler_start },
        { "profiler_stack_start", lprofiler_stack_start },
        { NULL, NULL },
    };
    luaL_newlib(L,l);

    lua_getglobal(L, "tostring");
    lua_pushcclosure(L, ltostring, 1);
    lua_setfield(L, -2, "tostring");

    return 1;
}
