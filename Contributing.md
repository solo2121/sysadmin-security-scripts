```markdown
# 🚀 Contribution Guidelines

Welcome to the Security & System Administration Toolkit contribution guide!
We appreciate your interest in helping improve this project.

## 📌 Table of Contents
- [Ways to Contribute](#-ways-to-contribute)
- [Development Workflow](#-development-workflow)
- [Code Standards](#-code-standards)
- [Pull Request Process](#-pull-request-process)
- [Local Setup](#-local-setup)

---

## 🤝 Ways to Contribute

### 🐛 Issue Reporting
- **Bug Reports**:
  [Use bug report template](https://github.com/solo2121/sysadmin-security-scripts/issues/new?template=bug_report.md)
- **Feature Requests**:
  [Use feature request template](https://github.com/solo2121/sysadmin-security-scripts/issues/new?template=feature_request.md)
- **Documentation Improvements**:
  Open a regular issue with "[Docs]" prefix

### 💻 Code Contributions
1. Fork the repository
2. Create a descriptive branch name:
   - `feat/` for new features
   - `fix/` for bug fixes
   - `docs/` for documentation
3. Commit your changes
4. Push to your fork
5. Open a pull request

---

## 🔧 Development Workflow

### ✅ Pre-Commit Checks
We recommend setting up our pre-commit hook:
```bash
ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit
```

### 🧪 Testing Requirements
- Verify scripts work on:
  - Ubuntu LTS (22.04+)
  - Alpine Linux (latest)
- Include test cases for complex logic

---

## 🛠️ Code Standards

### Shell Script Guidelines
```bash
#!/usr/bin/env bash
# [Optional] For POSIX compliance: #!/usr/bin/env sh
```
- Pass all `shellcheck` validations
- Include detailed header comments:
  ```bash
  #!/usr/bin/env bash
  #
  # Script Name: example.sh
  # Description: Brief description of script functionality
  # Author: Your Name
  # Usage: ./example.sh [options]
  #
  ```

### Dependency Management
- Keep external dependencies to ≤3 per script
- Document requirements in script headers

---

## 🔍 Pull Request Process

### PR Checklist
- [ ] All scripts pass `shellcheck`
- [ ] Tested on multiple platforms
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Follows existing code style

### Commit Message Format
```
type(scope): brief description

Optional body explaining changes in detail
```
**Types**: feat, fix, docs, style, refactor, test, chore

---

## ⚙️ Local Setup

1. Clone repository:
   ```bash
   git clone https://github.com/solo2121/sysadmin-security-scripts.git
   cd sysadmin-security-scripts
   ```

2. Install development dependencies:
   ```bash
   ./scripts/setup-dev-env.sh
   ```

---

## 📜 Community Guidelines

Please review our:
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Policy](SECURITY.md)

For questions, join our [Discussions](https://github.com/solo2121/sysadmin-security-scripts/discussions).

---
