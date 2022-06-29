FROM python:3.8-buster

RUN apt-get update
RUN apt-get install libpq-dev -y
RUN curl -fsSL https://get.docker.com -o get-docker.sh
RUN sh get-docker.sh

COPY ./requirements.txt /admin/requirements.txt
WORKDIR /admin

RUN pip3 install -r requirements.txt
COPY . /admin
ENV PYTHONPATH="/"
CMD [ "python3", "agent.py" ]