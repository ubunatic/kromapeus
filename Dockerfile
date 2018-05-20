# main app Dockerfile

FROM python:3
RUN pip install prometheus_client
ADD app/server.py /app/server.py

ENV APP_VERSION v0.0.1

EXPOSE 8080

CMD [ "python", "/app/server.py", "8080" ]
