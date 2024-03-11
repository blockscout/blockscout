# Deployment Guide

This guide outlines the steps to deploy BlockScout using Docker and Docker Compose on Ubuntu.

## Prerequisites
Before deploying BlockScout, ensure you have Docker and Docker Compose installed. If not, refer to the [official Docker documentation](https://docs.docker.com/engine/install/ubuntu/) for installation instructions.

## Deployment Steps

1. Clone Repository
```bash
git clone git@github.com:ONINO-IO/blockscout.git
```

2. Create Environment Files
```bash
cd docker-compose/envs
cp common-blockscout.env .env_blockscout
cp common-frontend.env .env_frontend
```

3. Fill environment variables. Refer to [official Blockscout documentation](https://docs.blockscout.com/for-developers/information-and-settings/env-variables)

4. Build backend and start the project
```bash
cd ..
docker compose up -d --build
```
