#!/bin/bash
jc=$(tail -2 logs/k8s-ziq-C85-setup.log)
lxc exec u2310ctrd -- $jc
