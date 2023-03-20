#!/bin/bash

posting=10
i=0
while [[ "$((i+=1))" -le "${posting}" ]]; do
    bash fblowres.sh "${1}" || { true ; continue ;}
    sleep "$(awk -v "a=120" -v "b=160" -v "c=$RANDOM" 'BEGIN{srand(c);print int(a+rand()*(b-a+1))}')"
done