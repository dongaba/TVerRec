#!/bin/bash

service ssh start

gosu tverrec bash /app/TVerRec/unix/start_tverrec.sh
