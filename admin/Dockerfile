FROM python:3.8-buster

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get install wget ca-certificates
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN apt-get update
RUN apt-get install libpq-dev
RUN curl -fsSL https://get.docker.com -o get-docker.sh
RUN sh get-docker.sh

COPY ./requirements.txt /admin/requirements.txt
WORKDIR /admin

RUN pip3 install -r requirements.txt
COPY . /admin
ENV PYTHONPATH="/"
CMD [ "python3", "agent.py" ]