//
// Created by 廖肇燕 on 2023/8/21.
//

#include "async_ssl.h"
#include <openssl/opensslconf.h>
#include <openssl/bio.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>

#define BUFF_MAX 16384
static SSL_CTX *sslContext = NULL;  // only setup on main function.

int ssl_read(void *handle, char *buff, int len)
{
    int ret = 0;
    int size = BUFF_MAX < len ? BUFF_MAX : len;

    ret = SSL_read((SSL *)handle, (void *)buff, size);
    if (ret < 0) {
        int err = SSL_get_error((SSL *)handle, ret);
        if (err == SSL_ERROR_WANT_READ) {
            ret = -11;
            goto needContinue;
        } else {
            fprintf(stderr, "ssl_read failed. ssl_err: %d, errno: %d, %s\n", err, errno, strerror(errno));
            ret = -EIO;
            goto readFailed;
        }
    }

    return ret;
    needContinue:   // for to continue read.
    return ret;
    readFailed:
    return ret;
}

int ssl_write(void *handle, const char *buff, int offset, int len) {
    int ret = 0;
    ret = SSL_write((SSL *)handle, buff + offset, len);

    if (ret < 0) {
        int err = SSL_get_error((SSL *)handle, ret);
        if (err == SSL_ERROR_WANT_WRITE) {  //just need to write.
            ret = -11;
            goto needContinue;
        } else {
            fprintf(stderr, "ssl_write failed. ssl_err: %d, errno: %d, %s\n", err, errno, strerror(errno));
            ret = -EIO;
            goto writeFailed;
        }
    }
    return ret;
    needContinue:
    writeFailed:
    return ret;
}

void *ssl_connect_pre(int fd, void* hCtx) {
    int ret;
    SSL_CTX *ctx = (SSL_CTX *)hCtx;
    if (ctx == NULL) {
        ctx = sslContext;
    }
    SSL *handle = SSL_new(ctx);
    if (handle == NULL) {
        fprintf(stderr, "ssl_connect_pre new ssl failed. %d, %s\n", errno, strerror(errno));
        return NULL;
    }

    ret = SSL_set_fd(handle, fd);
    if (ret < 0) {
        fprintf(stderr, "ssl_connect_pre bind fd failed. %d, %s\n", errno, strerror(errno));
        SSL_shutdown(handle);
        SSL_free(handle);
        return NULL;
    }
    SSL_set_connect_state(handle);
    return handle;
}

int ssl_handshake(void * handle) {
    int ret = 0, err = 0;
    SSL *h = (SSL *)handle;

    ret = SSL_do_handshake(h);
    if (ret == 1) {
        return 0;  // means handshake  success.
    }

    err = SSL_get_error(h, ret);
    switch (err) {
        case SSL_ERROR_NONE:  //no error
        case SSL_ERROR_SSL:  //no error
            return 0;
        case SSL_ERROR_WANT_WRITE:  //wait write.
            return 1;
        case SSL_ERROR_WANT_READ:
            return 2;
        case SSL_ERROR_SYSCALL:
            if (errno == 0) {
                fprintf(stderr, "ssl_connect handshake failed. remote server close connection.\n");
            } else {
                fprintf(stderr, "ssl_connect handshake failed. err: SSL_ERROR_SYSCALL, errno: %d, %s\n", errno, strerror(errno));
            }
            return -1;
        default:
            fprintf(stderr, "ssl_connect handshake failed. err: %d, errno: %d, %s\n", err, errno, strerror(errno));
            return -1;
    }
}

void ssl_shutdown(void *handle) {
    int ret = 0;
    unsigned long err_code;
    int tries = 0;

    if (handle == NULL) {
        return;
    }
    SSL *h = (SSL *)handle;
    while (ret == 0 && tries++ < 10) {
        ret = SSL_shutdown(h);
        if (ret < 0) {
            char buf[64];
            int size;
            int err = SSL_get_error(h, ret);
            switch (err)
            {
            case SSL_ERROR_NONE:  //no error
            case SSL_ERROR_SSL:  //no error
                break;
            case SSL_ERROR_WANT_WRITE:
                break;
            case SSL_ERROR_WANT_READ:
                size = ssl_read(h, buf, 64 - 1);
                if (size > 0) {
                    buf[size] = '\0';
                    fprintf(stderr, "SSL_shutdown, waste %d bytes: %s\n", size, buf);
                }
                break;
            case SSL_ERROR_SYSCALL:
                err_code = ERR_get_error();
                if (err_code != 0 || errno != 0) {
                    if (errno == EPIPE || errno == ECONNRESET) {  // remote server close connection, donot print error.
                        break;
                    }
                    fprintf(stderr, "SSL_shutdown failed. err: SSL_ERROR_SYSCALL, OpenSSL error: %s, errno: %d, %s\n", ERR_error_string(err_code, NULL), errno, strerror(errno));
                }
                break;
            default:
                fprintf(stderr, "SSL_shutdown failed. err: %d, OpenSSL error: %s, errno:%d, %s\n", err, ERR_error_string(ERR_get_error(), NULL), errno, strerror(errno));
                break;
            }
        }
    }
}

void ssl_free(void *handle) {
    if (handle == NULL) {
        return;
    }
    SSL *h = (SSL *)handle;
    SSL_free(h);
}

void *ssl_client_new_with_ca(const char* certificate, const char* ca) {
    SSL_CTX *ctx = SSL_CTX_new(TLS_client_method());
    if (ctx == NULL) {
        return NULL;
    }
    if (SSL_CTX_load_verify_locations(ctx, certificate, ca) <= 0) {
        fprintf(stderr, "set up certificate file failed. %d, %s\n", errno, strerror(errno));
        SSL_CTX_free(ctx);
        return NULL;
    }
    return ctx;
}

void *ssl_server_new(const char* certificate, const char* key) {
    SSL_CTX *ctx = SSL_CTX_new(TLS_server_method());
    if (ctx == NULL) {
        return NULL;
    }
    if (SSL_CTX_use_certificate_file(ctx, certificate, SSL_FILETYPE_PEM) <= 0) {
        fprintf(stderr, "set up certificate file failed. %d, %s\n", errno, strerror(errno));
        SSL_CTX_free(ctx);
        return NULL;
    }
    if (SSL_CTX_use_PrivateKey_file(ctx, key, SSL_FILETYPE_PEM) <= 0) {
        fprintf(stderr, "set up private key file failed. %d, %s\n", errno, strerror(errno));
        SSL_CTX_free(ctx);
        return NULL;
    }
    SSL_CTX_set_session_cache_mode(ctx, SSL_SESS_CACHE_SERVER);
    SSL_CTX_sess_set_cache_size(ctx, 16);
    return ctx;
}

void ssl_ctx_del(void *hCtx) {
    SSL_CTX *ctx = (SSL_CTX *)hCtx;
    SSL_CTX_free(ctx);
}

void *ssl_accept_pre(int fd, void* hCtx) {
    int ret;
    SSL_CTX *ctx = (SSL_CTX *)hCtx;
    SSL *handle = SSL_new(ctx);
    if (handle == NULL) {
        fprintf(stderr, "ssl_connect_pre new ssl failed. %d, %s\n", errno, strerror(errno));
        return NULL;
    }

    ret = SSL_set_fd(handle, fd);
    if (ret < 0) {
        fprintf(stderr, "ssl_connect_pre bind fd failed. %d, %s\n", errno, strerror(errno));
        SSL_shutdown(handle);
        SSL_free(handle);
        return NULL;
    }
    SSL_set_accept_state(handle);
    return handle;
}

void async_ssl_deinit(void) {
    if (sslContext != NULL) {
        SSL_CTX_free(sslContext);
        ERR_free_strings();
        EVP_cleanup();
        CRYPTO_cleanup_all_ex_data();
        sslContext = NULL;
    }
}

int async_ssl_init(void) {
    int ret = 0;

    SSL_library_init();
    SSL_load_error_strings();   /* load all error messages */
    OpenSSL_add_all_algorithms();  /* load all algorithms */

    sslContext = SSL_CTX_new(TLS_client_method());
    if (sslContext == NULL) {
        unsigned long err = ERR_get_error(); 
        fprintf(stderr, "set up sslContext failed. OpenSSL error: %s\n", ERR_error_string(err, NULL));
        ret = -1; // 使用 OpenSSL 特定的错误代码或自定义错误处理
        goto sslFailed;
    }
    SSL_CTX_set_session_cache_mode(sslContext, SSL_SESS_CACHE_CLIENT);
    SSL_CTX_sess_set_cache_size(sslContext, 16);
    return ret;

    sslFailed:
    return ret;
}
