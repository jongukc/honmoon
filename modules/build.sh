#!/bin/bash -ex

make clean
bear -- make -j$(nproc) CC=gcc all
