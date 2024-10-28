#!/bin/bash

as -o server.o server.s
ld -o server server.o