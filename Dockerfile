FROM raykao/azure_lightsaber:latest
MAINTAINER Ray Kao <ray.kao@microsoft.com>

USER kenobi
WORKDIR /home/kenobi
ADD . OSSonAzure/
WORKDIR /home/kenobi/OSSonAzure