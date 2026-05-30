# Contributing to DAKKHO

Thank you for your interest in contributing to the DAKKHO platform! This document outlines the development guidelines and processes that all contributors must follow.

---

## Code of Conduct

- Be respectful and professional
- Focus on constructive feedback
- Prioritize the student experience in all decisions
- Respect the proprietary nature of this codebase

---

## Code Style

### Dart / Flutter

- **Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)** guidelines
- Use `dart format` before committing (line length: 80)
- Run `dart analyze` and ensure zero warnings before pushing
- Use meaningful variable and function names (Bengali context: English names, Bengali user-facing strings)
- Prefer composition over inheritance
- Keep widgets small and focused — extract when a widget exceeds 150 lines

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Files | `snake_case` | `course_detail_page.dart` |
| Classes | `PascalCase` | `CourseDetailPage` |
| Functions/Methods | `camelCase` | `fetchCourses()` |
| Variables | `camelCase` | `courseList` |
| Constants | `camelCase` | `maxRetryCount` |
| Private members | Prefix with `_` | `_handleTap()` |
| Enums | `PascalCase` | `DakkhoAnimation` |
| Extensions | `PascalCase` | `BuildContextExtensions` |

### Imports Order

Organize imports in this order (enforced by `flutter_lints`):

```dart
// 1. Dart SDK
import 'dart:async';

// 2. Flutter packages
import 'package:flutter/material.dart';

// 3. Third-party packages
import 'package:riverpod/riverpod.dart';

// 4. Project imports
import 'package:dakkho_student/core/theme/app_colors.dart';
```

---

## Commit Format

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Code style (formatting, semicolons, etc.) |
| `refactor` | Code refactoring without behavior change |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Build process, tooling, dependencies |
| `ci` | CI/CD configuration |
| `revert` | Revert a previous commit |

### Examples

```bash
feat(quiz): add negative marking UI for mock exams
fix(video): resolve HLS stream buffering on slow networks
docs(readme): update environment variables section
refactor(auth): extract OTP verification into reusable widget
perf(animations): defer Lottie precache to first frame
test(course): add unit tests for course repository
chore(deps): bump flutter_animate to 4.5.0
```

---

## Branch Naming

| Pattern | Purpose | Example |
|---------|---------|---------|
| `feature/<ticket>-<description>` | New feature | `feature/DAK-142-quiz-negative-marking` |
| `fix/<ticket>-<description>` | Bug fix | `fix/DAK-89-hls-buffering` |
| `hotfix/<ticket>-<description>` | Production hotfix | `hotfix/DAK-201-payment-crash` |
| `refactor/<description>` | Code refactoring | `refactor/auth-extraction` |
| `docs/<description>` | Documentation | `docs/api-reference` |

### Rules

- Always branch from `main`
- Keep branch names short but descriptive
- Include ticket number when available
- Use hyphens (`-`) as separators, not underscores

---

## Pull Request Process

### Requirements

1. **1 Approval** — At least one team member must approve
2. **Tests Pass** — All CI checks must be green (analyze, test, build)
3. **No Merge Conflicts** — Rebase on `main` before requesting review
4. **PR Description** — Use the PR template, describe what and why
5. **Small PRs** — Aim for < 400 lines changed; break large features into stacked PRs

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] feat: New feature
- [ ] fix: Bug fix
- [ ] refactor: Code refactoring
- [ ] perf: Performance improvement
- [ ] test: Test addition/update
- [ ] docs: Documentation update
- [ ] chore: Build/tooling change

## Related Tickets
- DAK-XXX

## Testing
- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Tested on physical device
- [ ] Tested in offline mode
- [ ] Performance Mode tested

## Screenshots (if UI change)
Before | After
---|---
| |

## Checklist
- [ ] Code follows Effective Dart guidelines
- [ ] `dart analyze` passes with zero warnings
- [ ] `dart format` applied
- [ ] No secrets/keys committed
- [ ] Animations use DakkhoAnimation presets
- [ ] Performance Mode respected (if animation change)
```

### Review Guidelines

- Review within 24 hours
- Be constructive — explain *why*, not just *what*
- Test the branch locally for UI changes
- Verify animations respect Performance Mode

---

## Animation Standards

All animations in DAKKHO must follow the architecture defined in `DAKKHO-Flutter-Animation-Architecture.md`:

### Rules

1. **Use `DakkhoAnimation` enum** — All animation IDs must be registered in the central enum
2. **Use `AnimationPresets`** — Apply animations via preset methods, not ad-hoc `AnimationController`
3. **Respect `PerformanceMode`** — Every animated widget must check:
   ```dart
   final isPerformanceMode = ref.watch(performanceModeProvider);
   if (isPerformanceMode) {
     // Skip or simplify animation
     return child;
   }
   return AnimationPresets.fadeIn(child: child);
   ```
4. **Duration limits** — Micro-animations ≤ 300ms, Page transitions ≤ 400ms, Loading ≤ 1500ms
5. **Asset budget** — Total animation assets ≤ 3 MB per app
6. **Lottie precache** — Use `DakkhoLottieCache` singleton for preloading
7. **RepaintBoundary** — Wrap expensive animated widgets with `RepaintBoundary`
8. **Controller disposal** — Always dispose `AnimationController` in `dispose()` or use `flutter_hooks`

---

## Testing Requirements

| Type | Requirement |
|------|-------------|
| **Unit Tests** | Required for all repositories, services, and utility functions |
| **Widget Tests** | Required for custom widgets with interaction |
| **Integration Tests** | Required for critical flows (auth, payment, video playback) |
| **Golden Tests** | Required for custom painters and complex layouts |
| **Coverage** | Aim for ≥ 70% line coverage |

### Running Tests

```bash
# All tests
flutter test

# With coverage
flutter test --coverage

# Specific test file
flutter test test/unit/data/repositories/course_repository_test.dart

# Integration tests
flutter test integration_test/
```

---

## Security

- **Never commit secrets** — Use `.env.example` as template, actual values in `.env` (gitignored)
- **Never commit keystores** — `*.jks`, `*.keystore`, `key.properties` are gitignored
- **Never commit google-services.json** — Keep only the template
- **Audit dependencies** — Run `dart pub audit` before updating dependencies
- **Report vulnerabilities** — Email security issues to the project maintainer directly

---

## Release Process

1. Create a branch from `main`: `release/vX.Y.Z`
2. Update version in `pubspec.yaml`
3. Update `CHANGELOG.md`
4. Run full test suite and verify
5. Create PR to `main`
6. After merge, tag the release: `git tag v1.0.0 && git push origin v1.0.0`
7. CI will build the release AAB automatically
8. Upload AAB to Google Play Console

### Version Scheme

- **MAJOR** (X): Breaking changes
- **MINOR** (Y): New features (backward compatible)
- **PATCH** (Z): Bug fixes

---

## Questions?

For questions about these guidelines, reach out to the project maintainer or open a discussion in the repository.

---

<p align="center">
  Built with ❤️ for BTEB Diploma Engineering Students of Bangladesh
</p>
