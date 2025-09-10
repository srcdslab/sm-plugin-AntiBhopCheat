# Copilot Instructions for AntiBhopCheat Plugin

## Repository Overview
This repository contains **AntiBhopCheat**, a SourcePawn plugin for SourceMod that detects bunny hopping cheats in Source engine games. The plugin analyzes player movement patterns to identify automated jumping scripts, hyperscrolling, and other bhop-related cheats.

### Key Features
- Real-time detection of bhop cheats and hyperscroll patterns
- Configurable detection thresholds for current streaks and global statistics
- Admin notification system with detailed statistics
- Optional integration with SelectiveBhop plugin for automatic bhop limiting
- Forward declarations for integration with other plugins
- Comprehensive logging and kick functionality

## Technical Environment

### Language & Platform
- **Language**: SourcePawn (modern syntax with methodmaps)
- **Platform**: SourceMod 1.11.0+ (uses latest stable release)
- **Compiler**: SourcePawn compiler (spcomp) via SourceKnight
- **Target Games**: Source engine games (CS:S, CS:GO, TF2, etc.)

### Build System
- **Primary Tool**: SourceKnight (automated build system)
- **Configuration**: `sourceknight.yaml` defines dependencies and build targets
- **CI/CD**: GitHub Actions workflow (`.github/workflows/ci.yml`)
- **Artifacts**: Automatic packaging and release creation

### Dependencies
The plugin has several managed dependencies (defined in `sourceknight.yaml`):
- **SourceMod**: Core framework (1.11.0-git6934)
- **MultiColors**: For colored chat messages
- **SelectiveBhop**: Optional integration for bhop limiting
- **Basic**: Utility methodmap base class

## Code Architecture

### File Structure
```
addons/sourcemod/scripting/
├── AntiBhopCheat.sp              # Main plugin file
└── include/
    ├── AntiBhopCheat.inc         # Forward declarations
    ├── CPlayer.inc               # Player data methodmap
    ├── CStreak.inc               # Streak analysis methodmap
    └── CJump.inc                 # Individual jump methodmap
```

### Core Components
1. **CPlayer**: Manages per-player statistics and streak history
2. **CStreak**: Represents a sequence of bunny hops for analysis
3. **CJump**: Individual jump data with timing and velocity information
4. **Detection Engine**: Analyzes patterns to identify cheating behavior

### Key Design Patterns
- **Methodmaps**: Used for object-oriented design (extends Basic class)
- **Event-driven**: Hooks player movement commands and processes in real-time
- **Memory Management**: Proper disposal patterns to prevent leaks
- **Forward System**: Allows other plugins to hook detection events

## Code Style & Standards

### SourcePawn Conventions
- Follow modern SourcePawn syntax (newdecls recommended for new code)
- Indentation: Tabs (4-space equivalent)
- Variable naming:
  - **Local variables**: camelCase (e.g., `iPlayerCount`)
  - **Global variables**: Prefix with `g_` (e.g., `g_bFlagged`)
  - **Function names**: PascalCase (e.g., `HandleFlagging`)
  - **ConVars**: Descriptive names with plugin prefix (e.g., `sm_antibhopcheat_`)

### Memory Management Rules
- Always use `delete` for cleanup (never check for null first)
- Never use `.Clear()` on StringMap/ArrayList (creates memory leaks)
- Use `delete` then create new instances instead of clearing
- Implement proper `Dispose()` methods in methodmaps
- Clean up timers and handles on plugin unload

### Performance Guidelines
- Minimize operations in `OnPlayerRunCmdPost` (called every server tick)
- Cache ConVar values and update only on changes
- Use efficient data structures (ArrayList over arrays where possible)
- Avoid string operations in high-frequency functions
- Consider server tick rate impact (typically 64-128 ticks/second)

## Development Workflow

### Building the Plugin
```bash
# Automatic build via SourceKnight (recommended)
# Triggered by GitHub Actions on push/PR

# Local development (if SourceKnight is available)
sourceknight build
```

### Testing Procedures
1. **Functional Testing**: Deploy on a test server with bhop-enabled maps
2. **Performance Testing**: Monitor server performance during heavy player loads
3. **Integration Testing**: Verify compatibility with other movement plugins
4. **False Positive Testing**: Test with legitimate skilled players

### Configuration Testing
Test various ConVar combinations:
```
sm_antibhopcheat_current_jumps "6"      // Streak length for analysis
sm_antibhopcheat_current_hack "0.90"    // Hack detection threshold
sm_antibhopcheat_current_hyper "0.95"   // Hyperscroll threshold
sm_antibhopcheat_max_detection "2"      // Flags before action
```

## Plugin-Specific Guidelines

### Detection Algorithm Understanding
The plugin analyzes several factors:
- **Jump timing**: Intervals between ground contact and jump press
- **Velocity patterns**: Suspicious speed maintenance or gain
- **Input patterns**: Rapid key press/release cycles (hyperscroll)
- **Consistency**: Statistical analysis over multiple jumps

### ConVar Management
- All detection thresholds are configurable
- Use `OnConVarChanged` hooks for real-time updates
- Validate threshold ranges (0.0 to 1.0 for percentages)
- Consider server type when setting defaults (casual vs competitive)

### Admin Interface
- `sm_stats <player>`: Show detailed player statistics
- `sm_streak <player> [streak_id]`: Analyze specific jump sequences
- Rich console output with timing patterns and velocity data

### Integration Points
- **Forward**: `AntiBhopCheat_OnClientDetected` for other plugins
- **SelectiveBhop**: Optional automatic bhop limiting on detection
- **Sound system**: Admin notification sounds (configurable)

## Common Development Tasks

### Adding New Detection Methods
1. Extend the `DoStats` function in main plugin
2. Add new ConVars for threshold configuration
3. Update `OnConVarChanged` handler
4. Test against known cheat patterns
5. Update admin notification messages

### Modifying Detection Thresholds
1. Consider game type (CS:S vs CS:GO movement differences)
2. Account for legitimate skilled players
3. Test with various scroll wheel settings
4. Validate against recorded demo files

### Performance Optimization
1. Profile code in `OnPlayerRunCmdPost` (most critical)
2. Cache expensive calculations
3. Use efficient data access patterns
4. Monitor memory usage in methodmap classes

## Debugging & Troubleshooting

### Common Issues
- **False positives**: Lower detection thresholds or increase required jumps
- **Memory leaks**: Check methodmap disposal and timer cleanup
- **Performance impact**: Profile tick-rate sensitive functions
- **Compatibility**: Test with other movement-related plugins

### Debug Tools
- Enable console debug prints (uncomment debug lines)
- Use SourceMod's built-in profiler
- Monitor server tick rate during testing
- Analyze demo files for pattern verification

### Log Analysis
The plugin logs important events:
```
[AntiBhopCheat] Player "Name" was kicked for using bhop hack streak
[AntiBhopCheat] Player flagged for hyperscroll (Global: 85.3%)
```

## Security Considerations

### Cheat Detection Accuracy
- Balance between catching cheats and avoiding false positives
- Consider legitimate techniques (scroll wheel binding, skilled players)
- Implement graduated responses (warn → limit → kick)
- Log all detection events for manual review

### Admin Verification
- Encourage spectating flagged players before taking action
- Provide detailed statistics for informed decisions
- Consider recording demos of flagged players
- Implement appeal processes for false positives

## Best Practices Summary

1. **Always test thoroughly** on various game types and player skill levels
2. **Monitor performance impact** on server tick rate and CPU usage
3. **Use methodmaps** for clean object-oriented design
4. **Implement proper memory management** to prevent leaks
5. **Cache ConVar values** and update only when necessary
6. **Provide rich debugging information** through admin commands
7. **Consider integration points** with other movement plugins
8. **Balance detection sensitivity** to minimize false positives
9. **Log important events** for audit trails
10. **Follow SourcePawn modern conventions** for maintainable code

## Version Control & Releases

### Commit Guidelines
- Clear, descriptive commit messages
- Separate feature additions from bug fixes
- Include performance impact notes where relevant
- Reference GitHub issues when applicable

### Release Process
- Automatic builds via GitHub Actions
- Semantic versioning (MAJOR.MINOR.PATCH)
- Release notes should include threshold changes
- Test releases on staging servers before production deployment

This repository follows modern SourcePawn development practices optimized for anti-cheat detection systems. Always prioritize accuracy and performance when making modifications, as false positives can significantly impact the player experience.