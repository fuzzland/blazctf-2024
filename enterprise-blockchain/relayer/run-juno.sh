#!/bin/sh -e

. ./venv/bin/activate
python3 main.py -l1_url http://localhost:18704/ -l2_url http://localhost:18705/

exit 0
