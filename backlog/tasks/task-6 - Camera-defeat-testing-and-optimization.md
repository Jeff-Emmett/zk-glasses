---
id: TASK-6
title: Camera defeat testing and optimization
status: To Do
assignee: []
created_date: '2026-02-22 00:44'
labels: []
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Systematic testing against facial recognition systems. Test against OpenCV/dlib face detector, cloud FR APIs (AWS Rekognition, Google Vision). Measure at various distances (1-5m), lighting conditions (indoor, outdoor, night), and camera types (phone, webcam, CCTV, doorbell). Optimize LED angle, brightness, and pulse frequency for maximum disruption with minimum power draw.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Face detection fails at 2m+ indoor
- [ ] #2 Tested against 3+ FR algorithms
- [ ] #3 Optimal pulse frequency identified
- [ ] #4 Power vs effectiveness tradeoff documented
- [ ] #5 Limitations documented (daylight, high-end cameras)
<!-- AC:END -->
