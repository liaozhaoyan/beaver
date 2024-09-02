#include <string.h>
#include <stdio.h>
#include <openssl/md5.h>
#include <openssl/sha.h>
#include <openssl/hmac.h>
#include <openssl/evp.h>

static const char hexChars[] = "0123456789abcdef";

static void binaryToHex(const unsigned char* binary, int binaryLength, char* hexOutput) {
    int i;
    for(i = 0; i < binaryLength; i ++) {
        hexOutput[i * 2] = hexChars[(binary[i] >> 4) & 0x0F];
        hexOutput[i * 2 + 1] = hexChars[binary[i] & 0x0F];
    }
    hexOutput[binaryLength * 2] = '\0';
}

void md5_digest(const char *data, int len, char *digest) {
    MD5_CTX ctx;
    unsigned char md5[MD5_DIGEST_LENGTH];

    MD5_Init(&ctx);
    MD5_Update(&ctx, data, len);
    MD5_Final(md5, &ctx);

    binaryToHex(md5, MD5_DIGEST_LENGTH, digest);
}

void sha1_digest(const char *data, int len, char *digest) {
    SHA_CTX ctx;
    unsigned char sha1[SHA_DIGEST_LENGTH];

    SHA1_Init(&ctx);
    SHA1_Update(&ctx, data, len);
    SHA1_Final(sha1, &ctx);
    binaryToHex(sha1, SHA_DIGEST_LENGTH, digest);
}

void sha256_digest(const char *data, int len, char *digest) {
    SHA256_CTX ctx;
    unsigned char sha256[SHA256_DIGEST_LENGTH];

    SHA256_Init(&ctx);
    SHA256_Update(&ctx, data, len);
    SHA256_Final(sha256, &ctx);
    binaryToHex(sha256, SHA256_DIGEST_LENGTH, digest);
}

#define HMAC_MD5 0
#define HMAC_SHA1 1
#define HMAC_SHA224 2
#define HMAC_SHA256 3
#define HMAC_SHA384 4
#define HMAC_SHA512 5
#define HMAC_MAX 6
int hmac_digest(const char *key, int key_len, const char *data, int data_len, char *digest, int mode) {
    int hmac_len;

     HMAC_CTX *ctx = HMAC_CTX_new();
    if (ctx == NULL) {
        printf("Failed to create HMAC context\n");
        return -1;
    }

    switch (mode) {
    case HMAC_MD5:
         if (!HMAC_Init_ex(ctx, (const void*)key, key_len, EVP_md5(), NULL)) {
            printf("Failed to init HMAC context\n");
            HMAC_CTX_free(ctx);
            return -1;
        }
        break;

    case HMAC_SHA1:
        if (!HMAC_Init_ex(ctx, (const void*)key, key_len, EVP_sha1(), NULL)) {
            printf("Failed to init HMAC context\n");
            HMAC_CTX_free(ctx);
            return -1;
        }
        break;
    
    case HMAC_SHA224:
        if (!HMAC_Init_ex(ctx, (const void*)key, key_len, EVP_sha224(), NULL)) {
            printf("Failed to init HMAC context\n");
            HMAC_CTX_free(ctx);
            return -1;
        }
        break;

    case HMAC_SHA256:
        if (!HMAC_Init_ex(ctx, (const void*)key, key_len, EVP_sha256(), NULL)) {
            printf("Failed to init HMAC context\n");
            HMAC_CTX_free(ctx);
            return -1;
        }
        break;

    case HMAC_SHA384:
        if (!HMAC_Init_ex(ctx, (const void*)key, key_len, EVP_sha384(), NULL)) {
            printf("Failed to init HMAC context\n");
            HMAC_CTX_free(ctx);
            return -1;
        }
        break;
    case HMAC_SHA512:
        if (!HMAC_Init_ex(ctx, (const void*)key, key_len, EVP_sha512(), NULL)) {
            printf("Failed to init HMAC context\n");
            HMAC_CTX_free(ctx);
            return -1;
        }
        break;
    
    default:
        printf("Invalid HMAC mode %d\n", mode);
        HMAC_CTX_free(ctx);
        return -1;
    }

    if (!HMAC_Update(ctx, (unsigned char*)data, data_len)) {
        printf("Failed to update HMAC data\n");
        HMAC_CTX_free(ctx);
        return -1;
    }

    if (!HMAC_Final(ctx, digest, &hmac_len)) {
        printf("Failed to finalize HMAC\n");
        HMAC_CTX_free(ctx);
        return -1;
    }

    HMAC_CTX_free(ctx);
    return hmac_len;
}
