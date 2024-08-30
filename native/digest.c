#include <string.h>
#include <stdio.h>
#include <openssl/md5.h>
#include <openssl/sha.h>

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
