#!/usr/bin/bash
test=$(setxkbmap  -query)
if grep us <<< "$test"; then
     setxkbmap de
else
    setxkbmap us
fi

