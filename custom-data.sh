#!/usr/bin/python3 /etc/cloud_config.py

installationType="waap_vmss"
allowUploadDownload="false"
osVersion="R8120"
templateName="waap_vmss"
isBlink="True"
templateVersion="20211111"
bootstrapScript64=""
location="westeurope"
sicKey=""
waapAgentToken ="${token}"
waapAgentFog =""

vnet="${vnet}"