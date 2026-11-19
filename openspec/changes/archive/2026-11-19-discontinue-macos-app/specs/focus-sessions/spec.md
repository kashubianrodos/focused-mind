# Spec Delta

## REMOVED Requirements

### Requirement: Compact always-visible indicator
**Reason**: The macOS app, the only platform with a menu bar, is discontinued. On Android and iPhone a session keeps running in the background instead (Android shows an ongoing notification).
**Migration**: None for users. The implementation is kept in `archive/macos/` with steps to restore it.
