#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#include "openssl/crypto.h"
#include "openssl/err.h"
#include "openssl/ssl.h"

// To compile and run
// gcc psk.c -lssl -lcrypto -DCLIENT -o client && gcc psk.c -lssl -lcrypto -o
// server && ./server and run the client in another window
// ./client

#define MAX_BUF_SIZE 1024

#define MSG1_REQ "NVMe req 1\n"
#define MSG1_RES "NVMe res 1\n"
#define MSG2_REQ "NVMe req 2\n"
#define MSG2_RES "NVMe res 2\n"

#define SERVER_IP "127.0.0.1"

// TCP port 4420 has been assigned for use by NVMe over Fabrics and TCP port
// 8009 has been assigned by IANA
#define SERVER_PORT 8009

int do_tcp_connection(const char* server_ip, uint16_t port);
int do_tcp_listen(const char* server_ip, uint16_t port);
int do_tcp_accept(int lfd);
void check_and_close(int* fd);

int do_tcp_connection(const char* server_ip, uint16_t port) {
  struct sockaddr_in serv_addr;
  int fd;
  int ret;

  fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    printf("Socket creation failed\n");
    return -1;
  }

  printf("Client fd=%d created\n", fd);
  serv_addr.sin_family = AF_INET;
  if (inet_aton(server_ip, &serv_addr.sin_addr) == 0) {
    printf("inet_aton failed\n");
    goto err_handler;
  }

  serv_addr.sin_port = htons(port);
  printf("Connecting to %s:%d...\n", server_ip, port);
  ret = connect(fd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
  if (ret) {
    printf("Connect failed, errno=%d\n", errno);
    goto err_handler;
  }

  printf("TLS connection succeeded, fd=%d\n", fd);
  return fd;

err_handler:
  close(fd);
  return -1;
}

int do_tcp_listen(const char* server_ip, uint16_t port) {
  struct sockaddr_in addr;
  int optval = 1;
  int lfd;
  int ret;

  lfd = socket(AF_INET, SOCK_STREAM, 0);
  if (lfd < 0) {
    printf("Socket creation failed\n");
    return -1;
  }

  addr.sin_family = AF_INET;
  if (inet_aton(server_ip, &addr.sin_addr) == 0) {
    printf("inet_aton failed\n");
    goto err_handler;
  }

  addr.sin_port = htons(port);
  if (setsockopt(lfd, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval))) {
    printf("set sock reuseaddr failed\n");
  }

  ret = bind(lfd, (struct sockaddr*)&addr, sizeof(addr));
  if (ret) {
    printf("bind failed %s:%d\n", server_ip, port);
    goto err_handler;
  }

  printf("TCP listening on %s:%d...\n", server_ip, port);
  ret = listen(lfd, 5);
  if (ret) {
    printf("listen failed\n");
    goto err_handler;
  }

  printf("TCP listen fd=%d\n", lfd);
  return lfd;

err_handler:
  close(lfd);
  return -1;
}

int do_tcp_accept(int lfd) {
  struct sockaddr_in peeraddr;
  socklen_t peerlen = sizeof(peeraddr);
  int cfd;

  printf("Waiting for TCP connection from client on listen fd=%d...\n", lfd);
  cfd = accept(lfd, (struct sockaddr*)&peeraddr, &peerlen);
  if (cfd < 0) {
    printf("accept failed, errno=%d\n", errno);
    return -1;
  }

  printf("TCP connection accepted fd=%d\n", cfd);
  return cfd;
}

void check_and_close(int* fd) {
  if (*fd < 0) {
    return;
  }

  if (*fd == 0 || *fd == 1 || *fd == 2) {
    printf("Trying to close fd=%d, skipping it !!!\n", *fd);
  }

  printf("Closing fd=%d\n", *fd);
  close(*fd);
  *fd = -1;
}

SSL_CTX* create_context() {
  SSL_CTX* ctx;

#ifdef CLIENT
  ctx = SSL_CTX_new(TLS_client_method());
#else
  ctx = SSL_CTX_new(TLS_server_method());
#endif

  if (!ctx) {
    printf("SSL ctx new failed\n");
    return NULL;
  }

  printf("SSL context created\n");
  return ctx;
}

// The psk_identity field in the ClientKeyExchange message shall contain the
// host NQN and the subsystem NQN separated by a space (‘ ‘=U+0020) character as
// a UTF-8 string, including the terminating null (00h) character.

// These values were concatenated as openssl had issues with long string
#if 0
#define PSK_ID                                                            \
  "nqn.2014-08.org.nvmexpress:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6 " \
  "nqn.2014-08.org.nvmexpress:uuid:36ebf5a9-1df9-47b3-a6d0-e9ba32e428a2"
#endif

#define PSK_ID                                                            \
  "nqn.2014-08.org.nvmexpress:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6 " \
  "nqn.2014-08.org.nvmexpress:uuid:36ebf5a9-1df9-47b3-a6d0-e9"
#define PSK_KEY "1234567890ABCDEF"

unsigned int tls_psk_out_of_bound_serv_cb(SSL* ssl,
                                          const char* id,
                                          unsigned char* psk,
                                          unsigned int max_psk_len) {
  printf("Length of Client's PSK ID %lu\n", strlen(PSK_ID));
  if (strcmp(PSK_ID, id) != 0) {
    printf("Unknown Client's PSK ID\n");
    goto err;
  }

  printf("Length of Client's PSK KEY %u\n", max_psk_len);
  if (strlen(PSK_KEY) > max_psk_len) {
    printf("Insufficient buffer size to copy PSK_KEY\n");
    goto err;
  }

  memcpy(psk, PSK_KEY, strlen(PSK_KEY));
  return strlen(PSK_KEY);

err:
  return 0;
}

SSL* create_ssl_object_server(SSL_CTX* ctx, int lfd) {
  SSL* ssl;
  int fd;

  fd = do_tcp_accept(lfd);
  if (fd < 0) {
    printf("TCP connection establishment failed\n");
    return NULL;
  }

  ssl = SSL_new(ctx);
  if (!ssl) {
    printf("SSL object creation failed\n");
    return NULL;
  }

  SSL_set_fd(ssl, fd);
  SSL_set_psk_server_callback(ssl, tls_psk_out_of_bound_serv_cb);
  printf("SSL object creation finished\n");
  return ssl;
}

#ifndef CLIENT
int do_data_transfer(SSL* ssl) {
  const char* msg_res[] = {MSG1_RES, MSG2_RES};
  const char* res;
  char buf[MAX_BUF_SIZE] = {0};
  int ret, i;

  for (int j = 0; j <= 131072000; j += 22) {
  for (i = 0; i < sizeof(msg_res) / sizeof(msg_res[0]); i++) {
    res = msg_res[i];
    ret = SSL_read(ssl, buf, sizeof(buf) - 1);
    if (ret <= 0) {
      printf("SSL_read failed ret=%d\n", ret);
      return -1;
    }

    printf("SSL_read[%d] %s\n", ret, buf);
    ret = SSL_write(ssl, res, strlen(res));
    if (ret <= 0) {
      printf("SSL_write failed ret=%d\n", ret);
      return -1;
    }

    printf("SSL_write[%d] sent %s\n", ret, res);
  }
  }

  return 0;
}
#endif

// 1 Gbit = 125 megabytes = 131,072,000 bytes
#ifdef CLIENT
int do_data_transfer(SSL* ssl) {
  const char* msg_req[] = {MSG1_REQ, MSG2_REQ};
  const char* req;
  char buf[MAX_BUF_SIZE] = {0};
  int ret, i;
  int len_sent = 0;

  for (int j = 0; j <= 131072000; j += 22) {
  for (i = 0; i < sizeof(msg_req) / sizeof(msg_req[0]); i++) {
    req = msg_req[i];
    const int this_len = strlen(req);
    ret = SSL_write(ssl, req, this_len);
    if (ret <= 0) {
      printf("SSL_write failed ret=%d\n", ret);
      return -1;
    }

    printf("SSL_write[%d] sent %s\n", ret, req);
    ret = SSL_read(ssl, buf, sizeof(buf) - 1);
    if (ret <= 0) {
      printf("SSL_read failed ret=%d\n", ret);
      return -1;
    }

    printf("SSL_read[%d] %s\n", ret, buf);
    len_sent += this_len;
  }
  }

  printf("%d bytes sent\n", len_sent);

  return 0;
}
#endif

void do_cleanup(SSL_CTX* ctx, SSL* ssl) {
  int fd;
  if (ssl) {
    fd = SSL_get_fd(ssl);
    SSL_free(ssl);
    close(fd);
  }

  if (ctx) {
    SSL_CTX_free(ctx);
  }
}

void get_error() {
  unsigned long error;
  const char* file = NULL;
  int line = 0;
  error = ERR_get_error_line(&file, &line);
  printf("Error reason=%d on [%s:%d]\n", ERR_GET_REASON(error), file, line);
}

int tls_server() {
  SSL_CTX* ctx;
  SSL* ssl = NULL;
  int lfd;
  int ret;

  ctx = create_context();
  if (!ctx) {
    return -1;
  }

  lfd = do_tcp_listen(SERVER_IP, SERVER_PORT);
  if (lfd < 0) {
    goto err_handler;
  }

  ssl = create_ssl_object_server(ctx, lfd);
  check_and_close(&lfd);
  if (!ssl) {
    goto err_handler;
  }

  ret = SSL_accept(ssl);
  if (ret != 1) {
    printf("SSL accept failed%d\n", ret);
    if (SSL_get_error(ssl, ret) == SSL_ERROR_SSL) {
      get_error();
    }

    goto err_handler;
  }

  printf("SSL accept succeeded\n");
  printf("Negotiated Cipher suite:%s\n",
         SSL_CIPHER_get_name(SSL_get_current_cipher(ssl)));
  if (do_data_transfer(ssl)) {
    printf("Data transfer over TLS failed\n");
    goto err_handler;
  }

  printf("Data transfer over TLS succeeded\n");
  SSL_shutdown(ssl);

err_handler:
  do_cleanup(ctx, ssl);
  return 0;
}

#ifndef CLIENT
int main() {
  printf("OpenSSL version: %s, %s\n", OpenSSL_version(OPENSSL_VERSION),
         OpenSSL_version(OPENSSL_BUILT_ON));
  if (tls_server()) {
    printf("TLS server connection failed\n");
    fflush(stdout);
    return -1;
  }

  return 0;
}
#endif

unsigned int tls_psk_out_of_bound_cb(SSL* ssl,
                                     const char* hint,
                                     char* identity,
                                     unsigned int max_identity_len,
                                     unsigned char* psk,
                                     unsigned int max_psk_len) {
  if ((strlen(PSK_ID) + 1 > max_identity_len) ||
      (strlen(PSK_KEY) > max_psk_len)) {
    printf("PSK ID or Key buffer is not sufficient\n");
    goto err;
  }

  strcpy(identity, PSK_ID);
  memcpy(psk, PSK_KEY, strlen(PSK_KEY));
  printf("Provided Out of bound PSK for TLS client\n");
  return strlen(PSK_KEY);

err:
  return 0;
}

SSL* create_ssl_object_client(SSL_CTX* ctx) {
  SSL* ssl;
  int fd;

  fd = do_tcp_connection(SERVER_IP, SERVER_PORT);
  if (fd < 0) {
    printf("TCP connection establishment failed\n");
    return NULL;
  }

  ssl = SSL_new(ctx);
  if (!ssl) {
    printf("SSL object creation failed\n");
    return NULL;
  }

  SSL_set_fd(ssl, fd);

  SSL_set_psk_client_callback(ssl, tls_psk_out_of_bound_cb);

  printf("SSL object creation finished\n");

  return ssl;
}

int tls_client() {
  SSL_CTX* ctx;
  SSL* ssl = NULL;
  int ret;

  ctx = create_context();
  if (!ctx) {
    return -1;
  }

  ssl = create_ssl_object_client(ctx);
  if (!ssl) {
    goto err_handler;
  }

  ret = SSL_connect(ssl);
  if (ret != 1) {
    printf("SSL connect failed%d\n", ret);
    if (SSL_get_error(ssl, ret) == SSL_ERROR_SSL) {
      get_error();
    }

    goto err_handler;
  }

  printf("SSL connect succeeded\n");
  printf("Negotiated Cipher suite: %s\n",
         SSL_CIPHER_get_name(SSL_get_current_cipher(ssl)));
  if (do_data_transfer(ssl)) {
    printf("Data transfer over TLS failed\n");
    goto err_handler;
  }

  printf("Data transfer over TLS succeeded\n");
  SSL_shutdown(ssl);

err_handler:
  do_cleanup(ctx, ssl);
  return 0;
}

#ifdef CLIENT
int main() {
  printf("OpenSSL version: %s, %s\n", OpenSSL_version(OPENSSL_VERSION),
         OpenSSL_version(OPENSSL_BUILT_ON));
  if (tls_client()) {
    printf("TLS client connection failed\n");
    fflush(stdout);
    return -1;
  }

  return 0;
}
#endif

