FROM ubuntu@sha256:b060fffe8e1561c9c3e6dea6db487b900100fc26830b9ea2ec966c151ab4c020
# 22.04

RUN apt-get update && apt-get install -y \
  curl \
  git \
  gcc g++ \
  python3 \
  python3-dev \
  python3-pip \
  && rm -rf /var/lib/apt/lists/*

RUN curl -L https://foundry.paradigm.xyz | bash
SHELL ["/bin/bash", "-c"]
RUN source ~/.bashrc
ENV PATH="~/.foundry/bin:${PATH}"
RUN foundryup && \
    mv /root/.foundry /opt/foundry && \
    chown -R root: /opt/foundry
RUN bash -c "git config --global user.email root@localhost; git config --global user.name root"

COPY package/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt && rm /tmp/requirements.txt

COPY package/ /app/
RUN chmod 777 /app/*.json

WORKDIR /app/
ENTRYPOINT ["uvicorn", "main:app", "--host", "0.0.0.0"]
