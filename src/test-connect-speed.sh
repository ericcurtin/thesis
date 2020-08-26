#!/bin/bash

> http2-$$.txt
> http3-$$.txt

j=0
for i in {1..128}; do
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

  LD_LIBRARY_PATH=../bin ../bin/curl -m 1 --http2 -I -w "@curl-format.txt" -o /dev/null -s "$host" >> http2-$$.txt
  LD_LIBRARY_PATH=../bin ../bin/curl -m 1 --http3 -I -w "@curl-format.txt" -o /dev/null -s "$host" >> http3-$$.txt
done

./connect-speed-calc.pl http2-$$.txt http3-$$.txt

