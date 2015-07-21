#!/bin/bash

# Firewalld sample shell scripts


### permit http and https ###
firewall-cmd --zone=public --add-service=http --perma
nent
firewall-cmd --zone=public --add-service=https --perma
nent



firewall-cmd --reload
