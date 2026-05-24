#!/bin/bash
cd /Users/kemaltuncer/Desktop/praticase/build/web
/usr/bin/python3 -m http.server ${PORT:-8081}
