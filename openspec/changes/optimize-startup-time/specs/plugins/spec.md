# Spec Delta

## ADDED Requirements

### Requirement: Real configuration starts within the snappy budget
Neovim SHALL complete a warmed, isolated startup of the real configuration within a 120 ms base budget. The measurement SHALL normalize the budget for current host load and SHALL exclude dependency installation and cold-cache setup.

#### Scenario: Warm real-config startup stays within budget
- **WHEN** `make smoke-startup` launches the real configuration after its warm-up start
- **THEN** the measured startup passes the 120 ms base budget after host-load normalization
