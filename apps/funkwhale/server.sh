#!/bin/bash -eux
python /app/manage.py collectstatic --noinput
gunicorn config.asgi:application -w ${FUNKWHALE_WEB_WORKERS-1} -k uvicorn.workers.UvicornWorker -b 0.0.0.0:5678 ${GUNICORN_ARGS-}