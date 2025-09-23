#!/bin/bash
yamllint -d "{extends: relaxed, rules: {line-length: disable}}" "$1"
