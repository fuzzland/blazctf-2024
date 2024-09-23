#!/bin/sh -e

. ./venv/bin/activate
python3 main.py -l1_url http://localhost:10001/ -l2_url http://localhost:10002/

exit 0
