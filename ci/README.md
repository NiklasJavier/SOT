# Continuous Integration Toolkit

This directory contains helper scripts that are executed by the GitHub Actions workflows.
They provide a reproducible environment for testing the CLI, validating configuration files
and exercising the Vault integration in a non-interactive manner.

The scripts are written with local execution in mind to ease debugging. They source the
same fixtures as the CI runners and therefore mirror the behaviour of the automated
pipelines.
