## ADDED Requirements

### Requirement: The sandbox VM restores repo-controlled guest state before each e2e run
Before the e2e layer starts, `tests/sandbox/sandbox.sh e2e` SHALL restore the guest state the repo controls (the `org.alacritty` defaults domain and the terminal setup the checked-out branch applies) to exactly what the checked-out branch defines, so an e2e result never depends on which branch ran in the VM before.

#### Scenario: Guest restore drops Alacritty defaults the branch does not define
- **WHEN** the guest restore step runs against an `org.alacritty` domain (a temp plist) that holds `NSUserKeyEquivalents` `"Quit alacritty" = "@~^q"` and `"Hide alacritty" = "@~^h"`, in a checkout whose `terminal/` defines no menu key setup
- **THEN** reading `NSUserKeyEquivalents` from that domain fails (the key does not exist)

#### Scenario: Guest restore applies the branch's own terminal setup
- **WHEN** the guest restore step runs against an empty `org.alacritty` domain (a temp plist) in a checkout whose `terminal/` defines a setup script writing a key to that domain
- **THEN** the domain holds exactly the key that script writes and nothing an earlier run left there

#### Scenario: sandbox.sh e2e restores guest state after syncing and before the e2e layer
- **WHEN** `tests/sandbox/sandbox.sh e2e` runs with `lume`, `ssh` and `rsync` stubbed (VM running, provisioned, GUI session up)
- **THEN** the logged guest commands contain the repo sync, then the guest restore step, then `make -s e2e-local`, in that order
