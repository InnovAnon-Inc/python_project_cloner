#! /usr/bin/env python

import uvicorn

from python_project_cloner.python_project_cloner import app

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=9323) # TODO get from env

