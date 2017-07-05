#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# This Dockerfile is for an image to test a "local" RepoGate deployment.

FROM debian:8.6

RUN \
    apt-get update \
    && apt-get install --quiet --assume-yes \
        git \
        python \
        sudo

RUN \
    useradd --password '' --create-home dev \
    && usermod --append --groups sudo dev

RUN \
    git config --global user.email 'dev@example.com' \
    && git config --global user.name 'Dev Eloper'

USER dev

RUN \
    mkdir /home/dev/rg_deploy
