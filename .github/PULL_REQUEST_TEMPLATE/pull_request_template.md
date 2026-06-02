name: Pull request
description: Submit changes to Stackup
title: "[PR] "
labels: []
body:
  - type: markdown
    attributes:
      value: |
        ## Description

        Briefly describe what this PR changes and why.

        ## Checklist

        - [ ] `make lint` passes locally
        - [ ] `helm template` renders without error
        - [ ] CI is green
        - [ ] Changes are focused and small

        ## Related issue

        Fixes # (if any)