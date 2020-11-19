#!/bin/bash

#https://quic.rocks:4433/

> http2-$$.txt
> http3-$$.txt

export LD_LIBRARY_PATH=$PWD/../usr/lib

j=0 # basicaly acting like a comment
#host="https://quic.rocks:4433/"
for i in {1..32}; do
  if [ $j -lt 7 ]; then
    if [ $j -eq 0 ]; then 
      host="https://www.google.com/"
    elif [ $j -eq 1 ]; then
      host="https://www.youtube.com/"
    elif [ $j -eq 2 ]; then
      host="https://www.google.ie/"
    elif [ $j -eq 3 ]; then
      host="https://www.youtube.ie/"
    elif [ $j -eq 4 ]; then
      host="https://www.google.co.uk/"
    elif [ $j -eq 5 ]; then
      host="https://www.youtube.co.uk/"
    elif [ $j -eq 6 ]; then
      host="https://www.google.pt/"
    else
      host="https://www.youtube.pt/"
      j=-1
    fi

    ((++j))
  fi

  ../usr/bin/curl -m 2 --http2 -I -w "@curl-format.txt" -o /dev/null -s "$host" >> http2-$$.txt
  ../usr/bin/curl -m 2 --http3 -I -w "@curl-format.txt" -o /dev/null -s "$host" >> http3-$$.txt
done

./connect-speed-calc.pl http2-$$.txt http3-$$.txt

