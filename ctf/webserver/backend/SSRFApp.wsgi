#!/usr/bin/python
import sys
import logging
import random
import string
logging.basicConfig(stream=sys.stderr)
sys.path.insert(0,"/var/www/SSRFApp/")

from SSRFApp import app as application
application.secret_key = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(24))
