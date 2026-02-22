---
id: TASK-5
title: Flash ATtiny85 firmware and full system integration
status: To Do
assignee: []
created_date: '2026-02-22 00:44'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Flash zk_glasses.ino onto ATtiny85 via USBasp programmer. Wire complete circuit: MCU → MOSFETs → flex PCB LED strips → battery → charger → switches. Assemble into printed frame. Test all 6 modes, brightness control, button response, battery life, and USB-C charging.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ATtiny85 flashed and running
- [ ] #2 All 6 LED modes working
- [ ] #3 Button short/long/double press working
- [ ] #4 Battery charges via USB-C
- [ ] #5 Status LED shows low battery warning
- [ ] #6 Full assembly fits in printed frame
<!-- AC:END -->
