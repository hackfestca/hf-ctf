from urllib.parse import urlparse
import os
from flask import Flask, request

app = Flask(__name__)

@app.route('/')
def hello():
    host = urlparse(request.host_url).hostname
    return """This is {0}!
    Only accessible from 10.0.0.0/8!
    Accessed using host: {1}
    Here is your flag: {2}
    """.format(os.environ['CUTENAME'],
                "[{}]".format(host),
                os.environ['FLAG'])

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=True)
