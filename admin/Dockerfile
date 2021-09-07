FROM python:3.8-buster

COPY ./requirements.txt /admin/requirements.txt
WORKDIR /admin
RUN pip3 install -r requirements.txt

COPY . /admin
ENV PYTHONPATH="/"
CMD [ "python3", "agent.py" ]