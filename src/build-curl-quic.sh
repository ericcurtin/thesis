#!/bin/bash

set -e

# somewhere1="$PWD/../usr/openssl-quic"
somewhere1="$PWD/../usr/freetls"
somewhere2="$PWD/../usr/nghttp3"
somewhere3="$PWD/../usr/ngtcp2"
somewhere4="$PWD/../usr/curl"
base="$PWD/.."

rm -rf $somewhere1
rm -rf $somewhere2
rm -rf $somewhere3
rm -rf $somewhere4
mkdir -p $somewhere1
mkdir -p $somewhere2
mkdir -p $somewhere3
mkdir -p $somewhere4

nproc=$(nproc)

# Build openssl-quic

if false; then
cd ../..
if [ ! -d "$somewhere1" ]; then
  git clone -b OpenSSL_1_1_1g-quic-draft-29 https://github.com/tatsuhiro-t/openssl $somewhere1
fi

cd openssl-quic
git clean -fdx
git fetch
git reset --hard origin/OpenSSL_1_1_1g-quic-draft-29
printf "openssl-quic\n\n" > "$base/usr/origins.txt"
git log -1 HEAD >> "$base/usr/origins.txt"
./config enable-tls1_3 --prefix=$somewhere1
make -j$nproc
make install_sw
fi

# Build freetls (instead of the other unofficial fork)

cd ../..
if [ ! -d "$somewhere1" ]; then
  git clone -b OpenSSL_1_1_1g-quic-draft-29 https://github.com/freetls/freetls $somewhere1
fi

cd freetls
git clean -fdx
git fetch
git reset --hard origin/OpenSSL_1_1_1g-quic-draft-29
printf "freetls\n\n" > "$base/usr/origins.txt"
git log -1 HEAD >> "$base/usr/origins.txt"
./config enable-tls1_3 --prefix=$somewhere1
make -j$nproc
make install_sw

# Build nghttp3

cd ..
if [ ! -d "$somewhere2" ]; then
  git clone https://github.com/ngtcp2/nghttp3
fi

cd nghttp3
git clean -fdx
git fetch
git reset --hard origin/master
printf "\nnghttp3\n\n" >> "$base/usr/origins.txt"
git log -1 HEAD >> "$base/usr/origins.txt"
autoreconf -i
./configure --prefix=$somewhere2 --enable-lib-only
make -j$nproc
make install

# Build ngtcp2

cd ..
if [ ! -d "$somewhere3" ]; then
  git clone https://github.com/ngtcp2/ngtcp2
fi

cd ngtcp2
git clean -fdx
git fetch
git reset --hard origin/master
printf "\nngtcp2\n\n" >> "$base/usr/origins.txt"
git log -1 HEAD >> "$base/usr/origins.txt"
autoreconf -i
./configure PKG_CONFIG_PATH=$somewhere1/lib/pkgconfig:$somewhere2/lib/pkgconfig LDFLAGS="-Wl,-rpath,$somewhere1/lib" --prefix=$somewhere3
make -j$nproc
make install

# Build curl

cd ..
if [ ! -d "curl" ]; then
  git clone https://github.com/curl/curl
fi

cd curl
git clean -fdx
git fetch
#git reset --hard origin/master
printf "\ncurl\n\n" >> "$base/usr/origins.txt"
git log -1 HEAD >> "$base/usr/origins.txt"
./buildconf
LDFLAGS="-Wl,-rpath,$somewhere1/lib" ./configure --with-ssl=$somewhere1 --with-nghttp3=$somewhere2 --with-ngtcp2=$somewhere3 --enable-alt-svc --prefix=$somewhere4
make -j$nproc
make install

cp -R $somewhere1/* $somewhere1/..
cp -R $somewhere2/* $somewhere2/..
cp -R $somewhere3/* $somewhere3/..
cp -R $somewhere4/* $somewhere4/..

exit 0

rm -rf $somewhere1
rm -rf $somewhere2
rm -rf $somewhere3
rm -rf $somewhere4
rm -rf $base/usr/share
rm -rf $base/usr/include
rm -rf $base/usr/lib/engines-*
rm -rf $base/usr/lib/pkgconfig
rm -rf $base/usr/lib/*.a
rm -rf $base/usr/lib/*.la

