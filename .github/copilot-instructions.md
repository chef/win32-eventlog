# AI Assistant Repository Guidelines for win32-eventlog

## Purpose

This document defines the authoritative operational workflow for AI assistants contributing to the win32-eventlog repository. This Ruby gem provides an interface to the MS Windows Event Log, enabling applications to interact with Windows event logging services.

## Repository Structure

```
win32-eventlog/
├── .expeditor/              # Chef Expeditor automation (release, versioning)
│   ├── config.yml          # Main Expeditor configuration
│   ├── verify.pipeline.yml # CI/CD pipeline definition
│   ├── update_version.sh   # Version update script
│   └── run_windows_tests.ps1 # Windows-specific test runner
├── .github/                # GitHub configuration and templates
│   ├── workflows/          # GitHub Actions CI/CD workflows
│   │   ├── unit.yml       # Unit tests on Windows (2022, 2025) with Ruby 3.1, 3.4
│   │   ├── lint.yml       # Cookstyle linting workflow
│   │   └── logchecker.ps1 # PowerShell log checking utility
│   ├── CODEOWNERS         # Code review assignments
│   ├── ISSUE_TEMPLATE.md  # Issue reporting template
│   └── PULL_REQUEST_TEMPLATE.md # PR submission template
├── lib/                    # Core library code
│   ├── win32-eventlog.rb  # Main entry point
│   └── win32/             # Windows-specific modules
│       ├── eventlog.rb    # Event log interface
│       ├── mc.rb          # Message compiler interface
│       └── windows/       # Low-level Windows API bindings
│           ├── constants.rb # Windows API constants
│           ├── functions.rb # FFI function definitions
│           └── structs.rb   # Windows data structures
├── examples/               # Usage examples
│   ├── example_notify.rb  # Event notification example
│   ├── example_read.rb    # Event reading example
│   └── example_write.rb   # Event writing example
├── test/                   # Test suite
│   ├── test_eventlog.rb   # Event log functionality tests
│   ├── test_mc.rb         # Message compiler tests
│   └── foo.mc             # Test message file
├── misc/                   # Miscellaneous utilities
│   ├── install_msg.rb     # RubyMsg event source installer
│   └── rubymsg.mc         # Ruby message catalog
├── doc/                    # Documentation
│   └── tutorial.txt       # Usage tutorial
├── Gemfile                 # Ruby dependency management
├── Rakefile               # Build and task automation
├── win32-eventlog.gemspec # Gem specification
├── .rubocop.yml           # Cookstyle/RuboCop configuration
├── .travis.yml            # Legacy Travis CI configuration
├── VERSION                # Current version file
├── README.md              # Project documentation
├── CHANGELOG.md           # Version history
└── CODE_OF_CONDUCT.md     # Community guidelines
```

## Tooling & Ecosystem

**Primary Language**: Ruby (3.1, 3.4 supported)
**Testing Framework**: test-unit
**Linting**: Cookstyle (ChefStyle variant of RuboCop)
**FFI**: Ruby FFI for Windows API bindings
**Documentation**: YARD with Markdown support
**Package Management**: RubyGems
**Platform**: Windows-specific (Windows Server 2022, 2025)

**Development Dependencies**:
- `cookstyle` - Code style enforcement
- `test-unit` - Testing framework
- `ptools` - Additional platform tools
- `yard` - Documentation generation
- `pry-*` - Debugging tools

## Issue (Jira/Tracker) Integration

If an issue key is supplied:
- MUST parse: summary, description, acceptance criteria, issue type, linked issues, labels/tags
- Implementation Plan MUST include:
  - Goal
  - Impacted Files
  - Public API/Interface Changes
  - Data/Integration Considerations
  - Test Strategy
  - Edge Cases
  - Risks & Mitigations
  - Rollback Strategy
- No code changes until user approves plan ("yes")
- If acceptance criteria absent → AI MUST prompt user to confirm inferred criteria

## Workflow Overview

Phases (AI MUST follow in order):
1. Intake & Clarify
2. Repository Analysis
3. Plan Draft
4. Plan Confirmation (gate)
5. Incremental Implementation
6. Lint / Style
7. Test & Coverage Validation
8. DCO Commit
9. Push & Draft PR Creation
10. Label & Risk Application
11. Final Validation

Each phase ends with: Step Summary + Checklist + "Continue to next step? (yes/no)".

## Detailed Step Instructions

**Principles (MUST)**:
- Smallest cohesive change per commit
- Add/adjust tests immediately with each behavior change
- Present a mapping of changes to tests before committing

**Example Step Output**:
```
Step: Add boundary guard in parser
Summary: Added nil check & size constraint; tests added for empty input & overflow.
Checklist:
- [x] Plan
- [x] Implementation
- [ ] Tests
Proceed? (yes/no)
```

If user responds other than explicit "yes" → AI MUST pause & clarify.

## Branching & PR Standards

**Branch Naming (MUST)**: EXACT issue key if provided; else kebab-case slug (≤40 chars) derived from task description (e.g., `optimize-parser-allocation`)

**One logical change set per branch (MUST)**

**PR MUST remain draft until**: tests pass + lint/style pass + coverage mapping completed

**PR Description Sections (MUST)**: Uses existing template structure with additional sections:
- Description
- Issues Resolved
- Check List (with DCO requirement)
- Tests & Coverage mapping
- Risk & Mitigations

**Risk Classification (MUST pick one)**:
- Low: Localized, non-breaking
- Moderate: Shared module / light interface touch
- High: Public API change / performance / security / migration

**Rollback Strategy (MUST)**: revert commit <SHA> or feature toggle reference if available

## Commit & DCO Policy

**Commit format (MUST)**:
```
TYPE(OPTIONAL_SCOPE): SUBJECT (ISSUE_KEY)

Rationale (what & why).

Issue: <ISSUE_KEY or none>
Signed-off-by: Full Name <email@domain>
```

Missing sign-off → block and request name/email.

## Testing & Coverage

**Changed Logic → Test Assertions Mapping (MUST)**:
| File | Method/Block | Change Type | Test File | Assertion Reference |

**Coverage Threshold (MUST)**: ≥80% changed lines (qualitative reasoning allowed if tooling absent). If below: add tests or refactor for testability.

**Edge Cases (MUST enumerate for each plan)**:
- Large input / boundary size
- Empty / nil input
- Invalid / malformed data
- Windows-specific behaviors (event log limits, permissions)
- FFI memory management
- Windows API error conditions

**Test Commands**:
- `bundle exec rake test` - Run all tests
- `bundle exec rake test:eventlog` - Event log tests only
- `bundle exec rake test:mc` - Message compiler tests only

## Labels Reference

| Name | Description | Typical Use |
|------|-------------|-------------|
| Aspect: Documentation | How do we use this project? | Documentation improvements |
| Aspect: Integration | Works correctly with other projects or systems | Integration fixes |
| Aspect: Packaging | Distribution of the project's compiled artifacts | Gem packaging issues |
| Aspect: Performance | Works without negatively affecting the system | Performance optimizations |
| Aspect: Portability | Does this project work correctly on the specified platform? | Windows compatibility |
| Aspect: Security | Can an unwanted third party affect stability or look at privileged information? | Security fixes |
| Aspect: Stability | Consistent results | Bug fixes, reliability |
| Aspect: Testing | Does the project have good coverage, and is CI working? | Test improvements |
| Aspect: UI | User interaction with the interface | API design changes |
| Aspect: UX | User experience improvements | Ease of use enhancements |
| dependencies | Pull requests that update a dependency file | Dependency updates |
| Expeditor: Bump Version Major | Used by github.major_bump_labels to bump the Major version number | Breaking changes |
| Expeditor: Bump Version Minor | Used by github.minor_bump_labels to bump the Minor version number | New features |
| Expeditor: Skip All | Used to skip all merge_actions | Emergency bypasses |
| Expeditor: Skip Changelog | Used to skip built_in:update_changelog | Skip changelog updates |
| Expeditor: Skip Version Bump | Used to skip built_in:bump_version | Version bump bypasses |
| hacktoberfest-accepted | A PR that has been accepted for credit in the Hacktoberfest project | Community contributions |
| oss-standards | Related to OSS Repository Standardization | Repository standards |
| Platform: Windows | Windows-specific functionality | Primary platform |

## CI / Release Automation Integration

**GitHub Actions Workflows**:
- `unit.yml`: Unit tests on Windows 2022/2025 with Ruby 3.1/3.4, triggered on PR and master push
- `lint.yml`: Cookstyle linting on Ubuntu, triggered on PR and main push

**Chef Expeditor Integration**:
- Automatic version bumping based on PR labels
- Changelog generation from merged PRs
- RubyGems publishing on version promotion
- Tag format: `win32-eventlog-{{version}}`
- Release branch: `main` with version constraint `*`

**AI MUST NOT directly edit release automation configs without explicit user instruction.**

## Security & Protected Files

**Protected (NEVER edit without explicit approval)**:
- CODE_OF_CONDUCT.md
- CODEOWNERS
- .expeditor/ (all files)
- .github/workflows/ (all files)
- win32-eventlog.gemspec (version field)
- VERSION

**NEVER**:
- Exfiltrate or inject secrets
- Force-push default branch
- Merge PR autonomously
- Insert new binaries
- Remove license headers
- Fabricate issue or label data

## Prompts Pattern

After each step AI MUST output:
```
Step: STEP_NAME
Summary: CONCISE_OUTCOME
Checklist: markdown list of phases with status
Prompt: "Continue to next step? (yes/no)"
```

Non-affirmative response → AI MUST pause & clarify.

## Validation & Exit Criteria

Task is COMPLETE ONLY IF:
1. Feature/fix branch exists & pushed
2. Lint/style passes (`bundle exec rake style`)
3. Tests pass (`bundle exec rake test`)
4. Coverage mapping complete + ≥80% changed lines
5. PR open (draft or ready) with required sections
6. Appropriate labels applied
7. All commits DCO-compliant
8. No unauthorized Protected File modifications
9. User explicitly confirms completion

Otherwise AI MUST list unmet items.

## Issue Planning Template

```
Issue: ABC-123
Summary: <from issue>
Acceptance Criteria:
- ...
Implementation Plan:
- Goal:
- Impacted Files:
- Public API Changes:
- Data/Integration Considerations:
- Test Strategy:
- Edge Cases:
- Risks & Mitigations:
- Rollback:
Proceed? (yes/no)
```

## PR Description Canonical Template

The repository has an existing PR template that MUST be used as the base structure:

### Description
[Please describe what this change achieves]

### Issues Resolved
[List any existing issues this PR resolves, or any Discourse or StackOverflow discussions that are relevant]

### Check List
- [ ] New functionality includes tests
- [ ] All tests pass
- [ ] All commits have been signed-off for the Developer Certificate of Origin

**Additional required sections to inject**:

### Tests & Coverage
Changed lines: N; Estimated covered: ~X%; Mapping complete.

### Risk & Mitigations
Risk: Low | Mitigation: revert commit SHA

## Idempotency Rules

**Re-entry Detection Order (MUST)**:
1. Branch existence (`git rev-parse --verify <branch>`)
2. PR existence (`gh pr list --head <branch>`)
3. Uncommitted changes (`git status --porcelain`)

**Delta Summary (MUST)**:
- Added Sections:
- Modified Sections:
- Deprecated Sections:
- Rationale:

## Failure Handling

**Decision Tree (MUST)**:
- Labels fetch fails → Abort; prompt: "Provide label list manually or fix auth. Retry? (yes/no)"
- Issue fetch incomplete → Ask: "Missing acceptance criteria—provide or proceed with inferred? (provide/proceed)"
- Coverage < threshold → Add tests; re-run; block commit until satisfied
- Missing DCO → Request user name/email
- Protected file modification attempt → Reject & restate policy

## Glossary

- **Changed Lines Coverage**: Portion of modified lines executed by assertions
- **Implementation Plan Freeze Point**: No code changes allowed until approval
- **Protected Files**: Policy-restricted assets requiring explicit user authorization
- **Idempotent Re-entry**: Resuming workflow without duplicated or conflicting state
- **Risk Classification**: Qualitative impact tier (Low/Moderate/High)
- **Rollback Strategy**: Concrete reversal action (revert commit / disable feature)
- **DCO**: Developer Certificate of Origin sign-off confirming contribution rights
- **Cookstyle**: ChefStyle variant of RuboCop for Ruby code styling
- **FFI**: Foreign Function Interface for calling Windows APIs from Ruby

## Quick Reference Commands

```bash
# Generic flow
git checkout -b <BRANCH>
bundle install
bundle exec rake style  # Run cookstyle linting
bundle exec rake test   # Run all tests
git add .
git commit -m "feat(component): add capability (ABC-123)" -m "Issue: ABC-123" -m "Signed-off-by: Full Name <email@domain>"
git push -u origin <BRANCH>
gh pr create --base main --head <BRANCH> --title "ABC-123: Short summary" --draft
gh pr edit <PR_NUMBER> --add-label "Aspect: Documentation"

# Ruby/Gem specific
bundle exec rake test:eventlog  # Run event log tests only
bundle exec rake test:mc        # Run message compiler tests only
bundle exec rake example:read   # Run read example
bundle exec rake example:write  # Run write example
bundle exec rake example:notify # Run notify example
bundle exec rake docs           # Generate documentation
bundle exec rake console        # Start interactive console
```