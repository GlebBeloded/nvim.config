## MODIFIED Requirements

### Requirement: Move thresholds
Moves SHALL keep VS Code's thresholds:
- at least 3 lines;
- a deletion and insertion pair only above 0.90 histogram similarity;
- 3-line windows of trimmed lines in other changes;
- growth into touching lines that are trim-equal or share over 60% of the longer line's non-space characters, with more than 10 of them;
- moves joined when their gaps sum to at most 2 lines;
- under 15 trimmed characters dropped, as are moves within one change.

#### Scenario: Short moves are ignored
- **WHEN** `{ "x=10", "y=20", "z=30" }` followed by the four `function` lines is compared with `moves = true` against the four `function` lines followed by `{ "x=10", "y=20", "z=30" }`
- **THEN** `fragments` is `{ { 0, 3, 0, 0 }, { 7, 7, 4, 7 } }` as `{ start1, end1, start2, end2 }`, and `moves` is empty, because the moved text has 14 characters

#### Scenario: Two-line moves are ignored
- **WHEN** `{ "local limit = 2048", "local cheap = true" }` followed by the four `function` lines is compared with `moves = true` against the four `function` lines followed by the two `local` lines
- **THEN** `moves` is empty

#### Scenario: Moves with no containing change are retained
- **WHEN** the same-change filter is called with changes `{ { 5, 8, 5, 8 } }` and move `{ 0, 3, 0, 3 }`
- **THEN** the move is retained because neither side belongs to a change

#### Scenario: Long similar lines extend a move
- **WHEN** `moves.compute` receives changes `{ { 0, 4, 0, 0 }, { 8, 8, 4, 8 } }`, with three equal anchor lines followed by 220 `a` and 80 `b` characters on the original side, four stable lines, then the same anchors followed by 220 `a` and 130 `c` characters on the modified side
- **THEN** it returns `{ { 0, 4, 4, 8 } }`, extending the move through the 300- and 350-character lines without exceeding the shared deadline
